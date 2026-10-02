# Proxy authentication — design

**Status:** Section 1 (storage, form, copy) presented to the user on
2026-10-02, who then moved straight to planning without changes; that is
taken as approval of it and of its four new strings. The rest of this
document (connection flow, failures, testing) was decided by the planning
session without a further round of questions; every such decision is listed
under "Rulings" so the user can overturn it.

## Purpose

A site's own upstream proxy can ask for a login. Two kinds of user need it
(user's answer: "Both"):

1. **Paid or private proxies** that require a username and password, typed by
   the user per site.
2. **Tor circuit isolation.** Tor gives each distinct SOCKS username/password
   pair its own circuit (`IsolateSOCKSAuth`, on by default). An automatic,
   per-site login therefore keeps two sites on the same Tor port off the same
   exit.

Today neither works: SOCKS is delegated to `java.net.Socket`, whose only login
hook is the process-wide `java.net.Authenticator` (one login per proxy
host:port, so no per-site logins), and `HttpConnectTunnel` sends no
`Proxy-Authorization`. A `407` is reported as `PROXY_REFUSED`, "The proxy
refused the destination", which is wrong for a bad password.

## User's answers (2026-10-02)

- Purpose: **both** typed logins and an automatic per-site login.
- Decoy re-sync: typed logins **are copied** into the decoy.
- The automatic login stays the same **until the site is wiped**: a wipe gives
  the site a fresh `profileId`, and so a fresh login and a fresh circuit. A
  throwaway, which always has its own `profileId`, always has its own login.

## 1. Storage and form (approved)

**`Site` fields**, stored in the vault's `sites` table (schema 7):

| Field | Column | Default |
|---|---|---|
| `proxyUser` (`String?`) | `proxy_user TEXT` | null |
| `proxyPassword` (`String?`) | `proxy_password TEXT` | null |
| `proxyLoginPerSite` (`bool`) | `proxy_login_per_site INTEGER NOT NULL DEFAULT 0` | false |

Existing rows upgrade to "no login". The vault is the SQLCipher-encrypted
store, so the password sits beside everything else the vault protects.

**Automatic login.** Nothing extra is stored: the username and password are
derived from the site's `profileId` (§2.3). A wipe rotates the `profileId`
(`wipeSavedSite`), which rotates the login.

**Form — `2a`, Network tab.** Below the HOST/PORT row, and only while "Route
through proxy" is on:

- A toggle row: title **`Separate login per site`**, subtitle **`Tor gives
  this site its own circuit`**. Off by default.
- While that toggle is off: two fields side by side under mono labels
  **`USERNAME`** and **`PASSWORD`**, both optional. The password is masked
  with no reveal control.

**Failure copy.** A new route failure, **`The proxy rejected the login`**.

These four strings (`USERNAME`/`PASSWORD` counted as the field labels, the
toggle's title and subtitle, the failure) are the only new copy.

## 2. Connection flow

### 2.1 Which login a route uses

`Router.resolve` attaches a login to a `Route.Proxy`:

1. `proxyLoginPerSite` on → the derived login (§2.3), whatever is typed.
2. Otherwise a non-empty `proxyUser` → that user and `proxyPassword` (empty
   when null).
3. Otherwise no login.

A direct route never carries a login, including a direct site behind the
network's own (Wi-Fi) proxy.

### 2.2 SOCKS5, by hand

Every SOCKS route goes through a new `Socks5Tunnel` (RFC 1928, with RFC 1929
username/password), replacing the platform's SOCKS. One code path, logged in
or not:

- Greeting offers exactly one method: `0x02` with a login, `0x00` without.
  A reply of `0xFF` (no acceptable method) is a **rejected login**: the proxy
  wanted a login we do not have, or will not take the one we have.
- RFC 1929 sub-negotiation: a non-zero status is a **rejected login**. A user
  that is empty or longer than 255 UTF-8 bytes, or a password longer than 255
  bytes, cannot be sent and is a rejected login too.
- CONNECT with address type 3 (domain name) and the target as given, brackets
  stripped from an IPv6 literal. This is what the platform sent for an
  unresolved address, so the proxy still does every lookup.
- A non-zero reply code is `ProxyTunnelException(code)`, which already maps to
  `PROXY_REFUSED`. The bound address is read and discarded on success.
- 15 s connect and handshake timeouts, as `HttpConnectTunnel`.

### 2.3 The derived login

`perSiteLogin(profileId)`: SHA-256 of `"container-proxy-login:" + profileId`
(UTF-8). The username is the first 16 bytes as 32 lowercase hex digits, the
password the last 16. Stable for a `profileId`, unrelated across
`profileId`s, and reveals nothing about the `profileId` to the proxy. It
applies to SOCKS5 and HTTP alike.

### 2.4 HTTP CONNECT

`HttpConnectTunnel.open` takes an optional login and, with one, sends
`Proxy-Authorization: Basic base64(user ":" password)` (UTF-8). A `407` reply
is a **rejected login**, sent or not. Every other non-2xx stays
`ProxyTunnelException`.

### 2.5 Credentials never leak

The login type's `toString` is redacted; `SiteConfig` holds the typed login
in that type, so a logged config prints no password. No exception message
names a credential. Nothing new logs a host.

## 3. Failures

A rejected login is `ProxyLoginRejectedException` in Kotlin and
`RouteFailure.PROXY_LOGIN_REJECTED` / Dart `RouteFailure.proxyLoginRejected`,
copy "The proxy rejected the login".

- **Page loads.** A rejected login is a fault of the route, not of one
  destination, so the loopback proxy reports it through the binding's
  `onRefused` (as it does a refused route) before answering `502`. Only for a
  `Route.Proxy`. Other upstream failures stay unreported (P2 plan deviation 1).
- **A refusal reported while the session is still opening refuses the
  session** with that failure, so `8b` shows it ("The proxy rejected the
  login" headline, the generic "did not complete the connection" sentence).
  Today such a report is dropped, and the first load ends on WebView's own
  error page. A refusal on a live session stays `tunnel_dropped` (`8c`), as
  today; on a backgrounded or refused session it is ignored, as today.
- **Downloads.** `DownloadFetcher` maps the exception to the new failure, so
  the outcome line reads "The proxy rejected the login".
- `ProxyProbe` is unchanged: it checks that something listens, never a login.

## 4. Copies of a site

- **Throwaways** inherit the route of the container they were typed in, so
  they inherit its typed login and its per-site toggle; with the toggle on,
  the throwaway's own `profileId` gives it its own login.
- **Decoy re-sync** copies the three fields (`copyWith`), and with the toggle
  on the decoy copy's own `profileId` gives it a login distinct from the real
  vault's.
- **Saving a throwaway** pre-fills the form with what it inherited.

## 5. Testing

- Kotlin JVM: `Socks5Tunnel` against a fake SOCKS5 server (method choice,
  RFC 1929 bytes, rejection, `0xFF`, reply codes, address type 3, payload
  after the handshake); `HttpConnectTunnel`'s header and `407`; `Router`'s
  login choice and per-site derivation; the loopback proxy reporting a
  rejected login (and not reporting other failures); the download mapping;
  the opening-session refusal decision; the failure's Dart name.
- Dart: round trip and v6→v7 upgrade; the channel map; failure decoding and
  copy; throwaway and decoy inheritance; the form.
- Device: the harness proxy gains an optional login requirement; a manual run
  sheet is added. Device checks are not part of this work's gates.

## Rulings (decided without asking)

1. Every SOCKS route uses the hand-written client, not only logged-in ones.
2. The SOCKS target is always address type 3, as the platform sent it.
3. Exactly one method is offered; `0xFF` is a rejected login.
4. Any `407` is a rejected login, even when none was sent.
5. A rejected login is reported route-wide, for a `Route.Proxy` only.
6. Any refusal reported while a session is opening refuses it (not only a
   rejected login).
7. The automatic login applies to HTTP proxies as well as SOCKS5.
8. Username and password are saved only while the proxy is on, the per-site
   toggle is off and the username is non-empty; otherwise both are null. The
   password is stored exactly as typed.
9. Each field takes at most 255 characters; a login longer than 255 UTF-8
   bytes is a rejected login on SOCKS5.
10. A colon in an HTTP username is not refused (RFC 7617 forbids it; the
    proxy will reject it).
11. No login check at open; `ProxyProbe` stays a TCP check.
12. The login block sits under HOST/PORT in this order: toggle, then the two
    fields.

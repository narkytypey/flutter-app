# Loopback authenticating proxy (P2) — design

**Date:** 2026-09-30
**Status:** Designed section by section with the user on 2026-09-30, and each
section approved. This written spec is waiting for the user's review.
**Evidence:** `2026-09-30-p2-loopback-proxy-findings.md` (the spike, by
session flutter-app-85, on WebView 154 on the Android 16 emulator). Every
claim below about how Chromium behaves comes from that document. Where the
spike did not test something, this spec says so.

## 0. Why

The proxy leak fixes (`docs/superpowers/plans/2026-09-30-proxy-leak-fixes.md`,
merged at `f6ec1b3`) closed four of the five ways a proxied site's traffic
left the device directly. The fifth, `<link rel=preconnect>`, cannot be
closed from the interceptor. Chromium opens a preconnect's socket itself,
without calling `shouldInterceptRequest`. A hostile page can always make
one.

The interceptor has a second problem. On a proxied site today the app's
`ProxyHttpClient` does all the HTTP work, and it cannot do what Chromium
does:

- it stores no cookies and sends none;
- it follows no redirects;
- it sends no request bodies;
- it hands WebView responses that WebView partly ignores.

So a login on a proxied site cannot be kept, `https://httpbin.org/cookies/set`
fails with `net::ERR_HTTP_RESPONSE_CODE_FAILURE`, and forms that POST do not
work.

P2 moves the HTTP work back to Chromium, and moves the per-site routing
underneath it, into a proxy inside the app.

### Decisions the user made (2026-09-30)

| Question | Decision |
|---|---|
| Scope | **Page loads.** Every site's page traffic goes through the loopback proxy, with Chromium doing the HTTP. `ProxyHttpClient` stays, for downloads only. |
| dns-prefetch | Inject a `x-dns-prefetch-control: off` meta tag at document start, verify it on a device, and accept a known gap if it does not work. **Verified on 2026-09-30: it does not work** (findings, "dns-prefetch control"). No script is injected, and the gap is recorded (§6). |
| A WebView without proxy override | **Proxied sites are refused**, never sent direct. Direct sites open as they do today. |
| Wording for that refusal | Headline `This phone cannot route sites through a proxy`, detail `Update Android System WebView to open proxied sites.` Approved as new copy; this spec is its source. |
| Approach | **A: a loopback proxy that tells sites apart by the credentials each site's WebView answers with.** A per-site switch of the process-wide override (B) cannot work while several sites are open. A `VpnService` (C) routes per app, not per site, and would take the user's VPN slot. |

## 1. Architecture

Two new Kotlin units, both started in `MainActivity` before any page can
load, in the same place as today's `blockAutofillQueries()`, which P2
replaces.

### 1.1 `LoopbackProxy`

- Listens on `127.0.0.1` only, never on any other interface, on an
  ephemeral port the OS chooses. The port changes on every start.
- Accepts two request shapes:
  - `CONNECT host:port`, which Chromium sends for every `https` request, and
    for preconnects;
  - absolute-form requests (`GET http://host/path HTTP/1.1`), for `http`
    sites.
- Authenticates every request with `Proxy-Authorization: Basic`, before
  anything is forwarded (§2):
  - no credentials: `407 Proxy Authentication Required` with the app's realm.
    Nothing is forwarded.
  - wrong or expired credentials: `403`, and the connection is closed. Never
    a second `407`. The spike never rejected an answer, so Chromium's
    behaviour on a re-challenge is unknown, and a loop is possible. The plan
    tests this first (§7).
  - `CONNECT content-autofill.googleapis.com:*`, or an absolute-form request
    to that host: `403` whatever the credentials. This replaces
    `AutofillBlock.kt`. There is one override per process and the last call
    wins, so its reverse-bypass rule cannot coexist with P2's.
- For valid credentials it finds the site (`SiteConfig`) they belong to and
  resolves its route with the existing `Router`, proxy probe included. The
  probe runs on the proxy's worker threads, never on the main thread
  (`a42896d`).
  - `Route.Direct`: a socket to `host:port`. The proxy does the DNS lookup,
    as the device does today for a direct site.
  - `Route.Proxy`: `Router.connect`. SOCKS5 gets an unresolved target, so
    the hostname goes to the proxy (`5b00193`). HTTP proxies go through
    `HttpConnectTunnel`.
  - `Route.Refused`: `502`, and the site's failure is reported (§3.3).
- After a successful `CONNECT` it replies `200 Connection Established` and
  relays bytes both ways until either side closes. TLS runs end to end
  between Chromium and the destination. The proxy never sees inside it, and
  certificate checks are Chromium's own.
- For absolute-form `http` requests (§3.2) it rewrites the request line to
  origin form, forces `Connection: close`, forwards the request, relays the
  response, and closes. One request per connection keeps requests to
  different hosts from ever sharing a connection.

### 1.2 `SiteCredentials`

The table of which credentials belong to which site (§2).

### 1.3 The process-wide override

`ProxyController.setProxyOverride` is set once at start:

- a single proxy rule `http://127.0.0.1:<port>` for every scheme;
- `removeImplicitRules()`, so `localhost` and loopback addresses go through
  it too;
- no `DIRECT` rule, so if the loopback proxy is down every request fails.
  Nothing falls back to direct.

### 1.4 Changes to existing code

- **Auth prompts.** Each view's `WebViewClient` overrides
  `onReceivedHttpAuthRequest`.
  - When `host` is the loopback proxy's and the realm is the app's, it calls
    `handler.proceed(user, password)` at once with its profile's
    credentials, read from memory. **Every call is answered.** The spike saw
    five parallel requests make five separate calls, and an unanswered call
    leaves its request waiting.
  - Any other prompt (a site's own HTTP auth) keeps today's behaviour. The
    tree overrides nothing today, so WebView's default cancels it.
- **`RequestInterceptor.intercept`** keeps two jobs:
  - the closing-view gate (`Disposition.Closed`, `8c82e90`);
  - filter-list blocks (`Disposition.Blocked`).

  Otherwise it returns `null`, so Chromium fetches through the loopback
  proxy. `Disposition.Through` and the page-load use of `fetchThrough` are
  removed, and so is `Disposition.Refused`: route refusal moves to the
  proxy.
- **Service workers.** The per-profile client (`routeServiceWorkers`) keeps
  the same two jobs, and the default profile still refuses everything.
- **`ProxyHttpClient`, `ChunkedBody` and `DownloadFetcher`** stay unchanged,
  for downloads only. A proxied site's downloads now get the site's real
  cookies, because Chromium now stores them in the site's profile.
- **`DeclaredLengths` and the proxied branch of `heldDownloadSize`** are
  removed. Chromium now fetches proxied pages itself, so `DownloadListener`'s
  `contentLength` means the same on every route as it does on a direct one
  today. `heldDownloadSize` keeps only its direct rule: above 0 is a length,
  0 is unknown.
- **Without `PROXY_OVERRIDE`.** The feature check happens once at start.
  - Direct sites: nothing is overridden, and they load as they do today.
  - Proxied sites: refused at open with `RouteFailure.UNSUPPORTED` (§3.3).
  - Autofill: cannot be blocked without an override. As today, this is
    logged, not hidden.

## 2. Credentials and security

**The threat.** Any app on the device can connect to a loopback port.
Without credentials the loopback proxy would be an open relay into the
user's SOCKS5 or HTTP proxy, and a way to make connections that look like the
user's.

- **One credential per profile:** 128 bits from `SecureRandom`, as a user and
  password pair, created the first time that profile is opened in this
  process. It is held in memory, keyed by profile id.
  - It never crosses the channel to Dart.
  - It is never written to disk and never logged.
- **Fixed for the process.** Chromium caches a profile's proxy credentials in
  memory, and neither a lock nor a wipe clears that cache (findings, "Is the
  auth cache cleared"). So a profile's credential cannot rotate within a run.
  A wiped saved site gets a fresh profile id, and so a fresh credential: every
  explicit close-and-wipe rotates the profile id (branch `fix-site-wipe`,
  user's ruling, 2026-09-30).
- **Valid only while its site has an open session.** The table maps a
  credential to its session's current `SiteConfig` and the session's
  `onRefused` reporter (so the proxy can report the failures in §3.3). A
  closed session is removed from it. After a lock (every session closed) or a closed
  throwaway, Chromium keeps sending the old credential. The proxy answers
  `403`.
- **Compared in constant time** (`MessageDigest.isEqual`), so response
  timing cannot reveal a credential.
- **Panic.** Its first step closes every session, so from then on the
  loopback proxy refuses everything. The proxy keeps running, so the app
  works again after the next setup.
- **Two vaults.** The proxy never asks which vault is open. Credentials
  belong to profiles, and each vault's sites have their own profiles.
- **Out of scope:** code running inside the app's process, and root on the
  device. The threat model is coerced unlock (`CLAUDE.md`).

## 3. Data flow and errors

### 3.1 An https request

1. The page asks for `https://x.com/a.js`.
2. `shouldInterceptRequest` refuses it only for a closing view or a filter
   match. Otherwise it returns `null`.
3. Chromium sends `CONNECT x.com:443` to the loopback proxy with the
   profile's credentials. On the profile's first request there are none: the
   proxy answers `407`, `onReceivedHttpAuthRequest` answers from memory, and
   Chromium retries with them and sends them unprompted from then on.
4. The proxy resolves the site's route, connects, answers `200`, and relays.

### 3.2 An http site

Chromium sends an absolute-form request with the credentials. The proxy
connects to the host over the site's route, rewrites the request line, sets
`Connection: close`, relays the response, and closes.

### 3.3 Failures

The existing `RouteFailure` kinds and their copy are unchanged, and one kind
is added.

| What happens | Reported as | Where |
|---|---|---|
| The site's route is refused (proxy unreachable, misconfigured) | the route's own failure | the loopback proxy answers `502` and calls the site's `onRefused`, which shows `8b` as today |
| The upstream proxy refuses the destination (`ProxyTunnelException`, SOCKS failure) | `PROXY_REFUSED` | loopback proxy, `502` |
| The upstream connection times out | `UPSTREAM_TIMEOUT` | loopback proxy, `504` |
| TLS fails | `TLS_FAILURE` | **Chromium now does TLS**, so the view's `onReceivedError` for the **main frame** maps Chromium's SSL-class error codes to it |
| The WebView has no proxy override and the site is proxied | new `UNSUPPORTED` | at open, before any view is built |

- A subresource's failure never takes over the screen. Only a main-frame
  failure or a route refusal does, as today.
- `UNSUPPORTED`'s copy:
  - headline `This phone cannot route sites through a proxy`;
  - detail `Update Android System WebView to open proxied sites.`

  It crosses the channel as `unsupported`, and the Dart side adds it to
  `RouteFailure`, `refusalMessage` and `proxyFailureDetail`.
- **Unchanged:** the probe on open, `EngineChannel`'s events, and the Dart
  side apart from the one new failure kind.

## 4. What P2 closes

Checked against the findings:

- **Preconnect (a1) is closed, even against a hostile page.** An
  unauthenticated preconnect `CONNECT` gets a `407` that no callback
  answers, and Chromium gives up. An authenticated one carries the site's
  credentials, and the proxy routes it by site. The target is never looked
  up on the device.
- **Service-worker fetches and keepalive/beacon traffic** go to the loopback
  proxy with the site's credentials. The closing-view gate stays, so nothing
  from a closing page reaches even the proxy.
- **The Autofill query** is refused by host at the loopback proxy.
- **Proxied sites keep cookies, follow redirects, and send POST bodies**,
  because Chromium does the HTTP.

## 5. Units

| Unit | Does | Depends on |
|---|---|---|
| `LoopbackProxy` | listens, authenticates, routes, relays | `SiteCredentials`, `Router`, `HttpConnectTunnel` |
| `SiteCredentials` | credential per profile; credential → open session's `SiteConfig`; constant-time lookup | nothing Android |
| `loopbackProxyConfig(port)` | builds the override `ProxyConfig` | `androidx.webkit` |
| `ProxyAuth` (in the view's client) | answers the loopback proxy's `407` from `SiteCredentials` | `SiteCredentials` |
| `mainFrameFailure(errorCode)` | maps a WebView error code to `TLS_FAILURE` or none | nothing Android |

`LoopbackProxy`'s request parsing and routing decisions should be pure
functions over byte streams, so the JVM tests reach them without Android, as
`dispositionFor` and `Teardown` already do.

## 6. Known gaps (recorded, not fixed)

- **dns-prefetch still leaks** (a2): `<link rel=dns-prefetch>` makes the
  device look up the hostname, on proxied sites too.
  `NetworkContext::ResolveHost` ignores proxy configuration. WebView 154
  ignores the document's prefetch control (the meta tag and the response
  header both failed on the device). Blink checks only a frame setting that
  WebView does not expose. It is a lookup only: no connection is made.
- **A profile's first request decides what can go before it.** Until the
  profile has answered one `407`, its service-worker fetches and preconnects
  fail closed. In practice the main frame always comes first.
- **WebRTC** is UDP and never passes through any proxy. The existing "Block
  WebRTC" shield governs it, as today.
- **Downloads still use `ProxyHttpClient`.** They now carry the profile's
  cookies, but still follow no redirects.
- **No authentication to the user's own upstream proxy**, unchanged from
  Plan 10.
- **Not verified:**
  - WebView versions other than 154, and a physical phone;
  - HTTP/2 or QUIC to the loopback proxy (the spike saw HTTP/1.1);
  - non-Basic schemes;
  - whether the per-profile auth cache survives a renderer crash (it lives in
    the browser process, so it should).
- **Wipe-on-exit's automatic wipe does not rotate the profile id** (a ruling
  on `fix-site-wipe`). A profile reused in the same run can keep its
  HSTS/alt-svc network state and history until the next start.

## 7. Testing

**JVM (Kotlin), against fake upstream servers on localhost:**

- no credentials: `407`, and nothing reaches the upstream;
- a wrong credential: `403` and the connection is closed; a closed session's
  credential: `403`;
- the Autofill host: `403` with valid credentials;
- the right route per credential:
  - direct;
  - SOCKS5, receiving address type 3 and the hostname;
  - HTTP CONNECT;
- a refused route: `502`, with `onRefused` called with the route's failure;
  a CONNECT refused upstream: `PROXY_REFUSED`; a timeout: `UPSTREAM_TIMEOUT`;
- absolute-form `http`: request line rewritten, `Connection: close`, response
  relayed;
- CONNECT: `200` then bytes relayed both ways, and a close on either side
  ends both;
- the listener's bound address is `127.0.0.1`;
- credentials:
  - 128 bits, one per profile, distinct across profiles;
  - the same for a profile within a run;
  - compared with `MessageDigest.isEqual`;
- the override config: every scheme to `127.0.0.1:<port>`, implicit rules
  removed, no `DIRECT`;
- `mainFrameFailure`'s mapping, and `heldDownloadSize`'s direct-only rule.

**Dart:** `unsupported` decodes, and its headline and detail show in `8b`
and the refusal screens, verbatim.

**Gates:**

- `flutter analyze`;
- `flutter test`;
- the Kotlin JVM tests, with counts read from the JUnit XML;
- `flutter build apk --debug`, with zero `e:` lines.

**Early device check (first task that has a running proxy):** reject a
credential with `403` and watch for a re-challenge loop.

**Device, on the emulator,** with a logging DNS forwarder (`-dns-server`),
`ss -tnpe`, and a local SOCKS5/CONNECT proxy:

- a proxied site's page, preconnect, service worker and beacon make zero
  direct sockets from the app's uid;
- the SOCKS5 proxy receives hostnames;
- a login survives a reopen on SOCKS5 (`httpbin.org/cookies/set?p2=1`,
  then `/cookies`);
- a redirect and a form POST work on SOCKS5;
- `adb shell` connecting to the loopback port gets `407`, or `403` with a
  made-up credential, and nothing is forwarded;
- no Autofill connection anywhere;
- after a lock, the old credential gets `403`;
- panic shows `3c` and deletes the stores;
- direct sites still work;
- the only device lookup left is dns-prefetch.

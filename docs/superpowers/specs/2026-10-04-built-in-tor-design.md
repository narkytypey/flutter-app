# Built-in Tor

**Status:** design approved section by section by the user on 2026-10-04, in
conversation; this document is for their review. Every new string in §7 was
approved word for word. It amends one global constraint (§2, ruling 1).

## 1. Why

For a public release, a user should be able to send a site through a proxy
without finding one or installing anything else. Until now every proxy is
brought by the user (SOCKS5 or HTTP, typed into `2a`'s Network tab). This
design embeds a Tor client in the app, as a third proxy mode beside SOCKS5 and
HTTP. Direct stays the default; Tor is opt-in per site and as the default
route.

Success: on a fresh install, a site set to Tor loads through the Tor network
with nothing else installed, and a site whose Tor cannot connect is refused,
never sent direct.

## 2. The user's rulings (2026-10-04)

1. **Global constraint amended.** "No network requests of the app's own"
   becomes: *No network requests of the app's own, except connecting to the
   Tor network when the user has chosen Tor.* Tor runs only while something
   needs it (§4.2); with nothing on Tor the app stays silent.
2. **Plain Tor only.** No bridges or pluggable transports in this design.
   Where Tor is blocked, Tor sites are refused (`8b`). Bridges are a later
   project.
3. **Onion addresses never go direct.** On a proxy route an onion address goes
   to that proxy by name, like every hostname; typed on a Direct route it opens
   as a throwaway on built-in Tor (§5.3).
4. **Guardian Project's `tor-android`**, in process, not Arti and not a
   separate executable.
5. **Tor's SOCKS port is a Unix socket** in the app's private directory, not a
   TCP port on localhost (§4.4).

## 3. Scope

In: the Tor runtime and its lifecycle, `ProxyMode.tor` through Dart, storage
and Kotlin, the onion rules, the form and `8a`/`8b` copy, Block WebRTC forced
on for Tor, panic deleting Tor's state.

Out: bridges; a Tor status screen or Settings section; onion services hosted
by the app; any change to SOCKS5 or HTTP routes beyond the onion refusal on
Direct (§5.3); New identity changing a typed proxy login (unchanged).

## 4. The Tor runtime

### 4.1 One owner

`TorRuntime` (Kotlin, new, in `engine/`) is the only code that touches
`tor-android`. Its states: **off**, **starting** (with Tor's bootstrap
percentage), **ready**, **failed**. Tor's configuration:

- `SocksPort unix:<filesDir>/tor/socks` with `IsolateSOCKSAuth` (Tor's
  default for SOCKS logins, set explicitly);
- no TCP control port, no other listening ports;
- `DataDirectory <filesDir>/tor`.

### 4.2 When it runs (ruling 1)

- **Starts** when a container on the Tor route opens, including an onion
  throwaway opened from Direct (§5.3).
- **Stops** when the last container on the Tor route closes, at every lock,
  at panic, and when the Flutter engine detaches (`EngineChannel.detach`, the
  hook that already closes every container).
- Nothing else starts it: not the Default route being Tor, not an onion link
  on a page (§5.3).

### 4.3 Waiting and failing

Every container that needs Tor while it is starting waits on the same start.
Closing a container while it waits cancels only its own wait. The open's
checklist (`8a`) shows Tor's progress (§7).

**Tor is failed** when it reports an error, or when its bootstrap percentage
has not moved for **2 minutes**. Every container waiting on it is then
refused with `8b` (§7). "Try again" starts Tor again. A Tor that fails or is
still starting never leads to a direct connection.

If Tor stops while a Tor container is live (an error after `ready`), that
container shows `8c` (tunnel dropped), as any proxy route does.

### 4.4 The engine's connection

`Router.connect` gets a `Route.Tor` case: it opens an Android `LocalSocket` to
`<filesDir>/tor/socks` and speaks SOCKS5 over it through the existing
`Socks5Tunnel`, sending the site's per-site login (§5.2).

**Risk the plan proves first.** The engine passes `java.net.Socket` around:
`LoopbackProxy` pipes it, and `ProxyHttpClient.startTls` layers an
`SSLSocket` on it for downloads. A `LocalSocket` is not a `java.net.Socket`.
The plan's first task is a spike: a wrapper that lets both paths use the
`LocalSocket`, with TLS over it checked on the emulator. **Fallback** if the
wrapper cannot be made to work: Tor listens on a random `127.0.0.1` TCP port
and requires a random SOCKS password set at each start; the spec's Known gaps
then record that another app on the phone can see the port exists.

### 4.5 Tor's data directory

One directory, `filesDir/tor`, kept between runs: the cached network
consensus and the chosen guard relays. Keeping guards is Tor's own advice
(fresh guards at every start widen exposure to a hostile first hop), and
starts are faster. It is shared by both vaults; it is shown nowhere in the
app, and the threat model is coerced unlock, not disk imaging.

**Panic** stops Tor and deletes `filesDir/tor` among its container steps,
before the key steps, in `ContainerPanicService.trigger`'s existing
best-effort order.

## 5. The Tor route

### 5.1 The mode

`ProxyMode.tor` joins `direct`, `socks5`, `http` in Dart and in Kotlin's
`SiteConfig`. Kotlin's `Router.resolve` admits `tor` **by name**, so an
unrecognised mode is still `MISCONFIGURED`. It is stored in the existing
`proxy_mode` column (no schema change) and in `app_settings.default_route`'s
`mode`. A Tor route has no host, port or typed login: `ProxyRoute.fromForm`
drops them, and `ProxyRoute.label` reads `Tor`.

### 5.2 Circuits

A Tor route always sends a login derived from the site's `profileId` (what
"Separate login per site" does on other routes), so each site has its own
circuit. On Tor this is not a switch. Wiping a site rotates its `profileId`,
so it gets a new circuit; so does New identity. A throwaway's login comes from
its own in-memory profile.

### 5.3 Onion addresses (ruling 3)

- **Typed** into the address pill or the dashboard's search field:
  - on a Tor, SOCKS5 or HTTP route, it opens as that route would open any
    host (the host goes to the proxy by name);
  - on a Direct route, it opens as a **throwaway on Tor**, whatever the
    opener's route. This is an exception to "a throwaway opens on its
    opener's route". Its suggestion row reads `THROWAWAY · TOR` (the existing
    label code).
- **A link** to an onion host from a page on a Direct route is refused inside
  `LoopbackProxy` before any DNS lookup or system proxy (`403`, like the
  `127.0.0.1` refusal). It does not start Tor. The page shows WebView's own
  error. Today such a link could send the onion name to DNS; this closes that.
- **A saved site** whose address is an onion host cannot be saved on Direct:
  the form switches its route to Tor (proxy switch on, Tor chip selected).

### 5.4 WebRTC

On a Tor route Block WebRTC is always on: WebRTC can send UDP outside Tor and
reveal the real IP. Dart sends it on whatever the stored value is; `6c` and
the form show the switch on and inert (40% opacity, the existing inert
`AppToggle`).

### 5.5 Decoy vault

Decoy re-sync copies the mode like any other site field. Both vaults can use
Tor, and their Settings are identical.

### 5.6 `8b`'s "Open without the tunnel"

Stays for a Tor site: it is an explicit choice with its own warning, as on any
proxy. **Hidden when the address is an onion host**, which cannot go direct
and would leak its name.

## 6. Forms

`RouteFields` (shared by `2a`'s Network tab and the Default route screen):
with the proxy switch on, a third chip **`Tor`** beside `SOCKS5` and `HTTP`.
With Tor selected, the host, port and login fields are hidden and one line is
shown in their place (§7).

## 7. Copy

All new; approved word for word on 2026-10-04.

| Where | Copy |
|---|---|
| Mode chip, beside `SOCKS5` and `HTTP` | `Tor` |
| Under the chips, Tor selected | `Through the Tor network. Each site gets its own circuit.` |
| Route label (container, `2c`, Default route row) | `Tor` |
| `8a` step, in place of `Connecting through host:port` | `Connecting to Tor`; while starting, `Connecting to Tor · 45%` (Tor's own percentage) |
| `8b` headline, Tor failed | `Tor did not connect` |
| `8b` sentence | `<Site> is set to go through Tor, which could not reach the Tor network. The page was not loaded, so no request left your device.` |
| `8b` Tunnel row | `Tor` |

Reused unchanged: `8b`'s buttons, `8c`, `THROWAWAY · TOR` (from
`'THROWAWAY · ${mode.name.toUpperCase()}'`). No new Settings rows, no new
jade.

## 8. Testing

- **Kotlin JVM:** `TorRuntime`'s states over a fake Tor (start, shared waits,
  a cancelled wait, an error, a 2-minute stall, stop when the last Tor
  container closes, stop at lock, panic deleting the directory);
  `Router.resolve` admitting `tor` by name; `LoopbackProxy` refusing an onion
  host on Direct with no lookup.
- **Dart:** `ProxyMode.tor` through `ProxyRoute.fromForm`, `label` and the
  stored default route; `destinationFor`'s onion rules; the form switching an
  onion address to Tor; Block WebRTC forced on; `openStepsFor`; `8b`'s copy
  and its hidden button; the chip and the line under it.
- **Gates:** `flutter analyze` clean; `flutter test`; Kotlin JVM counts read
  from the JUnit XML; `flutter build apk --debug` with zero `e:` lines. Record
  the APK's size before and after.

## 9. Device checks

On the emulator against the real Tor network, with `tool/device-check/`'s DNS
and socket logs:

1. A fresh start makes no Tor connection until a Tor site opens.
2. `check.torproject.org` on a Tor site says it is using Tor.
3. Two Tor sites show different exit IPs; New identity changes one site's.
4. A typed onion address on Direct opens as `THROWAWAY · TOR`; an onion link
   on a Direct page is refused with no DNS lookup.
5. Tor listens on the Unix socket only, no TCP port.
6. A lock stops Tor; no Tor connections remain.
7. Panic deletes `filesDir/tor`.
8. With the network cut, `8b` shows `Tor did not connect` after the 2-minute
   stall.

Plus the §4.4 spike: TLS over the wrapped `LocalSocket` on the emulator.

## 10. Known gaps

- **This is not Tor Browser.** WebView has its own fingerprint, so sites can
  link a phone's Tor visits more easily than Tor Browser's. No copy says
  "anonymous".
- **dns-prefetch (accepted leak a2) is worse on Tor.** A Tor page's
  `<link rel=dns-prefetch>` hints still resolve on the phone's own DNS, so the
  local network can see hostnames the page referenced. No WebView setting
  turns it off. The plan tries removing those hints with a document-start
  script on Tor routes and records how much it reduces; it does not claim to
  close the gap.
- **No bridges** (ruling 2): Tor sites do not work where Tor is blocked.
- **One Tor data directory for both vaults** (§4.5).
- **"Open without the tunnel" stays on Tor sites** (§5.6).
- **Tor adds native code to the APK** (several MB per ABI); the plan records
  the size.

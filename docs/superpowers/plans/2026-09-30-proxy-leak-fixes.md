# Proxy leak fixes

Branch `fix-proxy-leaks`, off `main` at `fef94c0`, 2026-09-30, session flutter-app-85. This is a fix record, not a forward plan: the work was investigated, sent to the coordinating session (flutter-app-77) for a design check, approved with the user's rulings, and executed test-first, one commit per fix. It has **no design spec**. The rulings below stand in for one.

## Why

Plan 12's device checks (2026-09-30) found traffic leaving a proxied site outside its proxy: a direct socket to `links.duckduckgo.com`, a direct IPv6 connection to Google, and every proxied hostname resolved on the device. CLAUDE.md's "Device verification" records them as issues (a)–(c). The user chose to fix them next.

## How the leaks were found

- The emulator ran with `-dns-server` pointed at a logging DNS forwarder on the host (a Python script forwarding to the host's resolver), so every name the device looked up was logged.
- `ss -tunpe` was sampled every 0.2 s for the app's uid, and a local Python proxy logged every SOCKS5 and CONNECT request with its target.
- Each profile's `Network Persistent State` is Chromium's own record of the servers it exchanged HTTP with, outside any interception.
- Probe pages served over https through `httpbin.org/base64/…` isolated each mechanism. DuckDuckGo and squoosh.app were the real-world cases.
- Chromium's source (googlesource, main) settled what WebView does and what, if anything, turns it off. The WebView on the emulator is 154.0.8037.57.
- WebView's own NetLog could not be taken off the device: its only share targets were Quick Share, Drive, Gmail and Chat.

## Root causes

- **(c) DNS on the device.** `Router.connect` handed the platform a resolved `InetSocketAddress` for the SOCKS target. Android's `SocksSocketImpl` sends the hostname (`DOMAIN_NAME`) only for an unresolved one, so the device looked every proxied host up first. The HTTP CONNECT tunnel already sent the hostname.
- **(a) is four bypasses, not one.** Each was seen as a direct socket from the app's uid.
  - **a1 `<link rel=preconnect>`.** Blink → `network_hints` → `NetworkContext::PreconnectSockets`. It checks nothing but the scheme, has no WebView setting, and `shouldInterceptRequest` never sees it.
  - **a2 `<link rel=dns-prefetch>`.** A DNS query only, made by `NetworkContext::ResolveHost`, which ignores any proxy configuration.
  - **a3 Requests that outlive the view.** `ContainerView.dispose` called `destroy()` at once. The page's pagehide and unload handlers then ran after the view's interception hook was gone, and their keepalive requests (a `sendBeacon`, a keepalive `fetch`) went out through Chromium's own network stack. The same page navigated away inside a live view sent the same two requests through the proxy.
  - **a4 Service workers.** `ServiceWorkerControllerCompat.getInstance()` is the *default* profile's controller. Every site runs in its own profile with its own controller (`Profile.getServiceWorkerController()`), which was never set, so no site's service worker was intercepted.
- **(b) Chromium Autofill server predictions** (`content-autofill.googleapis.com`, in the `2001:4860:484x:400::` range seen). WebView always creates an `AndroidAutofillClient`, and `AutofillManager::ParseFormsAsync` queries the server for every form the renderer reports. The query comes from the browser process, so no interceptor sees it, and no `AwSettings` or manifest switch turns it off. A form's signature hashes its site and field names, so each query tells Google the page, from the device's own address. It is not Safe Browsing (already off), variations or component updates: those run in the WebView provider's process.

Two further pre-existing bugs turned up along the way:

- **(f)** `ProxyHttpClient` never decoded `Transfer-Encoding: chunked`, so example.org over SOCKS5 showed its chunk sizes (`2c9`, `0`) as page text.
- **(g)** `RequestInterceptor` looked `Content-Type` up case-sensitively, so a server sending `Content-type` had its page held as a download.

## The user's rulings (2026-09-30, relayed by flutter-app-77)

- (a3): a closing view **refuses** every request. Nothing is routed and nothing goes direct.
- (c): **accept** that a SOCKS4-only proxy stops working, since the mode is SOCKS5.
- (b): **block** it with the reverse-bypass proxy override to `127.0.0.1:1`. Routing is not possible, because a browser-initiated request belongs to no site.
- (f) and (g): fix both on this branch.
- a1/a2: not on this branch. **The loopback authenticating proxy ("P2") is the next project** (see Handoff).

## Fixes

| Commit | Fix | Tests |
|---|---|---|
| `5b00193` | (c) `InetSocketAddress.createUnresolved` for the SOCKS target | `RouterTest`: a fake SOCKS5 server receives address type 3 and `localhost:443`. It is `localhost` because a name that fails to resolve silently becomes unresolved and would hide the bug. |
| `9b8f704` | (g) response headers in a case-insensitive map; `mediaTypeOf` matches the `charset` parameter's name without regard to case and unquotes its value | `ProxyHttpClientTest` (1), `RequestInterceptorMediaTypeTest` (4) |
| `13c9a27` | (f) `ChunkedBody` decodes the framing, ignoring extensions and consuming trailers; a body cut off mid-chunk throws. `Content-Length` is dropped whenever `Transfer-Encoding` is sent (RFC 9112 §6.3), and `Transfer-Encoding` is kept, so `declaredLength` still reads no length. | `ChunkedBodyTest` (8), `ProxyHttpClientTest` (1) |
| `0aeeddc` | (a4) `routeServiceWorkers` puts the site's client on the site's own profile and a refuse-everything client on the default profile | `ServiceWorkerRoutingTest` (2) |
| `8c82e90` | (a3) `dispose` marks the view closing (its `WebViewClient` then refuses everything, via `dispositionFor`), loads `about:blank`, and destroys once that has finished or after 1 s (`Teardown`). The flag belongs to the view, not the interceptor, because a session outlives its views. | `DispositionTest` (6), `TeardownTest` (4) |
| `198cdda` | (b) `blockAutofillQueries` at start: `ProxyController` with reverse bypass sends only `content-autofill.googleapis.com` to `127.0.0.1:1`, with no implicit rules and no DIRECT rule | `AutofillBlockTest` (3) |

## Verification

On the branch at `198cdda`, clean tree:

- `flutter analyze`: No issues found!
- `flutter test`: 520 passed. No Dart code changed.
- Kotlin JVM tests: 128 tests, 0 failures, 0 errors (JUnit XML; `main` had 98, and this branch adds 30).
- `flutter build apk --debug`: built, zero `e:` lines.

Device checks, emulator (`Pixel_9`, Android 16), with the logging DNS forwarder, `ss` and the proxy log:

- **DuckDuckGo on SOCKS5:** the proxy received `duckduckgo.com:443` (27), `improving.duckduckgo.com:443` (3) and `links.duckduckgo.com:443` (1), all by name, and `duckduckgo.com` was never looked up on the device. The only direct traffic was `links.duckduckgo.com`'s lookup and socket, which is DuckDuckGo's preconnect hint (known gap a1). Leaving the page produced no lookup, no proxy request and no new socket.
- **Pagehide probe:** on load, `httpbin.org` went through the proxy by name, and the page's own preconnect (`www.wikipedia.org`) and dns-prefetch (`www.mozilla.org`) were the only direct traffic (a1, a2). On leaving, nothing: before the fix its beacon (`www.openssl.org`) and keepalive fetch (`www.gentoo.org`) were resolved on the device and sent direct.
- **squoosh.app in a SOCKS5 throwaway:** its service worker registered (`Service Worker/ScriptCache`, `CacheStorage` in the throwaway's profile), and all 34 connections went through the proxy as `squoosh.app:443`, against 14 before, when the worker's own fetches went direct. There was no lookup and no direct socket.
- **Autofill:** no `content-autofill.googleapis.com` lookup or socket on any load, including a form page in a fresh profile.
  - Positive control: the kernel's TCP `AttemptFails` stayed at 0 over 20 s idle, and rose by exactly 5 on that form page's load (and by 5 on a DuckDuckGo load). Chromium's `kAutofillMaxServerAttempts` defaults to 5, so the queries are attempted and refused at `127.0.0.1:1`.
- **example.org on SOCKS5:** renders without the stray `2c9`/`0` text nodes.
- **A page served with Python's `Content-type` over SOCKS5:** renders ("content-type probe"). Before the fix it was held as a download.
- **Panic from inside a site:** `3c` ("Everything closed · 5 sessions destroyed, temporary storage wiped, app locked."), `meta.bin` and `store-1.db` gone, the throwaway journal gone, six profiles journaled, the app still up, and no network traffic. Nothing in panic waits on a view's teardown: `dispose` returns at once, and the view refuses everything until it is destroyed.

**Not verified on a physical phone.**

## Known gaps

- **a1 preconnect and a2 dns-prefetch still leak on proxied sites.** A preconnect opens a DNS lookup and a direct TCP/TLS connection (the device's address, and the host in the TLS SNI), and a dns-prefetch sends a DNS lookup. No WebView setting stops either, and neither passes `shouldInterceptRequest`. Both are the next project's (see Handoff). P2 would close a1. **It would not close a2**, because `ResolveHost` ignores proxies and a loopback proxy cannot see the HTML to strip the hint.
- **The Autofill block is process-wide and host-specific.** A direct site's page cannot reach `content-autofill.googleapis.com` either, which is harmless. On a WebView without `PROXY_OVERRIDE_REVERSE_BYPASS`, the block is skipped and a warning is logged.
- **A closing view lives up to a second longer**, refusing every request meanwhile. A wipe-on-exit site's wipe runs after its destroy, so it runs up to a second later too.
- **A SOCKS4-only proxy no longer works.** SOCKS4 cannot carry a hostname, and the platform's v4 fallback throws `UnknownHostException`, reported as "The destination did not respond".
- **Out of scope and unchanged:** (d) a proxied site keeps no HTTP cookies, redirects are still not followed on a proxied route (Plan 10), and POST bodies still cannot be read from `shouldInterceptRequest`.

## Handoff

- **Next project, P2: a loopback authenticating proxy.** All WebView traffic goes through `ProxyController` to an in-app proxy on loopback. Each WebView answers the proxy's 407 through `onReceivedHttpAuthRequest` with random per-site credentials, which Chromium caches in that site's profile. The proxy then routes each connection by its credentials: direct, SOCKS5 with the hostname, or CONNECT. A request with no WebView and no cached credentials fails closed: `AwHttpAuthHandler` cancels auth when there is no `WebContents` (checked in source). This would close a1, a3, a4 and (b) even against a hostile page, and would give Chromium the HTTP work, fixing (d), redirects and POST bodies with it. Its spec must first **prove two assumptions**:
  1. that the HTTP auth cache is isolated per profile;
  2. that the 407 callback reaches the app for subresource requests.
- `ChunkedBody`, the case-insensitive header map and `mediaTypeOf` (in `ProxyHttpClient.kt` and `RequestInterceptor.kt`) are what the current interceptor path needs, and P2 would retire them along with it.
- `dispositionFor` (in `Teardown.kt`) is now the one place an interceptor decides what happens to a request. Add a new case there, not in `intercept`.

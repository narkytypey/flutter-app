# P2 loopback authenticating proxy — assumption spike findings

2026-09-30, session flutter-app-85, branch `spike-p2-loopback-proxy` off `main` at `f6ec1b3`. This is evidence for the P2 spec, not the spec. The spike's code was disposable and is not committed. What it did is described under "Method" so the runs can be repeated.

## Verdict

Both assumptions hold on WebView 154 (Android 16 emulator), with one refinement to (B) that shapes the design.

- **(A) Isolated per profile: proven.** Credentials one profile gave in answer to a 407 were never sent on another profile's requests, including while that other profile's own requests were going out unauthenticated.
- **(B) The 407 reaches the app for subresources: proven for every request that has a page, and not for requests that have none.**
  - img, script, `fetch`, XHR, `sendBeacon` and main-frame navigations: each 407 reached `onReceivedHttpAuthRequest`, and the request was retried with the answer.
  - Service-worker fetches and preconnects: a 407 never reaches the app, and the request fails closed.
  - **Once a profile has answered, Chromium sends that profile's credentials pre-emptively on every later request to the proxy.** That includes service-worker fetches, preconnects, beacons, main-frame navigations and WebView's own Autofill query. So those are attributable too, as soon as the site has authenticated once.

So P2 is viable as designed, provided the spec accounts for five things (see "What the spec must account for"). The biggest: **dns-prefetch still leaks under P2** (confirmed on the device), and **the loopback proxy must refuse the Autofill host itself**, because the Autofill block's override and P2's override cannot coexist.

## Method

- **App (disposable patch on `main`).** The build did three things:
  - called `ProxyController.setProxyOverride` right after the shipped `blockAutofillQueries()`, with every scheme sent to a host-side proxy at `10.0.2.2:9999` and implicit rules removed, so `*.localhost` went through it too;
  - answered `onReceivedHttpAuthRequest` in each view's `WebViewClient` with `p-<first 8 hex of the site's profile id>` / `spike`, logging each call;
  - allowed cleartext, so plain-HTTP probe pages could show the proxy full request lines.

  A realm of `cancel` made the app call `handler.cancel()`. A realm of `delayN` made it answer after N ms. All test sites were **direct**, so the app's interceptor returned null and Chromium did the fetching through the override, as P2 would.
- **Host proxy (Python).** It handled both CONNECT and absolute-form HTTP, and demanded Basic auth by policy: plain-HTTP paths under `/r/`, and chosen CONNECT hosts (all CONNECTs, for two runs). Every request was logged with the credential's user, or `-` when there was none. Pages under `/p/` passed without auth, so **the first 407 in a fresh profile always came from the subresource under test**.
- **Probe pages** were served at `http://<type><n>.localhost:8000/p/t.html?t=<type>`. Each run used a new host, which the app opens as a throwaway, so each got a **fresh profile** with nothing cached. Each page did one thing: an `<img>`, a `<script>`, a `fetch`, an XHR, a `sendBeacon`, registering a service worker that fetched on activate, or adding a `<link rel=preconnect>`. The `auth*` variants first triggered a 407 with an image, then did the thing four seconds later. `*.localhost` is a secure context, so service workers register over plain HTTP.
- The emulator's DNS went through a logging forwarder on the host (`-dns-server`), so device-side lookups were visible.

## (A) Isolation per profile — proven

Two saved direct sites, SpikeX and SpikeY, each in its own profile.

1. SpikeX loads an image under auth: `407` → callback (`user=p-8f9f47e6`) → retry `user=p-8f9f47e6 -> OK`. Its next request (the favicon) already carries `p-8f9f47e6`: the credentials are now pre-emptive in that profile.
2. SpikeY, opened next, sends its page and favicon with `user=-`, **not X's credentials**. Its image gets its own `407` and its own callback, and it retries with `user=p-4b77d5f1`.
3. Back in SpikeX, with its view rebuilt, every request carries `p-8f9f47e6` pre-emptively, the main frame included, and there is no callback. SpikeY's credentials never appear there.

Twelve more throwaway profiles each answered their own first 407 with their own user, and no profile's user ever appeared on another's request. So the auth cache belongs to the profile's network context, which is what P2 needs to tell sites apart.

## (B) Does the 407 reach the app? — by request type

| Request | Nothing cached in the profile | Profile already authenticated |
|---|---|---|
| main-frame navigation | 407 → callback → retried with creds | creds pre-emptive |
| `<img>` | 407 → callback → retried | pre-emptive |
| `<script>` | 407 → callback → retried | pre-emptive |
| `fetch` | 407 → callback → retried | pre-emptive |
| XHR | 407 → callback → retried | pre-emptive |
| `sendBeacon` (view alive) | 407 → callback → retried | pre-emptive |
| service-worker fetch | **407 → no callback, no retry: fails** | **pre-emptive** (`GET /r/sw user=p-c4ac4896 -> OK`) |
| service-worker script | not challenged in the runs (path was open) | pre-emptive |
| `<link rel=preconnect>` | **`CONNECT www.wikipedia.org:443 user=-` → 407 → no callback, no retry** | **pre-emptive** (`CONNECT www.wikipedia.org:443 user=p-aa9e6b38 -> OK`) |
| WebView Autofill query | not seen unauthenticated | **pre-emptive** (`CONNECT content-autofill.googleapis.com:443 user=p-8054e40e`) |
| HTTPS main frame (CONNECT) | 407 → callback → retried | pre-emptive |

`onReceivedHttpAuthRequest` is called with `host` set to the **proxy's** host (`10.0.2.2`) and the proxy's realm, so the app can tell a proxy challenge from a site's own HTTP auth. The source agrees about the "no callback" rows: `AwHttpAuthHandler::Start` cancels when there is no `WebContents` (a service worker), and `AwContentBrowserClient::CreateLoginDelegate` returns null for requests marked `do_not_prompt_for_login`.

**Keepalive after the view is destroyed** was not re-tested here. Since the fix at `8c82e90`, a closing view refuses every request before it can reach Chromium's network stack. If P2 keeps that gate, nothing from a closing page reaches the proxy. If it drops the gate, such requests carry the profile's cached credentials (as the beacon did), so the proxy would route them by site.

## Answers to the questions

- **What does Chromium do while it waits for an answer? It holds requests; it does not fail them.** Five parallel `fetch`es in a fresh profile each got their own 407, and the app received **five separate callbacks**, not one. The app answered all five after 3 s. All five were held that long, then retried with credentials, and all returned 200. So P2's app side must answer every callback: they are not coalesced. A slow answer delays the page and fails nothing.
- **Does a preconnect send a 407-able request? Yes: a CONNECT.** With nothing cached, it arrives as `CONNECT host:443` with no credentials. A 407 there reaches no one, and Chromium gives up (nothing leaves the device). With the profile authenticated, it carries that profile's credentials. So the proxy **can** tell which site a preconnect belongs to once the site has authenticated, and **must refuse** an unauthenticated CONNECT (reply 407, never forward). Under P2 a preconnect never goes direct: the target was not looked up on the device (`www.kernel.org`, no DNS entry), and it went to the proxy as a CONNECT.
- **What happens to a direct site under a process-wide override? It goes through the loopback proxy, and works.** Every site in this spike was a direct site: pages, subresources, service workers, HTTPS over CONNECT, all through the proxy with the site's credentials. Under P2 the loopback proxy would connect directly for such a site. Chromium sends CONNECT with the hostname, so the proxy does the lookup, as the device does today for a direct site.
- **Does P2's override fight the Autofill override? Yes. There is one override per process, and the last call wins.** The spike set its override right after `blockAutofillQueries()`, and the Autofill query then reached the spike proxy (`CONNECT content-autofill.googleapis.com:443`) instead of `127.0.0.1:1`. One `ProxyConfig` cannot express "all hosts to the loopback proxy, but this host to nowhere": rules filter by scheme, and reverse bypass flips the whole list. **So under P2 the loopback proxy must refuse `content-autofill.googleapis.com` itself.** It can: the query carries the profile's credentials, so the proxy knows the site, and a refusal by host needs nothing more.
- **Is the auth cache cleared when a profile is wiped or deleted? Not by a wipe, and not by a lock. Only by the process ending.**
  - After a `9c`-style lock, which closed every session (`0 SESSIONS`), SpikeX's first request still carried `p-8f9f47e6`.
  - After "Close and wipe this session" in the site sheet, which journaled the profile for deletion and cleared its cookies and storage in place, it still did. (The dashboard row menu's "Wipe this site's data" does nothing: the code notes it as a known gap.)
  - The cache is in memory, so a new process starts empty, and deletion at the next start removes the profile itself.
  - So P2's credentials must stay valid for a profile for the whole process: a site's credential cannot be rotated per session or per lock unless the proxy also accepts the old one.

## What the spec must account for

1. **dns-prefetch still leaks under P2** (a2). Under the override, `<link rel=dns-prefetch href=https://www.python.org>` produced a device-side lookup of `www.python.org`. `NetworkContext::ResolveHost` ignores proxy configuration, and P2's proxy sees only CONNECTs, never the HTML. This needs a separate decision, for example rewriting hints in HTML the app still fetches itself, or accepting it as a known gap.
2. **A profile's first request decides everything before it.** Until a profile has answered one 407, its service-worker fetches and preconnects fail closed. That is safe, but a service worker that starts before any page request in the process (for example a push or periodic sync, if one ever runs) would fail. In practice the main frame is always first. The spec should say the loopback proxy challenges the main frame too, so every profile authenticates on its first navigation.
3. **The loopback proxy must refuse the Autofill host by name**, since the Autofill block's override is replaced by P2's.
4. **Credentials are fixed per profile for the life of the process**, surviving lock and wipe. They should be derived from the profile, or held in memory keyed by it, and never shown anywhere. Another app on the device can connect to a loopback port, so the credentials are what stop the proxy being an open relay into the user's SOCKS proxy. They must be unguessable, and the proxy must refuse everything without them, including direct-route connections.
5. **Every callback must be answered.** Parallel 407s are not coalesced (five callbacks for five requests). A request whose callback is never answered waits indefinitely, with no timeout seen within 3 s. The app side should answer synchronously from an in-memory map.

## Not verified here

- A physical phone. Other WebView versions: `PROXY_OVERRIDE` and multi-profile both need a recent WebView, and this was 154.
- Proxy authentication schemes other than Basic, and what Chromium does when the proxy rejects the credentials it was given (repeated 407 after a `proceed`). The spike never rejected an answer.
- HTTP/2 or QUIC to the proxy. The override was a plain `http` proxy rule, and Chromium used HTTP/1.1 CONNECT and absolute-form requests.
- WebSocket (the app's shields block it) and WebRTC (UDP, not proxied at all; the app's "Block WebRTC" governs it).
- Whether the per-profile auth cache survives a WebView renderer crash (it lives in the browser process, so it should).

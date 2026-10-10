# Container — Isolated Web Container (Android)

A privacy-first Android browser where every site runs in its own isolated
"container": separate storage, per-site proxy routing, filtering, and a
two-vault decoy PIN system. Flutter UI, Kotlin platform layer.

## Source of truth for design

- `Sandbox Container -canvas-.dc.html` — **authoritative spec.** 32 screen
  blocks, each with an `id` (e.g. `id="1b"`). Exact copy, colours, sizes,
  layout. When anything conflicts, this file wins.
- `Sandbox Container.dc.html` — same screens, print layout. Not authoritative.
- `app-design.pdf` — rendered version of the canvas file, for skimming only.

Never paraphrase, re-capitalise, or "improve" user-facing copy — it is
transcribed verbatim from the HTML. If a string isn't in the spec, that's a
design question to ask about, not to invent.

## Where the work is planned

`docs/superpowers/plans/` holds one implementation plan per subsystem,
written with the `superpowers:writing-plans` skill and meant to be executed
with `superpowers:subagent-driven-development` or `superpowers:executing-plans`.
Each plan ships working, tested software on its own.

| Plan | File | Status | Covers |
|---|---|---|---|
| 1 — Foundation | `2026-08-30-isolated-web-container-01-foundation.md` | **Built** (checked 2026-09-30 against the tree: every file its tasks create exists; no execution record of its own, and it predates this repo's first commit `7f54e8d`) | Design tokens/typography, dashboard (`1b`), SQLite, domain model. Import-path bug (#1) fixed 2026-08-30. |
| 2 — Entry and identity | `2026-08-30-isolated-web-container-02-entry-and-identity.md` | **Done** (2026-09-02) | Setup wizard, lock screen, decoy vault, panic wipe, settings, PIN-derived crypto, lock states (`9a`–`9c`). **Correction, 2026-09-01:** this row previously said the missing glue code (LockController, LockScreen, SetupController.complete, SetupFlow, `session_controller.dart`) was filled in 2026-08-30 by flutter-app-1e. That was never true of this checkout at the time — verified independently by flutter-app-9c and flutter-app-f5 on 2026-09-01, and by the same-day `CLAUDE_REPORT.md` audit. **Update, 2026-09-04:** all 8 tasks are now genuinely done. Tasks 1/2/4/5/6 as recorded above; Tasks 3 (Android crypto plugin — `CryptoPlugin.kt`), 7 (panic, see issue #6), and 8 (settings/lifecycle/session gate — `session_controller.dart`, `app_gate.dart`) landed 2026-09-02 in commits `261a3fd`/`883e16f`/`26540fc`, one day after this row's 2026-09-01 "remain open" note — that note was stale by the time it was read, not wrong when written. Re-verified 2026-09-04: `flutter analyze` clean, `flutter test` 223/223 passing. |
| 3 — The container | `2026-08-30-isolated-web-container-03-container.md` | **Built** (checked 2026-09-30 against the tree: every file its tasks create exists but two that later plans replaced: `container_toolbar.dart`, deleted by Plan 12's layout C (`173c544`), and `assets/filters/default.txt`, never created, Plan 11's three bundled lists in `assets/filters/` taking its place. Its engine was since reshaped by Plans 10–13; no execution record of its own, and it predates this repo's first commit `7f54e8d`) | Kotlin platform layer, per-site WebView isolation, filtering proxy, container/switcher/add-site screens. Phantom `openVault()` bug (#4/#7) fixed 2026-08-30 — see note below, the original diagnosis of that issue was inaccurate. Task 5 Step 6's `fetchThrough` was a `TODO_IMPLEMENTED_IN_STEP_7` sentinel with Step 7 only describing it in prose (a placeholder violation) and calling `ProxyProbe.reachable()` with no host/port, so it could never check the right proxy — fixed 2026-08-30 (flutter-app-42) with a real HTTP-over-socket implementation and a per-`host:port` cached `ProxyProbe`. |
| 4 — Failure states & in-page moments | `2026-08-30-isolated-web-container-04-failure-states-and-in-page-moments.md` | **Built** (checked 2026-09-30 against the tree: every file its tasks create exists, and Plan 6 wired its screens to the engine's events; no execution record of its own, and it predates this repo's first commit `7f54e8d`) | Permission ask, reader mode, site sheet, row menu, held download, Today log, proxy-unreachable, tunnel-dropped |
| 5 — Workspaces and scripts | `2026-08-30-isolated-web-container-05-workspaces-and-scripts.md` | **Built** (checked 2026-09-30 against the tree: every file its tasks create exists, and Plan 6 Tasks 6–7 made its screens reachable; no execution record of its own, and it predates this repo's first commit `7f54e8d`) | Workspace list/create/delete (`10a`–`10c`), filter lists + script library + script editor (`10d`/`10e`). Turn 9 (`9a`–`9c`) is Plan 2's, not this plan's — see its own header note. |
| 6 — Integration | `2026-09-02-isolated-web-container-06-integration.md` | **Done** (2026-09-28) | Wires the five plans into one navigable app: `ContainerRoute` navigation shell, discriminated native events (permission asks, held downloads, tunnel-drop) reaching Plan 4's screens, per-category `FilterEngine`/`BlockedTallyRecorder` feeding a live Today log, `SiteSheet` toggle persistence, and the decoy-sync correction. Implements `docs/superpowers/specs/2026-09-02-integration-design.md` (approved by the user 2026-09-02); three places deliberately correct or narrow that spec against what the tree can actually do — see the plan's own header. 7 tasks. Explicitly leaves search and biometric unlock unbuilt — see Unassigned Work below. **Update, 2026-09-28:** Tasks 1–5 landed 2026-09-04 (merge `3fc3b43`), but Tasks 6 and 7 never did — the struck-through "SiteSheet toggle persistence" bullet below claimed otherwise, and the Workspaces, Scripts and Today screens were built and tested yet unreachable from anywhere in the app. Both were executed on branch `plan-06-tasks-6-7` (commits `c9ad712`..`a7af50a`): the container toolbar's `☰` opens `SiteSheet` (`6c`), whose two switches persist and whose Edit opens the add-site form; a live `BlockedTallyController` feeds the Today log and replaces the dashboard's hardcoded-zero leak count; Today is reached from the workspace dropdown (`5c`: "reachable from the dashboard menu"); Settings' MANAGE rows open real Workspaces (`10a`–`10c`, create/edit/long-press delete, delete wipes each site's profile) and Scripts and filters (`10d`/`10e`) routes. Task 6's `syncToDecoy` half was skipped — superseded by Plan 9's `resyncDecoy`. Several places deliberately deviate from the plan's text; each is a ruling recorded in the plan's Known gaps. Verified 2026-09-28: `flutter analyze` clean, `flutter test` 333/333, `flutter build apk --debug` succeeding. **Not verified on a device.** **Device-verified 2026-10-02 (emulator; see "Device verification (2026-10-02)"):** `6c`'s Desktop view switch persists (a reopened site echoes a desktop User-Agent), its Edit opens the site's form filled in, and Workspaces creates, renames and long-press deletes (an empty workspace only; a delete that wipes sites' profiles was not tried). |
| 7 — Search | `2026-09-04-isolated-web-container-07-search.md` | **Done** (2026-09-08) | Wires `DashboardFooter`'s long-dead search button to a real screen: `SiteRepository.all()`, a `searchResults()` join/filter/sort across every workspace in the open vault, and a pure `SearchScreen`. Implements `docs/superpowers/specs/2026-09-04-search-screen-design.md` (brainstormed and approved by the user 2026-09-04) — that spec itself stands in for the missing canvas screen block, since search was never actually designed anywhere. 5 tasks, all executed; final-review fix wave (2026-09-08) made tapping a search result push a real `ContainerRoute` (it previously only marked the site open and popped back to the dashboard) and fixed `allSitesProvider` never being invalidated, so search now sees adds/deletes/touches made after it first loaded. **Superseded 2026-10-03 by Plan 18:** the search screen is gone; the dashboard's search field took its place. |
| 9 — Decoy re-sync | `2026-09-08-decoy-resync.md` | **Done** (2026-09-08) | Gives the owner a reachable "re-sync with the decoy PIN" flow from Settings, replacing the setup-time-only `provisionDecoy` with `resyncDecoy` (`lib/data/repositories/decoy_provisioner.dart`) — a real add-and-remove sync that preserves an already-synced site's `profileId` so its decoy-side cookies/history survive repeated syncs. Persists `decoy_configured` on the real vault (`SetupController.complete`) and wires it to `decoyEnabledProvider`/`decoySiteCountProvider`, so `SettingsScreen`'s VAULT section — hardcoded invisible before this plan — now actually shows or hides based on whether a decoy was configured. Adds `DecoyResyncPinScreen` (pure widget, reuses `PinDots`/`PinKeypad`) and `DecoyResyncRoute` (reuses `LockController`, calls the new `SettingsController.resyncDecoyVault`, which checks the entered PIN against both vault slots via the existing `VaultUnlocker`/attempt-gate before opening the decoy vault just long enough to sync and close it). Implements `docs/superpowers/specs/2026-09-08-decoy-resync-design.md`. 5 tasks, all executed. |
| 10 — HTTP CONNECT tunnel | `2026-09-09-http-connect-tunnel.md` | **Done** (2026-09-09) | Makes `ProxyMode.http` actually work by hand-writing the CONNECT tunnel AOSP removed from `java.net.Socket`. New `android/app/src/main/kotlin/com/mono/container/engine/HttpConnectTunnel.kt`: `HttpConnectTunnel.open(proxyHost, proxyPort, targetHost, targetPort)` opens a plain socket to the proxy, writes `CONNECT host:port HTTP/1.1`, requires a 2xx, drains the header block so the returned socket sits at the first byte of tunnel payload, and otherwise throws the new `ProxyTunnelException(statusCode, message)` after closing the socket. `Router.connect`'s `Route.Proxy` branch now splits on `route.socks` — SOCKS still delegated to the platform, `http` to the tunnel — and no executable `java.net.Proxy.Type.HTTP` remains in the tree. Undoes the `ca9552c` interim guard on both sides (`Router.resolve` re-admits `http` **by name**, so an unrecognised mode is still `MISCONFIGURED`; the Dart mirror in `resolveRoute` is deleted, `ProxyMode` being a closed enum). Gives `RouteFailure.PROXY_REFUSED` its first producer in this repo's history, via `RequestInterceptor` and `DownloadFetcher` mapping `ProxyTunnelException` — the existing copy `'The proxy refused the destination'` was not reworded. `ProxyHttpClient` needed no code change: `startTls` already wraps whatever socket `Router.connect` returns, against the target host. This plan has **no design spec** — it was written from defect 5 of the download-manager plan, and the user approved its three design decisions inline on 2026-09-09 (hand-rolled CONNECT over a new dependency, no proxy authentication, `PROXY_REFUSED` as the mapping). 4 tasks, all executed; commits `64c0fa6`/`f6bd41b`/`5e42dd5` plus this documentation pass. Verified 2026-09-09 on a clean tree: Kotlin JVM tests 12/12 (`HttpConnectTunnelTest` 3, `RouterTest` 5, `FilterEngineTest` 4, counts read from the JUnit XML, not from `BUILD SUCCESSFUL`), `flutter analyze` clean, `flutter test` 300/300, `flutter build apk --debug` succeeding with zero `e:` lines. **Not verified: it has never spoken to a real HTTP proxy on a real device** — every test replies from a localhost `ServerSocket` with a canned status line, and the `IllegalArgumentException("Invalid Proxy")` this work exists to fix is Android-only and cannot be reproduced on the desktop JVM the unit tests run on. See its Known gaps below. **Update, 2026-09-28:** exercised on an Android emulator (not a physical phone) through a minimal local CONNECT proxy (a Python script, not a real-world proxy): an http-mode Google site went live with every request tunnelled, and a destination the proxy deliberately routed to the wrong server was refused with `SSLHandshakeException: No subjectAltNames on the certificate match` — hostname verification against the target, over the tunnel, on Android's provider. See "Device verification" below. |
| 11 — Filter lists and scripts | `2026-09-28-filter-lists-and-scripts.md` | **Done** (2026-09-29) | Makes `10d`/`10e` real: three bundled rule files (`assets/filters/`), synced into every vault on open (`syncBundledFilterLists`, replacing the mock `seedFilterListsIfEmpty`); on open Dart sends the vault's enabled rules and the site's library scripts (`EngineExtras`), Kotlin builds the site's `FilterEngine` from them and injects each script separately, scoped to the site's origin (`UserScriptJs`). Implements `docs/superpowers/specs/2026-09-28-filter-lists-and-scripts-design.md`. Verified 2026-09-29: JVM 74/74, `flutter test` 379/379, analyze clean, APK builds; on the emulator the Social embeds and Trackers and ads switches each decide, on the next open, whether their hosts are blocked. ~~**Script injection is not device-verified**: the script editor's "+ Add site" picker is unbuilt (`onAddSite: () {}`), so no UI can attach a script to a site.~~ **Update, 2026-09-29 (branch `feat-script-site-picker`):** the picker is built (`ScriptSitePicker`, user's ruling: an untitled sheet of the vault's sites not yet on the script, tap adds, effective on Save, chip dimmed and inert when none are left; no new copy), and **script injection is now seen on the emulator**: a JS script attached through it to a direct `https://example.com` site put its text at the top of the page, and following the page's link to iana.org showed no trace of it, so the origin scoping holds. See the plan's Verification and Known gaps. |
| 12 — Browser chrome and navigation | `2026-09-29-browser-chrome.md` | **Done** (2026-09-29) | Rebuilds `2b` as layout C, implementing `docs/superpowers/specs/2026-09-28-browser-chrome-design.md` (project 1 of 4; supersedes `2b` and its toolbar copy): a top bar whose address pill ends in a shield (`6c`) and, while loading, a stop ×, beside panic; a 2px muted load line; a bottom bar with back / forward / `N OPEN` / ☰; drawn line icons (`lib/ui/core/icons.dart`); find in page; the ☰ menu (`BrowserMenuSheet`: Reload, Find, Reader, Copy link; Today, Scripts and filters, Workspaces, Settings, All sites); and a `Search engine` setting in `2d`. **Mullvad Leta is not offered** — it shut down on 2025-11-27, and the spec drops an engine that no longer works — so the picker lists DuckDuckGo, Startpage and Brave Search. Typing in the pill opens this container (`loadUrl`, which refuses every scheme but http/https in Dart and in Kotlin), a saved site's own container pushed over this one, or a **throwaway** container on this container's exact route, held in memory (`throwawaySitesProvider`, emptied on leaving `SessionOpen`) until `Save as a site`, which writes the row and then `keep`s the profile. A throwaway's profile id is journaled in `filesDir/throwaway-profiles` (`ThrowawayJournal`, beside `PendingDeletions`) from before the profile exists, so a crash cannot leak it; every start sweeps the journal and panic clears it. Verified 2026-09-29: `flutter analyze` clean, `flutter test` 520/520, Kotlin JVM tests 98/98 (read from the JUnit XML), `flutter build apk --debug` with zero `e:` lines. A final review found a typed address replacing a saved site's stored URL natively (moving its script scope) and the save form keeping a throwaway's first host as its name; both fixed with tests. **Device-verified 2026-09-30 (emulator, merged to `main`):** a search from a SOCKS5 site opened a throwaway on SOCKS5 (`THROWAWAY · SOCKS5`); back returned to the original page with no new request; a direct-route throwaway saved as a site kept its cookie on the same profile; a force-stop, and separately an emulator kill, left no throwaway profile behind; Startpage's results showed after its proof-of-work page; find, Copy link and every ☰ row worked; a `9c` lock cleared the throwaway journal. Brave Search was not seen past its bot check (the host gets HTTP 429 too, so it is this network's IP reputation, not the app); **user's ruling 2026-09-30: keep it in the picker**, recorded as unverified. The run also found pre-existing engine leaks, none from this plan: see "Device verification". See the plan's "Device checks", Known gaps and Design questions. **Design questions answered 2026-10-02** (branch `plan12-design-answers`): the save bar's × is labelled `Dismiss`; typing a saved site whose container is already lower in the stack returns to that container and loads there, instead of pushing a second one that took its session over; Unicode hosts open as addresses in punycode (`lib/domain/idn.dart`); the `6c`-on-a-throwaway and back-closes-find rulings are confirmed. `flutter analyze` clean, `flutter test` 603/603. **Not verified on a device.** **Device-verified 2026-10-02 (emulator):** the save bar's × reads `Dismiss`; typing ExDirect's address from a throwaway above it popped back to ExDirect, wiped the throwaway (journaled) and loaded there, with one open session and Back walking that container's history; `münchen.de` (pasted through the emulator's shared clipboard) was offered as an address and opened, redirecting to `www.muenchen.de`. Project 2 (tabs) is Plan 15, which replaces the stack of pushed containers and the one-entry `2c` stub. |
| 13 — Loopback proxy (P2) | `2026-09-30-loopback-proxy.md` | **Done** (2026-10-02) | Every WebView request goes through `ProxyController` to an in-app loopback proxy (`LoopbackProxy`), which answers a profile's first `CONNECT` with `407`. Each site's view answers with that profile's random credential (`SiteCredentials`, valid while the site is open), and the proxy routes the connection by it on the site's own route. Chromium now does the HTTP and TLS work, so a proxied site keeps cookies, follows redirects and posts forms. The interceptor only gates (closing views) and blocks (filters). Autofill's `content-autofill.googleapis.com` is answered `403` inside the proxy. A tunnel never outlives its binding: `unbind`, and a `bind` that replaces one, close every socket opened under it (`4feb541`, open problem 1). By the user's rulings of 2026-09-30, an open waits for the override's listener (no timeout, no copy), and a direct route goes through the system (Wi-Fi) proxy unless the host is excluded. **Plan deviation 2: the proxy refuses any destination named `127.0.0.1` with `403`**, so a local server cannot phish a site's credential by challenging as the proxy. A site at `127.0.0.1` cannot be opened (`localhost` can). Tasks 1–6 were executed 2026-09-30 in a cloud session; Task 7 ran 2026-10-02. Gates at `6760d78`: `flutter analyze` clean, `flutter test` 603/603, Kotlin JVM 200/200 (JUnit XML), `flutter build apk --debug` zero `e:` lines. **Device-verified 2026-10-02 (emulator, API 36, WebView 154; not a physical phone):** every check in the plan's Task 7 was seen, including the re-challenge stop-check (one `403`, no loop), open problem 1's fix, preconnect by name through SOCKS5 (a1 closed), a cookie surviving close-and-reopen and a lock, the pagehide beacon sending nothing on close, strangers' `407`/`403`, and the system proxy with a bypass. Panic ran by accident, from a harness tap; the plan's "Device checks" says so. The run found a refused reopen leaving the old binding live (**✅ fixed on `main` as `2ed5ca7`**, ported from `0c7ad4e`; `p2-task7` no longer exists), an unhandled exception at every lock and panic (**✅ fixed 2026-10-02**: the tally's site lookup finds nothing while no vault is open), and older Plan 12 bugs (the pill's stale `allSitesProvider` reopened a removed site; **✅ fixed 2026-10-02**: the pill re-resolves against the vault before opening, and every site write calls `sitesChanged`). See the plan's "Device checks" and Known gaps. |
| 14 — Proxy authentication | `2026-10-02-proxy-authentication.md` | **Done** (2026-10-02, merged to `main` at `8dc0e5d`) | A site's upstream proxy can take a login: typed per site (USERNAME/PASSWORD on `2a`'s Network tab), or derived from the site's `profileId` ("Separate login per site", for Tor circuit isolation; a wipe rotates it). Every SOCKS route now goes through the hand-written `Socks5Tunnel` (RFC 1928/1929) instead of the platform's; `HttpConnectTunnel` sends `Proxy-Authorization: Basic`. A rejected login (`407`, a SOCKS5 auth failure, `0xFF`) is `PROXY_LOGIN_REJECTED`, "The proxy rejected the login", reported route-wide by the loopback proxy; a refusal while a session is still opening now refuses it (`8b`). Schema 7. Implements `docs/superpowers/specs/2026-10-02-proxy-authentication-design.md`. Verified 2026-10-02 on the branch rebased onto `main` at `eb6f6de`: `flutter analyze` clean, `flutter test` 627/627, Kotlin JVM 233/233 (33 JUnit XML files, no failures or errors), `flutter build apk --debug` with zero `e:` lines. **Device-verified 2026-10-02 (emulator, against `tool/device-check/proxy.py`; not a physical phone, not a real proxy or Tor):** all seven run-sheet checks seen — a typed login accepted, rejected and missing on SOCKS5 and on HTTP, each refusal while opening showing `8b`; a no-login SOCKS5 site still loading through the new client; per-site logins differing between sites and rotating only for the wiped one; a throwaway inheriting the login; and a login rejected under a live site showing `8c`. The run found three older bugs in `8b` (its buttons do nothing, a refused site stays under OPEN NOW, "Last worked" is always "never"). **✅ All three fixed 2026-10-02 (branch `fix-8b`), seen on the emulator:** `8b` is shown inside the container's own route, and its buttons reopen the site in place (Try again; Change proxy settings opens the form on Network; Open without the tunnel is this visit only, direct, in the site's own profile); a refused site leaves OPEN NOW; "Last worked" is `sites.last_worked_at` (schema 8). See the plan's Device checks. |
| 15 — Tabs | `2026-10-02-tabs.md` | **Done** (2026-10-02, merged to `main` from `plan-15-tabs` before the device checks, at the user's request) | Project 2 of the browser-chrome series: several pages per container, a real `2c`, and one container host route in place of Plan 12's pushed `ContainerRoute` stack. Implements `docs/superpowers/specs/2026-10-02-tabs-design.md`, every question in it answered by the user on 2026-10-02. **Pages outlive their Flutter view:** natively a `Page` owns each WebView and `PageHost` (the platform view) only attaches and detaches it, so open containers survive a trip to the dashboard and come back without reloading; `ContainerView`/`ContainerViewFactory` are gone. A new page opens only from a link that asks for a new window, on a user tap, up to **6 per container** (user's ruling, changed in the spec review; the 7th loads in place, read by a capture view that refuses every request); it comes to the front. `2c` lists every open container (viewed first, then most recently viewed; `viewing now · <mode>` / `background · now`, `N min`, `N h`), with a container's pages nested under it (title or host, then host in mono; no jade), taps to switch in place, × per page and per container; "Close all and wipe" closes and wipes every container. `N OPEN`, `2c`'s header and `9b` count open containers vault-wide, throwaways included; the dashboard's `N SESSIONS` stays per workspace and counts a throwaway under its opener's workspace. System back: in-page history, then close a link page to its opener, then a saved container goes to the dashboard (left open) and a throwaway to its opener container, else the most recently viewed one, else it is closed and wiped. Background pages are paused; their permission asks and held downloads wait until the page is viewed, and are answered "keep blocked"/discarded if it closes first. A saved route or cookie-policy change closes an open container (the viewed one reopens in place; moving to wipe on exit rotates the profile). `OpenContainers` (`lib/ui/features/container/view_models/open_containers.dart`) is the in-memory registry of all of it, emptied on every transition out of `SessionOpen`; **every lock now calls `engine.closeAll()`** (before this plan a lock left every saved site's native session and loopback binding registered). Every wipe goes through a close: a profile is wiped only after its last page's `Teardown` (`EngineChannel.wipeProfile`). Nothing about pages is written anywhere. Deviations and decisions are in the plan's header and Verification. Verified 2026-10-02 at `d2d12f4` on a clean tree: `flutter analyze` clean, `flutter test` 760/760 (baseline 663), Kotlin JVM 250/250 (35 JUnit XML files, re-run with `--rerun`; baseline 235), `flutter build apk --debug` with zero `e:` lines. **Not verified on a device** — no emulator was available; reattaching a WebView to a new platform view, `onCreateWindow`'s transport with a profile set, the capture view and `onPause` are from the WebView contract only. The plan's "Device checks" section is the run sheet (`tool/device-check/`). **Device-checked 2026-10-03 (emulator, on `main` at `f1e3950` with Plans 16 and 17; not a physical phone):** all 12 checks seen, check 8 with a geolocation ask instead of the camera, and check 4's cap one tap earlier than the sheet says (the opener counts: 6 pages). The run found three bugs: **pages outlive their Flutter engine** (a Plan 15 regression: back on the dashboard finishes the Activity, and the old engine's pages stayed alive, holding their profiles, after the relaunch's cold lock; **✅ fixed 2026-10-03, branch `fix-pages-outlive-engine`**: `MainActivity.cleanUpFlutterEngine` calls `EngineChannel.detach`, which closes every container as a lock does; seen on the emulator), **every page renders at about 38%** (older: `setInitialScale(100)` is a percentage of physical pixels, so `width=device-width` is ignored; **✅ fixed 2026-10-03, branch `fix-zoom-and-capture`**: `initialScaleFor` gives WebView's own scale at 100% and `pageZoom × density` otherwise); and **camera and microphone asks never reach `6a`** (**✅ fixed on the same branch**: two causes, not the one guessed. Block WebRTC, on by default, stubbed `getUserMedia` to reject before any ask; it now removes only `RTCPeerConnection`. And with no `CAMERA`/`RECORD_AUDIO` the system refused the camera after an allow; they are declared and asked at runtime, by `PermissionAsks`, when a site is allowed one, and Android's dialog no longer locks the vault: `LifecycleController.systemDialogShowing` excuses its `inactive`). All three seen on the emulator. See the plan's "Device checks (2026-10-03, emulator)". |
| 16 — Privacy controls | `2026-10-02-privacy-controls.md` | **Done** (2026-10-02, merged to `main` from `plan-16-privacy-controls` at the user's request, before any device check) | Project 3 of the browser-chrome series, implementing `docs/superpowers/specs/2026-10-02-privacy-controls-design.md` (every question in it answered by the user on 2026-10-02, §5's copy approved word for word). A **security level**, Standard / Safer / Safest ("like Mullvad Browser": its ideas, on what WebView can switch off): Safer injects `shields/safer.js` (a `script-src 'none'` meta CSP on `http:` documents, no WebAssembly, no WebGL); Safest turns JavaScript and network images off and adds no document-start scripts; an unknown or missing level is Safest on both sides. Held as a **vault default** (`app_settings` `security_level`, Standard until chosen, set in Settings' BROWSING) and a nullable **per-site override** (schema 9, set from ☰ and `6c`, copied by decoy re-sync, kept by every wipe and by the `2a` form); Dart resolves the effective level at every open and sends Kotlin only that. A site's level or any `6c` switch applies **at once, by reopening the container in place** at the viewed page (`OpenContainers.reopenInPlace`, `close(wipe: false)`: a throwaway or wipe-on-exit site keeps its login; only the viewed page survives). A vault default change reaches open sites at their next open. **`6c` is the shield panel:** level, blocked counts by category (above 0 only), Block WebRTC / trackers and ads / Anti-fingerprinting switches, and permissions in use (`Allowed`, or `Revoke` for an "allow while open" grant, which reloads every page of the container). **New identity** (☰ only, after a confirm sheet): `wipeSavedSite` (a throwaway: a wiped close and a fresh in-memory profile), then a reopen at the site's first address; with "Separate login per site" that is a new proxy login, so a new Tor circuit. Verified 2026-10-02: `flutter analyze` clean, `flutter test` 826/826 (baseline 760), Kotlin JVM 261/261 (37 JUnit XML files; baseline 250), `flutter build apk --debug` zero `e:` lines. Re-reading the spec found `buildSite` dropping the level on every form save; fixed (`b1b902f`). **Device-checked 2026-10-03 (emulator, on `main` at `e572c29`; not a physical phone):** all eight checks of "Run sheet: privacy controls (Plan 16)" in `tool/device-check/README.md` seen, and seen again in a re-run the same day by another session (the plan's "Re-run (2026-10-03, emulator)"). **Safer's `http:` CSP works** (inline, external, `onclick` and `javascript:` scripts all stopped, the external script still fetched), so the fallback is not needed; Safer on https gives `WASM undefined WEBGL false` with JS on; Safest stops scripts and image requests; a vault default change waits for the next open; a throwaway keeps its cookie across a `6c` switch; New identity rotates the per-site proxy user, journals the old profile and returns to the stored address; Revoke reloads and the next ask shows `6a`; the decoy's level is its own. **Reader at Safest does nothing on tap, with no message** (expected, since it runs JavaScript). Two first loads of a small `http:` page hung empty until Reload, most likely the emulator's dropped last byte. See the plan's "Device checks (2026-10-03, emulator)". Known gaps: WebView has no JIT switch (removing WebAssembly is a partial stand-in); workers keep WebAssembly and `OffscreenCanvas` WebGL at Safer; at Safest, Reader opens nothing and custom CSS does not apply; fonts and media are never blocked; a reopen keeps only the viewed page and loses history and "allow while open" grants, and also ends an `8b` "Open without the tunnel" visit (fail-safe); New identity does not change a typed proxy login. See the plan's Known gaps and Handoff. |
| 17 — Restyle | `2026-10-02-restyle.md` | **Done** (2026-10-02; merged to `main` 2026-10-03 at the user's request, before any device check, after `origin/main` with Plans 15 and 16 was merged into `plan-17-restyle`) | Project 4 of the browser-chrome series (`2026-09-28-browser-chrome-design.md` §11), implementing `docs/superpowers/specs/2026-10-02-restyle-design.md`: every icon is now an `AppIcon` line icon. `AppGlyph` gains `check`, `plus`, `more`, `vault`, `fingerprint`, `backspace`, `refused` and `contrast`, and the remaining Unicode glyphs (`‹ › × ⟳ ◑ ◉ ◇ ☉ ⛌ ✓ ⋯ ▲ ⌫`, jade `+`) and Material `Icons.*` are drawn on `1b`, `2a`, `2b`, `2c`, `2d` and its pickers, `3a`/`4a` keypad, `3c`, `4b`, `4c`/`9b`, `5a`, `5c`, `6b`, `8a`, `8b`, `8c`, `10a`, `10b`, `10d`, `10e` and search. No copy, layout or colour changed; four hard-coded canvas colours became tokens with the same values (`C.handle`, `C.pillText`, `C.dangerPanel`, `C.pinError`), and the add-site tab labels use `T.sectionLabel`. Icon-only buttons are `IconTap`s with screen-reader labels; new, approved by the user 2026-10-02: `Close`, `Search`, `Settings`, `Delete`, `Remove`, `Reader theme`. **One behaviour change (user's ruling):** `2d`'s back icon pops Settings; it was inert. `8b`/`8c`'s `‹` and `⟳` stay inert, as the canvas draws them. `+ Add site` keeps its text `+`; `Aa` stays letters. `test/no_glyphs_test.dart` fails on any of the replaced glyphs or `Icons.` in `lib/` (copy punctuation `·`, `—`, `→`, `“ ”`, `+` passes; `⌫` only as the keypad's key value in its four files); `test/support/glyph_finders.dart` has `findGlyph`/`findIconTap`. Plan 15's rewritten `2c` (left to this project by its Handoff) is restyled on top of it: panic and every container and page row's × are icons (`Panic`, `Close`). Plan 16's one Material icon, `SecurityLevelPicker`'s check, is drawn the same way. Later plans must keep the guard test passing: see the plan's Handoff. Verified 2026-10-02 at `038c153` on `main`'s base (`flutter analyze` clean, `flutter test` 684/684, APK with zero `e:` lines), again at `7d697f4` with Plan 15 merged in (`flutter test` 781/781), and on the tree merged with `main`'s Plans 15 and 16: `flutter analyze` clean, `flutter test` 847/847, `flutter build apk --debug` with zero `e:` lines. Plan 17 changes no Kotlin. **Not verified on a device**: no emulator in the cloud session that ran it. The screens to look at are in the plan's "Device checks". **Device-checked 2026-10-03 (emulator, the shipped build: `adb emu screenrecord screenshot` is not blanked by `FLAG_SECURE`; not a physical phone):** every listed screen's icons seen in place (`3c`, `4b` and `5a` through a panic and new setups, by the user's go-ahead; the vault was set up again with the same PINs and sites) except `8a`'s done steps, which the app never shows (`openStepsFor` makes every step `pending`). The run found two bugs, both **✅ fixed on branch `fix-workspace-menu-material`** and seen by hot reload: **the dashboard's workspace menu crashed on every device since Plan 1** ("No Material widget found": it is stacked beside the `Scaffold`, so the dashboard's way into Today never worked; `afc7fc5`), and **panic from inside a container never reached `3c`** (a Plan 15 regression: `panic(ref)` used the container route's disposed `ref` after the wipe, leaving the dashboard's "database_closed" error on screen; the wipe itself completed; `20b9a9e`). See the plan's "Device checks (2026-10-03, emulator)". |
| 18 — Dashboard redesign | `2026-10-03-dashboard-redesign.md` | **Done** (2026-10-03) | Implements `docs/superpowers/specs/2026-10-03-dashboard-redesign-design.md` (the user's nine rulings of 2026-10-03, approved section by section). The dashboard is a shell with three tabs (Sites · Today · Settings; `AppGlyph.sites/today/settings`; back on Today or Settings shows Sites; the bar hides while the keyboard is up). Sites has workspace chips (tap views, long-press opens `10b`, `+` makes one; delete stays in Settings ▸ Workspaces), one list with open sites first and no `OPEN NOW`/`IDLE`/`N SESSIONS`, and a search field in place of `+ Add site`. The field suggests as the container's address bar does, with no opener (`destinationFor`/`suggestionsFor` take an optional `current` and a `route`). A throwaway opened from it has no opener, counts under the viewed chip, and its first page's back closes and wipes it to the dashboard. The `+` opens `2a` on the viewed workspace with the keyboard up. A **default route** (`ProxyRoute`, `app_settings.default_route`, per vault, Direct until set, not copied by decoy re-sync; one that cannot be read is refused, never direct) is set in Settings ▸ BROWSING and is where a new site's Network tab starts. `2a` and the Default route screen share `RouteFields`. A blank NAME saves as the host. A fling on the container's bottom bar moves to the next or previous open container, **in opening order (plan D1, not `2c`'s order)**. The Plan 7 search screen is deleted (`sitesMatching` stays). Decisions D1–D7 are in the plan's header. Verified 2026-10-03: `flutter analyze` clean, `flutter test` 923/923, `flutter build apk --debug` with zero `e:` lines. **Not verified on a device**: the run sheet is the plan's "Device checks". |
| 19 — Built-in Tor | `2026-10-04-built-in-tor.md` | **Done** (2026-10-04) | Implements `docs/superpowers/specs/2026-10-04-built-in-tor-design.md` (the user's five rulings of 2026-10-04, approved section by section; §7's copy word for word). `ProxyMode.tor` is a third proxy mode beside SOCKS5 and HTTP, per site and as the Default route: Guardian Project's `tor-android` 0.4.9.13 runs Tor in process (`TorService`), started by `TorRuntime` when a Tor container opens and stopped **10 s after the last one closes** (`TorRuntime.LINGER_MS`, a deviation from spec §4.2: a reopen in place would otherwise stop and restart Tor, and the old `TorService` instance's late broadcasts failed the new run), and at once at every lock (`closeAll` → `stopAll`; a lock is decided only when the app returns, so Tor keeps running while it is backgrounded) and at panic. Tor's SOCKS port is a Unix socket, `files/tor/socks:0` (plan D2: the `:0` keeps tor-android's port parser from crashing the app), reached through `LocalSocket` wrapped as `StreamSocket`; each site sends its per-site login, so its own circuit. `8a` shows `Connecting to Tor · N%`; a Tor that fails or stalls (2 minutes with no new percentage) is `8b`'s `Tor did not connect`, never direct. An onion address never goes direct: typed on a Direct route it opens as `THROWAWAY · TOR`, a link to one from a direct page is refused by the loopback proxy before any lookup, and the form saves one on Tor. Block WebRTC is always on for Tor. Panic deletes `files/tor`, `app_TorService` and `cache/TorService`, again 5 s later, and once more at the next start (plan D4). Decisions D1–D10 are in the plan's header, and the 10 s linger. A Tor page also gets a dns-prefetch experiment script (`TOR_DNS_HINTS_JS`; accepted leak a2, not closed). **Known gaps (plan's Known gaps):** a Tor start within about a second of a stop can hear the old instance's late broadcast and show `8b` (Try again recovers; the broadcasts carry no instance id); the AAR metadata check is disabled for every library in `android/app/build.gradle.kts` because tor-android declares minCompileSdk 37 and this project compiles against 36 (remove the block at compileSdk 37); a `LocalSocket` read timeout is a plain `IOException`, so a Tor handshake timeout shows as 502 / "Download failed", not `UPSTREAM_TIMEOUT`; TLS over `StreamSocket` is verified only on API 36, not on API 29. Verified 2026-10-04: `flutter analyze` clean, `flutter test` 968/968, Kotlin JVM 325/325 (44 JUnit XML files), `flutter build apk --debug` with zero `e:` lines; debug APK 244.5 MB (233 MiB), of which `libtor.so` 7.6/6.8/8.4 MB (arm64-v8a/armeabi-v7a/x86_64). **Engine-path device spike passed** (`TorSpikeTest`, `OK (1 test)` in 29.6 s on the emulator, 2026-10-04: Tor over the Unix socket, `IsTor:true` through TLS, no listener on 9050/8118, a second start after `stopAll`). **Device-checked 2026-10-04 (emulator, against the real Tor network; not a physical phone):** all eight §9 checks and the controller's A–D seen (no Tor until a Tor site opens; check.torproject.org's "Congratulations"; two sites, two exits, and New identity changing only its own; a typed onion opening as `THROWAWAY · TOR` and onion links refused with no `.onion` lookup; only the Unix socket `socks:0`; Tor stopping at a lock, after the 10 s linger and at panic, which deletes all three directories; `Tor did not connect` 2:00 after a network cut, and Try again loading once it was back). **The dns-prefetch script reduced nothing**: 21/21 hinted hosts looked up without it, 20/21 and 21/21 with it, on The Guardian and CNN. **Found, open:** once, Tor aborted the app (`SIGABRT` in `pubsub_install` from `tor_run_main`) when a Tor site opened 46 s after a lock that came right after Android had frozen and unfrozen the process; not reproduced in one retry. See the plan's "Device checks". **Final-review fix (`08489c2`):** a Tor start now waits for the old `tor` thread to end, and a stop before Tor's control connection exists halts Tor once it does (`TorRuns`): the likely cause of that abort, JVM-tested only and not proven fixed. **✅ Root-caused and fixed 2026-10-09 (branch `fix-tor-process`):** the abort is Tor running *again* in a process it already ran in (`tor_api.h`, Tor bug 23847), not two at once: the fourth Tor start in one app process aborted it every time on the emulator. Every Tor run now has a `:tor` process of its own (`TorHostService`, `TorProcessDaemon`/`TorProcessRuns`), killed at its stop, so a lock or panic ends Tor at once and Tor dying shows `8b`/`8c` instead of killing the app. Kotlin JVM 378/378; `TorSpikeTest` rewritten and green on the emulator (`am instrument`, vault kept); seen in the app: six open/close cycles in one process, a lock ending `:tor`, `:tor` killed under a page showing `8c`. `8c`'s Reconnect on a Tor site now restarts Tor (user's ruling 2026-10-09): it reopens the container in place, unwiped, at the page shown, through `8a`'s "Connecting to Tor" (seen: `:tor` killed under TorC, Reconnect loaded it in 11 s in a new `:tor`). See the plan's Known gaps. |
| 20 — Restyle v2: foundation | `2026-10-05-restyle-v2-20-foundation.md` | **Done** (2026-10-06, branch `restyle-implementation`; not merged) | First of four plans implementing `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` ("Instrument", chosen by the overnight design run's debate, `docs/design-exploration/debate/VERDICT.md`; **awaits the user's review**, six open questions in its §12). New values behind every `C.*` name (warm ink `#121110`, four surfaces, three text tones each ≥ 4.5:1, `C.edge`/`C.line`/`C.lineSoft`/`C.code`/`C.onJade`/`C.focus`; retired names kept as deprecated aliases until Plan 23), `S`/`R` spacing and radii, IBM Plex Sans (static, unsubset: OFL Reserved Font Name) in place of Figtree, the v2 `T.*` scale (13 sp floor, badges 12), glyphs `shieldHalf/Full`, `*Filled`, `caseSolid/Broken/Double` and `vault` redrawn as the case mark, v2 shared widgets (52×32 toggle not jade, 14 dp dots, 48 dp `IconTap` default, `PillTone.dangerText`, `AppChip`, `Group`, step bar not jade), and the adaptive launcher icon (resources only; Android themes untouched). Verified 2026-10-06: `flutter analyze` clean, `flutter test` 1075/1075, `flutter build apk --debug` zero `e:` lines. **Device-checked 2026-10-08 (emulator, Pixel_9, API 36, WebView 154, the branch's own x64-only debug build; not a physical phone; the emulator's system theme was light, so most of it was seen in the Plan 24 light variant):** the new adaptive launcher icon on the home screen, the lock screen's case mark, switches on `2d` and `6c` reading on/off by knob and check with no colour, and the dashboard clean at 320×568 dp (font scale 1.0 and 1.3) and at font scale 2.0 (dashboard and ☰). **Not checked: the Android 13+ themed-icon variant.** **Seen 2026-10-09 (emulator, at `1a61dcf`):** the themed icon draws the case mark in the launcher's tint like the other themed apps, its glyph a little larger in the disc than theirs. See the plan's Device checks. |
| 21 — Restyle v2: dashboard and container chrome | `2026-10-05-restyle-v2-21-dashboard-and-chrome.md` | **Done** (2026-10-06, branch `restyle-implementation`; not merged) | Second of four plans implementing `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` (**awaits the user's review**). `1b`/`3b`/`5b`: workspace chips are `AppChip`s (check on the selected one), tabs draw the viewed tab's filled glyph on a raised pill (`T.tab`/`T.tabSelected`, no jade), a 48 dp search field on the group tone with a 1.5 dp edge border, and site rows of at least 72 dp in one `Group`, the jade light at the monogram's corner and nothing for idle rows (`StatusRail(showIdle: false)`), the host in Plex Mono. `2b`: the host is **never ellipsized** — `breakAfterDots`/`hostSpan`/`HostText` (`lib/ui/core/host_text.dart`) wrap it after its dots, with the plain host as the span's `semanticsLabel`, so `find.text(host)` still matches; the pill (min 48) grows, the route badge wraps under the host, and on a very narrow screen reload and shield move under it. The pill shows the container's **case** (`CaseKind` keep/wipe/throwaway: `caseSolid`/`caseBroken`, `caseDouble` on Tor; screen-reader label `Keep for this site` / `Wipe on exit`) and the **shield by security level** (`shield`/`shieldHalf`/`shieldFull`, never jade), from values `ContainerRoute` already holds. Panic is a 48 dp `C.danger` outline; every chrome target is 48 dp; the bottom bar's `N OPEN` and its chevron are text-1 (`ContainerBottomBar.openCountStyle`, shared with `2c`'s header). `2c`: viewed container a jade light, others an edge ring, hosts wrap, 24 dp between Close all and wipe and the panic tile. ☰ rows are `SheetRow`s; `8a` has no jade and its lines wrap. The save bar's `Save as a site` stays neutral (one jade role on `2b`). Ten test expectations moved to the spec's values (listed in the plan's Verification). Verified 2026-10-06: `flutter analyze` clean, `flutter test` 1094/1094, `flutter build apk --debug` zero `e:` lines. **Device-checked 2026-10-08 (emulator, Pixel_9, API 36, WebView 154, the branch's own x64-only debug build; not a physical phone; the emulator's system theme was light, so most of it was seen in the Plan 24 light variant):** a long host showed **whole** at font scale 1.0 and 2.0, the pill growing and the reload and shield moving under it at 2.0; the spec's own attack shape `forum.example.com.evil.io` wrapped to `forum.example.` / `com.evil.io` at 2.0 with the real domain still visible; all three cases told apart (solid on a Keep site, broken on a throwaway labelled `Wipe on exit`, double on a Tor site); the shield filled at Safest and outlined at Standard from the same pill; `1b`'s idle rows carried no ring. **Found, older than this plan:** `8a` draws every step as pending and never marks one done (Plan 17's `openStepsFor` finding; **✅ fixed 2026-10-10**: `880fbe4` from `second/tender-mccarthy-90488l`, merged to `main`, marks every step done once the open has returned and the last one running until the page goes live; `flutter analyze` clean, `flutter test` 1165/1165, Kotlin JVM 380/380 (51 JUnit XML files), debug APK with zero `e:` lines; not seen on a device). **Seen once 2026-10-09 (emulator), not reproduced:** the first dashboard tap after an unlock opened a different site than the row tapped. See the plan's Device checks. |
| 22 — Restyle v2: setup, lock and PIN | `2026-10-05-restyle-v2-22-setup-and-lock.md` | **Done** (2026-10-06, branch `restyle-implementation`; not merged to `main`) | Restyles `3a`/`4c`/`9b`/`9c` (lock), `4a`/`4b`/`5a` (setup), the decoy re-sync / Change PIN screen and `3c` (panic done) to `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` §5, §6, §8. View layer only (`lock_body.dart`, the three setup screens, `decoy_resync_pin_screen.dart`, `panic_screen.dart`); no copy, behaviour, controller, domain or Kotlin change, and nothing on a lock screen differs by vault. The case mark is text-1 (danger after a wrong PIN); lock headlines `T.stepTitle`, notes `T.bodyMuted`, counts in Mono inside their sentences; 20 dp gutters; `4b`'s rows, `5a`'s defaults, `3c`'s status lines and `9c`'s note are groups; `5a`'s checks and `3c`'s status words are text-1; `3c` is on `C.bg`. The one jade per screen is `4a`/`4b`'s Continue, `5a`'s Add your first site, and `9b`'s fingerprint when offered. One expectation updated to the spec's value: `lock_body_test.dart:152`, the vault mark `C.jade` → `C.textPrimary`. Deviations: `9c`'s "Locked after N minutes" number is not Mono (a domain string); `3c`'s title is `T.sheetTitle` by the §3.3 ladder. Executed in a worktree (`4511b1f`..`04675a5`, 1085/1085 there) and merged after Plan 21; on the merged tree 2026-10-06: `flutter analyze` clean, `flutter test` 1104/1104, `flutter build apk --debug` zero `e:` lines. **Device-checked 2026-10-08 (emulator, Pixel_9, API 36, WebView 154, the branch's own x64-only debug build; not a physical phone; the emulator's system theme was light, so most of it was seen in the Plan 24 light variant):** the lock in portrait, and in landscape at font scale 1.0 and 2.0 (`PinLayout`: message and dots left, keypad right, nothing clipped); a wrong PIN turning the case mark, headline and dots danger; and **`3c` after a real panic** (status words text-1, no jade, `Unlock` neutral, the app still up, `meta.bin` and both stores gone and the profiles journaled). The vault was then set up again with the same PINs, which also showed `4a`/`4b`/`5a`: the step bar position-only, `5a`'s checks text-1 and its one jade `Add your first site`. See the plan's Device checks. |
| 23 — Restyle v2: settings, management, sheets | `2026-10-05-restyle-v2-23-settings-management-sheets.md` | **Done** (2026-10-06, branch `restyle-implementation`; not merged to `main`) | Last of four plans implementing `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` (**awaits the user's review**). `2d` and its pickers in `Group`s with text-1 checks; `2a` (and the Default route screen via `RouteFields`) with `FormSegment` (selected = text-1 outline + check, no jade), `FormInput`, `AppChip` workspace chips, v2 `AppToggle`s, code in `C.code`, Save the one jade; `10a`–`10e` with the v2 markers, `10c`'s Delete on danger-wash, and script badge colours chosen in the view (`UserScript` holds no colour); `5c` total in `T.display`, bars not jade or amber; `6b` host `C.readerMuted`; **`6a`'s jade moves to "Keep blocked"** (words, order, handlers unchanged); `6c` Edit the only jade; `7b`'s wipe row danger; **`8b`'s "Open without the tunnel" is `PillTone.dangerText` 24 dp below the others**, shown exactly when it was; `8c` a danger-wash banner sharing `8b`'s `TunnelHeader`. Task 6 deleted every retired `C.*` alias (and the unused `C.readerHost`) and the analyzer ignore, so `C`/`T`/`S`/`R` are spec v2. The optional motion (Task 7) was not done. Three expectations moved to spec values (Settings' back glyph 22, `2a` Close 48, `7b` wipe row danger) plus same-value alias renames; listed in the plan's Verification. Verified 2026-10-06 at `a34c7ad`: `flutter analyze` clean, `flutter test` 1142/1142, `flutter build apk --debug` zero `e:` lines. **Device-checked 2026-10-08 (emulator, Pixel_9, API 36, WebView 154, the branch's own x64-only debug build; not a physical phone; the emulator's system theme was light, so most of it was seen in the Plan 24 light variant):** `6a` with **`Keep blocked` jade** and both allow buttons neutral (raised by `pages.py`'s `/ask.html`); `8b` for SOCKS5 with `Open without the tunnel` as danger text set well below the safe buttons; `6c`'s six switches reading on/off without colour, `Edit` its one jade; and the **decoy's Settings with no VAULT section**. Also seen: the security-level picker's check in text-1, `2a`'s selected tab and route chip marked by outline **and** check, `7b` showing only Open, Edit settings and the wipe group. **Not done: `8b` for Tor-clearnet and Tor-onion.** **Tor-clearnet seen 2026-10-09 (emulator, at `1a61dcf`):** `Tor did not connect` about 2 minutes after the network was cut, and Try again loading over a new exit once it was back; Tor-onion is still not done. See the plan's Device checks. **Not verified on a device.** |
| 24 — Restyle v2: light variant | `2026-10-06-restyle-v2-24-light-variant.md` | **Done** (2026-10-06, branch `restyle-implementation`; not merged) | The app follows the phone's light/dark setting (spec `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` §9, user's ruling D9): no in-app switch, no copy, nothing differs by vault. `Palette.dark` (the v2 values, byte-identical) and `Palette.light` (§9's table; jade is spruce `#1D6B57`, white on it); **`C` is now static getters over the active palette, not `const`** — never cache a `C.*` value in a `static` or `const` field (the plan's Handoff). `C.use(Brightness)` switches it. `PaletteScope` (`lib/ui/core/palette_scope.dart`, in `MaterialApp.builder`) reads the platform brightness, calls `C.use`, sets the status bar (`SystemUiOverlayStyle.dark` on light, `.light` on dark), and on a change marks every element below it for rebuild, which reaches the open vault's own navigator and its routes and sheets. `theme`/`darkTheme` from `containerTheme(Brightness)`, `themeMode: system`, no theme animation. Default colour parameters (`AppIcon`, `IconTap`, `Hairline`, `DashedBox`, `ui()`, `mono()`) resolve when read; the add-site tabs' cached label style and `8a`'s ring painter no longer hold a colour across a switch. Android window themes unchanged (dark launch frame on a light phone, accepted). `test/flutter_test_config.dart` starts every test dark (palette and, for widget tests, the platform brightness). The light sweep found one colour that assumed dark: the dashboard's jade `+` drew its icon in `C.bg`, now `C.onJade`. Two forced expectation edits (`const` removed in `icons_test.dart` and `primitives_test.dart`). Light screenshots of 18 screens rendered by a scratch test and looked at. Verified 2026-10-06 at `f3cf6a4`: `flutter analyze` clean, `flutter test` 1151/1151 (baseline 1142), `flutter build apk --debug` zero `e:` lines. **Device-checked 2026-10-08 (emulator, Pixel_9, API 36, WebView 154, the branch's own x64-only debug build; not a physical phone; the emulator's system theme was light, so most of it was seen in the Plan 24 light variant):** the emulator's system theme was light, so the **whole app came up in the light palette** — the first time this variant has run outside a test. Switching the system theme with the app open re-themed it in all three places the plan asks for: the dashboard, **inside an open container** (both bars, with no page reload) and **with the `6c` sheet up**, which is the case the plan's Handoff worries about since the sheet lives on the open vault's own navigator. Status bar icons stayed readable both ways, and the dashboard's `+` was spruce with a white glyph on an empty workspace (this plan's one found colour, `C.bg` → `C.onJade`) and neutral on a workspace with sites. **Not captured: the dark launch frame on a light phone** (spec §9's accepted deviation). See the plan's Device checks. |
| 25 — Cyberpunk palette | `2026-10-10-cyberpunk-palette.md` | **Done** (2026-10-10, branch `cyberpunk-palette`; not merged) | Implements `docs/superpowers/specs/2026-10-10-cyberpunk-palette-design.md` (the user's three rulings of 2026-10-10): `Palette.dark` becomes cool blue-black (`#0B0D12`) with a neon live colour `#3DF5D0`, pink danger `#FF7AA6`, neon yellow amber `#F5D13D`, lavender code `#C9B8FF` and pink/blue/yellow/violet/grey markers; Reader and light mode unchanged. The live and opening lights glow (`C.glow`: 60 %, blur 6) in dark mode only — `StatusRail`, `2b`'s pill dot and `8a`'s pill dot (the last added during the device check) — the one exception to v2 §4's "only sheets cast a shadow". Gates 2026-10-10 at `e787dbb`: `flutter analyze` clean, `flutter test` 1181/1181, APK zero `e:`. **Device-checked 2026-10-10 (emulator, not a physical phone):** every listed screen but `8c`; light mode unchanged. Found: no widget passes `StatusRail(opening: true)`, so amber shows only in the pills (older). See the plan's Device checks. |

Each plan's own **Handoff** and **Known gaps** sections at the bottom are the
authoritative record of what it produces for later plans and what it
deliberately leaves unbuilt — check those before assuming something exists.

## Tech stack

Flutter stable / Dart 3, `flutter_riverpod`, `sqflite` (+ `sqflite_common_ffi`
for host tests), `path`, `path_provider`. Plan 2 replaces `sqflite` with
`sqflite_sqlcipher` for encrypted stores and adds `local_auth`, BouncyCastle
(Argon2id + AES-GCM via Kotlin plugin), and the Android Keystore. Plan 3
adds `androidx.webkit:webkit:1.12.0` (multi-profile WebView API) and raises
`minSdk` to 29. Fonts Figtree + IBM Plex Mono (IBM Plex Sans in place of Figtree on `restyle-implementation`, Plan 20), bundled as assets, never
fetched at runtime. No code generation anywhere (no `build_runner`,
`freezed`, `drift`) — hand-written mappers only. Plan 19 adds `info.guardianproject:tor-android` (Tor in process, Maven Central) and `androidx.localbroadcastmanager`.

## Global constraints (apply everywhere, not just Plan 1)

- **Android only.** ~~Dark theme only.~~ **User's ruling 2026-10-06 (restyle v2, `docs/design-exploration/DECISIONS.md` D9): a light variant**, following the phone's system setting, with no in-app toggle (Plan 24). The Android window themes stay dark so WebView force-darkens pages (`test/android_theme_test.dart`).
- **No network requests of the app's own, except connecting to the Tor
  network when the user has chosen Tor** (user's ruling, 2026-10-04, Plan
  19). No account, sync, analytics, or telemetry, ever. Tor runs only while a
  container on the Tor route is open, and stops at every lock and at panic.
- **Jade `#7FC8A9`** means live state or the single affirmative action on a
  screen — never decorative, never more than one per screen.
- **Hairline dividers, not cards.** 1px white-alpha lines separate rows.
- **IBM Plex Mono for anything technical**, Figtree for everything else (IBM Plex Sans on `restyle-implementation`).
- **Two-vault decoy model, not a filter.** Two separate encrypted SQLite
  stores selected by which PIN unwraps them; no query anywhere filters rows
  for privacy, and no aggregate ever counts across both vaults.
- **The interceptor never falls back to direct.** A site set to a proxy that
  becomes unreachable is refused, never silently sent unproxied.
- **Threat model is coerced unlock**, not forensic disk imaging — the decoy
  vault must be convincing to a person compelling an unlock, not to someone
  imaging the device.
- **No leak count, anywhere** (user's ruling, 2026-10-02). The dashboard shows no count at all since Plan 18 (`N SESSIONS` was removed by the user's ruling of 2026-10-03); `1b`'s `· 0 LEAKS` was removed from both spec HTML files
  (`app-design.pdf` still shows it, and is not authoritative). Never add a leak
  count back, under that name or another. The blocked-request tally (Today,
  `5c`, and the container's blocked-today count) is a different number and
  stays.

Each plan repeats the subset of these it depends on in its own "Global
Constraints" section — that repetition is intentional so a plan can be read
standalone.

## Known cross-plan issues (must fix before executing)

A gap analysis on 2026-08-30 found the following. Fix these in the plan
files before running them, not during.

### Blocking

1. **✅ Fixed 2026-08-30. Plan 1 Task 6 Step 11: wrong import paths in
   `main.dart`.** The plan wrote `import 'ui/features/dashboard/dashboard_screen.dart'`
   and `import 'ui/features/dashboard/providers.dart'`, but the file
   structure puts them at `dashboard/views/dashboard_screen.dart` and
   `dashboard/view_models/providers.dart`. Fixed directly in the plan file.

2. **✅ Fixed 2026-08-30 (by flutter-app-1e). Plan 2 Task 8 (not Task 7 —
   that reference was stale): `session_controller.dart` was never written.**
   `AppGate` references `sessionProvider`, `SessionUnconfigured`,
   `SessionLocked`, `SessionOpen` and `SetupFlow`, but the plan only
   described them in prose and never provided implementation code. Now
   written in full — `sealed class Session`, `SessionController extends
   Notifier<Session>` with `unlock`/`graceExpired`/`completeSetup`, plus the
   supporting providers (`vaultStoreProvider`, `cryptoServiceProvider`,
   `documentsDirectoryProvider`, `vaultOpenerProvider`,
   `initialSessionProvider`, `setupControllerProvider`). `LockController`
   (Task 5) and `SetupController.complete` (Task 6) were also missing and
   are now written; `LockScreen` and `SetupFlow` — which the original plan
   implied belonged in Tasks 5/6 — were built in Task 8 instead, because
   both need `sessionProvider`, which only exists once Task 8's
   `session_controller.dart` does. Building them earlier would have left
   Tasks 5/6 unable to compile standalone. See Plan 2 Task 8 Steps 6–22 for
   the full diff, and "Rulings recorded while fixing issue #2" below for the
   design calls made along the way.

3. **✅ Fixed 2026-08-31 (by flutter-app-6d, as part of Plan 2 Task 4). Plan 1
   `Vault` vs Plan 2 `VaultId` naming collision.** Plan 1 defined
   `enum Vault { a, b }` in `app_database.dart`; Plan 2 defines
   `enum VaultId { a, b }` in `vault.dart`. Same concept, two names. Task 4's
   own Step 6 was written to fix exactly this, so it was resolved in the same
   commit as that task rather than separately: `Vault` is deleted,
   `vaultFileName` now takes `VaultId`, and the two call sites the plan
   didn't list (`lib/main.dart`'s `Vault.a`, and `test/data/repositories_test.dart`'s
   two `Vault.a`/`Vault.b` uses) were fixed too, since the analyzer flagged
   both once the enum was gone. `session_controller.dart` (Plan 2 Task 8)
   does not exist yet in the tree, so there was no `vaultDatabasePath` bridge
   to delete — Task 8 will simply never need one.

4. **✅ Fixed 2026-08-30 (by flutter-app-42). Plan 3 Task 1's schema
   migration and its test both targeted a phantom `openVault()` function
   that was never defined in any plan.** The original diagnosis of this
   issue (below, struck through) named the wrong function: Plan 2 never
   defines or calls `openVault()` anywhere — grep confirms zero hits. Plan
   2's real function is `openEncrypted({path, dataKey})`, and Plan 1's
   `AppDatabase.open` itself is only extended with an optional `password`
   parameter, never replaced. The actual bug was Plan 3 Task 1's test
   calling a phantom `openVault(Vault.a, path:, factory:)` that no plan ever
   defined. Fixed by swapping Plan 3 Task 1 to `AppDatabase.open` +
   `seedIfEmpty`, and giving the 8 seeded `Site(...)` calls a `profileId`
   (see issue #5) in that same task.
   ~~Plan 3 Task 1 schema migration targets Plan 1's `AppDatabase.open`, but
   Plan 2 has already replaced it with encrypted `openVault()` using
   `sqflite_sqlcipher`. Plan 3's `onUpgrade` code must be reworked to apply
   inside Plan 2's `openVault()`, not Plan 1's `AppDatabase.open`.~~

5. **✅ Fixed before this repo's history begins** (both are in the root
   commit `7f54e8d`; confirmed 2026-09-30). ~~Plan 3 Task 1 makes
   `Site.profileId` required, breaking Plan 2's call sites (decoy
   provisioner, tests). Plan 3 Step 7 acknowledges this for Plan 1 but not
   for Plan 2.~~ `Site.profileId` is required, and `provisionDecoy` gives
   each copied site a fresh `newProfileId()`, citing this issue
   (`lib/data/repositories/decoy_provisioner.dart`).

### Ordering / dependency

6. **✅ Fixed 2026-09-02 (commit `883e16f`, "implement panic against real
   containers"). Panic handoff between Plan 2 and Plan 3.** ~~Plan 2 creates
   `PanicService` as an interface; Plan 3 creates `wipe(profileId)`. Panic
   must call wipe *before* destroying data keys. No plan specifies how
   `PanicService` gains access to the profile-wipe capability after Plan 3
   ships. Plan 2's `PanicScreen`/`PanicService` (Task 7) are also not wired
   into `AppGate` yet — `AppGate`'s `switch` has no case for a panicked
   state.~~ `lib/data/services/container_panic_service.dart`'s
   `ContainerPanicService.trigger()` now does exactly that ordering:
   `engine.close()` each live session (a profile can't be deleted while a
   WebView is attached to it), then `engine.wipeAll()`, then
   `closeDatabase()`/`destroyVaults()` — containers die first, while their
   ids are still readable, keys die last. Wired via `panicServiceProvider`
   in `lib/ui/features/container/view_models/providers.dart`, and `AppGate`
   (`lib/ui/features/shell/views/app_gate.dart`) now has a
   `SessionPanicked(:final report) => PanicScreen(...)` case. Verified
   2026-09-04: `flutter analyze` clean, `flutter test` 223/223 passing.

7. **✅ Fixed 2026-08-30 (by flutter-app-42).** ~~Plan 3 Task 1's test calls
   `openVault`, which is a Plan 2 concept. Plan 3's header says "Depends on
   Plan 1" but actually also requires Plan 2.~~ Same fix as #4 — the test's
   phantom `openVault` call is gone.

### Implementation bugs found while executing (2026-08-31)

Found and fixed while three sessions executed Plan 1 Task 4/5 and Plan 2
Task 1 in parallel off `plan-01-foundation`, before merging back.

8. **✅ Fixed 2026-08-31 (by flutter-app-c7).** Plan 2 Task 1's reference
   code for `AttemptGate.recordFailure` only re-locked on failure counts
   that were exact multiples of `maxTries` (`total % maxTries == 0`), so a
   6th failure arriving after the 5th failure's lockout had already expired
   did not re-lock — failing the plan's own test "the penalty repeats for
   every further failure". Fixed in the plan file to `total >= maxTries`.

9. **✅ Fixed 2026-08-31 (by flutter-app-1e).** Plan 1 Task 5's reference
   code for `dashboard_body.dart` imported `dashboard_view.dart` as if it
   were in the same directory (`views/`), but Task 5's own Step 3 puts
   `dashboard_view.dart` in `view_models/` — `session_row.dart`'s Step 4
   code already imported it correctly as `../view_models/dashboard_view.dart`.
   Fixed the same way in the plan file.

10. **✅ Fixed 2026-08-31 (by flutter-app-ce).** Plan 4 Task 7's widget test
    for the Today screen (spec `5c`) asserts on all four category rows and
    all four site rows plus the total block simultaneously, with no scroll.
    The default 800x600 `flutter_test` surface is shorter than that content,
    so the sliver list never builds the last row (`Webmail`) into the
    Element tree and `find.text` finds zero widgets for it — not a
    visibility issue, an existence one. Fixed by widening the test's
    surface (`tester.view.physicalSize`) before pumping, in both the plan
    file and the implementation.

11. **✅ Fixed 2026-08-31 (by flutter-app-ce).** `AppToggle` is produced by
    Plan 2 **Task 6** (setup wizard and decoy provisioning), not Task 5 (PIN
    primitives and lock screen) — every other plan that consumes it (Plan 4
    Task 5's site sheet, Plan 5's intro/Task 1/Task 2/Task 5) cited "Plan 2
    Task 5." Task 5 does not produce `AppToggle` at all; it produces
    `PinDots`, `PinKeypad`, `LockBody`, `LockController`. Also fixed a
    second, independent numbering slip in Plan 4's own intro: it called its
    own site-sheet task "Task 6" in the "Depends on" line when the task list
    has it as Task 5, and listed Task 5 among the tasks with "none of that"
    extra dependency even though Task 5 is the one that needs `AppToggle`.
    Fixed all references in the Plan 4 and Plan 5 doc files. This means
    Plan 4 Task 5 and Plan 5 Tasks 1/2/5/6 are gated behind Plan 2 Task 6
    (setup wizard), which itself needs Task 4 (`VaultStore`) — a longer
    chain than the old "Task 5" citation implied.

12. **✅ Fixed 2026-08-31 (by flutter-app-ce).** Plan 2 Task 5's `LockBody`
    widget test overflows a `RenderFlex` by 20px in the `wrong` and
    `afterTimeout` moods — same root cause as issue #10, a different
    symptom: the default 800x600 `flutter_test` surface is landscape-shaped
    and shorter than a real phone in portrait, and those two moods' extra
    footnote content doesn't fit the fixed `Expanded` region at that height.
    Verified a 400x800 portrait surface renders it with no overflow, so this
    is a test-canvas mismatch, not a real layout bug for the phone screens
    this app targets. Fixed by setting `tester.view.physicalSize` to a
    portrait size in `_pump`, in both the plan file and the test.

13. **✅ Fixed 2026-08-31 (by flutter-app-6d).** Plan 2 Task 4's own
    `vault_store_test.dart` reuses `FakeCrypto` from
    `test/domain/vault_unlocker_test.dart` (`show FakeCrypto`), but that
    fake's `randomBytes(length)` returned the same `List.filled(length, 7)`
    on every call — deterministic, not random. `VaultStore.provision` calls
    it once per salt, so vault A and vault B always got byte-identical
    salts, failing the plan's own test "the two slots have different
    salts." Separately, `FakeCrypto.deriveKek`'s simulated KEK length was
    `pin.length`-dependent (`'$pin|$saltJoin'.codeUnits`), so a 6-digit PIN
    and a 32-character generated `provisionUnopenable` PIN produced
    different-length wrapped keys — failing "both slots are the same size
    whether or not a decoy is real," the exact invariant the design depends
    on to keep a decoy indistinguishable from a real vault. Real Argon2id
    always emits a fixed-length key regardless of input length; the fake
    didn't model that. Fixed by making `randomBytes` counter-seeded (varies
    per call) and `deriveKek` a fixed-length (32-byte) hash of pin+salt
    (FNV-1a seed, splitmix64 expansion) — both only in the test fixture,
    `lib/domain/services/crypto_service.dart`'s contract is unchanged.
    Verified `vault_unlocker_test.dart`'s own 7 tests still pass, since none
    of them call `randomBytes` and `deriveKek`'s output remains a
    deterministic function of (pin, salt).

14. **✅ Fixed 2026-09-01 (by flutter-app-9c, landing Plan 2 Task 6).** Two
    bugs found verifying pre-existing uncommitted Task 6 work (StepProgress,
    AppToggle, the three setup screens, SetupController, decoy provisioner)
    that was sitting unstaged in the `worktree-plan-02-task6-setup-wizard`
    worktree against the plan's own tests:
    - `AppDatabase.open` (Plan 1) left sqflite's `singleInstance` at its
      default `true`, which caches a single connection per path. Both
      `decoy_provisioner_test.dart` and `setup_controller_test.dart` open two
      `AppDatabase`s at the literal `inMemoryDatabasePath` (one for the real
      vault, one for the decoy/second vault) — with caching on, both opens
      returned the *same* underlying connection, so provisioning "vault B"
      mutated vault A's tables via a self-referential `INSERT OR REPLACE` +
      `ON DELETE CASCADE`. Also security-relevant beyond tests: caching by
      path means reopening a vault file under a different password/data key
      would silently return the old connection instead of re-authenticating.
      Fixed with `singleInstance: false` in `AppDatabase.open`.
    - `FakeCrypto.wrap`/`unwrap` (`test/domain/vault_unlocker_test.dart`,
      reused by Task 6's `setup_controller_test.dart`) wrapped a data key as
      `[...kek, 0, ...dataKey]` and unwrapped by finding the first `0` byte.
      The KEK is 32 pseudorandom bytes and can legitimately contain `0x00`
      (~12% chance per unlock attempt), which made `indexOf(0)` find a
      spurious separator inside the KEK itself and reject a correct PIN —
      this is what made "both PINs actually unlock their own vault
      afterwards" flaky/failing for the decoy PIN specifically. Fixed with a
      length-prefixed encoding instead of a sentinel byte, in the test
      fixture only; `CryptoService`'s contract is unchanged.
    Verified full suite: 159/159 passing, `flutter analyze`: No issues found.

## Rulings recorded while fixing issue #2 (2026-08-30, flutter-app-1e)

Plan 2 Task 8 now documents these inline (Step 6 and Step 17); summarized
here for anyone scanning this file first.

- **`LockMood.welcomeBack` (spec `9b`) is reachable.** The original Task 8
  draft silently returned to the dashboard on any return within the grace
  period, never showing `9b` at all — dead code despite Task 5 fully
  building and testing it. Spec turn 9 lists exactly two on-resume outcomes
  (`9b`, `9c`), both lock-shaped; there is no "no screen" third outcome.
  `ReturnDestination.board` now means "come back to a screen that still
  trusts your open sessions" (`9b`), never "skip the lock screen entirely."
- **Decoy PIN entry has no screen of its own in the spec.** `4a`/`4b`/`5a`
  are the only three setup ids and `4b`'s step bar is fixed at three
  segments. `SetupFlow` reuses `SetupPinScreen` a second time for the decoy
  PIN rather than inventing a fourth screen or copy the spec never
  specified; the visible cost is the step-progress bar reading "step 1 of
  3" again during that reuse instead of a fourth segment. A real dedicated
  screen is a spec question, not a code fix.
- **`9b`'s "one tap to resume" caption is not literal.** `LockBody` (Task 5,
  already built and tested before this was noticed) renders the same
  six-dot row and full keypad for `welcomeBack` as every other lock mood.
  The built/tested widget was treated as authoritative over the option
  caption; resuming within the grace period still takes a full six-digit
  PIN. If literal one-tap resume is wanted, that is a `LockBody` change,
  not something invented at the wiring layer.

## Unassigned work (no plan owns these)

Plans 6 (Integration, written 2026-09-02) and 7 (Search, written 2026-09-04)
now own most of what this section used to list. What's left below is
genuinely unassigned; the rest is struck through with a pointer to the
task that covers it.

- ~~Search screen.~~ — Plan 7, all 5 tasks. Plan 6 explicitly deferred it
  (design spec's own scope decision); it now has its own plan and its own
  design spec (`docs/superpowers/specs/2026-09-04-search-screen-design.md`).
- **Biometric unlock.** Plan 2's settings shows the toggle; the actual
  Keystore-gated key mechanism is described in one sentence and unassigned —
  Plan 6 leaves the toggle wired to nowhere as well (see its Handoff).
  **Update, 2026-09-08:** design spec written and approved —
  `docs/superpowers/specs/2026-09-08-biometric-unlock-design.md`. Resume-only
  (never cold-unlocks, to avoid conflicting with the coerced-unlock threat
  model), Keystore RSA keypair with the private key gated by biometric auth,
  ciphertext held in memory only. Also wires `SettingsScreen` itself into
  navigation for the first time (a `⋯` icon on `WorkspaceBar`) — every other
  row on that screen stays exactly as inert as it is today. No implementation
  plan yet.
  **Update, 2026-09-08 (done):** implemented, all 8 tasks —
  `docs/superpowers/plans/2026-09-08-biometric-unlock.md` — on branch
  `plan-08-biometric-unlock` off `plan-01-foundation` @ `af9f780`. `3d49654`
  fixed two pre-flight defects; `b538e85` added the `app_settings` table and
  `SettingsRepository` (Task 1); `35d238c`/`f0b3b1e`/`bb83fc2` added the
  Keystore-backed `BiometricPlugin` and its Dart bridge, including a
  `MainActivity` base-class fix found during review (Task 2); `6825d83`
  wired resume-only biometric unlock into `SessionController` (Task 3);
  `a5a34a2` gated `LockBody`'s fingerprint prompt to `welcomeBack` resume
  only (Task 4); `61809ae` added `SettingsController` for the biometrics
  toggle (Task 5); `c3d88f8` reached Settings from the dashboard via the new
  `⋯` overflow icon (Task 6); `6051730` made panic also destroy the
  biometric Keystore key (Task 7). Task 8's full verification pass
  (2026-09-08) re-ran the suite clean: `flutter test` 270/270 passing,
  `flutter analyze` "No issues found!". Two of the design's three "known
  gaps" held up on re-read (every other `SettingsScreen` row is still inert;
  no "unavailable"/"invalidated" copy exists anywhere) — the third didn't:
  the design and `SettingsScreen`'s own doc comment claimed the screen (and
  so the biometrics toggle) is unreachable from a decoy session, but Task
  6's `⋯` icon is wired identically for every open session and nothing
  anywhere checks `SessionOpen.vault` first — consistent with
  `databaseProvider`'s existing "no code anywhere asking which one that is"
  principle in `dashboard/view_models/providers.dart`, which a vault check
  would have broken. Task 8 corrected `SettingsScreen`'s doc comment to say
  so plainly rather than add new vault-distinguishing code no task
  specified; whether to actually restrict decoy reachability is left as an
  open design question for a future task, not decided here.
  **Update, 2026-09-08 (final review — merged):** the whole-branch review
  this table entry never recorded a verdict for (the reviewing session
  ended before writing one) found the implementation above **not** safe to
  merge as-is: `SessionController._rewrapIfEnabled` called
  `BiometricService.wrap` with no error handling and never regenerated the
  Keystore keypair, so a correct PIN entered after Android invalidates the
  key (e.g. a new fingerprint enrolled) threw out of `unlock()` and left
  the user **permanently locked out of a correct-PIN vault**, with no
  in-app recovery — the design spec's own "Failure modes" section specifies
  exactly the self-heal (regenerate-then-retry) that was missing. Separately,
  `BiometricService.isAvailable()` had zero call sites, so the spec's
  "hide/disable the toggle when unavailable" requirement was unimplemented.
  Both fixed in `6ce2a04`: `_rewrapIfEnabled` now retries once after
  regenerating the keypair and fails closed (returns null, never throws)
  if that also fails; a new `biometricsAvailableProvider` gates
  `SettingsScreen`'s toggle via `AppToggle`'s existing nullable `onChanged`.
  Re-reviewed clean, no new breakage, merged to `plan-01-foundation` at
  `6ce2a04`; `flutter test` 273/273 passing, `flutter analyze` clean on the
  merged result. The review also corrected the decoy-reachability finding
  above: **endorsed** as documentation-only (an identical Settings surface
  for both vaults is required by the coerced-unlock threat model, not a gap
  in it — divergence would itself be the tell), but flagged that the shared
  global Keystore alias (`container.biometric`) does let a decoy session's
  biometrics toggle delete the *real* vault's Keystore key — correcting this
  entry's earlier claim that decoy actions "cannot cross-affect the real
  vault" (true for confidentiality/data exposure, false for this one
  availability side-channel). The regenerate-on-demand fix above already
  neutralizes the practical damage (the real vault repairs itself on its
  next correct-PIN unlock); a per-vault Keystore alias
  (`container.biometric.a`/`.b`) is logged as a follow-up, not required for
  this merge.
  **✅ Follow-up done 2026-09-29 (branch `second/kind-cerf-0tso50`).** Each
  vault now has its own keypair, `container.biometric.<VaultId.name>`
  (`biometricAlias` in `BiometricPlugin.kt`, which refuses anything but `a`
  or `b`). Every `BiometricService` method except `isAvailable` takes the
  `VaultId`: the settings toggle makes or destroys only the open vault's key,
  a PIN unlock re-wraps under the unlocked vault's key, and resume unwraps
  with `SessionLocked.biometricVault`'s. Panic calls the new
  `destroyAllKeyPairs`, which deletes both vaults' keys *and* the old shared
  `container.biometric`, each attempted even if another throws, so panic from
  either vault clears everything. `generateKeyPair` also retires the old
  shared alias: ciphertext under it lived only in memory, so none survives
  the update. Anyone upgrading with biometrics on needs no migration, because
  the first PIN unlock finds no per-vault key and the existing self-heal
  regenerates one. Tests: `BiometricAliasTest` (Kotlin, 4); Dart tests that
  turning biometrics off in the decoy leaves the real vault's key, on makes
  only the decoy's, a decoy-PIN unlock re-wraps under the decoy's key, resume
  unwraps with the backgrounded vault's key, and panic from the decoy clears
  both. Each of those fails when the shared-key behaviour is put back.
  Verified 2026-09-29: `flutter analyze` clean, `flutter test` 369/369,
  Kotlin JVM tests 60/60 (read from the JUnit XML), `flutter build apk
  --debug` succeeding. **Not verified on a device**: the Keystore calls
  themselves cannot run on the JVM.
  **Device-verified 2026-09-29 (emulator, merged to `main`).** Which keys
  exist was read through the VM service by calling the app's own `wrap`
  channel method per vault (it never prompts, and fails with "biometric
  keypair not generated" when the alias is missing): none after setup; only
  the real vault's after turning biometrics on there; both after turning it
  on in the decoy; **the real vault's still present after turning it off in
  the decoy**; neither after panic, which showed `3c` with the app still up.
  That run also found that **biometric resume had never worked on any
  device**: the cipher used RSA-OAEP with MGF1-SHA-256, the Keystore key only
  authorizes MGF1-SHA-1 (the only MGF1 digest a key can have before API 35's
  `setMgf1Digests`), so every decrypt failed with `INCOMPATIBLE_MGF_DIGEST`
  and `unwrap` silently replied null. No prompt ever appeared. **✅ Fixed
  (`85a3d96`, branch `fix-biometric-oaep-mgf1`):** both directions share
  `biometricOaepParams` (SHA-256 OAEP, MGF1-SHA-1), pinned by
  `BiometricOaepTest` (Kotlin, 3). Seen on the emulator with an enrolled
  fingerprint: `9b` shows the system prompt and a sensor touch resumes the
  vault, both right after enabling biometrics and after a PIN unlock's
  re-wrap. Don't change the MGF1 digest back: the JVM tests cannot catch it.
- ~~Wiring Plan 4's screens to Plan 3's events~~ — Plan 6 Tasks 2–4
  (`engine_events.dart`, discriminated `EngineChannel` events, `ContainerRoute`).
  Known gap: a backgrounded (non-foreground) site's events are dropped, not
  queued — no notification centre exists.
- ~~Reader mode extraction~~ — Plan 6 Task 5 (`extractArticle`). Known gap:
  the heuristic is honestly approximate outside typical article-shaped pages.
- ~~FilterEngine category tagging~~ — Plan 6 Task 1 (schema v5,
  `FilterListCategory`) and Task 3 (categorized Kotlin `FilterEngine`).
- ~~Download interception~~ — Plan 6 Task 3 (`ContainerView`'s
  `DownloadListener` → `download` event). Known gap: downloads are held,
  never actioned — no `DownloadManager` integration, matching the design
  spec's own stated scope. **Update, 2026-09-09:** real
  `DownloadManager`/`MediaStore`/private-directory integration now exists
  behind the held-download sheet's three actions (keep in container, save to
  device, discard), implementing
  `docs/superpowers/specs/2026-09-08-download-manager-integration-design.md`
  via `docs/superpowers/plans/2026-09-08-download-manager-integration.md`.
  `ProxyHttpClient` (new) centralizes the same Route-aware fetch
  `RequestInterceptor` already used for page loads, so a download's bytes
  always travel the site's actual route — refused exactly like a page load
  would be, never silently sent unproxied. `DownloadFetcher` (new) resolves
  each sheet decision: "keep in container" streams into
  `context.filesDir/downloads/<profileId>/` and opens the result via a new
  `FileProvider` (`res/xml/file_paths.xml`); "save to device" uses a manual
  fetch + `MediaStore` insert on a Proxy-routed site (the system
  `DownloadManager` cannot speak through this app's per-site proxy routing)
  and the real system `DownloadManager` on a Direct-routed site.
  `EngineChannel` gained a `resolveDownload` case and a `download_result`
  event feeding `ContainerRoute`'s outcome snackbar. Every wipe path
  (`ContainerView.dispose`'s `wipeOnExit`, the `wipe` case, and `wipeAll()`)
  now also deletes kept-in-container downloads — note `wipeAll()` deletes the
  whole `downloads/` tree inline rather than calling `deleteDownloadsDir`
  per profile, so don't "simplify" that line away.
  **Executed 2026-09-09 across three parallel sessions; Task 7 is NOT fully
  verified and this entry deliberately does not claim it is.** What is
  verified at `40a972f`, with a clean tree: `flutter analyze` clean,
  `flutter test` 299/299, `flutter build apk --debug` succeeding. What is
  not: Task 7 Step 4's two manual on-device checks were never run (no
  emulator/device in this environment), so the feature's core path is
  unvalidated end to end. **Update, 2026-10-02: both checks seen on the
  emulator** (see "Device verification (2026-10-02)"): a direct "save to
  device" reached `/sdcard/Download` through `DownloadManager`, and a site's
  `downloads/<profileId>/` was gone after its wipe. The same run found
  **proxied "save to device" had never worked**: `saveViaMediaStore`'s temp
  file prefix `"dl"` is under `File.createTempFile`'s three-character minimum,
  so it threw before fetching anything (fixed there). Commits: `5a27dbf` (Tasks 1–6, recovered as
  uncommitted orphan work — one commit rather than the plan's six, because
  the changes interleave within shared files), `5e970f5` (the
  `ContainerView` Context fix), `deb70aa` (defect documentation), `40a972f`
  (Task 3's tests).
  **Two defects remain open and unfixed — see the plan's own "Defects found
  while executing" section:** (1) **the engine performs no TLS at all**, so
  "keep in container" fails for every `https://` download and only
  Direct-routed "save to device" works (the OS does its own TLS there);
  `RouteFailure.TLS_FAILURE` has an enum entry, a channel mapping, and
  user-facing copy, but its only producer is an `SSLException` catch that can
  never fire — evidence it was designed and dropped, not scoped out. (2)
  whether Android supports `Proxy.Type.HTTP` for a raw `Socket` is an open
  question, deciding whether the HTTP-proxy route tunnels via CONNECT or is
  non-functional. *(That question is answered: it does not support it. It
  became defect (a) below, and Plan 10 then wrote the CONNECT by hand.)*
  Defect 1 was documented first and then, the same day, fixed
  at `9c598a1` after the user reversed the "document now, fix later"
  decision: `ProxyHttpClient.fetch` takes a `secure` flag and wraps the
  connected socket in an `SSLSocket` for https, with
  `endpointIdentificationAlgorithm = "HTTPS"` set before the handshake —
  the load-bearing line, since Android's default `SSLSocketFactory` validates
  the cert chain but not that the cert belongs to the host. Wrapping on top
  of `Router.connect`'s socket makes it correct for Direct and SOCKS.
  The previously-unreachable `SSLException → TLS_FAILURE` branch is now live.
  **But TLS is compiled, not proven:** nothing in this repo has ever opened a
  socket to a real server, so the handshake and
  `endpointIdentificationAlgorithm`'s behavior on Android's provider are
  untested. (An earlier version of this entry claimed the TLS wrap also made
  the HTTP-proxy defect fail *safe* via hostname verification. That was
  **wrong** — an HTTP-proxy route never reaches TLS at all; see below. That
  correction described the tree as it stood; since Plan 10 an HTTP-proxy route
  *does* reach TLS, over the CONNECT tunnel, and `startTls` wraps against the
  target host — so hostname verification is against the destination, not the
  proxy.)
  **Two further defects were found here: (a) is fixed, (b) is open and
  unowned.** (a) **✅ Fixed 2026-09-09 by Plan 10 — HTTP proxy mode *was*
  non-functional on Android.** The original record is kept below because it is
  how the defect was found and why the interim fix exists; the fix note
  follows it. `Router.connect` built
  `Socket(Proxy(Type.HTTP, ...))`, and AOSP removed HTTP-proxy support from
  `java.net.Socket` — verified in
  `$LOCALAPPDATA/Android/Sdk/sources/android-36/java/net/Socket.java`, which
  throws `IllegalArgumentException("Invalid Proxy")` at construction. It was
  user-reachable (`ProxyMode.http`, and an "HTTP" chip in the add-site
  Network tab beside SOCKS5), so every such site failed on every page load and
  download; SOCKS5 and direct were unaffected. It was also **misreported** — the
  throw lands in `RequestInterceptor`'s catch-all and surfaces as
  `UPSTREAM_TIMEOUT`, "The destination did not respond," for a destination
  never contacted — and **fails late**, since `ProxyProbe` opens a plain
  socket to the proxy and succeeds, so the site looks healthy until it
  doesn't. **Interim fix, same day** *(since undone by Plan 10 — see the Real
  fix below; described here in the present tense it was written in)***:**
  `Router.resolve` and its Dart mirror
  `resolveRoute` refuse any non-`socks5` mode up front as `MISCONFIGURED`,
  so the failure is immediate and honestly labelled rather than a late bogus
  timeout; `RequestInterceptor` maps `IllegalArgumentException` the same way as
  defence in depth. This fixes the reporting, **not the feature** — an HTTP
  proxy still cannot work, and the reused "This site has no proxy configured"
  copy is still inaccurate (it has one; Android just cannot open it). Better
  copy would be a new string, which the spec does not provide. The "HTTP" chip
  in the Network tab was left in place because it is in the authoritative
  canvas spec — removing it is a design decision, not a bug fix. A real fix
  means implementing CONNECT by hand.
  **Real fix, 2026-09-09 (Plan 10, commits `64c0fa6`/`f6bd41b`/`5e42dd5`):**
  CONNECT is now implemented by hand in `HttpConnectTunnel.kt`, `Router.connect`
  routes `socks = false` proxies through it, and the `ca9552c` interim guard is
  undone on both sides — `Router.resolve` re-admits `http` **by name** (an
  unrecognised mode is still `MISCONFIGURED`, which is the property that guard
  protected), and the Dart mirror is deleted. So the inaccurate "This site has
  no proxy configured" copy is no longer shown for an http site, and a proxy
  that refuses CONNECT now reports `PROXY_REFUSED`, "The proxy refused the
  destination" — that failure's first producer ever. The "HTTP" chip is still
  in place and now backed by something that works. **Verified only by JVM unit
  tests against a localhost fake proxy and a clean APK build; it has never run
  against a real HTTP proxy on a real device**, and the Android-only
  `IllegalArgumentException` it fixes cannot even be reproduced on the desktop
  JVM those tests run on. See Plan 10's row and its known gaps. (b)
  `DownloadFetcher.fetchTo` passes no request headers, so keep-in-container
  sends neither `User-Agent` nor `Cookie` while `saveViaDownloadManager` sends
  both — a cookie-gated download succeeds via Direct save-to-device and fails
  via keep-in-container.
  **✅ Fixed 2026-09-28 on branch `fix-download-request-headers`.** Both
  download paths now build their headers in one pure function,
  `downloadRequest()` in `DownloadFetcher.kt`. The cookies come from **the
  site's own profile** (`ProfileManager.profileFor(...).cookieManager`), not
  `CookieManager.getInstance()`: that is the default profile's jar, which holds
  nothing an isolated site set, so the old `saveViaDownloadManager` was sending
  the wrong jar too. That profile lookup goes through androidx.webkit's
  UI-thread-only `ProfileStore`, so `DownloadFetcher.requestFor` is called from
  `EngineChannel.resolveDownload` on the platform thread, and only the
  network/disk work in `DownloadFetcher.run` goes to the executor. Don't move
  `requestFor` back inside `run`. Also fixed `ProxyHttpClient.fetch` sending
  `Host` without the port on non-default ports (RFC 9110 §7.2). It affected
  proxied page loads as well as downloads. Verified 2026-09-28: Kotlin JVM
  tests 23/23 (read from the JUnit XML; new `DownloadRequestTest` 7 and
  `ProxyHttpClientTest` 4), `flutter analyze` clean, `flutter test` 300/300,
  `flutter build apk --debug` succeeding. **Not verified on a device** — the
  UI-thread requirement in particular is from the library's contract, not
  observed. **Device-verified 2026-10-02 (emulator):** against a
  header-logging origin that serves a file only with its cookie, a direct
  site's keep-in-container refetch and its `DownloadManager` save both sent
  the site's own cookie and its WebView User-Agent, and both files arrived
  whole. That origin was plain HTTP, so the run used a local build with
  `usesCleartextTraffic` set (never committed; see the cleartext question in
  "Device verification (2026-10-02)").
  Standing lesson from this plan: `flutter analyze` and `flutter test` are
  Dart-only and never compile `engine/`, which is how Tasks 1–6 reached a
  commit having never been compiled. `flutter build apk --debug` is the only
  check that catches Kotlin errors here.
- ~~SiteSheet toggle persistence~~ — Plan 6 Task 6, **actually landed
  2026-09-28** (this bullet was struck through on 2026-09-04 while the task
  was still unexecuted). Known gaps: the desktop-view toggle only
  distinguishes `android` vs. `desktop`, so `UserAgentMode.minimal` loses
  that distinction once flipped; and a change applies the next time the site
  is opened, since `ContainerEngine` has no call to re-apply settings to a
  live view.
- ~~Decoy auto-sync after provisioning~~ — Plan 6 Task 6 gives `provisionDecoy`
  (not `syncToDecoy`, which never existed under that name) a real call path,
  but only *inside* the two-PIN setup wizard, where both vaults' data keys
  are simultaneously in memory. **Update, 2026-09-08 (done):** the
  reachable "re-sync with the decoy PIN" flow this bullet pointed to is now
  built — Plan 9, `docs/superpowers/plans/2026-09-08-decoy-resync.md`, all 5
  tasks. A new `resyncDecoy` function (add-and-remove, not `provisionDecoy`'s
  add-only) is reachable from a "Re-sync decoy now" row in Settings' VAULT
  section, gated behind a PIN-entry screen that checks the decoy PIN via the
  existing `VaultUnlocker`/attempt-gate before opening the decoy vault just
  long enough to sync and close it again.
- ~~**P2 — loopback authenticating proxy (next project; user's ruling
  2026-09-30).**~~ — Plan 13 (`2026-09-30-loopback-proxy.md`), done and
  device-verified 2026-10-02. The original note: All WebView traffic goes through `ProxyController` to an
  in-app loopback proxy. Each site's WebView answers the proxy's 407 with
  random per-site credentials (`onReceivedHttpAuthRequest`), and the proxy
  routes each connection by them. This closes preconnect (a1) even against a
  hostile page, and hands Chromium the HTTP work (cookies on proxied sites,
  redirects, POST bodies). It will not close dns-prefetch (a2): `ResolveHost`
  ignores proxies. It needs its own spec, which must first prove two
  assumptions: that the HTTP auth cache is isolated per profile, and that the
  407 callback reaches the app for subresource requests. See
  `docs/superpowers/plans/2026-09-30-proxy-leak-fixes.md` "Handoff".
- **Gaps Plan 10 (HTTP CONNECT tunnel) leaves open.** The mode works now; these
  are the edges it deliberately does not cover, recorded verbatim from that
  plan's Task 4 Step 3 so they are not rediscovered as bugs:
  - **No proxy authentication.** A proxy answering `407 Proxy Authentication
    Required` is reported as `PROXY_REFUSED` and the request fails. There is no
    credential storage, no `Proxy-Authorization` header, and no UI for either.
    Authenticated HTTP proxies do not work.
    **✅ Built by Plan 14 (proxy authentication, 2026-10-02):** a typed or
    per-site login, `Proxy-Authorization: Basic`, and `407` reported as
    `PROXY_LOGIN_REJECTED`. SOCKS is no longer delegated to the platform
    either: every SOCKS route uses `Socks5Tunnel`.
  - **No CONNECT for SOCKS.** Unchanged and correct — SOCKS is still delegated
    to the platform, which supports it.
  - **Untested against a real proxy.** Every test in Tasks 1 and 2 talks to a
    `ServerSocket` on localhost that replies with a canned status line. Real
    proxies vary in header handling, keep-alive behaviour and error bodies.
    This shares the limitation of the whole engine: **Task 7 Step 4 of the
    download-manager plan is recorded UNREACHABLE because no Android device is
    available here.**
  - **`ProxyProbe` still probes the proxy, not the tunnel.** `ProxyProbe.reachable`
    opens a plain socket to `host:port`, so a proxy that is up but refuses
    CONNECT to a given destination still reports reachable, and the site reads
    as correctly configured until the request fails. Narrower than before this
    plan — the failure is now named correctly rather than reported as a timeout
    — but the ordering is unchanged.

  Two further gaps came out of the branch review rather than the plan, both
  verified against the tree at `5e42dd5`. Task 4 recorded them unfixed because
  that task changes documentation only; **both were then fixed at `81a69f2`**,
  after an independent re-run of the four verification commands. The findings
  are kept as written because they record what the review actually caught —
  each carries its own resolution:
  - **`ProxyHttpClient.startTls`'s doc comment now asserts the opposite of what
    the code does.** It still reads "There is deliberately no CONNECT-tunnel
    case here … a `Route.Proxy` with `socks = false` throws
    `IllegalArgumentException` at socket construction and never reaches this
    function." Since `f6bd41b` that socket arrives on every `https` load through
    an HTTP proxy, and the enumeration just above it ("a direct socket or a
    SOCKS-routed one") is missing its third case. Behaviour is correct — the
    wrap uses the target host, so hostname verification is against the
    destination — but the stale sentence sits on the one function whose
    `endpointIdentificationAlgorithm` line the tunnel's security depends on,
    telling a future auditor the case cannot exist. A comment-only fix.
    **Fixed at `81a69f2`:** the enumeration now names all three socket kinds and
    the paragraph says the HTTP-proxy case does reach the function, and why that
    makes the certificate check meaningful on a proxied route. No code changed.
  - **`DownloadFetcher.failureFor` mis-names a direct site's `ConnectException`.**
    It mirrors `RequestInterceptor`'s mapping, but the two have different
    preconditions: `RequestInterceptor.fetchThrough` runs only for
    `Route.Proxy`, while `DownloadFetcher` applies the same lambda to
    `keepInContainer`, which runs for any route including `Route.Direct`. A
    refused connection on a direct-routed keep-in-container download therefore
    reports `PROXY_UNREACHABLE` and renders as "Cannot reach the proxy" for a
    site that has no proxy at all; before `5e42dd5` the reason was null and the
    user saw the accurate "Download failed". Gating the proxy-flavoured entries
    on `route is Route.Proxy` would fix it. Not a routing-constraint violation
    — nothing goes direct that should not — only copy accuracy on a path this
    branch newly made reachable.
    **Fixed at `81a69f2`:** `failureFor` now takes the route and maps a
    `ConnectException` to `PROXY_UNREACHABLE` only for a `Route.Proxy`, falling
    back to `UPSTREAM_TIMEOUT` ("The destination did not respond") for a direct
    one. That is the honest member of the five existing `RouteFailure` strings —
    a direct site's refused connection genuinely is the destination failing to
    answer. No copy was reworded and no enum value was added, since either would
    be a spec question rather than a bug fix.

## Device verification (2026-09-28, branch `device-verification-fixes`)

First time the app ran on Android at all: an `sdk_gphone64_x86_64` emulator,
driven through `adb`/`uiautomator`. Screenshots come back solid black because
the app sets `FLAG_SECURE` (`secure_window.dart`) — read the UI tree instead.
Every bug below passed `flutter test` and the JVM tests; each was invisible to
them for the reason given.

Fixed, each with a regression test except the manifest:
- `3d0a778` — **no `INTERNET` permission in the main manifest.** Flutter's
  template declares it only for debug/profile, so a release build could load
  nothing.
- `a42896d` — **`EngineChannel.open` probed the proxy on the main thread.**
  Android throws `NetworkOnMainThreadException`, `ProxyProbe` read that as
  unreachable, and every proxied site was refused. The probe now runs on the
  network executor; `PendingOpens` tickets stop an open overtaken by `close`
  or panic's `wipeAll` from registering late (and from recreating a profile
  panic just deleted).
- `7996a17` — **every site hung on the opening checklist.** `ContainerRoute`
  waited for `live` before building the view whose first load is what reports
  `live`; and `sessionForSiteProvider` read its snapshot before subscribing,
  losing a registration that landed in between. `FakeContainerEngine` had
  reported sessions as `live` immediately, hiding both — it now has
  `opensLive: false`/`markLive` for tests that need the real handoff.
- `339afcf` — **a failed keep-in-container download left a truncated file**,
  one more per retry. `writeDownload` writes a `.part`, checks
  `Content-Length`, rejects non-2xx, and renames only on success.
- `6a5f013` (branch `fix-lock-covers-routes`) — **locking or panicking left
  every pushed screen on top of the lock and panic screens.** `AppGate` is
  `MaterialApp.home` and the dashboard pushed containers, Settings, Search and
  Today onto the root navigator above it, so leaving `SessionOpen` swapped only
  the bottom route: a site stayed live over `LockScreen` with no PIN asked, and
  queued snackbars (`Decoy vault synced`) carried over too. The open vault now
  gets its own `Navigator` and `ScaffoldMessenger` inside `AppGate`
  (`_OpenVault`), so leaving `SessionOpen` tears everything down. **Accepted
  cost (user's call):** a `9b` return closes the open sites and lands on the
  dashboard after the PIN, not back inside the site. Seen on the emulator:
  `9b` covers a container and Settings, and Android back still pops a
  container. Don't move pushes back onto the root navigator, and don't add a
  `useRootNavigator: true` sheet or dialog — either reopens the hole.
- `cec9e45`..`56483c1` (branch `fix-panic-fails-open`) — **panic failed open,
  and no wipe of a used site ever worked.** Four bugs, each hidden behind the
  one before it because panic had never completed on a device:
  1. `cec9e45` — **WebView will not delete a profile this process has
     loaded.** Chromium's `AwBrowserContextStore::Delete` returns `kInUse` for
     any context with a live instance and never releases one, so every wipe of
     a site used since start threw "Cannot delete in-use profile": panic's
     `wipeAll`, `2c`'s "Close all and wipe", and — silently, swallowed in
     Flutter's platform-view dispose — every ephemeral site's wipe on exit.
     (It is not about the view being attached: detaching first was tried on
     the emulator and changed nothing.) `ProfileManager.wipe` now deletes when
     it can, otherwise journals the profile in
     `filesDir/pending-profile-deletions` (`PendingDeletions.kt`) and clears
     its cookies, web storage and geolocation grants in place;
     `MainActivity` sweeps the journal before anything can load a profile; a
     profile used again (`profileFor`) drops out of it. **Accepted gap:** what
     the profile APIs cannot clear (history, network state) stays on disk
     until the next start — unreachable from the app meanwhile. Don't
     "simplify" `wipe` back to a bare `deleteProfile`.
  2. `4f02968` — **panic's order was absolute.** A throwing container step
     aborted it before any key died. `ContainerPanicService.trigger` now runs
     container steps best-effort and always runs the three key steps.
  3. `66b5fad` — **`CryptoPlugin` replied `Unit`** for `destroyDeviceKey`,
     which `StandardMessageCodec` cannot encode: the app crashed mid-panic.
     Replies go through `channelReply`.
  4. `56483c1` — **panic never deleted the vault stores** (`PanicService`'s
     documented step 3), so the next setup opened the old ciphertext with a
     new key and hung on "file is not a database". Panic now deletes both
     stores after the keys; setup deletes any store it finds first.
  Seen on the emulator: panic from inside a site shows `3c`, the app stays up,
  `meta.bin` and `store-1.db` are gone, the loaded profiles are journaled, a
  cold restart leaves WebView with zero profiles, and setup works again; an
  ephemeral site's close journals its profile with no exception.

Seen working on the emulator: setup wizard with both PINs, lock/wrong-PIN/
unlock (`9a`), the encrypted vault surviving a reinstall, a direct HTTPS site,
an http-proxy site over the CONNECT tunnel (see Plan 10's row), the held
download sheet, and a direct-route save to device via `DownloadManager`.

Still open:
- **`2c`'s "Close all and wipe" leaves you on a dead container.** Now that the
  wipe no longer throws, `ContainerRoute.onCloseAllAndWipe` reaches its
  `Navigator.pop(context)` — which closes the switcher sheet on top, not the
  route under it, so the user lands on that site's opening checklist
  (`8a`) instead of the dashboard. `onCloseSession` likely has the same
  shape. Found 2026-09-28 verifying the panic fix; unowned.
  **✅ Fixed 2026-09-29 (`64d72ae`, merged to `main`).** `ContainerScreen`'s
  switcher now dismisses itself by its own context before reporting either
  close action, so the route's `Navigator.pop` pops the route; closing some
  *other* site's session no longer pops the route at all. Two widget tests
  push `ContainerRoute` over a stand-in home route and assert you land on
  it. The fix was found as uncommitted work in an agent worktree and
  committed during the branch merge. **Not verified on a device.**
  *(Seen once on the emulator 2026-09-29: closing the viewed site from the
  switcher's `×` landed on the dashboard. "Close all and wipe" was not
  tried.)* **Seen 2026-10-02 (emulator):** "Close all and wipe" landed on
  the dashboard, the site moved to IDLE, and its profile was journaled.
- **Keep-in-container over HTTPS fails mid-body on the emulator** with
  `SSLProtocolException: Read error` (BoringSSL `BAD_RECORD_MAC`), now
  reported as `TLS_FAILURE` with nothing left on disk. A standalone probe
  reproduced it on the emulator with a plain `SSLSocket` too, and the same
  probe on the host JVM succeeded 6/6 — so it is most likely the emulator's
  network, but that is unproven until it is tried on a physical phone.
  *(2026-10-02, during Plan 13's device run on the same emulator: a SOCKS5
  site's `https://www.w3.org/…/dummy.pdf` was kept in the container whole,
  13,264 bytes, and opened. One success does not show the failure is gone.)*
- **The held-download sheet showed "0 B"** for a 190 KB PDF. The size is
  `DownloadListener`'s `contentLength`, passed through unchanged; why it was 0
  was not investigated.
  **Cause found 2026-09-29 (from Chromium source, not seen on a device).**
  WebView never reports "unknown" as `-1` here: Chromium's
  `DownloadResponseHandler` sets `total_bytes = head.content_length > 0 ?
  head.content_length : 0`, and that is the value WebView hands
  `DownloadListener`. So `0` means "no length known", and which route the site
  is on decides why:
  - **Direct:** Chromium's own network stack fetches it, so `0` means the
    server sent no `Content-Length` (a chunked, or HTTP/2 streamed, response).
    The size is unknowable before the download without a request, and the app
    must not make one of its own.
  - **Proxied (SOCKS5 or HTTP):** `RequestInterceptor.fetchThrough` returns a
    `WebResourceResponse`, and WebView sets `content_length` from
    `InputStream.available()` on that body. Here that is the raw socket stream,
    so it reports however many bytes happen to be buffered: usually 0, never
    reliably the file size. The site's own `Content-Length` is appended as a
    header afterwards and never read back into that field, so the size is lost
    even when the server sent it.
  Spec `7c` has no copy for an unknown size (its only example is "1.4 MB ·
  from forum.example.com"), so the fix waited on a design answer.
  **✅ Fixed 2026-09-29 (branch `second/kind-cerf-0tso50`). User's ruling: an
  unknown size is left out, and the line reads "from forum.example.com".** No
  new words were added and no request is made. `heldDownloadSize` in
  `DownloadSize.kt` decides the size:
  - **Direct:** WebView's `contentLength` when it is above 0, otherwise
    unknown.
  - **Proxied (`proxyMode != "direct"`):** only the length the server
    declared. `RequestInterceptor.fetchThrough` records it per URL into the
    view's `DeclaredLengths` (in memory, bounded, gone with the view), and the
    `DownloadListener` takes it from there. A `Transfer-Encoding` or a
    non-identity `Content-Encoding` means no declared length.
  An unknown size crosses the channel as `null`, and `HeldDownload.sizeBytes`
  is `int?`. The listener cannot call `currentRoute()` to tell the two routes
  apart, because that probes the proxy on the main thread. Tests:
  `DownloadSizeTest` (Kotlin, 11), and on the Dart side the sheet's
  unknown-size line and the channel decoding `null`. Verified 2026-09-29:
  `flutter analyze` clean, `flutter test` 371/371, Kotlin JVM tests 71/71,
  `flutter build apk --debug` succeeding. **Not verified on a device**, and
  `RequestInterceptor`'s URL key matching the listener's URL comes from
  WebView's contract, not from observation.
  **Device-verified 2026-09-29 (emulator, merged to `main`)**, with a site
  whose URL is the file itself and a local Python CONNECT proxy for the
  http-mode cases: w3.org's 13,264-byte `dummy.pdf` (sends `Content-Length`)
  read "13.0 KB · from www.w3.org" both direct and over the tunnel, so the
  URL keys do match; `httpbin.org/stream-bytes` (chunked, no length) read
  "from httpbin.org" both direct and over the tunnel. The direct runs made no
  proxy connection; the proxied ones made one each.

Found while verifying the above (2026-09-29), both unowned:
- **The decoy vault's `+ Add site` crashes** when the decoy was set up with
  "Pick after setup" (no sites): the decoy vault has no workspaces, and
  `AddSiteScreen` takes `widget.workspaces.first`
  (`add_site_screen.dart:46`), so it throws `Bad state: No element` and shows
  a red error screen. That is a crash in exactly the session a coerced
  unlock opens. Which workspace an empty decoy should get is a design
  question, so this was not fixed.
  **✅ Fixed 2026-09-29 (branch `fix-empty-decoy-workspace`). User's ruling:
  the empty decoy gets a Personal workspace.** `ensureWorkspace`
  (`app_database.dart`) gives any vault with no workspaces a Personal one
  (keep storage, marker 0), and `SessionController` runs it on both `unlock`
  and `resumeWithBiometric`. It never asks which vault is open, so the real
  vault gets the same repair if its owner deletes every workspace, and an
  install that already has an empty decoy is repaired on its next unlock. Its
  id is fresh (`newProfileId()`), never a real-vault id such as
  `ws-personal`, so `resyncDecoy` counts it as decoy-original and never
  deletes it or the sites added to it; don't "tidy" that id into a fixed
  one. ~~**Known gap:** if the owner later flags the real vault's Personal for
  the decoy and re-syncs, the decoy shows two workspaces named Personal.~~
  **✅ Fixed 2026-09-29 (branch `fix-decoy-duplicate-personal`, raised by the
  ultrareview).** `resyncDecoy` now folds any decoy-original workspace with
  the same name as a synced one into it (`_mergeSameNamed`): its sites move
  over by `UPDATE`, keeping their ids, `profileId`s and script assignments,
  and the emptied row is deleted. The fix also found a **pre-existing
  re-sync bug**: an already-synced workspace was re-written with the
  repository's REPLACE upsert, whose delete cascaded to *every* site in it,
  so any site the owner added in the decoy inside a synced workspace was
  deleted on every re-sync. Such workspaces are now updated in place. Tests:
  six new in `decoy_provisioner_test.dart`; the cascade one fails on the old
  code.
  **Superseded 2026-09-29 (`9667f7f`, merged in `b95b6e0`):** the same
  REPLACE cascade was in the repositories themselves, so *editing* a
  workspace (rename, marker, "Show in decoy vault") deleted every site in it,
  and editing a site (the site sheet's switches, the edit form) dropped its
  script assignments. Seen on a device: the real vault's Personal lost all
  six sites. `SqliteWorkspaceRepository.upsert` and
  `SqliteSiteRepository.upsert` now go through `upsertRow`
  (`app_database.dart`), an `INSERT ... ON CONFLICT(id) DO UPDATE` that
  updates in place, and `resyncDecoy` uses the repository upsert again.
  Don't switch `upsertRow` back to `ConflictAlgorithm.replace` on any table
  that other rows reference with `ON DELETE CASCADE`: the cascade is
  silent.
  Tests: `ensure_workspace_test.dart` (5, including the re-sync case), two
  in `session_controller_test.dart`. `lock_screen_test.dart`'s resume test
  now lets the extra sqflite query finish in `tester.runAsync`. Verified
  2026-09-29: `flutter analyze` clean, `flutter test` 378/378, `flutter build
  apk --debug` succeeding. Seen on the emulator as an upgrade: the previous
  build set up with an empty decoy, then this build installed over it with
  data kept. The decoy dashboard read "Personal", `+ Add site` opened with
  WORKSPACE Personal, and a saved site appeared on the decoy board. Re-sync
  on the device was not tried; the unit test covers it against real SQLite.
- **A site reopened after its settings changed while its session was still
  open sometimes hung on `8a`'s "Connecting through 10.0.2.2:8888"**, with no
  request reaching the proxy. Leaving to the dashboard and opening the site
  again loaded it. Seen twice while switching a site's proxy mode; the exact
  steps were not pinned down and the cause was not investigated.
  **✅ Root-caused and fixed 2026-09-29 (branch `fix-connecting-hang`). It was
  worse than a hang: the reopened page loaded under the site's *old*
  settings, so a site switched from direct to a proxy went out direct.**
  Reproduced on the emulator with plain `https://example.com`: open it
  direct, back out (its session stays open), switch it to HTTP
  `10.0.2.2:8888`, reopen. It hung on the checklist with the page already
  rendered underneath and **zero** connections at the proxy. Cause:
  `sessionForSiteProvider` still held the previous visit's session, so
  `ContainerRoute` built `ContainerWebView` before its own `open` returned.
  `ContainerViewFactory` binds a view to whatever session the site has at
  creation (the old one, old config, and `RequestInterceptor` routes by that
  config). `open` then registered a new `Session` with no view. The new
  session only went live if the old view's first load happened to finish
  after that; `reload` and reader mode, which look up the new session's
  view, found null. Making the provider auto-dispose would not help: its
  snapshot would still return the old session until the new `open`
  registers. Fix: `ContainerRoute` shows only the checklist until its own
  `open` has returned (`_openReturned`), since by then the native map holds
  the new session. Test: `container_route_test.dart`'s "a reopened site
  builds no page view until its own open returns" (fails without the fix).
  Verified 2026-09-29: `flutter analyze` clean, `flutter test` 379/379,
  `flutter build apk --debug` succeeding; the same emulator repro now goes
  live with no overlay, every request goes through the proxy, and ⟳ reloads
  through it. Don't build the page view off a session the route did not
  open itself.

Found while device-verifying the script site picker (2026-09-29, branch
`feat-script-site-picker`), both fixed there:
- **Scripts and filters showed the vault as it was on the first visit.**
  `scriptsViewProvider` was a plain `FutureProvider` that nothing
  invalidated when a site was added or removed elsewhere, so a site added
  after Scripts had been opened once was missing from the picker, and its
  chip was silently dropped from a script's RUNS ON row. It is now
  `autoDispose`, so each visit reads the vault afresh (`a290bfa`).
- **A closed session went on reading as open.** `openSiteIdsProvider`, which
  the dashboard's OPEN NOW rows and `N SESSIONS`, search's live rail and
  `9c`'s closed-session count all read, was added to by `openSite` and never
  removed from: the switcher's ×, "Close all and wipe", `6c`'s close and
  wipe and `8c`'s close all left the site listed as open until the next
  lock. `closeSite`, beside `openSite`, now removes it on all four
  (`1f7f9a3`). Backing out of a container still leaves it open, which is
  correct, since its session keeps running in the background.
  *(Until Plan 15 only the session record stayed: backing out destroyed the
  page, and going back in loaded the stored address fresh. Since Plan 15 the
  page itself stays alive until its container is closed.)*

Plan 12 (browser chrome), device-checked 2026-09-30 on branch
`plan-12-browser-chrome` at `82c6b61` (Task 14 Step 7), by session
flutter-app-85. The proxies were one local Python script, SOCKS5 on `:1080`
and HTTP CONNECT on `:8888`, and the emulator's sockets came from `ss -tnpe`.
No Plan 12 code changed. Per check: 1 seen on SOCKS5, with the leak below;
2, 4, 6 and 7 seen; 3 seen on a direct route; 5 seen for Startpage, which is
slow behind a proof-of-work page, and not seen for Brave Search, whose bot
check this network cannot pass (`curl` from the host gets 429) — kept in the
picker by the user's ruling. Details are in the plan's "Device checks".
Found along the way, all older than Plan 12. The user chose on 2026-09-30 to
fix the first three next.
**✅ Fixed 2026-09-30 (branch `fix-proxy-leaks`, `5b00193`..`198cdda`,
session flutter-app-85), except the preconnect itself: see
`docs/superpowers/plans/2026-09-30-proxy-leak-fixes.md`.** Investigating found
the three were five: preconnect (a1), dns-prefetch (a2), requests sent as a
view is destroyed (a3), service workers never intercepted (a4), and WebView's
Autofill queries (b). Two further pre-existing bugs were fixed on the same
branch: chunked bodies handed to WebView raw (f), and case-sensitive response
header lookups (g).
- **A proxied site's `<link rel="preconnect">` goes direct.** Chromium opens
  a preconnect's socket without `shouldInterceptRequest`, so the app's own
  uid opened `48.222.183.128:443` (links.duckduckgo.com) directly one second
  after a DuckDuckGo load on a SOCKS5 site. A plain saved SOCKS5 site at
  duckduckgo.com does the same. It exposes the device's real IP, and via SNI
  the host, to any origin a proxied page preconnects to. This breaks "the
  interceptor never falls back to direct" in effect, if not in code.
  ~~**Still open — known gap, and the next project's (P2, under Unassigned
  work).**~~ **✅ Closed by Plan 13** (the loopback proxy). Seen on the
  emulator 2026-10-02: `links.duckduckgo.com` reached SOCKS5 by name through
  the loopback proxy, with no direct socket and no device lookup.
  dns-prefetch (a2, a DNS lookup only) is the same kind of leak, and stays
  the accepted gap: `ResolveHost` ignores proxies. Two neighbours found with it are fixed: a view's
  pagehide/unload requests went direct because `ContainerView.dispose`
  destroyed the WebView at once; a closing view now refuses everything, loads
  `about:blank`, and is destroyed after that finishes or after 1 s
  (`Teardown`, user's ruling: refuse). The closing flag is per view, not per
  interceptor, because a session outlives its views. Service workers were
  never intercepted, because the client was set on the default profile's
  controller and every site has its own profile; `routeServiceWorkers` now
  sets it per profile and the default profile refuses everything.
- **A direct IPv6 connection to Google** (`2001:4860:4842:400::`,
  `…4843:400::`, the googleapis range) from the app's uid during those
  loads, which DuckDuckGo's page does not reference. Its SNI could not be
  captured on a user-build image.
  **✅ Fixed.** It was Chromium Autofill server predictions
  (`content-autofill.googleapis.com`): WebView queries it for every form, from
  the browser process, and no WebView setting turns it off. At start,
  `ProxyController`'s reverse-bypass override sends that one host to
  `127.0.0.1:1` with no DIRECT fallback (`AutofillBlock.kt`; user's ruling:
  block). Seen: no lookup or socket for it; TCP `AttemptFails` +5 on a fresh
  form page, matching Chromium's 5 attempts.
- **Proxied routes resolve DNS on the device.** The SOCKS5 proxy only ever
  receives IP addresses.
  **✅ Fixed.** `Router.connect` passes the SOCKS target unresolved, so the
  proxy receives the hostname (seen: `duckduckgo.com:443`, `squoosh.app:443`
  at the proxy, with no device lookup). A SOCKS4-only proxy no longer works
  (user accepted: the mode is SOCKS5).
- **A proxied site keeps no HTTP cookies.** WebView ignores `Set-Cookie` on
  an intercepted response and `ProxyHttpClient` sends no `Cookie`, so "Keep
  for this site · Stays signed in" cannot hold an HTTP-cookie login on any
  proxied site. With Plan 10's unfollowed redirects, `httpbin.org/cookies/set`
  on SOCKS5 fails with `net::ERR_HTTP_RESPONSE_CODE_FAILURE`.
  **✅ Fixed by Plan 13.** Chromium now fetches proxied pages itself. Seen on
  the emulator 2026-10-02: on a SOCKS5 site, `postman-echo.com/cookies/set?p2=1`
  redirected and set the cookie, and `"p2":"1"` was still sent after a
  close-and-reopen with a fresh `CONNECT`, and after a `9c` lock. Downloads
  still go through `ProxyHttpClient`.
- The add-site form's `×` has no tap handler (system back works).
  **✅ Fixed 2026-09-30 (`693a5f5`, branch `fix-add-site-close`).** The `×`
  pops the form without saving, like `10b`'s; the canvas implies no discard
  confirmation. Test: `add_site_test.dart`'s "× leaves the form without
  saving". `flutter test` 521/521. **Not verified on a device.** *(Seen
  2026-10-02 on the emulator: an address typed, then ×, left no new site.)*

Proxy leak fixes (branch `fix-proxy-leaks`), device-checked 2026-09-30 on the
emulator, with DNS logged by pointing `-dns-server` at a logging forwarder on
the host. Seen: DuckDuckGo, a service-worker site (squoosh.app) and a pagehide
probe on SOCKS5 sent every request through the proxy by hostname, and the
device looked up nothing but the page's own preconnect/dns-prefetch hints (the
known gap); leaving a page sent nothing; no Autofill query went anywhere;
example.org rendered without its chunk sizes, and a `Content-type` page
rendered instead of being held as a download; panic still showed `3c` and
deleted the stores. Gates at `198cdda`: `flutter analyze` clean, `flutter
test` 520/520, Kotlin JVM 128/128 (JUnit XML; re-run independently by
flutter-app-77), `flutter build apk --debug` with zero `e:` lines. **Not
verified on a physical phone.** The emulator's vault was found wiped before
that run (stores gone, profiles swept — the shape a panic leaves); no session
reported touching it, and the cause is unknown.

**Site wipe (branch `fix-site-wipe`, 2026-09-30, session flutter-app-85).**

- **The row menu's "Wipe this site's data" (`7b`) was wired to nothing** (Plan 6's Known gaps: nothing decided what confirms a destructive wipe).
  - It now asks in `WipeSiteSheet`, with copy the user approved: "Wipe this site's data?" / "Its logins, storage and downloads are destroyed. The site stays in its workspace." / "Wipe" / "Cancel".
  - The sheet has no jade and opens on the open vault's own navigator. Cancel, a tap outside or back do nothing, and nothing is shown after a wipe.
  - Wipe runs `wipeSavedSite` (`lib/data/services/site_wipe.dart`): close the session, wipe the profile and its kept downloads, then **write the row back with a fresh `profileId`**. The site keeps its id, settings and script assignments.
- **Every close-and-wipe of a saved site goes through that helper**: `6c`, `2c` and `8c` (`ContainerRoute._closeAndWipe`). A throwaway has no row, so it is only closed and wiped.
  - Why the fresh id: a profile this run has loaded is only cleared in place (cookies, web storage, permissions), and the rest waits in the pending-deletion journal. Reopening the site under the same id took it off that journal, so its cache, history and network state survived every wipe.
  - **Known gap (ruling):** a wipe-on-exit site's automatic per-close wipe does not rotate. Only HSTS/alt-svc network state and history can survive it, and only if the site is reopened in the same run.
- **"Remove site" deleted only the row**, leaving the site's WebView profile (logins, storage, cache) and its kept downloads on disk, and an open session running. It now closes, wipes, then deletes (`removeSavedSite`, in `WorkspaceActions.delete`'s order). Its confirmation behaviour is unchanged (none).
- Commits `2a94e2c` (helper and 6c/2c/8c rotation), `60686d9` (Remove site), `5fe8391` (row-menu wipe and sheet), `07e1dec` (docs).
- Tests: `site_wipe_test.dart` 5, `container_route_test.dart` +4 (rotation on 6c/2c/8c, none for a throwaway), `dashboard_site_actions_test.dart` 3, `wipe_site_sheet_test.dart` 7.
- Verified: `flutter analyze` clean, `flutter test` 540/540, `flutter build apk --debug` with zero `e:` lines (no Kotlin changed).
- **Seen on the emulator:**
  - SpikeX's session was open. After the row-menu wipe, the sheet showed the approved copy. Tapping Wipe kept the row and took it off OPEN NOW (`0 SESSIONS`), and its old profile `8f9f47e6…` was journaled.
  - Reopening created a new profile `d05ba47e…`, and the old one stayed journaled.
  - Remove site on SpikeY deleted its profile (`4b77d5f1…`, not loaded that run) from disk and from WebView's registry at once.

## Controls that did nothing, decided and built (2026-09-30)

User's rulings of 2026-09-30, branch `second/modest-knuth-f83zbx`
(`9da830e`..`702f60a`). **None of it is verified on a device.**
**Update, 2026-10-02: most of it is seen on the emulator** (see "Device
verification (2026-10-02)"): Auto-lock shared between the vaults and `9c`'s
"1 minute" line, Change main PIN's refusal costing an attempt, setup refusing
a decoy PIN equal to the main one, Reader's Aa size kept, and flip-to-panic.
Not seen: ◑'s colours and the 40% dimming (screenshots are black under
`FLAG_SECURE`).

- **`2d` Settings.**
  - *Auto-lock* opens a picker: "After 1 min", "After 5 min", "After 15 min".
    `SessionController` holds the choice and uses it for `9b`/`9c` and `9b`'s
    deadline. `9c` reads "Locked after N minutes in the background" ("1
    minute" singular).
    **✅ One choice for both vaults (user's ruling 2026-10-01, branch
    `shared-auto-lock`).** It was first saved per vault, but the lock screen
    names it before any unlock, so a real vault on 15 minutes and a decoy on
    1 let someone compare the lock screen with the decoy's Settings and see
    there is a second vault. It now lives in the key file beside the slots
    (`VaultStore.autoLock`/`saveAutoLock`, key `autoLock`), so either vault's
    Settings reads and writes the same value. Panic deletes it with the key
    file. An `auto_lock` row a vault kept from the per-vault build is
    ignored, so an upgrade reads 1 minute until it is chosen again. Don't
    move it back into the vault databases.
  - *Change main PIN* is built (`ChangePinRoute`): current PIN ("Enter your
    PIN"), then the new PIN twice on setup's PIN screen without its step bar.
    `VaultStore.rewrap` re-wraps the same data key; the store is not
    re-encrypted. A new PIN that would also open the other vault is refused
    with "Choose a different PIN" and **costs an attempt**, and Change PIN's
    checks **never reset** the attempt gate. Either one lets a coerced decoy
    session guess the real PIN faster than the lock screen. Don't undo them.
  - *Hide from app switcher* and *Decoy vault*: on and inert (dimmed).
    *On panic*: its value only. *Sites shown in decoy* opens Workspaces.
  - *Trigger by flipping face down* is built, off by default, per vault
    (`panic_on_flip`): `FlipPanicGuard` around the open vault, and
    `FlipPanicPlugin`/`FlipDetector` in Kotlin (face down 2 s, re-armed only
    once back up).
- **Setup refuses a decoy PIN equal to the main PIN** ("Choose a different
  PIN"); before, that PIN opened only vault A, and the decoy never.
- **`6b` Reader:** Aa cycles three text sizes, ◑ a softer dark pair (dark
  only), saved per vault (`ReaderRoute`).
- **`10d`:** the "Update over the proxy · Next check · Update now" block is
  left out; the lists are bundled and the app makes no requests of its own.
- An inert `AppToggle` is drawn at 40% opacity.
- **Known gap (user's ruling 2026-10-01: leave it):** with a 5- or 15-minute
  Auto-lock, `9b`'s "locks in Ns" counts in seconds ("locks in 897s").

## Device verification (2026-10-02, branch `fix-proxied-save-to-device`)

Every executed item still marked "not verified on a device", checked on the
`Pixel_9` emulator (API 36, WebView 154; not a physical phone) with
`tool/device-check/proxy.py` for proxied routes. Session flutter-app-78.

**Fixed: proxied "Save to device storage" had never worked.**
`DownloadFetcher.saveViaMediaStore` made its temp file with
`File.createTempFile("dl", …)`, and Java refuses a prefix under three
characters, so every save on a SOCKS5 or HTTP site threw before fetching and
showed "Download failed" (the cause was read from a local build that logged
the exception). Now `deviceSaveTempFile` (`"download"` prefix), pinned by
`DeviceSaveTempFileTest` (Kotlin, 2), which fails on the old prefix with the
device's exact message. JVM tests could not catch it before: the function
needs an Android `Context`. Seen on the fixed build: a SOCKS5 site's PDF went
through the proxy by name and arrived whole (13,264 bytes) in
`/sdcard/Download`. Gates: Kotlin JVM 235/235 (34 JUnit XML files),
`flutter analyze` clean, `flutter test` 662/662, `flutter build apk --debug`
with zero `e:` lines.

Seen:
- **Downloads.** Keep-in-container on a direct and a SOCKS5 site wrote the
  file whole to `files/downloads/<profileId>/` and opened it in the system
  PDF viewer through the `FileProvider`; the row menu's wipe deleted that
  directory; a direct save reached `/sdcard/Download` through
  `DownloadManager`. A header-logging origin that serves a file only with its
  cookie saw the site's own cookie and WebView User-Agent on the
  keep-in-container refetch and on the `DownloadManager` request.
- **`2c`** "Close all and wipe" lands on the dashboard; **add-site's ×**
  leaves without saving.
- **Plan 6:** `6c`'s Desktop view persists, Edit opens the form, Workspaces
  create/rename/delete.
- **Plan 12's 2026-10-02 answers:** `Dismiss`, returning to a lower
  container, `münchen.de` opening as an address.
- **2026-09-30 controls:** setup refuses decoy = main PIN; Auto-lock set in
  the decoy reads the same in the real vault; `9c` reads "Locked after 1
  minute in the background"; Change main PIN refuses the other vault's PIN
  with "Choose a different PIN", and the next lock-screen failure read "3
  tries left", so the refusal cost an attempt; the changed PIN opens and the
  old one is refused; Reader's Aa size survives closing and reopening Reader;
  flip-to-panic (`adb emu sensor set acceleration 0:0:-9.8`) showed `3c` with
  the app still up and `meta.bin` and both stores deleted.

Not seen: Reader's ◑ colours, the 40% dimming, Force dark mode's effect,
deleting a workspace that has sites.

Found, open (none fixed here):
- ~~**Design question: `http://` sites cannot load.** The manifest has no
  `usesCleartextTraffic` (targetSdk 36), so WebView refuses cleartext, yet
  the address bar and the site form accept `http://`. A local build with the
  flag set loaded the same site. Either allow cleartext or refuse `http://`
  up front; that is the user's call.~~ **✅ User's ruling 2026-10-02: allow
  them** (branch `allow-cleartext`): the main manifest's `<application>` sets
  `android:usesCleartextTraffic="true"`. Seen on the emulator: a direct
  `http://10.0.2.2:8099/` site and a SOCKS5 `http://localhost:8099/` site
  (`SOCKS5 NAME localhost:8099` at the proxy) both rendered and finished
  loading. Gates: `flutter analyze` clean, `flutter test` 662/662, APK built.
  **Emulator caveat, not an app bug:** `http://example.com/` loads only
  some of the time there, failing with `ERR_INCOMPLETE_CHUNKED_ENCODING`.
  The emulator's network drops the **last byte** of a connection that the
  server closes right after its final segment: a raw request from `adb
  shell` with `toybox nc` (no app involved) got 755 of 756 bytes in 2 of 10
  tries, ending `0\r\n\r` with no final `\n`, and a debug build showed the
  loopback proxy receiving 411 of 412 body bytes from the origin. That loss
  likely also explains the "Keep-in-container over HTTPS fails mid-body on
  the emulator" note above. Don't "fix" `LoopbackProxy`'s close for it; test
  `http://` against an origin that doesn't close that way, or on a phone.
- ~~**"+ New workspace"** (`10a`) opens only from a tap on its text, not the
  row's centre: the bug `bf32358` fixed for "+ New script".~~ **✅ Fixed
  2026-10-02** (branch `fix-new-workspace-row`) the same way:
  `HitTestBehavior.opaque` on its row. `workspaces_screen_test.dart`'s "New
  workspace opens from anywhere on its row" fails without it. Not re-checked
  on a device.
- **"Trigger by flipping face down"**: a tap on the row's text does nothing;
  only the switch toggles.
- **A site whose address is itself a file** stays on `8a`'s checklist after
  its download sheet closes (the page never goes live), and its switcher does
  not open from there.

## Whole-codebase review (2026-10-05, branch `second/tender-mccarthy-sad3qc`)

A scheduled run reviewed all of `lib/` and the Kotlin layer, then fixed what it
found. **None of it is verified on a device** (no emulator in that session).
Gates on the merged tree: `flutter analyze` clean, `flutter test` 1008/1008,
Kotlin JVM 365/365 (48 JUnit XML files, `--rerun`), `flutter build apk --debug`
with zero `e:` lines.

- **Layout overflows** (`1bd3b24`). At 320x568, and at a 1.3 text scale,
  sheets, PIN screens, `4a`, `8b`, `3c` and many rows overflowed. Every
  `BottomSheetSurface` now scrolls its children (`scrolls: false` for a sheet
  with its own `Flexible` region: `6c`, the script site picker); the PIN and
  centred screens use `CenteredScroll`; the keypad is a little shorter under
  640 px high; long hosts and names ellipsize; `PillButton`'s height is a
  minimum. `test/ui/small_screen_layout_test.dart` guards the worst cases.
  Test fonts are much wider than Figtree, so a sweep (a temporary
  `test/flutter_test_config.dart` setting every test's view to 320x568)
  overstates real overflows; it found 0 after the fix at 1.0 and 1.3.
- **Data layer:** re-sync rescues decoy-owned sites from an unflagged
  workspace's cascade and wipes the profiles of removed decoy sites; the decoy
  store closes in a `finally`; `meta.bin` is written to a temp file and
  renamed, with its read-modify-writes queued; panic's three key steps each
  run even if one throws; `triesLeft` is 0 once the lockout repeats; scripts
  save through `upsertRow`; unknown engine events decode safely.
- **Kotlin:** a kept download cannot land or open after its site's wipe or
  panic (`DownloadWipes`); HTTP heads and chunk lines are bounded
  (`HttpHead.kt`); failed fetches close their sockets; the loopback accept
  loop backs off; a direct site is never probed; CONNECT EOF before the blank
  line fails; reader extraction always replies; MediaStore saves use
  `IS_PENDING`; per-engine plugins are released; the unused all-zero
  `CryptoCore.deviceKey()` is gone.
- **UI logic:** one PIN submit at a time and `unlock` serialised (overlapping
  wrong PINs counted once before); dismissing `6a`/`7c` answers "keep
  blocked"/discard natively; Save runs once in `2a`, `10b`, `10e`; deleting the
  last workspace leaves a fresh Personal one (`2a` crashed); the row menu's
  Open works; `8b`'s form reopens a throwaway once; the decoy site count
  refreshes; a throwing open shows `8b` instead of spinning on `8a`.
  ~~**Copy caveat:** that `8b` uses `RouteFailure.misconfigured` ("This site has
  no proxy configured"), the nearest existing string; accurate copy for "the
  open failed" is a design question.~~ **✅ User's ruling 2026-10-05:** it is
  `RouteFailure.openFailed` (Dart only; Kotlin never names it), headline "This
  site could not be opened", detail "Something went wrong before the page
  loaded. The page was not loaded, so no request left your device." `8b` no
  longer offers "Open without the tunnel" for a direct site
  (`canOpenWithoutTunnel`), which only a failed open could show it for.
- **Follow-up the same day** (`294b087`..`560d600`): a tap on the text of
  "Trigger by flipping face down" or "Unlock with biometrics" toggles it (only
  the switch did); `2a`'s workspace chips scroll sideways with four or more
  (up to three still share the row); Block WebRTC also strips a same-origin
  child frame's window when the page reaches it through
  `contentWindow`/`contentDocument` (checked under jsdom only;
  `window.frames[i]` cannot be hooked, so the gap is narrowed, not closed); a
  site whose address is itself a file goes live on its download instead of
  staying on `8a` (`goesLiveOnDownload`). Gates: `flutter analyze` clean,
  `flutter test` 1010/1010, Kotlin JVM 368/368, APK with zero `e:` lines.
  None of it seen on a device.
- **Left open:** `wipeSavedSite`'s two writes are not one transaction
  (**accepted, user's ruling 2026-10-05**: the profile is rotated first, so a
  crash between them leaves only a stale "Last worked", never an unrotated
  profile; don't swap their order); the WebRTC frame hook needs a device
  check.
- **`7b`'s unbuilt rows are hidden (user's ruling 2026-10-05).** "Open in
  Ephemeral", "Duplicate into Work" and "Require PIN to open" did nothing and
  named hardcoded workspaces. They are no longer drawn, and `SiteRowAction`
  has no values for them; each comes back with its action. The menu shows
  Open, Edit settings, then the wipe group. `flutter analyze` clean, `flutter
  test` 1012/1012 (no Kotlin changed). Not seen on a device.
- **Two fixes ported from local branches before merging to `main`
  (2026-10-05).** `fix-pinch-zoom`'s pinch zoom (`Page.kt`: built-in zoom on,
  its +/- buttons hidden; seen on a physical phone) and `fix-unlock-hardening`'s
  "after a panic, a PIN is refused like a wrong one" (with `meta.bin` gone,
  `unlock` threw, so `3c`'s lock screen did nothing on a PIN; it now checks
  against `VaultStore.unopenableSlots()` in memory and writes nothing),
  merged into this branch's queued `_unlock`. That branch's other two commits
  (atomic `meta.bin`, one PIN check at a time) were superseded by `6744d77`
  and `c1d96d8`. Gates: `flutter analyze` clean, `flutter test` 1016/1016,
  Kotlin JVM 368/368 (49 JUnit XML files), `flutter build apk --debug`
  succeeding.

## Full app test (2026-10-05, branch `tor-early-stop-device-test`)

Every gate, then the app driven on the `Pixel_9` emulator (API 36, WebView
154; not a physical phone). Gates before the fixes: `flutter analyze` clean,
`flutter test` 1016/1016, Kotlin JVM 368/368 (49 JUnit XML files),
`flutter build apk --debug` succeeding; after them, `flutter test` 1025/1025
and analyze clean (no Kotlin changed).

- **Seen working:** wrong PIN refused with tries left; `9b` with the open
  count, `9c` "Locked after 1 minute", the decoy PIN opening the decoy; a
  direct site; a SOCKS5 site added through `2a` (the proxy got the hostname,
  and a cookie survived a close and a reopen over a fresh tunnel); changing
  it to HTTP closed the tunnel and reopened it in place over CONNECT;
  built-in Tor (`Connecting to Tor · N%`, then check.torproject.org's
  "Congratulations", Tor's lock released at the lock); a dashboard
  throwaway with its save bar; a `target=_blank` page nested in `2c`, back
  closing it to its opener; the bottom-bar fling both ways; keep-in-container
  (13,264 bytes, opened in the system viewer, wiped with its throwaway);
  Reader and its ◑ softer theme; Find; `6c`; Today; Settings.
- **Fixed, each seen on the emulator:**
  - **Force dark mode never worked on a phone in light mode** (`61f8215`).
    `values/styles.xml` was `Theme.Light`, and WebView darkens only under a
    dark theme. Both themes are dark now, and so is the application's own
    context, which every page's WebView is made on. Side effect: a page with
    its own dark styles (example.com) now shows them on every phone.
    `test/android_theme_test.dart` guards it.
  - **The dashboard's tab labels had a yellow double underline**: the bar sat
    outside any Material (`7d222e8`).
  - **Settings' values began mid-row** since `1bd3b24`'s loose `Flexible`;
    they end at the row's right edge again, as the canvas draws them
    (`53292f4`).
  - **A switch row's label did nothing**, only its switch toggled: `6c`
    (`6e374cf`), and `2a`'s Network/Privacy/Appearance tabs, the Default route
    screen, `10b` and setup's decoy switch (`f5ec3e2`). An inert switch's row
    stays inert.
- **Found, open:**
  - **WebView sends `X-Requested-With: com.mono.container` on every request**,
    on every route including Tor (seen in postman-echo's echoed headers, on a
    navigation and a `fetch`), naming this app to every site.
    `WebSettingsCompat.setRequestedWithHeaderOriginAllowList` would stop it,
    but `WebViewFeature.REQUESTED_WITH_HEADER_ALLOW_LIST` is unsupported on
    WebView 154, so it was tried and reverted. The loopback proxy sees only
    TLS tunnels, so it cannot strip it either. No fix known.
  - ~~**Copy questions:** `2a`'s Network tab reads "Local filter lists · 42
    rules matched today" for every site (the canvas's example number,
    hardcoded in `network_tab.dart`); `5b`'s "Sites you open in this workspace
    leave nothing behind when you close the app" shows for every empty
    workspace, keep-storage ones included (the canvas draws it for an
    Ephemeral one); editing a site opens a form titled "Add site".~~
    **✅ User's rulings 2026-10-05:** editing a saved site shows its real
    count, "Local filter lists · N rules matched today" ("1 rule"), N being
    that site's trackers and ads blocks in Today's in-memory tally
    (`BlockedTally.rulesMatched`); a new site and a throwaway show "Local
    filter lists" alone. `5b`'s sentence shows only for a wipe-on-exit
    workspace; a keep-storage one shows "Nothing here yet" alone. An edited
    site's form is titled with its name (its host if the name is blank); a new
    site, and a throwaway being saved (`savesAsNew`), read "Add site".
    `flutter analyze` clean, `flutter test` 1036/1036. Not seen on a device.
  - The dashboard's search field has no accessibility label (its hint is not
    exposed).
- **Not run:** panic (it wipes the test vault; last seen 2026-10-04), and
  `TorSpikeTest` (Gradle uninstalls the app after an instrumentation run,
  which destroys the vault's Keystore key).

## Responsiveness run (2026-10-05, same branch)

The whole suite was run with a temporary `test/flutter_test_config.dart` (not
committed) that loads the bundled Figtree and IBM Plex Mono, so text measures
as on a phone, and sets every test's screen: 320x568 at 1.0, 360x640 at 1.3
and 2.0, 412x915 at 2.0, 915x412 at 1.0. **No layout overflowed in any of
them**; every failure was a test finding nothing because, at a larger scale,
what it looks for is scrolled out of a lazy list. The 25 test files that set
their own size took no part. Then the emulator was checked at font scale 2.0,
at 360x640 dp with 1.3, and in landscape.

- **Fixed, each with a test that fails without it, seen on the emulator:**
  - **PIN screens in landscape hid their dots**: the keypad took the height
    and the dots sat below the fold of a short scroll region. User's ruling:
    in landscape the message and dots are on the left and the keypad on the
    right (`PinLayout`, used by the lock screen, setup's PIN step and the
    decoy PIN / Change PIN screen); portrait is unchanged.
  - **Tall sheets ran up under the status bar** in landscape and on short
    screens (`6c`, ☰, `6a`, `7c`, `10c`): every `isScrollControlled` sheet now
    sets `useSafeArea: true`.
  - **Monograms were clipped to one letter** at large text scales ("W" for
    "Wm"): `Monogram` scales its letters down to fit its square.
  - **`2a`'s tab labels broke mid-word** at 2.0 ("Networ / k"): one line,
    scaled down to fit, with 4 px between tabs.
  - **Counts of 1 read plural** (user's ruling: singular for 1, as `9c`'s "1
    minute"): `6c`'s "1 request", `9b`'s "1 session still open", "1 try
    left", `3c`'s "1 session destroyed", Today's "request blocked across 1
    site". `9b`'s headline lines are centred when they wrap.
  - Gates: `flutter analyze` clean, `flutter test` 1051/1051, debug APK built
    (no Kotlin changed).
- **Seen fine:** every other screen checked (`8a`, the container's bars, ☰,
  `6c`, the dashboard, Settings, `2a` Network) at 2.0 and at 360x640; the
  container and dashboard in landscape (the dashboard shows about two rows
  there, cramped but usable).

## Reload and route change while browsing (2026-10-05, same branch)

User's request and rulings of 2026-10-05, a change to the browser-chrome
spec's layout C (§6.1 had moved reload into the ☰ menu only):

- **Reload in the pill.** The stop × that shows while a page loads becomes a
  reload (`AppGlyph.reload`, labelled `Reload`) whenever it does not
  (`ContainerTopBar.onReload`). Reload is still in ☰ as well.
- **`6c`'s Proxy row opens the site's form on its Network tab**
  (`SiteSheet.onProxy`, `ContainerRoute._changeRoute`). Saved with a new
  route and the same cookie policy, the container reopens in place at the
  page it shows, unwiped (`reopenInPlace`, as `6c`'s switches); a changed
  cookie policy goes through `siteSaved` as Edit does (wipe on exit rotates
  the profile); otherwise nothing reopens. The site keeps its cookies across
  a route change, as editing its route always has: New identity is the clean
  start. On a throwaway the row does what `8b`'s "Change proxy settings"
  does, saving it as a site; that form now reads "Add site" (`savesAsNew`).
- Tests: the pill's reload and stop (`container_screen_test`), reload acting
  on the page and the Proxy row's reopen at the page shown, and no reopen
  when the route is unchanged (`container_route_test`), the row's tap
  (`site_sheet_test`). `flutter analyze` clean, `flutter test` 1056/1056.
- **Seen on the emulator:** the ⟳ starts a new document (DevTools
  `performance.timeOrigin`); on ExD at `?shown=1`, `6c` › Proxy › SOCKS5
  `10.0.2.2:1080` › Save reopened at `?shown=1` with the pill reading SOCKS5,
  and a reload went out as `SOCKS5 NAME example.com:443`; switching back to
  Direct the same way stayed at `?shown=1`. The first reopen rendered from
  WebView's cache with no request, as a reopened Keep site can.
- ~~**Found, open (older than this change):** `8c`'s Reconnect only clears the
  overlay (`clearTunnelDropped`); the page stays as it was, Chromium's error
  page included, until it is reloaded.~~ **✅ User's ruling 2026-10-05:
  Reconnect also reloads the page shown** (`ContainerRoute._reconnect`).
  Test: `container_route_test`'s "8c's Reconnect clears the overlay and
  reloads the page shown" (fails without it). `flutter test` 1057/1057.
  Seen on the emulator: PxS live over HTTP `10.0.2.2:8888`, the proxy
  swapped for one demanding a login, a reload showed `8c` over Chromium's
  error page; with the plain proxy back, Reconnect cleared `8c`, the proxy
  logged `CONNECT postman-echo.com:443`, and postman-echo's reply was back
  on the page.

## Reader left the page unstyled (2026-10-09, branch `fix-reader-live-page`)

Found on the emulator, older than Plan 6's Reader: `READER_JS` began by
removing every `script`, `style`, `nav`, `aside` and `footer` from the **live**
page, so once Reader closed the page stayed unstyled until a reload
(example.com turned left-aligned; Wikipedia lost its icons and banner styles).
It now strips a copy of the body (`document.body.cloneNode(true)`), dropping
`noscript` and `template` too, since a detached copy is not rendered. Checked
in Chromium (Playwright) on Wikipedia's Onion routing article: the old script
left 2 of the page's 18 stylesheets and removed 452 elements, the new one
changes nothing, and both extract the same paragraphs. `ReaderJsTest` (Kotlin,
2) fails on the old script. Kotlin JVM 380/380. Don't point the strip back at
`document`.

## Tor crashed in every release build (2026-10-09, branch `fix-release-build`)

Found on a physical phone (Xiaomi, Android 13), the first release build ever
run: every Tor start killed the `:tor` process with `NoSuchFieldError: no "J"
field "torConfiguration" in class TorService` (`Tor-api: The fieldID is
NULL`). Flutter's Gradle plugin turns R8 on for release, R8 renamed
`TorService`'s fields, and Tor's native code looks them up by name;
tor-android 0.4.9.13 ships no keep rules. Every device check before this ran a
debug build, which is not shrunk. `android/app/proguard-rules.pro` (which
Flutter's plugin hands R8 when it exists) keeps `org.torproject.jni.**`, and
`test/android_release_rules_test.dart` fails without it. Seen on the emulator
with release builds: before, the same `fieldID is NULL` death; after, Tor
bootstrapped and the DuckDuckGo onion loaded. `flutter analyze` clean,
`flutter test` 1162/1162. In the same release build panic from a site's top
bar reached `3c` and the old PIN was refused afterwards; panic reported not
working on the phone was not reproduced. **Device-check release builds too**:
anything reached by name (JNI, reflection) can break only there.

## One bar while browsing; panic only by flip (2026-10-10, branch `chrome-one-bar`)

The user's rulings of 2026-10-10, changing the browser-chrome spec's layout C
(`docs/superpowers/specs/2026-09-28-browser-chrome-design.md` §6.1, which had
the address pill and panic on top, back / forward / `N OPEN` / ☰ at the
bottom):

- **No bottom bar.** The open count and ☰ moved to the top bar, where panic
  was: the pill (light, case, host, reload/stop, shield), then the count — the
  number alone in an outlined box, `open-sessions-target`, still "Open
  sessions" to a screen reader — then ☰. The page reaches the foot of the
  screen; a throwaway's save bar sits there. Dashboard spec §9's fling between
  open containers moved to the top bar, with the same rule (at least the bar's
  height). `ContainerBottomBar` is deleted; `2c`'s header count takes its style
  from `ContainerTopBar.openCountStyle`.
- **Back and forward** are Android's own back (unchanged: back in the page
  first) and ☰'s first two quick actions, so its tile row reads Back · Forward
  · Reload · Find · Reader · Copy link, each dimmed and inert with no history
  that way. The user approved them as "the first two rows of ☰"; they are
  tiles in that sheet's first row, beside the other page actions, not list
  rows.
- **Why not all four buttons on the top bar (user's choice A of three):** at
  48 dp the four plus a pill holding reload, the shield and six characters of
  host need about 470 dp, so on every phone the pill would have put reload and
  the shield under the host.
- **No panic button anywhere.** Gone from the top bar, the address field, the
  find bar and `2c` (`panic_square.dart` deleted); `2c`'s "Close all and wipe"
  takes the full row. A panic starts only by flipping the phone face down
  (`FlipPanicGuard`, which calls the unchanged `panic(ref)`).
- **Flip-to-panic is on by default:** `panicOnFlipProvider` reads an unset
  `panic_on_flip` as on, so every existing vault that never set the switch has
  it on after updating; one where it was turned off keeps it off. Settings'
  copy is unchanged.
- **Layout:** the top, address and find bars' sides went from 12 to 8 dp. The
  pill's "about six characters" rule counted the pill's left padding twice and
  measured six characters as 6 em (about ten characters); it now subtracts
  only what is inside the pill and asks 4 em (about seven). So on a 360 dp
  phone at 1.0, reload and the shield stay beside the host. A host that does
  not fit wraps after its dots, as before; at large text the actions still
  move under it.
- Tests: `chrome_bars_test` (no panic on any bar; the count and ☰; the fling
  on the top bar), `top_bar_v2_test` (beside the host at 360 and 412 wide; the
  bar fits at 320x568 at 1.0/1.3/2.0, 360x640 at 1.3, 915x412),
  `address_and_menu_test` (Back and Forward tiles, dimmed with no history),
  `container_screen_test`, `container_route_test`, `switcher_sheet_test`,
  `flip_panic_guard_test` (a vault that never set the switch listens) and
  `settings_controller_test`. Found on the way: the count's box stretched to
  any height it was offered (`alignment:` on its `Container`), which made the
  fling's threshold 600 dp in a test; it is sized to the number now.
- Gates: `flutter analyze` clean, `flutter test` 1173/1173, Kotlin JVM 380/380
  (51 JUnit XML files; no Kotlin changed), `flutter build apk --debug
  --target-platform android-x64` with zero `e:` lines.
- **Seen on the emulator (debug build, not a physical phone):** a vault that
  never touched the switch showed it on and had the accelerometer listener
  registered; the bar is one row (pill, `1`/`2` count, ☰) with no panic and no
  bottom bar, the save bar at the foot; ☰'s Back and Forward moved between two
  local pages and Forward was dimmed with nothing ahead; `2c` had no panic
  tile; a fling right and left on the top bar switched between two open
  containers; flipping face down inside a site showed `3c` "2 sessions
  destroyed" with the vault files deleted and the app up. The emulator could
  not reach the internet that day (a raw connection from its shell timed out
  too), so pages came from `tool/device-check/pages.py`.

## Working on this repo

- ~~No git repo initialized yet, and Flutter isn't installed on this machine as
  of the last check — Plan 1 Task 1 Step 1 bootstraps both.~~ Both exist now;
  `main` tracks `origin/main` on GitHub.
- **GitHub is reachable again** (`git fetch` and `git push origin main`
  worked on 2026-10-02). On 2026-09-29 it was not: pushing failed, and a TCP
  connection to github.com:443 was "destination host unreachable". If that
  recurs, `flutter test` in a fresh checkout or worktree fails with "Building
  native assets failed", because the `sqlite3` package's native-assets hook
  downloads a prebuilt binary from GitHub. Copying in the main checkout's
  `.dart_tool/hooks_runner` works around it. Whether a fresh worktree now
  builds without that copy was not checked. Flutter and Gradle commands need
  the Bash sandbox disabled.
- Multiple Claude sessions may be working here in parallel; check in before
  starting implementation work on a plan another session may already have
  picked up (`ListAgents` / cross-session message), since there's no git
  history yet to reveal who's touched what.
- **Device checks** use the host-side harness in `tool/device-check/`
  (logging SOCKS5/CONNECT proxy, logging DNS forwarder, the app uid's socket
  watcher). Its README has setup and the Plan 13 Task 7 run sheet. Extend it
  rather than writing new scratch scripts.
- When resuming an unfinished plan, look for a `<!-- PART-2-APPENDS-HERE -->`
  style marker or a missing "Known gaps"/"Handoff" section at the end — that
  means the plan is incomplete, not that the work described in it is done.
- **Read "Known cross-plan issues" above before executing any plan.** Several
  plans contain blocking errors (wrong imports, missing files, schema
  migration targeting the wrong function) that must be patched first.

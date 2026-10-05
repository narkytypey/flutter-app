# Container — isolated web container for Android

A privacy-first Android browser where every site runs in its own **container**:
its own storage, its own proxy route, its own filter and script set. Nothing is
shared between containers, and the app makes no network requests of its own.

Flutter UI, Kotlin platform layer, Android only, dark theme only.

> **Status: work in progress.** There is no release build, no app-store
> listing, and no signed APK. The app has been driven on an Android emulator
> (API 36, WebView 154) and briefly on a physical phone; most features are
> verified there, and the gaps are recorded in `docs/superpowers/plans/`.

## What it does

- **Per-site isolation.** Each saved site gets its own WebView profile
  (cookies, storage, cache, permissions) through androidx.webkit's multi-profile
  API. Sites cannot see each other.
- **Per-site routing.** Direct, SOCKS5, HTTP CONNECT, or **built-in Tor**
  (Guardian Project's `tor-android`, run in process over a Unix socket, started
  only while a Tor container is open). A site set to a proxy that becomes
  unreachable is refused — the interceptor never falls back to direct.
- **A loopback authenticating proxy.** All WebView traffic goes through an
  in-app proxy that routes each connection by a random per-site credential, so
  Chromium does the HTTP and TLS work while the app still decides the route.
  This also closes preconnect leaks that `shouldInterceptRequest` cannot see.
- **Proxy logins.** Typed per site, or derived per site from its profile id —
  which gives each site its own Tor circuit.
- **Tabs.** Several pages per container, up to six, with a switcher listing
  every open container and its pages. Pages survive a trip to the dashboard
  and come back without reloading.
- **Filtering and scripts.** Three bundled rule lists (no updates fetched at
  runtime), per-category blocked-request tallies, and a script library you can
  attach to individual sites, injected scoped to that site's origin.
- **Security levels.** Standard / Safer / Safest, as a vault default and as a
  per-site override — in the spirit of Mullvad Browser, limited to what WebView
  can actually switch off (CSP on cleartext documents, no WebAssembly, no
  WebGL; at Safest, no JavaScript and no network images).
- **Two-vault decoy model.** Two separate encrypted SQLite stores, selected by
  which PIN unwraps them. No query filters rows for privacy, and no aggregate
  ever counts across both vaults. The threat model is a **coerced unlock**, not
  forensic disk imaging.
- **Panic wipe.** Closes every container, wipes every profile and its kept
  downloads, destroys both vaults' keys and stores, and clears Tor's state —
  best-effort at each step, so one failure cannot leave it half done. Reachable
  from the container chrome, and optionally by flipping the phone face down.
- **Privacy guarantees by construction.** No account, no sync, no analytics, no
  telemetry, ever. Fonts are bundled, never fetched. The only outbound
  connection the app itself makes is to the Tor network, and only when you
  choose Tor.

## Build and run

Requires the Flutter SDK (CI pins **3.47.2** stable, Dart `^3.13.2`), the
Android SDK, and JDK 17. Android `minSdk` 29, `targetSdk` 36.

```sh
flutter pub get
flutter run                  # on a connected device or emulator
flutter build apk --debug    # the only check that compiles the Kotlin engine
```

The debug APK is large (~240 MB) because Tor's native libraries are bundled for
every ABI.

## Tests

```sh
flutter analyze
flutter test                                  # Dart: ~1,050 unit and widget tests
cd android && ./gradlew :app:testDebugUnitTest # Kotlin: ~370 JVM tests
```

`flutter analyze` and `flutter test` are Dart-only and never compile the Kotlin
engine — `flutter build apk --debug` is what catches Kotlin errors. CI
(`.github/workflows/dart.yml`) runs all four on every push to `main`.

Host-side helpers for on-device checks (a logging SOCKS5/CONNECT proxy, a
logging DNS forwarder, a socket watcher) live in `tool/device-check/`.

## Layout

```
lib/
  domain/     models and pure logic (routes, filters, crypto contracts)
  data/       SQLite repositories, vault store, services
  ui/
    core/     design tokens, typography, drawn line icons, shared widgets
    features/ one directory per screen area, each split view_models/ and views/
android/app/src/main/kotlin/com/mono/container/
  engine/     WebView profiles, routing, tunnels, loopback proxy, downloads, Tor
docs/superpowers/
  specs/      approved design specs
  plans/      one implementation plan per subsystem, with its own verification
              record, known gaps and handoff notes
```

No code generation anywhere — no `build_runner`, `freezed` or `drift`, only
hand-written mappers.

## Design source of truth

The UI is transcribed from `Sandbox Container -canvas-.dc.html`, a 32-screen
canvas spec. User-facing copy comes from there verbatim and is never
paraphrased or re-capitalised. `CLAUDE.md` holds the working notes: what each
plan built, what is verified on a device, and what is still open.

## Known limitations

- Android only. No iOS, web or desktop target, and no light theme.
- DNS prefetch hints from a page are still resolved on the device; WebView's
  `ResolveHost` ignores proxies. Accepted gap.
- WebView sends `X-Requested-With: com.mono.container` on every request,
  naming the app to every site. The header's allow-list API is unsupported on
  current WebView builds, and the loopback proxy only sees TLS tunnels, so
  there is no known fix.
- Deleting a WebView profile the process has loaded is refused by Chromium, so
  such a profile is cleared in place and journaled for deletion at the next
  start. History and network state can survive until then — unreachable from
  the app meanwhile.
- Nothing has been audited by anyone. Don't rely on it where being wrong
  matters.

## Licence

No licence has been chosen yet, so all rights are reserved by default. If you
want to reuse any of this, open an issue and ask.

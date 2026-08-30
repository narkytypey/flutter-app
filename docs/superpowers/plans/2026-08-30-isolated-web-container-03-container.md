# Isolated Web Container — Plan 3: The Container

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A site opens in a genuinely isolated Android WebView, routed per-site through its own proxy, with trackers filtered and shields on — reachable from the dashboard through `2a`, `8a`, `2b` and `2c`.

**Architecture:** A thin hand-written Kotlin platform layer, not a WebView package. Each site gets its own `androidx.webkit` `Profile` (separate cookies, localStorage and cache), addressed by an opaque id stored in the vault. Resource loads are intercepted in Kotlin at `shouldInterceptRequest`, where the issuing WebView — and therefore the site — is known; that is what makes per-site routing real, and it is why `ProxyController` appears nowhere in this plan. The interceptor owns the fetch, so turn 8's rule is a property of the transport rather than a promise in the UI: when a route is unavailable the interceptor refuses, and no code path connects direct. Dart never sees a WebView; it sees a `ContainerEngine` interface with a fake that drives every widget test.

**Tech Stack:** Everything from Plan 1, plus `androidx.webkit:webkit:1.12.0` (the `Profile`/`ProfileStore` multi-profile API) and Kotlin coroutines. No WebView wrapper package, no code generation, no new Dart dependencies.

**Spec:**
- `Sandbox Container -canvas-.dc.html` — authoritative. Blocks `id="2a"`, `id="2b"`, `id="2c"`, `id="8a"`.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-01-foundation.md` — Plan 1. This plan consumes its tokens, typography, primitives, domain models and repositories, and fills two of its named seams (`leakCountProvider`, `onAddSite`).

---

## Global Constraints

Plan 1's Global Constraints apply in full and are not repeated here. Additions, and one amendment:

- **`minSdk` rises from 26 to 29.** Plan 1 permitted this ("Plan 3 may raise `minSdk`"). Per-site isolation depends on the multi-profile WebView API, which is not available below it.
- **Isolation is a precondition, not a feature.** If `WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)` is false at runtime, the app refuses to open containers and says so. It must never fall back to a shared profile. The product promise is "Each site gets its own storage"; a silent downgrade would make that sentence a lie on exactly the devices where it matters.
- **The interceptor never falls back to direct.** Turn 8: "never fall back to a direct connection on its own." When a site's route is unavailable, `shouldInterceptRequest` returns a refusal response. No code path in this plan opens an unproxied socket for a site whose `proxyMode` is not `direct`.
- **`ProxyController` is not used.** It is process-wide, so it cannot attribute a request to the container that issued it. If you find yourself reaching for `setProxyOverride`, you have lost per-site routing.
- **Profile names are opaque and stored, never derived.** A profile is named from a random 128-bit id held in the vault — never from the site's name, host or id. Deriving it from the host would put a list of visited sites in a namespace the vault does not control. Under the coerced-unlock threat model these artifacts sit in app-private storage and are not readable without root or adb, so this is defence in depth rather than a load-bearing boundary; it costs one column and one `Random.secure()` call.
- **Three bypass paths must be closed explicitly, because the interceptor cannot see them.** WebRTC negotiates over UDP and never reaches `shouldInterceptRequest`, so it leaks the real IP past any proxy. Safe Browsing pings Google directly. Both are closed in Task 5. Until they are, no screen may claim a container is fully tunnelled.
- **Interception is a chokepoint with known holes — see "What the interceptor cannot see" below.** Do not write copy anywhere in this plan that asserts total coverage.
- **Hardware permissions default to deny, silently.** Spec `2a`: "HARDWARE · ALL OFF BY DEFAULT". A container never receives camera, microphone, location or clipboard access unless its stored `Site` grants it. The permission prompt in `6a` is Plan 4's; this plan denies without asking.
- **Sessions remain runtime-only.** Plan 1's rule holds: open/idle state is never persisted. Killing the app ends every session.

### What the interceptor cannot see

Every guarantee this app makes about routing and filtering is enforced at `shouldInterceptRequest`. Anything that does not reach it is traffic the UI claims to route and does not. Treat this list as load-bearing, not trivia:

| Path | Reaches the interceptor? | Handling in this plan |
|---|---|---|
| Document, subresource, XHR, `fetch` | Yes | Routed and filtered normally |
| WebRTC | **No** — UDP, not a resource load | Disabled outright (Task 5) |
| Safe Browsing | **No** — WebView-internal | Disabled outright (Task 5) |
| WebSocket | **No** on Android WebView | Blocked by CSP injection (Task 5) |
| Service-worker-issued requests | Only via `ServiceWorkerController` | Same interceptor registered there (Task 5) |
| `<video>`/`<audio>` byte-range | Partially; range semantics are lossy | Documented gap, see Known Gaps |

The first two are closed. The third is closed by refusing the capability rather than routing it. The fourth is closed by registering the same interceptor on the service-worker path. The fifth is a real, open limitation and is recorded in Known Gaps rather than papered over.

---

## File Structure

```
android/app/build.gradle.kts                   minSdk 29, androidx.webkit
android/app/src/main/kotlin/com/mono/container/
  MainActivity.kt                              registers the platform view + channel
  engine/ContainerViewFactory.kt               PlatformViewFactory
  engine/ContainerView.kt                      one WebView, one profile, one site
  engine/ProfileManager.kt                     ProfileStore wrapper: create/delete/wipe
  engine/RequestInterceptor.kt                 shouldInterceptRequest -> routed fetch
  engine/Router.kt                             SOCKS5 / HTTP CONNECT / direct / refuse
  engine/FilterEngine.kt                       rule matching + per-session leak count
  engine/Shields.kt                            WebRTC, fingerprint JS, Safe Browsing, CSP
  engine/EngineChannel.kt                      MethodChannel + EventChannel plumbing
android/app/src/main/assets/shields/fingerprint.js   document-start noise shim
android/app/src/main/assets/filters/default.txt      seed filter list

lib/domain/models/site.dart                    MODIFY: shields, hardware, appearance
lib/domain/models/route_decision.dart          RouteDecision + RouteFailure
lib/domain/models/container_session.dart       ContainerSession + SessionPhase
lib/domain/models/open_step.dart               OpenStep + OpenStepState (screen 8a)

lib/data/services/app_database.dart            MODIFY: schema v2 + migration
lib/data/repositories/site_repository_sqlite.dart  MODIFY: new columns
lib/data/services/container_engine.dart        ContainerEngine interface
lib/data/services/container_engine_channel.dart    MethodChannel implementation
lib/data/services/fake_container_engine.dart   in-memory fake, drives every widget test

lib/ui/features/container/view_models/container_view.dart
lib/ui/features/container/view_models/providers.dart
lib/ui/features/container/views/opening_screen.dart       8a
lib/ui/features/container/views/container_screen.dart     2b
lib/ui/features/container/views/container_top_bar.dart    2b
lib/ui/features/container/views/container_toolbar.dart    2b
lib/ui/features/container/views/switcher_sheet.dart       2c
lib/ui/features/add_site/view_models/add_site_view.dart
lib/ui/features/add_site/views/add_site_screen.dart       2a
lib/ui/features/add_site/views/basics_tab.dart            2a
lib/ui/features/add_site/views/network_tab.dart           2a
lib/ui/features/add_site/views/privacy_tab.dart           2a
lib/ui/features/add_site/views/appearance_tab.dart        2a

test/domain/route_decision_test.dart
test/data/site_migration_test.dart
test/ui/features/opening_screen_test.dart
test/ui/features/container_screen_test.dart
test/ui/features/switcher_sheet_test.dart
test/ui/features/add_site_test.dart
android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt
android/app/src/test/kotlin/com/mono/container/engine/FilterEngineTest.kt
```

Two notes on boundaries. `Router` and `FilterEngine` are pure Kotlin with no Android types, so they are JVM-unit-testable without a device — deliberate, because they hold the two rules most worth testing (never fall back; count what you blocked). `ContainerView` owns exactly one WebView and one site; there is no manager holding a map of sites to views, because the platform-view lifecycle already gives one instance per container.

---

## Task 1: Extend the site model for screen `2a`

Plan 1's `Site` cannot express `2a`. Its Network, Privacy and Appearance tabs need fourteen fields that do not exist. Do this first — every later task reads them.

**Files:**
- Modify: `lib/domain/models/site.dart`
- Modify: `lib/data/services/app_database.dart`
- Modify: `lib/data/repositories/site_repository_sqlite.dart`
- Test: `test/data/site_migration_test.dart`

**Interfaces:**
- Consumes: `Site`, `CookiePolicy`, `ProxyMode`, `AppDatabase.open`, `seedIfEmpty` (Plan 1).
- Produces: `Site` gains `profileId`, `blockWebRtc`, `blockTrackers`, `antiFingerprinting`, `allowCamera`, `allowMicrophone`, `allowLocation`, `allowClipboard`, `userAgentMode`, `forceDark`, `openInReader`, `pageZoom`, `customCss`, `customJs`; `enum UserAgentMode { android, desktop, minimal }`; `String newProfileId()`; schema version 2.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/data/site_migration_test.dart
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('a seeded row carries the documented shield defaults', () async {
    final database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await seedIfEmpty(database);
    final db = database.db;

    final rows = await db.query('sites', limit: 1);
    expect(rows, isNotEmpty);
    final site = siteFromRow(rows.first);

    // Spec 2a: "HARDWARE · ALL OFF BY DEFAULT".
    expect(site.allowCamera, isFalse);
    expect(site.allowMicrophone, isFalse);
    expect(site.allowLocation, isFalse);
    expect(site.allowClipboard, isFalse);

    // Shields the spec draws as on.
    expect(site.blockWebRtc, isTrue);
    expect(site.blockTrackers, isTrue);
    expect(site.antiFingerprinting, isTrue);

    // Opaque profile id, never derived from the host.
    expect(site.profileId, hasLength(32));
    expect(site.profileId.contains(site.host), isFalse);
  });

  test('two sites never share a profile id', () async {
    expect(newProfileId(), isNot(newProfileId()));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/data/site_migration_test.dart`
Expected: FAIL — `allowCamera` is not defined on `Site`.

- [ ] **Step 3: Add the fields to `Site`**

In `lib/domain/models/site.dart`, above `class Site`:

```dart
/// Spec `2a`, USER AGENT. Three presets and no free-text field, because a
/// unique UA string is itself a fingerprint.
enum UserAgentMode { android, desktop, minimal }
```

Add to the constructor, in this order, after `required this.url,`:

```dart
    required this.profileId,
    this.blockWebRtc = true,
    this.blockTrackers = true,
    this.antiFingerprinting = true,
    this.allowCamera = false,
    this.allowMicrophone = false,
    this.allowLocation = false,
    this.allowClipboard = false,
    this.userAgentMode = UserAgentMode.android,
    this.forceDark = true,
    this.openInReader = false,
    this.pageZoom = 100,
    this.customCss = '',
    this.customJs = '',
```

And the fields, after `final String url;`:

```dart
  /// Names this site's WebView profile. Opaque, random, stored — never derived
  /// from [url] or [name]. See Global Constraints.
  final String profileId;

  final bool blockWebRtc;
  final bool blockTrackers;
  final bool antiFingerprinting;
  final bool allowCamera;
  final bool allowMicrophone;
  final bool allowLocation;
  final bool allowClipboard;
  final UserAgentMode userAgentMode;
  final bool forceDark;
  final bool openInReader;

  /// Percent. Spec `2a` shows `110%`; the slider spans 50–200.
  final int pageZoom;

  final String customCss;
  final String customJs;
```

Extend `copyWith` with one nullable named parameter per field, each falling back to `this.<field>`, matching the existing method exactly. Leave `operator ==` and `hashCode` keyed on `id` alone — do not widen them.

- [ ] **Step 4: Bump the schema and migrate**

In `lib/data/services/app_database.dart`, add `import 'dart:math';`, raise `version` from 1 to 2, and add this helper at top level:

```dart
/// 128 bits of entropy, hex-encoded. Used to name WebView profiles.
String newProfileId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
```

Add the fourteen columns to the `CREATE TABLE sites` statement in `onCreate` so a fresh install and a migrated install produce identical schemas:

```sql
              profile_id          TEXT    NOT NULL,
              block_webrtc        INTEGER NOT NULL DEFAULT 1,
              block_trackers      INTEGER NOT NULL DEFAULT 1,
              anti_fingerprinting INTEGER NOT NULL DEFAULT 1,
              allow_camera        INTEGER NOT NULL DEFAULT 0,
              allow_microphone    INTEGER NOT NULL DEFAULT 0,
              allow_location      INTEGER NOT NULL DEFAULT 0,
              allow_clipboard     INTEGER NOT NULL DEFAULT 0,
              user_agent_mode     TEXT    NOT NULL DEFAULT 'android',
              force_dark          INTEGER NOT NULL DEFAULT 1,
              open_in_reader      INTEGER NOT NULL DEFAULT 0,
              page_zoom           INTEGER NOT NULL DEFAULT 100,
              custom_css          TEXT    NOT NULL DEFAULT '',
              custom_js           TEXT    NOT NULL DEFAULT '',
```

The seed rows must now pass `profile_id: newProfileId()`. Then add `onUpgrade` beside `onCreate`:

```dart
        onUpgrade: (db, from, to) async {
          if (from < 2) {
            const columns = <String, String>{
              'profile_id': "TEXT NOT NULL DEFAULT ''",
              'block_webrtc': 'INTEGER NOT NULL DEFAULT 1',
              'block_trackers': 'INTEGER NOT NULL DEFAULT 1',
              'anti_fingerprinting': 'INTEGER NOT NULL DEFAULT 1',
              'allow_camera': 'INTEGER NOT NULL DEFAULT 0',
              'allow_microphone': 'INTEGER NOT NULL DEFAULT 0',
              'allow_location': 'INTEGER NOT NULL DEFAULT 0',
              'allow_clipboard': 'INTEGER NOT NULL DEFAULT 0',
              'user_agent_mode': "TEXT NOT NULL DEFAULT 'android'",
              'force_dark': 'INTEGER NOT NULL DEFAULT 1',
              'open_in_reader': 'INTEGER NOT NULL DEFAULT 0',
              'page_zoom': 'INTEGER NOT NULL DEFAULT 100',
              'custom_css': "TEXT NOT NULL DEFAULT ''",
              'custom_js': "TEXT NOT NULL DEFAULT ''",
            };
            for (final entry in columns.entries) {
              await db.execute(
                  'ALTER TABLE sites ADD COLUMN ${entry.key} ${entry.value}');
            }
            // A row that predates profiles still needs an opaque one.
            for (final row in await db.query('sites', columns: ['id'])) {
              await db.update('sites', {'profile_id': newProfileId()},
                  where: 'id = ?', whereArgs: [row['id']]);
            }
          }
        },
```

`profileId` is now a required constructor argument, which breaks every `Site(...)` call site that predates it — including Plan 1's own `seedIfEmpty` in this same file, which builds eight seed `Site`s. Add `profileId: newProfileId()` to each of the eight `Site(...)` calls in `seedIfEmpty` (the ones for `st-notes`, `st-webmail`, `st-forum`, `st-reader`, `st-bank`, `st-market`, `st-wiki`, `st-tickets`). Without this, `app_database.dart` does not compile and nothing in the project runs.

- [ ] **Step 5: Map the new columns**

In `lib/data/repositories/site_repository_sqlite.dart`, extend `siteToRow` and `siteFromRow`. Booleans are `INTEGER` 0/1, exactly as Plan 1 already does for `show_in_decoy`. `user_agent_mode` stores `.name` and reads back through:

```dart
UserAgentMode _uaFromName(String name) => switch (name) {
      'desktop' => UserAgentMode.desktop,
      'minimal' => UserAgentMode.minimal,
      _ => UserAgentMode.android,
    };
```

- [ ] **Step 6: Run the test and watch it pass**

Run: `flutter test test/data/site_migration_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 7: Run the whole Plan 1 suite**

Run: `flutter test`
Expected: PASS. Plan 1's `repositories_test.dart` constructs `Site`s and `profileId` is now required — fix those call sites with `profileId: newProfileId()`. If Plan 2 has already been implemented in this codebase, its test files (`test/data/vault_store_test.dart` and any other file constructing a bare `Site(...)`) construct `Site`s the same way and need the same fix — `profileId` is one shared class, and whichever plan lands second is the one that has to update the other's call sites. If anything else fails, the migration broke something an earlier plan relied on; fix it here, not later.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/models/site.dart lib/data/services/app_database.dart lib/data/repositories/site_repository_sqlite.dart test/data/site_migration_test.dart
git commit -m "feat: extend site model and schema for per-site shields and routing"
```

---

## Task 2: Route decisions, and the rule that there is no fallback

Pure Dart. This encodes turn 8's rule as a tested function before any Kotlin exists to get it wrong. The Kotlin `Router` in Task 5 mirrors it exactly.

**Files:**
- Create: `lib/domain/models/route_decision.dart`
- Test: `test/domain/route_decision_test.dart`

**Interfaces:**
- Consumes: `Site`, `ProxyMode`.
- Produces: `sealed class RouteDecision` with `RouteDirect`, `RouteProxy({String host, int port, ProxyMode mode})`, `RouteRefused(RouteFailure)`; `enum RouteFailure { proxyUnreachable, proxyRefused, upstreamTimeout, tlsFailure, misconfigured }`; `RouteDecision resolveRoute(Site site, {required bool proxyReachable})`; `String refusalMessage(RouteFailure)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/route_decision_test.dart
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site({
  ProxyMode mode = ProxyMode.socks5,
  String? host = '127.0.0.1',
  int? port = 9050,
}) =>
    Site(
      id: 's',
      workspaceId: 'w',
      name: 'Forum',
      monogram: 'Fr',
      url: 'https://forum.example.com',
      profileId: 'a' * 32,
      proxyMode: mode,
      proxyHost: host,
      proxyPort: port,
    );

void main() {
  test('a direct site routes direct', () {
    expect(resolveRoute(_site(mode: ProxyMode.direct), proxyReachable: false),
        isA<RouteDirect>());
  });

  test('a proxied site with a reachable proxy routes through it', () {
    final decision = resolveRoute(_site(), proxyReachable: true);
    expect(decision, isA<RouteProxy>());
    decision as RouteProxy;
    expect(decision.host, '127.0.0.1');
    expect(decision.port, 9050);
    expect(decision.mode, ProxyMode.socks5);
  });

  test('a proxied site with an unreachable proxy REFUSES, never direct', () {
    final decision = resolveRoute(_site(), proxyReachable: false);
    expect(decision, isA<RouteRefused>());
    expect((decision as RouteRefused).failure, RouteFailure.proxyUnreachable);
  });

  test('a proxied site with no host refuses as misconfigured', () {
    final decision = resolveRoute(_site(host: null), proxyReachable: true);
    expect((decision as RouteRefused).failure, RouteFailure.misconfigured);
  });

  test('unreachable and refused read differently to the user', () {
    expect(refusalMessage(RouteFailure.proxyUnreachable),
        isNot(refusalMessage(RouteFailure.proxyRefused)));
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/domain/route_decision_test.dart`
Expected: FAIL — `route_decision.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/domain/models/route_decision.dart
import 'site.dart';

/// Why a request was refused. These are distinguished because the user's
/// remedy differs: an unreachable proxy is a local problem, a refused one is a
/// policy problem at the far end. Spec `8b` currently says only "Proxy
/// unreachable"; the copy is Plan 4's to settle.
enum RouteFailure {
  proxyUnreachable,
  proxyRefused,
  upstreamTimeout,
  tlsFailure,
  misconfigured,
}

sealed class RouteDecision {
  const RouteDecision();
}

class RouteDirect extends RouteDecision {
  const RouteDirect();
}

class RouteProxy extends RouteDecision {
  const RouteProxy({required this.host, required this.port, required this.mode});

  final String host;
  final int port;
  final ProxyMode mode;
}

class RouteRefused extends RouteDecision {
  const RouteRefused(this.failure);

  final RouteFailure failure;
}

/// Turn 8: "never fall back to a direct connection on its own." A site that
/// asked for a proxy and cannot have one gets [RouteRefused]. There is
/// deliberately no branch that returns [RouteDirect] for such a site — if you
/// add one, you have removed the product's central guarantee.
RouteDecision resolveRoute(Site site, {required bool proxyReachable}) {
  if (site.proxyMode == ProxyMode.direct) return const RouteDirect();

  final host = site.proxyHost;
  final port = site.proxyPort;
  if (host == null || host.isEmpty || port == null) {
    return const RouteRefused(RouteFailure.misconfigured);
  }
  if (!proxyReachable) return const RouteRefused(RouteFailure.proxyUnreachable);

  return RouteProxy(host: host, port: port, mode: site.proxyMode);
}

String refusalMessage(RouteFailure failure) => switch (failure) {
      RouteFailure.proxyUnreachable => 'Cannot reach the proxy',
      RouteFailure.proxyRefused => 'The proxy refused the destination',
      RouteFailure.upstreamTimeout => 'The destination did not respond',
      RouteFailure.tlsFailure => 'The secure connection failed',
      RouteFailure.misconfigured => 'This site has no proxy configured',
    };
```

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/domain/route_decision_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/route_decision.dart test/domain/route_decision_test.dart
git commit -m "feat: route resolution that refuses rather than falling back to direct"
```

---

## Task 3: The `ContainerEngine` seam and its fake

Dart's whole view of the platform. Every widget test in Tasks 6–8 runs against the fake, so none of them need a device.

**Files:**
- Create: `lib/domain/models/container_session.dart`
- Create: `lib/domain/models/open_step.dart`
- Create: `lib/data/services/container_engine.dart`
- Create: `lib/data/services/fake_container_engine.dart`
- Create: `lib/data/services/container_engine_channel.dart`

**Interfaces:**
- Consumes: `Site`, `RouteDecision`, `RouteFailure`.
- Produces: `ContainerSession`, `SessionPhase`, `OpenStep`, `OpenStepState`, `openStepsFor(Site)`, `abstract interface class ContainerEngine`, `FakeContainerEngine`, `ChannelContainerEngine`.

- [ ] **Step 1: Write the session and step models**

```dart
// lib/domain/models/container_session.dart
/// Runtime-only. Never persisted — Plan 1's rule: sessions do not survive the
/// app closing.
enum SessionPhase { opening, live, background, refused }

class ContainerSession {
  const ContainerSession({
    required this.siteId,
    required this.phase,
    this.lastActiveAt,
    this.blockedCount = 0,
  });

  final String siteId;
  final SessionPhase phase;
  final DateTime? lastActiveAt;

  /// Rules matched in this session. Feeds spec `2a`'s "42 rules matched today"
  /// and fills Plan 1's `leakCountProvider` seam.
  final int blockedCount;

  ContainerSession copyWith({
    SessionPhase? phase,
    DateTime? lastActiveAt,
    int? blockedCount,
  }) =>
      ContainerSession(
        siteId: siteId,
        phase: phase ?? this.phase,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        blockedCount: blockedCount ?? this.blockedCount,
      );
}
```

```dart
// lib/domain/models/open_step.dart
import 'site.dart';

enum OpenStepState { pending, running, done }

/// One line of spec `8a`'s checklist.
class OpenStep {
  const OpenStep(this.label, this.state);

  final String label;
  final OpenStepState state;

  OpenStep withState(OpenStepState next) => OpenStep(label, next);
}

/// The checklist `8a` shows, built from what this site actually applies. Copy
/// is verbatim from the spec; the tunnel line interpolates the real endpoint.
List<OpenStep> openStepsFor(Site site) {
  return <OpenStep>[
    const OpenStep('Fresh session, no shared cookies', OpenStepState.pending),
    if (site.blockTrackers)
      const OpenStep('Filter lists loaded', OpenStepState.pending),
    if (site.antiFingerprinting)
      const OpenStep('Fingerprint noise injected', OpenStepState.pending),
    if (site.proxyMode != ProxyMode.direct)
      OpenStep('Connecting through ${site.proxyHost}:${site.proxyPort}',
          OpenStepState.pending),
  ];
}
```

- [ ] **Step 2: Write the failing engine test**

```dart
// test/domain/open_step_test.dart
import 'package:container/domain/models/open_step.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site({
  ProxyMode mode = ProxyMode.socks5,
  bool trackers = true,
  bool fingerprint = true,
}) =>
    Site(
      id: 's',
      workspaceId: 'w',
      name: 'Forum',
      monogram: 'Fr',
      url: 'https://forum.example.com',
      profileId: 'a' * 32,
      proxyMode: mode,
      proxyHost: '127.0.0.1',
      proxyPort: 9050,
      blockTrackers: trackers,
      antiFingerprinting: fingerprint,
    );

void main() {
  test('the checklist names the real endpoint', () {
    final steps = openStepsFor(_site());
    expect(steps.map((s) => s.label), [
      'Fresh session, no shared cookies',
      'Filter lists loaded',
      'Fingerprint noise injected',
      'Connecting through 127.0.0.1:9050',
    ]);
  });

  test('a direct site shows no tunnel line', () {
    final steps = openStepsFor(_site(mode: ProxyMode.direct));
    expect(steps.any((s) => s.label.startsWith('Connecting')), isFalse);
  });

  test('shields that are off do not appear', () {
    final steps = openStepsFor(_site(trackers: false, fingerprint: false));
    expect(steps, hasLength(2));
  });
}
```

Run: `flutter test test/domain/open_step_test.dart` — Expected: FAIL, then PASS once Step 1's files exist.

- [ ] **Step 3: Define the engine interface**

```dart
// lib/data/services/container_engine.dart
import '../../domain/models/container_session.dart';
import '../../domain/models/route_decision.dart';
import '../../domain/models/site.dart';

/// Everything Dart is allowed to know about the platform. No WebView type
/// crosses this line.
abstract interface class ContainerEngine {
  /// False when the device cannot isolate. The app refuses to open containers
  /// rather than sharing a profile — see Global Constraints.
  Future<bool> isolationAvailable();

  /// Creates the profile if absent and begins loading. Emits progress on
  /// [sessions]. Completes when the page is live or the route was refused.
  Future<ContainerSession> open(Site site);

  /// Destroys the profile's cookies, cache and storage. Called for
  /// `CookiePolicy.wipeOnExit` and by "Close all and wipe" in `2c`.
  Future<void> wipe(String profileId);

  Future<void> close(String siteId);

  /// Every live session. Spec `2c`'s drawer renders exactly this.
  Stream<List<ContainerSession>> sessions();

  Future<void> reload(String siteId);
}
```

- [ ] **Step 4: Write the fake**

```dart
// lib/data/services/fake_container_engine.dart
import 'dart:async';

import '../../domain/models/container_session.dart';
import '../../domain/models/route_decision.dart';
import '../../domain/models/site.dart';
import 'container_engine.dart';

/// Drives every widget test in this plan. Deterministic: no timers, no delays.
class FakeContainerEngine implements ContainerEngine {
  FakeContainerEngine({
    this.isolation = true,
    this.proxyReachable = true,
  });

  bool isolation;
  bool proxyReachable;

  final _sessions = <String, ContainerSession>{};
  final _controller = StreamController<List<ContainerSession>>.broadcast();
  final wiped = <String>[];

  void _emit() => _controller.add(_sessions.values.toList());

  @override
  Future<bool> isolationAvailable() async => isolation;

  @override
  Future<ContainerSession> open(Site site) async {
    final decision = resolveRoute(site, proxyReachable: proxyReachable);
    final session = ContainerSession(
      siteId: site.id,
      phase: decision is RouteRefused ? SessionPhase.refused : SessionPhase.live,
      lastActiveAt: DateTime(2026, 8, 30, 12),
    );
    _sessions[site.id] = session;
    _emit();
    return session;
  }

  @override
  Future<void> wipe(String profileId) async => wiped.add(profileId);

  @override
  Future<void> close(String siteId) async {
    _sessions.remove(siteId);
    _emit();
  }

  @override
  Stream<List<ContainerSession>> sessions() => _controller.stream;

  @override
  Future<void> reload(String siteId) async {}

  /// Test helper: put a session into the background without opening a page.
  void seedBackground(String siteId, {int blockedCount = 0}) {
    _sessions[siteId] = ContainerSession(
      siteId: siteId,
      phase: SessionPhase.background,
      lastActiveAt: DateTime(2026, 8, 30, 11, 58),
      blockedCount: blockedCount,
    );
    _emit();
  }

  void dispose() => _controller.close();
}
```

- [ ] **Step 5: Write the channel implementation**

```dart
// lib/data/services/container_engine_channel.dart
import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/models/container_session.dart';
import '../../domain/models/site.dart';
import 'container_engine.dart';

const _method = MethodChannel('com.mono.container/engine');
const _events = EventChannel('com.mono.container/sessions');

SessionPhase _phase(String name) => switch (name) {
      'opening' => SessionPhase.opening,
      'background' => SessionPhase.background,
      'refused' => SessionPhase.refused,
      _ => SessionPhase.live,
    };

ContainerSession _sessionFrom(Map<Object?, Object?> map) => ContainerSession(
      siteId: map['siteId']! as String,
      phase: _phase(map['phase']! as String),
      lastActiveAt: map['lastActiveAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt']! as int),
      blockedCount: (map['blockedCount'] as int?) ?? 0,
    );

class ChannelContainerEngine implements ContainerEngine {
  @override
  Future<bool> isolationAvailable() async =>
      await _method.invokeMethod<bool>('isolationAvailable') ?? false;

  @override
  Future<ContainerSession> open(Site site) async {
    final result = await _method.invokeMapMethod<Object?, Object?>('open', {
      'siteId': site.id,
      'profileId': site.profileId,
      'url': site.url,
      'proxyMode': site.proxyMode.name,
      'proxyHost': site.proxyHost,
      'proxyPort': site.proxyPort,
      'blockWebRtc': site.blockWebRtc,
      'blockTrackers': site.blockTrackers,
      'antiFingerprinting': site.antiFingerprinting,
      'allowCamera': site.allowCamera,
      'allowMicrophone': site.allowMicrophone,
      'allowLocation': site.allowLocation,
      'allowClipboard': site.allowClipboard,
      'userAgentMode': site.userAgentMode.name,
      'forceDark': site.forceDark,
      'pageZoom': site.pageZoom,
      'customCss': site.customCss,
      'customJs': site.customJs,
      'wipeOnExit': site.cookiePolicy == CookiePolicy.wipeOnExit,
    });
    return _sessionFrom(result!);
  }

  @override
  Future<void> wipe(String profileId) =>
      _method.invokeMethod('wipe', {'profileId': profileId});

  @override
  Future<void> close(String siteId) =>
      _method.invokeMethod('close', {'siteId': siteId});

  @override
  Future<void> reload(String siteId) =>
      _method.invokeMethod('reload', {'siteId': siteId});

  @override
  Stream<List<ContainerSession>> sessions() =>
      _events.receiveBroadcastStream().map((event) => (event as List<Object?>)
          .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
          .toList());
}
```

- [ ] **Step 6: Run the suite and commit**

Run: `flutter test`
Expected: PASS.

```bash
git add lib/domain/models/container_session.dart lib/domain/models/open_step.dart lib/data/services/ test/domain/open_step_test.dart
git commit -m "feat: container engine interface, fake and method channel"
```

---

## Task 4: Android platform layer and per-site profile isolation

First Kotlin. Ends with a device able to open two sites whose cookies genuinely do not see each other.

**Files:**
- Modify: `android/app/build.gradle.kts`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/ProfileManager.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/ContainerViewFactory.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/MainActivity.kt`

**Interfaces:**
- Consumes: the method names in Task 3's `ChannelContainerEngine`.
- Produces: `ProfileManager.isAvailable()`, `.profileFor(String)`, `.wipe(String)`; `ContainerView`; channel `com.mono.container/engine`; event channel `com.mono.container/sessions`.

- [ ] **Step 1: Raise `minSdk` and add the dependency**

In `android/app/build.gradle.kts`:

```kotlin
    defaultConfig {
        applicationId = "com.mono.container"
        minSdk = 29          // was 26; multi-profile WebView needs it
        targetSdk = 36
    }

dependencies {
    implementation("androidx.webkit:webkit:1.12.0")
}
```

- [ ] **Step 2: Write `ProfileManager`**

```kotlin
package com.mono.container.engine

import androidx.webkit.Profile
import androidx.webkit.ProfileStore
import androidx.webkit.WebViewFeature

/**
 * One WebView profile per site. A profile owns its own cookies, localStorage
 * and cache, which is what makes "Each site gets its own storage" true.
 *
 * Profile names are the opaque ids stored in the vault. They are never derived
 * from a host — see Global Constraints.
 */
class ProfileManager {

    fun isAvailable(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)

    /**
     * Returns this site's profile, creating it on first use.
     * @throws IllegalStateException when the device cannot isolate. Callers
     * must surface this, never degrade to the default profile.
     */
    fun profileFor(profileId: String): Profile {
        check(isAvailable()) { "This device cannot isolate containers." }
        return ProfileStore.getInstance().getOrCreateProfile(profileId)
    }

    /** Destroys everything the profile holds. Irreversible. */
    fun wipe(profileId: String) {
        check(isAvailable()) { "This device cannot isolate containers." }
        val store = ProfileStore.getInstance()
        if (store.allProfileNames.contains(profileId)) {
            store.deleteProfile(profileId)
        }
    }
}
```

- [ ] **Step 3: Write `ContainerView`**

One WebView, one profile, one site. Note the profile is attached *before* the first load, and that `setSafeBrowsingEnabled(false)` is here rather than in `Shields` because it must be set at construction.

```kotlin
package com.mono.container.engine

import android.content.Context
import android.view.View
import android.webkit.WebView
import android.webkit.WebSettings
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.platform.PlatformView

class ContainerView(
    context: Context,
    private val config: SiteConfig,
    private val profiles: ProfileManager,
    private val interceptor: RequestInterceptor,
) : PlatformView {

    private val webView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.userAgentString = userAgentFor(config.userAgentMode)
        settings.setSupportMultipleWindows(false)
        settings.mediaPlaybackRequiresUserGesture = true
        setSafeBrowsingEnabled(false)   // pings Google directly; see Constraints

        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(this, config.forceDark)
        }
        setInitialScale(config.pageZoom)
    }

    init {
        // Must precede the first load, or the request goes to the default store.
        androidx.webkit.WebViewCompat.setProfile(webView, config.profileId)
        webView.webViewClient = interceptor.clientFor(config)
        webView.webChromeClient = Shields.chromeClientFor(config)
        Shields.apply(webView, config)
        webView.loadUrl(config.url)
    }

    override fun getView(): View = webView

    override fun dispose() {
        webView.stopLoading()
        webView.destroy()
        if (config.wipeOnExit) profiles.wipe(config.profileId)
    }

    private fun userAgentFor(mode: String): String = when (mode) {
        "desktop" -> "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        "minimal" -> "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
        else -> WebSettings.getDefaultUserAgent(webView.context)
    }
}
```

- [ ] **Step 4: Write `SiteConfig`, the factory, and the channel**

`SiteConfig` is a plain data class mirroring the map `ChannelContainerEngine.open` sends — one field per key, same names. `ContainerViewFactory` builds a `ContainerView` from the creation params. `EngineChannel` registers both channels on `MainActivity`, routes `isolationAvailable`/`open`/`wipe`/`close`/`reload`, and pushes session lists to the event sink. Register in `MainActivity.configureFlutterEngine`:

```kotlin
flutterEngine.platformViewsController.registry
    .registerViewFactory("com.mono.container/view", ContainerViewFactory(profiles, interceptor))
EngineChannel(profiles).attach(flutterEngine.dartExecutor.binaryMessenger)
```

- [ ] **Step 5: Verify isolation on a device**

There is no unit test for this — it is a platform guarantee, so it needs a real WebView. Run the app, open two sites that both set a cookie on the same host, and confirm neither sees the other's. Then:

Run: `adb shell run-as com.mono.container ls -R app_webview*`
Expected: one directory per profile id, none named for a host.

- [ ] **Step 6: Commit**

```bash
git add android/
git commit -m "feat: per-site WebView profiles behind a platform view"
```

---

## Task 5: The interceptor, the router, filtering and shields

The heart of the plan. `Router` and `FilterEngine` are pure Kotlin and JVM-testable; the rest is glue.

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/Router.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/FilterEngine.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/Shields.kt`
- Create: `android/app/src/main/assets/shields/fingerprint.js`
- Create: `android/app/src/main/assets/filters/default.txt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/FilterEngineTest.kt`

**Interfaces:**
- Consumes: `SiteConfig`, `ProfileManager`.
- Produces: `Router.resolve(SiteConfig, Boolean): Route`; `FilterEngine.matches(String): Boolean` and `.blockedCount`; `RequestInterceptor.clientFor(SiteConfig)`; `Shields.apply(WebView, SiteConfig)`.

- [ ] **Step 1: Write the failing router test**

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertTrue
import org.junit.Test

class RouterTest {

    private fun config(mode: String = "socks5", host: String? = "127.0.0.1", port: Int? = 9050) =
        SiteConfig(
            siteId = "s", profileId = "a".repeat(32), url = "https://forum.example.com",
            proxyMode = mode, proxyHost = host, proxyPort = port,
            blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
            allowCamera = false, allowMicrophone = false, allowLocation = false,
            allowClipboard = false, userAgentMode = "android", forceDark = true,
            pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
        )

    @Test fun `direct site routes direct`() {
        assertTrue(Router.resolve(config(mode = "direct"), proxyReachable = false) is Route.Direct)
    }

    @Test fun `proxied site with reachable proxy routes through it`() {
        assertTrue(Router.resolve(config(), proxyReachable = true) is Route.Proxy)
    }

    @Test fun `proxied site with unreachable proxy refuses and never goes direct`() {
        val route = Router.resolve(config(), proxyReachable = false)
        assertTrue(route is Route.Refused)
        assertTrue((route as Route.Refused).failure == RouteFailure.PROXY_UNREACHABLE)
    }

    @Test fun `proxied site with no host is misconfigured`() {
        val route = Router.resolve(config(host = null), proxyReachable = true)
        assertTrue((route as Route.Refused).failure == RouteFailure.MISCONFIGURED)
    }
}
```

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests '*RouterTest*'`
Expected: FAIL — `Router` does not exist.

- [ ] **Step 2: Write `Router`**

Mirrors Task 2's Dart exactly. Same rule, same absence of a fallback branch.

```kotlin
package com.mono.container.engine

enum class RouteFailure {
    PROXY_UNREACHABLE, PROXY_REFUSED, UPSTREAM_TIMEOUT, TLS_FAILURE, MISCONFIGURED
}

sealed class Route {
    object Direct : Route()
    data class Proxy(val host: String, val port: Int, val socks: Boolean) : Route()
    data class Refused(val failure: RouteFailure) : Route()
}

/**
 * Turn 8: "never fall back to a direct connection on its own."
 * There is deliberately no branch returning [Route.Direct] for a proxied site.
 */
object Router {
    fun resolve(config: SiteConfig, proxyReachable: Boolean): Route {
        if (config.proxyMode == "direct") return Route.Direct

        val host = config.proxyHost
        val port = config.proxyPort
        if (host.isNullOrEmpty() || port == null) {
            return Route.Refused(RouteFailure.MISCONFIGURED)
        }
        if (!proxyReachable) return Route.Refused(RouteFailure.PROXY_UNREACHABLE)

        return Route.Proxy(host, port, socks = config.proxyMode == "socks5")
    }

    /** Opens a socket for [route]. Never called for [Route.Refused]. */
    fun connect(route: Route, targetHost: String, targetPort: Int): java.net.Socket =
        when (route) {
            is Route.Direct -> java.net.Socket(targetHost, targetPort)
            is Route.Proxy -> {
                val type = if (route.socks) java.net.Proxy.Type.SOCKS
                           else java.net.Proxy.Type.HTTP
                java.net.Socket(
                    java.net.Proxy(type, java.net.InetSocketAddress(route.host, route.port))
                ).apply { connect(java.net.InetSocketAddress(targetHost, targetPort), 15_000) }
            }
            is Route.Refused -> error("connect() called for a refused route")
        }
}
```

- [ ] **Step 3: Run the router test and watch it pass**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests '*RouterTest*'`
Expected: PASS, 4 tests.

- [ ] **Step 4: Write the failing filter test**

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FilterEngineTest {

    private val engine = FilterEngine(
        listOf("||ads.example.com^", "||track.example.net^", "!a comment", "")
    )

    @Test fun `a listed host is blocked`() {
        assertTrue(engine.matches("https://ads.example.com/banner.js"))
    }

    @Test fun `a subdomain of a listed host is blocked`() {
        assertTrue(engine.matches("https://cdn.ads.example.com/x.gif"))
    }

    @Test fun `an unlisted host is allowed`() {
        assertFalse(engine.matches("https://forum.example.com/thread"))
    }

    @Test fun `comments and blank lines are not rules`() {
        assertFalse(engine.matches("https://a-comment/"))
    }

    @Test fun `blocked requests are counted`() {
        engine.matches("https://ads.example.com/a")
        engine.matches("https://track.example.net/b")
        engine.matches("https://forum.example.com/c")
        assertEquals(2, engine.blockedCount)
    }
}
```

- [ ] **Step 5: Write `FilterEngine`**

A deliberately small subset of ABP syntax — `||host^` domain rules only. Anything richer is Plan 5's filter-list library.

```kotlin
package com.mono.container.engine

import java.net.URI
import java.util.concurrent.atomic.AtomicInteger

/**
 * Domain-blocking only: `||host^` rules. Feeds spec `2a`'s
 * "Local filter lists · 42 rules matched today" and Plan 1's leak count.
 */
class FilterEngine(rules: List<String>) {

    private val blockedHosts: Set<String> = rules
        .map { it.trim() }
        .filter { it.startsWith("||") && it.endsWith("^") }
        .map { it.removePrefix("||").removeSuffix("^").lowercase() }
        .toSet()

    private val counter = AtomicInteger(0)
    val blockedCount: Int get() = counter.get()

    fun matches(url: String): Boolean {
        val host = runCatching { URI(url).host }.getOrNull()?.lowercase()
            ?: return false
        val hit = blockedHosts.any { host == it || host.endsWith(".$it") }
        if (hit) counter.incrementAndGet()
        return hit
    }
}
```

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests '*FilterEngineTest*'`
Expected: PASS, 5 tests.

- [ ] **Step 6: Write `RequestInterceptor`**

Where per-site routing becomes real: the `WebViewClient` is built per site, so `config` — and therefore the route — is in scope for every request.

```kotlin
package com.mono.container.engine

import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.ByteArrayInputStream

class RequestInterceptor(private val filters: FilterEngine) {

    /** One client per site. This is what `ProxyController` could never do. */
    fun clientFor(config: SiteConfig): WebViewClient = object : WebViewClient() {

        override fun shouldInterceptRequest(
            view: WebView,
            request: WebResourceRequest,
        ): WebResourceResponse? {
            val url = request.url.toString()

            if (config.blockTrackers && filters.matches(url)) return blocked()

            return when (val route = Router.resolve(config, proxyReachable(config))) {
                is Route.Direct -> null   // let WebView fetch it itself
                is Route.Proxy -> fetchThrough(route, request)
                is Route.Refused -> refused(route.failure)
            }
        }
    }

    /** A 204 with no body. The request is simply not made. */
    private fun blocked() = WebResourceResponse(
        "text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0))
    )

    /**
     * Turn 8's rule at the only layer that can enforce it. Returning a response
     * here means WebView never opens its own socket — which is precisely why
     * there is no silent direct fallback anywhere in this app.
     */
    private fun refused(failure: RouteFailure) = WebResourceResponse(
        "text/plain", "utf-8", 523, "Route refused",
        mapOf("X-Container-Refusal" to failure.name), ByteArrayInputStream(ByteArray(0))
    )

    /**
     * Opens the socket, writes a bare HTTP/1.1 request line, and streams the
     * response straight back to WebView. Never returns null on failure — see
     * the class doc — every exit is either a real response or [refused].
     */
    private fun fetchThrough(
        route: Route.Proxy,
        request: WebResourceRequest,
    ): WebResourceResponse {
        val url = request.url
        val host = url.host ?: return refused(RouteFailure.MISCONFIGURED)
        val targetPort = if (url.port != -1) url.port else if (url.scheme == "https") 443 else 80

        return runCatching {
            val socket = Router.connect(route, host, targetPort)
            socket.soTimeout = 15_000
            val out = socket.getOutputStream()
            val path = url.path.ifEmpty { "/" } + (url.query?.let { "?$it" } ?: "")
            out.write("${request.method} $path HTTP/1.1\r\n".toByteArray(Charsets.US_ASCII))
            out.write("Host: $host\r\n".toByteArray(Charsets.US_ASCII))
            request.requestHeaders.forEach { (k, v) ->
                out.write("$k: $v\r\n".toByteArray(Charsets.US_ASCII))
            }
            out.write("Connection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
            out.flush()

            val input = socket.getInputStream()
            val (status, reason, headers) = readStatusAndHeaders(input)
            val contentType = headers["Content-Type"]
            val mimeType = contentType?.substringBefore(';')?.trim()
                ?: "application/octet-stream"
            val charset = contentType?.substringAfter("charset=", "")?.trim()
                ?.ifEmpty { null } ?: "utf-8"
            WebResourceResponse(mimeType, charset, status, reason, headers, input)
        }.getOrElse { error ->
            refused(
                when (error) {
                    is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
                    is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
                    is java.net.ConnectException -> RouteFailure.PROXY_UNREACHABLE
                    else -> RouteFailure.UPSTREAM_TIMEOUT
                }
            )
        }
    }

    /**
     * Reads one CRLF-terminated line a byte at a time. A [java.io.BufferedReader]
     * would over-read into its own buffer and swallow the first bytes of the
     * response body along with the headers; this stops exactly at the blank
     * line so [input] is positioned at byte zero of the body for the caller.
     */
    private fun readLine(input: java.io.InputStream): String {
        val line = StringBuilder()
        while (true) {
            val b = input.read()
            if (b == -1 || b == '\n'.code) break
            if (b != '\r'.code) line.append(b.toChar())
        }
        return line.toString()
    }

    private fun readStatusAndHeaders(
        input: java.io.InputStream,
    ): Triple<Int, String, Map<String, String>> {
        val statusLine = readLine(input)
        val parts = statusLine.split(' ', limit = 3)
        val status = parts.getOrNull(1)?.toIntOrNull() ?: 502
        val reason = parts.getOrNull(2) ?: "OK"

        val headers = mutableMapOf<String, String>()
        while (true) {
            val line = readLine(input)
            if (line.isEmpty()) break
            val idx = line.indexOf(':')
            if (idx > 0) headers[line.substring(0, idx).trim()] = line.substring(idx + 1).trim()
        }
        return Triple(status, reason, headers)
    }

    /** `config`, not a bare host/port: each site can point at a different proxy. */
    private fun proxyReachable(config: SiteConfig): Boolean {
        val host = config.proxyHost ?: return false
        val port = config.proxyPort ?: return false
        return ProxyProbe.reachable(host, port)
    }
}
```

- [ ] **Step 7: Write `ProxyProbe`**

A page can pull in dozens of subresources within a few hundred milliseconds; probing the proxy's TCP reachability on every one of them would turn one slow connect into sixty. `ProxyProbe.reachable(host, port)` caches each `host:port` result for 5 seconds behind a 2-second connect timeout.

```kotlin
package com.mono.container.engine

import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

object ProxyProbe {
    private data class Entry(val reachable: Boolean, val checkedAtMs: Long)

    private val cache = ConcurrentHashMap<String, Entry>()
    private const val CACHE_MS = 5_000L
    private const val CONNECT_TIMEOUT_MS = 2_000

    fun reachable(host: String, port: Int): Boolean {
        val key = "$host:$port"
        val now = System.currentTimeMillis()
        cache[key]?.let { if (now - it.checkedAtMs < CACHE_MS) return it.reachable }

        val result = runCatching {
            Socket().use { it.connect(InetSocketAddress(host, port), CONNECT_TIMEOUT_MS) }
            true
        }.getOrDefault(false)

        cache[key] = Entry(result, now)
        return result
    }
}
```

- [ ] **Step 8: Write `Shields` and the fingerprint shim**

```kotlin
package com.mono.container.engine

import android.webkit.WebView

object Shields {
    fun apply(webView: WebView, config: SiteConfig) {
        val js = buildString {
            if (config.blockWebRtc) {
                // WebRTC never reaches the interceptor — it leaks over UDP past
                // any proxy. Removing the constructors is the only fix.
                append(
                    "delete window.RTCPeerConnection;" +
                    "delete window.webkitRTCPeerConnection;" +
                    "navigator.mediaDevices && (navigator.mediaDevices.getUserMedia=" +
                    "()=>Promise.reject(new DOMException('Blocked','NotAllowedError')));"
                )
            }
            // WebSocket does not reach shouldInterceptRequest either.
            append("window.WebSocket=function(){throw new Error('Blocked');};")
            if (config.antiFingerprinting) {
                append(webView.context.assets.open("shields/fingerprint.js")
                    .bufferedReader().readText())
            }
            if (config.customCss.isNotEmpty()) {
                append("document.addEventListener('DOMContentLoaded',()=>{" +
                    "const s=document.createElement('style');" +
                    "s.textContent=${config.customCss.asJsString()};" +
                    "document.head.appendChild(s);});")
            }
            append(config.customJs)
        }
        androidx.webkit.WebViewCompat.addDocumentStartJavaScript(
            webView, js, setOf("*")
        )
    }

    /** Denies every hardware permission the site was not granted. */
    fun chromeClientFor(config: SiteConfig) = object : android.webkit.WebChromeClient() {
        override fun onPermissionRequest(request: android.webkit.PermissionRequest) {
            val allowed = request.resources.filter { resource ->
                when (resource) {
                    android.webkit.PermissionRequest.RESOURCE_VIDEO_CAPTURE -> config.allowCamera
                    android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE -> config.allowMicrophone
                    else -> false
                }
            }
            if (allowed.isEmpty()) request.deny() else request.grant(allowed.toTypedArray())
        }

        override fun onGeolocationPermissionsShowPrompt(
            origin: String, callback: android.webkit.GeolocationPermissions.Callback,
        ) = callback.invoke(origin, config.allowLocation, false)
    }
}
```

`assets/shields/fingerprint.js` overrides `HTMLCanvasElement.prototype.toDataURL`, `CanvasRenderingContext2D.prototype.getImageData`, `WebGLRenderingContext.prototype.getParameter` and `AudioBuffer.prototype.getChannelData` to add per-session deterministic noise seeded from a value injected at document start. Spec `2a`: "Noise for canvas, WebGL and audio readouts."

- [ ] **Step 9: Register the interceptor for service workers**

Service-worker requests bypass `WebViewClient` entirely. In `MainActivity`:

```kotlin
if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
    ServiceWorkerControllerCompat.getInstance()
        .setServiceWorkerClient(interceptor.serviceWorkerClient())
}
```

Add `serviceWorkerClient()` to `RequestInterceptor`, returning a `ServiceWorkerClientCompat` whose `shouldInterceptRequest` applies the same filter-and-route logic. Without this, a site with a service worker routes around every guarantee in this plan.

- [ ] **Step 10: Commit**

```bash
cd android && ./gradlew :app:testDebugUnitTest
git add android/
git commit -m "feat: per-site interception, routing, filtering and shields"
```

---

## Task 6: Screen `8a` — Opening

**Files:**
- Create: `lib/ui/features/container/views/opening_screen.dart`
- Test: `test/ui/features/opening_screen_test.dart`

**Interfaces:**
- Consumes: `C` (tokens), `ui()`/`mono()` (typography), `OpenStep`, `OpenStepState`, `openStepsFor`.
- Produces: `OpeningBody({required String host, required List<OpenStep> steps, required double progress, required VoidCallback onCancel})`.

- [ ] **Step 1: Write the failing widget test**

```dart
// test/ui/features/opening_screen_test.dart
import 'package:container/domain/models/open_step.dart';
import 'package:container/ui/features/container/views/opening_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the checklist and the tunnel promise', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OpeningBody(
        host: 'forum.example.com',
        steps: const [
          OpenStep('Fresh session, no shared cookies', OpenStepState.done),
          OpenStep('Filter lists loaded', OpenStepState.done),
          OpenStep('Fingerprint noise injected', OpenStepState.done),
          OpenStep('Connecting through 127.0.0.1:9050', OpenStepState.running),
        ],
        progress: 0.58,
        onCancel: () {},
      ),
    ));

    expect(find.text('Starting a clean container'), findsOneWidget);
    expect(find.text('Nothing loads until the tunnel is up.'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Connecting through 127.0.0.1:9050'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/features/opening_screen_test.dart`
Expected: FAIL — `opening_screen.dart` does not exist.

- [ ] **Step 3: Build the screen**

Layout from spec `8a`, sizes verbatim. Top bar: 8px/12px padding, `‹` 32×32 `C.icon`, a 34px pill (`C.surface`, 1px `C.line08`, radius 17) holding a 6px dot in `C.warning` — amber because the tunnel is not up yet, and it turns `C.jade` only in `2b` — the host at 11.5px `Color(0xFFA9B0AE)`, then `×` 32×32. Below it a 2px track in `C.barTrack` with a `C.jade` fill at `progress`. The body centres with 34px horizontal padding and 20px gaps: "Starting a clean container" at 16px/600 `C.textPrimary`, then the steps at 14px gaps. A done step is a 12px `✓` in `C.jade` with its label at 13.5px `C.textMuted`; a running step is an 11px circle with a 1.5px `C.warning` border and a transparent top edge, with its label at 13.5px `C.textSecondary`. Footer: 34px padding, 30px bottom, "Nothing loads until the tunnel is up." at 12px/1.6 `C.textDim`.

- [ ] **Step 4: Run the test and watch it pass**

Run: `flutter test test/ui/features/opening_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/container/views/opening_screen.dart test/ui/features/opening_screen_test.dart
git commit -m "feat: opening screen (8a)"
```

---

## Task 7: Screens `2b` and `2c` — the container and the switcher

**Files:**
- Create: `lib/ui/features/container/views/container_screen.dart`
- Create: `lib/ui/features/container/views/container_top_bar.dart`
- Create: `lib/ui/features/container/views/container_toolbar.dart`
- Create: `lib/ui/features/container/views/switcher_sheet.dart`
- Test: `test/ui/features/container_screen_test.dart`
- Test: `test/ui/features/switcher_sheet_test.dart`

**Interfaces:**
- Consumes: `C`, typography, `Monogram`, `StatusRail`, `Hairline` (Plan 1 primitives), `ContainerSession`, `SessionPhase`, `FakeContainerEngine`.
- Produces: `ContainerTopBar({required String host, required String routeLabel, required bool live, ...})`; `ContainerToolbar({required int openCount, ...})`; `SwitcherSheet({required List<SwitcherEntry> entries, required String workspaceName, required VoidCallback onCloseAllAndWipe, required VoidCallback onPanic})`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/features/container_screen_test.dart — key assertions
expect(find.text('forum.example.com'), findsOneWidget);
expect(find.text('SOCKS5'), findsOneWidget);   // route label, 9.5px/500
expect(find.text('3 OPEN'), findsOneWidget);   // toolbar pill

// test/ui/features/switcher_sheet_test.dart — key assertions
expect(find.text('3 OPEN SESSIONS'), findsOneWidget);
expect(find.text('PERSONAL'), findsOneWidget);
expect(find.text('viewing now · socks5'), findsOneWidget);
expect(find.text('background · 2 min'), findsOneWidget);
expect(find.text('Close all and wipe'), findsOneWidget);
```

Run both: `flutter test test/ui/features/container_screen_test.dart test/ui/features/switcher_sheet_test.dart`
Expected: FAIL.

- [ ] **Step 2: Build `ContainerTopBar` (`2b`)**

8px/12px padding, bottom border 1px `C.line07`. `‹` at 32×32 radius 9, `C.icon`. Then a flexed 34px pill: `C.surface`, 1px `C.line08`, radius 17, 12px padding, 7px gaps — a 6px `C.jade` dot (live; `C.warning` while opening), the host at 11.5px `Color(0xFFA9B0AE)` with `TextOverflow.ellipsis`, and the route label pushed right at 9.5px/500 `C.textFaint`. Then `⟳` 32×32 `C.icon`, and the panic square: 32×32 radius 9, `C.danger` at 14% opacity, glyph `◉` 13px `C.danger`. **Panic is always reachable — never hide it behind an overflow menu.**

The route label is `site.proxyMode.name.toUpperCase()` for a proxied site and empty for a direct one. Do not invent a "DIRECT" label; the spec never shows one.

- [ ] **Step 3: Build `ContainerToolbar` (`2b`)**

A floating bar, `margin-top: -70px` over the content, 20px horizontal padding, 14px bottom. 48px tall, radius 24, `Color(0xFF181C1F)` at 94% opacity, 1px `C.line09`, 8px inner padding, `MainAxisAlignment.spaceBetween`. Four 40px round icon slots — `◑` reader, `≡` , `☰`, `⋯` — around a centre pill: 34px, radius 17, `C.selected`, 14px padding, "N OPEN" at 11px/500 `C.textSecondary` and a 9px `▲` in `C.jade`. Tapping the pill opens `SwitcherSheet`.

- [ ] **Step 4: Build `SwitcherSheet` (`2c`)**

The page behind it dims to 32% opacity. The sheet is `C.sheet`, top border 1px `C.line09`, radius 22 on the top corners, `10px 0 16px` padding, shadow `0 -20px 40px rgba(0,0,0,.5)`. A 36×4 grabber in `Color(0xFF2C3134)`, 12px below. Header row at 18px padding: "N OPEN SESSIONS" at 10px/500 letter-spacing .1em in `C.jade`, and the workspace name uppercased at 10px/500 letter-spacing .06em in `C.textFaint`.

Each row: 12px gaps, 18px horizontal padding, 14px vertical, bottom hairline `C.line06` on all but the last. A 3px×38px rail radius 2 — full `C.jade` for the live session, `C.jade` at 45% for backgrounded ones. A 36px monogram, radius 10, `C.monogramOpen`, 14px/600 `C.monogramText`. Name at 14.5px/500 `C.textPrimary`; meta at 10.5px `C.textFaint` — `'viewing now · ${mode}'` for the live one, `'background · ${relativeAge(lastActiveAt)}'` for the rest, reusing Plan 1's `relativeAge`. A 16px `×` in `C.textFaint` closes that session.

Footer at `16px 18px 0`, 10px gap: "Close all and wipe" fills the row — 46px, radius 14, `C.button`, 13.5px/500 `C.textSecondary` — beside a 46px square, radius 14, `C.danger` at 14%, 1px `C.danger` at 30%, glyph `◉` 15px `C.danger`.

**Both destructive actions are on this sheet by design** (turn 2: "wipe and panic in the same sheet"). Neither gets a confirmation dialog — `3c` establishes that panic simply happens and reports afterwards. Do not add one.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `flutter test test/ui/features/container_screen_test.dart test/ui/features/switcher_sheet_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/container/ test/ui/features/
git commit -m "feat: container screen and quick switcher (2b, 2c)"
```

---

## Task 8: Screen `2a` — Add site

Four tabs, all visible from the start (turn 2's title). This is where every field from Task 1 becomes editable.

**Files:**
- Create: `lib/ui/features/add_site/view_models/add_site_view.dart`
- Create: `lib/ui/features/add_site/views/add_site_screen.dart`
- Create: `lib/ui/features/add_site/views/basics_tab.dart`
- Create: `lib/ui/features/add_site/views/network_tab.dart`
- Create: `lib/ui/features/add_site/views/privacy_tab.dart`
- Create: `lib/ui/features/add_site/views/appearance_tab.dart`
- Test: `test/ui/features/add_site_test.dart`

**Interfaces:**
- Consumes: `Site`, `UserAgentMode`, `CookiePolicy`, `ProxyMode`, `suggestMonogram` (Plan 1), `C`, typography.
- Produces: `AddSiteScreen({Site? initial, required List<Workspace> workspaces, required ValueChanged<Site> onSave})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/ui/features/add_site_test.dart — key assertions
expect(find.text('Add site'), findsOneWidget);
expect(find.text('Save'), findsOneWidget);
for (final tab in ['Basics', 'Network', 'Privacy', 'Appearance']) {
  expect(find.text(tab), findsOneWidget);   // all four visible from the start
}

// Network tab
await tester.tap(find.text('Network'));
await tester.pumpAndSettle();
expect(find.text('Route through proxy'), findsOneWidget);
expect(find.text('This site only'), findsOneWidget);
expect(find.text('Prevents real IP leaking past the proxy'), findsOneWidget);

// Privacy tab — hardware off by default
await tester.tap(find.text('Privacy'));
await tester.pumpAndSettle();
expect(find.text('HARDWARE · ALL OFF BY DEFAULT'), findsOneWidget);
expect(find.text('Show in decoy vault'), findsOneWidget);
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/features/add_site_test.dart`
Expected: FAIL.

- [ ] **Step 3: Build the shell**

Header at `12px 18px`: `‹` 20px `C.icon`, "Add site" 15px/600 `C.textPrimary`, "Save" 14px/500 `C.jade` — jade because it is the single affirmative action on the screen, which is exactly what Plan 1's jade rule permits. Tab row at 18px horizontal, each tab `11px 0 10px`, label 12.5px/500 — active `C.textPrimary` with a 2px `C.jade` underline, inactive `C.tabInactive`. Body at 18px padding.

- [ ] **Step 4: Build the Basics tab**

Section labels are 10px/500 letter-spacing .1em `C.textFaint`: `ADDRESS`, `NAME`, `WORKSPACE`, `COOKIES`. Text fields are 46px, radius 12, `C.surface`, 1px `C.line09`, 13px padding, 13–14px `C.textSecondary`. The NAME field carries a trailing 28px monogram chip, radius 8, `C.monogramOpen`, 12px/600 `C.monogramText`, fed live by Plan 1's `suggestMonogram(name)`.

WORKSPACE is a row of chips: 40px, radius 11, selected `C.selected` with 1px `C.line10` and 13px `C.textPrimary`; unselected transparent with 1px `C.line07` and 13px `C.tabInactive`.

COOKIES is a bordered group, radius 12, 1px `C.line08`, two 13px-padded rows on `C.surface`: "Keep for this site" / "Stays signed in, isolated from other sites", and "Wipe on exit" / "Cookies, cache and form history destroyed". Titles 13.5px (`C.textPrimary` selected, `C.textTertiary` not), subtitles 11px `C.textFaint`. The radio is a 16px circle — selected is a 5px `C.jade` ring over `C.bg`; unselected is a 1.5px `C.pinEmpty` border.

- [ ] **Step 5: Build the Network tab**

A toggle row "Route through proxy" / "This site only" (14px `C.textPrimary`, 11px `C.textFaint`). Then the mode chips `SOCKS5` / `HTTP` — 40px, radius 11, same selected/unselected treatment as WORKSPACE but with 12px/500 mono-ish labels. Then `HOST` and `PORT` fields side by side, 46px, IBM Plex Mono 13px `C.textSecondary`, defaulting to `127.0.0.1` and `9050`. Then two more toggles: "Block WebRTC" / "Prevents real IP leaking past the proxy", and "Block trackers and ads" / "Local filter lists · N rules matched today", where N is the live `blockedCount` from the engine.

The switch is 44×26, radius 20 — on is `C.jade` with a 20px `C.bg` knob; off is `C.trackOff` with a `C.knobOff` knob.

**"Block WebRTC" defaults on and its subtitle is literally true**: WebRTC never reaches the interceptor, so without this the real IP leaks past the proxy. Do not present it as an optional hardening.

- [ ] **Step 6: Build the Privacy tab**

Label `HARDWARE · ALL OFF BY DEFAULT`, then four toggle rows — Camera, Microphone, Location, Clipboard — all off. Label `SHIELDS` with `22px 0 12px` padding, then "Anti-fingerprinting" / "Noise for canvas, WebGL and audio readouts" (on), "Ask for PIN before opening" / "Biometric accepted" (off), "Show in decoy vault" / "Visible when the second PIN is used" (off).

`Show in decoy vault` writes `Site.showInDecoy`. Under the two-store model this is a **provisioning** flag — it decides which vault the site is written into when saved, not a runtime filter. Plan 1's Global Constraints are explicit that no query in this app filters rows for privacy; if you find yourself writing `where: 'show_in_decoy = ?'`, stop.

- [ ] **Step 7: Build the Appearance tab**

`USER AGENT` chips for the three `UserAgentMode` values. Toggles: "Force dark mode" / "For sites with no dark theme" (on), "Open in reader mode" (off). Then "Page zoom" with its value at 12px/500 `C.jade` and a 3px track in `C.trackOff` with a `C.jade` fill and a 17px `C.textPrimary` knob, spanning 50–200%.

`CUSTOM CSS` is a code box: radius 12, `C.surface`, 1px `C.line09`, 12px padding, IBM Plex Mono 11.5px/1.6 in `C.jadeCode`. `CUSTOM JS` matches it but shows the placeholder "Runs at document start" at 11.5px `C.textFaint` when empty — that sentence is a promise Task 5 keeps via `addDocumentStartJavaScript`.

- [ ] **Step 8: Wire Save**

Build a `Site` from the form with `profileId: newProfileId()` for a new site, preserving the existing id when editing. Persist through `SiteRepository.upsert`, then pop. This fills Plan 1's `onAddSite` seam — replace its empty callback with a push to `AddSiteScreen`.

- [ ] **Step 9: Run everything**

Run: `flutter test`
Expected: PASS, all suites.

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/ui/features/add_site/ test/ui/features/add_site_test.dart
git commit -m "feat: add site screen with four tabs (2a)"
```

---

## Known gaps this plan deliberately leaves

- **Byte-range media requests are lossily intercepted.** `<video>` and `<audio>` issue range requests whose semantics `WebResourceResponse` represents poorly. A proxied site playing media may stall or fall back to a partial fetch. This is the one entry in "What the interceptor cannot see" that is not closed, and it is a real hole in the routing guarantee. It needs a device measurement before any screen claims media is tunnelled.
- **`FilterEngine` handles `||host^` rules only.** No path patterns, no element hiding, no exception rules. Spec `10d`'s filter-list library is Plan 5's, and it will need a real matcher.
- **Anti-fingerprinting is partial and always will be.** Noise on canvas, WebGL and audio raises the cost of fingerprinting; it does not prevent it. Screen `2a`'s subtitle claims exactly what is implemented — "Noise for canvas, WebGL and audio readouts" — and nothing broader. Do not let later copy inflate it.
- **`8b` and `8c` are Plan 4's.** This plan produces `RouteRefused` and the `X-Container-Refusal` header that those screens render; it does not render them. Plan 4 has them stubbed and is waiting on this plan's interfaces.
- **The reader-mode toggle in `2a` is stored but not honoured.** `6b` is Plan 4's screen. `Site.openInReader` persists correctly and does nothing yet.
- **`ProxyProbe` reachability is cached for 5 seconds**, so a proxy that dies mid-page can serve up to 5 seconds of requests before refusals begin. Shortening it costs a TCP connect per resource; `8c` exists because this window is real.
- **No test asserts real isolation.** Task 4 Step 5 is a manual device check because profile separation is a platform guarantee that a host test cannot observe. If this app ever gets instrumentation tests, that check is the first one to automate.

## Handoff

- **To Plan 4 (49's lane):** `RouteFailure`, `refusalMessage()` and the `X-Container-Refusal` response header are the contract for `8b` and `8c`. Failures are distinguishable — at minimum keep "cannot reach the proxy" separate from "the proxy refused the destination", because the remedy differs. Routing is per-site, so one container can be frozen while others keep running.
- **To Plan 5:** `FilterEngine` is where the script and filter library lands, and `addDocumentStartJavaScript` in `Shields.apply` is where `10e`'s script editor injects.
- **To Plan 2 (0b's lane):** `wipe(profileId)` destroys a container's storage and is what panic must call for every site in the vault being destroyed — before the data keys go, since afterwards the profile ids are unreadable.

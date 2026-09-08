# Decoy Re-sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the owner a reachable "re-sync with the decoy PIN" flow from Settings, replacing the setup-time-only `provisionDecoy` with a real two-way sync, and make the VAULT section of Settings actually visible in the shipped app (it is hardcoded invisible today).

**Architecture:** A new `resyncDecoy(from:, into:)` repository function extends `provisionDecoy`'s add-only copy into add-and-delete, using the existing invariant that a synced row keeps its real-vault id. A new Settings row pushes a small PIN-entry screen (built from the existing `PinDots`/`PinKeypad` core widgets, not the session-coupled `LockBody`); the entered PIN is checked with the existing `VaultUnlocker` against the existing `VaultStore`, sharing its attempt-gate/lockout. On a decoy-PIN match, the decoy `AppDatabase` is opened just long enough to run the sync, then closed. Separately, `SetupController` starts persisting whether a decoy was actually configured, and `SettingsScreen`'s VAULT-section visibility is wired to that instead of a hardcoded `false`.

**Tech Stack:** Flutter/Dart 3, `flutter_riverpod`, `sqflite_sqlcipher` (`sqflite_common_ffi` in tests). No new dependencies, no schema migration — `app_settings` is already a generic key-value table.

**Spec:** `docs/superpowers/specs/2026-09-08-decoy-resync-design.md`

## Global Constraints

- **Two-vault decoy model, not a filter.** No query anywhere filters rows for privacy, and no aggregate ever counts across both vaults. `resyncDecoy` only ever runs with both `AppDatabase`s explicitly passed in by a caller that already unlocked both — it never opens a vault itself.
- **The two slots stay indistinguishable from the outside.** A PIN is tried against every slot in a fixed order (`VaultUnlocker`); this plan adds no new code path that stops early or reveals which slot matched anything other than "correct" vs. "incorrect."
- **No network requests of the app's own.** Nothing in this plan makes one.
- **Hairline dividers, not cards. IBM Plex Mono for anything technical, Figtree for everything else.** The new PIN screen and Settings row follow the same tokens/typography every other screen in this codebase already uses (`lib/ui/core/tokens.dart`, `lib/ui/core/typography.dart`).
- **Jade `#7FC8A9`** is not used anywhere in this plan's new UI — there is no single affirmative action being highlighted on the PIN-entry screen (unlike the lock screen's own mark, which stays as-is).

---

### Task 1: `resyncDecoy` — add, keep, and remove

**Files:**
- Modify: `lib/data/repositories/decoy_provisioner.dart`
- Test: `test/data/decoy_provisioner_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (`lib/data/services/app_database.dart`), `SqliteWorkspaceRepository`/`SqliteSiteRepository` (`lib/data/repositories/workspace_repository_sqlite.dart`, `site_repository_sqlite.dart` — both already have `all()`, `byId(String)`, `upsert(...)`, `delete(String)`), `newProfileId()` (already exported from `decoy_provisioner.dart` itself), `Workspace`/`Site` models (`lib/domain/models/workspace.dart`, `site.dart` — both have `showInDecoy`, `copyWith`).
- Produces: `Future<int> resyncDecoy({required AppDatabase from, required AppDatabase into})` — returns the count of **newly added** sites (sites with no prior decoy-side row). Task 4 does not use the return value; it exists for tests and future callers.

- [ ] **Step 1: Write the failing tests**

Append to `test/data/decoy_provisioner_test.dart` (the file's existing `setUp`/`tearDown` and fixture — `real`/`decoy` databases, workspace `ws`/`ws-secret`, sites `s1`/`s2`/`s3` — stays as-is; these tests add to the same `main()`):

```dart
  group('resyncDecoy', () {
    test('adds a newly flagged site with a fresh profileId', () async {
      final copied = await resyncDecoy(from: real, into: decoy);

      expect(copied, 1);
      final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
      expect(sites.map((s) => s.name), ['News']);
    });

    test('keeps an already-synced site\'s existing profileId on a second call',
        () async {
      await resyncDecoy(from: real, into: decoy);
      final firstProfile =
          (await SqliteSiteRepository(decoy).byId('s1'))!.profileId;

      final copied = await resyncDecoy(from: real, into: decoy);

      expect(copied, 0, reason: 'nothing new was flagged the second time');
      final secondProfile =
          (await SqliteSiteRepository(decoy).byId('s1'))!.profileId;
      expect(secondProfile, firstProfile,
          reason: 'regenerating it would silently wipe decoy-side cookies '
              'and history for a site that did not actually change');
    });

    test('removes a decoy site whose flag was turned off since the last sync',
        () async {
      await resyncDecoy(from: real, into: decoy);
      await SqliteSiteRepository(real).upsert(
        (await SqliteSiteRepository(real).byId('s1'))!.copyWith(showInDecoy: false),
      );

      await resyncDecoy(from: real, into: decoy);

      final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
      expect(sites, isEmpty);
    });

    test('removes every site of a workspace whose flag was turned off',
        () async {
      await resyncDecoy(from: real, into: decoy);
      await SqliteWorkspaceRepository(real).upsert(
        (await SqliteWorkspaceRepository(real).byId('ws'))!
            .copyWith(showInDecoy: false),
      );

      await resyncDecoy(from: real, into: decoy);

      expect(await SqliteWorkspaceRepository(decoy).byId('ws'), isNull);
      expect(await SqliteSiteRepository(decoy).inWorkspace('ws'), isEmpty);
    });

    test('never touches a site the owner added directly inside the decoy '
        'session', () async {
      await resyncDecoy(from: real, into: decoy);
      await SqliteWorkspaceRepository(decoy).upsert(const Workspace(
          id: 'decoy-only-ws', name: 'Recipes', markerIndex: 2,
          storageRule: StorageRule.keep));
      await SqliteSiteRepository(decoy).upsert(Site(
          id: 'decoy-only-site', workspaceId: 'decoy-only-ws', name: 'Blog',
          monogram: 'Bl', url: 'https://blog.example.com',
          profileId: newProfileId()));

      await resyncDecoy(from: real, into: decoy);

      expect(await SqliteWorkspaceRepository(decoy).byId('decoy-only-ws'),
          isNotNull);
      expect(await SqliteSiteRepository(decoy).byId('decoy-only-site'),
          isNotNull);
    });

    test('an unflagged site in an otherwise-flagged workspace is left '
        'unflagged in the decoy copy', () async {
      await resyncDecoy(from: real, into: decoy);

      final bank = await SqliteSiteRepository(decoy).byId('s2');
      expect(bank, isNull, reason: 's2 was never flagged, so it was never '
          'copied and there is nothing to remove');
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/data/decoy_provisioner_test.dart`
Expected: FAIL — `resyncDecoy` is undefined.

- [ ] **Step 3: Implement `resyncDecoy`**

Add to `lib/data/repositories/decoy_provisioner.dart`, below the existing `provisionDecoy` (leave `provisionDecoy` and its doc comment untouched — `SetupController.complete` keeps calling it as-is, since a one-shot provision into an empty decoy has nothing to remove):

```dart
/// Brings the decoy store back into agreement with which workspaces/sites
/// are currently flagged `showInDecoy` — adds newly flagged rows, removes
/// rows for anything un-flagged or deleted since the last sync, and leaves
/// alone anything the owner added directly while browsing inside the decoy
/// session.
///
/// The mechanism relies on an invariant [provisionDecoy] already
/// establishes: every synced row keeps the *same id* as its real-vault
/// source. Nothing else in the app ever writes a decoy-vault row using a
/// real-vault id, so any decoy row whose id matches one from `from` is
/// sync-owned by definition; a row whose id does not is decoy-original
/// content this function must never touch.
///
/// Unlike [provisionDecoy], an already-synced site keeps its existing
/// decoy-side `profileId` rather than getting a new one each call —
/// `profileId` is what Plan 3's WebView isolation keys cookies, cache, and
/// history to, and regenerating it on every call would silently wipe an
/// unchanged site's accumulated decoy browsing state each time. A fresh
/// `profileId` is only minted for a site with no existing decoy-side row.
///
/// Returns the number of sites newly added this call (not the total
/// flagged count).
Future<int> resyncDecoy({
  required AppDatabase from,
  required AppDatabase into,
}) async {
  final sourceWorkspaces = SqliteWorkspaceRepository(from);
  final sourceSites = SqliteSiteRepository(from);
  final targetWorkspaces = SqliteWorkspaceRepository(into);
  final targetSites = SqliteSiteRepository(into);

  final allWorkspaces = await sourceWorkspaces.all();
  final ownedWorkspaceIds = <String>{};
  final flaggedWorkspaceIds = <String>{};
  final ownedSiteIds = <String>{};
  final flaggedSiteIds = <String>{};

  var added = 0;

  for (final workspace in allWorkspaces) {
    ownedWorkspaceIds.add(workspace.id);
    final sites = await sourceSites.inWorkspace(workspace.id);
    for (final site in sites) {
      ownedSiteIds.add(site.id);
    }

    if (!workspace.showInDecoy) continue;
    flaggedWorkspaceIds.add(workspace.id);
    await targetWorkspaces.upsert(workspace.copyWith(showInDecoy: false));

    for (final site in sites) {
      if (!site.showInDecoy) continue;
      flaggedSiteIds.add(site.id);
      final existing = await targetSites.byId(site.id);
      await targetSites.upsert(site.copyWith(
        showInDecoy: false,
        profileId: existing?.profileId ?? newProfileId(),
      ));
      if (existing == null) added++;
    }
  }

  for (final decoyWorkspace in await targetWorkspaces.all()) {
    if (ownedWorkspaceIds.contains(decoyWorkspace.id) &&
        !flaggedWorkspaceIds.contains(decoyWorkspace.id)) {
      // Cascades that workspace's sites too — sites.workspace_id
      // REFERENCES workspaces(id) ON DELETE CASCADE, foreign_keys is ON.
      await targetWorkspaces.delete(decoyWorkspace.id);
    }
  }

  for (final decoyWorkspace in await targetWorkspaces.all()) {
    for (final decoySite in await targetSites.inWorkspace(decoyWorkspace.id)) {
      if (ownedSiteIds.contains(decoySite.id) &&
          !flaggedSiteIds.contains(decoySite.id)) {
        await targetSites.delete(decoySite.id);
      }
    }
  }

  return added;
}
```

`decoy_provisioner_test.dart` already imports everything this needs (`WorkspaceRepository`'s `StorageRule`, `Site`, `Workspace`) except nothing new — no import changes required.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/data/decoy_provisioner_test.dart`
Expected: PASS, all tests including the pre-existing `provisionDecoy` ones (unmodified, must still pass).

- [ ] **Step 5: Commit**

```bash
git add lib/data/repositories/decoy_provisioner.dart test/data/decoy_provisioner_test.dart
git commit -m "feat: add resyncDecoy, a two-way sync that preserves untouched profileIds"
```

---

### Task 2: Persist `decoy_configured` and wire `decoyEnabled`/`decoySiteCount` for real

**Files:**
- Modify: `lib/ui/features/setup/view_models/setup_controller.dart`
- Modify: `lib/ui/features/settings/view_models/providers.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart:197-221` (`_SettingsRoute`)
- Test: `test/ui/features/setup/setup_controller_test.dart`
- Test: `test/ui/features/settings/settings_providers_test.dart` (new)

**Interfaces:**
- Consumes: `SqliteSettingsRepository` (`lib/data/repositories/settings_repository_sqlite.dart` — `getBool(String key, {bool fallback = false})`, `setBool(String key, bool value)`), `siteRepositoryProvider`/`workspaceRepositoryProvider` (`lib/ui/features/dashboard/view_models/providers.dart`), `settingsRepositoryProvider` (already in `lib/ui/features/settings/view_models/providers.dart`).
- Produces: `decoyEnabledProvider` (`FutureProvider<bool>`), `decoySiteCountProvider` (`FutureProvider<int>`) in `lib/ui/features/settings/view_models/providers.dart` — both consumed by Task 5's `_SettingsRoute` wiring already added in this task.

- [ ] **Step 1: Write the failing test for `SetupController` persisting the flag**

Add to `test/ui/features/setup/setup_controller_test.dart` (uses the file's existing `controller()` helper and `setUp`):

```dart
  test('a decoy PIN persists decoy_configured=true on the real vault',
      () async {
    await controller().complete(mainPin: '111111', decoyPin: '222222');

    final mainDb = opened['${dir.path}/a.db']!;
    expect(
      await SqliteSettingsRepository(mainDb).getBool('decoy_configured'),
      isTrue,
    );
  });

  test('no decoy PIN persists decoy_configured=false on the real vault',
      () async {
    await controller().complete(mainPin: '111111');

    final mainDb = opened['${dir.path}/a.db']!;
    expect(
      await SqliteSettingsRepository(mainDb).getBool('decoy_configured'),
      isFalse,
    );
  });
```

Add the import at the top of the test file:

```dart
import 'package:container/data/repositories/settings_repository_sqlite.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/features/setup/setup_controller_test.dart`
Expected: FAIL — `getBool('decoy_configured')` returns `false` in the first new test (the flag is never written), so the first assertion fails. (The second test passes vacuously today, which is fine — it starts passing for the right reason once Step 3 lands.)

- [ ] **Step 3: Write the minimal implementation**

In `lib/ui/features/setup/view_models/setup_controller.dart`, add the import:

```dart
import '../../../../data/repositories/settings_repository_sqlite.dart';
```

Then in `complete()`, after `await seedIfEmpty(mainDb);` and before the `if (decoyPin != null)` branch:

```dart
    await seedIfEmpty(mainDb);
    await SqliteSettingsRepository(mainDb).setBool('decoy_configured', decoyPin != null);

    if (decoyPin != null) {
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ui/features/setup/setup_controller_test.dart`
Expected: PASS, all 6 tests (4 pre-existing + 2 new).

- [ ] **Step 5: Write the failing test for the new providers**

Create `test/ui/features/settings/settings_providers_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    container = ProviderContainer(overrides: [
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32))),
    ]);
    addTearDown(container.dispose);
  });

  test('decoyEnabledProvider reflects the persisted decoy_configured flag',
      () async {
    expect(await container.read(decoyEnabledProvider.future), isFalse);

    await SqliteSettingsRepository(db).setBool('decoy_configured', true);
    container.invalidate(decoyEnabledProvider);

    expect(await container.read(decoyEnabledProvider.future), isTrue);
  });

  test('decoySiteCountProvider counts only flagged sites', () async {
    await SqliteWorkspaceRepository(db).upsert(const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0,
        storageRule: StorageRule.keep, showInDecoy: true));
    await SqliteSiteRepository(db).upsert(Site(
        id: 's1', workspaceId: 'ws', name: 'News', monogram: 'Nw',
        url: 'https://news.example.com', profileId: newProfileId(),
        showInDecoy: true));
    await SqliteSiteRepository(db).upsert(Site(
        id: 's2', workspaceId: 'ws', name: 'Bank', monogram: 'Bk',
        url: 'https://bank.example.com', profileId: newProfileId(),
        showInDecoy: false));

    expect(await container.read(decoySiteCountProvider.future), 1);
  });
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/ui/features/settings/settings_providers_test.dart`
Expected: FAIL — `decoyEnabledProvider`/`decoySiteCountProvider` are undefined.

- [ ] **Step 7: Write the minimal implementation**

In `lib/ui/features/settings/view_models/providers.dart`, change the import of `databaseProvider` to also pull in the site repository:

```dart
import '../../dashboard/view_models/providers.dart'
    show databaseProvider, siteRepositoryProvider;
```

Then add, after `biometricsAvailableProvider`:

```dart
/// Backs `SettingsScreen`'s VAULT section visibility. `false` until
/// `SetupController.complete` (this plan's Task 2) has run with a non-null
/// `decoyPin`.
final decoyEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).getBool('decoy_configured'),
);

/// Backs `SettingsScreen`'s "Sites shown in decoy" row. Counts sites in the
/// currently open (real) vault flagged `showInDecoy` — never touches the
/// decoy vault itself, which this session does not have open.
final decoySiteCountProvider = FutureProvider<int>((ref) async {
  final sites = await ref.watch(siteRepositoryProvider).all();
  return sites.where((site) => site.showInDecoy).length;
});
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/ui/features/settings/settings_providers_test.dart`
Expected: PASS.

- [ ] **Step 9: Wire `_SettingsRoute` to the real providers**

In `lib/ui/features/dashboard/views/dashboard_screen.dart`, change the import list (around line 11-16) to add the two new providers to the existing settings-providers import, then replace the hardcoded values:

```dart
import '../../settings/view_models/providers.dart'
    show
        biometricsEnabledProvider,
        biometricsAvailableProvider,
        decoyEnabledProvider,
        decoySiteCountProvider,
        settingsControllerProvider;
```

(Match whatever the existing multi-line `show` clause currently lists — add the two new names to it rather than replacing the whole import.)

```dart
class _SettingsRoute extends ConsumerWidget {
  const _SettingsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometrics = ref.watch(biometricsEnabledProvider);
    final biometricsAvailable = ref.watch(biometricsAvailableProvider);
    final decoyEnabled = ref.watch(decoyEnabledProvider);
    final decoySiteCount = ref.watch(decoySiteCountProvider);
    return SettingsScreen(
      biometrics: biometrics.value ?? false,
      biometricsAvailable: biometricsAvailable.value ?? false,
      autoLockLabel: 'After 1 min',
      decoyEnabled: decoyEnabled.value ?? false,
      decoySiteCount: decoySiteCount.value ?? 0,
      hideFromSwitcher: true,
      panicOnFlip: false,
      onPanicLabel: 'Wipe + lock',
      onChanged: (key, value) {
        if (key == 'biometrics') {
          ref.read(settingsControllerProvider).setBiometricsEnabled(value);
        }
      },
      onTap: (_) {},
    );
  }
}
```

- [ ] **Step 10: Run the full test suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all tests pass (this task does not yet wire `onTap` — that's Task 5).

- [ ] **Step 11: Commit**

```bash
git add lib/ui/features/setup/view_models/setup_controller.dart lib/ui/features/settings/view_models/providers.dart lib/ui/features/dashboard/views/dashboard_screen.dart test/ui/features/setup/setup_controller_test.dart test/ui/features/settings/settings_providers_test.dart
git commit -m "feat: persist decoy_configured and wire Settings' VAULT section to real state"
```

---

### Task 3: `DecoyResyncPinScreen` — the PIN-entry widget

**Files:**
- Create: `lib/ui/features/settings/views/decoy_resync_pin_screen.dart`
- Test: `test/ui/features/settings/decoy_resync_pin_screen_test.dart`

**Interfaces:**
- Consumes: `PinDots`, `PinKeypad` (`lib/ui/core/widgets/pin_dots.dart`, `pin_keypad.dart` — signatures already shown in this plan's research; no changes needed to either).
- Produces: `DecoyResyncPinScreen` — a pure `StatelessWidget` (all state/logic lives in the caller, same separation `LockBody` uses relative to `LockScreen`):

```dart
class DecoyResyncPinScreen extends StatelessWidget {
  const DecoyResyncPinScreen({
    super.key,
    required this.filled,
    required this.error,
    required this.onKey,
  });

  final int filled;
  final bool error;
  final void Function(String key) onKey;
}
```

Task 5 supplies the `ConsumerStatefulWidget` wrapper that owns the PIN buffer (via the existing `LockController` from `lib/ui/features/lock/view_models/lock_controller.dart` — it already "knows nothing about vaults, PINs being right or wrong, or Riverpod," per its own doc comment, so it is directly reusable here with no changes) and calls `SettingsController.resyncDecoyVault`.

- [ ] **Step 1: Write the failing widget test**

Create `test/ui/features/settings/decoy_resync_pin_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/features/settings/views/decoy_resync_pin_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {int filled = 0, bool error = false}) {
    return tester.pumpWidget(MaterialApp(
      home: DecoyResyncPinScreen(filled: filled, error: error, onKey: (_) {}),
    ));
  }

  testWidgets('prompts for the decoy PIN and never mentions vaults',
      (tester) async {
    await pump(tester);

    expect(find.text('Enter the decoy PIN'), findsOneWidget);
    expect(find.textContaining('decoy vault'), findsNothing,
        reason: 'the same instinct LockBody follows: give no more away in '
            'copy than necessary');
  });

  testWidgets('shows six empty dots at rest', (tester) async {
    await pump(tester);

    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.filled, 0);
    expect(dots.error, isFalse);
  });

  testWidgets('shows filled dots as digits are entered', (tester) async {
    await pump(tester, filled: 3);

    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.filled, 3);
  });

  testWidgets('shows the error state and a wrong-PIN message', (tester) async {
    await pump(tester, error: true);

    final dots = tester.widget<PinDots>(find.byType(PinDots));
    expect(dots.error, isTrue);
    expect(find.text('Wrong PIN'), findsOneWidget);
  });

  testWidgets('forwards keypad taps', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: DecoyResyncPinScreen(filled: 0, error: false, onKey: pressed.add),
    ));

    await tester.tap(find.text('5'));

    expect(pressed, ['5']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/features/settings/decoy_resync_pin_screen_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/ui/features/settings/views/decoy_resync_pin_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';

/// Verifies the decoy PIN before `SettingsController.resyncDecoyVault` runs.
///
/// Deliberately built from the low-level `PinDots`/`PinKeypad` widgets
/// rather than `LockBody` — `LockBody` is coupled to the app-wide
/// `SessionController` lock state machine (resume moods, grace timers,
/// biometric resume), none of which applies to this one-off check
/// triggered from inside Settings. Says nothing about vaults, real or
/// decoy, in its copy — same instinct `LockBody` already follows.
class DecoyResyncPinScreen extends StatelessWidget {
  const DecoyResyncPinScreen({
    super.key,
    required this.filled,
    required this.error,
    required this.onKey,
  });

  final int filled;
  final bool error;
  final void Function(String key) onKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Enter the decoy PIN',
                        style: ui(size: 14, color: C.textMuted)),
                    const SizedBox(height: 26),
                    PinDots(filled: filled, error: error),
                    if (error) ...[
                      const SizedBox(height: 20),
                      Text('Wrong PIN', style: ui(size: 14, color: C.danger)),
                    ],
                  ],
                ),
              ),
              PinKeypad(onKey: onKey),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/features/settings/decoy_resync_pin_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/settings/views/decoy_resync_pin_screen.dart test/ui/features/settings/decoy_resync_pin_screen_test.dart
git commit -m "feat: add the decoy re-sync PIN entry screen (pure widget)"
```

---

### Task 4: `SettingsController.resyncDecoyVault` — PIN verification and the sync call

**Files:**
- Modify: `lib/ui/features/settings/view_models/providers.dart`
- Test: `test/ui/features/settings/settings_controller_test.dart`

**Interfaces:**
- Consumes: `VaultUnlocker` (`lib/domain/services/vault_unlocker.dart` — `attempt({pin, slots, gate, now}) → Future<UnlockOutcome>`, where `UnlockOutcome` is `Unlocked(vault, dataKey, gate)` / `Rejected(gate)` / `Throttled(remaining)`), `VaultStore` (`.gate()`, `.slots()`, `.saveGate(AttemptGate)`), `AttemptGate.recordFailure(DateTime)`, `vaultStoreProvider`/`cryptoServiceProvider`/`vaultOpenerProvider`/`documentsDirectoryProvider`/`vaultDatabasePath`/`sessionProvider`/`SessionOpen` (all `lib/ui/features/shell/view_models/session_controller.dart`), `resyncDecoy` (Task 1).
- Produces:

```dart
sealed class DecoyResyncOutcome {
  const DecoyResyncOutcome();
}

class DecoyResyncSucceeded extends DecoyResyncOutcome {
  const DecoyResyncSucceeded();
}

class DecoyResyncRejected extends DecoyResyncOutcome {
  const DecoyResyncRejected(this.triesLeft);
  final int triesLeft;
}

class DecoyResyncThrottled extends DecoyResyncOutcome {
  const DecoyResyncThrottled(this.remaining);
  final Duration remaining;
}
```

`Future<DecoyResyncOutcome> SettingsController.resyncDecoyVault(String pin)` — Task 5 calls this and maps the result to the PIN screen's `error` flag and the SnackBar.

- [ ] **Step 1: Write the failing tests**

Add to `test/ui/features/settings/settings_controller_test.dart` (reuses the file's existing `container`/`db`/`dir` setup, which already opens the real vault as `VaultId.a` via `initialSessionProvider` — these new tests additionally provision real slots in `vaultStoreProvider` so `VaultUnlocker` has something to match against):

```dart
  group('resyncDecoyVault', () {
    setUp(() async {
      final vaultStore =
          VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'));
      await vaultStore.provision(pin: '111111', vault: VaultId.a);
      await vaultStore.provision(pin: '222222', vault: VaultId.b);
      container = ProviderContainer(overrides: [
        cryptoServiceProvider.overrideWithValue(FakeCrypto()),
        vaultStoreProvider.overrideWithValue(vaultStore),
        documentsDirectoryProvider.overrideWithValue(dir),
        biometricServiceProvider.overrideWithValue(biometrics),
        vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) =>
              AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi),
        ),
        initialSessionProvider.overrideWithValue(
            SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32))),
      ]);
      addTearDown(container.dispose);
    });

    test('a correct decoy PIN runs the sync and resets the gate', () async {
      await SqliteWorkspaceRepository(db).upsert(const Workspace(
          id: 'ws', name: 'Personal', markerIndex: 0,
          storageRule: StorageRule.keep, showInDecoy: true));
      await SqliteSiteRepository(db).upsert(Site(
          id: 's1', workspaceId: 'ws', name: 'News', monogram: 'Nw',
          url: 'https://news.example.com', profileId: newProfileId(),
          showInDecoy: true));

      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('222222');

      expect(outcome, isA<DecoyResyncSucceeded>());
    });

    test('the main PIN is rejected the same as a wrong one', () async {
      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('111111');

      expect(outcome, isA<DecoyResyncRejected>());
    });

    test('a non-matching PIN is rejected and counts a failure', () async {
      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('000000');

      expect(outcome, isA<DecoyResyncRejected>());
      final gate = await container.read(vaultStoreProvider).gate();
      expect(gate.failures, 1);
    });

    test('five wrong attempts throttle the sixth', () async {
      for (var i = 0; i < 5; i++) {
        await container.read(settingsControllerProvider).resyncDecoyVault('000000');
      }

      final outcome =
          await container.read(settingsControllerProvider).resyncDecoyVault('000000');

      expect(outcome, isA<DecoyResyncThrottled>());
    });
  });
```

Add these imports to the top of the test file (alongside the existing ones):

```dart
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/features/settings/settings_controller_test.dart`
Expected: FAIL — `resyncDecoyVault` is undefined.

- [ ] **Step 3: Write the implementation**

In `lib/ui/features/settings/view_models/providers.dart`, extend the existing import of `session_controller.dart`:

```dart
import '../../shell/view_models/session_controller.dart'
    show
        biometricServiceProvider,
        sessionProvider,
        SessionOpen,
        vaultStoreProvider,
        cryptoServiceProvider,
        vaultOpenerProvider,
        documentsDirectoryProvider,
        vaultDatabasePath;
```

Add new imports:

```dart
import '../../../../data/repositories/decoy_provisioner.dart' show resyncDecoy;
import '../../../../domain/models/attempt_gate.dart';
import '../../../../domain/services/vault_unlocker.dart';
```

Add the result type above `class SettingsController`:

```dart
sealed class DecoyResyncOutcome {
  const DecoyResyncOutcome();
}

class DecoyResyncSucceeded extends DecoyResyncOutcome {
  const DecoyResyncSucceeded();
}

class DecoyResyncRejected extends DecoyResyncOutcome {
  const DecoyResyncRejected(this.triesLeft);
  final int triesLeft;
}

class DecoyResyncThrottled extends DecoyResyncOutcome {
  const DecoyResyncThrottled(this.remaining);
  final Duration remaining;
}
```

Add the method inside `SettingsController`:

```dart
  /// Verifies [pin] against both vault slots the same way the lock screen
  /// does, sharing its attempt-gate — a wrong guess here locks out the lock
  /// screen too, and vice versa, rather than opening a second independent
  /// brute-force surface. A match against the vault already open this
  /// session (re-entering the main PIN by mistake) is folded into the same
  /// generic rejection as a non-match: this is the same PIN-guessing
  /// surface [VaultUnlocker] itself never distinguishes, so this method
  /// does not either. Only a match against the *other* vault opens it, runs
  /// [resyncDecoy], and closes it again — its key and connection never
  /// outlive this one call.
  Future<DecoyResyncOutcome> resyncDecoyVault(String pin) async {
    final vaultStore = _ref.read(vaultStoreProvider);
    final unlocker = VaultUnlocker(_ref.read(cryptoServiceProvider));
    final now = DateTime.now();
    final beforeGate = await vaultStore.gate();
    final slots = await vaultStore.slots();
    final outcome = await unlocker.attempt(
      pin: pin,
      slots: slots,
      gate: beforeGate,
      now: now,
    );

    final session = _ref.read(sessionProvider);
    if (session is! SessionOpen) {
      return DecoyResyncRejected(beforeGate.triesLeft);
    }

    switch (outcome) {
      case Throttled(:final remaining):
        return DecoyResyncThrottled(remaining);
      case Rejected(:final gate):
        await vaultStore.saveGate(gate);
        return DecoyResyncRejected(gate.triesLeft);
      case Unlocked(:final vault, :final dataKey, :final gate):
        if (vault == session.vault) {
          final failedGate = beforeGate.recordFailure(now);
          await vaultStore.saveGate(failedGate);
          return DecoyResyncRejected(failedGate.triesLeft);
        }
        await vaultStore.saveGate(gate);
        final decoyDatabase = await _ref.read(vaultOpenerProvider)(
          path: vaultDatabasePath(_ref.read(documentsDirectoryProvider), vault),
          dataKey: dataKey,
        );
        await resyncDecoy(from: session.database, into: decoyDatabase);
        await decoyDatabase.close();
        _ref.invalidate(decoySiteCountProvider);
        return const DecoyResyncSucceeded();
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/ui/features/settings/settings_controller_test.dart`
Expected: PASS, all tests including the pre-existing biometrics ones (unmodified, must still pass).

- [ ] **Step 5: Run the full test suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/settings/view_models/providers.dart test/ui/features/settings/settings_controller_test.dart
git commit -m "feat: SettingsController.resyncDecoyVault verifies the decoy PIN and runs the sync"
```

---

### Task 5: Wire it together — Settings row, navigation, feedback

This task's Riverpod-wiring widget (`DecoyResyncRoute`) deliberately gets no
widget test of its own — same precedent `LockScreen` already sets in this
codebase: `LockBody` (pure widget) has `test/ui/features/lock_body_test.dart`,
`LockController` (pure state) has `test/ui/features/lock/lock_controller_test.dart`,
but `lib/ui/features/lock/views/lock_screen.dart`, the class that glues them
to `sessionProvider`, has no test file of its own anywhere in the tree —
it's covered by `SessionController`'s own tests plus the analyzer. This
task's `DecoyResyncRoute` is the exact same shape: `DecoyResyncPinScreen`
(Task 3) and `LockController` (reused, already tested) are the pure pieces;
`SettingsController.resyncDecoyVault` (Task 4) is the tested logic; this
task only wires them together.

**Files:**
- Create: `lib/ui/features/settings/views/decoy_resync_route.dart`
- Modify: `lib/ui/features/settings/views/settings_screen.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart`
- Test: `test/ui/features/settings_test.dart`

**Interfaces:**
- Consumes: `DecoyResyncPinScreen` (Task 3), `SettingsController.resyncDecoyVault` + `DecoyResyncOutcome` family (Task 4), `LockController` (`lib/ui/features/lock/view_models/lock_controller.dart` — reused as-is, no changes).
- Produces: `DecoyResyncRoute`, a public `ConsumerStatefulWidget` with a no-arg const constructor — `dashboard_screen.dart` is the only caller.

- [ ] **Step 1: Write the failing test for the new Settings row**

Add to `test/ui/features/settings_test.dart`:

```dart
  testWidgets('the re-sync row appears in the VAULT section and is tappable',
      (tester) async {
    var tapped = '';
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: true,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        onChanged: (_, __) {},
        onTap: (key) => tapped = key,
      ),
    ));

    expect(find.text('Re-sync decoy now'), findsOneWidget);
    await tester.tap(find.text('Re-sync decoy now'));

    expect(tapped, 'resyncDecoy');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/features/settings_test.dart`
Expected: FAIL — no widget with text `'Re-sync decoy now'`.

- [ ] **Step 3: Add the row to `SettingsScreen`**

In `lib/ui/features/settings/views/settings_screen.dart`, inside the `if (decoyEnabled) ...[` block, immediately after the existing `SettingRow(title: 'Sites shown in decoy', ...)`:

```dart
                    SettingRow(
                        title: 'Sites shown in decoy',
                        value: '$decoySiteCount selected',
                        onTap: () => onTap('decoySites')),
                    SettingRow(
                        title: 'Re-sync decoy now',
                        onTap: () => onTap('resyncDecoy')),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/features/settings_test.dart`
Expected: PASS.

- [ ] **Step 5: Create `DecoyResyncRoute`**

No failing test precedes this step — per this task's header note, this
Riverpod-wiring class follows `LockScreen`'s established precedent of
having no test file of its own; `DecoyResyncPinScreen` (Task 3) and
`LockController` (reused) are already tested as pure pieces, and
`SettingsController.resyncDecoyVault` (Task 4) is already tested as the
logic this class calls.

Create `lib/ui/features/settings/views/decoy_resync_route.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lock/view_models/lock_controller.dart';
import '../view_models/providers.dart';
import 'decoy_resync_pin_screen.dart';

/// Pushed from `SettingsScreen`'s "Re-sync decoy now" row. Owns the PIN
/// buffer (via the same [LockController] the real lock screen uses — it
/// "knows nothing about vaults, PINs being right or wrong, or Riverpod",
/// per its own doc comment, so it is directly reusable here) and calls
/// [SettingsController.resyncDecoyVault], mapping the result to
/// [DecoyResyncPinScreen]'s `error` flag or a success SnackBar + pop.
class DecoyResyncRoute extends ConsumerStatefulWidget {
  const DecoyResyncRoute({super.key});

  @override
  ConsumerState<DecoyResyncRoute> createState() => _DecoyResyncRouteState();
}

class _DecoyResyncRouteState extends ConsumerState<DecoyResyncRoute> {
  late final LockController _pin;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _pin = LockController(onSubmit: _submit)..addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _pin
      ..removeListener(_onPinChanged)
      ..dispose();
    super.dispose();
  }

  void _onPinChanged() => setState(() {});

  Future<void> _submit(String pin) async {
    final outcome =
        await ref.read(settingsControllerProvider).resyncDecoyVault(pin);
    if (!mounted) return;

    switch (outcome) {
      case DecoyResyncSucceeded():
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Decoy vault synced')));
        Navigator.pop(context);
      case DecoyResyncRejected():
      case DecoyResyncThrottled():
        setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoyResyncPinScreen(
      filled: _pin.value.filled,
      error: _error,
      onKey: (key) {
        if (_error) setState(() => _error = false);
        _pin.onKey(key);
      },
    );
  }
}
```

- [ ] **Step 6: Wire the Settings route's navigation**

In `lib/ui/features/dashboard/views/dashboard_screen.dart`, add the import:

```dart
import '../../settings/views/decoy_resync_route.dart';
```

Then change `_SettingsRoute`'s `onTap`:

```dart
      onTap: (key) {
        if (key == 'resyncDecoy') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const DecoyResyncRoute()));
        }
      },
```

This one line is not independently widget-tested, matching every other
`Navigator.push` already in this file (`onAddSite`, `onSearch`, the
container-navigation call in `onOpen`) — none of them have a
`DashboardScreen`-level test either; no such test file exists in the tree
today (`Glob 'test/ui/features/dashboard/**'` finds only
`site_row_menu_test.dart` and `workspace_bar_test.dart`, neither of which
constructs `DashboardScreen`). This plan does not introduce a new testing
tier `DashboardScreen`'s existing wiring doesn't already have.

- [ ] **Step 7: Run the full test suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: 0 issues, all tests pass.

- [ ] **Step 8: Update `CLAUDE.md`**

Add a row to the plan table for this plan (Plan 9 — Decoy re-sync), matching the existing table's style, and update the "Unassigned work" section's `**To a future decoy-resync plan:**`-style entry (currently in Plan 6's own handoff, referenced from `CLAUDE.md`'s "Unassigned work" section) to mark it done, pointing at this plan's file and the corrected function name (`resyncDecoy`, not the never-real `syncToDecoy`).

- [ ] **Step 9: Commit**

```bash
git add lib/ui/features/settings/views/settings_screen.dart lib/ui/features/settings/views/decoy_resync_route.dart lib/ui/features/dashboard/views/dashboard_screen.dart test/ui/features/settings_test.dart CLAUDE.md
git commit -m "feat: wire the decoy re-sync flow end to end from Settings"
```

## Known gaps this plan deliberately leaves

- `SettingsScreen` still cannot distinguish a real session from a decoy one — this new row is exactly as reachable from inside a decoy session as every other row already is. Confirmed out of scope during brainstorming.
- No progress indicator or synced-item count in the success SnackBar beyond the fixed "Decoy vault synced" copy.
- `workspaces`, `scripts`, and `decoySites`'s own `onTap` destinations remain unbuilt no-ops — this plan only makes the VAULT section's *visibility* real, not those other rows' actions.

## Handoff

- **To whoever eventually distinguishes real vs. decoy sessions in the UI layer:** this plan's new row, and the pre-existing "Decoy vault"/"Sites shown in decoy" rows, all become the first things that need gating once that distinction exists.
- **To whoever builds `decoySites`'s own screen:** `decoySiteCountProvider` (Task 2) already gives it a live count to start from.

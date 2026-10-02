# Privacy Controls Implementation Plan (Plan 16)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A security level (Standard / Safer / Safest), held as a vault default with a per-site override; New identity for one site; and `6c` as a per-site shield panel. These are Project 3 of the browser-chrome series.

**Architecture:**
- **Dart** stores the level in two places: per site in a nullable `security_level` column (schema 9), and as the vault default in `app_settings`.
  - It resolves the effective level at every open, through `EngineExtras`, and sends Kotlin only that.
- **Kotlin** turns the level into a `SecurityPolicy`. That policy is two WebView settings plus whether document-start scripts are added, and whether `shields/safer.js` is one of them.
  - Every page of a container is built from the one `SiteConfig` (Tabs spec §9), so the policy holds for every page of the container.
- **A change to a site applies by reopening its container in place.** That means `close(siteId, wipe: false)`, then `open` at the address the viewed page is showing.
- **New identity** is `wipeSavedSite` (or, for a throwaway, a close with wipe and a fresh profile), then a reopen at the site's saved address.
- **Revoke** is a native `revokeGrant` that drops one "allow while open" grant and reloads every page of the container.

**Tech Stack:**
- Kotlin, with JVM unit tests on JUnit 4.
- Flutter / Dart 3, with Riverpod.
- `sqflite_sqlcipher` in the app, and `sqflite_common_ffi` in tests.

**Spec:** `docs/superpowers/specs/2026-10-02-privacy-controls-design.md`. Read it before any task. Its "Decisions the user made", §5's copy and its "Rulings" are binding.

**Depends on Plan 15 (Tabs), which must be on `main` before Task 1.** This plan was written on 2026-10-02 against the **Tabs spec** (`docs/superpowers/specs/2026-10-02-tabs-design.md`, branch `claude/project-2-tabs-v4gbp5`). At that point Plan 15 had neither a plan file nor code: the user ruled that branch is Plan 15, and asked for Plan 16 against it.
- Tasks 1–8 and 11 touch nothing Plan 15 changes, except where a step says so.
- Tasks 5, 6, 9 and 10 build on Plan 15's code. The names they use (`Page`, `Session.pages`, `close(siteId, {wipe})`, `OpenContainers`, `ContainerHostRoute`, the per-container controller, `navigationState(pageId)`) are the Tabs spec's.
- "Before Task 1" checks those names against the real tree and records any difference. **Use the real names**, and use this plan's code for its logic, not its spelling.

## Global Constraints

- **Copy is verbatim.** These strings are the only new ones, exactly as spec §5 lists them:
  - `Standard`, `Safer`, `Safest`, `Security level`;
  - `Every site feature is on`, `JavaScript off on http pages · no WebGL or WebAssembly`, `JavaScript and images off on every page`;
  - `Default`, `<Level> · set in Settings`, `<Level> · default`;
  - `STANDARD`, `SAFER`, `SAFEST`, `New identity`;
  - `New identity for this site?`, `Its logins, storage and downloads are destroyed, and it starts over at its first page.`;
  - `Allowed`, `Revoke`.

  Everything else is reused verbatim from the canvas, or already in the tree. Nothing user-visible is reworded.
- **Two vaults.** No code asks which vault is open, and both vaults show the same controls. The vault default is per vault (`app_settings`) and is never read before an unlock. Nothing counts across vaults.
- **No network requests of the app's own.** Nothing here fetches anything. A reopen is the site's own traffic, on its own route.
- **The route never falls back to direct.** A reopen and New identity go through the same `open`, route resolution and loopback proxy as any open, and never change a route.
- **A reopen never wipes** (spec ruling 1). It calls `close(siteId, wipe: false)` whatever the cookie policy, throwaways included. **Only New identity** wipes, with `wipe: true`.
- **Unknown fails closed.** An unknown level is Safest, in Kotlin and in Dart (spec §1.5).
- **Jade:**
  - each picker's check is jade, as `SearchEnginePicker`'s already is;
  - `Revoke`, the menu rows and the New identity sheet add **no** jade;
  - in `6c`, `Edit` stays the only jade.
- **Dark only, hairlines not cards.** Use existing tokens (`lib/ui/core/tokens.dart`), and no new colours.
- **Everything goes on the open vault's own `Navigator`.** No `useRootNavigator: true` (`6a5f013`).
- **Nothing about pages is written to disk** (Tabs §2). A level is a site setting, and is stored. A page's address used for a reopen is held in memory only.
- **Kotlin is only compiled by Gradle.** `flutter analyze` and `flutter test` never compile `engine/`.
  - Kotlin tests: from `android/`, run `./gradlew :app:testDebugUnitTest`. In a fresh checkout, run `flutter build apk --debug` once first.
  - Read counts from `build/app/test-results/testDebugUnitTest/TEST-*.xml`, never from `BUILD SUCCESSFUL`.
  - Flutter and Gradle commands need the Bash sandbox disabled.
- **Never call `android.util.Log` in engine code**, and never log a host, URL or credential.
- **Branch:** `plan-16-privacy-controls`, off `main` once Plan 15 is merged. Commit after every task. **Never push or merge to `main` without asking the user.**

## Review Focus

1. **A reopen of a throwaway or a wipe-on-exit site keeps its cookies.** It must call `close(siteId, wipe: false)`, never a bare `close`. A bare close wipes by the session's own flag, which would log the user out on every switch. Pinned in Task 9.
2. **A level that is unknown, missing or misspelt** is Safest natively (`SecurityLevel.fromChannel`), and a stored unknown name reads `safest` in Dart. Pinned in Tasks 1 and 5.
3. **A Safest page runs no document-start script at all, and has JavaScript off.** That includes a page opened later by a link in the same container, which goes through the same `Page` construction. Pinned in Task 5.
4. **Revoke drops only the kind named, reloads every page of the container, and emits a new session list.** A stored (`2a`) grant is never touched. Pinned in Task 6.
5. **New identity on a saved site writes the fresh `profileId` before it reopens, and reopens at `site.url`, never at the page being shown.** On a throwaway, the reopened throwaway has a new profile and is still journaled as one. Pinned in Task 10.
6. **The vault default is read fresh from the repository at each open,** not from a cached provider, so a change in Settings reaches the next open. Pinned in Task 4.

---

## Before Task 1: baseline

- [ ] **Step 1: Plan 15 is on `main`.** Run `git log --oneline main | head` and confirm Plan 15's merge. If it is not there, stop and tell the user: this plan is written against it.
- [ ] **Step 2: Branch.** `git checkout -b plan-16-privacy-controls main`.
- [ ] **Step 3: Gates on the untouched tree.** Run `flutter analyze`, `flutter test`, `cd android && ./gradlew :app:testDebugUnitTest`, and `flutter build apk --debug`. Record each count, the Kotlin count read from the JUnit XML, in the Execution record at the end of this file. Every later count is compared with these.
- [ ] **Step 4: Plan 15's names.** For each name in the table, find the real one (`grep -rn`) and fill in the right-hand column of the copy in the Execution record:

| Tabs spec name | Used in this plan's tasks | Real name |
|---|---|---|
| Kotlin `Page` (owns one WebView; replaced `ContainerView`) | 5 | |
| `Session.pages: LinkedHashMap<String, Page>` | 6 | |
| `Page.reload()` | 6 | |
| Dart `ContainerEngine.close(String siteId, {bool? wipe})` | 9, 10 | |
| Dart `ContainerEngine.navigationState(String pageId)` | 9 | |
| `OpenContainers` registry and its entry type (site, throwaway flag, last viewed page id) | 9, 10 | |
| The per-container controller that holds `8b`'s reopen | 9, 10 | |
| `ContainerHostRoute` (where `_showSiteSheet` now lives) | 9, 10 | |
| `FakeContainerEngine`'s record of `close` calls with their `wipe` argument | 9, 10 | |
| `wipeSavedSite` (now `close(siteId, wipe: true)` then the rotation, Tabs §5.8a) | 10 | |

  If anything is missing (for example, the fake records `close` but not its `wipe`), add the smallest piece the task needs, in that task's commit, with a test.

---

## File map

| File | Change |
|---|---|
| `lib/domain/models/security_level.dart` | **Create.** `SecurityLevel`, `securityLevelSettingKey`, `effectiveLevel`, `securityLevelValue`. |
| `lib/domain/models/site.dart` | `securityLevel`, `copyWith`, `withSecurityLevel`, `withoutProxy` carries it. |
| `lib/data/services/app_database.dart` | Schema 9, `security_level` column, row mapping. |
| `lib/domain/models/engine_extras.dart` | `securityLevel`. |
| `lib/data/services/engine_extras_builder.dart` | Resolves the effective level from the site and the stored default. |
| `lib/ui/features/container/view_models/providers.dart` | The builder reads the settings repository. |
| `lib/data/services/container_engine.dart`, `container_engine_channel.dart`, `fake_container_engine.dart` | `securityLevel` sent; `revokeGrant`; `ContainerSession.grants` decoded. |
| `lib/domain/models/container_session.dart` | `grants`. |
| `lib/domain/models/permissions_in_use.dart` | **Create.** `PermissionInUse`, `permissionsInUse`. |
| `lib/ui/features/settings/view_models/providers.dart` | `vaultSecurityLevelProvider`, `SettingsController.setSecurityLevel`. |
| `lib/ui/features/settings/views/security_level_picker.dart` | **Create.** The vault picker and the site picker. |
| `lib/ui/features/settings/views/settings_screen.dart`, `settings_route.dart` | BROWSING's `Security level` row. |
| `lib/ui/features/in_page/views/site_sheet.dart` | `6c` as the shield panel. |
| `lib/ui/features/container/views/browser_menu_sheet.dart`, `container_screen.dart` | The two ☰ rows. |
| `lib/ui/features/container/views/new_identity_sheet.dart` | **Create.** The confirm sheet. |
| Plan 15's host route and per-container controller | Reopen in place, the pickers, the switches, Revoke, New identity. |
| `android/.../engine/SecurityPolicy.kt` | **Create.** `SecurityLevel`, `SecurityPolicy`, `securityPolicyFor`. |
| `android/app/src/main/assets/shields/safer.js` | **Create.** |
| `android/.../engine/SiteConfig.kt`, `EngineChannel.kt`, `Shields.kt`, Plan 15's `Page.kt` | The level read, applied; grants in the session map; `revokeGrant`. |
| `android/.../engine/SessionGrants.kt` | **Create.** |
| `tool/device-check/pages.py`, `README.md` | **Create** / extend: local test pages and the Plan 16 run sheet. |
| `CLAUDE.md` | Plan 16 row. |

`android/...` is `android/app/src/main/kotlin/com/mono/container`. Kotlin tests go under `android/app/src/test/kotlin/com/mono/container/engine/`.

---

### Task 1: `SecurityLevel` and `Site.securityLevel`

**Files:**
- Create: `lib/domain/models/security_level.dart`
- Modify: `lib/domain/models/site.dart`
- Test: `test/domain/security_level_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/domain/security_level_test.dart
import 'package:container/domain/models/security_level.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = Site(
  id: 's', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p',
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
  proxyUser: 'alice', proxyPassword: 'pw', blockWebRtc: false,
);

void main() {
  test('the copy is spec §5, verbatim', () {
    expect(SecurityLevel.values.map((l) => l.label), ['Standard', 'Safer', 'Safest']);
    expect(SecurityLevel.values.map((l) => l.meta), ['STANDARD', 'SAFER', 'SAFEST']);
    expect(SecurityLevel.values.map((l) => l.description), [
      'Every site feature is on',
      'JavaScript off on http pages · no WebGL or WebAssembly',
      'JavaScript and images off on every page',
    ]);
  });

  test('a stored name reads back; nothing stored is null; anything else is safest', () {
    for (final level in SecurityLevel.values) {
      expect(SecurityLevel.fromStored(level.name), level);
    }
    expect(SecurityLevel.fromStored(null), isNull);
    expect(SecurityLevel.fromStored('Safer'), SecurityLevel.safest, reason: 'fails closed');
    expect(SecurityLevel.fromStored(''), SecurityLevel.safest);
  });

  test('the vault default is Standard until one is stored, and fails closed', () {
    expect(SecurityLevel.vaultDefaultFrom(null), SecurityLevel.standard);
    expect(SecurityLevel.vaultDefaultFrom('safer'), SecurityLevel.safer);
    expect(SecurityLevel.vaultDefaultFrom('bogus'), SecurityLevel.safest);
  });

  test('a site follows the default until it has its own level', () {
    expect(effectiveLevel(_site, SecurityLevel.safer), SecurityLevel.safer);
    final own = _site.withSecurityLevel(SecurityLevel.safest);
    expect(effectiveLevel(own, SecurityLevel.standard), SecurityLevel.safest);
  });

  test("6c's value marks a followed default", () {
    expect(securityLevelValue(_site, SecurityLevel.standard), 'Standard · default');
    expect(securityLevelValue(_site.withSecurityLevel(SecurityLevel.safer), SecurityLevel.standard),
        'Safer');
  });

  test('withSecurityLevel sets and clears, and keeps every other field', () {
    final set = _site.withSecurityLevel(SecurityLevel.safer);
    expect(set.securityLevel, SecurityLevel.safer);
    final cleared = set.withSecurityLevel(null);
    expect(cleared.securityLevel, isNull);
    expect(cleared.proxyUser, 'alice');
    expect(cleared.proxyPort, 9050);
    expect(cleared.blockWebRtc, isFalse);
    expect(cleared.profileId, 'p');
  });

  test('copyWith and withoutProxy keep the level', () {
    final own = _site.withSecurityLevel(SecurityLevel.safest);
    expect(own.copyWith(profileId: 'q').securityLevel, SecurityLevel.safest);
    expect(own.withoutProxy().securityLevel, SecurityLevel.safest);
  });

  test('a new site follows the default', () {
    expect(_site.securityLevel, isNull);
  });
}
```

- [ ] **Step 2: Run it and see it fail.** `flutter test test/domain/security_level_test.dart` fails because `security_level.dart` does not exist.

- [ ] **Step 3: Create `lib/domain/models/security_level.dart`**

```dart
import 'site.dart';

/// The `app_settings` key of the open vault's default level (spec §2.1).
const securityLevelSettingKey = 'security_level';

/// What a site may run (privacy-controls spec §1). The names and intent are
/// Mullvad Browser's; what each switches off is what WebView can switch off.
enum SecurityLevel {
  standard('Standard', 'STANDARD', 'Every site feature is on'),
  safer('Safer', 'SAFER', 'JavaScript off on http pages · no WebGL or WebAssembly'),
  safest('Safest', 'SAFEST', 'JavaScript and images off on every page');

  const SecurityLevel(this.label, this.meta, this.description);

  /// The level's name: pickers, `6c` and Settings (spec §5).
  final String label;

  /// The ☰ row's mono meta (spec §5).
  final String meta;

  /// The picker's second line (spec §5).
  final String description;

  /// A stored or sent name. Nothing stored is null ("follow the default"
  /// for a site). Any other name fails closed to [safest] (spec §1.5): only a
  /// downgrade or a damaged row can produce one.
  static SecurityLevel? fromStored(String? name) {
    if (name == null) return null;
    for (final level in values) {
      if (level.name == name) return level;
    }
    return safest;
  }

  /// The vault default: [standard] until one is stored (spec §2.1).
  static SecurityLevel vaultDefaultFrom(String? name) => fromStored(name) ?? standard;
}

/// What [site] runs at: its own level, or else the vault default (spec §2.2).
SecurityLevel effectiveLevel(Site site, SecurityLevel vaultDefault) =>
    site.securityLevel ?? vaultDefault;

/// `6c`'s Security level value (spec §5): `<Level>` for a site's own level,
/// `<Level> · default` while it follows the vault default.
String securityLevelValue(Site site, SecurityLevel vaultDefault) =>
    site.securityLevel?.label ?? '${vaultDefault.label} · default';
```

- [ ] **Step 4: Add the field to `Site`** (`lib/domain/models/site.dart`)
  - Add `import 'security_level.dart';` at the top.
  - Constructor: add `this.securityLevel,` after `this.sortIndex = 0,`.
  - Field, after `sortIndex`:

```dart
  /// This site's own level, or null to follow the vault default
  /// (privacy-controls spec §2.1). A setting, not data: no wipe and no New
  /// identity changes it, and decoy re-sync copies it.
  final SecurityLevel? securityLevel;
```

  - `copyWith`: add the parameter `SecurityLevel? securityLevel,` and the argument `securityLevel: securityLevel ?? this.securityLevel,`. `copyWith` cannot clear it; `withSecurityLevel` can.
  - `withoutProxy()`: add `securityLevel: securityLevel,`.
  - Add, after `withoutProxy`:

```dart
  /// This site with [level] as its own level; null clears it, so the site
  /// follows the vault default again. `copyWith` cannot set null.
  Site withSecurityLevel(SecurityLevel? level) => Site(
        id: id,
        workspaceId: workspaceId,
        name: name,
        monogram: monogram,
        url: url,
        profileId: profileId,
        blockWebRtc: blockWebRtc,
        blockTrackers: blockTrackers,
        antiFingerprinting: antiFingerprinting,
        allowCamera: allowCamera,
        allowMicrophone: allowMicrophone,
        allowLocation: allowLocation,
        allowClipboard: allowClipboard,
        userAgentMode: userAgentMode,
        forceDark: forceDark,
        openInReader: openInReader,
        pageZoom: pageZoom,
        customCss: customCss,
        customJs: customJs,
        cookiePolicy: cookiePolicy,
        proxyMode: proxyMode,
        proxyHost: proxyHost,
        proxyPort: proxyPort,
        proxyUser: proxyUser,
        proxyPassword: proxyPassword,
        proxyLoginPerSite: proxyLoginPerSite,
        requirePin: requirePin,
        showInDecoy: showInDecoy,
        lastVisitedAt: lastVisitedAt,
        sortIndex: sortIndex,
        securityLevel: level,
      );
```

  If Plan 15 added fields to `Site`, add them here too: Task 2's row-map test catches a field this copy drops.

- [ ] **Step 5: Run it and see it pass.** `flutter test test/domain/security_level_test.dart`, then `flutter analyze`.

- [ ] **Step 6: Commit.** `git commit -am "feat: SecurityLevel and a site's own level"` (add the new files first).

---

### Task 2: Schema 9 — the column, the upgrade, the decoy and throwaways

**Files:**
- Modify: `lib/data/services/app_database.dart`
- Test: `test/data/security_level_storage_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/security_level_storage_test.dart
import 'dart:io';

import 'package:container/data/repositories/decoy_provisioner.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/security_level.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/throwaway.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _site = Site(
  id: 's1', workspaceId: 'ws', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
);

Future<AppDatabase> _open() =>
    AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);

Future<void> _workspace(AppDatabase db, {bool showInDecoy = false}) =>
    SqliteWorkspaceRepository(db).upsert(Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep,
        showInDecoy: showInDecoy));

void main() {
  setUpAll(sqfliteFfiInit);

  test('a site keeps its own level, and a followed default stays null', () async {
    final db = await _open();
    addTearDown(db.close);
    await _workspace(db);
    final sites = SqliteSiteRepository(db);
    await sites.upsert(_site.withSecurityLevel(SecurityLevel.safer));
    await sites.upsert(const Site(
        id: 's2', workspaceId: 'ws', name: 'Mail', monogram: 'Ml',
        url: 'https://mail.example.com', profileId: 'p2'));

    expect((await sites.byId('s1'))!.securityLevel, SecurityLevel.safer);
    expect((await sites.byId('s2'))!.securityLevel, isNull);

    await sites.upsert((await sites.byId('s1'))!.withSecurityLevel(null));
    expect((await sites.byId('s1'))!.securityLevel, isNull, reason: 'cleared, not kept');
  });

  test('an unknown stored level reads as safest', () async {
    final db = await _open();
    addTearDown(db.close);
    await _workspace(db);
    await SqliteSiteRepository(db).upsert(_site);
    await db.db.update('sites', {'security_level': 'paranoid'});
    expect((await SqliteSiteRepository(db).byId('s1'))!.securityLevel, SecurityLevel.safest);
  });

  test('withSecurityLevel drops no column', () {
    final row = siteToRow(_site);
    final copied = siteToRow(_site.withSecurityLevel(SecurityLevel.safest));
    expect(copied.keys, row.keys);
    for (final key in row.keys) {
      if (key == 'security_level') continue;
      expect(copied[key], row[key], reason: key);
    }
  });

  test('a v8 vault upgrades its sites to follow the default', () async {
    final dir = await Directory.systemTemp.createTemp('v8-upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/store.db';

    final v8 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 8, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE workspaces (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, marker_index INTEGER NOT NULL,
          storage_rule TEXT NOT NULL, require_pin INTEGER NOT NULL DEFAULT 0,
          show_in_decoy INTEGER NOT NULL DEFAULT 0, sort_index INTEGER NOT NULL DEFAULT 0)
      ''');
      await db.execute('''
        CREATE TABLE sites (
          id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
          name TEXT NOT NULL, monogram TEXT NOT NULL, url TEXT NOT NULL,
          cookie_policy TEXT NOT NULL, proxy_mode TEXT NOT NULL, proxy_host TEXT, proxy_port INTEGER,
          proxy_user TEXT, proxy_password TEXT, proxy_login_per_site INTEGER NOT NULL DEFAULT 0,
          require_pin INTEGER NOT NULL DEFAULT 0, show_in_decoy INTEGER NOT NULL DEFAULT 0,
          last_visited_at INTEGER, last_worked_at INTEGER, sort_index INTEGER NOT NULL DEFAULT 0,
          profile_id TEXT NOT NULL, block_webrtc INTEGER NOT NULL DEFAULT 1,
          block_trackers INTEGER NOT NULL DEFAULT 1, anti_fingerprinting INTEGER NOT NULL DEFAULT 1,
          allow_camera INTEGER NOT NULL DEFAULT 0, allow_microphone INTEGER NOT NULL DEFAULT 0,
          allow_location INTEGER NOT NULL DEFAULT 0, allow_clipboard INTEGER NOT NULL DEFAULT 0,
          user_agent_mode TEXT NOT NULL DEFAULT 'android', force_dark INTEGER NOT NULL DEFAULT 1,
          open_in_reader INTEGER NOT NULL DEFAULT 0, page_zoom INTEGER NOT NULL DEFAULT 100,
          custom_css TEXT NOT NULL DEFAULT '', custom_js TEXT NOT NULL DEFAULT '')
      ''');
    }));
    await v8.insert('workspaces',
        {'id': 'ws', 'name': 'Personal', 'marker_index': 0, 'storage_rule': 'keep'});
    await v8.insert('sites', {
      'id': 's1', 'workspace_id': 'ws', 'name': 'Forum', 'monogram': 'Fr',
      'url': 'https://forum.example.com', 'cookie_policy': 'keep',
      'proxy_mode': 'direct', 'profile_id': 'p1',
    });
    await v8.close();

    final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);
    final site = siteFromRow((await upgraded.db.query('sites')).single);
    expect(site.securityLevel, isNull);
    expect(site.url, 'https://forum.example.com', reason: 'nothing else changes');
    await upgraded.close();
  });

  test('decoy re-sync copies a site\'s own level', () async {
    final real = await _open();
    final decoy = await _open();
    addTearDown(real.close);
    addTearDown(decoy.close);
    await _workspace(real, showInDecoy: true);
    await SqliteSiteRepository(real).upsert(_site.withSecurityLevel(SecurityLevel.safest));

    await resyncDecoy(from: real, into: decoy);

    final copied = (await SqliteSiteRepository(decoy).all()).single;
    expect(copied.securityLevel, SecurityLevel.safest);
    expect(copied.profileId, isNot('p1'), reason: 'its own profile, as every sync');
  });

  test('a throwaway follows the vault default', () {
    final throwaway = buildThrowaway(
      destination: Throwaway(Uri.parse('https://news.example.org'), ProxyMode.direct, null, null),
      current: _site.withSecurityLevel(SecurityLevel.safest),
      newId: () => 'fresh',
    );
    expect(throwaway.securityLevel, isNull, reason: 'spec: only the route is inherited');
  });
}
```


- [ ] **Step 2: Run it and see it fail.** `flutter test test/data/security_level_storage_test.dart` fails: the column does not exist, and `schemaVersion` is 8.

- [ ] **Step 3: Schema 9** (`lib/data/services/app_database.dart`)
  - `static const schemaVersion = 9;`
  - `onCreate`'s `sites` table: add a line after `custom_js` (keep the comma rules valid):

```sql
              custom_js           TEXT    NOT NULL DEFAULT '',
              -- This site's own security level, or NULL to follow the
              -- vault default (`app_settings.security_level`).
              security_level      TEXT
```

  - `onUpgrade`, after the `from < 8` step:

```dart
          if (from < 9) {
            // Privacy controls: every existing site follows the vault
            // default, which is Standard until one is chosen.
            await db.execute('ALTER TABLE sites ADD COLUMN security_level TEXT');
          }
```

  - `siteToRow`: add `'security_level': s.securityLevel?.name,`.
  - `siteFromRow`: add `securityLevel: SecurityLevel.fromStored(r['security_level'] as String?),`, and import `../../domain/models/security_level.dart`.

- [ ] **Step 4: Run it and see it pass**, then run the whole suite: `flutter test`. Any test that builds a v1–v8 fixture and checks `schemaVersion` must still pass, because each upgrade step stands alone.

- [ ] **Step 5: Commit.** `git commit -m "feat: store a site's own security level (schema 9)"`.

---

### Task 3: The vault default — provider, controller, pickers, Settings row

**Files:**
- Create: `lib/ui/features/settings/views/security_level_picker.dart`
- Modify: `lib/ui/features/settings/view_models/providers.dart`, `settings_screen.dart`, `settings_route.dart`
- Test: `test/ui/features/settings/security_level_picker_test.dart`, `test/ui/features/settings/security_level_setting_test.dart`

- [ ] **Step 1: Write the failing picker test**

```dart
// test/ui/features/settings/security_level_picker_test.dart
import 'package:container/domain/models/security_level.dart';
import 'package:container/ui/features/settings/views/security_level_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget picker) => MaterialApp(home: Scaffold(body: picker));

Finder _checkIn(String title) => find.descendant(
      of: find.ancestor(of: find.text(title), matching: find.byType(Row)).first,
      matching: find.byIcon(Icons.check),
    );

void main() {
  testWidgets('the vault picker lists the three levels with their lines, the current checked',
      (tester) async {
    await tester.pumpWidget(_host(
        SecurityLevelPicker.vault(current: SecurityLevel.safer, onPick: (_) {})));

    expect(find.text('Security level'), findsOneWidget);
    for (final level in SecurityLevel.values) {
      expect(find.text(level.label), findsOneWidget);
      expect(find.text(level.description), findsOneWidget);
    }
    expect(find.text('Default'), findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(_checkIn('Safer'), findsOneWidget);
  });

  testWidgets('the site picker starts with Default, checked while the site follows it',
      (tester) async {
    await tester.pumpWidget(_host(SecurityLevelPicker.site(
        current: null, vaultDefault: SecurityLevel.standard, onPick: (_) {})));

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Standard · set in Settings'), findsOneWidget);
    expect(_checkIn('Default'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets("a site's own level is checked instead of Default", (tester) async {
    await tester.pumpWidget(_host(SecurityLevelPicker.site(
        current: SecurityLevel.safest, vaultDefault: SecurityLevel.safer, onPick: (_) {})));

    expect(find.text('Safer · set in Settings'), findsOneWidget);
    expect(_checkIn('Safest'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('tapping reports the level, and Default reports null', (tester) async {
    final picked = <SecurityLevel?>[];
    await tester.pumpWidget(_host(SecurityLevelPicker.site(
        current: SecurityLevel.safest, vaultDefault: SecurityLevel.standard, onPick: picked.add)));

    await tester.tap(find.text('Safer'));
    await tester.tap(find.text('Default'));
    expect(picked, [SecurityLevel.safer, null]);
  });
}
```

- [ ] **Step 2: Run it and see it fail** (the file does not exist).

- [ ] **Step 3: Create the picker**

```dart
// lib/ui/features/settings/views/security_level_picker.dart
import 'package:flutter/material.dart';

import '../../../../domain/models/security_level.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/sheet.dart';

/// Privacy-controls spec §2.3, built like `SearchEnginePicker`, with the
/// current row checked in its jade.
///
/// [SecurityLevelPicker.vault] is Settings' picker for the vault default: the
/// three levels. [SecurityLevelPicker.site] is the ☰ and `6c` picker for one
/// site: a `Default` row first, which reports null, so the site follows the
/// vault default from then on.
class SecurityLevelPicker extends StatelessWidget {
  const SecurityLevelPicker.vault({
    super.key,
    required SecurityLevel this.current,
    required this.onPick,
  }) : vaultDefault = null;

  const SecurityLevelPicker.site({
    super.key,
    required this.current,
    required SecurityLevel this.vaultDefault,
    required this.onPick,
  });

  /// The level chosen now; null while a site follows the default.
  final SecurityLevel? current;

  /// Set for a site's picker only: shown on its `Default` row.
  final SecurityLevel? vaultDefault;

  final ValueChanged<SecurityLevel?> onPick;

  @override
  Widget build(BuildContext context) {
    final vaultDefault = this.vaultDefault;
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Text('Security level', style: T.sheetTitle),
        ),
        if (vaultDefault != null)
          _LevelRow(
            title: 'Default',
            line: '${vaultDefault.label} · set in Settings',
            checked: current == null,
            onTap: () => onPick(null),
          ),
        for (final level in SecurityLevel.values)
          _LevelRow(
            title: level.label,
            line: level.description,
            checked: current == level,
            onTap: () => onPick(level),
          ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.title,
    required this.line,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final String line;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.line05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ui(size: 14.5, color: C.textPrimary)),
                  const SizedBox(height: 3),
                  Text(line, style: ui(size: 12, color: C.textFaint)),
                ],
              ),
            ),
            if (checked) const Icon(Icons.check, size: 15, color: C.jade),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the picker test and see it pass.**

- [ ] **Step 5: Write the failing setting test**, modelled on `search_engine_setting_test.dart` (same `_settle` helper and the same overrides):

```dart
// test/ui/features/settings/security_level_setting_test.dart
// (imports as search_engine_setting_test.dart, plus security_level.dart)

void main() {
  setUpAll(sqfliteFfiInit);

  test('the vault default reads Standard until another is stored, and fails closed', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(vaultSecurityLevelProvider.future), SecurityLevel.standard);

    await SqliteSettingsRepository(database).setString('security_level', 'safer');
    container.invalidate(vaultSecurityLevelProvider);
    expect(await container.read(vaultSecurityLevelProvider.future), SecurityLevel.safer);

    await SqliteSettingsRepository(database).setString('security_level', 'x');
    container.invalidate(vaultSecurityLevelProvider);
    expect(await container.read(vaultSecurityLevelProvider.future), SecurityLevel.safest);
  });

  testWidgets("picking a level in 2d's BROWSING stores it in the open vault and shows it",
      (tester) async {
    // Same database, surface and ProviderScope setup as the search-engine test.
    // ...
    await _settle(tester);
    expect(find.text('Security level'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget, reason: 'the row value');

    await tester.tap(find.text('Security level'));
    await tester.pumpAndSettle();
    expect(find.text('Default'), findsNothing, reason: 'the vault picker has no Default row');
    await tester.tap(find.text('Safest'));
    await tester.pumpAndSettle();
    await _settle(tester);

    final stored = await tester.runAsync(
        () => SqliteSettingsRepository(database).getString('security_level'));
    expect(stored, 'safest');
    expect(find.text('Safest'), findsOneWidget);
  });
}
```

  Write the elided setup in full, copied from `search_engine_setting_test.dart`; the sketch above only marks where it goes.

- [ ] **Step 6: Run it and see it fail.**

- [ ] **Step 7: Provider and controller** (`lib/ui/features/settings/view_models/providers.dart`; import `security_level.dart`)

```dart
/// Privacy-controls spec §2.1: the open vault's default level, stored as the
/// enum name under `security_level`. Per vault, like the search engine, and
/// never read before an unlock. Standard until chosen; unknown is Safest.
final vaultSecurityLevelProvider = FutureProvider<SecurityLevel>((ref) async {
  final stored = await ref.watch(settingsRepositoryProvider).getString(securityLevelSettingKey);
  return SecurityLevel.vaultDefaultFrom(stored);
});
```

  In `SettingsController`, after `setSearchEngine`:

```dart
  /// The vault default (spec §2.3). Open sites keep the level they opened
  /// with until their next open (user's ruling, 2026-10-02).
  Future<void> setSecurityLevel(SecurityLevel level) async {
    await _ref.read(settingsRepositoryProvider).setString(securityLevelSettingKey, level.name);
    _ref.invalidate(vaultSecurityLevelProvider);
  }
```

- [ ] **Step 8: The Settings row**
  - **`settings_screen.dart`:**
    - Add `required this.securityLevelName,`, with the field doc `/// The vault default's name (privacy-controls spec §2.3); empty while it loads.` and `final String securityLevelName;`.
    - In BROWSING, after the `Search engine` row:

```dart
                  SettingRow(
                    title: 'Security level',
                    value: securityLevelName,
                    onTap: () => onTap('securityLevel'),
                  ),
```

  - **`settings_route.dart`:**
    - Watch `final securityLevel = ref.watch(vaultSecurityLevelProvider).valueOrNull;` and pass `securityLevelName: securityLevel?.label ?? '',`.
    - In `onTap`, before the destination lookup:

```dart
        if (key == 'securityLevel') {
          _pickSecurityLevel(context, ref, securityLevel ?? SecurityLevel.standard);
          return;
        }
```

  - Add the method, beside `_pickSearchEngine`:

```dart
  void _pickSecurityLevel(BuildContext context, WidgetRef ref, SecurityLevel current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SecurityLevelPicker.vault(
        current: current,
        onPick: (level) {
          Navigator.pop(sheetContext);
          ref.read(settingsControllerProvider).setSecurityLevel(level!);
        },
      ),
    );
  }
```

  - Update `settingsDestination`'s doc: `securityLevel` is a third key that opens a sheet.
  - `grep -rn "SettingsScreen(" lib test`: every other caller passes `securityLevelName: 'Standard'`.

- [ ] **Step 9: Run both tests, `flutter test test/ui/features/settings`, and `flutter analyze`.** All pass.

- [ ] **Step 10: Commit.** `git commit -m "feat(settings): the vault's default security level"`.

---

### Task 4: The effective level reaches the engine

**Files:**
- Modify: `lib/domain/models/engine_extras.dart`, `lib/data/services/engine_extras_builder.dart`, `lib/ui/features/container/view_models/providers.dart`, `lib/data/services/container_engine_channel.dart`
- Test: `test/data/engine_extras_builder_test.dart` (extend), `test/data/container_engine_channel_test.dart` (extend)

- [ ] **Step 1: Write the failing tests**
  - **`engine_extras_builder_test.dart`:**
    - Add a group that passes a `SqliteSettingsRepository` on the in-memory database the file already opens, or a two-line fake implementing `SettingsRepository`'s `getString`.
    - Update every existing `engineExtrasFor(...)` call to pass `settings:`.

```dart
  group('security level (privacy-controls spec §2.2)', () {
    test('a site with its own level opens at it, whatever the default', () async {
      await settings.setString('security_level', 'standard');
      final extras = await build(site.withSecurityLevel(SecurityLevel.safest));
      expect(extras.securityLevel, SecurityLevel.safest);
    });

    test('a site that follows the default opens at the stored default', () async {
      await settings.setString('security_level', 'safer');
      expect((await build(site)).securityLevel, SecurityLevel.safer);
    });

    test('nothing stored is Standard; an unknown default is Safest', () async {
      expect((await build(site)).securityLevel, SecurityLevel.standard);
      await settings.setString('security_level', '??');
      expect((await build(site)).securityLevel, SecurityLevel.safest);
    });

    test('the default is read at each build, not remembered', () async {
      expect((await build(site)).securityLevel, SecurityLevel.standard);
      await settings.setString('security_level', 'safest');
      expect((await build(site)).securityLevel, SecurityLevel.safest);
    });
  });
```

    Here `build(site)` is the file's helper calling `engineExtrasFor(site, filterLists: …, scripts: …, rules: …, settings: settings)`. Add the helper if the file has none.

  - **`container_engine_channel_test.dart`,** beside "open sends the proxy login and the per-site choice", with the same mock setup:

```dart
    test('open sends the effective security level', () async {
      // same handler setup as the neighbouring open tests
      await ChannelContainerEngine().open(site,
          extras: const EngineExtras(securityLevel: SecurityLevel.safer));
      await ChannelContainerEngine().open(site);
      final args = [for (final c in calls) c.arguments as Map<Object?, Object?>];
      expect(args.map((a) => a['securityLevel']), ['safer', 'standard']);
    });
```

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: `EngineExtras`** (`lib/domain/models/engine_extras.dart`; import `security_level.dart`)

```dart
class EngineExtras {
  const EngineExtras({
    this.filterRules = const {},
    this.userScripts = const [],
    this.securityLevel = SecurityLevel.standard,
  });

  static const none = EngineExtras();

  final Map<String, List<String>> filterRules;
  final List<InjectedScript> userScripts;

  /// The level this open runs at: the site's own, or the vault default
  /// (privacy-controls spec §2.2). Kotlin is never told "follow the default".
  final SecurityLevel securityLevel;
}
```

  Also update the class doc so it names the level beside the lists and scripts.

- [ ] **Step 4: The builder** (`engine_extras_builder.dart`)
  - Add the parameter `required SettingsRepository settings,`, importing `../../domain/repositories/repositories.dart` and `../../domain/models/security_level.dart`.
  - Before the `return`:

```dart
  // Read now, never cached: a default changed in Settings reaches the next
  // open (spec §2.4).
  final vaultDefault =
      SecurityLevel.vaultDefaultFrom(await settings.getString(securityLevelSettingKey));
```

  - Pass `securityLevel: effectiveLevel(site, vaultDefault),` to `EngineExtras`.
  - In `lib/ui/features/container/view_models/providers.dart`'s `engineExtrasBuilderProvider`, add `settings: ref.read(settingsRepositoryProvider),`, importing it from `../../settings/view_models/providers.dart` with `show settingsRepositoryProvider`.

- [ ] **Step 5: The channel.** In `ChannelContainerEngine.open`'s argument map, after `'userScripts'`: `'securityLevel': extras.securityLevel.name,`.

- [ ] **Step 6: Run the two files, then `flutter test` and `flutter analyze`.** All pass.

- [ ] **Step 7: Commit.** `git commit -m "feat: send each open's effective security level"`.

---

### Task 5: Kotlin — the policy, `safer.js`, and applying it to every page

**Files:**
- Create: `android/.../engine/SecurityPolicy.kt`, `android/app/src/main/assets/shields/safer.js`
- Modify: `android/.../engine/SiteConfig.kt`, `EngineChannel.kt` (`configFrom`), `Shields.kt`, Plan 15's `Page.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/SecurityPolicyTest.kt`

- [ ] **Step 1: Write the failing test**

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class SecurityPolicyTest {
    @Test fun `each name Dart sends is its level`() {
        assertEquals(SecurityLevel.STANDARD, SecurityLevel.fromChannel("standard"))
        assertEquals(SecurityLevel.SAFER, SecurityLevel.fromChannel("safer"))
        assertEquals(SecurityLevel.SAFEST, SecurityLevel.fromChannel("safest"))
    }

    @Test fun `missing, unknown or misspelt fails closed to Safest`() {
        for (name in listOf(null, "", "Standard", "SAFER", "medium")) {
            assertEquals(name.toString(), SecurityLevel.SAFEST, SecurityLevel.fromChannel(name))
        }
    }

    @Test fun `Standard is today's behaviour`() {
        val p = securityPolicyFor(SecurityLevel.STANDARD)
        assertTrue(p.javaScriptEnabled); assertFalse(p.blockNetworkImage)
        assertTrue(p.documentStartScripts); assertFalse(p.saferScript)
    }

    @Test fun `Safer adds safer js and keeps JavaScript on`() {
        val p = securityPolicyFor(SecurityLevel.SAFER)
        assertTrue(p.javaScriptEnabled); assertFalse(p.blockNetworkImage)
        assertTrue(p.documentStartScripts); assertTrue(p.saferScript)
    }

    @Test fun `Safest turns JavaScript and network images off and adds no script`() {
        val p = securityPolicyFor(SecurityLevel.SAFEST)
        assertFalse(p.javaScriptEnabled); assertTrue(p.blockNetworkImage)
        assertFalse(p.documentStartScripts); assertFalse(p.saferScript)
    }

    @Test fun `a SiteConfig with no level is Safest`() {
        assertEquals(SecurityLevel.SAFEST, SecurityLevel.fromChannel(null))
    }

    @Test fun `safer js carries the three measures`() {
        // Unit tests run from android/app.
        val js = File("src/main/assets/shields/safer.js").readText()
        assertTrue(js.contains("location.protocol === 'http:'"))
        assertTrue(js.contains("Content-Security-Policy"))
        assertTrue(js.contains("script-src 'none'"))
        assertTrue(js.contains("WebAssembly"))
        for (context in listOf("'webgl'", "'webgl2'", "'experimental-webgl'")) {
            assertTrue(context, js.contains(context))
        }
        assertTrue(js.contains("OffscreenCanvas"))
    }
}
```

- [ ] **Step 2: Run it and see it fail.** From `android/`: `./gradlew :app:testDebugUnitTest --tests '*SecurityPolicyTest*'` fails to compile.

- [ ] **Step 3: Create `SecurityPolicy.kt`**

```kotlin
package com.mono.container.engine

/**
 * What a site may run (privacy-controls spec §1). Dart resolves the
 * effective level and sends its name; this never sees "follow the default".
 */
enum class SecurityLevel {
    STANDARD, SAFER, SAFEST;

    companion object {
        /** A name Dart did not send, or none, is [SAFEST] (spec §1.5). */
        fun fromChannel(name: String?): SecurityLevel = when (name) {
            "standard" -> STANDARD
            "safer" -> SAFER
            "safest" -> SAFEST
            else -> SAFEST
        }
    }
}

/** How a [SecurityLevel] is applied to one WebView. Pure, so the JVM tests reach it. */
data class SecurityPolicy(
    val javaScriptEnabled: Boolean,
    val blockNetworkImage: Boolean,
    /** [Shields.apply]'s document-start scripts. None can run with JavaScript
     *  off, so Safest adds none. */
    val documentStartScripts: Boolean,
    /** `shields/safer.js`: no page script on `http:`, no WebAssembly, no WebGL. */
    val saferScript: Boolean,
)

fun securityPolicyFor(level: SecurityLevel): SecurityPolicy = when (level) {
    SecurityLevel.STANDARD -> SecurityPolicy(
        javaScriptEnabled = true, blockNetworkImage = false,
        documentStartScripts = true, saferScript = false,
    )
    SecurityLevel.SAFER -> SecurityPolicy(
        javaScriptEnabled = true, blockNetworkImage = false,
        documentStartScripts = true, saferScript = true,
    )
    SecurityLevel.SAFEST -> SecurityPolicy(
        javaScriptEnabled = false, blockNetworkImage = true,
        documentStartScripts = false, saferScript = false,
    )
}
```

- [ ] **Step 4: Create `shields/safer.js`**

```js
(function () {
  // Privacy-controls spec §1.2, Safer. Runs in every document and frame
  // before the page's own scripts; it is injected by the browser, so the CSP
  // below does not stop it or the other shields.

  // No page script on an http: page. A meta CSP only counts as a child of a
  // <head>, and at document start there is none yet: one is made, and the
  // parser's own <head> follows it. Verified on a device first (spec §1.4);
  // the fallback is per-navigation javaScriptEnabled.
  if (location.protocol === 'http:') {
    var meta = document.createElement('meta');
    meta.httpEquiv = 'Content-Security-Policy';
    meta.content = "script-src 'none'";
    var head = document.head;
    if (!head) {
      head = document.createElement('head');
      (document.documentElement || document).appendChild(head);
    }
    head.insertBefore(meta, head.firstChild);
  }

  // No WebAssembly: the nearest thing to Tor's JIT-off that WebView allows.
  try { delete window.WebAssembly; } catch (e) {}
  if (window.WebAssembly) {
    try { Object.defineProperty(window, 'WebAssembly', { value: undefined }); } catch (e) {}
  }

  // No WebGL. 2d and bitmaprenderer are untouched.
  var refused = { 'webgl': 1, 'webgl2': 1, 'experimental-webgl': 1 };
  function guard(proto) {
    if (!proto || !proto.getContext) return;
    var original = proto.getContext;
    proto.getContext = function (type) {
      if (refused[String(type)]) return null;
      return original.apply(this, arguments);
    };
  }
  if (window.HTMLCanvasElement) guard(HTMLCanvasElement.prototype);
  if (window.OffscreenCanvas) guard(OffscreenCanvas.prototype);
})();
```

- [ ] **Step 5: Carry the level.**
  - **`SiteConfig`:** add the last field:

```kotlin
    /** Privacy-controls spec §1. Missing is Safest (§1.5), so a config built
     *  without one fails closed. */
    val securityLevel: SecurityLevel = SecurityLevel.SAFEST,
```

  - **`EngineChannel.configFrom`:** add `securityLevel = SecurityLevel.fromChannel(call.argument<String>("securityLevel")),`.

- [ ] **Step 6: Apply it.**
  - **`Shields.apply`:** take the policy, and return before adding anything when it allows no scripts. Put `safer.js` first:

```kotlin
    fun apply(
        webView: WebView,
        config: SiteConfig,
        policy: SecurityPolicy = securityPolicyFor(config.securityLevel),
        onFingerprintNoiseApplied: () -> Unit = {},
    ) {
        // Safest: JavaScript is off, so no document-start script could run.
        if (!policy.documentStartScripts) return
        val js = buildString {
            if (policy.saferScript) {
                append(webView.context.assets.open("shields/safer.js").bufferedReader().readText())
            }
            // ... everything that is here today, unchanged ...
        }
        // ... unchanged ...
    }
```

    Update the one caller, which passes the fingerprint lambda by position today, to name it: `onFingerprintNoiseApplied = { ... }`.
  - **Plan 15's `Page`,** where it builds its WebView's settings (today `ContainerView`'s `WebView(context).apply { … }`):

```kotlin
        val policy = securityPolicyFor(config.securityLevel)
        settings.javaScriptEnabled = policy.javaScriptEnabled   // was: true
        settings.blockNetworkImage = policy.blockNetworkImage
```

    Then pass `policy` to `Shields.apply`. Every page of a container, including one a link opens (`onCreateWindow`), is built by this one constructor from the session's `SiteConfig`. Confirm that by reading Plan 15's `Page` and its new-window path. If a second construction path exists, apply the policy there too, and add a JVM test if that path is pure.

- [ ] **Step 7: Run the Kotlin tests** (`./gradlew :app:testDebugUnitTest`) and read the counts from the XML. Run `flutter build apk --debug` and check for zero `e:` lines.

- [ ] **Step 8: Commit.** `git commit -m "feat(engine): apply each site's security level to every page"`.

---

### Task 6: Grants in the session, and `revokeGrant`

**Files:**
- Create: `android/.../engine/SessionGrants.kt`, `lib/domain/models/permissions_in_use.dart`
- Modify: `EngineChannel.kt`, `Shields.kt` (the `"geolocation"` literal), `lib/domain/models/container_session.dart`, `container_engine.dart`, `container_engine_channel.dart`, `fake_container_engine.dart`
- Test: `SessionGrantsTest.kt`, `test/domain/permissions_in_use_test.dart`, `test/data/container_engine_channel_test.dart` (extend)

- [ ] **Step 1: Write the failing Kotlin test**

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SessionGrantsTest {
    // WebView's names, as literals: the main code uses the constants.
    private val video = "android.webkit.resource.VIDEO_CAPTURE"
    private val audio = "android.webkit.resource.AUDIO_CAPTURE"

    @Test fun `each grant has Dart's PermissionKind name`() {
        assertEquals("camera", SessionGrants.kindOf(video))
        assertEquals("microphone", SessionGrants.kindOf(audio))
        assertEquals("location", SessionGrants.kindOf("geolocation"))
        assertNull(SessionGrants.kindOf("android.webkit.resource.MIDI_SYSEX"))
    }

    @Test fun `a kind names its resource, and nothing else names one`() {
        assertEquals(video, SessionGrants.resourceFor("camera"))
        assertEquals(audio, SessionGrants.resourceFor("microphone"))
        assertEquals("geolocation", SessionGrants.resourceFor("location"))
        assertNull("clipboard is never a session grant", SessionGrants.resourceFor("clipboard"))
        assertNull(SessionGrants.resourceFor("anything"))
    }

    @Test fun `the session map lists kinds in 2a's order`() {
        assertEquals(listOf("camera", "microphone", "location"),
            SessionGrants.kindsOf(setOf("geolocation", audio, video)))
        assertEquals(emptyList<String>(), SessionGrants.kindsOf(emptySet()))
    }

    @Test fun `revoking takes away only the kind named`() {
        val grants = mutableSetOf(video, audio, "geolocation")
        assertEquals(true, SessionGrants.revoke(grants, "microphone"))
        assertEquals(setOf(video, "geolocation"), grants)
        assertEquals("already gone", false, SessionGrants.revoke(grants, "microphone"))
        assertEquals(false, SessionGrants.revoke(grants, "clipboard"))
    }
}
```


- [ ] **Step 2: Run it and see it fail.**

- [ ] **Step 3: Create `SessionGrants.kt`**

```kotlin
package com.mono.container.engine

import android.webkit.PermissionRequest

/**
 * A session's "allow while this site is open" grants (`6a`), named the way
 * Dart's `PermissionKind` names them, for `6c`'s permissions (privacy-controls
 * spec §3). Clipboard is never one: it is only ever a stored grant.
 */
object SessionGrants {
    const val GEOLOCATION = "geolocation"

    private val order = listOf("camera", "microphone", "location")

    fun kindOf(resource: String): String? = when (resource) {
        PermissionRequest.RESOURCE_VIDEO_CAPTURE -> "camera"
        PermissionRequest.RESOURCE_AUDIO_CAPTURE -> "microphone"
        GEOLOCATION -> "location"
        else -> null
    }

    fun resourceFor(kind: String): String? = when (kind) {
        "camera" -> PermissionRequest.RESOURCE_VIDEO_CAPTURE
        "microphone" -> PermissionRequest.RESOURCE_AUDIO_CAPTURE
        "location" -> GEOLOCATION
        else -> null
    }

    fun kindsOf(grants: Set<String>): List<String> =
        order.filter { kind -> resourceFor(kind) in grants }

    /** Removes [kind]'s grant; true when there was one to remove. */
    fun revoke(grants: MutableSet<String>, kind: String): Boolean {
        val resource = resourceFor(kind) ?: return false
        return grants.remove(resource)
    }
}
```

  In `Shields.kt` and `EngineChannel.resolvePermission`, replace the literal `"geolocation"` with `SessionGrants.GEOLOCATION`.

- [ ] **Step 4: The channel**
  - **`Session.toMap()`:** add `"grants" to SessionGrants.kindsOf(sessionGrants),`.
  - **`resolvePermission`:** after each `session.sessionGrants.add…` for `allowWhileOpen`, call `emitSessions()`, so `6c` sees the grant.
  - **The method:** add `"revokeGrant"` beside `"keep"`:

```kotlin
                "revokeGrant" -> {
                    revokeGrant(call.argument<String>("siteId")!!, call.argument<String>("kind")!!)
                    result.success(null)
                }
```

  - **And the function:**

```kotlin
    /** `6c`'s Revoke (privacy-controls spec §3): one "allow while open" grant
     *  goes, and every page of the container reloads, so no page, viewed or
     *  paused, keeps a stream (user's ruling, 2026-10-02). A no-op on an
     *  unknown session or a kind not granted. */
    private fun revokeGrant(siteId: String, kind: String) {
        val session = sessions[siteId] ?: return
        if (!SessionGrants.revoke(session.sessionGrants, kind)) return
        for (page in session.pages.values) page.reload()
        emitSessions()
    }
```

    `session.pages` and `page.reload()` are Plan 15's; use the real names from Before Task 1 Step 4.

- [ ] **Step 5: Run the Kotlin tests and the APK build.** Both are green.

- [ ] **Step 6: Write the failing Dart tests**
  - **`container_engine_channel_test.dart`:**
    - `sessionsFromEvent` decodes `'grants': ['camera', 'location', 'bogus']` to `{PermissionKind.camera, PermissionKind.location}`, and decodes a missing key to `{}`.
    - `revokeGrant('s1', PermissionKind.microphone)` sends `revokeGrant` with `{'siteId': 's1', 'kind': 'microphone'}`.
  - **`test/domain/permissions_in_use_test.dart`:**

```dart
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/permissions_in_use.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = Site(id: 's', workspaceId: 'w', name: 'Meet', monogram: 'Mt',
    url: 'https://meet.example.com', profileId: 'p');

void main() {
  test('nothing granted, no rows', () {
    expect(permissionsInUse(_site, const {}), isEmpty);
  });

  test("stored grants and while-open grants, in 2a's order", () {
    final site = _site.copyWith(allowClipboard: true, allowCamera: true);
    final rows = permissionsInUse(site, {PermissionKind.location, PermissionKind.microphone});
    expect(rows.map((r) => (r.kind, r.whileOpen)), [
      (PermissionKind.camera, false),
      (PermissionKind.microphone, true),
      (PermissionKind.location, true),
      (PermissionKind.clipboard, false),
    ]);
  });

  test('a stored grant wins over a session grant of the same kind', () {
    final rows = permissionsInUse(_site.copyWith(allowCamera: true), {PermissionKind.camera});
    expect(rows.single.whileOpen, isFalse);
  });
}
```

- [ ] **Step 7: Run them and see them fail.**

- [ ] **Step 8: Implement the Dart side**
  - **`ContainerSession`:**
    - Add `this.grants = const {},` to the constructor.
    - Add the field `/// "Allow while this site is open" grants in this session (spec §3). Never "allow once", never clipboard.` and `final Set<PermissionKind> grants;`.
    - Add `Set<PermissionKind>? grants` to `copyWith`, and import `permissions.dart`.
  - **The channel:** in `_sessionFrom`, add `grants: _grantsFrom(map['grants']),`, with:

```dart
Set<PermissionKind> _grantsFrom(Object? raw) => {
      for (final name in (raw as List<Object?>?) ?? const <Object?>[])
        for (final kind in PermissionKind.values)
          if (kind.name == name) kind,
    };
```

    And the method `revokeGrant(String siteId, PermissionKind kind) => _method.invokeMethod('revokeGrant', {'siteId': siteId, 'kind': kind.name});`.
  - **`ContainerEngine`:**

```dart
  /// `6c`'s Revoke (privacy-controls spec §3): ends one "allow while open"
  /// grant and reloads every page of the container. A no-op when [siteId] has
  /// no such grant.
  Future<void> revokeGrant(String siteId, PermissionKind kind);
```

  - **`FakeContainerEngine`:**

```dart
  final revokedGrants = <({String siteId, PermissionKind kind})>[];

  /// Test helper: an "allow while open" decision, as the native session records it.
  void grantWhileOpen(String siteId, PermissionKind kind) {
    final current = _sessions[siteId];
    if (current == null) return;
    _sessions[siteId] = current.copyWith(grants: {...current.grants, kind});
    _emit();
  }

  @override
  Future<void> revokeGrant(String siteId, PermissionKind kind) async {
    revokedGrants.add((siteId: siteId, kind: kind));
    final current = _sessions[siteId];
    if (current == null || !current.grants.contains(kind)) return;
    _sessions[siteId] = current.copyWith(grants: {...current.grants}..remove(kind));
    _emit();
  }
```

  - **`lib/domain/models/permissions_in_use.dart`:**

```dart
import 'permissions.dart';
import 'site.dart';

/// One row of `6c`'s permissions (privacy-controls spec §3).
class PermissionInUse {
  const PermissionInUse(this.kind, {required this.whileOpen});
  final PermissionKind kind;

  /// True for an "allow while this site is open" grant, which can be
  /// revoked; false for a grant stored in `2a`, changed only through Edit.
  final bool whileOpen;
}

/// What [site] may use now, in `2a`'s HARDWARE order: its stored grants and
/// this session's [grants]. "Allow once" is never tracked, so never listed.
List<PermissionInUse> permissionsInUse(Site site, Set<PermissionKind> grants) {
  bool stored(PermissionKind kind) => switch (kind) {
        PermissionKind.camera => site.allowCamera,
        PermissionKind.microphone => site.allowMicrophone,
        PermissionKind.location => site.allowLocation,
        PermissionKind.clipboard => site.allowClipboard,
      };
  return [
    for (final kind in PermissionKind.values)
      if (stored(kind))
        PermissionInUse(kind, whileOpen: false)
      else if (grants.contains(kind))
        PermissionInUse(kind, whileOpen: true),
  ];
}
```

- [ ] **Step 9: Run `flutter test` and `flutter analyze`.** Both pass.

- [ ] **Step 10: Commit.** `git commit -m "feat: a session's grants reach Dart, and Revoke ends one"`.

---

### Task 7: `6c` as the shield panel

**Files:**
- Modify: `lib/ui/features/in_page/views/site_sheet.dart`
- Test: `test/ui/features/in_page/site_sheet_test.dart` (extend; update `host()`)

- [ ] **Step 1: Write the failing tests.** Extend `host()` with the new parameters and these defaults:
  - `securityLevelValue: 'Standard · default'`;
  - `categoryCounts: const {}`;
  - `blockWebRtc: true`, `blockTrackers: true`, `antiFingerprinting: true`;
  - `permissions: const []`;
  - a callback for each.

  Then add:

```dart
  testWidgets('the security level row shows its value and opens the picker', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(securityLevelValue: 'Safer', onSecurityLevel: () => taps++));
    expect(find.text('Security level'), findsOneWidget);
    expect(find.text('Safer'), findsOneWidget);
    await tester.tap(find.text('Security level'));
    expect(taps, 1);
  });

  testWidgets("blocked categories with a count above 0 are listed in 5c's order and words",
      (tester) async {
    await tester.pumpWidget(host(categoryCounts: const {
      BlockedCategory.ads: 30, BlockedCategory.trackers: 120, BlockedCategory.fingerprinting: 0,
    }));
    expect(find.text('Trackers'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('Ads'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Fingerprinting'), findsNothing);
    expect(find.text('Permission asks'), findsNothing);
    expect(tester.getTopLeft(find.text('Trackers')).dy,
        lessThan(tester.getTopLeft(find.text('Ads')).dy));
  });

  testWidgets('the three shield switches report their new value', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(host(
      onBlockWebRtcChanged: (v) => changes.add('webrtc $v'),
      onBlockTrackersChanged: (v) => changes.add('trackers $v'),
      onAntiFingerprintingChanged: (v) => changes.add('fp $v'),
    ));
    for (final title in ['Block WebRTC', 'Block trackers and ads', 'Anti-fingerprinting']) {
      final row = find.ancestor(of: find.text(title), matching: find.byType(Row)).first;
      await tester.ensureVisible(row);
      await tester.tap(find.descendant(of: row, matching: find.byType(AppToggle)));
    }
    expect(changes, ['webrtc false', 'trackers false', 'fp false']);
  });

  testWidgets('a stored grant reads Allowed; a while-open grant offers Revoke', (tester) async {
    final revoked = <PermissionKind>[];
    await tester.pumpWidget(host(
      permissions: const [
        PermissionInUse(PermissionKind.camera, whileOpen: false),
        PermissionInUse(PermissionKind.microphone, whileOpen: true),
      ],
      onRevoke: revoked.add,
    ));
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Microphone'), findsOneWidget);
    await tester.ensureVisible(find.text('Revoke'));
    await tester.tap(find.text('Revoke'));
    expect(revoked, [PermissionKind.microphone]);
    expect(find.text('Location'), findsNothing);
  });

  testWidgets('no jade but Edit', (tester) async {
    await tester.pumpWidget(host(permissions: const [
      PermissionInUse(PermissionKind.microphone, whileOpen: true),
    ]));
    final jade = tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.color == C.jade);
    expect(jade.map((t) => t.data), ['Edit']);
  });

  testWidgets('on a small phone the sheet scrolls to Close and wipe, with no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(
      categoryCounts: const {BlockedCategory.trackers: 1, BlockedCategory.ads: 2,
          BlockedCategory.fingerprinting: 3, BlockedCategory.permissionAsks: 4},
      permissions: const [
        PermissionInUse(PermissionKind.camera, whileOpen: false),
        PermissionInUse(PermissionKind.microphone, whileOpen: true),
        PermissionInUse(PermissionKind.location, whileOpen: true),
        PermissionInUse(PermissionKind.clipboard, whileOpen: false),
      ],
    ));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Close and wipe this session'), 100);
    expect(find.text('Close and wipe this session'), findsOneWidget);
  });
```

  - Add the imports: `blocked_tally.dart`, `permissions.dart`, `permissions_in_use.dart`, `tokens.dart`.
  - Update the existing tests that tap Force dark mode and Desktop view: call `tester.ensureVisible` before each tap, since the sheet now scrolls.
  - Pump `host()` in a `Scaffold` body as today. The sheet must lay out inside a bounded height: the scroll test sets one.

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Rebuild `SiteSheet`**
  - **New constructor parameters:**

```dart
    required this.securityLevelValue,
    required this.onSecurityLevel,
    required this.categoryCounts,
    required this.blockWebRtc,
    required this.blockTrackers,
    required this.antiFingerprinting,
    required this.onBlockWebRtcChanged,
    required this.onBlockTrackersChanged,
    required this.onAntiFingerprintingChanged,
    required this.permissions,
    required this.onRevoke,
```

    The matching fields, with one-line docs that cite privacy-controls spec §3:
    - `String securityLevelValue` and `VoidCallback onSecurityLevel`;
    - `Map<BlockedCategory, int> categoryCounts`;
    - three `bool`s and three `ValueChanged<bool>`s;
    - `List<PermissionInUse> permissions` and `ValueChanged<PermissionKind> onRevoke`.

    Update the class doc: `6c` is now the per-site shield panel, and every switch applies at once by reopening the container (spec §2.4).

  - **`build`:** the handle stays outside the scroll. Everything else goes in a `Flexible(child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...])))`, in this order:
    1. the header, unchanged;
    2. `Proxy`, `Cookies`;
    3. `_SheetInfoRow(label: 'Security level', value: securityLevelValue, onTap: onSecurityLevel)`;
    4. `_SheetInfoRow(label: 'Blocked here', value: '$blockedCount requests', showDivider: categories.isEmpty)`, followed when non-empty by `_CategoryRows(categories)` with a bottom `C.line05` divider;
    5. `_SheetInfoRow(label: 'Block WebRTC', trailing: AppToggle(value: blockWebRtc, onChanged: onBlockWebRtcChanged))`;
    6. `Block trackers and ads`, then `Anti-fingerprinting`, likewise;
    7. `Force dark mode`, then `Desktop view` with `showDivider: permissions.isNotEmpty`;
    8. one `_SheetInfoRow` per permission, each with a divider except the last;
    9. the `Close and wipe this session` pill.

    Here `categories` is `[for (final c in BlockedCategory.values) if ((categoryCounts[c] ?? 0) > 0) (c, categoryCounts[c]!)]`.

  - **`_SheetInfoRow`:** gains an optional `onTap`. When it is set, wrap the row in `GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, …)`.

  - **`_CategoryRows`:** a `Padding(padding: EdgeInsets.fromLTRB(32, 0, 18, 12))` around a `Column` of rows. Each row is `Text(category.label, style: ui(size: 12.5, color: C.textMuted))`, a `Spacer`, then `Text('$count', style: mono(size: 11, color: C.textFaint))`, with 6px between rows and no dividers.

  - **Permission row trailing:** `whileOpen` gets `GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onRevoke(p.kind), child: Text('Revoke', style: ui(size: 13, weight: 500, color: C.textPrimary)))`; otherwise `Text('Allowed', style: ui(size: 12.5, color: C.textMuted))`. The label comes from:

```dart
String _permissionLabel(PermissionKind kind) => switch (kind) {
      PermissionKind.camera => 'Camera',
      PermissionKind.microphone => 'Microphone',
      PermissionKind.location => 'Location',
      PermissionKind.clipboard => 'Clipboard',
    };
```

  - **Callers:** update every caller in `lib` to pass the new arguments. Plan 15's host route owns `_showSiteSheet` by then. For now, pass the values and no-op callbacks; Task 9 wires them. Set `isScrollControlled: true` on that `showModalBottomSheet` so a tall sheet can use the screen.

- [ ] **Step 4: Run `flutter test test/ui/features/in_page/site_sheet_test.dart`, then `flutter test` and `flutter analyze`.** All pass.

- [ ] **Step 5: Commit.** `git commit -m "feat(6c): the per-site shield panel"`.

---

### Task 8: The ☰ rows and the New identity sheet

**Files:**
- Create: `lib/ui/features/container/views/new_identity_sheet.dart`
- Modify: `browser_menu_sheet.dart`, `container_screen.dart`
- Test: `test/ui/features/container/browser_menu_sheet_test.dart` (create, or extend `address_and_menu_test.dart` if it already pumps the sheet alone), `test/ui/features/container/new_identity_sheet_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
// new_identity_sheet_test.dart
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/container/views/new_identity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<bool?> ask(WidgetTester tester, Future<void> Function() act) async {
    bool? answer;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () async => answer = await confirmNewIdentity(context),
        child: const Text('open'),
      ),
    ))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('the approved copy, and no jade', (tester) async {
    await ask(tester, () async {
      expect(find.text('New identity for this site?'), findsOneWidget);
      expect(find.text(
          'Its logins, storage and downloads are destroyed, and it starts over at its first page.'),
          findsOneWidget);
      expect(find.text('New identity'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.widgetList<Text>(find.byType(Text)).where((t) => t.style?.color == C.jade),
          isEmpty);
    });
  });

  testWidgets('New identity answers true', (tester) async {
    expect(await ask(tester, () => tester.tap(find.text('New identity'))), isTrue);
  });

  testWidgets('Cancel, a tap outside and back answer false', (tester) async {
    expect(await ask(tester, () => tester.tap(find.text('Cancel'))), isFalse);
    expect(await ask(tester, () => tester.tapAt(const Offset(10, 10))), isFalse);
    expect(await ask(tester, () async {
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
      navigator.maybePop();
    }), isFalse);
  });
}
```

```dart
// browser_menu_sheet_test.dart (or a group in address_and_menu_test.dart)
  testWidgets("Security level and New identity come first, with the level's meta",
      (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BrowserMenuSheet(
      monogram: 'Fr', name: 'Forum', subtitle: 'forum.example.com · Personal',
      blockedToday: 3, securityLevelMeta: 'SAFER',
      onSecurityLevel: () => taps.add('level'), onNewIdentity: () => taps.add('identity'),
      onReload: () {}, onFind: () {}, onReader: () {}, onCopyLink: () {}, onToday: () {},
      onScripts: () {}, onWorkspaces: () {}, onSettings: () {}, onAllSites: () {},
    ))));
    expect(find.text('Security level'), findsOneWidget);
    expect(find.text('SAFER'), findsOneWidget);
    final order = ['Security level', 'New identity', 'Today', 'Scripts and filters',
        'Workspaces', 'Settings', 'All sites'];
    for (var i = 1; i < order.length; i++) {
      expect(tester.getTopLeft(find.text(order[i - 1])).dy,
          lessThan(tester.getTopLeft(find.text(order[i])).dy), reason: order[i]);
    }
    await tester.tap(find.text('Security level'));
    await tester.tap(find.text('New identity'));
    expect(taps, ['level', 'identity']);
  });
```

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Create `new_identity_sheet.dart`.** Copy `WipeSiteSheet` and `confirmWipeSite` (`lib/ui/features/dashboard/views/wipe_site_sheet.dart`), with these changes:
  - the class is `NewIdentitySheet`, with `onNewIdentity` and `onCancel`;
  - the title is `New identity for this site?`;
  - the body is `Its logins, storage and downloads are destroyed, and it starts over at its first page.`;
  - the row is `SheetRow(label: 'New identity', labelColor: C.danger, onTap: onNewIdentity)`;
  - the function is `Future<bool> confirmNewIdentity(BuildContext context)`.

  Keep the doc comments' points:
  - the copy was approved by the user on 2026-10-02 (privacy-controls spec §5);
  - no jade, since New identity is destructive;
  - no `useRootNavigator`.

- [ ] **Step 4: The menu rows**
  - **`BrowserMenuSheet`:**
    - Add `required this.securityLevelMeta`, `required this.onSecurityLevel` and `required this.onNewIdentity`, with fields documented as privacy-controls spec §4.1.
    - Before `Today`, add:

```dart
        _MenuRow(label: 'Security level', meta: securityLevelMeta, onTap: onSecurityLevel),
        _MenuRow(label: 'New identity', onTap: onNewIdentity),
```

    - Update the class doc: the line "Project 3 adds security level and New identity to it" becomes a statement that it has them.
  - **`ContainerScreen`:**
    - Add the same three as widget parameters: `securityLevelMeta` (a `String`), `onSecurityLevel` and `onNewIdentity`.
    - In `_openMenu`, pass `securityLevelMeta: widget.securityLevelMeta`, `onSecurityLevel: closing(widget.onSecurityLevel)` and `onNewIdentity: closing(widget.onNewIdentity)`.
    - Its callers pass `'STANDARD'` and no-op callbacks until Task 9 (update `chrome_bars_test.dart` and the other callers that build it).

- [ ] **Step 5: Run `flutter test` and `flutter analyze`.** Both pass.

- [ ] **Step 6: Commit.** `git commit -m "feat(menu): Security level and New identity rows; the confirm sheet"`.

---

### Task 9: Wire it on Plan 15's host — reopen in place, pickers, switches, Revoke

**Files:**
- Modify: Plan 15's per-container controller and `ContainerHostRoute` (this plan calls them *the controller* and *the host*). Use the real names from Before Task 1 Step 4.
- Test: Plan 15's host-route widget test file (extend), using `FakeContainerEngine`.

This task's logic is fixed; where it lives depends on Plan 15's code.

- [ ] **Step 1: Write the failing widget tests.** They use Plan 15's harness for pumping the host with a saved site and with a throwaway, open and live, with a navigation event at `https://forum.example.com/t/9` on the viewed page. Add:
  1. **The ☰ level picker.**
     - Open ☰, and see `Security level` with the meta `STANDARD`.
     - Tap it: the site picker shows, with `Default` checked.
     - Tap `Safest`. Expect:
       - the repository row's `securityLevel` is `safest`;
       - the fake recorded `close(siteId, wipe: false)` for the site;
       - `openedExtras[siteId]!.securityLevel == SecurityLevel.safest`;
       - `openedInitialUrls[siteId] == 'https://forum.example.com/t/9'`;
       - the profile was not wiped (`wiped` is empty).
  2. **`Default` clears it.** With the site at `safer`, pick `Default`: the row's `securityLevel` is null, and the reopen's extras carry the vault default.
  3. **`6c`'s value.**
     - It reads `Standard · default`, then `Safest` after the pick.
     - Reopen `6c` and tap `Security level`: the same site picker.
  4. **Every `6c` switch saves, then reopens in place,** each with `wipe: false` at the viewed page's address. The switches are:
     - `Block WebRTC` → `blockWebRtc: false`;
     - `Block trackers and ads`;
     - `Anti-fingerprinting`;
     - `Force dark mode`;
     - `Desktop view` → `userAgentMode: desktop`.
  5. **A throwaway's switch writes no row.**
     - The repository is untouched, and the registry entry's site carries the change.
     - It is reopened with `throwaway: true` and `wipe: false`.
     - `wiped` is empty, so its cookies survive.
  6. **Categories and permissions reach `6c`.**
     - `fake.addBlocked(siteId, BlockedCategory.trackers, 4)` shows `Trackers` and `4`.
     - `fake.grantWhileOpen(siteId, PermissionKind.microphone)` shows `Microphone` and `Revoke`.
     - Tapping `Revoke` records `revokedGrants` and the row goes.
     - A site with `allowCamera: true` shows `Camera` and `Allowed`.
  7. **The vault default reaches the next open, not the open one.**
     - Store `safer` through `SettingsController`; the open container is not reopened.
     - Close it and open it again: its extras carry `safer`.

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Reopen in place, on the controller**

```dart
  /// Privacy-controls spec §2.4: [site] reopened in place, at [url] (the
  /// address the viewed page is showing), with every page but that one
  /// closed (user's ruling, 2026-10-02). Never wipes, whatever the cookie
  /// policy, so a throwaway or a wipe-on-exit site keeps its login (spec
  /// ruling 1). A throwaway is reopened as one, and its journal entry stays.
  Future<void> reopenInPlace(Site site, {required String url}) async {
    await engine.close(site.id, wipe: false);
    // Plan 15's reopen (8b's), with this open's address. It updates the
    // registry entry's site, re-reads the extras (so the level and the vault
    // default are current), and keeps the throwaway flag.
    await reopen(site, initialUrl: url);
  }
```

  If Plan 15's reopen takes no `initialUrl`, add one, passed to `engine.open(..., initialUrl:)`. Its other callers keep reopening at the stored address (Tabs §5.7), so their tests stay as they are.

  **The viewed page's address:** read `navigationState` / `navigationForPageProvider` for the container's viewed page. Fall back to the address the container was opened with, and then to `site.url` (spec ruling 5).

- [ ] **Step 4: One save-then-reopen path for every change**

```dart
  /// A `6c` switch or a level pick (spec §2.4): the site is saved (a
  /// throwaway only in memory), then reopened in place.
  Future<void> applySiteChange(Site updated) async {
    if (entry.throwaway) {
      openContainers.updateSite(updated);     // Plan 15's registry
    } else {
      await siteRepository.upsert(updated);
      sitesChanged(ref);
    }
    await reopenInPlace(updated, url: viewedPageUrl());
  }
```

  - **`6c`'s callbacks** in the host:
    - `onForceDarkChanged: (v) => applySiteChange(site.copyWith(forceDark: v))`;
    - `onDesktopViewChanged` as today's mapping, through `applySiteChange`;
    - `onBlockWebRtcChanged`, `onBlockTrackersChanged` and `onAntiFingerprintingChanged` likewise.

    This replaces Plan 15's "the `6c` switches never close anything" (Tabs §5.7), as privacy-controls spec §8 records. **Close `6c` before reopening**, since the sheet shows a session that is about to be replaced.
  - **`onSecurityLevel`,** from `6c` and from the ☰ menu, closes the sheet and shows:

```dart
    final vaultDefault = await ref.read(vaultSecurityLevelProvider.future);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SecurityLevelPicker.site(
        current: site.securityLevel,
        vaultDefault: vaultDefault,
        onPick: (level) {
          Navigator.pop(sheetContext);
          if (level == site.securityLevel) return;
          applySiteChange(site.withSecurityLevel(level));
        },
      ),
    );
```

  - **`6c`'s other arguments:**
    - `securityLevelValue: securityLevelValue(site, vaultDefault)`;
    - `categoryCounts: session.categoryCounts`;
    - the three shield booleans from `site`;
    - `permissions: permissionsInUse(site, session.grants)`;
    - `onRevoke: (kind) => engine.revokeGrant(site.id, kind)`.

    Here `session` is the container's `ContainerSession`, from Plan 15's per-site session provider. Keep `6c` live across a Revoke with the `StatefulBuilder` and session listener the host already uses, or rebuild the sheet from a provider.
  - **☰:** `securityLevelMeta: effectiveLevel(site, vaultDefault).meta` (spec ruling 10), with `vaultDefault` from `vaultSecurityLevelProvider` (`valueOrNull ?? SecurityLevel.standard`, for display only). `onSecurityLevel` as above; `onNewIdentity` is wired in Task 10 (a no-op until then).

- [ ] **Step 5: Run the host tests, then `flutter test` and `flutter analyze`.** All pass. Then check the reopens by reading the code: `grep -n "engine.close(" lib` must show no bare `close(siteId)` on the reopen path.

- [ ] **Step 6: Commit.** `git commit -m "feat: a site's level and 6c's switches apply at once, by reopening in place"`.

---

### Task 10: New identity

**Files:**
- Modify: the controller and the host (as in Task 9)
- Test: Plan 15's host-route test file (extend); `test/data/site_wipe_test.dart` if Step 3 adds a helper there

- [ ] **Step 1: Write the failing widget tests**
  1. **A saved site, at `https://forum.example.com/t/9`.**
     - ☰ → `New identity` shows the confirm sheet; Cancel changes nothing (no close, no wipe, and the row's `profileId` is unchanged).
     - ☰ → `New identity` → `New identity`. Expect, in this order:
       1. the fake recorded `close(siteId, wipe: true)`;
       2. the row's `profileId` is new, and "Last worked" is cleared;
       3. the site was opened again with that new `profileId`, with `openedInitialUrls[siteId] == null`, so it loads `site.url` (`https://forum.example.com`), **not** `/t/9`.
     - The site's own level and switches are unchanged.
  2. **A throwaway.**
     - New identity closes it with `wipe: true` and reopens it with `throwaway: true`.
     - The new `profileId` differs, and the registry entry holds it.
     - It is opened with `initialUrl == null`, at its first address.
     - No repository write happens.
  3. **Typed login and per-site login.**
     - A saved SOCKS5 site with `proxyUser: 'alice'` reopens with `proxyUser: 'alice'`.
     - One with `proxyLoginPerSite: true` reopens with a different `profileId`, so Kotlin derives a different login (Plan 14 §2.3; no Dart change).

- [ ] **Step 2: Run them and see them fail.**

- [ ] **Step 3: Implement it on the controller**

```dart
  /// Privacy-controls spec §4: this site's data destroyed and its profile
  /// rotated, so a fresh loopback credential and, with "Separate login per
  /// site", a fresh proxy login (a new Tor circuit). Then it reopens at its
  /// first page: a saved site's stored address, a throwaway's first address.
  /// Never the page being shown, which could carry an identifying token.
  /// Its settings, level and typed login stay.
  Future<void> newIdentity() async {
    final site = entry.site;
    final Site fresh;
    if (entry.throwaway) {
      await engine.close(site.id, wipe: true);  // journal: wiped and forgotten
      fresh = site.copyWith(profileId: newProfileId());
      openContainers.updateSite(fresh);
    } else {
      // Plan 15's wipeSavedSite: close(siteId, wipe: true), the rotation,
      // "Last worked" cleared.
      fresh = await wipeSavedSite(engine: engine, sites: siteRepository, site: site);
      sitesChanged(ref);
    }
    await reopen(fresh, initialUrl: null);  // throwaway: still opened as one
  }
```

  `wipeSavedSite` has already closed the session, so this reopen is not `reopenInPlace`. It must not call `close` a second time. If Plan 15's `reopen` always closes first, call its open half directly.

  In the host, the ☰ `onNewIdentity` handler is:

```dart
  onNewIdentity: () async {
    if (!await confirmNewIdentity(context)) return;
    await controller.newIdentity();
  },
```

  It runs after the menu has closed (`closing(...)`, Task 8).

- [ ] **Step 4: Run the tests, then `flutter test` and `flutter analyze`.** All pass.

- [ ] **Step 5: Commit.** `git commit -m "feat: New identity for one site"`.

---

### Task 11: Harness pages and the run sheet

**Files:**
- Create: `tool/device-check/pages.py`
- Modify: `tool/device-check/README.md`

- [ ] **Step 1: Write `pages.py`.** Python 3.8+, standard library only, in the style of `proxy.py`:
  - `http.server.ThreadingHTTPServer` on `--port` (default `8099`, all interfaces, so the emulator reaches it at `10.0.2.2:8099`);
  - it logs each request's path and `User-Agent`, never a body.

  Pages, each a few lines of HTML with no external resources except where named:
  - `/csp.html`:
    - `<p id=r>NO SCRIPT RAN</p>`;
    - an inline `<script>` that sets `r.textContent='INLINE RAN'`;
    - `<script src="/ext.js">`, where `ext.js` appends ` EXTERNAL RAN`;
    - `<button onclick="r.textContent+=' ONCLICK RAN'">tap</button>`;
    - `<a href="javascript:void(document.title='JSURL RAN')">jsurl</a>`.
  - `/probes.html`: on load, writes `WASM ` + `typeof WebAssembly` and `WEBGL ` + `!!document.createElement('canvas').getContext('webgl')` into the page.
  - `/image.html`: a 40×40 PNG served as `/dot.png`, generated in code; log its fetch, so "no request" is visible.
  - `/mic.html`: a button calling `navigator.mediaDevices.getUserMedia({audio:true})`; it shows `MIC ON` while the track is live and `MIC ENDED` when the track ends.

- [ ] **Step 2: Run it once on the host** (`python tool/device-check/pages.py`). Fetch each page with `curl -s localhost:8099/csp.html`, and check the content and the log line.

- [ ] **Step 3: Add the Plan 16 run sheet to `README.md`,** under its own heading, in the style of the Plan 13/14 sheets.
  - **Setup:**
    - `python pages.py` and `python proxy.py --any-login`, alongside the existing setup;
    - read results from `adb shell uiautomator dump`, since WebView text is in the tree and the screen is `FLAG_SECURE`.
  - **Checks:**
    1. **First, Safer's `http:` CSP (spec §1.4).**
       - A direct site at `http://10.0.2.2:8099/csp.html`: at Standard it reads `INLINE RAN EXTERNAL RAN`, and tapping adds `ONCLICK RAN`.
       - At Safer it reads `NO SCRIPT RAN`, tapping adds nothing, and `pages.py` still logs `/ext.js` being fetched (CSP blocks execution, not the fetch).
       - **If Safer still runs scripts, stop: record the failure and take the fallback** (per-navigation `javaScriptEnabled`) to the user.
    2. **Safer on https.**
       - Give a site at `https://example.com` this custom JS: `document.addEventListener('DOMContentLoaded',()=>document.body.prepend('WASM '+typeof WebAssembly+' WEBGL '+!!document.createElement('canvas').getContext('webgl')))`.
       - At Standard: `WASM object WEBGL true` (or `false` where the emulator has no GL).
       - At Safer: `WASM undefined WEBGL false`, and example.com's own text still renders, so JS is on.
    3. **Safest.**
       - `http://10.0.2.2:8099/csp.html` reads `NO SCRIPT RAN`, and so does an https page with the custom JS above (no prefix text).
       - `/image.html` logs no `/dot.png` request.
       - Reader on an article page: record whether it opens (spec §1.4).
    4. **Default and override.**
       - Settings → Security level → Safer: an open site is unchanged until it is closed and reopened, then Safer applies.
       - ☰ → Security level → Default returns a site with its own level to the default.
    5. **Reopen keeps a throwaway's cookie.**
       - A throwaway on `https://postman-echo.com/cookies/set?p16=1`, then any `6c` switch.
       - The reopened page at `/cookies` still shows `p16`.
    6. **New identity.**
       - A SOCKS5 site with "Separate login per site", against `proxy.py --any-login`.
       - Note its user, then ☰ → New identity → New identity. `proxy.py` logs a different 32-hex user, the old `profileId` is in `files/pending-profile-deletions`, and the page is the site's stored address.
       - Cancel changes nothing.
    7. **Revoke.**
       - `/mic.html`, then "Allow while this site is open", then `MIC ON`.
       - In `6c`, Microphone shows `Revoke`. Tapping it reloads the page (`MIC ENDED`, or a fresh page), and the next tap asks with `6a` again.
    8. **Two vaults.** Settings' Security level row looks the same in the decoy, and setting it there leaves the real vault's default unchanged.

- [ ] **Step 4: Commit.** `git commit -m "tool: test pages and the Plan 16 run sheet"`.

---

### Task 12: Docs and full verification

**Files:**
- Modify: `CLAUDE.md`, this plan (Execution record, Verification)

- [ ] **Step 1: Full gates.**
  - `flutter analyze` (clean);
  - `flutter test` (all passing; note the count);
  - `cd android && ./gradlew :app:testDebugUnitTest`, with counts read from `build/app/test-results/testDebugUnitTest/TEST-*.xml` (files, tests, failures, errors);
  - `flutter build apk --debug` (zero `e:` lines).

  Record each result in "Verification" below.
- [ ] **Step 2: Re-read the spec against the tree.** For each of spec §1–§5 and every ruling, find the code or test that carries it. List anything not carried under Known gaps. Never claim it is done.
- [ ] **Step 3: Add the Plan 16 row to `CLAUDE.md`'s plan table,** in the style of the rows above it:
  - status;
  - what it covers;
  - the spec;
  - the gates with counts;
  - **Not verified on a device**, with a pointer to the run sheet;
  - the known gaps that matter most: no JIT switch, workers, the unproven `http:` CSP, a reopen keeping only the viewed page.
- [ ] **Step 4: Commit.** `git commit -m "docs: Plan 16's row, verification and gaps"`.
- [ ] **Step 5: Ask the user before pushing or merging to `main`.**

---

## Device checks

**Not verified on a device.** No emulator or phone was available where this plan was written. Task 11 adds the run sheet to `tool/device-check/README.md`. Fill in this section with what was seen, check by check, when it is run, as Plans 13 and 14 did.

## Known gaps

From spec §1.4 and §9, and this plan:

- **No JIT switch in WebView.** Safer's WebAssembly removal is a partial stand-in.
- **Workers keep WebAssembly and `OffscreenCanvas` WebGL at Safer:** `safer.js` runs in documents and frames only.
- **Safer's `http:` CSP has never been seen on a device.** It is the run sheet's first check. If it fails, the fallback is per-navigation `javaScriptEnabled`, which the user decides on.
- **At Safest, Reader probably extracts nothing,** and custom CSS and CSS library scripts do not apply: both are injected through JavaScript.
- **Fonts and media are not blocked at any level** (user's ruling).
- **A reopen keeps only the viewed page**, and loses back/forward history and "allow while open" grants (approach A; user's ruling on tabs, 2026-10-02).
- **A vault default change reaches open sites only at their next open.**
- **New identity does not change a typed proxy login.** On Tor, only "Separate login per site" gets a new circuit.
- **The old profile's loopback auth-cache entry stays in Chromium's memory** until the process ends, as with every wipe (P2 spec §2). It names a profile no site uses.
- **Written against the Tabs spec, not Plan 15's code** (see the header). Before Task 1 Step 4's table records the real names. Any logic that had to change to fit them is listed here when executed.
- **The level is not shown in the address pill** (user's ruling).

## Handoff

- **`SecurityLevel` / `securityPolicyFor`** (Kotlin) is the one place a level becomes WebView settings and scripts. A new measure goes there, and in `safer.js` if it is a script, with its JVM test.
- **`EngineExtras.securityLevel`** is the only way a level reaches the engine. Dart resolves it at every open from `Site.securityLevel` and the stored default.
- **`reopenInPlace`** is the path for any later setting that should apply at once. It never wipes. **`newIdentity`** is the only reopen that does.
- **`revokeGrant`** reloads every page of a container. A later per-page grant model would change that.
- **Project 4 (restyle)** inherits `6c`'s new rows, both pickers and the New identity sheet, all on existing tokens.

## Verification

*(Filled in by Task 12.)*

## Execution record

*(Before Task 1: the baseline counts and the Plan 15 name table go here; then one entry per task, with its commit.)*

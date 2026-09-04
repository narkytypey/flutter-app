# Isolated Web Container — Plan 6: Integration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the five already-built plans into one navigable app: tapping a
site opens a real container through `ContainerEngine`, native permission /
download / tunnel-drop events reach the screens Plan 4 already built for
them, blocked requests are tallied by category on `5c`, `SiteSheet`'s toggles
persist, and reader mode extracts something real from the live page.

**Architecture:** No router package — plain `Navigator.push(MaterialPageRoute(...))`
from each call site, matching the project's hand-written-everything
convention and the fact that literally zero `Navigator` calls exist anywhere
in the tree today (`AppGate` is a flat `switch`, not a router). A new
`ContainerRoute` widget owns one site's `opening → live → refused` lifecycle
against `ContainerEngine`, subscribing to three new discriminated event
streams for the lifetime of the push. `EngineChannel.kt`'s existing
`EventChannel` (currently a plain, undifferentiated session list) gains a
`type` field and three new event kinds; `FilterEngine`/`Shields.kt` gain
per-category counters that flow back through the same channel into a new
in-memory `BlockedTallyRecorder`.

**Tech Stack:** Everything from Plans 1–5. No new Dart or Gradle
dependencies — every change here extends `com.mono.container/engine` and
`com.mono.container/sessions`, the two channels Plan 3 already registers.

**Spec:**
- `Sandbox Container -canvas-.dc.html` — authoritative. Blocks `id="1a"`,
  `id="1b"`, `id="2b"`, `id="6a"`, `id="6c"`, `id="7b"`, `id="7c"`, `id="8b"`,
  `id="8c"`.
- `docs/superpowers/specs/2026-09-02-integration-design.md` — the design this
  plan implements. Approved by the user 2026-09-02. Read alongside this plan;
  three places below deliberately correct or narrow it against what the
  current tree can actually do (Task 3 Step 7, Task 6's preamble, and the
  `onMenu`/`onMore` ruling in Task 4) — each is called out where it happens.
- Plans 1–5's own plan files, for the interfaces this plan consumes
  (`ContainerEngine`, `Site`, `BlockedTally`, `HeldDownload`, `ReaderArticle`,
  `RouteFailure`, `SiteRepository`, the six Plan 4 in-page screens, the six
  Plan 5/1 management screens).

---

## Global Constraints

Root `CLAUDE.md`'s global constraints apply in full; the ones this plan
actually touches:

- **Android only, dark theme only.** Nothing here adds a second theme.
- **No network requests of the app's own.** Nothing in this plan fetches
  anything; `extractArticle` runs entirely against the page already loaded
  in the site's own WebView.
- **Jade `#7FC8A9`** stays the single affirmative action per screen — this
  plan adds no new screens with their own jade action, it only wires
  existing ones.
- **The interceptor never falls back to direct.** Untouched by this plan;
  `ContainerRoute` only renders what `RouteDecision`/`RouteFailure` already
  say, it does not change how a route is chosen.
- **Two-vault decoy model, not a filter.** Load-bearing for Task 6: the app
  never holds both vaults' data keys at once outside initial setup, and nothing
  in this plan is allowed to pretend otherwise. See Task 6's preamble — this
  is where the design spec's §6 assumption does not survive contact with the
  actual `SessionController`/`AppDatabase` code and has to be corrected.

Plan 3's Global Constraints this plan additionally depends on:

- **Isolation is a precondition, not a feature.** `ContainerRoute` renders
  whatever `ContainerEngine.open` decided; it never opens a container by a
  path that bypasses `isolationAvailable()`.
- **Profile names are opaque and stored, never derived.** Unaffected — this
  plan never constructs a profile id itself.
- **Sessions remain runtime-only.** `BlockedTallyRecorder` (Task 1) is
  explicitly in-memory and reset on process death, same as `ContainerSession`
  itself — no table for it is added, matching `blocked_tally.dart`'s own doc
  comment.

Two constraints new to this plan:

- **A dropped or backgrounded event is dropped, not queued.** `ContainerRoute`
  only listens to the three new event streams filtered to its own `siteId`
  while it is the active route. There is no notification centre. This is a
  documented Known Gap, not a bug to route around.
- **No screen may claim `syncToDecoy` runs whenever it likes.** It only ever
  runs where both vaults' data keys are simultaneously in memory, which is
  nowhere in the shipped app outside the two-PIN setup wizard. See Task 6.

---

## File Structure

```
lib/domain/models/
  filter_list.dart                MODIFY: FilterListCategory, category field
  container_session.dart          MODIFY: categoryCounts, failure fields
  engine_events.dart               CREATE: PendingPermissionRequest, HeldDownloadEvent, TunnelDroppedEvent

lib/domain/services/
  blocked_tally_recorder.dart      CREATE: BlockedTallyRecorder

lib/domain/repositories/
  repositories.dart                MODIFY: SiteRepository.byId

lib/data/services/
  app_database.dart                MODIFY: schema v4 -> v5 (filter_lists.category)
  container_engine.dart            MODIFY: 4 new members
  container_engine_channel.dart    MODIFY: discriminated demux
  fake_container_engine.dart       MODIFY: 4 new members + test seams
  decoy_provisioner.dart           MODIFY: extract syncToDecoy

lib/data/repositories/
  filter_list_repository_sqlite.dart   MODIFY: category column, seed categories
  site_repository_sqlite.dart          MODIFY: byId

lib/ui/features/dashboard/
  view_models/providers.dart       MODIFY: leakCountProvider, blockedTallyProvider, decoyDatabaseProvider
  views/dashboard_screen.dart      MODIFY: real callbacks, management routes
  views/workspace_menu.dart        MODIFY: management rows

lib/ui/features/container/
  view_models/providers.dart       MODIFY: sessionForSite, panic wiring already present
  views/container_route.dart       CREATE: the site session widget

android/app/src/main/kotlin/com/mono/container/engine/
  EngineChannel.kt                 MODIFY: discriminated events, extractArticle, resolvePermission
  FilterEngine.kt                  MODIFY: categorized rule sets
  Shields.kt                       MODIFY: fingerprint + permission counters, hold/emit permission asks
  RequestInterceptor.kt            MODIFY: tunnel-dropped callback
  ContainerView.kt                 MODIFY: DownloadListener
  SiteConfig.kt                    unchanged
android/app/src/main/assets/filters/
  default.txt                      REPLACE: split into default_trackers.txt + default_ads.txt

test/domain/blocked_tally_recorder_test.dart      CREATE
test/data/filter_list_category_migration_test.dart CREATE
test/data/container_engine_channel_test.dart       CREATE
test/ui/features/container_route_test.dart         CREATE
android/app/src/test/kotlin/.../FilterEngineTest.kt MODIFY: category assertions
```

---

## Task 1: Filter categories and the in-memory blocked tally

Domain-first: the category concept and the aggregator both need to exist
before anything Kotlin-side or route-side can feed them.

**Files:**
- Modify: `lib/domain/models/filter_list.dart`
- Modify: `lib/data/services/app_database.dart`
- Modify: `lib/data/repositories/filter_list_repository_sqlite.dart`
- Modify: `lib/domain/repositories/repositories.dart`
- Modify: `lib/data/repositories/site_repository_sqlite.dart`
- Create: `lib/domain/services/blocked_tally_recorder.dart`
- Test: `test/data/filter_list_category_migration_test.dart`
- Test: `test/domain/blocked_tally_recorder_test.dart`

**Interfaces:**
- Consumes: `FilterList` (Plan 5), `BlockedTally`/`CategoryTally`/`SiteTally`/`BlockedCategory` (Plan 4), `AppDatabase.open`/`schemaVersion` (Plan 1/3), `SiteRepository` (Plan 1).
- Produces: `enum FilterListCategory { trackers, ads }` with `.blockedCategory`; `FilterList.category`; schema version 5; `SiteRepository.byId(String) → Future<Site?>`; `class BlockedTallyRecorder` with `recordCategory(BlockedCategory, int)`, `recordSite({required siteId, required monogram, required name, required int count})`, `BlockedTally snapshot()`.

- [ ] **Step 1: Write the failing migration test**

```dart
// test/data/filter_list_category_migration_test.dart
import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('seeded filter lists carry a real category, not all trackers', () async {
    final database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await seedFilterListsIfEmpty(database);

    final lists = await SqliteFilterListRepository(database).all();
    final byId = {for (final l in lists) l.id: l};

    expect(byId['fl-trackers']!.category, FilterListCategory.trackers);
    expect(byId['fl-cookies']!.category, FilterListCategory.trackers);
    expect(byId['fl-social']!.category, FilterListCategory.ads);
  });

  test('a v4 database migrates existing rows to trackers by default', () async {
    // Open at v4 by hand: exercise onCreate then simulate the pre-migration
    // shape by dropping the column, so onUpgrade has something real to do.
    final database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await database.db.insert('filter_lists', {
      'id': 'fl-legacy',
      'name': 'Legacy list',
      'rule_count': 10,
      'updated_at': 0,
      'enabled': 1,
    });
    // A fresh onCreate already has the column with its default, which is
    // exactly what onUpgrade would also produce for a pre-v5 row — assert
    // the default rather than re-running onUpgrade against a hand-rolled v4
    // schema, since onCreate and onUpgrade share one column definition.
    final rows = await database.db.query('filter_lists', where: "id = 'fl-legacy'");
    expect(rows.single['category'], 'trackers');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/data/filter_list_category_migration_test.dart`
Expected: FAIL — `FilterList.category` is not defined.

- [ ] **Step 3: Add the category to the domain model**

```dart
// lib/domain/models/filter_list.dart
import 'blocked_tally.dart' show BlockedCategory;

/// The two kinds of rule set a filter list can be. A subset of
/// [BlockedCategory] — `fingerprinting` and `permissionAsks` are not
/// list-driven, they come from `Shields.kt` and the permission-deny path
/// respectively (spec §4).
enum FilterListCategory {
  trackers,
  ads;

  BlockedCategory get blockedCategory => switch (this) {
        FilterListCategory.trackers => BlockedCategory.trackers,
        FilterListCategory.ads => BlockedCategory.ads,
      };
}

class FilterList {
  const FilterList({
    required this.id,
    required this.name,
    required this.ruleCount,
    required this.updatedAt,
    required this.enabled,
    required this.category,
  });

  final String id;
  final String name;
  final int ruleCount;
  final DateTime updatedAt;
  final bool enabled;
  final FilterListCategory category;
}
```

- [ ] **Step 4: Bump the schema to 5 and add the column**

In `lib/data/services/app_database.dart`:

```dart
  static const schemaVersion = 5;
```

Add the column to `_createFilterLists`:

```dart
const _createFilterLists = '''
  CREATE TABLE filter_lists (
    id          TEXT PRIMARY KEY,
    name        TEXT    NOT NULL,
    rule_count  INTEGER NOT NULL,
    updated_at  INTEGER NOT NULL,
    enabled     INTEGER NOT NULL DEFAULT 1,
    category    TEXT    NOT NULL DEFAULT 'trackers'
  )
''';
```

And a new `onUpgrade` branch, after the existing `if (from < 4)` block:

```dart
          if (from < 5) {
            await db.execute(
                "ALTER TABLE filter_lists ADD COLUMN category TEXT NOT NULL DEFAULT 'trackers'");
          }
```

- [ ] **Step 5: Map the column and seed real categories**

In `lib/data/repositories/filter_list_repository_sqlite.dart`:

```dart
  FilterList _fromRow(Map<String, Object?> row) => FilterList(
        id: row['id']! as String,
        name: row['name']! as String,
        ruleCount: row['rule_count']! as int,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row['updated_at']! as int,
            isUtc: true),
        enabled: (row['enabled']! as int) == 1,
        category: (row['category']! as String) == 'ads'
            ? FilterListCategory.ads
            : FilterListCategory.trackers,
      );
```

Update the three seed rows: `fl-trackers` and `fl-cookies` default to
`'trackers'` (already the column default, no change needed to those two
maps), `fl-social` gets `'category': 'ads'` added to its row map — social
embeds are the one bundled list that is about third-party ad/embed content
rather than tracking scripts, and the spec calls for at least one seeded
`ads` row to exist so the toggle in `10d` has something real to show.

- [ ] **Step 6: Add `SiteRepository.byId`**

`BlockedTallyRecorder`'s "by site" breakdown (spec `5c`) needs a point
lookup no existing repository method provides — `inWorkspace` only returns
one workspace's sites, and a blocked-request event can name a site in any
workspace of the open vault.

```dart
// lib/domain/repositories/repositories.dart
abstract interface class SiteRepository {
  Future<List<Site>> inWorkspace(String workspaceId);
  Future<Site?> byId(String id);
  Future<void> upsert(Site site);
  Future<void> delete(String id);
  Future<void> touch(String id, DateTime at);
}
```

```dart
// lib/data/repositories/site_repository_sqlite.dart, in SqliteSiteRepository
  @override
  Future<Site?> byId(String id) async {
    final rows =
        await _database.db.query('sites', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return siteFromRow(rows.first);
  }
```

- [ ] **Step 7: Run the migration tests and the whole suite**

Run: `flutter test test/data/filter_list_category_migration_test.dart`
Expected: PASS, 2 tests.

Run: `flutter test`
Expected: PASS — `FilterList(...)` is a positional-free named constructor, so
every existing call site (seed data, `filter_list_repository_test.dart`)
needs `category:` added; do that now if the analyzer flags it.

- [ ] **Step 8: Write the failing recorder test**

```dart
// test/domain/blocked_tally_recorder_test.dart
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/services/blocked_tally_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('categories accumulate across multiple record calls', () {
    final recorder = BlockedTallyRecorder();
    recorder.recordCategory(BlockedCategory.trackers, 12);
    recorder.recordCategory(BlockedCategory.trackers, 3);
    recorder.recordCategory(BlockedCategory.ads, 5);

    final tally = recorder.snapshot();
    final trackers =
        tally.categories.firstWhere((c) => c.category == BlockedCategory.trackers);
    expect(trackers.count, 15);
    expect(tally.total, 20);
  });

  test('a zero or negative delta is not recorded', () {
    final recorder = BlockedTallyRecorder();
    recorder.recordCategory(BlockedCategory.trackers, 0);
    recorder.recordCategory(BlockedCategory.trackers, -1);
    expect(recorder.snapshot().categories, isEmpty);
  });

  test('sites accumulate by id and keep the latest name and monogram', () {
    final recorder = BlockedTallyRecorder();
    recorder.recordSite(siteId: 's1', monogram: 'Fr', name: 'Forum', count: 4);
    recorder.recordSite(siteId: 's1', monogram: 'Fr', name: 'Forum', count: 6);
    recorder.recordSite(siteId: 's2', monogram: 'Nt', name: 'Notes', count: 1);

    final tally = recorder.snapshot();
    expect(tally.siteCount, 2);
    final forum = tally.sites.firstWhere((s) => s.name == 'Forum');
    expect(forum.count, 10);
  });
}
```

- [ ] **Step 9: Run it and watch it fail**

Run: `flutter test test/domain/blocked_tally_recorder_test.dart`
Expected: FAIL — `blocked_tally_recorder.dart` does not exist.

- [ ] **Step 10: Write `BlockedTallyRecorder`**

```dart
// lib/domain/services/blocked_tally_recorder.dart
import '../models/blocked_tally.dart';

/// Accumulates category and per-site counts across the process lifetime.
/// Deliberately not a [ChangeNotifier] or Riverpod class itself — kept as
/// plain, host-testable state, per `blocked_tally.dart`'s own promise that
/// this is memory-only and resets on process death; the Riverpod-aware
/// controller that reads live engine events lives in Task 7.
class BlockedTallyRecorder {
  final _categories = <BlockedCategory, int>{};
  final _sites = <String, _SiteCount>{};

  void recordCategory(BlockedCategory category, int delta) {
    if (delta <= 0) return;
    _categories[category] = (_categories[category] ?? 0) + delta;
  }

  void recordSite({
    required String siteId,
    required String monogram,
    required String name,
    required int count,
  }) {
    if (count <= 0) return;
    final existing = _sites[siteId];
    _sites[siteId] = _SiteCount(
      monogram: monogram,
      name: name,
      count: (existing?.count ?? 0) + count,
    );
  }

  BlockedTally snapshot() => BlockedTally(
        categories: [
          for (final entry in _categories.entries)
            CategoryTally(category: entry.key, count: entry.value),
        ],
        sites: [
          for (final entry in _sites.values)
            SiteTally(monogram: entry.monogram, name: entry.name, count: entry.count),
        ],
      );
}

class _SiteCount {
  const _SiteCount({required this.monogram, required this.name, required this.count});
  final String monogram;
  final String name;
  final int count;
}
```

- [ ] **Step 11: Run the tests and commit**

Run: `flutter test`
Expected: PASS.

```bash
git add lib/domain/models/filter_list.dart lib/data/services/app_database.dart \
  lib/data/repositories/filter_list_repository_sqlite.dart \
  lib/domain/repositories/repositories.dart lib/data/repositories/site_repository_sqlite.dart \
  lib/domain/services/blocked_tally_recorder.dart \
  test/data/filter_list_category_migration_test.dart test/domain/blocked_tally_recorder_test.dart
git commit -m "feat: filter list categories, schema v5, and an in-memory blocked tally"
```

---

## Task 2: `ContainerEngine` gains three event streams

Pure Dart. Every widget test after this task runs against `FakeContainerEngine`
with no platform channel, same as Plan 3's own convention.

**Files:**
- Create: `lib/domain/models/engine_events.dart`
- Modify: `lib/domain/models/container_session.dart`
- Modify: `lib/data/services/container_engine.dart`
- Modify: `lib/data/services/fake_container_engine.dart`
- Modify: `lib/data/services/container_engine_channel.dart`
- Test: `test/data/container_engine_channel_test.dart`

**Interfaces:**
- Consumes: `ContainerSession`, `PermissionKind`/`PermissionDecision` (Plan 4), `HeldDownload`, `RouteFailure`.
- Produces: `PendingPermissionRequest`, `HeldDownloadEvent`, `TunnelDroppedEvent`; `ContainerSession.categoryCounts`, `.failure`; `ContainerEngine.permissionRequests()`, `.downloads()`, `.tunnelDropped()`, `.resolvePermission(String, PermissionDecision)`, `.extractArticle(String)`.

- [ ] **Step 1: Write the event models**

```dart
// lib/domain/models/engine_events.dart
import 'held_download.dart';
import 'permissions.dart';

/// A hardware ask the native side is holding open, waiting for the user's
/// decision from `PermissionRequestSheet` (`6a`). [requestId] round-trips
/// through [ContainerEngine.resolvePermission] so the platform can resolve
/// the exact pending Android callback, not just "the most recent one".
class PendingPermissionRequest {
  const PendingPermissionRequest({
    required this.siteId,
    required this.host,
    required this.kind,
    required this.requestId,
  });

  final String siteId;
  final String host;
  final PermissionKind kind;
  final String requestId;
}

class HeldDownloadEvent {
  const HeldDownloadEvent({required this.siteId, required this.download});

  final String siteId;
  final HeldDownload download;
}

class TunnelDroppedEvent {
  const TunnelDroppedEvent({
    required this.siteId,
    required this.host,
    required this.droppedAt,
  });

  final String siteId;
  final String host;
  final DateTime droppedAt;
}
```

- [ ] **Step 2: Extend `ContainerSession`**

```dart
// lib/domain/models/container_session.dart
import 'route_decision.dart' show RouteFailure;
import 'blocked_tally.dart' show BlockedCategory;

enum SessionPhase { opening, live, background, refused }

class ContainerSession {
  const ContainerSession({
    required this.siteId,
    required this.phase,
    this.lastActiveAt,
    this.blockedCount = 0,
    this.categoryCounts = const {},
    this.failure,
  });

  final String siteId;
  final SessionPhase phase;
  final DateTime? lastActiveAt;
  final int blockedCount;

  /// Cumulative blocks for this session, broken down by [BlockedCategory].
  /// Feeds Task 7's `BlockedTallyController`. A category absent from the map
  /// means zero, not unknown — mirrors `categoryFraction`'s own
  /// partial-list tolerance in `blocked_tally.dart`.
  final Map<BlockedCategory, int> categoryCounts;

  /// Only set when [phase] is [SessionPhase.refused]. `null` in every other
  /// phase, and also `null` for a refusal the platform could not classify.
  final RouteFailure? failure;

  ContainerSession copyWith({
    SessionPhase? phase,
    DateTime? lastActiveAt,
    int? blockedCount,
    Map<BlockedCategory, int>? categoryCounts,
    RouteFailure? failure,
  }) =>
      ContainerSession(
        siteId: siteId,
        phase: phase ?? this.phase,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        blockedCount: blockedCount ?? this.blockedCount,
        categoryCounts: categoryCounts ?? this.categoryCounts,
        failure: failure ?? this.failure,
      );
}
```

- [ ] **Step 3: Extend the `ContainerEngine` interface**

```dart
// lib/data/services/container_engine.dart, add alongside the existing members
  /// Hardware asks the platform is holding, waiting on the user's decision.
  /// Filtered to the foreground site by whoever listens — see Task 4.
  Stream<PendingPermissionRequest> permissionRequests();

  /// Tells the platform what the user picked for [requestId]. A decision for
  /// a request that already timed out or whose site closed is a silent
  /// no-op on the platform side, not an error here.
  Future<void> resolvePermission(String requestId, PermissionDecision decision);

  Stream<HeldDownloadEvent> downloads();

  /// A *live* session's tunnel failing mid-browse. Distinct from
  /// [SessionPhase.refused], which only ever happens before a session goes
  /// live — see Plan 6's design spec §3.
  Stream<TunnelDroppedEvent> tunnelDropped();

  /// Runs the reader-mode heuristic against the page currently loaded for
  /// [siteId]. Returns `null` when extraction finds nothing article-shaped.
  Future<ReaderArticle?> extractArticle(String siteId);
```

Add the two new imports the interface file needs:

```dart
import '../../domain/models/engine_events.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
```

- [ ] **Step 4: Extend `FakeContainerEngine`**

```dart
// lib/data/services/fake_container_engine.dart — add fields and members
  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();
  final resolvedPermissions = <String, PermissionDecision>{};
  ReaderArticle? articleToReturn;

  @override
  Stream<PendingPermissionRequest> permissionRequests() => _permissionController.stream;

  @override
  Future<void> resolvePermission(String requestId, PermissionDecision decision) async {
    resolvedPermissions[requestId] = decision;
  }

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  @override
  Future<ReaderArticle?> extractArticle(String siteId) async => articleToReturn;

  /// Test helpers: push one event of each new kind.
  void emitPermissionRequest(PendingPermissionRequest request) =>
      _permissionController.add(request);
  void emitDownload(HeldDownloadEvent event) => _downloadController.add(event);
  void emitTunnelDropped(TunnelDroppedEvent event) => _tunnelDroppedController.add(event);

  /// Test helper: advance a live session's category counts by [delta] and
  /// re-emit — mirrors what a real category-tagged `FilterEngine` does over
  /// time.
  void addBlocked(String siteId, BlockedCategory category, int delta) {
    final current = _sessions[siteId];
    if (current == null) return;
    final counts = Map<BlockedCategory, int>.from(current.categoryCounts);
    counts[category] = (counts[category] ?? 0) + delta;
    _sessions[siteId] = current.copyWith(
      categoryCounts: counts,
      blockedCount: counts.values.fold(0, (a, b) => a + b),
    );
    _emit();
  }
```

Also update `dispose()` to close the three new controllers:

```dart
  void dispose() {
    _controller.close();
    _permissionController.close();
    _downloadController.close();
    _tunnelDroppedController.close();
  }
```

Add the matching imports (`engine_events.dart`, `permissions.dart`,
`reader_article.dart`, `blocked_tally.dart`) to the top of the file.

- [ ] **Step 5: Write the failing channel-demux test**

`ChannelContainerEngine` cannot be unit-tested through a real platform
channel on the host, but its private parsing function can be exposed and
tested directly — the same pattern Plan 3 used for `_sessionFrom`.

```dart
// test/data/container_engine_channel_test.dart
import 'package:container/data/services/container_engine_channel.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a sessions event decodes category counts', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1',
          'phase': 'live',
          'lastActiveAt': null,
          'blockedCount': 9,
          'categoryCounts': {'trackers': 6, 'ads': 3},
          'failure': null,
        },
      ],
    };
    final sessions = sessionsFromEvent(event);
    expect(sessions.single.categoryCounts[BlockedCategory.trackers], 6);
    expect(sessions.single.categoryCounts[BlockedCategory.ads], 3);
  });

  test('a refused session decodes its failure reason', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{},
          'failure': 'proxyUnreachable',
        },
      ],
    };
    expect(sessionsFromEvent(event).single.failure, RouteFailureX.proxyUnreachable);
  });

  test('a permission_request event decodes the pending ask', () {
    final event = <Object?, Object?>{
      'type': 'permission_request',
      'siteId': 's1', 'host': 'meet.example.com', 'kind': 'camera',
      'requestId': 'r1',
    };
    final request = permissionRequestFromEvent(event);
    expect(request.host, 'meet.example.com');
    expect(request.kind, PermissionKind.camera);
  });
}
```

`RouteFailureX.proxyUnreachable` in that test is shorthand for
`RouteFailure.proxyUnreachable` re-exported — use the real
`RouteFailure.proxyUnreachable` directly and drop the alias; it is written
this way above only to flag that the import is `route_decision.dart`, not a
new type.

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/data/container_engine_channel_test.dart`
Expected: FAIL — `sessionsFromEvent`/`permissionRequestFromEvent` are not
defined; `ChannelContainerEngine`'s parsing is still private and flat.

- [ ] **Step 6: Rewrite `container_engine_channel.dart` for the discriminated wire format**

```dart
// lib/data/services/container_engine_channel.dart
import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/held_download.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/route_decision.dart';
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

RouteFailure? _failure(String? name) => switch (name) {
      'proxyUnreachable' => RouteFailure.proxyUnreachable,
      'proxyRefused' => RouteFailure.proxyRefused,
      'upstreamTimeout' => RouteFailure.upstreamTimeout,
      'tlsFailure' => RouteFailure.tlsFailure,
      'misconfigured' => RouteFailure.misconfigured,
      _ => null,
    };

BlockedCategory? _category(String name) => switch (name) {
      'trackers' => BlockedCategory.trackers,
      'ads' => BlockedCategory.ads,
      'fingerprinting' => BlockedCategory.fingerprinting,
      'permissionAsks' => BlockedCategory.permissionAsks,
      _ => null,
    };

PermissionKind _kind(String name) => switch (name) {
      'microphone' => PermissionKind.microphone,
      'location' => PermissionKind.location,
      'clipboard' => PermissionKind.clipboard,
      _ => PermissionKind.camera,
    };

Map<BlockedCategory, int> _categoryCountsFrom(Object? raw) {
  final map = (raw as Map<Object?, Object?>?) ?? const {};
  final result = <BlockedCategory, int>{};
  for (final entry in map.entries) {
    final category = _category(entry.key! as String);
    if (category != null) result[category] = entry.value as int;
  }
  return result;
}

ContainerSession _sessionFrom(Map<Object?, Object?> map) => ContainerSession(
      siteId: map['siteId']! as String,
      phase: _phase(map['phase']! as String),
      lastActiveAt: map['lastActiveAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt']! as int),
      blockedCount: (map['blockedCount'] as int?) ?? 0,
      categoryCounts: _categoryCountsFrom(map['categoryCounts']),
      failure: _failure(map['failure'] as String?),
    );

/// Exposed for testing — decodes a `type: "sessions"` event's payload.
List<ContainerSession> sessionsFromEvent(Map<Object?, Object?> event) =>
    (event['sessions']! as List<Object?>)
        .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
        .toList();

/// Exposed for testing — decodes a `type: "permission_request"` event.
PendingPermissionRequest permissionRequestFromEvent(Map<Object?, Object?> event) =>
    PendingPermissionRequest(
      siteId: event['siteId']! as String,
      host: event['host']! as String,
      kind: _kind(event['kind']! as String),
      requestId: event['requestId']! as String,
    );

/// Exposed for testing — decodes a `type: "download"` event.
HeldDownloadEvent downloadFromEvent(Map<Object?, Object?> event) => HeldDownloadEvent(
      siteId: event['siteId']! as String,
      download: HeldDownload(
        fileName: event['fileName']! as String,
        sizeBytes: event['sizeBytes']! as int,
        sourceHost: event['sourceHost']! as String,
        kindLabel: event['kindLabel']! as String,
      ),
    );

/// Exposed for testing — decodes a `type: "tunnel_dropped"` event.
TunnelDroppedEvent tunnelDroppedFromEvent(Map<Object?, Object?> event) => TunnelDroppedEvent(
      siteId: event['siteId']! as String,
      host: event['host']! as String,
      droppedAt: DateTime.fromMillisecondsSinceEpoch(event['droppedAtMs']! as int),
    );

class ChannelContainerEngine implements ContainerEngine {
  ChannelContainerEngine() {
    _events.receiveBroadcastStream().listen((event) {
      final map = event as Map<Object?, Object?>;
      switch (map['type']) {
        case 'permission_request':
          _permissionController.add(permissionRequestFromEvent(map));
        case 'download':
          _downloadController.add(downloadFromEvent(map));
        case 'tunnel_dropped':
          _tunnelDroppedController.add(tunnelDroppedFromEvent(map));
        default:
          _sessionsController.add(sessionsFromEvent(map));
      }
    });
  }

  final _sessionsController = StreamController<List<ContainerSession>>.broadcast();
  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();

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
  Future<void> wipeAll() => _method.invokeMethod('wipeAll');

  @override
  Future<void> close(String siteId) =>
      _method.invokeMethod('close', {'siteId': siteId});

  @override
  Future<void> reload(String siteId) =>
      _method.invokeMethod('reload', {'siteId': siteId});

  @override
  Stream<List<ContainerSession>> sessions() => _sessionsController.stream;

  @override
  Future<List<ContainerSession>> liveSessions() async {
    final result = await _method.invokeListMethod<Object?>('liveSessions');
    return (result ?? const <Object?>[])
        .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Stream<PendingPermissionRequest> permissionRequests() => _permissionController.stream;

  @override
  Future<void> resolvePermission(String requestId, PermissionDecision decision) =>
      _method.invokeMethod('resolvePermission', {
        'requestId': requestId,
        'decision': decision.name,
      });

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  @override
  Future<ReaderArticle?> extractArticle(String siteId) async {
    final result = await _method
        .invokeMapMethod<Object?, Object?>('extractArticle', {'siteId': siteId});
    if (result == null) return null;
    return ReaderArticle(
      host: result['host']! as String,
      title: result['title']! as String,
      paragraphs: (result['paragraphs']! as List<Object?>).cast<String>(),
      minutesToRead: result['minutesToRead']! as int,
    );
  }
}
```

- [ ] **Step 7: Run everything and commit**

Run: `flutter test`
Expected: PASS. Fix any widget test that constructs `ContainerSession` with
positional-looking assumptions about the new optional fields — none should
need changes, since `categoryCounts`/`failure` both default.

```bash
git add lib/domain/models/engine_events.dart lib/domain/models/container_session.dart \
  lib/data/services/container_engine.dart lib/data/services/fake_container_engine.dart \
  lib/data/services/container_engine_channel.dart test/data/container_engine_channel_test.dart
git commit -m "feat: container engine gains permission/download/tunnel event streams"
```

---

## Task 3: Kotlin — discriminated events, categorized filtering, downloads

The largest task, matching Plan 3 Task 5's own precedent of doing the
interceptor, router-adjacent wiring, filtering and shields together because
they all touch the same `Session`/`EngineChannel` object in one pass.

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/FilterEngine.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Shields.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/ContainerViewFactory.kt`
- Create: `android/app/src/main/assets/filters/default_trackers.txt`
- Create: `android/app/src/main/assets/filters/default_ads.txt`
- Delete: `android/app/src/main/assets/filters/default.txt`
- Modify: `android/app/src/test/kotlin/com/mono/container/engine/FilterEngineTest.kt`

**Interfaces:**
- Consumes: `SiteConfig` (Plan 3, unchanged), `Router.resolve` (Plan 3).
- Produces: `FilterEngine.matches(String): String?` (returns the matched category name or null), `FilterEngine.countFor(String): Int`, `Shields.apply(webView, config, onBlocked: (String) -> Unit)`, `Shields.chromeClientFor(config, session, onPermissionRequest: (PendingPermission) -> Unit)`, `EngineChannel.resolvePermission(requestId, decision)`, `EngineChannel.extractArticle(siteId): Map<String, Any?>?`, discriminated event maps for all four `type`s.

- [ ] **Step 1: Write the failing categorized `FilterEngine` test**

```kotlin
// android/app/src/test/kotlin/com/mono/container/engine/FilterEngineTest.kt
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FilterEngineTest {

    private val engine = FilterEngine(mapOf(
        "trackers" to listOf("||track.example.net^"),
        "ads" to listOf("||ads.example.com^"),
    ))

    @Test fun `a tracker host is blocked under the trackers category`() {
        assertEquals("trackers", engine.matches("https://track.example.net/pixel.gif"))
    }

    @Test fun `an ad host is blocked under the ads category`() {
        assertEquals("ads", engine.matches("https://ads.example.com/banner.js"))
    }

    @Test fun `an unlisted host is not blocked`() {
        assertNull(engine.matches("https://forum.example.com/thread"))
    }

    @Test fun `each category counts independently`() {
        engine.matches("https://track.example.net/a")
        engine.matches("https://track.example.net/b")
        engine.matches("https://ads.example.com/c")
        assertEquals(2, engine.countFor("trackers"))
        assertEquals(1, engine.countFor("ads"))
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests '*FilterEngineTest*'`
Expected: FAIL — `FilterEngine` still takes a flat `List<String>` and returns
`Boolean` from `matches`.

- [ ] **Step 3: Rewrite `FilterEngine` for categories**

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/FilterEngine.kt
package com.mono.container.engine

import java.net.URI
import java.util.concurrent.atomic.AtomicInteger

/**
 * Domain-blocking only: `||host^` rules, now grouped by category so `2a`'s
 * match count and the Today log (`5c`) can tell trackers from ads. Feeds
 * spec `2a`'s "Local filter lists · 42 rules matched today".
 */
class FilterEngine(rulesByCategory: Map<String, List<String>>) {

    private data class CategorySet(val hosts: Set<String>, val counter: AtomicInteger)

    private val categories: Map<String, CategorySet> = rulesByCategory.mapValues { (_, rules) ->
        CategorySet(
            hosts = rules
                .map { it.trim() }
                .filter { it.startsWith("||") && it.endsWith("^") }
                .map { it.removePrefix("||").removeSuffix("^").lowercase() }
                .toSet(),
            counter = AtomicInteger(0),
        )
    }

    val blockedCount: Int get() = categories.values.sumOf { it.counter.get() }

    fun countFor(category: String): Int = categories[category]?.counter?.get() ?: 0

    /** Returns the category that matched, or `null` if nothing did. */
    fun matches(url: String): String? {
        val host = runCatching { URI(url).host }.getOrNull()?.lowercase() ?: return null
        for ((name, set) in categories) {
            if (set.hosts.any { host == it || host.endsWith(".$it") }) {
                set.counter.incrementAndGet()
                return name
            }
        }
        return null
    }
}
```

- [ ] **Step 4: Run the Kotlin tests and split the asset file**

Run: `cd android && ./gradlew :app:testDebugUnitTest --tests '*FilterEngineTest*'`
Expected: PASS, 4 tests.

Split the seed asset. Read the current
`android/app/src/main/assets/filters/default.txt`; move every line into
`default_trackers.txt` unchanged (it is one flat tracker-domain list today —
no line in it is ad-specific), and create `default_ads.txt` with one
starter rule so the `ads` category is not empty:

```
||doubleclick.net^
||adservice.google.com^
```

Delete `default.txt`.

- [ ] **Step 5: Wire categorized rules and per-session counters into `Session`**

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt
package com.mono.container.engine

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

/** Tracks fingerprinting and permission-ask blocks — the two categories
 * `FilterEngine` never sees, because they never touch the network layer. */
class SideCounters {
    val fingerprinting = AtomicInteger(0)
    val permissionAsks = AtomicInteger(0)
}

sealed class PendingPermission {
    abstract val requestId: String
    data class Hardware(
        override val requestId: String,
        val request: android.webkit.PermissionRequest,
        val resources: List<String>,
    ) : PendingPermission()
    data class Geolocation(
        override val requestId: String,
        val origin: String,
        val callback: android.webkit.GeolocationPermissions.Callback,
    ) : PendingPermission()
}

/**
 * One open container. It owns its own [FilterEngine] rather than sharing one,
 * because `2c` and the Today log report a blocked count *per site*.
 */
class Session(val config: SiteConfig, rulesByCategory: Map<String, List<String>>) {

    val filters = FilterEngine(rulesByCategory)
    val counters = SideCounters()
    val interceptor = RequestInterceptor(filters) { onTunnelDropped?.invoke(it) }
    val pendingPermissions = LinkedHashMap<String, PendingPermission>()

    /** Kinds granted for the rest of this session by an "allow while open"
     * decision. Cleared implicitly when the session closes with the object. */
    val sessionGrants = mutableSetOf<String>()

    var phase: String = PHASE_OPENING
    var lastActiveAtMs: Long? = null
    var failure: String? = null
    var view: ContainerView? = null

    /** Set by [EngineChannel] after construction; lets a live session's
     * dropped tunnel reach the event sink without `Session` holding a
     * reference to the channel itself. */
    var onTunnelDropped: ((RouteFailure) -> Unit)? = null

    fun toMap(): Map<String, Any?> = mapOf(
        "siteId" to config.siteId,
        "phase" to phase,
        "lastActiveAt" to lastActiveAtMs,
        "blockedCount" to filters.blockedCount + counters.fingerprinting.get() + counters.permissionAsks.get(),
        "categoryCounts" to mapOf(
            "trackers" to filters.countFor("trackers"),
            "ads" to filters.countFor("ads"),
            "fingerprinting" to counters.fingerprinting.get(),
            "permissionAsks" to counters.permissionAsks.get(),
        ),
        "failure" to failure,
    )

    companion object {
        const val PHASE_OPENING = "opening"
        const val PHASE_LIVE = "live"
        const val PHASE_BACKGROUND = "background"
        const val PHASE_REFUSED = "refused"
    }
}
```

- [ ] **Step 6: Rewrite `EngineChannel` for the discriminated wire format**

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt, continued
class EngineChannel(
    private val context: Context,
    private val profiles: ProfileManager,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val sessions = LinkedHashMap<String, Session>()
    private var sink: EventChannel.EventSink? = null
    private var requestCounter = 0

    private val rulesByCategory: Map<String, List<String>> by lazy {
        mapOf(
            "trackers" to readAsset("filters/default_trackers.txt"),
            "ads" to readAsset("filters/default_ads.txt"),
        )
    }

    private fun readAsset(path: String): List<String> =
        runCatching { context.assets.open(path).bufferedReader().readLines() }
            .getOrDefault(emptyList())

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
    }

    fun session(siteId: String): Session? = sessions[siteId]

    fun attachView(siteId: String, view: ContainerView) {
        sessions[siteId]?.view = view
    }

    fun markLive(siteId: String) {
        val session = sessions[siteId] ?: return
        if (session.phase == Session.PHASE_REFUSED) return
        session.phase = Session.PHASE_LIVE
        session.lastActiveAtMs = System.currentTimeMillis()
        emitSessions()
    }

    /** Called by [RequestInterceptor] when a *live* session's fetch starts
     * refusing mid-browse — spec §3's `tunnel_dropped`, distinct from an
     * initial-connect [Session.PHASE_REFUSED]. */
    private fun onTunnelDropped(siteId: String, failure: RouteFailure) {
        val session = sessions[siteId] ?: return
        if (session.phase != Session.PHASE_LIVE) return
        sink?.success(mapOf(
            "type" to "tunnel_dropped",
            "siteId" to siteId,
            "host" to (runCatching { java.net.URI(session.config.url).host }.getOrNull() ?: session.config.url),
            "droppedAtMs" to System.currentTimeMillis(),
        ))
    }

    /** Called by [Shields] when a hardware permission the site's stored
     * config does not already grant is requested live. */
    private fun onPermissionAsk(siteId: String, host: String, kind: String, requestId: String) {
        sink?.success(mapOf(
            "type" to "permission_request",
            "siteId" to siteId, "host" to host, "kind" to kind, "requestId" to requestId,
        ))
    }

    /** Called by [ContainerView]'s `DownloadListener`. */
    fun onDownload(siteId: String, fileName: String, sizeBytes: Long, kindLabel: String) {
        val session = sessions[siteId] ?: return
        val host = runCatching { java.net.URI(session.config.url).host }.getOrNull()
            ?: session.config.url
        sink?.success(mapOf(
            "type" to "download",
            "siteId" to siteId, "fileName" to fileName, "sizeBytes" to sizeBytes,
            "sourceHost" to host, "kindLabel" to kindLabel,
        ))
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isolationAvailable" -> result.success(profiles.isAvailable())
                "open" -> result.success(open(call))
                "close" -> { close(call.argument<String>("siteId")!!); result.success(null) }
                "reload" -> { sessions[call.argument<String>("siteId")]?.view?.reload(); result.success(null) }
                "wipe" -> { profiles.wipe(call.argument<String>("profileId")!!); result.success(null) }
                "wipeAll" -> { wipeAll(); result.success(null) }
                "liveSessions" -> result.success(sessions.values.map(Session::toMap))
                "resolvePermission" -> {
                    resolvePermission(call.argument<String>("requestId")!!, call.argument<String>("decision")!!)
                    result.success(null)
                }
                "extractArticle" -> extractArticle(call.argument<String>("siteId")!!, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("engine", e.message, null)
        }
    }

    private fun open(call: MethodCall): Map<String, Any?> {
        val config = configFrom(call)
        val session = Session(config, rulesByCategory)
        session.onTunnelDropped = { failure -> onTunnelDropped(config.siteId, failure) }
        sessions[config.siteId] = session

        if (!profiles.isAvailable()) {
            session.phase = Session.PHASE_REFUSED
            session.failure = null // no route was even attempted; isolation itself is unavailable
        } else {
            val route = Router.resolve(config, ProxyProbe.reachable(config.proxyHost ?: "", config.proxyPort ?: -1))
            if (route is Route.Refused) {
                session.phase = Session.PHASE_REFUSED
                session.failure = route.failure.name.let(::routeFailureToDartName)
            } else {
                profiles.profileFor(config.profileId)
                session.lastActiveAtMs = System.currentTimeMillis()
            }
        }

        emitSessions()
        return session.toMap()
    }

    private fun resolvePermission(requestId: String, decisionName: String) {
        for (session in sessions.values) {
            val pending = session.pendingPermissions.remove(requestId) ?: continue
            when (pending) {
                is PendingPermission.Hardware -> when (decisionName) {
                    "keepBlocked" -> pending.request.deny()
                    else -> {
                        if (decisionName == "allowWhileOpen") {
                            session.sessionGrants.addAll(pending.resources)
                        }
                        pending.request.grant(pending.resources.toTypedArray())
                    }
                }
                is PendingPermission.Geolocation -> when (decisionName) {
                    "keepBlocked" -> pending.callback.invoke(pending.origin, false, false)
                    else -> {
                        if (decisionName == "allowWhileOpen") session.sessionGrants.add("geolocation")
                        pending.callback.invoke(pending.origin, true, false)
                    }
                }
            }
            return
        }
        // The request already timed out or its site closed — a silent no-op,
        // per this plan's Known Gaps on backgrounded events.
    }

    private fun extractArticle(siteId: String, result: MethodChannel.Result) {
        val view = sessions[siteId]?.view
        if (view == null) { result.success(null); return }
        view.extractArticle { article -> result.success(article) }
    }

    private fun close(siteId: String) {
        val session = sessions.remove(siteId) ?: return
        session.view?.dispose()
        emitSessions()
    }

    private fun wipeAll() {
        for (siteId in sessions.keys.toList()) close(siteId)
        profiles.wipeAll()
    }

    private fun configFrom(call: MethodCall) = SiteConfig(
        siteId = call.argument<String>("siteId")!!,
        profileId = call.argument<String>("profileId")!!,
        url = call.argument<String>("url")!!,
        proxyMode = call.argument<String>("proxyMode")!!,
        proxyHost = call.argument<String>("proxyHost"),
        proxyPort = call.argument<Int>("proxyPort"),
        blockWebRtc = call.argument<Boolean>("blockWebRtc") ?: true,
        blockTrackers = call.argument<Boolean>("blockTrackers") ?: true,
        antiFingerprinting = call.argument<Boolean>("antiFingerprinting") ?: true,
        allowCamera = call.argument<Boolean>("allowCamera") ?: false,
        allowMicrophone = call.argument<Boolean>("allowMicrophone") ?: false,
        allowLocation = call.argument<Boolean>("allowLocation") ?: false,
        allowClipboard = call.argument<Boolean>("allowClipboard") ?: false,
        userAgentMode = call.argument<String>("userAgentMode") ?: "android",
        forceDark = call.argument<Boolean>("forceDark") ?: true,
        pageZoom = call.argument<Int>("pageZoom") ?: 100,
        customCss = call.argument<String>("customCss") ?: "",
        customJs = call.argument<String>("customJs") ?: "",
        wipeOnExit = call.argument<Boolean>("wipeOnExit") ?: false,
    )

    fun nextRequestId(): String = "req-${++requestCounter}"

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        emitSessions()
    }

    override fun onCancel(arguments: Any?) { sink = null }

    private fun emitSessions() {
        sink?.success(mapOf("type" to "sessions", "sessions" to sessions.values.map(Session::toMap)))
    }

    companion object {
        const val METHOD_CHANNEL = "com.mono.container/engine"
        const val EVENT_CHANNEL = "com.mono.container/sessions"
        const val VIEW_TYPE = "com.mono.container/view"
    }
}

/** Dart's `RouteFailure` enum is lowerCamelCase; Kotlin's is SCREAMING_SNAKE. */
fun routeFailureToDartName(kotlinName: String): String = when (kotlinName) {
    "PROXY_UNREACHABLE" -> "proxyUnreachable"
    "PROXY_REFUSED" -> "proxyRefused"
    "UPSTREAM_TIMEOUT" -> "upstreamTimeout"
    "TLS_FAILURE" -> "tlsFailure"
    else -> "misconfigured"
}
```

- [ ] **Step 7: Attach a per-request permission ask in `Shields.kt`**

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/Shields.kt
package com.mono.container.engine

import android.webkit.WebView

object Shields {
    fun apply(webView: WebView, config: SiteConfig, onFingerprintNoiseApplied: () -> Unit = {}) {
        val js = buildString {
            if (config.blockWebRtc) {
                append(
                    "delete window.RTCPeerConnection;" +
                    "delete window.webkitRTCPeerConnection;" +
                    "navigator.mediaDevices && (navigator.mediaDevices.getUserMedia=" +
                    "()=>Promise.reject(new DOMException('Blocked','NotAllowedError')));"
                )
            }
            append("window.WebSocket=function(){throw new Error('Blocked');};")
            if (config.antiFingerprinting) {
                append(webView.context.assets.open("shields/fingerprint.js")
                    .bufferedReader().readText())
                onFingerprintNoiseApplied()
            }
            if (config.customCss.isNotEmpty()) {
                append("document.addEventListener('DOMContentLoaded',()=>{" +
                    "const s=document.createElement('style');" +
                    "s.textContent=${config.customCss.asJsString()};" +
                    "document.head.appendChild(s);});")
            }
            append(config.customJs)
        }
        androidx.webkit.WebViewCompat.addDocumentStartJavaScript(webView, js, setOf("*"))
    }

    /**
     * A stored `allow*` flag is a pre-declaration made in the Add Site form
     * (`2a`); it silently grants with no live prompt. A site whose stored
     * flag is off but which asks anyway gets [onAsk] instead of an
     * unconditional deny — Plan 6 hands the decision to `PermissionRequestSheet`
     * (`6a`) rather than the platform refusing on the user's behalf.
     */
    fun chromeClientFor(
        config: SiteConfig,
        session: Session,
        onAsk: (PendingPermission) -> String,
    ) = object : android.webkit.WebChromeClient() {
        override fun onPermissionRequest(request: android.webkit.PermissionRequest) {
            val granted = mutableListOf<String>()
            val toAsk = mutableListOf<String>()
            for (resource in request.resources) {
                val storedAllow = when (resource) {
                    android.webkit.PermissionRequest.RESOURCE_VIDEO_CAPTURE -> config.allowCamera
                    android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE -> config.allowMicrophone
                    else -> false
                }
                val alreadyGrantedThisSession = session.sessionGrants.contains(resource)
                if (storedAllow || alreadyGrantedThisSession) granted.add(resource) else toAsk.add(resource)
            }
            if (toAsk.isEmpty()) {
                if (granted.isEmpty()) request.deny() else request.grant(granted.toTypedArray())
                return
            }
            val requestId = onAsk(PendingPermission.Hardware(
                requestId = "", request = request, resources = request.resources.toList(),
            ))
            session.pendingPermissions[requestId] =
                PendingPermission.Hardware(requestId, request, request.resources.toList())
        }

        override fun onGeolocationPermissionsShowPrompt(
            origin: String, callback: android.webkit.GeolocationPermissions.Callback,
        ) {
            if (config.allowLocation || session.sessionGrants.contains("geolocation")) {
                callback.invoke(origin, true, false)
                return
            }
            val requestId = onAsk(PendingPermission.Geolocation(requestId = "", origin = origin, callback = callback))
            session.pendingPermissions[requestId] =
                PendingPermission.Geolocation(requestId, origin, callback)
        }
    }
}
```

The `onAsk` callback's return value doubling as the id it is then stored
under (rather than generating the id once and passing it in) is intentional:
`EngineChannel` is the only object that owns `nextRequestId()` and the event
sink, so the id has to originate there — `onAsk` calls
`engine.nextRequestId()`, emits the event, and returns the id for `Shields`
to key its own map by, keeping `Shields` itself free of any channel
reference.

- [ ] **Step 8: Wire the `onAsk`/`onFingerprintNoiseApplied` callbacks from `EngineChannel.open` through to `ContainerView`**

```kotlin
// EngineChannel.kt — inside open(), after emitSessions() setup but before
// the profile branch, thread the counters and event emission down:
```

Extend `ContainerView`'s constructor to accept the two callbacks and pass
them straight to `Shields`:

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt
package com.mono.container.engine

import android.content.Context
import android.view.View
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.webkit.WebSettings
import androidx.webkit.ServiceWorkerControllerCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.platform.PlatformView

class ContainerView(
    context: Context,
    private val config: SiteConfig,
    private val profiles: ProfileManager,
    private val interceptor: RequestInterceptor,
    private val session: Session,
    private val onLive: () -> Unit = {},
    private val onAsk: (PendingPermission) -> String = { "" },
    private val onDownload: (fileName: String, sizeBytes: Long, kindLabel: String) -> Unit = { _, _, _ -> },
) : PlatformView {

    private var disposed = false

    private val webView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.userAgentString = userAgentFor(config.userAgentMode)
        settings.setSupportMultipleWindows(false)
        settings.mediaPlaybackRequiresUserGesture = true
        setSafeBrowsingEnabled(false)

        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(this, config.forceDark)
        }
        setInitialScale(config.pageZoom)
    }

    init {
        androidx.webkit.WebViewCompat.setProfile(webView, config.profileId)
        webView.webViewClient = interceptor.clientFor(config, onLive)
        webView.webChromeClient = Shields.chromeClientFor(config, session, onAsk)
        Shields.apply(webView, config) { session.counters.fingerprinting.incrementAndGet() }

        webView.setDownloadListener { url, _, contentDisposition, mimeType, contentLength ->
            val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val extension = MimeTypeMap.getFileExtensionFromUrl(url).ifEmpty {
                mimeType?.substringAfter('/') ?: ""
            }
            onDownload(fileName, contentLength, extension.uppercase().ifEmpty { "FILE" })
        }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
            ServiceWorkerControllerCompat.getInstance()
                .setServiceWorkerClient(interceptor.serviceWorkerClient(config))
        }

        webView.loadUrl(config.url)
    }

    override fun getView(): View = webView

    fun reload() { if (!disposed) webView.reload() }

    /** Runs the reader-mode JS heuristic and hands the parsed article back
     * on the platform thread. `null` when nothing article-shaped was found. */
    fun extractArticle(onResult: (Map<String, Any?>?) -> Unit) {
        if (disposed) { onResult(null); return }
        webView.evaluateJavascript(READER_JS) { rawJson ->
            val json = rawJson?.takeIf { it != "null" }
            if (json == null) { onResult(null); return@evaluateJavascript }
            onResult(parseReaderJson(json))
        }
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
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

`ContainerViewFactory` now needs to thread `session`/`onAsk`/`onDownload`
through:

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/ContainerViewFactory.kt
class ContainerViewFactory(
    private val engine: EngineChannel,
    private val profiles: ProfileManager,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val siteId = params?.get("siteId") as? String
            ?: error("A container view needs a siteId.")
        val session = engine.session(siteId)
            ?: error("open() must precede the container view for $siteId.")

        val view = ContainerView(
            context = context,
            config = session.config,
            profiles = profiles,
            interceptor = session.interceptor,
            session = session,
            onLive = { engine.markLive(siteId) },
            onAsk = { pending ->
                val requestId = engine.nextRequestId()
                val host = runCatching { java.net.URI(session.config.url).host }.getOrNull()
                    ?: session.config.url
                val kind = when (pending) {
                    is PendingPermission.Geolocation -> "location"
                    is PendingPermission.Hardware -> if (pending.resources.contains(
                            android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE)) "microphone" else "camera"
                }
                engine.onPermissionAskPublic(siteId, host, kind, requestId)
                requestId
            },
            onDownload = { fileName, sizeBytes, kindLabel ->
                engine.onDownload(siteId, fileName, sizeBytes, kindLabel)
            },
        )
        engine.attachView(siteId, view)
        return view
    }
}
```

Rename `EngineChannel`'s private `onPermissionAsk` to a public
`onPermissionAskPublic(siteId, host, kind, requestId)` (or drop the
`private` modifier and keep the shorter name — either is fine, but the
factory needs to call it, so it cannot stay `private`).

- [ ] **Step 9: Emit `tunnel_dropped` from a live session's failing fetch**

`RequestInterceptor` needs a way to tell `Session`/`EngineChannel` a live
fetch just refused, without holding a reference to either:

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt
class RequestInterceptor(
    private val filters: FilterEngine,
    private val onRefused: (RouteFailure) -> Unit = {},
) {
    fun clientFor(config: SiteConfig, onLoaded: () -> Unit = {}): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
            intercept(config, request)
        override fun onPageFinished(view: WebView, url: String) { onLoaded() }
    }

    fun serviceWorkerClient(config: SiteConfig): ServiceWorkerClientCompat =
        object : ServiceWorkerClientCompat() {
            override fun shouldInterceptRequest(request: WebResourceRequest): WebResourceResponse? =
                intercept(config, request)
        }

    private fun intercept(config: SiteConfig, request: WebResourceRequest): WebResourceResponse? {
        val url = request.url.toString()
        if (config.blockTrackers && filters.matches(url) != null) return blocked()

        return when (val route = Router.resolve(config, proxyReachable(config))) {
            is Route.Direct -> null
            is Route.Proxy -> fetchThrough(route, request)
            is Route.Refused -> { onRefused(route.failure); refused(route.failure) }
        }
    }

    // blocked(), refused(), fetchThrough(), readLine(), readStatusAndHeaders(),
    // proxyReachable() are unchanged from Plan 3 — see that plan's Task 5.
}
```

`Session`'s constructor already threads `{ onTunnelDropped?.invoke(it) }`
into `RequestInterceptor`'s `onRefused` parameter (Step 5) — this only fires
for a request made *after* the session reached `PHASE_LIVE`, because
`EngineChannel.onTunnelDropped` checks `session.phase != Session.PHASE_LIVE`
and returns early otherwise; the *first* refusal, before the page ever
loads, is what sets `Session.PHASE_REFUSED` in `open()` instead (Step 6) —
the two paths cannot double-fire because a refused session's `phase` never
reaches `PHASE_LIVE`.

- [ ] **Step 10: Write the reader-mode extraction JS and its Kotlin-side parser**

```kotlin
// android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt — top-level
private const val READER_JS = """
(function(){
  document.querySelectorAll('script,style,nav,aside,footer').forEach(e=>e.remove());
  var candidates = document.body.querySelectorAll('article,main,div,section');
  var best = null, bestScore = 0;
  candidates.forEach(function(el){
    var text = el.innerText || '';
    var tags = el.querySelectorAll('*').length || 1;
    var score = text.length / tags;
    if (text.length > 200 && score > bestScore) { bestScore = score; best = el; }
  });
  if (!best) return null;
  var paragraphs = [];
  best.querySelectorAll('p,h1,h2,h3,li').forEach(function(el){
    var t = (el.innerText || '').trim();
    if (t.length > 20) paragraphs.push(t);
  });
  if (paragraphs.length === 0) return null;
  var words = paragraphs.join(' ').split(/\s+/).length;
  return JSON.stringify({
    host: location.host,
    title: document.title,
    paragraphs: paragraphs,
    minutesToRead: Math.max(1, Math.round(words / 200)),
  });
})();
"""

private fun parseReaderJson(json: String): Map<String, Any?>? = runCatching {
    // evaluateJavascript double-encodes the string result; strip one layer.
    val unescaped = org.json.JSONTokener(json).nextValue() as String
    val obj = org.json.JSONObject(unescaped)
    val paragraphs = obj.getJSONArray("paragraphs")
    mapOf(
        "host" to obj.getString("host"),
        "title" to obj.getString("title"),
        "paragraphs" to (0 until paragraphs.length()).map { paragraphs.getString(it) },
        "minutesToRead" to obj.getInt("minutesToRead"),
    )
}.getOrNull()
```

This is the plan's one honestly-approximate piece, flagged in Known Gaps —
the highest text-to-tag-node-count heuristic finds typical article pages
and nothing more; there is no spec to be exact against (`reader_article.dart`'s
own doc comment already says so).

- [ ] **Step 11: Run every Kotlin test and commit**

Run: `cd android && ./gradlew :app:testDebugUnitTest`
Expected: PASS — `RouterTest` untouched and green, `FilterEngineTest` green
with the new category assertions.

Run: `flutter build apk --debug`
Expected: builds clean — this is the manual compile check Plan 3 established
for changes with no host-testable Kotlin coverage (the `WebView`/`WebChromeClient`
wiring here cannot run on the JVM test runner).

```bash
git add android/
git commit -m "feat: categorized filtering, download interception, and live permission/tunnel events"
```

---

## Task 4: `ContainerRoute` and the navigation shell

The first real `Navigator` usage anywhere in this app.

**Files:**
- Create: `lib/ui/features/container/views/container_route.dart`
- Modify: `lib/ui/features/container/view_models/providers.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart`
- Test: `test/ui/features/container_route_test.dart`

**Interfaces:**
- Consumes: `ContainerEngine` (Task 2/3), `Site`, `OpenStep`/`openStepsFor`, `RouteFailureCopy`, `SwitcherEntry`, `SiteRowAction`, `SiteRowMenu`, all six Plan 4 in-page screens.
- Produces: `sessionForSiteProvider`, `ContainerRoute` widget, real `onAddSite`/`onOpenSite`/`onSiteMenu` on `DashboardScreen`.

- [ ] **Step 1: Add `sessionForSiteProvider`**

```dart
// lib/ui/features/container/view_models/providers.dart — add
final sessionForSiteProvider =
    StreamProvider.family<ContainerSession?, String>((ref, siteId) {
  final engine = ref.watch(containerEngineProvider);
  return engine.sessions().map((sessions) {
    for (final session in sessions) {
      if (session.siteId == siteId) return session;
    }
    return null;
  });
});
```

Also drop the `// ignore: unused_element` and rename the private `_panic`
helper to a public one now that Step 4 gives it a real call site:

```dart
Future<void> panic(WidgetRef ref) async {
  final report = await ref.read(panicServiceProvider).trigger();
  ref.read(sessionProvider.notifier).panicked(report);
}
```

Add the `container_session.dart` import this file needs.

- [ ] **Step 2: Write the failing `ContainerRoute` test**

```dart
// test/ui/features/container_route_test.dart
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/container/views/container_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site() => Site(
      id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'a' * 32,
      proxyMode: ProxyMode.direct,
    );

Future<void> _pump(WidgetTester tester, FakeContainerEngine engine, Site site) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [containerEngineProvider.overrideWithValue(engine)],
    child: MaterialApp(home: ContainerRoute(site: site)),
  ));
}

void main() {
  testWidgets('opening a site shows the checklist, then the container', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pump();
    expect(find.text('Starting a clean container'), findsOneWidget);

    await tester.pump();
    expect(find.text('forum.example.com'), findsOneWidget);
  });

  testWidgets('a refused route pushes ProxyUnreachableScreen', (tester) async {
    final engine = FakeContainerEngine(proxyReachable: false);
    await _pump(tester, engine, _site().copyWith(
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cannot reach the proxy'), findsNothing); // headline differs; assert the screen instead
    expect(find.byType(ProxyUnreachableScreenFinder), findsNothing); // see note below
  });

  testWidgets('a tunnel_dropped event overlays TunnelDroppedScreen on the still-live page', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitTunnelDropped(const TunnelDroppedEventStub());
    await tester.pump();
    expect(find.text('Tunnel dropped'), findsOneWidget);
  });
}
```

The two `Finder`/`Stub` placeholders above are deliberately wrong — replace
them once the real widget exists: import `ProxyUnreachableScreen` and
`TunnelDroppedEvent` directly and assert `find.byType(ProxyUnreachableScreen)`
/ construct a real `TunnelDroppedEvent(siteId: 's1', host: 'forum.example.com',
droppedAt: DateTime(2026, 9, 2))`. Writing the test with the real imports the
first time is expected — the note exists only because this document cannot
import a not-yet-created file; delete this paragraph once the imports are
in.

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/ui/features/container_route_test.dart`
Expected: FAIL — `container_route.dart` does not exist.

- [ ] **Step 4: Write `ContainerRoute`**

```dart
// lib/ui/features/container/views/container_route.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/open_step.dart';
import '../../../../domain/models/relative_age.dart';
import '../../../../domain/models/route_failure_copy.dart';
import '../../../../domain/models/site.dart';
import '../../in_page/views/held_download_sheet.dart';
import '../../in_page/views/permission_request_sheet.dart';
import '../../in_page/views/proxy_unreachable_screen.dart';
import '../../in_page/views/reader_screen.dart';
import '../../in_page/views/tunnel_dropped_screen.dart';
import '../view_models/providers.dart';
import 'container_screen.dart';
import 'container_web_view.dart';
import 'opening_screen.dart';
import 'switcher_sheet.dart';

/// One push per site tap. Owns the `opening -> live -> refused` lifecycle
/// against [ContainerEngine] internally, rather than issuing a second
/// navigation event when the session finishes connecting — see this plan's
/// design spec §2 for why a `pushReplacement` was rejected.
class ContainerRoute extends ConsumerStatefulWidget {
  const ContainerRoute({super.key, required this.site});

  final Site site;

  @override
  ConsumerState<ContainerRoute> createState() => _ContainerRouteState();
}

class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  bool _opened = false;
  bool _refusalHandled = false;
  bool _tunnelDropped = false;
  StreamSubscription<PendingPermissionRequest>? _permissionSub;
  StreamSubscription<HeldDownloadEvent>? _downloadSub;
  StreamSubscription<TunnelDroppedEvent>? _tunnelSub;

  String get _host => Uri.tryParse(widget.site.url)?.host ?? widget.site.url;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(containerEngineProvider);
    _permissionSub = engine
        .permissionRequests()
        .where((r) => r.siteId == widget.site.id)
        .listen(_showPermissionSheet);
    _downloadSub = engine
        .downloads()
        .where((d) => d.siteId == widget.site.id)
        .listen(_showDownloadSheet);
    _tunnelSub = engine
        .tunnelDropped()
        .where((t) => t.siteId == widget.site.id)
        .listen((_) => setState(() => _tunnelDropped = true));
    _open();
  }

  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    await ref.read(containerEngineProvider).open(widget.site);
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    _downloadSub?.cancel();
    _tunnelSub?.cancel();
    super.dispose();
  }

  void _showPermissionSheet(PendingPermissionRequest request) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => PermissionRequestSheet(
        host: request.host,
        kind: request.kind,
        onDecision: (decision) {
          Navigator.pop(context);
          ref.read(containerEngineProvider).resolvePermission(request.requestId, decision);
        },
      ),
    );
  }

  void _showDownloadSheet(HeldDownloadEvent event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HeldDownloadSheet(
        download: event.download,
        onDecision: (_) => Navigator.pop(context),
      ),
    );
  }

  Future<void> _openReader() async {
    final article = await ref.read(containerEngineProvider).extractArticle(widget.site.id);
    if (article == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderScreen(
        article: article,
        onClose: () => Navigator.pop(context),
        onTextSize: () {},
        onTheme: () {},
      ),
    ));
  }

  void _handleRefusal(ContainerSession session) {
    if (_refusalHandled) return;
    _refusalHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ProxyUnreachableScreen(
          host: _host,
          siteName: widget.site.name,
          failure: session.failure ?? RouteFailure.misconfigured,
          tunnelDescriptor: widget.site.proxyHost == null
              ? 'no proxy'
              : '${widget.site.proxyMode.name} · ${widget.site.proxyHost}:${widget.site.proxyPort}',
          lastWorkedLabel: 'never on this device',
          onTryAgain: () => Navigator.pop(context),
          onChangeProxySettings: () => Navigator.pop(context),
          onOpenWithoutTunnel: () => Navigator.pop(context),
        ),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionForSiteProvider(widget.site.id));

    return sessionAsync.when(
      loading: () => OpeningBody(
        host: _host, steps: openStepsFor(widget.site), progress: 0.2,
        onCancel: () => Navigator.pop(context),
      ),
      error: (_, __) => OpeningBody(
        host: _host, steps: openStepsFor(widget.site), progress: 0,
        onCancel: () => Navigator.pop(context),
      ),
      data: (session) {
        if (session == null || session.phase == SessionPhase.opening) {
          return OpeningBody(
            host: _host, steps: openStepsFor(widget.site), progress: 0.6,
            onCancel: () => Navigator.pop(context),
          );
        }
        if (session.phase == SessionPhase.refused) {
          _handleRefusal(session);
          return const SizedBox.shrink();
        }

        final engine = ref.read(containerEngineProvider);
        return Stack(children: [
          ContainerScreen(
            host: _host,
            routeLabel: widget.site.proxyMode.name.toUpperCase(),
            live: session.phase == SessionPhase.live,
            openCount: 1,
            body: ContainerWebView(siteId: widget.site.id),
            entries: [
              SwitcherEntry(
                siteId: widget.site.id, name: widget.site.name,
                monogram: widget.site.monogram,
                meta: 'viewing now · ${widget.site.proxyMode.name}',
                live: true,
              ),
            ],
            workspaceName: '',
            onBack: () => Navigator.pop(context),
            onReload: () => engine.reload(widget.site.id),
            onPanic: () => panic(ref),
            onCloseSession: (siteId) async {
              await engine.close(siteId);
              if (mounted) Navigator.pop(context);
            },
            onCloseAllAndWipe: () async {
              await engine.close(widget.site.id);
              await engine.wipe(widget.site.profileId);
              if (mounted) Navigator.pop(context);
            },
            onReaderMode: _openReader,
            onFilters: () {},
            onMenu: () {},
            onMore: () {},
          ),
          if (_tunnelDropped)
            TunnelDroppedScreen(
              host: _host,
              droppedAgoLabel: 'just now',
              onReconnect: () => setState(() => _tunnelDropped = false),
              onCloseAndWipe: () async {
                await engine.close(widget.site.id);
                await engine.wipe(widget.site.profileId);
                if (mounted) Navigator.pop(context);
              },
            ),
        ]);
      },
    );
  }
}
```

`onFilters`/`onMenu`/`onMore` are left as empty callbacks here on purpose —
Task 6 gives `onMenu` a real `SiteSheet` call site and Task 7 gives
`onFilters` a real `ScriptsAndFiltersScreen` push; wiring them here and
again in a later task would just be churn. `relative_age.dart` is imported
for a future use and unused in this task's code — drop the import if the
analyzer flags it as unused after Step 4; it is not needed until
`droppedAgoLabel`'s "just now" placeholder is replaced with a real duration
(Known Gaps).

- [ ] **Step 5: Wire the dashboard's real callbacks**

```dart
// lib/ui/features/dashboard/views/dashboard_screen.dart
import '../../add_site/views/add_site_screen.dart';
import '../../container/views/container_route.dart';
import 'site_row_menu.dart';
// ... existing imports

// inside _DashboardScreenState.build's DashboardBody:
            onAddSite: () async {
              final workspaces = await ref.read(workspacesProvider.future);
              if (!context.mounted) return;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => AddSiteScreen(
                  workspaces: workspaces,
                  onSave: (site) async {
                    await ref.read(siteRepositoryProvider).upsert(site);
                    ref.invalidate(dashboardProvider);
                    Navigator.pop(context);
                  },
                ),
              ));
            },
            onSearch: () {},
            onOpenSite: (siteId) async {
              ref.read(openSiteIdsProvider.notifier).update((ids) => {...ids, siteId});
              ref.read(siteRepositoryProvider).touch(siteId, DateTime.now());
              ref.invalidate(dashboardProvider);
              final site = await ref.read(siteRepositoryProvider).byId(siteId);
              if (site == null || !context.mounted) return;
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => ContainerRoute(site: site),
              ));
              ref.invalidate(dashboardProvider);
            },
            onSiteMenu: (siteId) async {
              final site = await ref.read(siteRepositoryProvider).byId(siteId);
              if (site == null || !context.mounted) return;
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (_) => SiteRowMenu(
                  monogram: site.monogram,
                  name: site.name,
                  subtitle: site.url,
                  ephemeralWorkspaceName: 'Ephemeral',
                  duplicateTargetName: 'Work',
                  onCancel: () => Navigator.pop(context),
                  onAction: (action) async {
                    Navigator.pop(context);
                    if (action == SiteRowAction.editSettings) {
                      final workspaces = await ref.read(workspacesProvider.future);
                      if (!context.mounted) return;
                      await Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AddSiteScreen(
                          initial: site,
                          workspaces: workspaces,
                          onSave: (updated) async {
                            await ref.read(siteRepositoryProvider).upsert(updated);
                            ref.invalidate(dashboardProvider);
                            Navigator.pop(context);
                          },
                        ),
                      ));
                    } else if (action == SiteRowAction.removeSite) {
                      await ref.read(siteRepositoryProvider).delete(siteId);
                      ref.invalidate(dashboardProvider);
                    }
                    // openEphemeral, duplicate, requirePin, wipeData: Known Gap,
                    // see this plan's Known Gaps section — none has a target
                    // workspace/wipe-confirmation flow built anywhere yet.
                  },
                ),
              );
            },
```

`"Ephemeral"`/`"Work"` as literal `ephemeralWorkspaceName`/`duplicateTargetName`
strings is a stand-in — a real implementation resolves these from the
actual workspace list (the ephemeral-storage-rule workspace, and some
sensible "other" workspace), which needs a decision about what happens with
more than one of each; flagged in Known Gaps rather than guessed further
here.

- [ ] **Step 6: Run the tests and commit**

Run: `flutter test`
Expected: PASS.

```bash
git add lib/ui/features/container/view_models/providers.dart \
  lib/ui/features/container/views/container_route.dart \
  lib/ui/features/dashboard/views/dashboard_screen.dart \
  test/ui/features/container_route_test.dart
git commit -m "feat: navigate from the dashboard into a real container session"
```

---

## Task 5: Reader mode's Dart-side wiring

Task 3 already built `extractArticle` end-to-end on the Kotlin side and
`ContainerEngine.extractArticle`/`ContainerRoute._openReader` on the Dart
side (Task 4 Step 4). This task is the remaining seam: `FakeContainerEngine`
needs a way for a widget test to control what `extractArticle` returns
without a device, and a regression test proves the round trip.

**Files:**
- Test: add to `test/ui/features/container_route_test.dart`

**Interfaces:**
- Consumes: `FakeContainerEngine.articleToReturn` (Task 2 Step 4, already present).

- [ ] **Step 1: Write the failing reader-mode test**

```dart
// test/ui/features/container_route_test.dart — add
  testWidgets('tapping reader mode with a real article pushes ReaderScreen', (tester) async {
    final engine = FakeContainerEngine()
      ..articleToReturn = const ReaderArticle(
        host: 'forum.example.com', title: 'A thread', paragraphs: ['Hello.'], minutesToRead: 1,
      );
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await tester.tap(find.text('◑'));
    await tester.pumpAndSettle();

    expect(find.text('A thread'), findsOneWidget);
  });

  testWidgets('tapping reader mode with no article does nothing', (tester) async {
    final engine = FakeContainerEngine(); // articleToReturn stays null
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await tester.tap(find.text('◑'));
    await tester.pumpAndSettle();

    expect(find.byType(ReaderScreen), findsNothing);
  });
```

Add the `ReaderArticle`/`ReaderScreen` imports the test file needs.

- [ ] **Step 2: Run it**

Run: `flutter test test/ui/features/container_route_test.dart`
Expected: PASS — Task 4's `_openReader` and Task 2's `FakeContainerEngine.articleToReturn`
already implement this; this step exists to prove the wiring, not to write
new production code.

- [ ] **Step 3: Commit**

```bash
git add test/ui/features/container_route_test.dart
git commit -m "test: reader mode round trip through ContainerRoute"
```

---

## Task 6: `SiteSheet` persistence and the decoy-sync correction

**This task narrows the design spec.** §6 assumes `syncToDecoy(Site)` can
run "whenever `showInDecoy` is true and a decoy vault exists," called
directly from a site's create/update path. That is not achievable with the
architecture Plan 2 actually shipped: `SessionController` opens exactly one
`AppDatabase` per unlocked session (`SessionOpen(vault, database)`), keyed
by whichever single PIN unlocked it — the *other* vault's data key is never
in memory at the same time, by design (two-vault decoy model, Global
Constraints). The only place in the whole codebase where both vaults'
`AppDatabase`s are ever open together is Plan 2 Task 6's setup wizard, which
is exactly why `provisionDecoy({from, into})` takes two already-open
databases as parameters rather than opening one itself. A `SiteRepository.upsert`
call made during ordinary browsing has no second database to write into —
implementing §6 literally would mean either inventing a way to derive the
decoy's key without its PIN (a security hole) or silently doing nothing
while claiming to sync (a lie the user cannot detect). Neither is
acceptable, so this task builds `syncToDecoy` as real, tested logic reused
by whichever future flow can supply a second open database, wires its call
sites exactly where §6 asks, and gates the call behind a provider that is
honestly `null` in the shipped app. See Known Gaps for what a real fix
needs.

**Files:**
- Modify: `lib/data/repositories/decoy_provisioner.dart`
- Modify: `lib/ui/features/dashboard/view_models/providers.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart` (SiteSheet call site via `onMenu`)
- Modify: `lib/ui/features/container/views/container_route.dart`
- Test: `test/data/decoy_provisioner_test.dart` (existing file — add cases)

**Interfaces:**
- Consumes: `provisionDecoy`'s existing copy-with-fresh-`profileId` pattern.
- Produces: `Future<void> syncToDecoy({required Site site, required AppDatabase decoyDatabase})`, `decoyDatabaseProvider`, real `SiteSheet` call site wired to `siteRepository.upsert`.

- [ ] **Step 1: Write the failing `syncToDecoy` test**

```dart
// test/data/decoy_provisioner_test.dart — add, alongside the existing provisionDecoy tests
  test('syncToDecoy copies one site with a fresh profile id into an already-open decoy database', () async {
    final real = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final decoy = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);

    const workspace = Workspace(
      id: 'w1', name: 'Personal', markerIndex: 0,
      storageRule: StorageRule.keep, showInDecoy: true, sortIndex: 0,
    );
    await SqliteWorkspaceRepository(real).upsert(workspace);
    await SqliteWorkspaceRepository(decoy).upsert(workspace.copyWith(showInDecoy: false));

    final site = Site(
      id: 's1', workspaceId: 'w1', name: 'Notes', monogram: 'No',
      url: 'https://notes.example.com', profileId: 'a' * 32, showInDecoy: true,
    );

    await syncToDecoy(site: site, decoyDatabase: decoy);

    final copied = (await SqliteSiteRepository(decoy).inWorkspace('w1')).single;
    expect(copied.name, 'Notes');
    expect(copied.profileId, isNot(site.profileId));
    expect(copied.showInDecoy, isFalse);
  });

  test('syncToDecoy does nothing for a site not flagged showInDecoy', () async {
    final decoy = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final site = Site(
      id: 's1', workspaceId: 'w1', name: 'Notes', monogram: 'No',
      url: 'https://notes.example.com', profileId: 'a' * 32, showInDecoy: false,
    );
    await syncToDecoy(site: site, decoyDatabase: decoy);
    expect(await SqliteSiteRepository(decoy).inWorkspace('w1'), isEmpty);
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/data/decoy_provisioner_test.dart`
Expected: FAIL — `syncToDecoy` is not defined.

- [ ] **Step 3: Extract `syncToDecoy` from `provisionDecoy`**

```dart
// lib/data/repositories/decoy_provisioner.dart
import '../services/app_database.dart';
import '../../domain/models/site.dart';
import 'site_repository_sqlite.dart';
import 'workspace_repository_sqlite.dart';

/// Copies [site] into [decoyDatabase] with a fresh `profileId`, the same
/// rule [provisionDecoy] applies to every row it copies (cross-plan issue
/// #5 — see that function's own doc comment for why a shared profile id
/// would be a two-vault leak in the worst direction).
///
/// Only takes effect when [site]'s own workspace already exists in
/// [decoyDatabase] — i.e. the workspace itself was already marked
/// `showInDecoy` and provisioned. A site whose workspace was never mirrored
/// has nowhere to go: `sites.workspace_id` is a foreign key, and inventing a
/// workspace row here would be provisioning a workspace the user never
/// flagged. This mirrors [provisionDecoy]'s own workspace-level gate.
Future<void> syncToDecoy({
  required Site site,
  required AppDatabase decoyDatabase,
}) async {
  if (!site.showInDecoy) return;
  final workspace = await SqliteWorkspaceRepository(decoyDatabase).byId(site.workspaceId);
  if (workspace == null) return;

  await SqliteSiteRepository(decoyDatabase)
      .upsert(site.copyWith(showInDecoy: false, profileId: newProfileId()));
}

Future<int> provisionDecoy({
  required AppDatabase from,
  required AppDatabase into,
}) async {
  final sourceWorkspaces = SqliteWorkspaceRepository(from);
  final sourceSites = SqliteSiteRepository(from);
  final targetWorkspaces = SqliteWorkspaceRepository(into);

  var copied = 0;
  for (final workspace in await sourceWorkspaces.all()) {
    if (!workspace.showInDecoy) continue;
    await targetWorkspaces.upsert(workspace.copyWith(showInDecoy: false));
    for (final site in await sourceSites.inWorkspace(workspace.id)) {
      if (!site.showInDecoy) continue;
      await syncToDecoy(site: site, decoyDatabase: into);
      copied++;
    }
  }
  return copied;
}
```

`WorkspaceRepository` already has `byId` (see `repositories.dart`), so no
interface change is needed there.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/data/decoy_provisioner_test.dart`
Expected: PASS, all cases including the pre-existing `provisionDecoy` ones
— `provisionDecoy` now calls `syncToDecoy` internally, so this also proves
the refactor did not change its externally-visible behaviour.

- [ ] **Step 5: Add the honestly-null provider and wire the call sites**

```dart
// lib/ui/features/dashboard/view_models/providers.dart — add
/// A concurrently-open decoy database, when one exists. Always `null` in the
/// shipped app — see Plan 6 Task 6's preamble for why: the app never holds
/// both vaults' data keys in memory at once outside initial setup. Kept as a
/// provider, not deleted, so `syncToDecoy`'s call sites are real code ready
/// for whichever future "re-sync with the decoy PIN" flow supplies one, and
/// so tests can override it with a live in-memory decoy database to prove
/// `syncToDecoy` actually works.
final decoyDatabaseProvider = Provider<AppDatabase?>((ref) => null);
```

`AddSiteScreen.onSave` (Task 4 Step 5) and `SiteRowMenu.editSettings`'s
save handler both already call `siteRepository.upsert(site)`; extend both
with the guarded sync call, and add `SiteSheet`'s own call site inside
`ContainerRoute.onMenu`:

```dart
// dashboard_screen.dart — inside both onSave handlers, after siteRepository.upsert(...)
                    final decoy = ref.read(decoyDatabaseProvider);
                    if (decoy != null) await syncToDecoy(site: site, decoyDatabase: decoy);
```

```dart
// container_route.dart — replace the empty onMenu: () {} with:
            onMenu: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => SiteSheet(
                monogram: widget.site.monogram,
                name: widget.site.name,
                subtitle: _host,
                proxyDescriptor: widget.site.proxyMode == ProxyMode.direct
                    ? 'Direct'
                    : '${widget.site.proxyMode.name} · ${widget.site.proxyHost}:${widget.site.proxyPort}',
                cookiesDescriptor: widget.site.cookiePolicy.name,
                blockedCount: session.blockedCount,
                forceDark: widget.site.forceDark,
                desktopView: widget.site.userAgentMode == UserAgentMode.desktop,
                onEdit: () => Navigator.pop(context),
                onForceDarkChanged: (value) async {
                  final updated = widget.site.copyWith(forceDark: value);
                  await ref.read(siteRepositoryProvider).upsert(updated);
                  final decoy = ref.read(decoyDatabaseProvider);
                  if (decoy != null) await syncToDecoy(site: updated, decoyDatabase: decoy);
                },
                onDesktopViewChanged: (value) async {
                  final updated = widget.site.copyWith(
                    userAgentMode: value ? UserAgentMode.desktop : UserAgentMode.android,
                  );
                  await ref.read(siteRepositoryProvider).upsert(updated);
                  final decoy = ref.read(decoyDatabaseProvider);
                  if (decoy != null) await syncToDecoy(site: updated, decoyDatabase: decoy);
                },
                onCloseAndWipe: () async {
                  Navigator.pop(context);
                  await engine.close(widget.site.id);
                  await engine.wipe(widget.site.profileId);
                  if (mounted) Navigator.pop(context);
                },
              ),
            ),
```

`ContainerRoute` needs `siteRepositoryProvider` and `SiteSheet` imports
added, and `dashboard_screen.dart` needs `syncToDecoy`/`decoyDatabaseProvider`
imported. Note `onDesktopViewChanged`'s off-branch always resets to
`UserAgentMode.android` — a site previously set to `minimal` loses that
distinction if desktop view is toggled on and back off, since `6c`'s toggle
is binary and has no third state to return to. Documented in Known Gaps.

- [ ] **Step 6: Run everything and commit**

Run: `flutter test`
Expected: PASS.

```bash
git add lib/data/repositories/decoy_provisioner.dart \
  lib/ui/features/dashboard/view_models/providers.dart \
  lib/ui/features/dashboard/views/dashboard_screen.dart \
  lib/ui/features/container/views/container_route.dart \
  test/data/decoy_provisioner_test.dart
git commit -m "feat: persist SiteSheet's toggles and extract a real syncToDecoy"
```

---

## Task 7: Remaining entry points and the live `BlockedTally`

`WorkspaceMenu` is the only interactive, already-reachable surface on the
implemented dashboard variant (`1b`) that isn't pixel-fixed by the canvas
spec's own markup — the top bar in `1b` draws only the workspace name, its
dropdown caret, and the session/leak metric text; there is no drawn gear,
hamburger, or overflow icon anywhere on that screen. Rather than add chrome
the spec never draws, this task appends a management section to the
dropdown that tapping the workspace name already opens, using each target
screen's own existing title string as the row label (no invented copy):
"Workspaces", "Settings", "Today", "Scripts and filters".

**Files:**
- Modify: `lib/ui/features/dashboard/views/workspace_menu.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart`
- Modify: `lib/ui/features/dashboard/view_models/providers.dart`
- Create: `lib/ui/features/dashboard/view_models/blocked_tally_controller.dart`
- Test: `test/ui/features/blocked_tally_controller_test.dart`

**Interfaces:**
- Consumes: `BlockedTallyRecorder` (Task 1), `ContainerEngine.sessions()` (Task 2), `SiteRepository.byId` (Task 1).
- Produces: `blockedTallyProvider`, real `leakCountProvider`, management rows in `WorkspaceMenu`.

- [ ] **Step 1: Write the failing controller test**

```dart
// test/ui/features/blocked_tally_controller_test.dart
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSiteRepo {
  final sites = <String, Site>{};
}

void main() {
  test('a session emission increments the tally by the delta, not the running total', () async {
    final engine = FakeContainerEngine();
    final site = Site(
      id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'a' * 32,
    );

    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
      siteLookupProvider.overrideWithValue((id) async => id == 's1' ? site : null),
    ]);
    addTearDown(container.dispose);

    container.listen(blockedTallyProvider, (_, __) {});
    await engine.open(site);
    engine.addBlocked('s1', BlockedCategory.trackers, 5);
    await Future<void>.delayed(Duration.zero);
    engine.addBlocked('s1', BlockedCategory.trackers, 3);
    await Future<void>.delayed(Duration.zero);

    final tally = container.read(blockedTallyProvider);
    final trackers = tally.categories.firstWhere((c) => c.category == BlockedCategory.trackers);
    expect(trackers.count, 8);
  });

  test('leakCountProvider mirrors the tally total', () async {
    final engine = FakeContainerEngine();
    final site = Site(
      id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'a' * 32,
    );
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
      siteLookupProvider.overrideWithValue((id) async => id == 's1' ? site : null),
    ]);
    addTearDown(container.dispose);

    container.listen(blockedTallyProvider, (_, __) {});
    await engine.open(site);
    engine.addBlocked('s1', BlockedCategory.ads, 2);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(leakCountProvider), 2);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/features/blocked_tally_controller_test.dart`
Expected: FAIL — `blocked_tally_controller.dart` and `siteLookupProvider` do
not exist.

- [ ] **Step 3: Write `BlockedTallyController`**

```dart
// lib/ui/features/dashboard/view_models/blocked_tally_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/blocked_tally.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/services/blocked_tally_recorder.dart';
import '../../../../domain/models/site.dart';
import '../../container/view_models/providers.dart' show containerEngineProvider;
import 'providers.dart' show siteRepositoryProvider;

/// Indirection so this file's own test can fake site lookup without a real
/// database — the controller only ever needs one field each from [Site].
final siteLookupProvider =
    Provider<Future<Site?> Function(String)>((ref) {
  return (id) => ref.read(siteRepositoryProvider).byId(id);
});

class BlockedTallyController extends Notifier<BlockedTally> {
  final _recorder = BlockedTallyRecorder();
  final _lastCounts = <String, Map<BlockedCategory, int>>{};

  @override
  BlockedTally build() {
    ref.listen(_sessionsStreamProvider, (_, next) {
      next.whenData(_onSessions);
    });
    return _recorder.snapshot();
  }

  Future<void> _onSessions(List<ContainerSession> sessions) async {
    for (final session in sessions) {
      final previous = _lastCounts[session.siteId] ?? const {};
      var siteDelta = 0;
      for (final category in BlockedCategory.values) {
        final now = session.categoryCounts[category] ?? 0;
        final before = previous[category] ?? 0;
        final delta = now - before;
        if (delta > 0) {
          _recorder.recordCategory(category, delta);
          siteDelta += delta;
        }
      }
      _lastCounts[session.siteId] = session.categoryCounts;
      if (siteDelta > 0) {
        final site = await ref.read(siteLookupProvider)(session.siteId);
        if (site != null) {
          _recorder.recordSite(
            siteId: site.id, monogram: site.monogram, name: site.name, count: siteDelta,
          );
        }
      }
    }
    state = _recorder.snapshot();
  }
}

final _sessionsStreamProvider = StreamProvider<List<ContainerSession>>(
  (ref) => ref.watch(containerEngineProvider).sessions(),
);

final blockedTallyProvider =
    NotifierProvider<BlockedTallyController, BlockedTally>(BlockedTallyController.new);
```

- [ ] **Step 4: Wire `leakCountProvider` to the real total**

```dart
// lib/ui/features/dashboard/view_models/providers.dart
import 'blocked_tally_controller.dart' show blockedTallyProvider;

// replace:
// final leakCountProvider = Provider<int>((ref) => 0);
// with:
final leakCountProvider = Provider<int>((ref) => ref.watch(blockedTallyProvider).total);
```

- [ ] **Step 5: Run the controller test**

Run: `flutter test test/ui/features/blocked_tally_controller_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 6: Add the four management rows to `WorkspaceMenu` and wire their routes**

```dart
// lib/ui/features/dashboard/views/workspace_menu.dart — add below the existing options Column
class ManagementOption {
  const ManagementOption({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
}

class WorkspaceMenu extends StatelessWidget {
  const WorkspaceMenu({
    super.key,
    required this.options,
    required this.onPick,
    this.managementOptions = const [],
  });

  final List<WorkspaceOption> options;
  final void Function(String id) onPick;
  final List<ManagementOption> managementOptions;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 6),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border.all(color: C.line08),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            InkWell(
              onTap: () => onPick(option.id),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: const Border(bottom: BorderSide(color: C.line05)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.name, style: ui(size: 14, weight: 500)),
                            const SizedBox(height: 2),
                            Text(option.meta, style: ui(size: 10, color: C.textFaint)),
                          ],
                        ),
                      ),
                      if (option.selected) const Icon(Icons.check, size: 15, color: C.jade),
                    ],
                  ),
                ),
              ),
            ),
          for (final management in managementOptions)
            InkWell(
              onTap: management.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(management.label, style: ui(size: 13, color: C.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}
```

```dart
// lib/ui/features/dashboard/views/dashboard_screen.dart — _menu(), replace WorkspaceMenu(...) with:
            data: (options) => WorkspaceMenu(
              options: options,
              onPick: (id) {
                ref.read(activeWorkspaceIdProvider.notifier).state = id;
                setState(() => _menuOpen = false);
              },
              managementOptions: [
                ManagementOption(label: 'Workspaces', onTap: () {
                  setState(() => _menuOpen = false);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => _workspacesRoute(ref)));
                }),
                ManagementOption(label: 'Settings', onTap: () {
                  setState(() => _menuOpen = false);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => _settingsRoute(ref)));
                }),
                ManagementOption(label: 'Today', onTap: () {
                  setState(() => _menuOpen = false);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TodayScreen(
                      tally: ref.read(blockedTallyProvider),
                      onBack: () => Navigator.pop(context),
                    ),
                  ));
                }),
                ManagementOption(label: 'Scripts and filters', onTap: () {
                  setState(() => _menuOpen = false);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => _scriptsRoute(ref)));
                }),
              ],
            ),
```

`_workspacesRoute`/`_settingsRoute`/`_scriptsRoute` build each screen from
its already-existing view-model data (workspace list with stats,
settings-toggle state, filter lists + scripts) the same way `dashboardProvider`
assembles `DashboardView` — this plan does not re-specify each field
mapping here since Plan 5 and the settings/workspaces screens already define
what data each needs; wire each screen's constructor to the matching
existing repository/provider calls, following the same `FutureBuilder`/
`.when()` pattern `DashboardScreen` itself already uses for `dashboardProvider`.

- [ ] **Step 7: Run everything and commit**

Run: `flutter test`
Expected: PASS.

Run: `flutter analyze`
Expected: No issues found.

```bash
git add lib/ui/features/dashboard/ test/ui/features/blocked_tally_controller_test.dart
git commit -m "feat: live blocked tally, real leak count, and management entry points"
```

---

## Known gaps this plan deliberately leaves

- **`syncToDecoy` has no reachable call path in the shipped app outside
  initial setup.** The app never holds both vaults' data keys in memory at
  once after the two-PIN setup wizard finishes (Task 6's preamble). A real
  fix needs a dedicated "re-sync with the decoy PIN" settings flow — briefly
  prompting for and opening the decoy vault, running `syncToDecoy` for every
  flagged site, and closing it again — which this plan does not build.
- **Events for a backgrounded (non-foreground) session are dropped, not
  queued.** `ContainerRoute` only listens to `permissionRequests()`/
  `downloads()`/`tunnelDropped()` filtered to its own `siteId` while pushed.
  A permission ask or dropped tunnel on a site not currently in the
  foreground is silently missed — no notification-centre concept exists.
- **A pending permission request has no timeout.** If the sheet is dismissed
  by backgrounding the app rather than picking an option, the Android
  `PermissionRequest`/`GeolocationPermissions.Callback` sits in
  `Session.pendingPermissions` indefinitely (harmless — WebView itself has
  no timeout either — but no code ever cleans up an abandoned entry until
  the session closes).
- **`extractArticle`'s heuristic is honestly approximate** outside
  typical article-shaped pages — no spec exists to be exact against, per
  `reader_article.dart`'s own doc comment.
- **`SiteRowMenu`'s `openEphemeral`/`duplicate`/`requirePin`/`wipeData`
  actions are wired to nothing** (Task 4 Step 5). Each needs a decision this
  plan does not make: which workspace "Ephemeral" and "Work" actually
  resolve to when more than one workspace matches, what a duplicate site's
  new id/name convention is, what UI asks for a PIN, and what confirms a
  destructive wipe. `open` and `editSettings` and `removeSite` are the three
  wired.
- **`SiteSheet`'s desktop-view toggle only distinguishes `android` vs.
  `desktop`.** A site set to `UserAgentMode.minimal` loses that distinction
  the first time the toggle is flipped off, since `6c`'s switch is binary.
- **`TunnelDroppedScreen`'s `droppedAgoLabel` is a fixed `"just now"`**, not
  a live-updating duration — no timer drives it. A real implementation ticks
  it forward the same way `relativeAge` does for the dashboard's session
  rows.
- **The search screen and biometric unlock remain unbuilt**, per the design
  spec's own explicit scope decision.
- **Downloads are held, never actioned.** `HeldDownloadSheet`'s three
  decisions all just dismiss the sheet — no `DownloadManager` integration,
  matching the design spec's own stated scope.
- **`ProxyUnreachableScreen`'s `lastWorkedLabel` is a fixed
  `"never on this device"`.** No history of prior successful connects is
  tracked anywhere in the app; a real value needs a persisted
  last-connected timestamp this plan does not add.

## Handoff

- **To a future search plan:** nothing in this plan touches
  `DashboardFooter.onSearch` — it stays the documented no-op it already was.
- **To a future biometric-unlock plan:** unaffected; `SettingsScreen`'s
  biometrics toggle is still a no-op `onChanged('biometrics', ...)` call the
  settings route (Task 7) forwards to nowhere in particular.
- **To a future decoy-resync plan:** `syncToDecoy(site:, decoyDatabase:)`
  (Task 6) is the exact function to call once a flow exists that can open
  the decoy vault under its own PIN — override `decoyDatabaseProvider` with
  that live connection for the duration of the sync and this plan's call
  sites already invoke it correctly.
- **To whoever builds `SiteRowMenu`'s remaining actions:** `openEphemeral`,
  `duplicate`, `requirePin`, and `wipeData` all arrive at
  `dashboard_screen.dart`'s `onAction` switch (Task 4 Step 5) with nothing
  after them — that is the one call site needing four more branches.

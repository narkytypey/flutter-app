# Isolated Web Container — Plan 7: Search

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `DashboardFooter`'s search button — a no-op since Plan 1 —
to a real screen that finds a `Site` by name or host across every
workspace in the currently open vault, and jumps to it.

**Architecture:** A pure `searchResults()` function joins `Site`s with
`Workspace`s and the existing `openSiteIdsProvider` set, filters by a
query string, and sorts by recency — the same list serves both "recently
visited" (empty query) and "search results" (non-empty query), with no
separate code path for either. A pure `SearchScreen` widget renders
whatever that function returns, following this codebase's established
split between "dumb" views (no Riverpod import) and a small connected
wrapper that owns the Riverpod plumbing and the `TextEditingController`'s
lifecycle. `DashboardScreen`'s existing inline "open a site" logic is
extracted into one shared top-level function so the dashboard and the new
search screen can never disagree about what "opening a site" means.

**Tech Stack:** Everything already in the project — `flutter_riverpod`,
`sqflite_sqlcipher`. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-04-search-screen-design.md` —
approved by the user 2026-09-04, and itself standing in for the
authoritative screen spec, since `Sandbox Container -canvas-.dc.html` has
no dedicated search screen block, only a design-tool hint string ("search
across workspaces"). Read it alongside this plan for the full rationale;
this plan implements it exactly, with one addition the spec's self-review
already caught (`SearchResultEntry.workspaceId`, needed by the tap
handler) and two naming/mechanical refinements: Task 2's join/filter/sort
function is named `searchResults()`, not the spec's suggested
`filterSites()`, since it does more than filter (it also joins against
`Workspace` and sorts); and Task 5's connected wrapper is a
`ConsumerStatefulWidget`, not a stateless `Consumer`, because a
`TextEditingController` needs a stable owner with a `dispose()`.

## Global Constraints

Root `CLAUDE.md`'s global constraints apply in full; the ones this plan
actually touches:

- **Android only, dark theme only.** Nothing here adds a second theme.
- **No network requests of the app's own.** Search reads only the local
  SQLite vault database already open for the session — nothing here
  fetches anything.
- **Two-vault decoy model, not a filter.** `SiteRepository.all()` (Task 1)
  returns rows from whichever vault's `AppDatabase` connection it was
  constructed against — the exact same per-session `siteRepositoryProvider`
  every other screen already reads through `databaseProvider`. Nothing in
  this plan opens a second connection, accepts a vault parameter, or
  aggregates across vaults.
- **Hairline dividers, not cards.** Result rows are 1px-line-separated,
  matching `SessionRow`'s own `Border(bottom: BorderSide(color: C.line05))`.
- **Jade `#7FC8A9` is the single affirmative action per screen.** This
  screen adds no new jade action. The search field's focus-ring reuses the
  jade-tinted border spec `10b` already establishes for text entry
  generally — decorative on focus, not an action, same as every other
  text field already built (`BasicsTab`'s address/name fields).

---

## File Structure

```
lib/domain/repositories/
  repositories.dart                  MODIFY: SiteRepository.all()

lib/data/repositories/
  site_repository_sqlite.dart        MODIFY: implement all()

lib/ui/features/search/view_models/
  search_view.dart                   CREATE: SearchResultEntry, searchResults()
  providers.dart                     CREATE: allSitesProvider, searchQueryProvider, searchResultsProvider

lib/ui/features/search/views/
  search_screen.dart                 CREATE: SearchScreen, _SearchField, _SearchResultRow

lib/ui/features/dashboard/view_models/
  providers.dart                     MODIFY: openSite() extracted and exported

lib/ui/features/dashboard/views/
  dashboard_screen.dart              MODIFY: onSearch wiring, onOpenSite uses openSite(), _SearchRoute

test/data/
  repositories_test.dart             MODIFY: all() test

test/ui/features/search/
  search_view_test.dart              CREATE
  search_providers_test.dart         CREATE
  search_screen_test.dart            CREATE
```

---

## Task 1: `SiteRepository.all()`

The one repository change everything else depends on: a way to read every
site in the open vault regardless of workspace, mirroring
`WorkspaceRepository.all()`'s existing shape.

**Files:**
- Modify: `lib/domain/repositories/repositories.dart`
- Modify: `lib/data/repositories/site_repository_sqlite.dart`
- Test: `test/data/repositories_test.dart`

**Interfaces:**
- Consumes: `Site` (Plan 1), `AppDatabase` (Plan 1).
- Produces: `SiteRepository.all(): Future<List<Site>>`.

> **Note if Plan 6 has already merged when you start this task:** Plan 6
> Task 1 also edits `SiteRepository` in this same file, adding `byId`. If
> both changes are present, add `all()` alongside `byId` in one interface
> block rather than reverting to a version of the interface that only has
> one of the two.

- [ ] **Step 1: Write the failing test**

Add to the bottom of `test/data/repositories_test.dart`, inside the
existing `main()` (it already has `setUp`/`tearDown` opening an in-memory
database — reuse that, don't add a new `main()`):

```dart
  test('all returns every site across every workspace', () async {
    final workspaces = SqliteWorkspaceRepository(database);
    final sites = SqliteSiteRepository(database);

    await workspaces.upsert(const Workspace(
        id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep));
    await workspaces.upsert(const Workspace(
        id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep));
    await sites.upsert(Site(
        id: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: newProfileId()));
    await sites.upsert(Site(
        id: 's2', workspaceId: 'w2', name: 'Bank', monogram: 'Bk',
        url: 'https://bank.example.com', profileId: newProfileId()));

    final all = await sites.all();

    expect(all.map((s) => s.id).toSet(), {'s1', 's2'});
  });
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/data/repositories_test.dart`
Expected: FAIL — `SiteRepository` has no method `all`.

- [ ] **Step 3: Add the method to the interface**

```dart
// lib/domain/repositories/repositories.dart
abstract interface class SiteRepository {
  Future<List<Site>> inWorkspace(String workspaceId);
  Future<List<Site>> all();
  Future<void> upsert(Site site);
  Future<void> delete(String id);
  Future<void> touch(String id, DateTime at);
}
```

- [ ] **Step 4: Implement it**

```dart
// lib/data/repositories/site_repository_sqlite.dart, alongside inWorkspace
  @override
  Future<List<Site>> all() async {
    final rows = await _database.db.query('sites', orderBy: 'sort_index');
    return rows.map(siteFromRow).toList();
  }
```

- [ ] **Step 5: Run the test and the whole suite**

Run: `flutter test test/data/repositories_test.dart`
Expected: PASS.

Run: `flutter test`
Expected: PASS — `SiteRepository` is only implemented by
`SqliteSiteRepository` today, so no other class needs a new override.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/repositories/repositories.dart \
  lib/data/repositories/site_repository_sqlite.dart \
  test/data/repositories_test.dart
git commit -m "feat: SiteRepository.all(), reads every site in the open vault"
```

---

## Task 2: `SearchResultEntry` and the `searchResults()` join/filter/sort

Pure Dart, no Flutter/Riverpod import — the whole matching and ranking
logic lives here so it has its own direct tests, independent of provider
plumbing or widgets. Named `searchResults()` rather than the design spec's
suggested `filterSites()`, since it joins against `Workspace` and sorts by
recency in addition to filtering.

**Files:**
- Create: `lib/ui/features/search/view_models/search_view.dart`
- Test: `test/ui/features/search/search_view_test.dart`

**Interfaces:**
- Consumes: `Site` (`id`, `workspaceId`, `name`, `monogram`, `host`
  getter, `lastVisitedAt`), `Workspace` (`id`, `name`, `markerIndex`).
- Produces: `SearchResultEntry` (`siteId`, `workspaceId`, `name`,
  `monogram`, `host`, `live`, `workspaceName`, `markerIndex`);
  `searchResults({required sites, required workspaces, required
  openSiteIds, required query}): List<SearchResultEntry>`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/features/search/search_view_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/search/view_models/search_view.dart';

void main() {
  const personal = Workspace(
      id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);
  const work = Workspace(
      id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep);

  Site site({
    required String id,
    required String workspaceId,
    required String name,
    String url = 'https://example.com',
    DateTime? lastVisitedAt,
  }) {
    return Site(
      id: id,
      workspaceId: workspaceId,
      name: name,
      monogram: name.substring(0, 2),
      url: url,
      profileId: 'p-$id',
      lastVisitedAt: lastVisitedAt,
    );
  }

  test('an empty query returns every site, most recently visited first', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum', lastVisitedAt: DateTime.utc(2026, 1, 1));
    final b = site(id: 's2', workspaceId: 'w2', name: 'Notes', lastVisitedAt: DateTime.utc(2026, 6, 1));
    final c = site(id: 's3', workspaceId: 'w1', name: 'Bank');

    final results = searchResults(
        sites: [a, b, c], workspaces: [personal, work], openSiteIds: {}, query: '');

    expect(results.map((r) => r.siteId), ['s2', 's1', 's3']);
  });

  test('matches by name, case-insensitively', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum');
    final b = site(id: 's2', workspaceId: 'w1', name: 'Notes');

    final results = searchResults(
        sites: [a, b], workspaces: [personal], openSiteIds: {}, query: 'FOR');

    expect(results.map((r) => r.siteId), ['s1']);
  });

  test('matches by host, case-insensitively', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum', url: 'https://Forum.Example.com');

    final results = searchResults(
        sites: [a], workspaces: [personal], openSiteIds: {}, query: 'forum.example');

    expect(results.map((r) => r.siteId), ['s1']);
  });

  test('a query matching nothing returns an empty list', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum');

    final results = searchResults(
        sites: [a], workspaces: [personal], openSiteIds: {}, query: 'zzz');

    expect(results, isEmpty);
  });

  test('carries the id, name and marker of the site\'s own workspace', () {
    final a = site(id: 's1', workspaceId: 'w2', name: 'Ticket board');

    final results = searchResults(
        sites: [a], workspaces: [personal, work], openSiteIds: {}, query: '');

    expect(results.single.workspaceId, 'w2');
    expect(results.single.workspaceName, 'Work');
    expect(results.single.markerIndex, 1);
  });

  test('a site is live only when its id is in openSiteIds', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum');
    final b = site(id: 's2', workspaceId: 'w1', name: 'Notes');

    final results = searchResults(
        sites: [a, b], workspaces: [personal], openSiteIds: {'s2'}, query: '');

    expect(results.firstWhere((r) => r.siteId == 's1').live, isFalse);
    expect(results.firstWhere((r) => r.siteId == 's2').live, isTrue);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/features/search/search_view_test.dart`
Expected: FAIL — `search_view.dart` does not exist.

- [ ] **Step 3: Write `SearchResultEntry` and `searchResults()`**

```dart
// lib/ui/features/search/view_models/search_view.dart
import '../../../../domain/models/site.dart';
import '../../../../domain/models/workspace.dart';

class SearchResultEntry {
  const SearchResultEntry({
    required this.siteId,
    required this.workspaceId,
    required this.name,
    required this.monogram,
    required this.host,
    required this.live,
    required this.workspaceName,
    required this.markerIndex,
  });

  final String siteId;

  /// Needed to switch `activeWorkspaceIdProvider` when a result is opened —
  /// see `dashboard_screen.dart`'s `_SearchRoute`. Not shown in the UI;
  /// [workspaceName] is.
  final String workspaceId;

  final String name;
  final String monogram;
  final String host;
  final bool live;
  final String workspaceName;
  final int markerIndex;
}

/// Sites matching [query] by name or host, across every workspace in
/// [workspaces] — the whole point of this screen ("search across
/// workspaces"). An empty [query] matches everything, sorted by
/// [Site.lastVisitedAt] descending with never-visited sites last — this
/// doubles as the "recently visited" empty state with no separate code
/// path.
List<SearchResultEntry> searchResults({
  required List<Site> sites,
  required List<Workspace> workspaces,
  required Set<String> openSiteIds,
  required String query,
}) {
  final workspacesById = {for (final w in workspaces) w.id: w};
  final q = query.trim().toLowerCase();

  final matches = sites.where((site) {
    if (q.isEmpty) return true;
    return site.name.toLowerCase().contains(q) ||
        site.host.toLowerCase().contains(q);
  }).toList()
    ..sort((a, b) {
      final at = a.lastVisitedAt;
      final bt = b.lastVisitedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });

  final entries = <SearchResultEntry>[];
  for (final site in matches) {
    final workspace = workspacesById[site.workspaceId];
    if (workspace == null) continue;
    entries.add(SearchResultEntry(
      siteId: site.id,
      workspaceId: site.workspaceId,
      name: site.name,
      monogram: site.monogram,
      host: site.host,
      live: openSiteIds.contains(site.id),
      workspaceName: workspace.name,
      markerIndex: workspace.markerIndex,
    ));
  }
  return entries;
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ui/features/search/search_view_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/search/view_models/search_view.dart \
  test/ui/features/search/search_view_test.dart
git commit -m "feat: SearchResultEntry and the search join/filter/sort"
```

---

## Task 3: Search providers

Thin Riverpod glue over Task 2's pure function — resolves the two
`FutureProvider`s it needs and re-runs the join whenever the query or the
open-site set changes.

**Files:**
- Create: `lib/ui/features/search/view_models/providers.dart`
- Test: `test/ui/features/search/search_providers_test.dart`

**Interfaces:**
- Consumes: `siteRepositoryProvider`, `workspacesProvider`,
  `openSiteIdsProvider` (all Plan 1/5, in
  `lib/ui/features/dashboard/view_models/providers.dart`), `searchResults`
  (Task 2).
- Produces: `allSitesProvider: FutureProvider<List<Site>>`,
  `searchQueryProvider: StateProvider<String>`,
  `searchResultsProvider: Provider<AsyncValue<List<SearchResultEntry>>>`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/features/search/search_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show siteRepositoryProvider, workspacesProvider, openSiteIdsProvider;
import 'package:container/ui/features/search/view_models/providers.dart';

/// A minimal fake covering only what the search providers call.
class FakeSiteRepository implements SiteRepository {
  FakeSiteRepository(this.sites);
  final List<Site> sites;
  final touched = <String, DateTime>{};

  @override
  Future<List<Site>> all() async => sites;
  @override
  Future<List<Site>> inWorkspace(String workspaceId) => throw UnimplementedError();
  @override
  Future<void> upsert(Site site) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<void> touch(String id, DateTime at) async => touched[id] = at;
}

void main() {
  const workspace = Workspace(
      id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

  test('joins sites, workspaces and open ids into results', () async {
    final site = Site(
        id: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p1');

    final container = ProviderContainer(overrides: [
      siteRepositoryProvider.overrideWithValue(FakeSiteRepository([site])),
      workspacesProvider.overrideWith((ref) async => [workspace]),
    ]);
    addTearDown(container.dispose);
    container.read(openSiteIdsProvider.notifier).state = {'s1'};

    container.listen(searchResultsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    final result = container.read(searchResultsProvider);
    expect(result.value!.single.name, 'Forum');
    expect(result.value!.single.workspaceName, 'Personal');
    expect(result.value!.single.live, isTrue);
  });

  test('changing searchQueryProvider narrows the results', () async {
    final forum = Site(
        id: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p1');
    final bank = Site(
        id: 's2', workspaceId: 'w1', name: 'Bank', monogram: 'Bk',
        url: 'https://bank.example.com', profileId: 'p2');

    final container = ProviderContainer(overrides: [
      siteRepositoryProvider.overrideWithValue(FakeSiteRepository([forum, bank])),
      workspacesProvider.overrideWith((ref) async => [workspace]),
    ]);
    addTearDown(container.dispose);

    container.listen(searchResultsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    container.read(searchQueryProvider.notifier).state = 'ban';

    final result = container.read(searchResultsProvider);
    expect(result.value!.map((r) => r.name), ['Bank']);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/features/search/search_providers_test.dart`
Expected: FAIL — `lib/ui/features/search/view_models/providers.dart` does
not exist.

- [ ] **Step 3: Write the providers**

```dart
// lib/ui/features/search/view_models/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/site.dart';
import '../../dashboard/view_models/providers.dart'
    show siteRepositoryProvider, workspacesProvider, openSiteIdsProvider;
import 'search_view.dart';

final allSitesProvider = FutureProvider<List<Site>>(
  (ref) => ref.watch(siteRepositoryProvider).all(),
);

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = Provider<AsyncValue<List<SearchResultEntry>>>((ref) {
  final sitesAsync = ref.watch(allSitesProvider);
  final workspacesAsync = ref.watch(workspacesProvider);
  final query = ref.watch(searchQueryProvider);
  final openIds = ref.watch(openSiteIdsProvider);

  return sitesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (sites) => workspacesAsync.when(
      loading: () => const AsyncValue.loading(),
      error: AsyncValue.error,
      data: (workspaces) => AsyncValue.data(searchResults(
        sites: sites,
        workspaces: workspaces,
        openSiteIds: openIds,
        query: query,
      )),
    ),
  );
});
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ui/features/search/search_providers_test.dart`
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/search/view_models/providers.dart \
  test/ui/features/search/search_providers_test.dart
git commit -m "feat: search providers joining sites, workspaces and open ids"
```

---

## Task 4: The `SearchScreen` widget

Pure widget — no Riverpod import, matching `WorkspacesScreen`'s split
between view and connected wrapper. The `TextEditingController` is owned
by the caller (Task 5), not constructed here, for the same reason
`BasicsTab`'s address/name fields take their controllers as constructor
parameters: a widget that built its own `TextEditingController` inline
would recreate it — and lose cursor position and focus — on every parent
rebuild.

**Files:**
- Create: `lib/ui/features/search/views/search_screen.dart`
- Test: `test/ui/features/search/search_screen_test.dart`

**Interfaces:**
- Consumes: `SearchResultEntry` (Task 2), `C` (`lib/ui/core/tokens.dart`),
  `T`/`ui()` (`lib/ui/core/typography.dart`), `Monogram`, `StatusRail`
  (`lib/ui/core/widgets/`).
- Produces: `SearchScreen({controller, results, onQueryChanged, onOpen,
  onBack})`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/features/search/search_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/search/view_models/search_view.dart';
import 'package:container/ui/features/search/views/search_screen.dart';

void main() {
  const forum = SearchResultEntry(
    siteId: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
    host: 'forum.example.com', live: false, workspaceName: 'Personal', markerIndex: 0,
  );
  const bank = SearchResultEntry(
    siteId: 's2', workspaceId: 'w2', name: 'Bank', monogram: 'Bk',
    host: 'bank.example.com', live: true, workspaceName: 'Work', markerIndex: 1,
  );

  Widget host({
    String query = '',
    List<SearchResultEntry> results = const [forum, bank],
    ValueChanged<String>? onQueryChanged,
    void Function(String)? onOpen,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      home: SearchScreen(
        controller: TextEditingController(text: query),
        results: results,
        onQueryChanged: onQueryChanged ?? (_) {},
        onOpen: onOpen ?? (_) {},
        onBack: onBack ?? () {},
      ),
    );
  }

  testWidgets('renders every result: name, host and its workspace', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('bank.example.com'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('typing reports the new text', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(host(onQueryChanged: changes.add));

    await tester.enterText(find.byKey(const Key('search-field')), 'ban');

    expect(changes, ['ban']);
  });

  testWidgets('tapping a row reports its site id', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(host(onOpen: opened.add));

    await tester.tap(find.text('Bank'));

    expect(opened, ['s2']);
  });

  testWidgets('tapping back calls onBack', (tester) async {
    var backTaps = 0;
    await tester.pumpWidget(host(onBack: () => backTaps++));

    await tester.tap(find.text('‹'));

    expect(backTaps, 1);
  });

  testWidgets('a non-empty query with no results shows the no-match message', (tester) async {
    await tester.pumpWidget(host(query: 'zzz', results: const []));

    expect(find.text('No sites match "zzz"'), findsOneWidget);
    expect(find.text('Forum'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/ui/features/search/search_screen_test.dart`
Expected: FAIL — `search_screen.dart` does not exist.

- [ ] **Step 3: Write `SearchScreen`**

```dart
// lib/ui/features/search/views/search_screen.dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/status_rail.dart';
import '../view_models/search_view.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.results,
    required this.onQueryChanged,
    required this.onOpen,
    required this.onBack,
  });

  final TextEditingController controller;
  final List<SearchResultEntry> results;
  final ValueChanged<String> onQueryChanged;
  final void Function(String siteId) onOpen;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final showNoMatch = results.isEmpty && controller.text.isNotEmpty;

    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Text('‹', style: TextStyle(fontSize: 16, color: C.icon)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: C.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: C.line09),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, size: 18, color: C.icon),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              key: const Key('search-field'),
                              controller: controller,
                              autofocus: true,
                              onChanged: onQueryChanged,
                              style: ui(size: 14, color: C.textSecondary),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                hintText: 'Search sites',
                                hintStyle: ui(size: 14, color: C.textFaint),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: showNoMatch
                  ? Center(
                      child: Text('No sites match "${controller.text}"',
                          style: ui(size: 13, color: C.textDim)),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      children: [
                        for (final entry in results)
                          _SearchResultRow(entry: entry, onTap: () => onOpen(entry.siteId)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.entry, required this.onTap});

  final SearchResultEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line05)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              StatusRail(live: entry.live),
              const SizedBox(width: 12),
              Monogram(entry.monogram, open: entry.live),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.name, style: entry.live ? T.rowTitle : T.rowTitleIdle),
                    const SizedBox(height: 3),
                    Text(
                      entry.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: entry.live ? T.meta : T.metaIdle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: C.markers[entry.markerIndex],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(entry.workspaceName, style: ui(size: 11, color: C.textFaint)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/ui/features/search/search_screen_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/features/search/views/search_screen.dart \
  test/ui/features/search/search_screen_test.dart
git commit -m "feat: add the search screen (spec: search-screen-design)"
```

---

## Task 5: Wire search into the dashboard

Extracts the dashboard's inline "open a site" logic into one shared
function, then wires the footer's search button to a connected
`_SearchRoute` built from Tasks 1–4. No new test file — matching Plan 6
Task 7's own precedent for pure wiring changes in this file, verified
instead by the full existing suite plus a manual smoke check.

**Files:**
- Modify: `lib/ui/features/dashboard/view_models/providers.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart`

**Interfaces:**
- Consumes: `openSiteIdsProvider`, `siteRepositoryProvider`,
  `dashboardProvider`, `activeWorkspaceIdProvider` (all pre-existing in
  `dashboard/view_models/providers.dart`), `searchQueryProvider`,
  `searchResultsProvider` (Task 3), `SearchScreen` (Task 4).
- Produces: `openSite(WidgetRef ref, String siteId): void`, exported from
  `dashboard/view_models/providers.dart` for any future caller.

- [ ] **Step 1: Extract `openSite`**

```dart
// lib/ui/features/dashboard/view_models/providers.dart
// Add near the bottom of the file, after workspaceOptionsProvider.

/// Marks [siteId] open and records the visit. Shared by `DashboardScreen`'s
/// own row tap and the search screen's result tap, so both always agree on
/// what "opening a site" means — today this in-memory badge, later Plan 6's
/// real `ContainerEngine` session, without either caller needing to change.
void openSite(WidgetRef ref, String siteId) {
  ref.read(openSiteIdsProvider.notifier).update((ids) => {...ids, siteId});
  ref.read(siteRepositoryProvider).touch(siteId, DateTime.now());
  ref.invalidate(dashboardProvider);
}
```

- [ ] **Step 2: Wire `dashboard_screen.dart`**

Replace the whole `onOpenSite` callback and the `onSearch: () {}` line:

```dart
// lib/ui/features/dashboard/views/dashboard_screen.dart
// onSearch: () {} becomes:
            onSearch: () {
              ref.invalidate(searchQueryProvider);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const _SearchRoute()));
            },
// onOpenSite's body becomes a one-line delegation:
            onOpenSite: (siteId) => openSite(ref, siteId),
```

Add the two new imports at the top of the file:

```dart
import '../../search/view_models/providers.dart'
    show searchQueryProvider, searchResultsProvider;
import '../../search/views/search_screen.dart';
```

Add `_SearchRoute` as a private widget at the bottom of the file, below
`_DashboardScreenState`:

```dart
class _SearchRoute extends ConsumerStatefulWidget {
  const _SearchRoute();

  @override
  ConsumerState<_SearchRoute> createState() => _SearchRouteState();
}

class _SearchRouteState extends ConsumerState<_SearchRoute> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);

    return SearchScreen(
      controller: _controller,
      results: results.value ?? const [],
      onQueryChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
      onOpen: (siteId) {
        final entries = results.value ?? const [];
        final entry = entries.firstWhere((r) => r.siteId == siteId);
        ref.read(activeWorkspaceIdProvider.notifier).state = entry.workspaceId;
        openSite(ref, siteId);
        Navigator.pop(context);
      },
      onBack: () => Navigator.pop(context),
    );
  }
}
```

`_SearchRoute` owns the `TextEditingController` itself (a
`ConsumerStatefulWidget`, not the stateless `Consumer` the spec sketched)
so it can dispose it — `SearchScreen` never constructs its own controller,
per Task 4's note.

- [ ] **Step 3: Run the whole suite and analyze**

Run: `flutter test`
Expected: PASS — every existing test continues to pass; nothing here
changes the type of any public API `DashboardBody`/`DashboardFooter`
already depend on (`onSearch`/`onOpenSite` keep their existing
`VoidCallback`/`void Function(String)` signatures).

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/ui/features/dashboard/view_models/providers.dart \
  lib/ui/features/dashboard/views/dashboard_screen.dart
git commit -m "feat: wire the dashboard's search button to the search screen"
```

---

## Known gaps this plan deliberately leaves

- **No debouncing.** Filtering is synchronous and in-memory over an
  already-fetched list, cheap enough per keystroke without one.
- **`allSitesProvider` refetches on every push**, not kept warm in the
  background — acceptable given how rarely this screen is expected to
  open and how infrequently sites change.
- **No secondary tiebreaker** beyond `lastVisitedAt` for two sites that
  have never been visited — both simply go last, in whatever order the
  query happens to return them.
- **Workspace names themselves are not searchable** — a workspace is only
  a jump target by way of a site filed inside it, per the spec's explicit
  scope decision. Since `searchResults()` already receives the full
  `workspaces` list, extending this later is a change to that one
  function's filter predicate, not a new subsystem.
- **No highlighting of the matched substring** in a result row.

## Handoff

- **To whoever finishes Plan 6's `ContainerRoute` wiring:** `openSite`
  (Task 5) is now the one place "opening a site" happens for both the
  dashboard and search. When real container opening replaces the
  in-memory `openSiteIdsProvider` badge, change it there — both surfaces
  pick up the new behavior with no further changes.
- **To a future "search workspaces too" plan:** see the known gap above —
  `searchResults()`'s signature does not need to change, only its body.

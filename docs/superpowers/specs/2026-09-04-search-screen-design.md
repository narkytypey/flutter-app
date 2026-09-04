# Search screen — design

**Status:** Approved by the user 2026-09-04.

## Problem

`DashboardFooter`'s search button (`onSearch`) has been wired to a no-op
(`() {}`) since Plan 1. No plan or spec screen ever covered it. The only
trace of search anywhere in the authoritative spec
(`Sandbox Container -canvas-.dc.html`) is a design-tool suggestion string —
*"Try next: 'search across workspaces'"* — not an actual `id="..."` screen
block. That phrase is the entire brief: the dashboard only ever shows the
*active* workspace's sites, so there is no way today to find a site filed
under a different workspace without switching workspaces one at a time and
scanning each list.

This spec designs that screen from scratch. Per `CLAUDE.md`'s rule that an
unspecified string is "a design question to ask about, not to invent," this
document — reviewed and approved by the user — stands in for the missing
spec block; the implementation plan should treat it as authoritative for
this feature the same way it would treat a numbered spec id.

## Scope

**In scope:** a screen that searches `Site`s (name and host) across every
workspace in the currently open vault, and jumps the user to a match.

**Out of scope:**
- Matching workspace names themselves (a workspace is a jump target only by
  way of the sites inside it).
- Any browsing-history/URL search. The domain model has no history beyond
  `Site.lastVisitedAt`, and the app's no-tracking design constraint means
  none should be added for this.
- Cross-vault search. Search only ever reads the vault database already
  open for the current session — the same connection every other screen
  uses. Nothing here queries or even knows whether a decoy vault exists.
- Fuzzy matching, ranking, or highlighting matched substrings. Plain
  case-insensitive substring matching is enough for what is expected to be,
  at most, a few dozen sites.

## Data layer

Add one method to the existing repository interface
(`lib/domain/repositories/repositories.dart`):

```dart
abstract interface class SiteRepository {
  Future<List<Site>> inWorkspace(String workspaceId);
  Future<List<Site>> all();   // NEW
  Future<void> upsert(Site site);
  Future<void> delete(String id);
  Future<void> touch(String id, DateTime at);
}
```

`all()` returns every site in the vault this repository was opened
against, with no workspace filter — mirroring `WorkspaceRepository.all()`,
which already has this exact shape. The SQLite implementation
(`lib/data/repositories/site_repository_sqlite.dart`) adds the matching
unfiltered `SELECT * FROM sites`. This is the only schema-adjacent change;
no migration is needed since no column changes.

(Note for whoever implements this: Plan 6 Task 1 separately adds
`SiteRepository.byId`. If both land close together, add `all()` alongside
`byId` in the same interface edit rather than treating one as a conflict
with the other.)

## View-model layer

New file `lib/ui/features/search/view_models/search_view.dart` (naming
matches `dashboard_view.dart`'s precedent — the pure data class the view
consumes):

```dart
class SearchResultEntry {
  const SearchResultEntry({
    required this.siteId,
    required this.name,
    required this.monogram,
    required this.host,
    required this.live,
    required this.workspaceName,
    required this.markerIndex,
  });

  final String siteId;
  final String name;
  final String monogram;
  final String host;
  final bool live;
  final String workspaceName;
  final int markerIndex;
}
```

New file `lib/ui/features/search/view_models/providers.dart`:

- `allSitesProvider` — `FutureProvider<List<Site>>` calling
  `siteRepository.all()`.
- `searchQueryProvider` — `StateProvider<String>`. `DashboardScreen`'s
  `onSearch` callback calls `ref.invalidate(searchQueryProvider)`
  immediately before `Navigator.push`, so leaving and reopening search
  never shows a stale query.
- `searchResultsProvider` — `Provider<AsyncValue<List<SearchResultEntry>>>`.
  Joins `allSitesProvider`'s sites with `workspacesProvider`'s raw
  `Workspace` list (for `workspaceName`/`markerIndex` — note this is the
  plain `List<Workspace>` provider, not `workspaceOptionsProvider`, whose
  `WorkspaceOption` view-model has no `markerIndex` field) and
  `openSiteIdsProvider` (for `live`), filters by `searchQueryProvider`'s
  value — case-insensitive
  substring match against `name` **or** `host` — and sorts by
  `lastVisitedAt` descending (nulls last). An empty query is not a special
  case in this provider: it filters everything in, so the unfiltered,
  recency-sorted list *is* the empty-state list — "recently visited" and
  "no query yet" are the same code path.

The filter/sort itself should be a small top-level pure function (e.g.
`List<SearchResultEntry> filterSites(List<SearchResultEntry> all, String query)`)
so it has its own plain Dart test independent of the provider plumbing.

## View widget

New file `lib/ui/features/search/views/search_screen.dart`. Pure widget —
no Riverpod import, matching every other screen's split between a "dumb"
view and a connected call site (see `WorkspacesScreen`,
`WorkspaceFormScreen`, etc.):

```dart
class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    required this.query,
    required this.results,
    required this.onQueryChanged,
    required this.onOpen,
    required this.onBack,
  });

  final String query;
  final List<SearchResultEntry> results;
  final ValueChanged<String> onQueryChanged;
  final void Function(String siteId) onOpen;
  final VoidCallback onBack;
}
```

**Header** (padding `18,14,18,12`, bottom border `C.line06`, matching
`WorkspacesScreen`'s header exactly): `‹` back chevron (→ `onBack`), then a
46px-tall search field filling the remaining width — reusing the input
style already established for text entry in this design system (spec
`10b`'s name field: `C.surface` background, `BorderRadius.circular(12)`,
`C.line09` border idle, jade-tinted `rgba(127,200,169,.35)` border on
focus), with a leading `Icons.search` (size 18, `C.icon`) and placeholder
`Search sites`. Autofocused on push.

**Body:** `ListView` of `_SearchResultRow` — same visual skeleton as
`SessionRow` (`StatusRail(live:)`, `Monogram`, name as `T.rowTitle`/
`T.rowTitleIdle`, host as `T.meta`/`T.metaIdle`) but the trailing element
is a small marker-dot (`8x8`, `BorderRadius.circular(2)`,
`C.markers[markerIndex]`, same shape `WorkspacesScreen` already uses) plus
`workspaceName` in `ui(size: 11, color: C.textFaint)`, instead of
`SessionRow`'s trailing age string — the workspace is the piece of
information this screen exists to surface, age is not.

**No-match state:** when `query` is non-empty and `results` is empty,
centered text `No sites match "$query"` in `ui(size: 13, color: C.textDim)`,
replacing the `ListView`.

## Navigation and wiring

`lib/ui/features/dashboard/views/dashboard_footer.dart` is unchanged — it
already exposes `onSearch`. In `dashboard_screen.dart`, replace
`onSearch: () {}` with a push to a small connected wrapper, following the
same pattern Plan 6 Task 7 establishes for `_workspacesRoute`/
`_settingsRoute`/`_scriptsRoute`:

```dart
onSearch: () {
  ref.invalidate(searchQueryProvider);
  Navigator.push(context, MaterialPageRoute(builder: (_) => _searchRoute(ref)));
},
```

`_searchRoute(ref)` returns a `Consumer` (or small `ConsumerWidget`) that
watches `searchResultsProvider` and constructs `SearchScreen` with:

- `onQueryChanged: (value) => ref.read(searchQueryProvider.notifier).state = value`
- `onOpen: (siteId) => _openSiteAcrossWorkspaces(ref, siteId)`
- `onBack: () => Navigator.pop(context)`

`_openSiteAcrossWorkspaces` is a new small top-level helper in
`lib/ui/features/dashboard/view_models/providers.dart`, extracted from the
three lines `dashboard_screen.dart`'s own `onOpenSite` already runs
(`openSiteIdsProvider` update, `siteRepository.touch`, `invalidate
(dashboardProvider)`), plus one line new to this feature: switching
`activeWorkspaceIdProvider` to the tapped site's workspace first. Both
`DashboardScreen.onOpenSite` and the search route's `onOpen` call this one
helper, so a future change to what "opening a site" means (Plan 6's real
`ContainerRoute`, eventually) only has one call site to update — search
never needs to know how opening works, only that it should do whatever
opening already does. After calling the helper, the search route pops
back to the dashboard, which is now showing the newly active workspace
with the tapped site marked open, exactly as if the user had switched
workspace and tapped it manually.

## Testing

- `test/ui/features/search/search_screen_test.dart` — pure widget test
  (no Riverpod), matching `workspaces_screen_test.dart`'s style: renders
  the given `results`, typing calls `onQueryChanged`, tapping a row calls
  `onOpen` with the right `siteId`, empty `results` with a non-empty
  `query` shows the no-match text.
- `test/ui/features/search/filter_sites_test.dart` — plain Dart test for
  the extracted `filterSites` function: case-insensitive name match,
  case-insensitive host match, empty query returns everything unfiltered
  in recency order, no match returns an empty list.
- `test/data/site_repository_sqlite_test.dart` (extend existing file) —
  `all()` returns sites from every workspace, not just one.

## Known gaps this design accepts

- **No debouncing.** Filtering is a synchronous, in-memory operation over
  an already-fetched list (expected to be, at most, a few dozen sites), so
  every keystroke recomputing `searchResultsProvider` is cheap enough not
  to need one.
- **Reopens the entire site list every time the screen is pushed.**
  `allSitesProvider` is a plain `FutureProvider`, refetched fresh each push
  rather than kept warm in the background — acceptable given how
  infrequently sites change and how rarely this screen is expected to be
  opened.
- **No "recent workspaces" or other secondary sort break for ties** beyond
  `lastVisitedAt` — two sites that have literally never been visited
  (`lastVisitedAt == null`) fall back to whatever stable order the query
  returns them in, undefined beyond "both go last."

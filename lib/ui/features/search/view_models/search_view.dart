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

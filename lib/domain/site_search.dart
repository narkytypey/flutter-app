import 'models/site.dart';

/// What a typed text matches: [query], trimmed and case-insensitive, found in
/// a site's name or host. An empty query matches every site. Most recently visited
/// first, never-visited last. Shared by the container's address bar and
/// the dashboard's search field (`suggestionsFor`), so the two never disagree
/// about what matches.
List<Site> sitesMatching(List<Site> sites, String query) {
  final q = query.trim().toLowerCase();
  return sites.where((site) {
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
}

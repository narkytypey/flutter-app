import '../../../../domain/models/relative_age.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/site_descriptor.dart';
import '../../../../domain/models/workspace.dart';

/// One row on the dashboard, already reduced to strings. The widget layer does
/// no formatting of its own.
class SessionEntry {
  const SessionEntry({
    required this.siteId,
    required this.name,
    required this.monogram,
    required this.meta,
    required this.age,
    required this.live,
  });

  final String siteId;
  final String name;
  final String monogram;

  /// `forum.example.com · ephemeral`
  final String meta;

  /// `now`, `14m`, `2h`, `3d`
  final String age;
  final bool live;
}

class DashboardView {
  const DashboardView({
    required this.workspaceId,
    required this.wipesOnExit,
    required this.rows,
  });

  /// A vault with no workspaces: no chip is viewed.
  static const empty = DashboardView(workspaceId: null, wipesOnExit: false, rows: []);

  /// The viewed workspace (dashboard spec §4.2): its chip is drawn selected,
  /// and a new site or a typed address's throwaway goes into it. Null only
  /// for a vault with no workspaces.
  final String? workspaceId;

  /// True for a workspace whose storage rule is wipe-on-exit: the chip row
  /// shows `WIPES ON EXIT` (spec `5b`, plan D3).
  final bool wipesOnExit;

  /// Spec §4.3, rulings 5 and 6: one list, no titles. Open sites first, then
  /// the rest, each most recently visited first and never-visited last.
  final List<SessionEntry> rows;

  bool get isEmpty => rows.isEmpty;

  /// Which sites are live is runtime state, not stored state: containers do
  /// not survive the app closing, so [openSiteIds] comes from the registry
  /// rather than from the database. A throwaway is never a row (it is not a
  /// site). `N OPEN`, `2c` and the swipe reach it (spec §11).
  static DashboardView from({
    required Workspace workspace,
    required List<Site> sites,
    required Set<String> openSiteIds,
    required DateTime now,
  }) {
    // Ties keep the vault's order: `List.sort` is not stable.
    final position = {for (var i = 0; i < sites.length; i++) sites[i].id: i};
    final ordered = [...sites]
      ..sort((a, b) {
        final aOpen = openSiteIds.contains(a.id);
        final bOpen = openSiteIds.contains(b.id);
        if (aOpen != bOpen) return aOpen ? -1 : 1;
        final byRecency = _byRecency(a, b);
        return byRecency != 0 ? byRecency : position[a.id]!.compareTo(position[b.id]!);
      });

    return DashboardView(
      workspaceId: workspace.id,
      wipesOnExit: workspace.storageRule == StorageRule.wipeOnExit,
      rows: [
        for (final site in ordered)
          SessionEntry(
            siteId: site.id,
            name: site.name,
            monogram: site.monogram,
            meta: '${site.host} · ${siteDescriptor(site)}',
            age: relativeAge(now, site.lastVisitedAt),
            live: openSiteIds.contains(site.id),
          ),
      ],
    );
  }
}

/// Most recently visited first; never visited last.
int _byRecency(Site a, Site b) {
  final at = a.lastVisitedAt;
  final bt = b.lastVisitedAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}

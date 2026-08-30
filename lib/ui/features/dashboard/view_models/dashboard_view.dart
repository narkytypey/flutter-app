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
    required this.workspaceName,
    required this.wipesOnExit,
    required this.sessionCount,
    required this.leakCount,
    required this.open,
    required this.idle,
  });

  final String workspaceName;

  /// True for a workspace whose storage rule is wipe-on-exit; the bar shows
  /// `WIPES ON EXIT` instead of the session counts (spec `5b`).
  final bool wipesOnExit;
  final int sessionCount;
  final int leakCount;
  final List<SessionEntry> open;
  final List<SessionEntry> idle;

  bool get isEmpty => open.isEmpty && idle.isEmpty;

  /// Which sites are live is runtime state, not stored state: sessions do not
  /// survive the app closing, so [openSiteIds] comes from a provider rather
  /// than from the database.
  static DashboardView from({
    required Workspace workspace,
    required List<Site> sites,
    required Set<String> openSiteIds,
    required int leakCount,
    required DateTime now,
  }) {
    SessionEntry entry(Site s, bool live) => SessionEntry(
          siteId: s.id,
          name: s.name,
          monogram: s.monogram,
          meta: '${s.host} · ${siteDescriptor(s)}',
          age: relativeAge(now, s.lastVisitedAt),
          live: live,
        );

    final open = <SessionEntry>[];
    final idle = <SessionEntry>[];
    for (final site in sites) {
      final live = openSiteIds.contains(site.id);
      (live ? open : idle).add(entry(site, live));
    }

    return DashboardView(
      workspaceName: workspace.name,
      wipesOnExit: workspace.storageRule == StorageRule.wipeOnExit,
      sessionCount: open.length,
      leakCount: leakCount,
      open: open,
      idle: idle,
    );
  }
}

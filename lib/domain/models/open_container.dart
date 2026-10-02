import 'blocked_tally.dart' show BlockedCategory;
import 'container_session.dart' show SessionPhase;
import 'engine_events.dart';
import 'open_page.dart';
import 'permissions.dart' show PermissionKind;
import 'route_decision.dart' show RouteFailure;
import 'site.dart';

/// `8b`'s refusal: why the open was refused, and when the site last worked.
class Refusal {
  const Refusal({required this.failure, this.lastWorked});
  final RouteFailure failure;
  final DateTime? lastWorked;
}

/// A permission ask or held download waiting for its page to be viewed
/// (tabs spec §5.6). The platform holds the request with no timeout.
sealed class WaitingAsk {
  const WaitingAsk(this.pageId);
  final String pageId;
}

class WaitingPermission extends WaitingAsk {
  const WaitingPermission(super.pageId, this.request);
  final PendingPermissionRequest request;
}

class WaitingDownload extends WaitingAsk {
  const WaitingDownload(super.pageId, this.event);
  final HeldDownloadEvent event;
}

const _keep = Object();

/// One open container, as the registry holds it (tabs spec §4.1). Runtime
/// only: nothing here is ever written to disk.
class OpenContainer {
  const OpenContainer({
    required this.site,
    required this.opened,
    required this.lastViewedAt,
    this.throwaway = false,
    this.withoutTunnel = false,
    this.openerSiteId,
    this.initialUrl,
    this.pages = const [],
    this.viewOrder = const [],
    this.openReturned = false,
    this.phase = SessionPhase.opening,
    this.blockedCount = 0,
    this.categoryCounts = const {},
    this.grants = const {},
    this.refusal,
    this.workedAt,
    this.workedRecorded = false,
    this.tunnelDropped = false,
    this.loadedOnce = false,
    this.saveBarDismissed = false,
    this.waiting = const [],
  });

  /// The site as last saved from this container — the site sheet's (`6c`)
  /// record, moved on by every change made there.
  final Site site;

  /// The settings the session runs under: [site] at open, or what `8b`
  /// reopened it with. The chrome describes this.
  final Site opened;

  /// When it was last on screen: set when it is shown and when it stops
  /// being shown. `2c`'s "background · <age>" counts from here.
  final DateTime lastViewedAt;
  final bool throwaway;

  /// `8b`'s "Open without the tunnel": this visit only, direct.
  final bool withoutTunnel;

  /// A throwaway's opener container (tabs spec §5.3).
  final String? openerSiteId;

  /// The typed address of the first load, this session only.
  final String? initialUrl;

  /// In opening order, as the platform reports them.
  final List<OpenPage> pages;

  /// Page ids, most recently viewed first. Its head is the last viewed page.
  final List<String> viewOrder;

  /// Whether this container's own `open` has returned. Until then no page
  /// view is built (Plan 12's `_openReturned` rule).
  final bool openReturned;
  final SessionPhase phase;
  final int blockedCount;

  /// `6c`'s per-category rows (privacy-controls spec §3).
  final Map<BlockedCategory, int> categoryCounts;

  /// This session's "allow while open" grants, for `6c`.
  final Set<PermissionKind> grants;
  final Refusal? refusal;
  final DateTime? workedAt;
  final bool workedRecorded;

  /// `8c` waiting to be shown (tabs spec §5.6).
  final bool tunnelDropped;

  /// A throwaway's save bar waits for any page's first finished load.
  final bool loadedOnce;
  final bool saveBarDismissed;
  final List<WaitingAsk> waiting;

  String get siteId => site.id;

  /// The last viewed page, or null before the first page exists.
  String? get viewedPageId {
    for (final id in viewOrder) {
      if (pages.any((page) => page.pageId == id)) return id;
    }
    return pages.isEmpty ? null : pages.first.pageId;
  }

  OpenPage? page(String pageId) {
    for (final page in pages) {
      if (page.pageId == pageId) return page;
    }
    return null;
  }

  /// Counted and listed: everything but a saved site whose open was refused,
  /// which counts nowhere, as today (tabs plan, Deviation 2).
  bool get listed => throwaway || refusal == null;

  OpenContainer copyWith({
    Site? site,
    Site? opened,
    DateTime? lastViewedAt,
    bool? throwaway,
    bool? withoutTunnel,
    Object? initialUrl = _keep,
    List<OpenPage>? pages,
    List<String>? viewOrder,
    bool? openReturned,
    SessionPhase? phase,
    int? blockedCount,
    Map<BlockedCategory, int>? categoryCounts,
    Set<PermissionKind>? grants,
    Object? refusal = _keep,
    Object? workedAt = _keep,
    bool? workedRecorded,
    bool? tunnelDropped,
    bool? loadedOnce,
    bool? saveBarDismissed,
    List<WaitingAsk>? waiting,
  }) =>
      OpenContainer(
        site: site ?? this.site,
        opened: opened ?? this.opened,
        lastViewedAt: lastViewedAt ?? this.lastViewedAt,
        throwaway: throwaway ?? this.throwaway,
        withoutTunnel: withoutTunnel ?? this.withoutTunnel,
        openerSiteId: openerSiteId,
        initialUrl: identical(initialUrl, _keep) ? this.initialUrl : initialUrl as String?,
        pages: pages ?? this.pages,
        viewOrder: viewOrder ?? this.viewOrder,
        openReturned: openReturned ?? this.openReturned,
        phase: phase ?? this.phase,
        blockedCount: blockedCount ?? this.blockedCount,
        categoryCounts: categoryCounts ?? this.categoryCounts,
        grants: grants ?? this.grants,
        refusal: identical(refusal, _keep) ? this.refusal : refusal as Refusal?,
        workedAt: identical(workedAt, _keep) ? this.workedAt : workedAt as DateTime?,
        workedRecorded: workedRecorded ?? this.workedRecorded,
        tunnelDropped: tunnelDropped ?? this.tunnelDropped,
        loadedOnce: loadedOnce ?? this.loadedOnce,
        saveBarDismissed: saveBarDismissed ?? this.saveBarDismissed,
        waiting: waiting ?? this.waiting,
      );
}

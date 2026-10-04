import 'dart:async';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/engine_extras.dart';
import '../../domain/models/find_result.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
import '../../domain/models/navigation_state.dart';
import '../../domain/models/open_page.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/route_decision.dart';
import '../../domain/models/site.dart';
import 'container_engine.dart';

/// Drives every widget test in this plan. Deterministic: no timers, no delays.
class FakeContainerEngine implements ContainerEngine {
  FakeContainerEngine({
    this.isolation = true,
    this.proxyReachable = true,
    this.opensLive = true,
  });

  bool isolation;
  bool proxyReachable;

  /// Whether [open] reports a routable session as already `live`. The real
  /// engine never does: it reports `opening`, and only the native view's
  /// first finished load moves it to `live` (see [markLive]). Pass `false` to
  /// test anything that depends on that handoff.
  bool opensLive;

  final _sessions = <String, ContainerSession>{};
  final _controller = StreamController<List<ContainerSession>>.broadcast();
  final wiped = <String>[];
  final closed = <String>[];

  /// The `wipe` argument of each site's latest [close], by site id: null for
  /// a close that left it to the session's own wipe-on-exit.
  final closedWith = <String, bool?>{};

  /// Every page id passed to [closePage], in order.
  final closedPages = <String>[];

  /// How many times [closeAll] was called.
  int closedAll = 0;

  /// How many pages each site has been given, across every open: a page id
  /// is `'<siteId>-p<n>'` and is never reused.
  final _pageCounts = <String, int>{};

  /// The extras each site was last opened with, by site id.
  final openedExtras = <String, EngineExtras>{};

  /// Every site passed to [open], by id; the latest open wins.
  final openedSites = <String, Site>{};

  /// The typed address each site was last opened at, or null for a plain open.
  final openedInitialUrls = <String, String?>{};

  /// The ids of the sites opened as throwaways.
  final openedAsThrowaway = <String>{};

  // The in-page controls, each recording the page ids it was called with.
  final reloaded = <String>[];
  final wentBack = <String>[];
  final wentForward = <String>[];
  final stopped = <String>[];
  final loaded = <({String pageId, String url})>[];
  final findQueries = <({String pageId, String query})>[];
  final findSteps = <({String pageId, bool forward})>[];
  final clearedFind = <String>[];
  final kept = <String>[];

  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _downloadResultController = StreamController<DownloadResult>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();
  final _torProgressController = StreamController<int>.broadcast();
  final _navigationController = StreamController<NavigationState>.broadcast();
  final _findController = StreamController<FindResult>.broadcast();
  final _pageOpenedController = StreamController<PageOpened>.broadcast();

  /// The last navigation state of each page, by page id.
  final _navigation = <String, NavigationState>{};
  final resolvedPermissions = <String, PermissionDecision>{};
  final resolvedDownloads = <({String requestId, DownloadDecision decision})>[];
  ReaderArticle? articleToReturn;

  void _emit() => _controller.add(_sessions.values.toList());

  String _newPageId(String siteId) {
    final n = (_pageCounts[siteId] ?? 0) + 1;
    _pageCounts[siteId] = n;
    return '$siteId-p$n';
  }

  /// The site whose container holds [pageId], or null.
  String? _siteOfPage(String pageId) {
    for (final session in _sessions.values) {
      if (session.pages.any((page) => page.pageId == pageId)) return session.siteId;
    }
    return null;
  }

  @override
  Future<bool> isolationAvailable() async => isolation;

  @override
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
    String? initialUrl,
  }) async {
    openedExtras[site.id] = extras;
    openedSites[site.id] = site;
    openedInitialUrls[site.id] = initialUrl;
    if (throwaway) openedAsThrowaway.add(site.id);
    final decision = resolveRoute(site, proxyReachable: proxyReachable);
    final refused = decision is RouteRefused;
    final session = ContainerSession(
      siteId: site.id,
      phase: refused
          ? SessionPhase.refused
          : (opensLive ? SessionPhase.live : SessionPhase.opening),
      lastActiveAt: DateTime(2026, 8, 30, 12),
      failure: decision is RouteRefused ? decision.failure : null,
      // A refused open has no page; a routable one starts with one.
      pages: refused ? const [] : [OpenPage(pageId: _newPageId(site.id))],
    );
    _sessions[site.id] = session;
    _emit();
    return session;
  }

  @override
  Future<void> wipe(String profileId) async => wiped.add(profileId);

  bool wipedAll = false;

  @override
  Future<void> wipeAll() async {
    wipedAll = true;
    _sessions.clear();
    _emit();
  }

  @override
  Future<void> close(String siteId, {bool? wipe}) async {
    closed.add(siteId);
    closedWith[siteId] = wipe;
    _sessions.remove(siteId);
    _emit();
  }

  @override
  Future<void> closePage(String pageId) async {
    closedPages.add(pageId);
    final siteId = _siteOfPage(pageId);
    if (siteId == null) return;
    final session = _sessions[siteId]!;
    if (session.pages.length <= 1) {
      await close(siteId);
      return;
    }
    _sessions[siteId] = session.copyWith(
      pages: [for (final page in session.pages) if (page.pageId != pageId) page],
    );
    _emit();
  }

  @override
  Future<void> closeAll() async {
    closedAll++;
    for (final siteId in _sessions.keys.toList()) {
      await close(siteId);
    }
  }

  @override
  Stream<PageOpened> pageOpened() => _pageOpenedController.stream;

  @override
  Stream<List<ContainerSession>> sessions() => _controller.stream;

  @override
  Future<List<ContainerSession>> liveSessions() async =>
      _sessions.values.toList();

  @override
  Future<void> reload(String pageId) async => reloaded.add(pageId);

  @override
  Stream<PendingPermissionRequest> permissionRequests() => _permissionController.stream;

  @override
  Future<void> resolvePermission(String requestId, PermissionDecision decision) async {
    resolvedPermissions[requestId] = decision;
  }

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;
  @override
  Future<void> resolveDownload(String requestId, DownloadDecision decision) async {
    resolvedDownloads.add((requestId: requestId, decision: decision));
  }
  @override
  Stream<DownloadResult> downloadResults() => _downloadResultController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  @override
  Future<ReaderArticle?> extractArticle(String pageId) async => articleToReturn;

  @override
  Stream<NavigationState> navigation() => _navigationController.stream;

  @override
  Future<NavigationState?> navigationState(String pageId) async => _navigation[pageId];

  @override
  Stream<FindResult> findResults() => _findController.stream;

  @override
  Future<void> goBack(String pageId) async => wentBack.add(pageId);

  @override
  Future<void> goForward(String pageId) async => wentForward.add(pageId);

  @override
  Future<void> stop(String pageId) async => stopped.add(pageId);

  @override
  Future<void> loadUrl(String pageId, String url) async =>
      loaded.add((pageId: pageId, url: url));

  @override
  Future<void> find(String pageId, String query) async =>
      findQueries.add((pageId: pageId, query: query));

  @override
  Future<void> findNext(String pageId, {required bool forward}) async =>
      findSteps.add((pageId: pageId, forward: forward));

  @override
  Future<void> clearFind(String pageId) async => clearedFind.add(pageId);

  @override
  Future<void> keep(String siteId) async => kept.add(siteId);

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

  /// Test helpers: push one event of each new kind.
  void emitPermissionRequest(PendingPermissionRequest request) =>
      _permissionController.add(request);
  void emitDownload(HeldDownloadEvent event) => _downloadController.add(event);
  void emitDownloadResult(DownloadResult result) => _downloadResultController.add(result);
  /// Reports Tor's percentage, as the platform does while Tor starts.
  void emitTorProgress(int percent) => _torProgressController.add(percent);

  @override
  Stream<int> torProgress() => _torProgressController.stream;

  void emitTunnelDropped(TunnelDroppedEvent event) => _tunnelDroppedController.add(event);

  /// Test helper: what a native page does on every change — the event, and
  /// the per-page snapshot `navigationState` returns.
  void emitNavigation(NavigationState state) {
    _navigation[state.pageId] = state;
    _navigationController.add(state);
  }

  /// Test helper: the snapshot only — a change reported before anyone
  /// listened.
  void seedNavigation(NavigationState state) => _navigation[state.pageId] = state;

  /// Test helper: what a native page does when a link the user tapped asks
  /// for a new window (tabs spec §5.2) — a new page in [siteId]'s container,
  /// reported as [PageOpened] and then in the sessions list. Returns its id.
  String openPageFromLink(String siteId, {required String openerPageId}) {
    final session = _sessions[siteId];
    if (session == null) throw StateError('no session for $siteId');
    final pageId = _newPageId(siteId);
    _sessions[siteId] = session.copyWith(pages: [
      ...session.pages,
      OpenPage(pageId: pageId, openerPageId: openerPageId),
    ]);
    _pageOpenedController.add(
        PageOpened(siteId: siteId, pageId: pageId, openerPageId: openerPageId));
    _emit();
    return pageId;
  }

  /// [siteId]'s open pages, in opening order; empty with no session.
  List<OpenPage> pagesOf(String siteId) => _sessions[siteId]?.pages ?? const [];

  /// The id of [siteId]'s first open page.
  String firstPageOf(String siteId) => pagesOf(siteId).first.pageId;

  void emitFindResult(FindResult result) => _findController.add(result);

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
      blockedCount: counts.values.fold<int>(0, (a, b) => a + b),
    );
    _emit();
  }

  /// Test helper: what a native page does when its container's first load
  /// finishes — `EngineChannel.markLive` moves an `opening` session to `live`.
  void markLive(String siteId) {
    final current = _sessions[siteId];
    if (current == null || current.phase == SessionPhase.refused) return;
    _sessions[siteId] = current.copyWith(phase: SessionPhase.live);
    _emit();
  }

  /// Test helper: put a session into the background without opening a page
  /// view. It has one page, like any open container.
  void seedBackground(String siteId, {int blockedCount = 0}) {
    _sessions[siteId] = ContainerSession(
      siteId: siteId,
      phase: SessionPhase.background,
      lastActiveAt: DateTime(2026, 8, 30, 11, 58),
      blockedCount: blockedCount,
      pages: [OpenPage(pageId: _newPageId(siteId))],
    );
    _emit();
  }

  void dispose() {
    _controller.close();
    _permissionController.close();
    _downloadController.close();
    _downloadResultController.close();
    _tunnelDroppedController.close();
    _torProgressController.close();
    _navigationController.close();
    _findController.close();
    _pageOpenedController.close();
  }
}

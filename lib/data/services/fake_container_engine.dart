import 'dart:async';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/engine_extras.dart';
import '../../domain/models/find_result.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
import '../../domain/models/navigation_state.dart';
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

  /// The extras each site was last opened with, by site id.
  final openedExtras = <String, EngineExtras>{};

  /// Every site passed to [open], by id; the latest open wins.
  final openedSites = <String, Site>{};

  /// The typed address each site was last opened at, or null for a plain open.
  final openedInitialUrls = <String, String?>{};

  /// The ids of the sites opened as throwaways.
  final openedAsThrowaway = <String>{};

  final wentBack = <String>[];
  final wentForward = <String>[];
  final stopped = <String>[];
  final loaded = <({String siteId, String url})>[];
  final findQueries = <({String siteId, String query})>[];
  final findSteps = <({String siteId, bool forward})>[];
  final clearedFind = <String>[];
  final kept = <String>[];

  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _downloadResultController = StreamController<DownloadResult>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();
  final _navigationController = StreamController<NavigationState>.broadcast();
  final _findController = StreamController<FindResult>.broadcast();
  final _navigation = <String, NavigationState>{};
  final resolvedPermissions = <String, PermissionDecision>{};
  final resolvedDownloads = <({String requestId, DownloadDecision decision})>[];
  ReaderArticle? articleToReturn;

  void _emit() => _controller.add(_sessions.values.toList());

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
    final session = ContainerSession(
      siteId: site.id,
      phase: decision is RouteRefused
          ? SessionPhase.refused
          : (opensLive ? SessionPhase.live : SessionPhase.opening),
      lastActiveAt: DateTime(2026, 8, 30, 12),
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
  Future<void> close(String siteId) async {
    closed.add(siteId);
    _sessions.remove(siteId);
    _emit();
  }

  @override
  Stream<List<ContainerSession>> sessions() => _controller.stream;

  @override
  Future<List<ContainerSession>> liveSessions() async =>
      _sessions.values.toList();

  @override
  Future<void> reload(String siteId) async {}

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
  Future<ReaderArticle?> extractArticle(String siteId) async => articleToReturn;

  @override
  Stream<NavigationState> navigation() => _navigationController.stream;

  @override
  Future<NavigationState?> navigationState(String siteId) async => _navigation[siteId];

  @override
  Stream<FindResult> findResults() => _findController.stream;

  @override
  Future<void> goBack(String siteId) async => wentBack.add(siteId);

  @override
  Future<void> goForward(String siteId) async => wentForward.add(siteId);

  @override
  Future<void> stop(String siteId) async => stopped.add(siteId);

  @override
  Future<void> loadUrl(String siteId, String url) async =>
      loaded.add((siteId: siteId, url: url));

  @override
  Future<void> find(String siteId, String query) async =>
      findQueries.add((siteId: siteId, query: query));

  @override
  Future<void> findNext(String siteId, {required bool forward}) async =>
      findSteps.add((siteId: siteId, forward: forward));

  @override
  Future<void> clearFind(String siteId) async => clearedFind.add(siteId);

  @override
  Future<void> keep(String siteId) async => kept.add(siteId);

  /// Test helpers: push one event of each new kind.
  void emitPermissionRequest(PendingPermissionRequest request) =>
      _permissionController.add(request);
  void emitDownload(HeldDownloadEvent event) => _downloadController.add(event);
  void emitDownloadResult(DownloadResult result) => _downloadResultController.add(result);
  void emitTunnelDropped(TunnelDroppedEvent event) => _tunnelDroppedController.add(event);

  /// Test helper: what a native view does on every page change — the event,
  /// and the per-session snapshot `navigationState` returns.
  void emitNavigation(NavigationState state) {
    _navigation[state.siteId] = state;
    _navigationController.add(state);
  }

  /// Test helper: the snapshot only — a change reported before anyone
  /// listened.
  void seedNavigation(NavigationState state) => _navigation[state.siteId] = state;

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

  /// Test helper: what the native `ContainerView` does when its first load
  /// finishes — `EngineChannel.markLive` moves an `opening` session to `live`.
  void markLive(String siteId) {
    final current = _sessions[siteId];
    if (current == null || current.phase == SessionPhase.refused) return;
    _sessions[siteId] = current.copyWith(phase: SessionPhase.live);
    _emit();
  }

  /// Test helper: put a session into the background without opening a page.
  void seedBackground(String siteId, {int blockedCount = 0}) {
    _sessions[siteId] = ContainerSession(
      siteId: siteId,
      phase: SessionPhase.background,
      lastActiveAt: DateTime(2026, 8, 30, 11, 58),
      blockedCount: blockedCount,
    );
    _emit();
  }

  void dispose() {
    _controller.close();
    _permissionController.close();
    _downloadController.close();
    _downloadResultController.close();
    _tunnelDroppedController.close();
    _navigationController.close();
    _findController.close();
  }
}

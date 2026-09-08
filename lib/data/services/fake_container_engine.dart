import 'dart:async';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
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
  });

  bool isolation;
  bool proxyReachable;

  final _sessions = <String, ContainerSession>{};
  final _controller = StreamController<List<ContainerSession>>.broadcast();
  final wiped = <String>[];
  final closed = <String>[];

  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _downloadResultController = StreamController<DownloadResult>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();
  final resolvedPermissions = <String, PermissionDecision>{};
  final resolvedDownloads = <({String requestId, DownloadDecision decision})>[];
  ReaderArticle? articleToReturn;

  void _emit() => _controller.add(_sessions.values.toList());

  @override
  Future<bool> isolationAvailable() async => isolation;

  @override
  Future<ContainerSession> open(Site site) async {
    final decision = resolveRoute(site, proxyReachable: proxyReachable);
    final session = ContainerSession(
      siteId: site.id,
      phase: decision is RouteRefused ? SessionPhase.refused : SessionPhase.live,
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

  /// Test helpers: push one event of each new kind.
  void emitPermissionRequest(PendingPermissionRequest request) =>
      _permissionController.add(request);
  void emitDownload(HeldDownloadEvent event) => _downloadController.add(event);
  void emitDownloadResult(DownloadResult result) => _downloadResultController.add(result);
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
      blockedCount: counts.values.fold<int>(0, (a, b) => a + b),
    );
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
  }
}

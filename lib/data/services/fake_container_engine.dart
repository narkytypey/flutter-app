import 'dart:async';

import '../../domain/models/container_session.dart';
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

  void dispose() => _controller.close();
}

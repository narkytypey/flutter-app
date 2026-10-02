import 'dart:async';
import 'dart:typed_data';

import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/container_session.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/held_download.dart';
import 'package:container/domain/models/navigation_state.dart';
import 'package:container/domain/models/open_container.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/route_decision.dart' show RouteFailure;
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/container/view_models/open_containers.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show siteRepositoryProvider;
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A session stub the test can move in and out of `SessionOpen`.
class _Session extends SessionController {
  _Session(this.initial);
  final Session initial;

  @override
  Session build() => initial;

  void become(Session next) => state = next;
}

/// The fake engine, counting opens, with an optional gate an open waits on.
class _Engine extends FakeContainerEngine {
  _Engine({super.opensLive});

  int opens = 0;
  Completer<void>? gate;

  @override
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
    String? initialUrl,
  }) async {
    opens++;
    final waitFor = gate;
    if (waitFor != null) await waitFor.future;
    return super.open(site, extras: extras, throwaway: throwaway, initialUrl: initialUrl);
  }
}

/// In-memory rows, recording writes.
class _Sites implements SiteRepository {
  final rows = <String, Site>{};
  final upserts = <Site>[];
  final lastWorkedAt = <String, DateTime?>{};
  final setLastWorkedCalls = <({String id, DateTime? at})>[];

  @override
  Future<void> upsert(Site site) async {
    upserts.add(site);
    rows[site.id] = site;
  }

  @override
  Future<DateTime?> lastWorked(String id) async => lastWorkedAt[id];

  @override
  Future<void> setLastWorked(String id, DateTime? at) async {
    setLastWorkedCalls.add((id: id, at: at));
    lastWorkedAt[id] = at;
  }

  @override
  Future<List<Site>> all() async => rows.values.toList();
  @override
  Future<Site?> byId(String id) async => rows[id];
  @override
  Future<void> delete(String id) async => rows.remove(id);
  @override
  Future<List<Site>> inWorkspace(String workspaceId) async =>
      rows.values.where((s) => s.workspaceId == workspaceId).toList();
  @override
  Future<void> touch(String id, DateTime at) async {}
}

class _Clock {
  DateTime now = DateTime(2026, 10, 2, 12);
  void advance(Duration by) => now = now.add(by);
}

Site _site(
  String id, {
  String workspaceId = 'w1',
  ProxyMode proxyMode = ProxyMode.direct,
  String? proxyHost,
  int? proxyPort,
  CookiePolicy cookiePolicy = CookiePolicy.keep,
}) =>
    Site(
      id: id,
      workspaceId: workspaceId,
      name: '$id.example.org',
      monogram: id.substring(0, 2),
      url: 'https://$id.example.org',
      profileId: 'p-$id',
      proxyMode: proxyMode,
      proxyHost: proxyHost,
      proxyPort: proxyPort,
      cookiePolicy: cookiePolicy,
    );

/// A SOCKS5 site with no host: the fake refuses it as misconfigured.
Site _refusedSite(String id, {String workspaceId = 'w1'}) =>
    _site(id, workspaceId: workspaceId, proxyMode: ProxyMode.socks5);

NavigationState _nav(String siteId, String pageId, {bool loading = false}) => NavigationState(
      siteId: siteId,
      pageId: pageId,
      url: 'https://$siteId.example.org/$pageId',
      loading: loading,
    );

PendingPermissionRequest _ask(String siteId, String pageId, String requestId) =>
    PendingPermissionRequest(
      siteId: siteId,
      pageId: pageId,
      host: '$siteId.example.org',
      kind: PermissionKind.camera,
      requestId: requestId,
    );

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Harness {
  _Harness(this.container, this.engine, this.sites, this.clock);
  final ProviderContainer container;
  final _Engine engine;
  final _Sites sites;
  final _Clock clock;

  OpenContainers get registry => container.read(openContainersProvider.notifier);
  OpenContainersState get state => container.read(openContainersProvider);
  _Session get session => container.read(sessionProvider.notifier) as _Session;
}

Future<AppDatabase> _database() async {
  final database =
      await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  addTearDown(database.close);
  return database;
}

SessionOpen _open(AppDatabase database) =>
    SessionOpen(vault: VaultId.a, database: database, dataKey: Uint8List(32));

Future<_Harness> _harness({bool opensLive = true}) async {
  final engine = _Engine(opensLive: opensLive);
  final sites = _Sites();
  final clock = _Clock();
  final database = await _database();
  final container = ProviderContainer(overrides: [
    containerEngineProvider.overrideWithValue(engine),
    engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
    siteRepositoryProvider.overrideWithValue(sites),
    sessionProvider.overrideWith(() => _Session(_open(database))),
    tabsClockProvider.overrideWithValue(() => clock.now),
  ]);
  addTearDown(container.dispose);
  // Built now, so its subscriptions exist before anything is emitted.
  container.read(openContainersProvider);
  return _Harness(container, engine, sites, clock);
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('1. view registers synchronously, then the open\'s page becomes the viewed page',
      () async {
    final h = await _harness();
    h.engine.gate = Completer<void>();
    final opening = h.registry.view(_site('s1'));

    expect(h.state.viewedSiteId, 's1');
    final pending = h.state.byId('s1')!;
    expect(pending.openReturned, isFalse);
    expect(pending.viewedPageId, isNull);

    h.engine.gate!.complete();
    await opening;
    final opened = h.state.viewed!;
    expect(opened.openReturned, isTrue);
    expect(opened.viewedPageId, 's1-p1');
    expect(opened.pages.single.pageId, 's1-p1');
  });

  test('2. view of a listed container shows it without opening it again', () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    h.clock.advance(const Duration(minutes: 1));
    await h.registry.view(_site('s2'));
    h.clock.advance(const Duration(minutes: 5));
    final switchedAt = h.clock.now;

    await h.registry.view(_site('s1'));

    expect(h.engine.opens, 2);
    expect(h.state.viewedSiteId, 's1');
    expect(h.state.byId('s2')!.lastViewedAt, switchedAt);
    expect(h.state.byId('s1')!.viewedPageId, 's1-p1');
  });

  test('3. view with initialUrl of an open container loads it in its last viewed page',
      () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    final link = h.engine.openPageFromLink('s1', openerPageId: 's1-p1');
    await _settle();
    await h.registry.view(_site('s2'));

    await h.registry.view(_site('s1'), initialUrl: 'https://typed.example.net/a');

    expect(h.engine.opens, 2);
    expect(h.engine.loaded.single, (pageId: link, url: 'https://typed.example.net/a'));
  });

  test('4. a link page comes to the front; viewPage moves the first back to the head',
      () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    final link = h.engine.openPageFromLink('s1', openerPageId: 's1-p1');
    await _settle();

    var c = h.state.byId('s1')!;
    expect(c.pages.map((p) => p.pageId), ['s1-p1', link]);
    expect(c.page(link)!.openerPageId, 's1-p1');
    expect(c.viewedPageId, link);

    h.registry.viewPage('s1', 's1-p1');
    c = h.state.byId('s1')!;
    expect(c.viewedPageId, 's1-p1');
    expect(c.viewOrder.first, 's1-p1');
  });

  test('5. closePage of a non-last page closes only it; the most recently viewed remains',
      () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    final p2 = h.engine.openPageFromLink('s1', openerPageId: 's1-p1');
    await _settle();
    final p3 = h.engine.openPageFromLink('s1', openerPageId: p2);
    await _settle();
    h.registry.viewPage('s1', p2);
    // Most recently viewed first: p2, p3, p1.

    await h.registry.closePage('s1', p2);
    await _settle();

    expect(h.engine.closedPages, [p2]);
    expect(h.engine.closed, isEmpty);
    final c = h.state.byId('s1')!;
    expect(c.pages.map((p) => p.pageId), ['s1-p1', p3]);
    expect(c.viewedPageId, p3);
  });

  test('6. closePage of the last page closes the container', () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));

    await h.registry.closePage('s1', 's1-p1');
    await _settle();

    expect(h.engine.closed, ['s1']);
    expect(h.state.byId('s1'), isNull);
    expect(h.state.viewedSiteId, isNull);
  });

  test('7. a session closed elsewhere drops its container', () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    await h.registry.view(_site('s2'));

    // In the background: dropped, and the viewed container stays viewed.
    await h.engine.close('s1');
    await _settle();
    expect(h.state.byId('s1'), isNull);
    expect(h.state.viewedSiteId, 's2');

    // On screen: dropped, and nothing is viewed.
    await h.engine.close('s2');
    await _settle();
    expect(h.state.byId('s2'), isNull);
    expect(h.state.viewedSiteId, isNull);
  });

  test('8. a refused saved site on screen keeps its entry and refusal, unlisted, closed',
      () async {
    final h = await _harness();
    final worked = DateTime(2026, 9, 30, 8);
    h.sites.lastWorkedAt['r1'] = worked;

    await h.registry.view(_refusedSite('r1'));
    await _settle();

    final c = h.state.byId('r1')!;
    expect(c.refusal!.failure, RouteFailure.misconfigured);
    expect(c.refusal!.lastWorked, worked);
    expect(c.listed, isFalse);
    expect(h.state.openCount, 0);
    expect(h.state.viewedSiteId, 'r1');
    expect(h.engine.closed, ['r1']);
  });

  test('9. a refused saved site not on screen is dropped (Deviation 2)', () async {
    final h = await _harness();
    h.engine.gate = Completer<void>();
    final refused = h.registry.view(_refusedSite('r1'));
    // Switched away while still opening.
    final other = h.registry.view(_site('s1'));
    h.engine.gate!.complete();
    await Future.wait([refused, other]);
    await _settle();

    expect(h.state.byId('r1'), isNull);
    expect(h.state.viewedSiteId, 's1');
    expect(h.engine.closed, ['r1']);
  });

  test('10. a refused throwaway stays listed with its refusal', () async {
    final h = await _harness();
    await h.registry.view(_refusedSite('t1'), throwaway: true);
    await h.registry.view(_site('s1'));
    await _settle();

    final c = h.state.byId('t1')!;
    expect(c.refusal!.failure, RouteFailure.misconfigured);
    expect(c.listed, isTrue);
    expect(h.state.openSiteIds, {'t1', 's1'});
    expect(h.engine.closed, isEmpty);
  });

  test('11. an ask waits on its container and is released for its own page only', () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    final p2 = h.engine.openPageFromLink('s1', openerPageId: 's1-p1');
    await _settle();
    h.engine.emitPermissionRequest(_ask('s1', 's1-p1', 'r1'));
    h.engine.emitPermissionRequest(_ask('s1', p2, 'r2'));
    h.engine.emitPermissionRequest(_ask('s1', 's1-p1', 'r3'));
    await _settle();

    expect(h.state.byId('s1')!.waiting, hasLength(3));
    final forP2 = h.registry.takeWaiting('s1', p2) as WaitingPermission;
    expect(forP2.request.requestId, 'r2');
    expect(h.registry.takeWaiting('s1', p2), isNull);
    final oldest = h.registry.takeWaiting('s1', 's1-p1') as WaitingPermission;
    expect(oldest.request.requestId, 'r1');
    expect(h.state.byId('s1')!.waiting.map((a) => (a as WaitingPermission).request.requestId),
        ['r3']);
    expect(h.engine.resolvedPermissions, isEmpty);
  });

  test('12. an ask for a site with no container is answered at once', () async {
    final h = await _harness();
    h.engine.emitPermissionRequest(_ask('gone', 'gone-p1', 'r1'));
    h.engine.emitDownload(const HeldDownloadEvent(
      siteId: 'gone',
      pageId: 'gone-p1',
      requestId: 'd1',
      download: HeldDownload(
          fileName: 'a.pdf', sizeBytes: 10, sourceHost: 'gone.example.org', kindLabel: 'PDF'),
    ));
    await _settle();

    expect(h.engine.resolvedPermissions, {'r1': PermissionDecision.keepBlocked});
    expect(h.engine.resolvedDownloads.single,
        (requestId: 'd1', decision: DownloadDecision.discard));
  });

  test('13. a page closed natively takes its waiting asks and navigation with it', () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    final p2 = h.engine.openPageFromLink('s1', openerPageId: 's1-p1');
    await _settle();
    h.engine.emitNavigation(_nav('s1', 's1-p1'));
    h.engine.emitNavigation(_nav('s1', p2));
    h.engine.emitPermissionRequest(_ask('s1', p2, 'r1'));
    await _settle();
    expect(h.state.navigation.keys, containsAll(['s1-p1', p2]));

    // The page's own window.close().
    await h.engine.closePage(p2);
    await _settle();

    final c = h.state.byId('s1')!;
    expect(c.pages.map((p) => p.pageId), ['s1-p1']);
    expect(c.waiting, isEmpty);
    expect(c.viewedPageId, 's1-p1');
    expect(h.state.navigation.keys, ['s1-p1']);
  });

  test('14. tunnel_dropped sets the flag; clearTunnelDropped clears it', () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    h.engine.emitTunnelDropped(TunnelDroppedEvent(
        siteId: 's1', host: 's1.example.org', droppedAt: DateTime(2026, 10, 2, 12)));
    await _settle();
    expect(h.state.byId('s1')!.tunnelDropped, isTrue);

    h.registry.clearTunnelDropped('s1');
    expect(h.state.byId('s1')!.tunnelDropped, isFalse);
  });

  test('15. a finished navigation sets loadedOnce', () async {
    final h = await _harness(opensLive: false);
    await h.registry.view(_site('t1'), throwaway: true);
    h.engine.emitNavigation(_nav('t1', 't1-p1', loading: true));
    await _settle();
    expect(h.state.byId('t1')!.loadedOnce, isFalse);

    h.engine.emitNavigation(_nav('t1', 't1-p1'));
    await _settle();
    expect(h.state.byId('t1')!.loadedOnce, isTrue);
  });

  test('16. leaving SessionOpen sends closeAll and empties the registry; '
      'the next SessionOpen starts empty', () async {
    final h = await _harness();
    await h.registry.view(_site('s1'));
    await h.registry.view(_site('t1'), throwaway: true);
    expect(h.state.openCount, 2);

    // Nothing listens to the registry: only reads, as above.
    h.session.become(const SessionLocked(mood: LockMood.afterTimeout, gate: AttemptGate()));
    // Sent synchronously by the transition itself, before anything reads the
    // registry again.
    expect(h.engine.closedAll, 1);
    await _settle();
    expect(h.engine.pagesOf('s1'), isEmpty);
    expect(h.engine.pagesOf('t1'), isEmpty);
    expect(h.state.containers, isEmpty);
    expect(h.state.viewedSiteId, isNull);

    h.session.become(_open(await _database()));
    expect(h.state.containers, isEmpty);
    // Reading the registry while locked rebuilt it; the unlock that disposed
    // that build is not a lock, so it sends nothing.
    expect(h.engine.closedAll, 1);
    await h.registry.view(_site('s2'));
    expect(h.state.openSiteIds, {'s2'});
  });

  test('17. openCount, openSiteIds and throwawaysIn count listed containers only', () async {
    final h = await _harness();
    await h.registry.view(_site('s1', workspaceId: 'w1'));
    await h.registry.view(_site('t1', workspaceId: 'w1'), throwaway: true, openerSiteId: 's1');
    await h.registry.view(_site('t2', workspaceId: 'w2'), throwaway: true, openerSiteId: 's1');
    // A refused saved site, on screen: present, counted nowhere.
    await h.registry.view(_refusedSite('r1', workspaceId: 'w1'));
    await _settle();

    expect(h.state.containers, hasLength(4));
    expect(h.state.openCount, 3);
    expect(h.state.openSiteIds, {'s1', 't1', 't2'});
    expect(h.state.throwawaysIn('w1'), 1);
    expect(h.state.throwawaysIn('w2'), 1);
    expect(h.state.throwawaysIn('w3'), 0);
  });

  group('18. siteSaved', () {
    test('a cosmetic change only updates the site, and nothing closes', () async {
      final h = await _harness();
      final s1 = _site('s1');
      await h.registry.view(s1);

      final after = s1.copyWith(name: 'Renamed', forceDark: false);
      final saved = await h.registry.siteSaved(after);

      expect(saved, same(after));
      expect(h.state.byId('s1')!.site.name, 'Renamed');
      expect(h.state.byId('s1')!.opened, same(s1));
      expect(h.engine.closed, isEmpty);
      expect(h.engine.opens, 1);
    });

    test('a route change on a background container closes it, wipe: false, and drops it',
        () async {
      final h = await _harness();
      final s1 = _site('s1');
      await h.registry.view(s1);
      await h.registry.view(_site('s2'));

      final after = s1.copyWith(
          proxyMode: ProxyMode.socks5, proxyHost: '10.0.2.2', proxyPort: 1080);
      await h.registry.siteSaved(after);
      await _settle();

      expect(h.engine.closedWith, {'s1': false});
      expect(h.state.byId('s1'), isNull);
      expect(h.state.viewedSiteId, 's2');
      expect(h.engine.opens, 2);
    });

    test('a route change on the viewed container reopens it in place at its stored address',
        () async {
      final h = await _harness();
      final s1 = _site('s1');
      await h.registry.view(s1, initialUrl: 'https://typed.example.net/');

      final after = s1.copyWith(
          proxyMode: ProxyMode.socks5, proxyHost: '10.0.2.2', proxyPort: 1080);
      await h.registry.siteSaved(after);
      await _settle();

      expect(h.engine.closedWith, {'s1': false});
      expect(h.engine.opens, 2);
      expect(h.engine.openedInitialUrls['s1'], isNull);
      expect(h.engine.openedSites['s1']!.proxyMode, ProxyMode.socks5);
      final c = h.state.byId('s1')!;
      expect(h.state.viewedSiteId, 's1');
      expect(c.initialUrl, isNull);
      expect(c.opened, same(after));
      expect(c.openReturned, isTrue);
      expect(c.viewedPageId, 's1-p2');
    });

    test('keep → wipe on exit rotates the profile and reopens on the new one', () async {
      final h = await _harness();
      final s1 = _site('s1');
      h.sites.rows['s1'] = s1;
      await h.registry.view(s1);

      final after = s1.copyWith(cookiePolicy: CookiePolicy.wipeOnExit);
      final saved = await h.registry.siteSaved(after);
      await _settle();

      expect(saved.profileId, isNot(s1.profileId));
      expect(h.sites.upserts.single.profileId, saved.profileId);
      expect(h.sites.upserts.single.cookiePolicy, CookiePolicy.wipeOnExit);
      // Closed natively, with its wipe, before the old profile is wiped
      // (tabs spec §5.8a).
      expect(h.engine.closed, ['s1']);
      expect(h.engine.closedWith['s1'], isTrue);
      expect(h.engine.wiped, [s1.profileId]);
      expect(h.engine.opens, 2);
      expect(h.engine.openedSites['s1']!.profileId, saved.profileId);
      expect(h.state.byId('s1')!.opened.profileId, saved.profileId);
      expect(h.state.viewedSiteId, 's1');
    });
  });

  test('19. saveThrowaway with no route change reopens nothing and clears throwaway',
      () async {
    final h = await _harness();
    final t1 = _site('t1', cookiePolicy: CookiePolicy.wipeOnExit);
    await h.registry.view(t1, throwaway: true);

    // Saved with the form's default policy: not a change that closes.
    final row = t1.copyWith(name: 'Saved name', cookiePolicy: CookiePolicy.keep);
    await h.registry.saveThrowaway(row);
    await _settle();

    final c = h.state.byId('t1')!;
    expect(c.throwaway, isFalse);
    expect(c.site, same(row));
    expect(c.opened.cookiePolicy, CookiePolicy.keep);
    expect(h.engine.opens, 1);
    expect(h.engine.closed, isEmpty);
  });

  test('20. closeAndWipe: a throwaway closes with wipe; a saved site rotates its profile',
      () async {
    final h = await _harness();
    final s1 = _site('s1');
    h.sites.rows['s1'] = s1;
    await h.registry.view(s1);
    await h.registry.view(_site('t1'), throwaway: true);

    await h.registry.closeAndWipe('t1');
    expect(h.engine.closedWith['t1'], isTrue);
    expect(h.state.byId('t1'), isNull);

    await h.registry.closeAndWipe('s1');
    await _settle();
    expect(h.sites.upserts.single.id, 's1');
    expect(h.sites.upserts.single.profileId, isNot(s1.profileId));
    expect(h.engine.wiped, [s1.profileId]);
    expect(h.state.containers, isEmpty);
  });

  test('21. a container dropped while its open is in flight has its session closed',
      () async {
    final h = await _harness();
    h.engine.gate = Completer<void>();
    final opening = h.registry.view(_site('s1'));
    await _settle();
    expect(h.engine.opens, 1);

    await h.registry.close('s1');
    expect(h.state.byId('s1'), isNull);
    expect(h.engine.closed, ['s1']);

    h.engine.gate!.complete();
    await opening;
    await _settle();
    // The session that registered after the close was closed again.
    expect(h.engine.closed, ['s1', 's1']);
    expect(h.engine.pagesOf('s1'), isEmpty);
    expect(h.state.byId('s1'), isNull);
  });
}

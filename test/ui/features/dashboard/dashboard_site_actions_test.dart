import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/container/view_models/open_containers.dart';
import 'package:container/ui/features/container/view_models/providers.dart'
    show containerEngineProvider, engineExtrasBuilderProvider;
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:container/ui/features/search/view_models/providers.dart' show allSitesProvider;
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show Session, SessionController, SessionUnconfigured, sessionProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 9, 30, 12);

const _forum = Site(
  id: 'st-forum', workspaceId: 'ws', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p-forum',
);

/// The engine and the repository log into one list, so a test can pin order.
class _Engine extends FakeContainerEngine {
  _Engine(this.events);
  final List<String> events;

  @override
  Future<void> close(String siteId, {bool? wipe}) async {
    events.add('close $siteId wipe: $wipe');
    await super.close(siteId, wipe: wipe);
  }

  @override
  Future<void> wipe(String profileId) async {
    events.add('wipe $profileId');
    await super.wipe(profileId);
  }
}

class _Sites implements SiteRepository {
  _Sites(this.events, [this.site = _forum]);
  final List<String> events;
  Site site;
  final upserts = <Site>[];

  @override
  Future<Site?> byId(String id) async => id == site.id ? site : null;
  @override
  Future<void> upsert(Site updated) async {
    events.add('upsert ${updated.id}');
    upserts.add(updated);
    site = updated;
  }
  @override
  Future<void> delete(String id) async => events.add('delete $id');
  @override
  Future<List<Site>> all() async => [site];
  @override
  Future<List<Site>> inWorkspace(String workspaceId) async => [site];
  @override
  Future<void> touch(String id, DateTime at) async {}
  @override
  Future<DateTime?> lastWorked(String id) async => null;
  @override
  Future<void> setLastWorked(String id, DateTime? at) async {}
}

/// The registry watches the session only to empty itself on leaving
/// `SessionOpen`, which these tests never do.
class _Session extends SessionController {
  @override
  Session build() => const SessionUnconfigured();
}

const _personal =
    Workspace(id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

/// The dashboard over [sites]' one site, which is open in the registry as a
/// background container, as it is after leaving it for the dashboard. With
/// [realDashboard] the dashboard is built from the registry; otherwise it is
/// a fixed view, for tests about the row menu's actions.
Future<ProviderContainer> _pump(WidgetTester tester, _Engine engine, _Sites sites,
    {void Function()? onSavedRead, bool realDashboard = false}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
      sessionProvider.overrideWith(_Session.new),
      siteRepositoryProvider.overrideWithValue(sites),
      if (realDashboard)
        workspacesProvider.overrideWith((ref) async => const [_personal])
      else ...[
        dashboardProvider.overrideWith((ref) async => DashboardView.from(
              workspace: _personal,
              sites: const [_forum],
              openSiteIds: const {'st-forum'},
              now: _now,
            )),
        workspaceOptionsProvider.overrideWith((ref) async => const []),
      ],
      allSitesProvider.overrideWith((ref) async {
        onSavedRead?.call();
        return const [_forum];
      }),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  ));
  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  final registry = container.read(openContainersProvider.notifier);
  await tester.runAsync(() => registry.view(sites.site));
  registry.showDashboard();
  await tester.pumpAndSettle();
  expect(container.read(openSiteIdsProvider), {sites.site.id});
  return container;
}

Future<void> _menuAction(WidgetTester tester, String label) async {
  await tester.longPress(find.text('Forum').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  // Deleting the row alone left the site's WebView profile — its logins and
  // stored data — and its kept downloads on disk, and its session running.
  testWidgets('Remove site closes and wipes the site before deleting its row', (tester) async {
    final events = <String>[];
    final container = await _pump(tester, _Engine(events), _Sites(events));

    await _menuAction(tester, 'Remove site');

    expect(events, ['close st-forum wipe: true', 'wipe p-forum', 'delete st-forum']);
    expect(container.read(openSiteIdsProvider), isEmpty);
  });

  testWidgets("Wipe this site's data, confirmed, wipes the site and keeps it under a fresh profile",
      (tester) async {
    final events = <String>[];
    final sites = _Sites(events);
    final container = await _pump(tester, _Engine(events), sites);

    await _menuAction(tester, "Wipe this site's data");
    expect(events, isEmpty, reason: 'nothing happens before the sheet is answered');
    await tester.tap(find.text('Wipe'));
    await tester.pumpAndSettle();

    expect(events, ['close st-forum wipe: true', 'wipe p-forum', 'upsert st-forum']);
    expect(sites.upserts.single.profileId, isNot('p-forum'));
    expect(sites.upserts.single.name, 'Forum');
    expect(container.read(openSiteIdsProvider), isEmpty);
  });

  testWidgets("Wipe this site's data, cancelled, does nothing", (tester) async {
    final events = <String>[];
    final container = await _pump(tester, _Engine(events), _Sites(events));

    await _menuAction(tester, "Wipe this site's data");
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
    expect(container.read(openSiteIdsProvider), {'st-forum'});
  });

  // Tabs spec §5.7: the dashboard row's edit form is one of the forms whose
  // route change closes an open container. From the dashboard it is in the
  // background, so it stays closed, with no wipe, and leaves OPEN NOW.
  testWidgets('a row edit that changes the route of an open site closes it and it leaves OPEN NOW',
      (tester) async {
    final events = <String>[];
    final engine = _Engine(events);
    final sites = _Sites(events, _forum.copyWith(
        proxyMode: ProxyMode.socks5, proxyHost: '10.0.2.2', proxyPort: 1080));
    final container = await _pump(tester, engine, sites, realDashboard: true);
    expect(find.text('OPEN NOW'), findsOneWidget);
    expect(find.text('1 SESSIONS'), findsOneWidget);

    await _menuAction(tester, 'Edit settings');
    expect(find.byType(AddSiteScreen), findsOneWidget);
    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('proxy-enabled'))); // proxy off: direct
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(sites.upserts.single.proxyMode, ProxyMode.direct);
    expect(engine.closedWith['st-forum'], isFalse);
    expect(engine.wiped, isEmpty);
    expect(container.read(openContainersProvider).byId('st-forum'), isNull);
    expect(container.read(openSiteIdsProvider), isEmpty);
    expect(find.byType(AddSiteScreen), findsNothing);
    expect(find.text('OPEN NOW'), findsNothing);
    expect(find.text('0 SESSIONS'), findsOneWidget);
  });

  // The address bar's copy of the vault's sites went on offering a removed
  // site, and a wiped one under the profile its wipe had rotated away from.
  group("the address bar's sites are read again after", () {
    Future<int> readsAfter(WidgetTester tester, Future<void> Function() act) async {
      var reads = 0;
      final events = <String>[];
      final container = await _pump(tester, _Engine(events), _Sites(events),
          onSavedRead: () => reads++);
      await container.read(allSitesProvider.future);
      final before = reads;
      await act();
      await container.read(allSitesProvider.future);
      return reads - before;
    }

    testWidgets('Remove site', (tester) async {
      expect(await readsAfter(tester, () => _menuAction(tester, 'Remove site')), greaterThan(0));
    });

    testWidgets("Wipe this site's data", (tester) async {
      final reads = await readsAfter(tester, () async {
        await _menuAction(tester, "Wipe this site's data");
        await tester.tap(find.text('Wipe'));
        await tester.pumpAndSettle();
      });
      expect(reads, greaterThan(0));
    });
  });
}

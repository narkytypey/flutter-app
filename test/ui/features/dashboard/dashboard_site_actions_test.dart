import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/container/view_models/providers.dart' show containerEngineProvider;
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:container/ui/features/search/view_models/providers.dart' show allSitesProvider;
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
  Future<void> close(String siteId) async {
    events.add('close $siteId');
    await super.close(siteId);
  }

  @override
  Future<void> wipe(String profileId) async {
    events.add('wipe $profileId');
    await super.wipe(profileId);
  }
}

class _Sites implements SiteRepository {
  _Sites(this.events);
  final List<String> events;
  final upserts = <Site>[];

  @override
  Future<Site?> byId(String id) async => id == _forum.id ? _forum : null;
  @override
  Future<void> upsert(Site site) async {
    events.add('upsert ${site.id}');
    upserts.add(site);
  }
  @override
  Future<void> delete(String id) async => events.add('delete $id');
  @override
  Future<List<Site>> all() async => const [_forum];
  @override
  Future<List<Site>> inWorkspace(String workspaceId) async => const [_forum];
  @override
  Future<void> touch(String id, DateTime at) async {}
}

Future<ProviderContainer> _pump(WidgetTester tester, _Engine engine, _Sites sites,
    {void Function()? onSavedRead}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      siteRepositoryProvider.overrideWithValue(sites),
      openSiteIdsProvider.overrideWith((ref) => {'st-forum'}),
      dashboardProvider.overrideWith((ref) async => DashboardView.from(
            workspace: const Workspace(
                id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
            sites: const [_forum],
            openSiteIds: const {'st-forum'},
            now: _now,
          )),
      workspaceOptionsProvider.overrideWith((ref) async => const []),
      allSitesProvider.overrideWith((ref) async {
        onSavedRead?.call();
        return const [_forum];
      }),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
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

    expect(events, ['close st-forum', 'wipe p-forum', 'delete st-forum']);
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

    expect(events, ['close st-forum', 'wipe p-forum', 'upsert st-forum']);
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

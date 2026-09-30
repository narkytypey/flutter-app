import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/container/view_models/providers.dart' show containerEngineProvider;
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
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

Future<ProviderContainer> _pump(WidgetTester tester, _Engine engine, _Sites sites) async {
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
            leakCount: 0,
            now: _now,
          )),
      workspaceOptionsProvider.overrideWith((ref) async => const []),
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
}

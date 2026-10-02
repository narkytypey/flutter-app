import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/container/view_models/open_containers.dart';
import 'package:container/ui/features/container/view_models/providers.dart'
    show containerEngineProvider, engineExtrasBuilderProvider;
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show Session, SessionController, SessionUnconfigured, sessionProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The registry watches the session only to empty itself on leaving
/// `SessionOpen`, which these tests never do.
class _Session extends SessionController {
  @override
  Session build() => const SessionUnconfigured();
}

class _Sites implements SiteRepository {
  _Sites(this.rows);
  final List<Site> rows;

  @override
  Future<List<Site>> all() async => rows;
  @override
  Future<List<Site>> inWorkspace(String workspaceId) async =>
      rows.where((s) => s.workspaceId == workspaceId).toList();
  @override
  Future<Site?> byId(String id) async => rows.where((s) => s.id == id).firstOrNull;
  @override
  Future<void> upsert(Site site) async {}
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> touch(String id, DateTime at) async {}
  @override
  Future<DateTime?> lastWorked(String id) async => null;
  @override
  Future<void> setLastWorked(String id, DateTime? at) async {}
}

const _personal =
    Workspace(id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep, sortIndex: 0);
const _work =
    Workspace(id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep, sortIndex: 1);

Site _site(String id, String workspaceId) => Site(
      id: id,
      workspaceId: workspaceId,
      name: id,
      monogram: id.substring(0, 2),
      url: 'https://$id.example.org',
      profileId: 'p-$id',
    );

/// A saved site and a throwaway open under Personal, and a throwaway open
/// under Work: a throwaway counts under its opener's workspace, which
/// `buildThrowaway` sets as its `workspaceId` (tabs spec §5.4).
Future<ProviderContainer> _openThree() async {
  final saved = _site('s1', 'w1');
  final container = ProviderContainer(overrides: [
    containerEngineProvider.overrideWithValue(FakeContainerEngine()),
    engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
    sessionProvider.overrideWith(_Session.new),
    siteRepositoryProvider.overrideWithValue(_Sites([saved, _site('s2', 'w1')])),
    workspacesProvider.overrideWith((ref) async => const [_personal, _work]),
  ]);
  addTearDown(container.dispose);
  final registry = container.read(openContainersProvider.notifier);
  await registry.view(saved);
  await registry.view(_site('t1', 'w1'), throwaway: true, openerSiteId: 's1');
  await registry.view(_site('t2', 'w2'), throwaway: true, openerSiteId: 's1');
  registry.showDashboard();
  expect(container.read(openSiteIdsProvider), {'s1', 't1', 't2'});
  return container;
}

void main() {
  test("the dashboard's N SESSIONS counts a throwaway of its workspace, and lists only saved sites",
      () async {
    final container = await _openThree();

    final personal = await container.read(dashboardProvider.future);
    expect(personal.sessionCount, 2);
    expect(personal.open.map((e) => e.siteId), ['s1']);
    expect(personal.idle.map((e) => e.siteId), ['s2']);

    container.read(activeWorkspaceIdProvider.notifier).state = 'w2';
    final work = await container.read(dashboardProvider.future);
    expect(work.sessionCount, 1);
    expect(work.open, isEmpty);
  });

  test("the workspace menu's M OPEN counts a throwaway of its workspace", () async {
    final container = await _openThree();

    final options = await container.read(workspaceOptionsProvider.future);
    expect({for (final o in options) o.id: o.meta}, {
      'w1': '2 SITES · 2 OPEN',
      'w2': '0 SITES · 1 OPEN',
    });
  });

  test('the counts follow the registry: a closed throwaway stops counting', () async {
    final container = await _openThree();
    expect((await container.read(dashboardProvider.future)).sessionCount, 2);

    await container.read(openContainersProvider.notifier).close('t1');

    expect((await container.read(dashboardProvider.future)).sessionCount, 1);
  });
}

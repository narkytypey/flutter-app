import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show siteRepositoryProvider, workspacesProvider, openSiteIdsProvider;
import 'package:container/ui/features/search/view_models/providers.dart';

/// A minimal fake covering only what the search providers call.
class FakeSiteRepository implements SiteRepository {
  FakeSiteRepository(this.sites);
  final List<Site> sites;
  final touched = <String, DateTime>{};

  @override
  Future<List<Site>> all() async => sites;
  @override
  Future<List<Site>> inWorkspace(String workspaceId) => throw UnimplementedError();
  @override
  Future<void> upsert(Site site) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<void> touch(String id, DateTime at) async => touched[id] = at;
  @override
  Future<Site?> byId(String id) => throw UnimplementedError();
}

void main() {
  const workspace = Workspace(
      id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

  test('joins sites, workspaces and open ids into results', () async {
    const site = Site(
        id: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p1');

    final container = ProviderContainer(overrides: [
      siteRepositoryProvider.overrideWithValue(FakeSiteRepository([site])),
      workspacesProvider.overrideWith((ref) async => [workspace]),
    ]);
    addTearDown(container.dispose);
    container.read(openSiteIdsProvider.notifier).state = {'s1'};

    container.listen(searchResultsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    final result = container.read(searchResultsProvider);
    expect(result.value!.single.name, 'Forum');
    expect(result.value!.single.workspaceName, 'Personal');
    expect(result.value!.single.live, isTrue);
  });

  test('changing searchQueryProvider narrows the results', () async {
    const forum = Site(
        id: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p1');
    const bank = Site(
        id: 's2', workspaceId: 'w1', name: 'Bank', monogram: 'Bk',
        url: 'https://bank.example.com', profileId: 'p2');

    final container = ProviderContainer(overrides: [
      siteRepositoryProvider.overrideWithValue(FakeSiteRepository([forum, bank])),
      workspacesProvider.overrideWith((ref) async => [workspace]),
    ]);
    addTearDown(container.dispose);

    container.listen(searchResultsProvider, (_, __) {});
    await Future<void>.delayed(Duration.zero);

    container.read(searchQueryProvider.notifier).state = 'ban';

    final result = container.read(searchResultsProvider);
    expect(result.value!.map((r) => r.name), ['Bank']);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/search/view_models/search_view.dart';

void main() {
  const personal = Workspace(
      id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);
  const work = Workspace(
      id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep);

  Site site({
    required String id,
    required String workspaceId,
    required String name,
    String url = 'https://example.com',
    DateTime? lastVisitedAt,
  }) {
    return Site(
      id: id,
      workspaceId: workspaceId,
      name: name,
      monogram: name.substring(0, 2),
      url: url,
      profileId: 'p-$id',
      lastVisitedAt: lastVisitedAt,
    );
  }

  test('an empty query returns every site, most recently visited first', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum', lastVisitedAt: DateTime.utc(2026, 1, 1));
    final b = site(id: 's2', workspaceId: 'w2', name: 'Notes', lastVisitedAt: DateTime.utc(2026, 6, 1));
    final c = site(id: 's3', workspaceId: 'w1', name: 'Bank');

    final results = searchResults(
        sites: [a, b, c], workspaces: [personal, work], openSiteIds: {}, query: '');

    expect(results.map((r) => r.siteId), ['s2', 's1', 's3']);
  });

  test('matches by name, case-insensitively', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum');
    final b = site(id: 's2', workspaceId: 'w1', name: 'Notes');

    final results = searchResults(
        sites: [a, b], workspaces: [personal], openSiteIds: {}, query: 'FOR');

    expect(results.map((r) => r.siteId), ['s1']);
  });

  test('matches by host, case-insensitively', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum', url: 'https://Forum.Example.com');

    final results = searchResults(
        sites: [a], workspaces: [personal], openSiteIds: {}, query: 'forum.example');

    expect(results.map((r) => r.siteId), ['s1']);
  });

  test('a query matching nothing returns an empty list', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum');

    final results = searchResults(
        sites: [a], workspaces: [personal], openSiteIds: {}, query: 'zzz');

    expect(results, isEmpty);
  });

  test('carries the id, name and marker of the site\'s own workspace', () {
    final a = site(id: 's1', workspaceId: 'w2', name: 'Ticket board');

    final results = searchResults(
        sites: [a], workspaces: [personal, work], openSiteIds: {}, query: '');

    expect(results.single.workspaceId, 'w2');
    expect(results.single.workspaceName, 'Work');
    expect(results.single.markerIndex, 1);
  });

  test('a site is live only when its id is in openSiteIds', () {
    final a = site(id: 's1', workspaceId: 'w1', name: 'Forum');
    final b = site(id: 's2', workspaceId: 'w1', name: 'Notes');

    final results = searchResults(
        sites: [a, b], workspaces: [personal], openSiteIds: {'s2'}, query: '');

    expect(results.firstWhere((r) => r.siteId == 's1').live, isFalse);
    expect(results.firstWhere((r) => r.siteId == 's2').live, isTrue);
  });
}

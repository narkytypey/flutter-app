import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/data/services/engine_extras_builder.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/domain/models/security_level.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'bundled_filter_lists_test.dart' show FakeBundle;

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqliteSettingsRepository settings;

  final lists = [
    BundledFilterList(
      id: 'fl-a', name: 'A', enabledByDefault: true,
      category: FilterListCategory.trackers, asset: 'a.txt',
      updatedAt: DateTime.utc(2026, 9, 28),
    ),
    BundledFilterList(
      id: 'fl-b', name: 'B', enabledByDefault: true,
      category: FilterListCategory.ads, asset: 'b.txt',
      updatedAt: DateTime.utc(2026, 9, 28),
    ),
  ];
  final rules = BundledFilterRules(
    FakeBundle({
      'a.txt': '||t1.example^\n! category: ads\n||a1.example^\n',
      'b.txt': '||a2.example^\n',
    }),
    lists: lists,
  );

  const site = Site(
    id: 'forum', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
    url: 'https://forum.example.com', profileId: 'p',
  );

  UserScript script(String id, {bool enabled = true, List<String> sites = const ['forum']}) =>
      UserScript(
        id: id, name: id, kind: ScriptKind.css, code: '/* $id */',
        runAtDocumentStart: true, enabled: enabled, appliedSiteIds: sites,
      );

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
        id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep));
    await SqliteSiteRepository(database).upsert(site);
    await SqliteSiteRepository(database).upsert(const Site(
      id: 'news', workspaceId: 'w', name: 'News', monogram: 'Nw',
      url: 'https://news.example.com', profileId: 'p2',
    ));
    await syncBundledFilterLists(database, rules);
    settings = SqliteSettingsRepository(database);
  });

  tearDown(() => database.close());

  Future<EngineExtras> build([Site opened = site]) => engineExtrasFor(
        opened,
        filterLists: SqliteFilterListRepository(database),
        scripts: SqliteScriptRepository(database),
        rules: rules,
        settings: settings,
      );

  test('enabled lists are merged by category', () async {
    final extras = await build();
    expect(extras.filterRules, {
      'trackers': ['||t1.example^'],
      'ads': ['||a1.example^', '||a2.example^'],
    });
  });

  test('a disabled list contributes nothing', () async {
    await SqliteFilterListRepository(database).setEnabled('fl-a', false);
    expect((await build()).filterRules, {'ads': ['||a2.example^']});
  });

  // Review Focus 5: everything off means nothing blocked — not a fallback.
  test('every list off sends no rules at all', () async {
    await SqliteFilterListRepository(database).setEnabled('fl-a', false);
    await SqliteFilterListRepository(database).setEnabled('fl-b', false);
    expect((await build()).filterRules, isEmpty);
  });

  test('a vault row with no bundled file is ignored', () async {
    await database.db.insert('filter_lists', {
      'id': 'fl-legacy', 'name': 'Legacy', 'rule_count': 1,
      'updated_at': 0, 'enabled': 1, 'category': 'trackers',
    });
    expect((await build()).filterRules['trackers'], ['||t1.example^']);
  });

  test("only enabled scripts applied to this site are sent, in library order", () async {
    final repo = SqliteScriptRepository(database);
    await repo.upsert(script('first'));
    await repo.upsert(script('off', enabled: false));
    await repo.upsert(script('elsewhere', sites: ['news']));
    await repo.upsert(script('second', sites: ['news', 'forum']));

    final sent = (await build()).userScripts;
    expect(sent.map((s) => s.code), ['/* first */', '/* second */']);
    expect(sent.first.toMap(), {'kind': 'css', 'code': '/* first */', 'atDocumentStart': true});
  });

  group('security level (privacy-controls spec §2.2)', () {
    test('a site with its own level opens at it, whatever the default', () async {
      await settings.setString('security_level', 'standard');
      final extras = await build(site.withSecurityLevel(SecurityLevel.safest));
      expect(extras.securityLevel, SecurityLevel.safest);
    });

    test('a site that follows the default opens at the stored default', () async {
      await settings.setString('security_level', 'safer');
      expect((await build(site)).securityLevel, SecurityLevel.safer);
    });

    test('nothing stored is Standard; an unknown default is Safest', () async {
      expect((await build(site)).securityLevel, SecurityLevel.standard);
      await settings.setString('security_level', '??');
      expect((await build(site)).securityLevel, SecurityLevel.safest);
    });

    test('the default is read at each build, not remembered', () async {
      expect((await build(site)).securityLevel, SecurityLevel.standard);
      await settings.setString('security_level', 'safest');
      expect((await build(site)).securityLevel, SecurityLevel.safest);
    });
  });

  test('selectUserScripts matches on enabled and site', () {
    final picked = selectUserScripts(site, [
      script('a'), script('b', enabled: false), script('c', sites: ['news']),
    ]);
    expect(picked.map((s) => s.id), ['a']);
  });
}

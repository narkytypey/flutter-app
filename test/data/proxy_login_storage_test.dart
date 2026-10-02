import 'dart:io';

import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('a site keeps its typed login and per-site choice', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep));
    final sites = SqliteSiteRepository(database);
    await sites.upsert(const Site(
      id: 's1', workspaceId: 'ws', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      proxyUser: 'alice', proxyPassword: ' s3cret ',
    ));
    await sites.upsert(const Site(
      id: 's2', workspaceId: 'ws', name: 'Mail', monogram: 'Ml',
      url: 'https://mail.example.com', profileId: 'p2',
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      proxyLoginPerSite: true,
    ));

    final typed = (await sites.byId('s1'))!;
    expect(typed.proxyUser, 'alice');
    expect(typed.proxyPassword, ' s3cret ', reason: 'stored exactly as typed (ruling 8)');
    expect(typed.proxyLoginPerSite, isFalse);
    final perSite = (await sites.byId('s2'))!;
    expect(perSite.proxyUser, isNull);
    expect(perSite.proxyPassword, isNull);
    expect(perSite.proxyLoginPerSite, isTrue);
    await database.close();
  });

  test('a v6 vault upgrades its sites to no login', () async {
    final dir = await Directory.systemTemp.createTemp('v6-upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/store.db';

    final v6 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 6, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE workspaces (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, marker_index INTEGER NOT NULL,
          storage_rule TEXT NOT NULL, require_pin INTEGER NOT NULL DEFAULT 0,
          show_in_decoy INTEGER NOT NULL DEFAULT 0, sort_index INTEGER NOT NULL DEFAULT 0)
      ''');
      await db.execute('''
        CREATE TABLE sites (
          id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
          name TEXT NOT NULL, monogram TEXT NOT NULL, url TEXT NOT NULL,
          cookie_policy TEXT NOT NULL, proxy_mode TEXT NOT NULL, proxy_host TEXT, proxy_port INTEGER,
          require_pin INTEGER NOT NULL DEFAULT 0, show_in_decoy INTEGER NOT NULL DEFAULT 0,
          last_visited_at INTEGER, sort_index INTEGER NOT NULL DEFAULT 0,
          profile_id TEXT NOT NULL, block_webrtc INTEGER NOT NULL DEFAULT 1,
          block_trackers INTEGER NOT NULL DEFAULT 1, anti_fingerprinting INTEGER NOT NULL DEFAULT 1,
          allow_camera INTEGER NOT NULL DEFAULT 0, allow_microphone INTEGER NOT NULL DEFAULT 0,
          allow_location INTEGER NOT NULL DEFAULT 0, allow_clipboard INTEGER NOT NULL DEFAULT 0,
          user_agent_mode TEXT NOT NULL DEFAULT 'android', force_dark INTEGER NOT NULL DEFAULT 1,
          open_in_reader INTEGER NOT NULL DEFAULT 0, page_zoom INTEGER NOT NULL DEFAULT 100,
          custom_css TEXT NOT NULL DEFAULT '', custom_js TEXT NOT NULL DEFAULT '')
      ''');
    }));
    await v6.insert('workspaces',
        {'id': 'ws', 'name': 'Personal', 'marker_index': 0, 'storage_rule': 'keep'});
    await v6.insert('sites', {
      'id': 's1', 'workspace_id': 'ws', 'name': 'Forum', 'monogram': 'Fr',
      'url': 'https://forum.example.com', 'cookie_policy': 'keep',
      'proxy_mode': 'socks5', 'proxy_host': '127.0.0.1', 'proxy_port': 9050,
      'profile_id': 'p1',
    });
    await v6.close();

    final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    final site = siteFromRow((await upgraded.db.query('sites')).single);
    expect(site.proxyUser, isNull);
    expect(site.proxyPassword, isNull);
    expect(site.proxyLoginPerSite, isFalse);
    expect(site.proxyHost, '127.0.0.1', reason: 'nothing else changes');
    await upgraded.close();
  });

  test('copyWith carries the login fields', () {
    const site = Site(
      id: 's', workspaceId: 'w', name: 'n', monogram: 'N', url: 'https://a.example',
      profileId: 'p', proxyUser: 'alice', proxyPassword: 'pw', proxyLoginPerSite: true,
    );
    final copy = site.copyWith(profileId: 'q');
    expect(copy.proxyUser, 'alice');
    expect(copy.proxyPassword, 'pw');
    expect(copy.proxyLoginPerSite, isTrue);
  });
}

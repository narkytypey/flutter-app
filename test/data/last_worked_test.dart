import 'dart:io';

import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _site = Site(
  id: 's1', workspaceId: 'ws', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
);

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late SqliteSiteRepository sites;

  setUp(() async {
    database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep));
    sites = SqliteSiteRepository(database);
    await sites.upsert(_site);
  });

  tearDown(() => database.close());

  test('a site that never worked has no last-worked time', () async {
    expect(await sites.lastWorked('s1'), isNull);
    expect(await sites.lastWorked('missing'), isNull);
  });

  test('the last-worked time is recorded, and cleared with null', () async {
    final at = DateTime.utc(2026, 10, 2, 12);
    await sites.setLastWorked('s1', at);
    expect(await sites.lastWorked('s1'), at);

    await sites.setLastWorked('s1', null);
    expect(await sites.lastWorked('s1'), isNull);
  });

  test('editing a site keeps its last-worked time', () async {
    final at = DateTime.utc(2026, 10, 2, 12);
    await sites.setLastWorked('s1', at);

    await sites.upsert(_site.copyWith(name: 'Renamed'));

    expect(await sites.lastWorked('s1'), at);
    expect((await sites.byId('s1'))!.name, 'Renamed');
  });

  test('a v7 vault upgrades with no last-worked times', () async {
    final dir = await Directory.systemTemp.createTemp('v7-upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/store.db';

    final v7 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 7, onCreate: (db, _) async {
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
          proxy_user TEXT, proxy_password TEXT, proxy_login_per_site INTEGER NOT NULL DEFAULT 0,
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
    await v7.insert('workspaces',
        {'id': 'ws', 'name': 'Personal', 'marker_index': 0, 'storage_rule': 'keep'});
    await v7.insert('sites', {
      'id': 's1', 'workspace_id': 'ws', 'name': 'Forum', 'monogram': 'Fr',
      'url': 'https://forum.example.com', 'cookie_policy': 'keep',
      'proxy_mode': 'socks5', 'proxy_host': '127.0.0.1', 'proxy_port': 9050,
      'profile_id': 'p1',
    });
    await v7.close();

    final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    final repository = SqliteSiteRepository(upgraded);
    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);
    expect(await repository.lastWorked('s1'), isNull);
    final at = DateTime.utc(2026, 10, 2, 12);
    await repository.setLastWorked('s1', at);
    expect(await repository.lastWorked('s1'), at);
    await upgraded.close();
  });
}

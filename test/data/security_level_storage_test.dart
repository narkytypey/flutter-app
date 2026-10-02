import 'dart:io';

import 'package:container/data/repositories/decoy_provisioner.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/security_level.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/throwaway.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _site = Site(
  id: 's1', workspaceId: 'ws', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
);

Future<AppDatabase> _open() =>
    AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);

Future<void> _workspace(AppDatabase db, {bool showInDecoy = false}) =>
    SqliteWorkspaceRepository(db).upsert(Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep,
        showInDecoy: showInDecoy));

void main() {
  setUpAll(sqfliteFfiInit);

  test('a site keeps its own level, and a followed default stays null', () async {
    final db = await _open();
    addTearDown(db.close);
    await _workspace(db);
    final sites = SqliteSiteRepository(db);
    await sites.upsert(_site.withSecurityLevel(SecurityLevel.safer));
    await sites.upsert(const Site(
        id: 's2', workspaceId: 'ws', name: 'Mail', monogram: 'Ml',
        url: 'https://mail.example.com', profileId: 'p2'));

    expect((await sites.byId('s1'))!.securityLevel, SecurityLevel.safer);
    expect((await sites.byId('s2'))!.securityLevel, isNull);

    await sites.upsert((await sites.byId('s1'))!.withSecurityLevel(null));
    expect((await sites.byId('s1'))!.securityLevel, isNull, reason: 'cleared, not kept');
  });

  test('an unknown stored level reads as safest', () async {
    final db = await _open();
    addTearDown(db.close);
    await _workspace(db);
    await SqliteSiteRepository(db).upsert(_site);
    await db.db.update('sites', {'security_level': 'paranoid'});
    expect((await SqliteSiteRepository(db).byId('s1'))!.securityLevel, SecurityLevel.safest);
  });

  test('withSecurityLevel drops no column', () {
    final row = siteToRow(_site);
    final copied = siteToRow(_site.withSecurityLevel(SecurityLevel.safest));
    expect(copied.keys, row.keys);
    for (final key in row.keys) {
      if (key == 'security_level') continue;
      expect(copied[key], row[key], reason: key);
    }
  });

  test('a v8 vault upgrades its sites to follow the default', () async {
    final dir = await Directory.systemTemp.createTemp('v8-upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/store.db';

    final v8 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 8, onCreate: (db, _) async {
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
          last_visited_at INTEGER, last_worked_at INTEGER, sort_index INTEGER NOT NULL DEFAULT 0,
          profile_id TEXT NOT NULL, block_webrtc INTEGER NOT NULL DEFAULT 1,
          block_trackers INTEGER NOT NULL DEFAULT 1, anti_fingerprinting INTEGER NOT NULL DEFAULT 1,
          allow_camera INTEGER NOT NULL DEFAULT 0, allow_microphone INTEGER NOT NULL DEFAULT 0,
          allow_location INTEGER NOT NULL DEFAULT 0, allow_clipboard INTEGER NOT NULL DEFAULT 0,
          user_agent_mode TEXT NOT NULL DEFAULT 'android', force_dark INTEGER NOT NULL DEFAULT 1,
          open_in_reader INTEGER NOT NULL DEFAULT 0, page_zoom INTEGER NOT NULL DEFAULT 100,
          custom_css TEXT NOT NULL DEFAULT '', custom_js TEXT NOT NULL DEFAULT '')
      ''');
    }));
    await v8.insert('workspaces',
        {'id': 'ws', 'name': 'Personal', 'marker_index': 0, 'storage_rule': 'keep'});
    await v8.insert('sites', {
      'id': 's1', 'workspace_id': 'ws', 'name': 'Forum', 'monogram': 'Fr',
      'url': 'https://forum.example.com', 'cookie_policy': 'keep',
      'proxy_mode': 'direct', 'profile_id': 'p1',
    });
    await v8.close();

    final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);
    final site = siteFromRow((await upgraded.db.query('sites')).single);
    expect(site.securityLevel, isNull);
    expect(site.url, 'https://forum.example.com', reason: 'nothing else changes');
    await upgraded.close();
  });

  test('decoy re-sync copies a site\'s own level', () async {
    final real = await _open();
    final decoy = await _open();
    addTearDown(real.close);
    addTearDown(decoy.close);
    await _workspace(real, showInDecoy: true);
    await SqliteSiteRepository(real)
        .upsert(_site.copyWith(showInDecoy: true).withSecurityLevel(SecurityLevel.safest));

    await resyncDecoy(from: real, into: decoy);

    final copied = (await SqliteSiteRepository(decoy).all()).single;
    expect(copied.securityLevel, SecurityLevel.safest);
    expect(copied.profileId, isNot('p1'), reason: 'its own profile, as every sync');
  });

  test('a throwaway follows the vault default', () {
    final throwaway = buildThrowaway(
      destination: Throwaway(Uri.parse('https://news.example.org'), ProxyMode.direct, null, null),
      current: _site.withSecurityLevel(SecurityLevel.safest),
      newId: () => 'fresh',
    );
    expect(throwaway.securityLevel, isNull, reason: 'spec: only the route is inherited');
  });
}

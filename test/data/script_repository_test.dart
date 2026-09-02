import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/domain/models/workspace.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  // `script_sites.site_id` really does reference `sites(id)`, and the
  // database is opened with `PRAGMA foreign_keys = ON`, so a script can only
  // be applied to a site that exists. That constraint is the point — spec
  // `10c` keeps scripts when a workspace goes, and the cascade on `site_id`
  // is what removes an association when its site goes. So these tests seed
  // real sites rather than inventing ids.
  Future<void> seedSites(Iterable<String> ids) async {
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
      id: 'w1',
      name: 'Personal',
      markerIndex: 0,
      storageRule: StorageRule.keep,
    ));
    final sites = SqliteSiteRepository(database);
    for (final id in ids) {
      await sites.upsert(Site(
        id: id,
        workspaceId: 'w1',
        name: id,
        monogram: 'Xx',
        url: 'https://$id.example.com',
        profileId: newProfileId(),
      ));
    }
  }

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => database.close());

  test('a script round-trips its fields and its site associations', () async {
    await seedSites(['st-forum', 'st-reader']);
    final repo = SqliteScriptRepository(database);

    await repo.upsert(const UserScript(
      id: 'sc-1',
      name: 'Hide sticky headers',
      kind: ScriptKind.css,
      code: 'header { position: static !important; }',
      runAtDocumentStart: true,
      enabled: true,
      appliedSiteIds: ['st-forum', 'st-reader'],
    ));

    final loaded = await repo.byId('sc-1');
    expect(loaded!.name, 'Hide sticky headers');
    expect(loaded.kind, ScriptKind.css);
    expect(loaded.code, 'header { position: static !important; }');
    expect(loaded.runAtDocumentStart, isTrue);
    expect(loaded.enabled, isTrue);
    expect(loaded.appliedSiteIds, unorderedEquals(['st-forum', 'st-reader']));
  });

  test('re-saving replaces the site associations rather than appending', () async {
    await seedSites(['a', 'b', 'c']);
    final repo = SqliteScriptRepository(database);
    await repo.upsert(const UserScript(
      id: 'sc-1', name: 'S', kind: ScriptKind.js, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: ['a', 'b'],
    ));
    await repo.upsert(const UserScript(
      id: 'sc-1', name: 'S', kind: ScriptKind.js, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: ['c'],
    ));

    final loaded = await repo.byId('sc-1');
    expect(loaded!.appliedSiteIds, ['c']);
  });

  test('all() lists every script, deleting removes it and its associations', () async {
    await seedSites(['a']);
    final repo = SqliteScriptRepository(database);
    await repo.upsert(const UserScript(
      id: 'sc-1', name: 'One', kind: ScriptKind.css, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: ['a'],
    ));
    await repo.upsert(const UserScript(
      id: 'sc-2', name: 'Two', kind: ScriptKind.js, code: '', runAtDocumentStart: false,
      enabled: false, appliedSiteIds: [],
    ));

    expect((await repo.all()).map((s) => s.name), ['One', 'Two']);

    await repo.delete('sc-1');
    expect((await repo.all()).map((s) => s.id), ['sc-2']);
    expect(await repo.byId('sc-1'), isNull);
    expect(await database.db.query('script_sites', where: 'script_id = ?', whereArgs: ['sc-1']),
        isEmpty);
  });

  test('deleting a site drops its script associations, never the script', () async {
    await seedSites(['a', 'b']);
    final repo = SqliteScriptRepository(database);
    await repo.upsert(const UserScript(
      id: 'sc-1', name: 'One', kind: ScriptKind.css, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: ['a', 'b'],
    ));

    await SqliteSiteRepository(database).delete('a');

    final loaded = await repo.byId('sc-1');
    expect(loaded, isNotNull, reason: 'the library outlives any one site');
    expect(loaded!.appliedSiteIds, ['b']);
  });

  // As with the v3 migration: onCreate builds these tables directly, so a
  // fresh-create test passes even when the v3 -> v4 upgrade step is broken.
  test('an existing version-3 database upgrades to 4 without losing its rows', () async {
    final dir = await Directory.systemTemp.createTemp('container-migration-v4');
    final path = '${dir.path}/store.db';

    final v3 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        singleInstance: false,
        onCreate: (db, _) async {
          // A real version-3 database always carries the tables v1/v2 made.
          // `script_sites` references `sites(id)`, so a fixture without it
          // fails on the FK check rather than on the migration under test.
          // Only the columns the constraint needs are reproduced here.
          await db.execute('''
            CREATE TABLE workspaces (
              id   TEXT PRIMARY KEY,
              name TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE sites (
              id           TEXT PRIMARY KEY,
              workspace_id TEXT NOT NULL
                             REFERENCES workspaces(id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE filter_lists (
              id          TEXT PRIMARY KEY,
              name        TEXT    NOT NULL,
              rule_count  INTEGER NOT NULL,
              updated_at  INTEGER NOT NULL,
              enabled     INTEGER NOT NULL DEFAULT 1
            )
          ''');
          await db.insert('filter_lists', {
            'id': 'fl-trackers',
            'name': 'Trackers and ads',
            'rule_count': 84102,
            'updated_at': 0,
            'enabled': 1,
          });
        },
      ),
    );
    await v3.close();

    final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    addTearDown(() async {
      await upgraded.close();
      await dir.delete(recursive: true);
    });

    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);

    // The new tables exist...
    await SqliteScriptRepository(upgraded).upsert(const UserScript(
      id: 'sc-1', name: 'One', kind: ScriptKind.css, code: '', runAtDocumentStart: false,
      enabled: true, appliedSiteIds: [],
    ));
    expect((await SqliteScriptRepository(upgraded).all()).length, 1);

    // ...and the version-3 row survived.
    final lists = await upgraded.db.query('filter_lists');
    expect(lists.single['name'], 'Trackers and ads');
  });
}

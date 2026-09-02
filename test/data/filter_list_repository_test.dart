import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => database.close());

  DateTime fixedNow() => DateTime.utc(2026, 8, 30, 9);

  test('a fresh database seeds the three lists from the spec', () async {
    await seedFilterListsIfEmpty(database, now: fixedNow);
    final lists = await SqliteFilterListRepository(database).all();

    expect(lists.map((l) => l.name), ['Trackers and ads', 'Cookie notices', 'Social embeds']);
    expect(lists.map((l) => l.ruleCount), [84102, 11430, 2908]);
    expect(lists.map((l) => l.enabled), [true, true, false]);
  });

  test('seeding twice does not duplicate anything', () async {
    await seedFilterListsIfEmpty(database, now: fixedNow);
    await seedFilterListsIfEmpty(database, now: fixedNow);

    expect((await SqliteFilterListRepository(database).all()).length, 3);
  });

  test('toggling persists the enabled bit without touching anything else', () async {
    await seedFilterListsIfEmpty(database, now: fixedNow);
    final repo = SqliteFilterListRepository(database);
    final socialEmbeds = (await repo.all()).firstWhere((l) => l.name == 'Social embeds');

    await repo.setEnabled(socialEmbeds.id, true);
    final reloaded = (await repo.all()).firstWhere((l) => l.id == socialEmbeds.id);

    expect(reloaded.enabled, isTrue);
    expect(reloaded.ruleCount, socialEmbeds.ruleCount);
  });

  // A fresh-create test passes even when onUpgrade is broken, because
  // onCreate builds the table directly. An installed database is on version
  // 2, so the v2 -> v3 step is the one that actually has to work.
  test('an existing version-2 database upgrades to 3 without losing its rows', () async {
    final dir = await Directory.systemTemp.createTemp('container-migration-v3');
    final path = '${dir.path}/store.db';

    // Stand up a database exactly as schema version 2 left it: workspaces
    // and sites, no filter_lists.
    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        singleInstance: false,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE workspaces (
              id            TEXT PRIMARY KEY,
              name          TEXT    NOT NULL,
              marker_index  INTEGER NOT NULL,
              storage_rule  TEXT    NOT NULL,
              require_pin   INTEGER NOT NULL DEFAULT 0,
              show_in_decoy INTEGER NOT NULL DEFAULT 0,
              sort_index    INTEGER NOT NULL DEFAULT 0
            )
          ''');
          await db.insert('workspaces', {
            'id': 'ws-personal',
            'name': 'Personal',
            'marker_index': 0,
            'storage_rule': 'keep',
            'require_pin': 0,
            'show_in_decoy': 0,
            'sort_index': 0,
          });
        },
      ),
    );
    await v2.close();

    final upgraded =
        await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    addTearDown(() async {
      await upgraded.close();
      await dir.delete(recursive: true);
    });

    expect(await upgraded.db.getVersion(), AppDatabase.schemaVersion);

    // The new table exists and works...
    await seedFilterListsIfEmpty(upgraded, now: fixedNow);
    expect((await SqliteFilterListRepository(upgraded).all()).length, 3);

    // ...and the pre-existing row survived the upgrade.
    final workspaces = await upgraded.db.query('workspaces');
    expect(workspaces.single['name'], 'Personal');
  });
}

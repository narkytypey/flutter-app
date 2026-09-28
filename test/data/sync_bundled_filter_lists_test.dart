// test/data/sync_bundled_filter_lists_test.dart
import 'dart:typed_data';

import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/data/services/encrypted_database.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'bundled_filter_lists_test.dart' show FakeBundle;

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  final lists = [
    BundledFilterList(
      id: 'fl-a', name: 'List A', enabledByDefault: true,
      category: FilterListCategory.trackers, asset: 'a.txt',
      updatedAt: DateTime.utc(2026, 9, 28),
    ),
    BundledFilterList(
      id: 'fl-b', name: 'List B', enabledByDefault: false,
      category: FilterListCategory.ads, asset: 'b.txt',
      updatedAt: DateTime.utc(2026, 9, 20),
    ),
  ];
  final rules = BundledFilterRules(
    FakeBundle({'a.txt': '||1.example^\n||2.example^\n', 'b.txt': '||3.example^\n'}),
    lists: lists,
  );

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => database.close());

  Future<List<FilterList>> all() => SqliteFilterListRepository(database).all();

  test('a vault without lists gets every bundled list with its default switch', () async {
    await syncBundledFilterLists(database, rules);

    final synced = await all();
    expect(synced.map((l) => l.id), ['fl-a', 'fl-b']);
    expect(synced.map((l) => l.name), ['List A', 'List B']);
    expect(synced.map((l) => l.ruleCount), [2, 1]);
    expect(synced.map((l) => l.enabled), [true, false]);
    expect(synced.map((l) => l.category), [FilterListCategory.trackers, FilterListCategory.ads]);
    expect(synced.first.updatedAt, DateTime.utc(2026, 9, 28));
  });

  // Review Focus 1: rows already present — the spec's old mock seed, or a
  // switch the user flipped — keep their switch; everything else is the
  // bundle's.
  test('an existing row is refreshed from the bundle and keeps its switch', () async {
    await database.db.insert('filter_lists', {
      'id': 'fl-a', 'name': 'Old name', 'rule_count': 84102,
      'updated_at': 0, 'enabled': 0, 'category': 'ads',
    });

    await syncBundledFilterLists(database, rules);

    final a = (await all()).firstWhere((l) => l.id == 'fl-a');
    expect(a.name, 'List A');
    expect(a.ruleCount, 2);
    expect(a.updatedAt, DateTime.utc(2026, 9, 28));
    expect(a.category, FilterListCategory.trackers);
    expect(a.enabled, isFalse);
  });

  test('syncing twice changes nothing', () async {
    await syncBundledFilterLists(database, rules);
    await SqliteFilterListRepository(database).setEnabled('fl-b', true);
    await syncBundledFilterLists(database, rules);

    final synced = await all();
    expect(synced, hasLength(2));
    expect(synced.map((l) => l.enabled), [true, true]);
  });

  test('a row the bundle does not know is left alone', () async {
    await database.db.insert('filter_lists', {
      'id': 'fl-legacy', 'name': 'Legacy', 'rule_count': 5,
      'updated_at': 0, 'enabled': 1, 'category': 'trackers',
    });

    await syncBundledFilterLists(database, rules);

    final legacy = (await all()).firstWhere((l) => l.id == 'fl-legacy');
    expect(legacy.name, 'Legacy');
    expect(legacy.ruleCount, 5);
  });

  test('opening a vault syncs its lists', () async {
    final opened = await openEncrypted(
      path: inMemoryDatabasePath,
      dataKey: Uint8List(32),
      filterRules: rules,
      factory: databaseFactoryFfi,
    );
    addTearDown(opened.close);

    expect((await SqliteFilterListRepository(opened).all()).map((l) => l.id), ['fl-a', 'fl-b']);
  });

  // A broken bundle must not lock the owner out of their vault. Opening a
  // site still fails closed later (Task 3), so nothing loads unfiltered.
  test('a list that cannot be read does not stop the vault opening', () async {
    final broken = BundledFilterRules(FakeBundle({}), lists: lists);

    final opened = await openEncrypted(
      path: inMemoryDatabasePath,
      dataKey: Uint8List(32),
      filterRules: broken,
      factory: databaseFactoryFfi,
    );
    addTearDown(opened.close);

    expect(await SqliteFilterListRepository(opened).all(), isEmpty);
  });
}

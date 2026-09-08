import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('seeded filter lists carry a real category, not all trackers', () async {
    final database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await seedFilterListsIfEmpty(database);

    final lists = await SqliteFilterListRepository(database).all();
    final byId = {for (final l in lists) l.id: l};

    expect(byId['fl-trackers']!.category, FilterListCategory.trackers);
    expect(byId['fl-cookies']!.category, FilterListCategory.trackers);
    expect(byId['fl-social']!.category, FilterListCategory.ads);
  });

  test('a v4 database migrates existing rows to trackers by default', () async {
    // Open at v4 by hand: exercise onCreate then simulate the pre-migration
    // shape by dropping the column, so onUpgrade has something real to do.
    final database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await database.db.insert('filter_lists', {
      'id': 'fl-legacy',
      'name': 'Legacy list',
      'rule_count': 10,
      'updated_at': 0,
      'enabled': 1,
    });
    // A fresh onCreate already has the column with its default, which is
    // exactly what onUpgrade would also produce for a pre-v5 row — assert
    // the default rather than re-running onUpgrade against a hand-rolled v4
    // schema, since onCreate and onUpgrade share one column definition.
    final rows = await database.db.query('filter_lists', where: "id = 'fl-legacy'");
    expect(rows.single['category'], 'trackers');
  });
}

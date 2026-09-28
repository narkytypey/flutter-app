import '../../domain/models/filter_list.dart' show FilterList, FilterListCategory;
import '../../domain/repositories/filter_list_repository.dart';
import '../services/app_database.dart';
import '../services/bundled_filter_lists.dart' show BundledFilterRules;

class SqliteFilterListRepository implements FilterListRepository {
  SqliteFilterListRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<FilterList>> all() async {
    final rows = await _database.db.query('filter_lists', orderBy: 'rowid');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    await _database.db.update(
      'filter_lists',
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  FilterList _fromRow(Map<String, Object?> row) => FilterList(
        id: row['id']! as String,
        name: row['name']! as String,
        ruleCount: row['rule_count']! as int,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row['updated_at']! as int,
            isUtc: true),
        enabled: (row['enabled']! as int) == 1,
        category: (row['category']! as String) == 'ads'
            ? FilterListCategory.ads
            : FilterListCategory.trackers,
      );
}

/// Brings [database]'s `filter_lists` rows into line with the lists that
/// ship in the app. A missing list is added with its default switch; an
/// existing one takes the bundle's name, rule count, date and category but
/// keeps the switch the owner set. Rows the bundle does not know are left
/// alone. Runs on every vault open, so an app update reaches every vault —
/// the decoy included, which is its own store.
Future<void> syncBundledFilterLists(AppDatabase database, BundledFilterRules rules) async {
  final db = database.db;
  for (final list in rules.lists) {
    final fields = <String, Object>{
      'name': list.name,
      'rule_count': await rules.ruleCount(list),
      'updated_at': list.updatedAt.millisecondsSinceEpoch,
      'category': list.category.name,
    };
    final updated =
        await db.update('filter_lists', fields, where: 'id = ?', whereArgs: [list.id]);
    if (updated == 0) {
      await db.insert('filter_lists', {
        'id': list.id,
        ...fields,
        'enabled': list.enabledByDefault ? 1 : 0,
      });
    }
  }
}

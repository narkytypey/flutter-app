import '../../domain/models/filter_list.dart';
import '../../domain/repositories/filter_list_repository.dart';
import '../services/app_database.dart';

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
      );
}

/// Seeds the three lists spec `10d` shows. Real values need a downloaded
/// filter list this app does not yet fetch (see this plan's Global
/// Constraints on "no network requests"); these are the spec's own numbers.
Future<void> seedFilterListsIfEmpty(
  AppDatabase database, {
  DateTime Function() now = DateTime.now,
}) async {
  final db = database.db;
  final existing = await db.query('filter_lists', limit: 1);
  if (existing.isNotEmpty) return;

  final updatedAt =
      now().toUtc().subtract(const Duration(days: 2)).millisecondsSinceEpoch;
  final rows = <Map<String, Object?>>[
    {'id': 'fl-trackers', 'name': 'Trackers and ads', 'rule_count': 84102, 'updated_at': updatedAt, 'enabled': 1},
    {'id': 'fl-cookies', 'name': 'Cookie notices', 'rule_count': 11430, 'updated_at': updatedAt, 'enabled': 1},
    {'id': 'fl-social', 'name': 'Social embeds', 'rule_count': 2908, 'updated_at': updatedAt, 'enabled': 0},
  ];
  for (final row in rows) {
    await db.insert('filter_lists', row);
  }
}

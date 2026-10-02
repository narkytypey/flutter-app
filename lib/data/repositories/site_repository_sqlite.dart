import '../../domain/repositories/repositories.dart';
import '../../domain/models/site.dart';
import '../services/app_database.dart';

class SqliteSiteRepository implements SiteRepository {
  const SqliteSiteRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Site>> inWorkspace(String workspaceId) async {
    final rows = await _database.db.query(
      'sites',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'sort_index',
    );
    return rows.map(siteFromRow).toList();
  }

  @override
  Future<List<Site>> all() async {
    final rows = await _database.db.query('sites', orderBy: 'sort_index');
    return rows.map(siteFromRow).toList();
  }

  @override
  Future<Site?> byId(String id) async {
    final rows =
        await _database.db.query('sites', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return siteFromRow(rows.first);
  }

  @override
  Future<void> upsert(Site site) async {
    await upsertRow(_database.db, 'sites', siteToRow(site));
  }

  @override
  Future<void> delete(String id) async {
    await _database.db.delete('sites', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> touch(String id, DateTime at) async {
    await _database.db.update(
      'sites',
      {'last_visited_at': at.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<DateTime?> lastWorked(String id) async {
    final rows = await _database.db.query('sites',
        columns: ['last_worked_at'], where: 'id = ?', whereArgs: [id]);
    final ms = rows.isEmpty ? null : rows.first['last_worked_at'] as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  Future<void> setLastWorked(String id, DateTime? at) async {
    await _database.db.update(
      'sites',
      {'last_worked_at': at?.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

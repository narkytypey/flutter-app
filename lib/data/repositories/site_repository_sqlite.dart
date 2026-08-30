import 'package:sqflite_sqlcipher/sqflite.dart';

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
  Future<void> upsert(Site site) async {
    await _database.db.insert(
      'sites',
      siteToRow(site),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
}

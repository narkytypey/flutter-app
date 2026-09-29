import '../../domain/models/workspace.dart';
import '../../domain/repositories/repositories.dart';
import '../services/app_database.dart';

class SqliteWorkspaceRepository implements WorkspaceRepository {
  const SqliteWorkspaceRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Workspace>> all() async {
    final rows = await _database.db.query('workspaces', orderBy: 'sort_index');
    return rows.map(workspaceFromRow).toList();
  }

  @override
  Future<Workspace?> byId(String id) async {
    final rows = await _database.db
        .query('workspaces', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : workspaceFromRow(rows.first);
  }

  @override
  Future<void> upsert(Workspace workspace) async {
    await upsertRow(_database.db, 'workspaces', workspaceToRow(workspace));
  }

  @override
  Future<void> delete(String id) async {
    await _database.db.delete('workspaces', where: 'id = ?', whereArgs: [id]);
  }
}

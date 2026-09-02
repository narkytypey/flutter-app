import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../domain/models/user_script.dart';
import '../../domain/repositories/script_repository.dart';
import '../services/app_database.dart';

class SqliteScriptRepository implements ScriptRepository {
  SqliteScriptRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<UserScript>> all() async {
    final rows = await _database.db.query('scripts', orderBy: 'rowid');
    final scripts = <UserScript>[];
    for (final row in rows) {
      scripts.add(await _fromRow(row));
    }
    return scripts;
  }

  @override
  Future<UserScript?> byId(String id) async {
    final rows =
        await _database.db.query('scripts', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.single);
  }

  @override
  Future<void> upsert(UserScript script) async {
    await _database.db.transaction((txn) async {
      await txn.insert(
        'scripts',
        {
          'id': script.id,
          'name': script.name,
          'kind': script.kind.name,
          'code': script.code,
          'run_at_document_start': script.runAtDocumentStart ? 1 : 0,
          'enabled': script.enabled ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn
          .delete('script_sites', where: 'script_id = ?', whereArgs: [script.id]);
      for (final siteId in script.appliedSiteIds) {
        await txn
            .insert('script_sites', {'script_id': script.id, 'site_id': siteId});
      }
    });
  }

  @override
  Future<void> delete(String id) async {
    await _database.db.delete('scripts', where: 'id = ?', whereArgs: [id]);
  }

  Future<UserScript> _fromRow(Map<String, Object?> row) async {
    final siteRows = await _database.db.query(
      'script_sites',
      columns: ['site_id'],
      where: 'script_id = ?',
      whereArgs: [row['id']],
    );
    return UserScript(
      id: row['id']! as String,
      name: row['name']! as String,
      kind: ScriptKind.values.byName(row['kind']! as String),
      code: row['code']! as String,
      runAtDocumentStart: (row['run_at_document_start']! as int) == 1,
      enabled: (row['enabled']! as int) == 1,
      appliedSiteIds: siteRows.map((r) => r['site_id']! as String).toList(),
    );
  }
}

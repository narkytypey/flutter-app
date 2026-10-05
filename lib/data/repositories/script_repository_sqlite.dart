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
      // In place, not REPLACE: script_sites cascades from scripts.
      await upsertRow(
        txn,
        'scripts',
        {
          'id': script.id,
          'name': script.name,
          'kind': script.kind.name,
          'code': script.code,
          'run_at_document_start': script.runAtDocumentStart ? 1 : 0,
          'enabled': script.enabled ? 1 : 0,
        },
      );
      await txn
          .delete('script_sites', where: 'script_id = ?', whereArgs: [script.id]);
      // A site removed since the editor loaded would fail the foreign key
      // and abort the whole save; it is dropped instead.
      final wanted = script.appliedSiteIds.toSet();
      final existing = wanted.isEmpty
          ? const <String>{}
          : {
              for (final row in await txn.query('sites',
                  columns: ['id'],
                  where: 'id IN (${List.filled(wanted.length, '?').join(', ')})',
                  whereArgs: wanted.toList()))
                row['id']! as String,
            };
      for (final siteId in script.appliedSiteIds.where(existing.contains).toSet()) {
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

import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../domain/repositories/repositories.dart';
import '../services/app_database.dart';

class SqliteSettingsRepository implements SettingsRepository {
  const SqliteSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Future<bool> getBool(String key, {bool fallback = false}) async {
    final rows = await _database.db
        .query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return fallback;
    return rows.first['value'] == '1';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _database.db.insert(
      'app_settings',
      {'key': key, 'value': value ? '1' : '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

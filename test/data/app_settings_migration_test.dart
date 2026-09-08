import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('a fresh database has the app_settings table, defaulting to false',
      () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final repository = SqliteSettingsRepository(database);

    expect(await repository.getBool('biometrics_enabled'), isFalse);
  });

  test('setBool persists, and existing tables are unaffected', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final repository = SqliteSettingsRepository(database);

    await repository.setBool('biometrics_enabled', true);

    expect(await repository.getBool('biometrics_enabled'), isTrue);
    await seedIfEmpty(database);
    final workspaces = await database.db.query('workspaces');
    expect(workspaces, isNotEmpty, reason: 'seeding must still work post-migration');
  });

  test('setBool can flip a key back to false', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final repository = SqliteSettingsRepository(database);

    await repository.setBool('biometrics_enabled', true);
    await repository.setBool('biometrics_enabled', false);

    expect(await repository.getBool('biometrics_enabled'), isFalse);
  });
}

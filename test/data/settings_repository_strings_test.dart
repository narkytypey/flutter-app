import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<SqliteSettingsRepository> repository() async => SqliteSettingsRepository(
      await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi));

  test('an unset string reads as the fallback', () async {
    final settings = await repository();
    expect(await settings.getString('search_engine'), isNull);
    expect(await settings.getString('search_engine', fallback: 'duckDuckGo'), 'duckDuckGo');
  });

  test('setString persists, and a second set replaces the first', () async {
    final settings = await repository();
    await settings.setString('search_engine', 'startpage');
    await settings.setString('search_engine', 'braveSearch');
    expect(await settings.getString('search_engine'), 'braveSearch');
  });

  test('string and bool settings live side by side', () async {
    final settings = await repository();
    await settings.setBool('biometrics_enabled', true);
    await settings.setString('search_engine', 'startpage');
    expect(await settings.getBool('biometrics_enabled'), isTrue);
    expect(await settings.getString('search_engine'), 'startpage');
  });
}

import 'package:container/data/services/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('a seeded row carries the documented shield defaults', () async {
    final database = await AppDatabase.open(
      path: inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    await seedIfEmpty(database);
    final db = database.db;

    final rows = await db.query('sites', limit: 1);
    expect(rows, isNotEmpty);
    final site = siteFromRow(rows.first);

    // Spec 2a: "HARDWARE · ALL OFF BY DEFAULT".
    expect(site.allowCamera, isFalse);
    expect(site.allowMicrophone, isFalse);
    expect(site.allowLocation, isFalse);
    expect(site.allowClipboard, isFalse);

    // Shields the spec draws as on.
    expect(site.blockWebRtc, isTrue);
    expect(site.blockTrackers, isTrue);
    expect(site.antiFingerprinting, isTrue);

    // Opaque profile id, never derived from the host.
    expect(site.profileId, hasLength(32));
    expect(site.profileId.contains(site.host), isFalse);
  });

  test('two sites never share a profile id', () async {
    expect(newProfileId(), isNot(newProfileId()));
  });
}

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    container = ProviderContainer(overrides: [
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32))),
    ]);
    addTearDown(container.dispose);
  });

  test('decoyEnabledProvider reflects the persisted decoy_configured flag',
      () async {
    expect(await container.read(decoyEnabledProvider.future), isFalse);

    await SqliteSettingsRepository(db).setBool('decoy_configured', true);
    container.invalidate(decoyEnabledProvider);

    expect(await container.read(decoyEnabledProvider.future), isTrue);
  });

  test('decoySiteCountProvider counts only flagged sites', () async {
    await SqliteWorkspaceRepository(db).upsert(const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0,
        storageRule: StorageRule.keep, showInDecoy: true));
    await SqliteSiteRepository(db).upsert(Site(
        id: 's1', workspaceId: 'ws', name: 'News', monogram: 'Nw',
        url: 'https://news.example.com', profileId: newProfileId(),
        showInDecoy: true));
    await SqliteSiteRepository(db).upsert(Site(
        id: 's2', workspaceId: 'ws', name: 'Bank', monogram: 'Bk',
        url: 'https://bank.example.com', profileId: newProfileId(),
        showInDecoy: false));

    expect(await container.read(decoySiteCountProvider.future), 1);
  });
}

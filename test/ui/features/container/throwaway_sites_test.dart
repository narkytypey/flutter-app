import 'dart:typed_data';

import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/features/container/view_models/throwaway_sites.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../shell/session_controller_test.dart' show FakeBiometricService;

const _throwaway = Site(
  id: 't1', workspaceId: 'w', name: 'news.example.org', monogram: 'Nw',
  url: 'https://news.example.org', profileId: 'p-t1',
  cookiePolicy: CookiePolicy.wipeOnExit,
);

void main() {
  // SessionController.build starts a LifecycleController, which reaches for
  // WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  /// An open vault with one throwaway in it.
  Future<ProviderContainer> openVault() async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = ProviderContainer(overrides: [
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.a, database: database, dataKey: Uint8List(32))),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
    ]);
    addTearDown(container.dispose);
    container.read(throwawaySitesProvider.notifier).add(_throwaway);
    expect(container.read(throwawaySitesProvider), [_throwaway]);
    return container;
  }

  test('a 9b lock empties the list', () async {
    final container = await openVault();
    container.read(sessionProvider.notifier).debugHandleReturn(ReturnDestination.board);
    expect(container.read(throwawaySitesProvider), isEmpty);
  });

  test('a 9c lock empties the list', () async {
    final container = await openVault();
    container.read(sessionProvider.notifier).debugHandleReturn(ReturnDestination.pin);
    expect(container.read(throwawaySitesProvider), isEmpty);
  });

  test('panic empties the list', () async {
    final container = await openVault();
    container.read(sessionProvider.notifier).panicked(const PanicReport(sessionsDestroyed: 1));
    expect(container.read(throwawaySitesProvider), isEmpty);
  });

  test('the vault staying open keeps the list; removing one drops only it', () async {
    final container = await openVault();
    // A new SessionOpen on the same database, as turning biometrics on makes.
    container.read(sessionProvider.notifier).setBiometricWrapped(Uint8List.fromList([1, 2, 3]));
    expect(container.read(throwawaySitesProvider), [_throwaway]);

    const other = Site(
      id: 't2', workspaceId: 'w', name: 'elsewhere.example.net', monogram: 'Es',
      url: 'https://elsewhere.example.net', profileId: 'p-t2',
    );
    container.read(throwawaySitesProvider.notifier).add(other);
    container.read(throwawaySitesProvider.notifier).remove('t1');
    expect(container.read(throwawaySitesProvider), [other]);
  });
}

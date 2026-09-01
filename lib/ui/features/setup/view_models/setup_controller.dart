import 'dart:typed_data';

import '../../../../data/services/app_database.dart';
import '../../../../data/services/vault_store.dart';
import '../../../../domain/models/vault.dart';
import '../../../../data/repositories/decoy_provisioner.dart';

/// Opens (or creates) the vault database at [path] under [dataKey]. Injected
/// so this file — and Task 8's `SessionController` — never import
/// `openEncrypted` directly: `main()` wires the real one, tests wire an
/// in-memory one.
typedef VaultOpener = Future<AppDatabase> Function({
  required String path,
  required Uint8List dataKey,
});

/// Where [vault]'s database file lives. Injected for the same reason as
/// [VaultOpener] — this file has no dependency on `session_controller.dart`,
/// which is where the real path convention (`vaultDatabasePath`) is defined.
typedef VaultPath = String Function(VaultId vault);

/// Hands the freshly-opened real vault to whatever owns session state, once
/// setup is done. Injected for the same reason.
typedef SessionOpener = void Function({
  required VaultId vault,
  required AppDatabase database,
});

/// Runs the setup wizard's side effects: provisions both vault slots
/// (always both — an unconfigured decoy must be byte-indistinguishable from
/// a real one, per this plan's Global Constraints), seeds the real vault,
/// copies the chosen sites into the decoy if one was configured, and opens
/// the real vault as the new session.
class SetupController {
  const SetupController({
    required VaultStore vaultStore,
    required VaultOpener openVault,
    required VaultPath pathFor,
    required SessionOpener openSession,
  })  : _vaultStore = vaultStore,
        _openVault = openVault,
        _pathFor = pathFor,
        _openSession = openSession;

  // ignore_for_file: prefer_initializing_formals — an initializing formal
  // requires the parameter name to equal the field name, which would force
  // callers to pass `_vaultStore:` etc. instead of the readable
  // `vaultStore:`/`openVault:`/`pathFor:`/`openSession:` this class's own
  // tests and Task 8's wiring depend on.
  final VaultStore _vaultStore;
  final VaultOpener _openVault;
  final VaultPath _pathFor;
  final SessionOpener _openSession;

  Future<void> complete({required String mainPin, String? decoyPin}) async {
    final mainKey = await _vaultStore.provision(pin: mainPin, vault: VaultId.a);
    final mainDb = await _openVault(path: _pathFor(VaultId.a), dataKey: mainKey);
    await seedIfEmpty(mainDb);

    if (decoyPin != null) {
      final decoyKey =
          await _vaultStore.provision(pin: decoyPin, vault: VaultId.b);
      final decoyDb = await _openVault(path: _pathFor(VaultId.b), dataKey: decoyKey);
      await provisionDecoy(from: mainDb, into: decoyDb);
      await decoyDb.close();
    } else {
      await _vaultStore.provisionUnopenable(VaultId.b);
    }

    _openSession(vault: VaultId.a, database: mainDb);
  }
}

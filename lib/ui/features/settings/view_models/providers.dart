import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/decoy_provisioner.dart' show resyncDecoy;
import '../../../../data/repositories/settings_repository_sqlite.dart';
import '../../../../domain/models/vault.dart';
import '../../../../domain/repositories/repositories.dart' show SettingsRepository;
import '../../../../domain/services/vault_unlocker.dart';
import '../../dashboard/view_models/providers.dart'
    show databaseProvider, siteRepositoryProvider;
import '../../shell/view_models/session_controller.dart'
    show
        biometricServiceProvider,
        sessionProvider,
        SessionOpen,
        vaultStoreProvider,
        cryptoServiceProvider,
        vaultOpenerProvider,
        documentsDirectoryProvider,
        vaultDatabasePath;

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SqliteSettingsRepository(ref.watch(databaseProvider)),
);

/// Backs `SettingsScreen`'s LOCK section biometrics row. Every other row on
/// that screen is still a static placeholder — see this plan's Known Gaps.
final biometricsEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).getBool('biometrics_enabled'),
);

/// Gates whether `SettingsScreen`'s biometrics toggle is interactive at
/// all — no biometric hardware or nothing enrolled means the toggle is
/// shown disabled, not hidden, and the spec deliberately invents no
/// "unavailable" copy for this state.
final biometricsAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(biometricServiceProvider).isAvailable(),
);

/// Backs `SettingsScreen`'s VAULT section visibility. `false` until
/// `SetupController.complete` (this plan's Task 2) has run with a non-null
/// `decoyPin`.
final decoyEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).getBool('decoy_configured'),
);

/// Backs `SettingsScreen`'s "Sites shown in decoy" row. Counts sites in the
/// currently open (real) vault flagged `showInDecoy` — never touches the
/// decoy vault itself, which this session does not have open.
final decoySiteCountProvider = FutureProvider<int>((ref) async {
  final sites = await ref.watch(siteRepositoryProvider).all();
  return sites.where((site) => site.showInDecoy).length;
});

sealed class DecoyResyncOutcome {
  const DecoyResyncOutcome();
}

class DecoyResyncSucceeded extends DecoyResyncOutcome {
  const DecoyResyncSucceeded();
}

class DecoyResyncRejected extends DecoyResyncOutcome {
  const DecoyResyncRejected(this.triesLeft);
  final int triesLeft;
}

class DecoyResyncThrottled extends DecoyResyncOutcome {
  const DecoyResyncThrottled(this.remaining);
  final Duration remaining;
}

class SettingsController {
  SettingsController(this._ref);

  final Ref _ref;

  /// Turning this on happens from inside an already-open, already-
  /// authenticated session, so no PIN re-entry is needed — `SessionOpen`
  /// already holds the raw data key this wraps. Turning it off clears the
  /// in-memory ciphertext immediately, rather than waiting for the next
  /// time the app backgrounds.
  Future<void> setBiometricsEnabled(bool value) async {
    final biometrics = _ref.read(biometricServiceProvider);
    final repository = _ref.read(settingsRepositoryProvider);

    if (value) {
      await biometrics.generateKeyPair();
      final session = _ref.read(sessionProvider);
      if (session is SessionOpen) {
        final wrapped = await biometrics.wrap(session.dataKey);
        _ref.read(sessionProvider.notifier).setBiometricWrapped(wrapped);
      }
    } else {
      await biometrics.destroyKeyPair();
      _ref.read(sessionProvider.notifier).setBiometricWrapped(null);
    }

    await repository.setBool('biometrics_enabled', value);
    _ref.invalidate(biometricsEnabledProvider);
  }

  /// Verifies [pin] against both vault slots the same way the lock screen
  /// does, sharing its attempt-gate — a wrong guess here locks out the lock
  /// screen too, and vice versa, rather than opening a second independent
  /// brute-force surface. A match against the vault already open this
  /// session (re-entering the main PIN by mistake) is folded into the same
  /// generic rejection as a non-match: this is the same PIN-guessing
  /// surface [VaultUnlocker] itself never distinguishes, so this method
  /// does not either. Only a match against the *other* vault opens it, runs
  /// [resyncDecoy], and closes it again — its key and connection never
  /// outlive this one call.
  Future<DecoyResyncOutcome> resyncDecoyVault(String pin) async {
    final vaultStore = _ref.read(vaultStoreProvider);
    final unlocker = VaultUnlocker(_ref.read(cryptoServiceProvider));
    final now = DateTime.now();
    final beforeGate = await vaultStore.gate();
    final slots = await vaultStore.slots();
    final outcome = await unlocker.attempt(
      pin: pin,
      slots: slots,
      gate: beforeGate,
      now: now,
    );

    final session = _ref.read(sessionProvider);
    if (session is! SessionOpen) {
      return DecoyResyncRejected(beforeGate.triesLeft);
    }

    switch (outcome) {
      case Throttled(:final remaining):
        return DecoyResyncThrottled(remaining);
      case Rejected(:final gate):
        await vaultStore.saveGate(gate);
        return DecoyResyncRejected(gate.triesLeft);
      case Unlocked(:final vault, :final dataKey, :final gate):
        if (vault == session.vault) {
          final failedGate = beforeGate.recordFailure(now);
          await vaultStore.saveGate(failedGate);
          return DecoyResyncRejected(failedGate.triesLeft);
        }
        await vaultStore.saveGate(gate);
        final decoyDatabase = await _ref.read(vaultOpenerProvider)(
          path: vaultDatabasePath(_ref.read(documentsDirectoryProvider), vault),
          dataKey: dataKey,
        );
        await resyncDecoy(from: session.database, into: decoyDatabase);
        await decoyDatabase.close();
        _ref.invalidate(decoySiteCountProvider);
        return const DecoyResyncSucceeded();
    }
  }
}

final settingsControllerProvider = Provider((ref) => SettingsController(ref));

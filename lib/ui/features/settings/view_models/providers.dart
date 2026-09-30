import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/decoy_provisioner.dart' show resyncDecoy;
import '../../../../data/repositories/settings_repository_sqlite.dart';
import '../../../../domain/models/lock_state.dart';
import '../../../../domain/models/search_engine.dart';
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

/// Spec §6.7: the open vault's `search_engine` setting, stored as the enum
/// name. Per vault like every other setting; the row looks the same in both.
final searchEngineProvider = FutureProvider<SearchEngine>((ref) async {
  final stored = await ref.watch(settingsRepositoryProvider).getString('search_engine');
  return SearchEngine.fromStored(stored);
});

/// The open vault's Auto-lock choice (user's ruling, 2026-09-30), stored as
/// whole minutes in `auto_lock`.
final autoLockProvider = FutureProvider<AutoLockPolicy>((ref) async {
  final stored = await ref.watch(settingsRepositoryProvider).getString('auto_lock');
  return AutoLockPolicy.fromStored(stored);
});

/// Settings' "Trigger by flipping face down" for the open vault (user's
/// ruling, 2026-09-30): off until turned on.
final panicOnFlipProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).getBool('panic_on_flip'),
);

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

/// What Change main PIN's steps come to (user's ruling, 2026-09-30).
sealed class ChangePinOutcome {
  const ChangePinOutcome();
}

/// Step 1: the PIN entered is this vault's.
class ChangePinVerified extends ChangePinOutcome {
  const ChangePinVerified();
}

/// The vault now opens with the new PIN.
class ChangePinDone extends ChangePinOutcome {
  const ChangePinDone();
}

/// Not this vault's PIN: a failed attempt, shared with the lock screen.
class ChangePinRejected extends ChangePinOutcome {
  const ChangePinRejected(this.triesLeft);
  final int triesLeft;
}

class ChangePinThrottled extends ChangePinOutcome {
  const ChangePinThrottled(this.remaining);
  final Duration remaining;
}

/// The new PIN would also open the other vault. Nothing changed.
class ChangePinClash extends ChangePinOutcome {
  const ChangePinClash();
}

class SettingsController {
  SettingsController(this._ref);

  final Ref _ref;

  /// Turning this on happens from inside an already-open, already-
  /// authenticated session, so no PIN re-entry is needed — `SessionOpen`
  /// already holds the raw data key this wraps. Turning it off clears the
  /// in-memory ciphertext immediately, rather than waiting for the next
  /// time the app backgrounds.
  ///
  /// Only the open vault's Keystore key is made or destroyed: turning this
  /// off in one vault never touches the other vault's key.
  Future<void> setBiometricsEnabled(bool value) async {
    final biometrics = _ref.read(biometricServiceProvider);
    // Throws if no vault is open, so the cast below cannot fail.
    final repository = _ref.read(settingsRepositoryProvider);
    final vault = (_ref.read(sessionProvider) as SessionOpen).vault;

    if (value) {
      await biometrics.generateKeyPair(vault);
      final session = _ref.read(sessionProvider);
      if (session is SessionOpen && session.vault == vault) {
        final wrapped = await biometrics.wrap(vault, session.dataKey);
        _ref.read(sessionProvider.notifier).setBiometricWrapped(wrapped);
      }
    } else {
      await biometrics.destroyKeyPair(vault);
      _ref.read(sessionProvider.notifier).setBiometricWrapped(null);
    }

    await repository.setBool('biometrics_enabled', value);
    _ref.invalidate(biometricsEnabledProvider);
  }

  /// Saves the open vault's choice, and applies it from the next time the app
  /// goes to the background.
  Future<void> setAutoLock(AutoLockPolicy policy) async {
    await _ref.read(settingsRepositoryProvider).setString('auto_lock', policy.stored);
    _ref.read(sessionProvider.notifier).setAutoLock(policy);
    _ref.invalidate(autoLockProvider);
  }

  Future<void> setPanicOnFlip(bool value) async {
    await _ref.read(settingsRepositoryProvider).setBool('panic_on_flip', value);
    _ref.invalidate(panicOnFlipProvider);
  }

  Future<void> setSearchEngine(SearchEngine engine) async {
    await _ref.read(settingsRepositoryProvider).setString('search_engine', engine.name);
    _ref.invalidate(searchEngineProvider);
  }

  /// Change main PIN, step 1: whether [pin] opens the vault open now. Checked
  /// like the lock screen checks a PIN, on the same attempt gate, so this is
  /// no second surface for guessing, except that a match never resets the
  /// gate. The other vault's PIN is rejected like any wrong one.
  Future<ChangePinOutcome> verifyCurrentPin(String pin) async {
    final checked = await _checkCurrent(pin);
    return checked.$1;
  }

  /// Moves the open vault to [replacement], after checking [current] again.
  ///
  /// A [replacement] that would also open the other vault is refused
  /// ([ChangePinClash]), since one PIN would then open only whichever vault is
  /// tried first. The refusal tells the person that the PIN opens something,
  /// so it is recorded as a failed attempt, exactly as trying that PIN on the
  /// lock screen would be: from a coerced decoy session this is no faster a
  /// way to guess the real vault's PIN than the lock screen.
  Future<ChangePinOutcome> changePin({
    required String current,
    required String replacement,
  }) async {
    final (outcome, dataKey) = await _checkCurrent(current);
    if (outcome is! ChangePinVerified) return outcome;
    final vaultStore = _ref.read(vaultStoreProvider);
    final crypto = _ref.read(cryptoServiceProvider);
    final vault = (_ref.read(sessionProvider) as SessionOpen).vault;
    final other = VaultId.values.firstWhere((v) => v != vault);

    final otherSlot = (await vaultStore.slots())[other.index];
    final kek = await crypto.deriveKek(replacement, otherSlot.salt);
    if (await crypto.unwrap(kek, otherSlot.wrappedKey) != null) {
      await vaultStore.saveGate((await vaultStore.gate()).recordFailure(DateTime.now()));
      return const ChangePinClash();
    }
    await vaultStore.rewrap(vault: vault, pin: replacement, dataKey: dataKey!);
    return const ChangePinDone();
  }

  /// [ChangePinVerified] with the open vault's data key, or why not.
  Future<(ChangePinOutcome, Uint8List?)> _checkCurrent(String pin) async {
    final vaultStore = _ref.read(vaultStoreProvider);
    final now = DateTime.now();
    final beforeGate = await vaultStore.gate();
    final outcome = await VaultUnlocker(_ref.read(cryptoServiceProvider)).attempt(
      pin: pin,
      slots: await vaultStore.slots(),
      gate: beforeGate,
      now: now,
    );
    final session = _ref.read(sessionProvider);
    if (session is! SessionOpen) return (ChangePinRejected(beforeGate.triesLeft), null);

    switch (outcome) {
      case Throttled(:final remaining):
        return (ChangePinThrottled(remaining), null);
      case Rejected(:final gate):
        await vaultStore.saveGate(gate);
        return (ChangePinRejected(gate.triesLeft), null);
      case Unlocked(:final vault, :final dataKey):
        if (vault != session.vault) {
          final failed = beforeGate.recordFailure(now);
          await vaultStore.saveGate(failed);
          return (ChangePinRejected(failed.triesLeft), null);
        }
        // The counter is not reset (the unlocker's `gate` is): only a real
        // unlock resets it. Otherwise "verify, then try a PIN as the new one"
        // would leave one failure per round, and never reach the lockout.
        return (const ChangePinVerified(), dataKey);
    }
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

final settingsControllerProvider = Provider<SettingsController>((ref) => SettingsController(ref));

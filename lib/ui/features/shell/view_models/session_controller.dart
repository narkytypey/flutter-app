import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../data/repositories/settings_repository_sqlite.dart';
import '../../../../data/services/android_biometric_service.dart';
import '../../../../data/services/android_crypto_service.dart';
import '../../../../data/services/app_database.dart';
import '../../../../data/services/encrypted_database.dart';
import '../../../../data/services/vault_store.dart';
import '../../../../domain/models/attempt_gate.dart';
import '../../../../domain/models/lock_state.dart';
import '../../../../domain/models/vault.dart';
import '../../../../domain/services/biometric_service.dart';
import '../../../../domain/services/crypto_service.dart';
import '../../../../domain/services/panic_service.dart';
import '../../../../domain/services/vault_unlocker.dart';
import '../../container/view_models/open_containers.dart' show openContainerCountProvider;
import '../../container/view_models/providers.dart' show containerEngineProvider;
import '../../lock/views/lock_body.dart' show LockMood;
import '../../setup/view_models/setup_controller.dart';
import 'lifecycle_controller.dart';

/// Which of the two vaults, if either, is open. `AppGate` switches on this
/// directly (`SessionUnconfigured()`, `SessionLocked()`, `SessionOpen()`),
/// so it is a plain synchronous value, never wrapped in `AsyncValue` — see
/// `initialSessionProvider` below for how the one genuinely async step (does
/// `meta.bin` exist yet?) is kept out of this class's `build()`.
sealed class Session {
  const Session();
}

/// No `meta.bin` on disk: neither vault has ever been provisioned.
class SessionUnconfigured extends Session {
  const SessionUnconfigured();
}

/// A vault exists but is not open right now. [mood] drives which copy
/// `LockBody` shows. [lockDeadline] is set only while [mood] is
/// [LockMood.welcomeBack] — `LockScreen` ticks its own timer against it and
/// calls [SessionController.graceExpired] once it passes; this class never
/// runs a `Timer` of its own.
///
/// [biometricVault] and [biometricWrappedKey] are non-null only while
/// [mood] is [LockMood.welcomeBack] and biometrics was enabled for the
/// vault that just backgrounded — never during a cold lock. This is what
/// makes biometric unlock resume-only: nothing here can open a vault this
/// session hasn't already opened once with a PIN.
class SessionLocked extends Session {
  const SessionLocked({
    required this.mood,
    required this.gate,
    this.openSessionCount = 0,
    this.lockDeadline,
    this.biometricVault,
    this.biometricWrappedKey,
    this.lockedAfter = AutoLockPolicy.oneMinute,
  });

  final LockMood mood;
  final AttemptGate gate;
  final int openSessionCount;
  final DateTime? lockDeadline;
  final VaultId? biometricVault;
  final Uint8List? biometricWrappedKey;

  /// The Auto-lock choice that locked the vault, for `9c`'s line. Only
  /// meaningful for [LockMood.welcomeBack] and [LockMood.afterTimeout].
  final AutoLockPolicy lockedAfter;
}

/// A vault is open. Read by `databaseProvider` below — nothing else in the
/// app ever asks which vault that is.
///
/// [dataKey] is not a new exposure: the SQLCipher connection [database]
/// already holds the equivalent key material resident for as long as the
/// session is open, so a second reference to the same bytes here adds
/// nothing. [biometricWrappedKey], once set, is ciphertext the vault's
/// public Keystore key produced — safe to hold indefinitely, since reading
/// it back requires a successful fingerprint.
class SessionOpen extends Session {
  const SessionOpen({
    required this.vault,
    required this.database,
    required this.dataKey,
    this.biometricWrappedKey,
  });

  final VaultId vault;
  final AppDatabase database;
  final Uint8List dataKey;
  final Uint8List? biometricWrappedKey;
}

/// Panic has run: no store, no keys, nothing to open. `3c` renders [report].
///
/// This is a state, not an action — the destruction itself belongs to
/// `PanicService` (Plan 3 Task 9 implements it), and this class only records
/// that it finished. Keeping the sequence out of the controller is what lets
/// the ordering in `PanicService`'s doc comment stay in one place instead of
/// being split across a service and a `Notifier`.
class SessionPanicked extends Session {
  const SessionPanicked(this.report);

  final PanicReport report;
}

/// Overridden in `main()` once `VaultStore.exists`/`.gate()` — the one
/// genuinely async startup check — has resolved, so `SessionController`'s
/// own `build()` can stay synchronous.
final initialSessionProvider = Provider<Session>(
  (ref) =>
      throw StateError('initialSessionProvider must be overridden in main()'),
);

final cryptoServiceProvider =
    Provider<CryptoService>((ref) => const AndroidCryptoService());

final biometricServiceProvider =
    Provider<BiometricService>((ref) => const AndroidBiometricService());

final documentsDirectoryProvider = Provider<Directory>(
  (ref) =>
      throw StateError('documentsDirectoryProvider must be overridden in main()'),
);

final vaultStoreProvider = Provider<VaultStore>(
  (ref) => throw StateError('vaultStoreProvider must be overridden in main()'),
);

/// Defaults to the real `openEncrypted`; tests override it with an
/// in-memory factory, since `openEncrypted` itself talks to the real
/// SQLCipher platform channel and cannot run on a test host.
final vaultOpenerProvider = Provider<VaultOpener>((ref) => openEncrypted);

/// `vaultFileName` takes a `VaultId` as of Task 4 Step 6, which retired
/// Plan 1's parallel `Vault` enum (cross-plan issue #3). There is one enum
/// now and nothing left to bridge.
String vaultDatabasePath(Directory documents, VaultId vault) =>
    p.join(documents.path, vaultFileName(vault));

final sessionProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);

class SessionController extends Notifier<Session> {
  late final LifecycleController _lifecycle;

  /// `MainActivity` says when its runtime permission dialog opens and closes.
  static const _systemDialog =
      MethodChannel('com.mono.container/system_dialog');

  VaultStore get _vaultStore => ref.read(vaultStoreProvider);
  VaultUnlocker get _unlocker => VaultUnlocker(ref.read(cryptoServiceProvider));

  @override
  Session build() {
    _lifecycle = LifecycleController(
      policy: AutoLockPolicy.oneMinute,
      // FLAG_SECURE, set for the process lifetime in MainActivity, already
      // blanks the recents preview; there is nothing further for Dart to do
      // here yet.
      onMaskChanged: (_) {},
      onReturn: _handleReturn,
    )..start();
    _systemDialog.setMethodCallHandler((call) async {
      if (call.method == 'showing') {
        _lifecycle.systemDialogShowing = call.arguments as bool;
      }
    });
    ref.onDispose(() {
      _systemDialog.setMethodCallHandler(null);
      _lifecycle.stop();
    });
    return ref.watch(initialSessionProvider);
  }

  /// Called by `PanicService` once its sequence has completed. Terminal: no
  /// method on this class returns to `SessionOpen` afterwards, because there
  /// is no longer a store any PIN could unwrap.
  void panicked(PanicReport report) => state = SessionPanicked(report);

  /// `3c`'s single button.
  ///
  /// **Ruling.** This returns to a lock screen that no PIN will ever open,
  /// not to setup — even though `VaultStore.exists` is now false and
  /// `SessionUnconfigured` is what a genuinely fresh device would show. Under
  /// this plan's stated threat model (coerced unlock, not forensic imaging)
  /// the screen after a panic has to look like the screen before one; a setup
  /// wizard announces to the person holding the phone that everything was
  /// just destroyed, which is the one thing the past-tense report in `3c` is
  /// carefully not saying out loud to anyone but its owner. A cold start
  /// after this reaches `SessionUnconfigured` normally, since `main()` re-runs
  /// the `exists` check.
  void dismissPanicReport() =>
      state = const SessionLocked(mood: LockMood.normal, gate: AttemptGate());

  /// The tail of the unlock queue: every [unlock] runs after the one before
  /// it has finished, so two overlapping attempts can never both read the
  /// same attempt gate and record one failure between them.
  Future<void> _unlockQueue = Future<void>.value();

  Future<void> unlock(String pin) {
    final run = _unlockQueue.then((_) => _unlock(pin));
    _unlockQueue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _unlock(String pin) async {
    final previous = state;
    // An earlier attempt in the queue already opened a vault (or panic ran):
    // there is nothing left for this PIN to decide.
    if (previous is! SessionLocked) return;
    // No meta.bin: a panic destroyed it, and this is the lock screen no PIN
    // opens (`dismissPanicReport`). A PIN must still look refused, not do
    // nothing: it is checked against slots made in memory, at the same cost,
    // and the tries count down in memory only. Nothing is written.
    final provisioned = await _vaultStore.exists;
    final currentGate = provisioned ? await _vaultStore.gate() : previous.gate;
    final slots = provisioned
        ? await _vaultStore.slots()
        : await _vaultStore.unopenableSlots();
    final outcome = await _unlocker.attempt(
      pin: pin,
      slots: slots,
      gate: currentGate,
      now: DateTime.now(),
    );

    switch (outcome) {
      case Unlocked(:final vault, :final dataKey, :final gate):
        await _vaultStore.saveGate(gate);
        final database = await ref.read(vaultOpenerProvider)(
          path: vaultDatabasePath(ref.read(documentsDirectoryProvider), vault),
          dataKey: dataKey,
        );
        await ensureWorkspace(database);
        await _loadAutoLock();
        state = SessionOpen(
          vault: vault,
          database: database,
          dataKey: dataKey,
          biometricWrappedKey: await _rewrapIfEnabled(vault, database, dataKey),
        );
      case Rejected(:final gate):
        if (provisioned) await _vaultStore.saveGate(gate);
        // The failure is counted, but a late rejection must never take an
        // open vault (or a panic report) back to the lock screen.
        if (state is! SessionLocked) return;
        state = SessionLocked(
          mood: LockMood.wrong,
          gate: gate,
          openSessionCount: _openCount(),
          biometricVault: previous.biometricVault,
          biometricWrappedKey: previous.biometricWrappedKey,
        );
      case Throttled():
        if (state is! SessionLocked) return;
        state = SessionLocked(
          mood: LockMood.wrong,
          gate: currentGate,
          openSessionCount: _openCount(),
          biometricVault: previous.biometricVault,
          biometricWrappedKey: previous.biometricWrappedKey,
        );
    }
  }

  /// Every fresh PIN unlock is self-healing: if biometrics is on for this
  /// vault, re-wrap under this vault's Keystore key — and if
  /// no usable key currently exists (missing, or invalidated by new
  /// biometric enrollment; see `BiometricPlugin.unwrap`'s
  /// `KeyPermanentlyInvalidatedException` handling, which already deletes
  /// the dangling alias), regenerate the keypair and retry once. This must
  /// never throw: a correct-PIN unlock cannot be allowed to fail just
  /// because a *convenience* key is broken, so a failure on both attempts
  /// fails closed by returning null, same as `BiometricService.unwrap`'s
  /// own "nothing usable right now" convention.
  Future<Uint8List?> _rewrapIfEnabled(
      VaultId vault, AppDatabase database, Uint8List dataKey) async {
    final enabled =
        await SqliteSettingsRepository(database).getBool('biometrics_enabled');
    if (!enabled) return null;
    final biometrics = ref.read(biometricServiceProvider);
    try {
      return await biometrics.wrap(vault, dataKey);
    } catch (_) {
      // The alias may be gone — invalidated by new biometric enrollment and
      // already deleted by BiometricPlugin.unwrap, or missing for any other
      // reason. Regenerate and retry: this is the self-heal the design spec
      // requires. A correct-PIN unlock must never fail because a
      // *convenience* key is missing — see the spec's "Failure modes"
      // section.
      try {
        await biometrics.generateKeyPair(vault);
        return await biometrics.wrap(vault, dataKey);
      } catch (_) {
        return null;
      }
    }
  }

  /// `LockBody.onBiometric`'s target once `LockScreen` decides biometrics is
  /// on offer (`biometricAvailable`, Task 4). A no-op — the lock screen
  /// stays up with the PIN keypad still available — on cancel, a failed
  /// match, or an invalidated key, since [BiometricService.unwrap] returns
  /// null for all three.
  Future<void> resumeWithBiometric() async {
    final current = state;
    if (current is! SessionLocked ||
        current.mood != LockMood.welcomeBack ||
        current.biometricWrappedKey == null ||
        current.biometricVault == null) {
      return;
    }
    final dataKey = await ref
        .read(biometricServiceProvider)
        .unwrap(current.biometricVault!, current.biometricWrappedKey!);
    if (dataKey == null) return;
    final database = await ref.read(vaultOpenerProvider)(
      path: vaultDatabasePath(
          ref.read(documentsDirectoryProvider), current.biometricVault!),
      dataKey: dataKey,
    );
    await ensureWorkspace(database);
    await _loadAutoLock();
    state = SessionOpen(
      vault: current.biometricVault!,
      database: database,
      dataKey: dataKey,
      biometricWrappedKey: current.biometricWrappedKey,
    );
  }

  /// Called by `SettingsController` (Task 5) right after enabling or
  /// disabling biometrics. A no-op if the vault has since closed from
  /// under it.
  void setBiometricWrapped(Uint8List? wrapped) {
    final current = state;
    if (current is! SessionOpen) return;
    state = SessionOpen(
      vault: current.vault,
      database: current.database,
      dataKey: current.dataKey,
      biometricWrappedKey: wrapped,
    );
  }

  /// Called once by `SetupController` (Task 6), via `setupControllerProvider`
  /// below, when setup has just provisioned and seeded the real vault.
  /// Biometrics can't be enabled yet at this point — Settings is
  /// unreachable during setup — so this never wraps anything.
  void completeSetup({
    required VaultId vault,
    required AppDatabase database,
    required Uint8List dataKey,
  }) {
    // Setup has just written a fresh key file, with no Auto-lock choice yet.
    _lifecycle.policy = AutoLockPolicy.oneMinute;
    state = SessionOpen(vault: vault, database: database, dataKey: dataKey);
  }

  /// The Auto-lock choice, one for both vaults (user's rulings, 2026-09-30 and
  /// 2026-10-01), read from the key file as a vault opens and held here, so
  /// the return can decide between `9b` and `9c` without touching storage.
  /// Any `auto_lock` row a vault kept from the per-vault build is ignored.
  Future<void> _loadAutoLock() async {
    _lifecycle.policy = await _vaultStore.autoLock();
  }

  /// Called by `SettingsController` once the choice is saved, so the next
  /// return uses it.
  void setAutoLock(AutoLockPolicy policy) => _lifecycle.policy = policy;

  @visibleForTesting
  AutoLockPolicy get debugAutoLock => _lifecycle.policy;

  /// Called by `LockScreen`'s own timer once `SessionLocked.lockDeadline`
  /// has passed without a correct PIN. A no-op outside the welcome-back
  /// state, so a stray or late call after the user already unlocked cannot
  /// re-lock them.
  void graceExpired() {
    final current = state;
    if (current is! SessionLocked || current.mood != LockMood.welcomeBack) {
      return;
    }
    state = SessionLocked(
      mood: LockMood.afterTimeout,
      gate: current.gate,
      lockedAfter: current.lockedAfter,
    );
  }

  @visibleForTesting
  void debugHandleReturn(ReturnDestination destination) =>
      _handleReturn(destination);

  int _openCount() {
    final current = state;
    return current is SessionLocked ? current.openSessionCount : 0;
  }

  /// See this file's header and Step 6's Ruling: `ReturnDestination.board`
  /// means "come back to a screen that still trusts your open sessions"
  /// (`9b`, `welcomeBack`), never "come back to the dashboard unguarded."
  /// `ReturnDestination.pin` means the sessions are actually gone (`9c`,
  /// `afterTimeout`).
  void _handleReturn(ReturnDestination destination) {
    final current = state;
    if (current is! SessionOpen) return;
    unawaited(current.database.close());
    // `9b`'s count, read before anything closes: every listed container,
    // throwaways included (tabs spec §5.4).
    final openSessionCount = ref.read(openContainerCountProvider).value;
    // Pages outlive the widget tree; the registry's reset sends this too, but
    // no lock may depend on when Riverpod rebuilds it (tabs spec §5.8).
    unawaited(ref.read(containerEngineProvider).closeAll());

    switch (destination) {
      case ReturnDestination.board:
        state = SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          openSessionCount: openSessionCount,
          lockDeadline: DateTime.now().add(_lifecycle.policy.grace),
          biometricVault: current.vault,
          biometricWrappedKey: current.biometricWrappedKey,
          lockedAfter: _lifecycle.policy,
        );
      case ReturnDestination.pin:
        state = SessionLocked(
          mood: LockMood.afterTimeout,
          gate: const AttemptGate(),
          lockedAfter: _lifecycle.policy,
        );
    }
  }
}

/// Constructs the real `SetupController` (Task 6) from this task's
/// providers. `SetupController` itself has no Riverpod dependency — see its
/// own file for why — so this is the only place that wiring happens.
final setupControllerProvider = Provider<SetupController>((ref) {
  final documents = ref.read(documentsDirectoryProvider);
  return SetupController(
    vaultStore: ref.read(vaultStoreProvider),
    openVault: ref.read(vaultOpenerProvider),
    pathFor: (vault) => vaultDatabasePath(documents, vault),
    openSession: (
            {required VaultId vault,
            required AppDatabase database,
            required Uint8List dataKey}) =>
        ref.read(sessionProvider.notifier).completeSetup(
              vault: vault,
              database: database,
              dataKey: dataKey,
            ),
  );
});

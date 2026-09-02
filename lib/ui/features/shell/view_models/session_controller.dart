import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../data/services/android_crypto_service.dart';
import '../../../../data/services/app_database.dart';
import '../../../../data/services/encrypted_database.dart';
import '../../../../data/services/vault_store.dart';
import '../../../../domain/models/attempt_gate.dart';
import '../../../../domain/models/lock_state.dart';
import '../../../../domain/models/vault.dart';
import '../../../../domain/services/crypto_service.dart';
import '../../../../domain/services/panic_service.dart';
import '../../../../domain/services/vault_unlocker.dart';
import '../../dashboard/view_models/providers.dart' show openSiteIdsProvider;
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
class SessionLocked extends Session {
  const SessionLocked({
    required this.mood,
    required this.gate,
    this.openSessionCount = 0,
    this.lockDeadline,
  });

  final LockMood mood;
  final AttemptGate gate;
  final int openSessionCount;
  final DateTime? lockDeadline;
}

/// A vault is open. Read by `databaseProvider` below — nothing else in the
/// app ever asks which vault that is.
class SessionOpen extends Session {
  const SessionOpen({required this.vault, required this.database});

  final VaultId vault;
  final AppDatabase database;
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
    ref.onDispose(_lifecycle.stop);
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

  Future<void> unlock(String pin) async {
    final currentGate = await _vaultStore.gate();
    final slots = await _vaultStore.slots();
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
        state = SessionOpen(vault: vault, database: database);
      case Rejected(:final gate):
        await _vaultStore.saveGate(gate);
        state = SessionLocked(
            mood: LockMood.wrong, gate: gate, openSessionCount: _openCount());
      case Throttled():
        state = SessionLocked(
            mood: LockMood.wrong,
            gate: currentGate,
            openSessionCount: _openCount());
    }
  }

  /// Called once by `SetupController` (Task 6), via `setupControllerProvider`
  /// below, when setup has just provisioned and seeded the real vault.
  void completeSetup({required VaultId vault, required AppDatabase database}) {
    state = SessionOpen(vault: vault, database: database);
  }

  /// Called by `LockScreen`'s own timer once `SessionLocked.lockDeadline`
  /// has passed without a correct PIN. A no-op outside the welcome-back
  /// state, so a stray or late call after the user already unlocked cannot
  /// re-lock them.
  void graceExpired() {
    final current = state;
    if (current is! SessionLocked || current.mood != LockMood.welcomeBack) {
      return;
    }
    ref.read(openSiteIdsProvider.notifier).state = {};
    state = SessionLocked(mood: LockMood.afterTimeout, gate: current.gate);
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

    switch (destination) {
      case ReturnDestination.board:
        state = SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          openSessionCount: ref.read(openSiteIdsProvider).length,
          lockDeadline: DateTime.now().add(AutoLockPolicy.oneMinute.grace),
        );
      case ReturnDestination.pin:
        ref.read(openSiteIdsProvider.notifier).state = {};
        state =
            const SessionLocked(mood: LockMood.afterTimeout, gate: AttemptGate());
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
    openSession: ({required VaultId vault, required AppDatabase database}) =>
        ref.read(sessionProvider.notifier).completeSetup(
              vault: vault,
              database: database,
            ),
  );
});

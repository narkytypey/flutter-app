import '../../domain/services/panic_service.dart';
import 'container_engine.dart';

/// The real panic sequence.
///
/// [PanicService]'s doc comment gives the order Plan 2 established — sessions,
/// keys, files, lock. This adds the step that per-container storage makes
/// necessary, in front of all of them: the WebView profiles die first, while
/// their ids are still readable. Once the data keys are gone nothing in the
/// process can name a profile, and whatever is still on disk stays there.
///
/// [destroyVaults] and [closeDatabase] are callbacks rather than a `VaultStore`
/// and an `AppDatabase` so that this ordering can be tested on the host with no
/// crypto, no SQLCipher and no platform channel involved.
class ContainerPanicService implements PanicService {
  ContainerPanicService({
    required ContainerEngine engine,
    required Future<void> Function() closeDatabase,
    required Future<void> Function() destroyVaults,
    required Future<void> Function() destroyBiometricKeys,
  })  : _engine = engine,
        _closeDatabase = closeDatabase,
        _destroyVaults = destroyVaults,
        _destroyBiometricKeys = destroyBiometricKeys;

  // ignore_for_file: prefer_initializing_formals — see the constructor's
  // existing rationale above for the other three fields; the same applies
  // to `_destroyBiometricKeys`.

  final ContainerEngine _engine;
  final Future<void> Function() _closeDatabase;
  final Future<void> Function() _destroyVaults;
  final Future<void> Function() _destroyBiometricKeys;

  /// **Fails closed.** The container steps are best effort; the three steps
  /// that make the vault unreadable run whatever happened to them.
  ///
  /// That ordering used to be absolute, and it failed open on a device:
  /// WebView refuses to delete a profile this process has already loaded, so
  /// `wipeAll` threw and panic stopped with every key still intact, while the
  /// person who pressed it believed everything was gone. The platform now
  /// clears such a profile in place and deletes it on the next start instead
  /// of throwing, but nothing a container step does may ever again stand
  /// between panic and the keys.
  @override
  Future<PanicReport> trigger() async {
    // Snapshot before destroying: this is what `3c` reports.
    final live = await _bestEffort(_engine.liveSessions) ?? const [];

    for (final session in live) {
      await _bestEffort(() => _engine.close(session.siteId));
    }
    await _bestEffort(_engine.wipeAll);

    await _closeDatabase();
    await _destroyVaults();
    await _destroyBiometricKeys();

    return PanicReport(sessionsDestroyed: live.length);
  }

  static Future<T?> _bestEffort<T>(Future<T> Function() step) async {
    try {
      return await step();
    } catch (_) {
      return null;
    }
  }
}

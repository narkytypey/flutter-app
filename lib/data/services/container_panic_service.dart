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
    required Future<void> Function() destroyBiometricKey,
  })  : _engine = engine,
        _closeDatabase = closeDatabase,
        _destroyVaults = destroyVaults,
        _destroyBiometricKey = destroyBiometricKey;

  // ignore_for_file: prefer_initializing_formals — see the constructor's
  // existing rationale above for the other three fields; the same applies
  // to `_destroyBiometricKey`.

  final ContainerEngine _engine;
  final Future<void> Function() _closeDatabase;
  final Future<void> Function() _destroyVaults;
  final Future<void> Function() _destroyBiometricKey;

  @override
  Future<PanicReport> trigger() async {
    // Snapshot before destroying: this is what `3c` reports.
    final live = await _engine.liveSessions();

    // `ProfileStore.deleteProfile` throws while a profile is attached to a
    // live WebView, so detaching first is not optional politeness.
    for (final session in live) {
      await _engine.close(session.siteId);
    }

    await _engine.wipeAll();
    await _closeDatabase();
    await _destroyVaults();
    await _destroyBiometricKey();

    return PanicReport(sessionsDestroyed: live.length);
  }
}

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
  })  : _engine = engine,
        _closeDatabase = closeDatabase,
        _destroyVaults = destroyVaults;

  // ignore_for_file: prefer_initializing_formals — an initializing formal
  // requires the parameter name to equal the field name, which would force
  // callers to pass `_engine:`/`_closeDatabase:`/`_destroyVaults:` instead
  // of the readable `engine:`/`closeDatabase:`/`destroyVaults:` this
  // class's own test (and the plan's reference code) uses.

  final ContainerEngine _engine;
  final Future<void> Function() _closeDatabase;
  final Future<void> Function() _destroyVaults;

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

    return PanicReport(sessionsDestroyed: live.length);
  }
}

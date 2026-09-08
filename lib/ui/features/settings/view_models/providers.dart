import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/settings_repository_sqlite.dart';
import '../../../../domain/repositories/repositories.dart' show SettingsRepository;
import '../../dashboard/view_models/providers.dart' show databaseProvider;
import '../../shell/view_models/session_controller.dart'
    show biometricServiceProvider, sessionProvider, SessionOpen;

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SqliteSettingsRepository(ref.watch(databaseProvider)),
);

/// Backs `SettingsScreen`'s LOCK section biometrics row. Every other row on
/// that screen is still a static placeholder — see this plan's Known Gaps.
final biometricsEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).getBool('biometrics_enabled'),
);

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
}

final settingsControllerProvider = Provider((ref) => SettingsController(ref));

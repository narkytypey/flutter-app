import 'package:container/ui/features/settings/views/settings_route.dart';
import 'package:container/ui/features/scripts/views/scripts_route.dart';
import 'package:container/ui/features/settings/views/decoy_resync_route.dart';
import 'package:container/ui/features/workspaces/views/workspaces_route.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings rows lead to their screens', () {
    expect(settingsDestination('workspaces'), isA<WorkspacesRoute>());
    expect(settingsDestination('scripts'), isA<ScriptsRoute>());
    expect(settingsDestination('resyncDecoy'), isA<DecoyResyncRoute>());
  });

  /// User's ruling, 2026-09-30: which sites the decoy shows is decided per
  /// workspace ("Show in decoy vault", `10b`), so the row opens Workspaces.
  test('Sites shown in decoy opens Workspaces', () {
    expect(settingsDestination('decoySites'), isA<WorkspacesRoute>());
  });

  test('rows with nothing built behind them lead nowhere', () {
    for (final key in ['autoLock', 'changePin', 'onPanic']) {
      expect(settingsDestination(key), isNull, reason: key);
    }
  });
}

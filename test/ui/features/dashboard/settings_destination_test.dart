import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
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

  test('rows with nothing built behind them lead nowhere', () {
    for (final key in ['autoLock', 'changePin', 'decoySites', 'onPanic']) {
      expect(settingsDestination(key), isNull, reason: key);
    }
  });
}

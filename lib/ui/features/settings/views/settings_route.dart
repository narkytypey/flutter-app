import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/search_engine.dart';
import '../../scripts/views/scripts_route.dart';
import '../../workspaces/views/workspaces_route.dart';
import '../view_models/providers.dart';
import 'decoy_resync_route.dart';
import 'search_engine_picker.dart';
import 'settings_screen.dart';

/// The screen a Settings row opens, by the key `SettingsScreen.onTap`
/// reports. Null for a row with nothing built behind it yet, and for
/// `searchEngine`, which opens a sheet rather than a screen.
Widget? settingsDestination(String key) => switch (key) {
      'resyncDecoy' => const DecoyResyncRoute(),
      'workspaces' => const WorkspacesRoute(),
      'scripts' => const ScriptsRoute(),
      _ => null,
    };

/// Spec `2d` against the open vault. Pushed from the dashboard's `⋯` and
/// from a container's ☰ menu.
class SettingsRoute extends ConsumerWidget {
  const SettingsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometrics = ref.watch(biometricsEnabledProvider);
    final biometricsAvailable = ref.watch(biometricsAvailableProvider);
    final decoyEnabled = ref.watch(decoyEnabledProvider);
    final decoySiteCount = ref.watch(decoySiteCountProvider);
    final searchEngine = ref.watch(searchEngineProvider).valueOrNull;
    return SettingsScreen(
      biometrics: biometrics.value ?? false,
      biometricsAvailable: biometricsAvailable.value ?? false,
      autoLockLabel: 'After 1 min',
      decoyEnabled: decoyEnabled.value ?? false,
      decoySiteCount: decoySiteCount.value ?? 0,
      hideFromSwitcher: true,
      panicOnFlip: false,
      onPanicLabel: 'Wipe + lock',
      searchEngineName: searchEngine?.label ?? '',
      onChanged: (key, value) {
        if (key == 'biometrics') {
          ref.read(settingsControllerProvider).setBiometricsEnabled(value);
        }
      },
      onTap: (key) {
        if (key == 'searchEngine') {
          _pickSearchEngine(context, ref, searchEngine ?? SearchEngine.duckDuckGo);
          return;
        }
        final destination = settingsDestination(key);
        if (destination != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
        }
      },
    );
  }

  void _pickSearchEngine(BuildContext context, WidgetRef ref, SearchEngine current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SearchEnginePicker(
        current: current,
        onPick: (engine) {
          Navigator.pop(sheetContext);
          ref.read(settingsControllerProvider).setSearchEngine(engine);
        },
      ),
    );
  }
}

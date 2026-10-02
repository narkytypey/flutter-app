import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/lock_state.dart';
import '../../../../domain/models/search_engine.dart';
import '../../../../domain/models/security_level.dart';
import '../../scripts/views/scripts_route.dart';
import '../../workspaces/views/workspaces_route.dart';
import '../view_models/providers.dart';
import 'auto_lock_picker.dart';
import 'change_pin_route.dart';
import 'decoy_resync_route.dart';
import 'search_engine_picker.dart';
import 'security_level_picker.dart';
import 'settings_screen.dart';

/// The screen a Settings row opens, by the key `SettingsScreen.onTap`
/// reports. Null for a row with nothing built behind it yet, and for
/// `autoLock`, `searchEngine` and `securityLevel`, which open a sheet rather
/// than a screen.
Widget? settingsDestination(String key) => switch (key) {
      'resyncDecoy' => const DecoyResyncRoute(),
      'changePin' => const ChangePinRoute(),
      'workspaces' => const WorkspacesRoute(),
      // Each workspace's "Show in decoy vault" decides it (user's ruling,
      // 2026-09-30).
      'decoySites' => const WorkspacesRoute(),
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
    final securityLevel = ref.watch(vaultSecurityLevelProvider).valueOrNull;
    final autoLock = ref.watch(autoLockProvider).valueOrNull ?? AutoLockPolicy.oneMinute;
    final panicOnFlip = ref.watch(panicOnFlipProvider).valueOrNull ?? false;
    return SettingsScreen(
      biometrics: biometrics.value ?? false,
      biometricsAvailable: biometricsAvailable.value ?? false,
      autoLockLabel: autoLock.label,
      decoyEnabled: decoyEnabled.value ?? false,
      decoySiteCount: decoySiteCount.value ?? 0,
      hideFromSwitcher: true,
      panicOnFlip: panicOnFlip,
      onPanicLabel: 'Wipe + lock',
      searchEngineName: searchEngine?.label ?? '',
      securityLevelName: securityLevel?.label ?? '',
      onChanged: (key, value) {
        if (key == 'biometrics') {
          ref.read(settingsControllerProvider).setBiometricsEnabled(value);
        } else if (key == 'panicOnFlip') {
          ref.read(settingsControllerProvider).setPanicOnFlip(value);
        }
      },
      onTap: (key) {
        if (key == 'autoLock') {
          _pickAutoLock(context, ref, autoLock);
          return;
        }
        if (key == 'searchEngine') {
          _pickSearchEngine(context, ref, searchEngine ?? SearchEngine.duckDuckGo);
          return;
        }
        if (key == 'securityLevel') {
          _pickSecurityLevel(context, ref, securityLevel ?? SecurityLevel.standard);
          return;
        }
        final destination = settingsDestination(key);
        if (destination != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
        }
      },
    );
  }

  void _pickAutoLock(BuildContext context, WidgetRef ref, AutoLockPolicy current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => AutoLockPicker(
        current: current,
        onPick: (policy) {
          Navigator.pop(sheetContext);
          ref.read(settingsControllerProvider).setAutoLock(policy);
        },
      ),
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

  void _pickSecurityLevel(BuildContext context, WidgetRef ref, SecurityLevel current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SecurityLevelPicker.vault(
        current: current,
        onPick: (level) {
          Navigator.pop(sheetContext);
          ref.read(settingsControllerProvider).setSecurityLevel(level!);
        },
      ),
    );
  }
}

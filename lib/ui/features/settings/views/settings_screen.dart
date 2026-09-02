import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/setting_row.dart';

/// Spec `2d`.
///
/// The VAULT section is present only when a decoy has been configured. From
/// inside a decoy session this screen is never reachable at all — settings are
/// a real-vault surface, because a decoy that offers to manage a decoy is a
/// decoy that has announced itself.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.biometrics,
    required this.autoLockLabel,
    required this.decoyEnabled,
    required this.decoySiteCount,
    required this.hideFromSwitcher,
    required this.panicOnFlip,
    required this.onPanicLabel,
    required this.onChanged,
    required this.onTap,
  });

  final bool biometrics;
  final String autoLockLabel;
  final bool decoyEnabled;
  final int decoySiteCount;
  final bool hideFromSwitcher;
  final bool panicOnFlip;
  final String onPanicLabel;
  final void Function(String key, bool value) onChanged;
  final void Function(String key) onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left, size: 20, color: C.icon),
                  const SizedBox(width: 10),
                  Text('Settings', style: T.screenTitle),
                ],
              ),
            ),
            const Divider(height: 1, color: C.line06),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text('LOCK', style: T.sectionLabel),
                  SettingRow(
                    title: 'Unlock with biometrics',
                    subtitle: 'PIN always available as fallback',
                    trailing: AppToggle(
                      value: biometrics,
                      onChanged: (v) => onChanged('biometrics', v),
                    ),
                  ),
                  SettingRow(
                      title: 'Auto-lock',
                      value: autoLockLabel,
                      onTap: () => onTap('autoLock')),
                  SettingRow(
                      title: 'Change main PIN', onTap: () => onTap('changePin')),
                  const SizedBox(height: 24),
                  Text('MANAGE', style: T.sectionLabel),
                  SettingRow(title: 'Workspaces', onTap: () => onTap('workspaces')),
                  SettingRow(
                      title: 'Scripts and filters', onTap: () => onTap('scripts')),
                  if (decoyEnabled) ...[
                    const SizedBox(height: 24),
                    Text('VAULT', style: T.sectionLabel),
                    SettingRow(
                      title: 'Decoy vault',
                      subtitle: 'A second PIN opens a harmless board',
                      trailing: AppToggle(
                        value: decoyEnabled,
                        onChanged: (v) => onChanged('decoy', v),
                      ),
                    ),
                    SettingRow(
                        title: 'Sites shown in decoy',
                        value: '$decoySiteCount selected',
                        onTap: () => onTap('decoySites')),
                    SettingRow(
                      title: 'Hide from app switcher',
                      subtitle: 'Blurs previews, blocks screenshots',
                      trailing: AppToggle(
                        value: hideFromSwitcher,
                        onChanged: (v) => onChanged('hideFromSwitcher', v),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('PANIC', style: T.sectionLabel),
                  SettingRow(
                    title: 'Trigger by flipping face down',
                    subtitle: 'Uses the accelerometer',
                    trailing: AppToggle(
                      value: panicOnFlip,
                      onChanged: (v) => onChanged('panicOnFlip', v),
                    ),
                  ),
                  SettingRow(
                      title: 'On panic',
                      value: onPanicLabel,
                      onTap: () => onTap('onPanic')),
                  const SizedBox(height: 22),
                  Text(
                    'Nothing leaves this device. There is no account and no '
                    'sync.',
                    style: ui(size: 11, color: C.textDim, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

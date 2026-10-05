import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../../core/widgets/setting_row.dart';

/// Spec `2d`.
///
/// The VAULT section is present only when a decoy has been configured. This
/// screen is *meant* to be a real-vault surface — a decoy that offers to
/// manage a decoy would announce itself — but that is a design intent, not
/// something any code enforces: the dashboard's Settings tab is wired identically for every open session, and nothing
/// anywhere asks a `SessionOpen` which vault it holds before deciding what
/// to show it (see `dashboard/view_models/providers.dart`'s
/// `databaseProvider` doc comment — "no code anywhere asking which one that
/// is" is deliberate, existing architecture). So today a decoy session can
/// reach this screen, including the biometrics toggle added 2026-09-08,
/// exactly like a real one can. Actually restricting that would mean
/// teaching the UI layer to distinguish vaults for the first time — a real
/// design decision, left for a future task rather than assumed here.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.biometrics,
    required this.biometricsAvailable,
    required this.autoLockLabel,
    required this.decoyEnabled,
    required this.decoySiteCount,
    required this.hideFromSwitcher,
    required this.panicOnFlip,
    required this.onPanicLabel,
    required this.searchEngineName,
    required this.securityLevelName,
    this.defaultRouteLabel = '',
    this.defaultRouteMono = false,
    required this.onChanged,
    required this.onTap,
    this.onBack,
  });

  final bool biometrics;
  final bool biometricsAvailable;
  final String autoLockLabel;
  final bool decoyEnabled;
  final int decoySiteCount;
  final bool hideFromSwitcher;
  final bool panicOnFlip;
  final String onPanicLabel;

  /// The current engine's name (spec §6.7); empty while it loads.
  final String searchEngineName;

  /// The vault default's name (privacy-controls spec §2.3); empty while it loads.
  final String securityLevelName;

  /// The default route's row value (dashboard spec §8); empty while it loads.
  final String defaultRouteLabel;

  /// True when [defaultRouteLabel] is a proxy's address, shown in mono.
  final bool defaultRouteMono;
  final void Function(String key, bool value) onChanged;
  final void Function(String key) onTap;

  /// The header's back icon. Pops Settings, like every other screen's `‹`
  /// (restyle spec §4). Null draws none: the dashboard's Settings tab
  /// (dashboard spec §4.1).
  final VoidCallback? onBack;

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
                  if (onBack != null) ...[
                    IconTap(
                      glyph: AppGlyph.back,
                      label: 'Back',
                      onTap: onBack,
                      size: 20,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 10),
                  ],
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
                    // The whole row toggles, not only the switch.
                    onTap: biometricsAvailable
                        ? () => onChanged('biometrics', !biometrics)
                        : null,
                    trailing: AppToggle(
                      value: biometrics,
                      onChanged: biometricsAvailable
                          ? (v) => onChanged('biometrics', v)
                          : null,
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
                  const SizedBox(height: 24),
                  Text('BROWSING', style: T.sectionLabel),
                  SettingRow(
                    title: 'Search engine',
                    value: searchEngineName,
                    onTap: () => onTap('searchEngine'),
                  ),
                  SettingRow(
                    title: 'Default route',
                    value: defaultRouteLabel,
                    monoValue: defaultRouteMono,
                    onTap: () => onTap('defaultRoute'),
                  ),
                  SettingRow(
                    title: 'Security level',
                    value: securityLevelName,
                    onTap: () => onTap('securityLevel'),
                  ),
                  if (decoyEnabled) ...[
                    const SizedBox(height: 24),
                    Text('VAULT', style: T.sectionLabel),
                    SettingRow(
                      title: 'Decoy vault',
                      subtitle: 'A second PIN opens a harmless board',
                      // Shown, not offered (user's ruling, 2026-09-30):
                      // turning a decoy off is not built.
                      trailing: AppToggle(value: decoyEnabled),
                    ),
                    SettingRow(
                        title: 'Sites shown in decoy',
                        value: '$decoySiteCount selected',
                        onTap: () => onTap('decoySites')),
                    SettingRow(
                        title: 'Re-sync decoy now',
                        onTap: () => onTap('resyncDecoy')),
                    SettingRow(
                      title: 'Hide from app switcher',
                      subtitle: 'Blurs previews, blocks screenshots',
                      // Always on (user's ruling, 2026-09-30): FLAG_SECURE is
                      // set before the window exists, never per screen.
                      trailing: AppToggle(value: hideFromSwitcher),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('PANIC', style: T.sectionLabel),
                  SettingRow(
                    title: 'Trigger by flipping face down',
                    subtitle: 'Uses the accelerometer',
                    onTap: () => onChanged('panicOnFlip', !panicOnFlip),
                    trailing: AppToggle(
                      value: panicOnFlip,
                      onChanged: (v) => onChanged('panicOnFlip', v),
                    ),
                  ),
                  // The only behaviour there is (user's ruling, 2026-09-30).
                  SettingRow(title: 'On panic', value: onPanicLabel),
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

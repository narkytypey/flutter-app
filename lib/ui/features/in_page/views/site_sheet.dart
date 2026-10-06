import 'package:flutter/material.dart';

import '../../../../domain/models/blocked_tally.dart';
import '../../../../domain/models/permissions.dart';
import '../../../../domain/models/permissions_in_use.dart';
import '../../../core/host_text.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `6c` — the per-site shield panel (privacy-controls spec §3): what
/// this container is running under, editable in place. Every switch, and the
/// security level, applies at once by reopening the container (spec §2.4);
/// "Edit" is the one escape hatch into the full Add site form for everything
/// else. Taller than a phone screen, so everything under the handle scrolls.
class SiteSheet extends StatelessWidget {
  const SiteSheet({
    super.key,
    required this.monogram,
    required this.name,
    required this.subtitle,
    required this.proxyDescriptor,
    required this.cookiesDescriptor,
    required this.blockedCount,
    required this.forceDark,
    required this.desktopView,
    required this.onEdit,
    required this.onProxy,
    required this.onForceDarkChanged,
    required this.onDesktopViewChanged,
    required this.onCloseAndWipe,
    required this.securityLevelValue,
    required this.onSecurityLevel,
    required this.categoryCounts,
    required this.blockWebRtc,
    required this.blockTrackers,
    required this.antiFingerprinting,
    this.onBlockWebRtcChanged,
    required this.onBlockTrackersChanged,
    required this.onAntiFingerprintingChanged,
    required this.permissions,
    required this.onRevoke,
  });

  final String monogram;
  final String name;
  final String subtitle;
  final String proxyDescriptor;
  final String cookiesDescriptor;
  final int blockedCount;
  final bool forceDark;
  final bool desktopView;
  final VoidCallback onEdit;

  /// The Proxy row: the site's route, changed while browsing (user's ruling
  /// 2026-10-05).
  final VoidCallback onProxy;
  final ValueChanged<bool> onForceDarkChanged;
  final ValueChanged<bool> onDesktopViewChanged;
  final VoidCallback onCloseAndWipe;

  /// The effective level, `<Level>` or `<Level> · default` (spec §3, §5).
  final String securityLevelValue;

  /// Opens the site's security level picker (spec §3).
  final VoidCallback onSecurityLevel;

  /// This session's blocked requests by category; those above 0 are listed
  /// under `Blocked here` (spec §3).
  final Map<BlockedCategory, int> categoryCounts;

  /// The site's `Block WebRTC` setting (spec §3).
  final bool blockWebRtc;

  /// The site's `Block trackers and ads` setting (spec §3).
  final bool blockTrackers;

  /// The site's `Anti-fingerprinting` setting (spec §3).
  final bool antiFingerprinting;

  /// `Block WebRTC`'s new value (spec §3); null draws it inert (built-in Tor spec §5.4).
  final ValueChanged<bool>? onBlockWebRtcChanged;

  /// `Block trackers and ads`' new value (spec §3).
  final ValueChanged<bool> onBlockTrackersChanged;

  /// `Anti-fingerprinting`'s new value (spec §3).
  final ValueChanged<bool> onAntiFingerprintingChanged;

  /// The permissions in use, one row each (spec §3).
  final List<PermissionInUse> permissions;

  /// Revokes one "allow while open" grant (spec §3).
  final ValueChanged<PermissionKind> onRevoke;

  @override
  Widget build(BuildContext context) {
    final categories = [
      for (final c in BlockedCategory.values)
        if ((categoryCounts[c] ?? 0) > 0) (c, categoryCounts[c]!),
    ];
    return BottomSheetSurface(
      showHandle: true,
      scrolls: false,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, S.s5),
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.s5, 0, S.s2, S.s3),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: S.s3),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line)),
                    ),
                    child: Row(
                      children: [
                        Monogram(monogram, size: 40, radius: R.monogram, fontSize: 15),
                        const SizedBox(width: S.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: T.appBarTitle),
                              const SizedBox(height: 2),
                              // Starts with the site's host: it wraps after
                              // its dots, never cut short (restyle v2 §1.6).
                              HostText(subtitle, style: T.meta),
                            ],
                          ),
                        ),
                        // The sheet's one jade action (restyle v2 §8), a
                        // 48 dp target.
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onEdit,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: S.s3),
                              child: Center(
                                widthFactor: 1,
                                child: Text('Edit', style: T.label.copyWith(color: C.jade)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SheetInfoRow(label: 'Proxy', value: proxyDescriptor, onTap: onProxy),
                _SheetInfoRow(label: 'Cookies', value: cookiesDescriptor),
                _SheetInfoRow(
                  label: 'Security level',
                  value: securityLevelValue,
                  onTap: onSecurityLevel,
                ),
                _SheetInfoRow(
                  label: 'Blocked here',
                  value: '$blockedCount ${blockedCount == 1 ? 'request' : 'requests'}',
                  valueStyle: T.value,
                  showDivider: categories.isEmpty,
                ),
                if (categories.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.lineSoft)),
                    ),
                    child: _CategoryRows(categories),
                  ),
                // A tap anywhere on a switch row toggles it, not only on the
                // switch; a locked switch's row does nothing.
                _SheetInfoRow(
                  label: 'Block WebRTC',
                  onTap: _toggle(blockWebRtc, onBlockWebRtcChanged),
                  trailing: AppToggle(value: blockWebRtc, onChanged: onBlockWebRtcChanged),
                ),
                _SheetInfoRow(
                  label: 'Block trackers and ads',
                  onTap: _toggle(blockTrackers, onBlockTrackersChanged),
                  trailing: AppToggle(value: blockTrackers, onChanged: onBlockTrackersChanged),
                ),
                _SheetInfoRow(
                  label: 'Anti-fingerprinting',
                  onTap: _toggle(antiFingerprinting, onAntiFingerprintingChanged),
                  trailing: AppToggle(
                    value: antiFingerprinting,
                    onChanged: onAntiFingerprintingChanged,
                  ),
                ),
                _SheetInfoRow(
                  label: 'Force dark mode',
                  onTap: _toggle(forceDark, onForceDarkChanged),
                  trailing: AppToggle(value: forceDark, onChanged: onForceDarkChanged),
                ),
                _SheetInfoRow(
                  label: 'Desktop view',
                  onTap: _toggle(desktopView, onDesktopViewChanged),
                  trailing: AppToggle(value: desktopView, onChanged: onDesktopViewChanged),
                  showDivider: permissions.isNotEmpty,
                ),
                for (var i = 0; i < permissions.length; i++)
                  _SheetInfoRow(
                    label: _permissionLabel(permissions[i].kind),
                    trailing: _permissionTrailing(permissions[i]),
                    showDivider: i != permissions.length - 1,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(S.s5, S.s4, S.s5, 0),
                  child: PillButton(
                    label: 'Close and wipe this session',
                    height: 48,
                    radius: R.input,
                    onTap: onCloseAndWipe,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// A stored grant reads `Allowed` and changes only through Edit; a
  /// while-open grant offers `Revoke`, in a neutral colour (spec §3).
  static VoidCallback? _toggle(bool value, ValueChanged<bool>? onChanged) =>
      onChanged == null ? null : () => onChanged(!value);

  Widget _permissionTrailing(PermissionInUse p) {
    if (!p.whileOpen) {
      return Text('Allowed', style: T.sub);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onRevoke(p.kind),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Center(
          widthFactor: 1,
          child: Text('Revoke', style: T.body.copyWith(fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

/// Canvas `2a`'s HARDWARE labels.
String _permissionLabel(PermissionKind kind) => switch (kind) {
  PermissionKind.camera => 'Camera',
  PermissionKind.microphone => 'Microphone',
  PermissionKind.location => 'Location',
  PermissionKind.clipboard => 'Clipboard',
};

/// The indented, muted per-category counts under `Blocked here`, in `5c`'s
/// order and words, with no dividers (spec §3).
class _CategoryRows extends StatelessWidget {
  const _CategoryRows(this.categories);

  final List<(BlockedCategory, int)> categories;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, S.s5, S.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : S.s2),
              child: Row(
                children: [
                  Expanded(child: Text(categories[i].$1.label, style: T.sub)),
                  const SizedBox(width: S.s3),
                  Text('${categories[i].$2}', style: T.value),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SheetInfoRow extends StatelessWidget {
  const _SheetInfoRow({
    required this.label,
    this.value,
    this.trailing,
    this.showDivider = true,
    this.onTap,
    this.valueStyle,
  });

  final String label;
  final String? value;

  /// The value's style; a row subtitle unless a count (Mono) asks otherwise.
  final TextStyle? valueStyle;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: S.s5, vertical: S.s2),
      decoration: BoxDecoration(
        border: showDivider ? Border(bottom: BorderSide(color: C.lineSoft)) : null,
      ),
      // On a narrow phone the longer label or value wraps rather than
      // overflowing the row: the sheet scrolls, so a taller row is fine.
      child: Row(
        children: trailing != null
            ? [
                Expanded(child: Text(label, style: T.body)),
                const SizedBox(width: 12),
                trailing!,
              ]
            : [
                Text(label, style: T.body),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: valueStyle ?? T.sub,
                  ),
                ),
              ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

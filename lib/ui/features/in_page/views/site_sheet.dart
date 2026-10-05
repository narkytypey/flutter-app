import 'package:flutter/material.dart';

import '../../../../domain/models/blocked_tally.dart';
import '../../../../domain/models/permissions.dart';
import '../../../../domain/models/permissions_in_use.dart';
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
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line06)),
                    ),
                    child: Row(
                      children: [
                        Monogram(monogram, size: 40, radius: 11, fontSize: 15),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ui(size: 15.5, weight: 600)),
                              const SizedBox(height: 3),
                              Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ui(size: 11.5, color: C.textFaint)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: onEdit,
                          child: Text('Edit', style: ui(size: 13, weight: 500, color: C.jade)),
                        ),
                      ],
                    ),
                  ),
                ),
                _SheetInfoRow(label: 'Proxy', value: proxyDescriptor),
                _SheetInfoRow(label: 'Cookies', value: cookiesDescriptor),
                _SheetInfoRow(
                  label: 'Security level',
                  value: securityLevelValue,
                  onTap: onSecurityLevel,
                ),
                _SheetInfoRow(
                  label: 'Blocked here',
                  value: '$blockedCount ${blockedCount == 1 ? 'request' : 'requests'}',
                  showDivider: categories.isEmpty,
                ),
                if (categories.isNotEmpty)
                  Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line05)),
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
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: PillButton(
                    label: 'Close and wipe this session',
                    height: 46,
                    radius: 14,
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
      return Text('Allowed', style: ui(size: 12.5, color: C.textMuted));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onRevoke(p.kind),
      child: Text('Revoke', style: ui(size: 13, weight: 500, color: C.textPrimary)),
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
      padding: const EdgeInsets.fromLTRB(32, 0, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < categories.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
              child: Row(
                children: [
                  Text(categories[i].$1.label, style: ui(size: 12.5, color: C.textMuted)),
                  const Spacer(),
                  Text('${categories[i].$2}', style: mono(size: 11, color: C.textFaint)),
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
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: C.line05)) : null,
      ),
      // On a narrow phone the longer label or value wraps rather than
      // overflowing the row: the sheet scrolls, so a taller row is fine.
      child: Row(
        children: trailing != null
            ? [
                Expanded(child: Text(label, style: ui(size: 14, color: C.textPrimary))),
                const SizedBox(width: 12),
                trailing!,
              ]
            : [
                Text(label, style: ui(size: 14, color: C.textPrimary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: ui(size: 12.5, color: C.textMuted),
                  ),
                ),
              ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `6c` — what this container is running under, editable in place.
/// Every row here is read-only except the two switches; "Edit" is the one
/// escape hatch into the full Add site form for everything else.
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

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
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
                      Text(name, style: ui(size: 15.5, weight: 600)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: ui(size: 11.5, color: C.textFaint)),
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
        _SheetInfoRow(label: 'Blocked here', value: '$blockedCount requests'),
        _SheetInfoRow(
          label: 'Force dark mode',
          trailing: AppToggle(value: forceDark, onChanged: onForceDarkChanged),
        ),
        _SheetInfoRow(
          label: 'Desktop view',
          trailing: AppToggle(value: desktopView, onChanged: onDesktopViewChanged),
          showDivider: false,
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
    );
  }
}

class _SheetInfoRow extends StatelessWidget {
  const _SheetInfoRow({
    required this.label,
    this.value,
    this.trailing,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: showDivider ? const Border(bottom: BorderSide(color: C.line05)) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ui(size: 14, color: C.textPrimary)),
          trailing ?? Text(value!, style: ui(size: 12.5, color: C.textMuted)),
        ],
      ),
    );
  }
}

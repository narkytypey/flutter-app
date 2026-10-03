import 'package:flutter/widgets.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// The dashboard's tabs (dashboard spec §4.1), in bar order.
enum DashboardTab { sites, today, settings }

/// Spec §4.1's bottom tab bar: each tab a line icon over its label. The
/// viewed tab is in the primary text colour, the others muted. No jade,
/// which stays for open sessions.
class DashboardTabBar extends StatelessWidget {
  const DashboardTabBar({super.key, required this.current, required this.onSelect});

  final DashboardTab current;
  final ValueChanged<DashboardTab> onSelect;

  static const _tabs = [
    (DashboardTab.sites, AppGlyph.sites, 'Sites'),
    (DashboardTab.today, AppGlyph.today, 'Today'),
    (DashboardTab.settings, AppGlyph.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: C.footer,
        border: Border(top: BorderSide(color: C.line07)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (tab, glyph, label) in _tabs) Expanded(child: _item(tab, glyph, label)),
          ],
        ),
      ),
    );
  }

  Widget _item(DashboardTab tab, AppGlyph glyph, String label) {
    final viewed = tab == current;
    final color = viewed ? C.textPrimary : C.textMuted;
    return Semantics(
      button: true,
      selected: viewed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(glyph, size: 20, color: color),
              const SizedBox(height: 4),
              Text(label, style: ui(size: 10.5, weight: 500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

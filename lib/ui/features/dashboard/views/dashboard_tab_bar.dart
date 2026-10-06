import 'package:flutter/widgets.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// The dashboard's tabs (dashboard spec §4.1), in bar order.
enum DashboardTab { sites, today, settings }

/// Spec §4.1's bottom tab bar: each tab a line icon over its label. Restyle
/// v2 §5: the viewed tab's icon is its filled variant on a raised pill with
/// a text-2 outline, its label text-1 at 600; the others are outline icons
/// in text-2. No jade, which stays for open sessions.
class DashboardTabBar extends StatelessWidget {
  const DashboardTabBar({super.key, required this.current, required this.onSelect});

  final DashboardTab current;
  final ValueChanged<DashboardTab> onSelect;

  static const _tabs = [
    (DashboardTab.sites, AppGlyph.sites, AppGlyph.sitesFilled, 'Sites'),
    (DashboardTab.today, AppGlyph.today, AppGlyph.todayFilled, 'Today'),
    (DashboardTab.settings, AppGlyph.settings, AppGlyph.settingsFilled, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: C.bg,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (tab, glyph, filled, label) in _tabs)
              Expanded(child: _item(tab, tab == current ? filled : glyph, label)),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: viewed
                      ? BoxDecoration(
                          color: C.button,
                          borderRadius: BorderRadius.circular(R.full),
                          border: Border.all(color: C.textMuted, width: 1.5),
                        )
                      : null,
                  child: AppIcon(glyph, size: 20, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: viewed ? T.tabSelected : T.tab,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

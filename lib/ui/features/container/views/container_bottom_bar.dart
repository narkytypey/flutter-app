import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';

/// Browser-chrome spec §6.1's bottom bar, replacing `2b`'s floating pill: a
/// flat `C.footer` bar with a hairline above. Back and forward are 40px
/// round targets, dimmed and inert with no history that way (§3.3). The
/// centre `N OPEN ▲` pill keeps `2b`'s style and opens the `2c` switcher;
/// ☰ opens the menu (§6.4).
class ContainerBottomBar extends StatelessWidget {
  const ContainerBottomBar({
    super.key,
    required this.openCount,
    required this.onBack,
    required this.onForward,
    required this.onOpenSwitcher,
    required this.onMenu,
  });

  final int openCount;

  /// Null when the page cannot go back.
  final VoidCallback? onBack;

  /// Null when the page cannot go forward.
  final VoidCallback? onForward;
  final VoidCallback onOpenSwitcher;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: C.footer,
        border: Border(top: BorderSide(color: C.line07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconTap(glyph: AppGlyph.back, label: 'Back', onTap: onBack),
          IconTap(glyph: AppGlyph.forward, label: 'Forward', onTap: onForward),
          Semantics(
            label: 'Open sessions',
            button: true,
            excludeSemantics: true,
            onTap: onOpenSwitcher,
            child: GestureDetector(
              onTap: onOpenSwitcher,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: C.selected,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$openCount OPEN',
                        style: ui(size: 11, weight: 500, color: C.textSecondary)),
                    const SizedBox(width: 7),
                    Text('▲', style: ui(size: 9, color: C.jade)),
                  ],
                ),
              ),
            ),
          ),
          IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: onMenu),
        ],
      ),
    );
  }
}

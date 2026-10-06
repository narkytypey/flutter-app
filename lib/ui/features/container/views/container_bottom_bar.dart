import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';

/// Browser-chrome spec §6.1's bottom bar, replacing `2b`'s floating pill:
/// restyle v2 §8 `2b`, a flat bar of at least 56 dp on the page tone with a
/// line rule above. Back and forward are 48 dp round targets, dimmed and
/// inert with no history that way (§3.3). The centre `N OPEN ▲` pill opens
/// the `2c` switcher, its count and chevron in text-1 (not jade: jade on
/// `2b` is the pill's light); ☰ opens the menu (§6.4).
///
/// Dashboard spec §9: a fling sideways across the bar views the next open
/// container (left) or the previous one (right). It must travel at least the
/// bar's own height, so a tap that moves a little is still a tap.
class ContainerBottomBar extends StatefulWidget {
  const ContainerBottomBar({
    super.key,
    required this.openCount,
    required this.onBack,
    required this.onForward,
    required this.onOpenSwitcher,
    required this.onMenu,
    this.onNextContainer,
    this.onPreviousContainer,
  });

  final int openCount;

  /// `N OPEN`'s style, which `2c`'s header count shares (restyle v2 §8):
  /// the tab role at 600, text-1.
  static TextStyle get openCountStyle => T.tabSelected;

  /// Null when the page cannot go back.
  final VoidCallback? onBack;

  /// Null when the page cannot go forward.
  final VoidCallback? onForward;
  final VoidCallback onOpenSwitcher;
  final VoidCallback onMenu;

  /// Null at that end: a fling that way does nothing.
  final VoidCallback? onNextContainer;
  final VoidCallback? onPreviousContainer;

  @override
  State<ContainerBottomBar> createState() => _ContainerBottomBarState();
}

class _ContainerBottomBarState extends State<ContainerBottomBar> {
  /// How far the current horizontal drag has gone; left is negative.
  double _travel = 0;

  void _dragEnded() {
    final threshold = context.size?.height ?? double.infinity;
    if (_travel <= -threshold) {
      widget.onNextContainer?.call();
    } else if (_travel >= threshold) {
      widget.onPreviousContainer?.call();
    }
    _travel = 0;
  }

  @override
  Widget build(BuildContext context) {
    // With nowhere to go there is no drag recogniser at all, so the buttons'
    // taps are exactly as they were.
    final swipes = widget.onNextContainer != null || widget.onPreviousContainer != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: swipes ? (_) => _travel = 0 : null,
      onHorizontalDragUpdate: swipes ? (details) => _travel += details.delta.dx : null,
      onHorizontalDragEnd: swipes ? (_) => _dragEnded() : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: const BoxDecoration(
          color: C.bg,
          border: Border(top: BorderSide(color: C.line)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconTap(glyph: AppGlyph.back, label: 'Back', onTap: widget.onBack),
            IconTap(glyph: AppGlyph.forward, label: 'Forward', onTap: widget.onForward),
            Semantics(
              label: 'Open sessions',
              button: true,
              excludeSemantics: true,
              onTap: widget.onOpenSwitcher,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpenSwitcher,
                child: ConstrainedBox(
                  key: const Key('open-sessions-target'),
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.selected,
                        borderRadius: BorderRadius.circular(R.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${widget.openCount} OPEN', style: ContainerBottomBar.openCountStyle),
                          const SizedBox(width: 8),
                          const AppIcon(AppGlyph.chevronUp, size: 12, color: C.textPrimary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: widget.onMenu),
          ],
        ),
      ),
    );
  }
}

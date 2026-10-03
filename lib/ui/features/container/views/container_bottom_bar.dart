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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: const BoxDecoration(
          color: C.footer,
          border: Border(top: BorderSide(color: C.line07)),
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
                onTap: widget.onOpenSwitcher,
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
                      Text('${widget.openCount} OPEN',
                          style: ui(size: 11, weight: 500, color: C.textSecondary)),
                      const SizedBox(width: 7),
                      const AppIcon(AppGlyph.chevronUp, size: 12, color: C.jade),
                    ],
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

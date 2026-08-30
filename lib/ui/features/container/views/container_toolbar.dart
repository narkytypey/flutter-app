import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `2b`'s floating toolbar — drawn with `margin-top: -70px` so it
/// overlaps the tail of the page content above it.
class ContainerToolbar extends StatelessWidget {
  const ContainerToolbar({
    super.key,
    required this.openCount,
    required this.onReaderMode,
    required this.onFilters,
    required this.onMenu,
    required this.onMore,
    required this.onOpenSwitcher,
  });

  final int openCount;
  final VoidCallback onReaderMode;
  final VoidCallback onFilters;
  final VoidCallback onMenu;
  final VoidCallback onMore;

  /// Tapping the centre "N OPEN" pill.
  final VoidCallback onOpenSwitcher;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -70),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF181C1F).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: C.line09),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RoundIcon(glyph: '◑', onTap: onReaderMode),
              _RoundIcon(glyph: '≡', onTap: onFilters),
              GestureDetector(
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
              _RoundIcon(glyph: '☰', onTap: onMenu),
              _RoundIcon(glyph: '⋯', onTap: onMore),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.glyph, required this.onTap});

  final String glyph;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: Text(glyph, style: ui(size: 15, color: C.icon)),
      ),
    );
  }
}

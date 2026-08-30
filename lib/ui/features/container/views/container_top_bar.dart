import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `2b`'s minimal top bar. Panic is always reachable here — never
/// hidden behind an overflow menu.
class ContainerTopBar extends StatelessWidget {
  const ContainerTopBar({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.onBack,
    required this.onReload,
    required this.onPanic,
  });

  final String host;

  /// `site.proxyMode.name.toUpperCase()` for a proxied site, empty for a
  /// direct one. The caller computes this — there is no "DIRECT" label; the
  /// spec never shows one.
  final String routeLabel;

  /// Jade while the tunnel is up; amber while the container is still opening.
  final bool live;

  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onPanic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line07)),
      ),
      child: Row(
        children: [
          _IconSquare(glyph: '‹', size: 16, onTap: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: C.line08),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: live ? C.jade : C.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      host,
                      overflow: TextOverflow.ellipsis,
                      style: ui(size: 11.5, color: const Color(0xFFA9B0AE)),
                    ),
                  ),
                  if (routeLabel.isNotEmpty) ...[
                    const Spacer(),
                    Text(routeLabel,
                        style: ui(size: 9.5, weight: 500, color: C.textFaint)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _IconSquare(glyph: '⟳', size: 14, onTap: onReload),
          const SizedBox(width: 8),
          _IconSquare(
            glyph: '◉',
            size: 13,
            onTap: onPanic,
            background: C.danger.withValues(alpha: 0.14),
            color: C.danger,
          ),
        ],
      ),
    );
  }
}

class _IconSquare extends StatelessWidget {
  const _IconSquare({
    required this.glyph,
    required this.size,
    required this.onTap,
    this.background,
    this.color = C.icon,
  });

  final String glyph;
  final double size;
  final VoidCallback onTap;
  final Color? background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(glyph, style: ui(size: size, color: color)),
      ),
    );
  }
}

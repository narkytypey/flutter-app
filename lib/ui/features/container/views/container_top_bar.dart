import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.1's top bar (layout C). Keeps `2b`'s 12/8 padding,
/// 34px pill, 6px dot and 32px panic square; `2b`'s ‹ and ⟳ are gone — back
/// is on the bottom bar, reload in the ☰ menu. The pill ends in the shield,
/// which opens `6c`, and while the page loads a stop × sits just before it.
/// Panic is always here, never behind a menu.
class ContainerTopBar extends StatelessWidget {
  const ContainerTopBar({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.loading,
    required this.onStop,
    required this.onSiteDetails,
    required this.onPanic,
  });

  /// The page's host: after following a link, the other site's.
  final String host;

  /// `site.proxyMode.name.toUpperCase()` for a proxied site, empty for a
  /// direct one. The caller computes this — there is no "DIRECT" label; the
  /// spec never shows one.
  final String routeLabel;

  /// Jade while the tunnel is up; amber while the container is still opening.
  final bool live;

  /// Shows the stop ×.
  final bool loading;

  final VoidCallback onStop;

  /// The shield: `6c`.
  final VoidCallback onSiteDetails;
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
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.only(left: 12, right: 3),
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
                  Expanded(
                    child: Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ui(size: 11.5, color: const Color(0xFFA9B0AE)),
                    ),
                  ),
                  if (routeLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(routeLabel,
                        style: ui(size: 9.5, weight: 500, color: C.textFaint)),
                    const SizedBox(width: 2),
                  ],
                  if (loading)
                    IconTap(
                      glyph: AppGlyph.stop,
                      label: 'Stop',
                      onTap: onStop,
                      size: 28,
                      iconSize: 14,
                    ),
                  IconTap(
                    glyph: AppGlyph.shield,
                    label: 'Site details',
                    onTap: onSiteDetails,
                    size: 28,
                    iconSize: 15,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PanicSquare(onTap: onPanic),
        ],
      ),
    );
  }
}

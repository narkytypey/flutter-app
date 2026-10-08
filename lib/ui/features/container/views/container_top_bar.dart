import 'package:flutter/material.dart';

import '../../../../domain/models/route_display.dart';
import '../../../../domain/models/security_level.dart';
import '../../../core/host_text.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

export '../../../../domain/models/route_display.dart' show CaseKind;

/// Browser-chrome spec §6.1's top bar (layout C), restyled to v2 §8 `2b`: a
/// bar of at least 64 dp, a pill of at least 48 dp. Inside the pill, left to
/// right: the light, the case, the host (wrapping after its dots, never cut
/// short: the pill grows), the route badge (under the host when it does not
/// fit beside it), then the reload — a stop × while the page loads (user's
/// ruling 2026-10-05; reload is also in the ☰ menu) — and the shield, drawn
/// by security level, which opens `6c`. `2b`'s ‹ is gone — back is on the
/// bottom bar. A tap anywhere else on the pill starts typing an address
/// (§6.2). Panic is always here, never behind a menu.
class ContainerTopBar extends StatelessWidget {
  const ContainerTopBar({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.loading,
    required this.onEditAddress,
    required this.onStop,
    required this.onReload,
    required this.onSiteDetails,
    required this.onPanic,
    this.caseKind = CaseKind.keep,
    this.tor = false,
    this.securityLevel = SecurityLevel.standard,
  });

  /// The page's host: after following a link, the other site's.
  final String host;

  /// `site.proxyMode.name.toUpperCase()` for a proxied site, empty for a
  /// direct one. The caller computes this — there is no "DIRECT" label; the
  /// spec never shows one.
  final String routeLabel;

  /// Jade while the tunnel is up; amber while the container is still opening.
  final bool live;

  /// Shows the stop × in place of reload.
  final bool loading;

  /// The pill, outside its stop and shield: typing an address.
  final VoidCallback onEditAddress;
  final VoidCallback onStop;
  final VoidCallback onReload;

  /// The shield: `6c`.
  final VoidCallback onSiteDetails;
  final VoidCallback onPanic;

  /// The case's shape: solid for a site that keeps its storage, broken for
  /// one that does not.
  final CaseKind caseKind;

  /// The route is Tor: the case is drawn with a second edge.
  final bool tor;

  /// The level the site runs at: the shield's fill (never its colour).
  final SecurityLevel securityLevel;

  /// What a screen reader hears for the case: `6c`'s own words for the
  /// container's storage. A throwaway is wiped when it closes.
  static String caseLabel(CaseKind kind) => switch (kind) {
        CaseKind.keep => 'Keep for this site',
        CaseKind.wipe || CaseKind.throwaway => 'Wipe on exit',
      };

  static AppGlyph caseGlyph(CaseKind kind, {required bool tor}) {
    if (tor) return AppGlyph.caseDouble;
    return kind == CaseKind.keep ? AppGlyph.caseSolid : AppGlyph.caseBroken;
  }

  /// Restyle v2 §7, a protective change applying: the case redraws over
  /// [caseDuration] and the light goes amber → jade over [lightDuration];
  /// with animations turned off in the system, both take [stillDuration].
  static const caseDuration = Duration(milliseconds: 320);
  static const lightDuration = Duration(milliseconds: 150);
  static const stillDuration = Duration(milliseconds: 100);

  static AppGlyph shieldGlyph(SecurityLevel level) => switch (level) {
        SecurityLevel.standard => AppGlyph.shield,
        SecurityLevel.safer => AppGlyph.shieldHalf,
        SecurityLevel.safest => AppGlyph.shieldFull,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEditAddress,
              child: Container(
                key: const Key('address-pill'),
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: C.surface,
                  // Full on the 48 dp pill; when a long host makes it grow,
                  // its corners stay that round instead of turning it into a
                  // capsule that would cut into the first line.
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: C.line),
                ),
                child: LayoutBuilder(builder: (context, constraints) {
                  final still = MediaQuery.disableAnimationsOf(context);
                  final glyph = caseGlyph(caseKind, tor: tor);
                  final lead = [
                    AnimatedContainer(
                      duration: still ? stillDuration : lightDuration,
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: live ? C.jade : C.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      container: true,
                      label: caseLabel(caseKind),
                      child: AnimatedSwitcher(
                        duration: still ? stillDuration : caseDuration,
                        switchInCurve: still ? Curves.linear : Curves.easeOutCubic,
                        switchOutCurve: still ? Curves.linear : Curves.easeOutCubic,
                        child: AppIcon(glyph, key: ValueKey(glyph), size: 20, color: C.textMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            HostText(host, style: T.address.copyWith(color: C.pillText)),
                            if (routeLabel.isNotEmpty) Text(routeLabel, style: T.barBadge),
                          ],
                        ),
                      ),
                    ),
                  ];
                  final actions = [
                    if (loading)
                      IconTap(
                        glyph: AppGlyph.stop,
                        label: 'Stop',
                        onTap: onStop,
                        iconSize: 20,
                      )
                    else
                      IconTap(
                        glyph: AppGlyph.reload,
                        label: 'Reload',
                        onTap: onReload,
                        iconSize: 20,
                      ),
                    IconTap(
                      glyph: shieldGlyph(securityLevel),
                      label: 'Site details',
                      onTap: onSiteDetails,
                      iconSize: 22,
                    ),
                  ];
                  // The host gets the room left beside the light, the case
                  // and the two 48 dp actions. Where that is under about six
                  // characters (a narrow phone at a large text scale), the
                  // actions move under the host, in the same order, rather
                  // than squeeze it a letter at a time.
                  final hostRoom = constraints.maxWidth - 12 - 8 - 8 - 20 - 8 - 96;
                  final minRoom = MediaQuery.textScalerOf(context).scale(16) * 6;
                  if (hostRoom >= minRoom) {
                    return Row(children: [...lead, ...actions]);
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Row(children: lead),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
                    ],
                  );
                }),
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

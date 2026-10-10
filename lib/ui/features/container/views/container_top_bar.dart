import 'package:flutter/material.dart';

import '../../../../domain/models/route_display.dart';
import '../../../../domain/models/security_level.dart';
import '../../../core/host_text.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';

export '../../../../domain/models/route_display.dart' show CaseKind;

/// Browser-chrome spec §6.1's top bar (layout C), restyled to v2 §8 `2b`: a
/// bar of at least 64 dp, a pill of at least 48 dp. Inside the pill, left to
/// right: the light, the case, the host (wrapping after its dots, never cut
/// short: the pill grows), the route badge (under the host when it does not
/// fit beside it), then the reload — a stop × while the page loads (user's
/// ruling 2026-10-05; reload is also in the ☰ menu) — and the shield, drawn
/// by security level, which opens `6c`. `2b`'s ‹ is gone — back is on the
/// bottom bar. A tap anywhere else on the pill starts typing an address
/// (§6.2).
///
/// The container's only bar (user's rulings, 2026-10-10, replacing layout
/// C's bottom bar): after the pill, where panic was, the open count — the
/// number alone in an outlined box, which opens `2c` — and ☰. Back is
/// Android's own back, and back and forward are ☰'s first quick actions.
/// There is no panic button anywhere in the container: a panic starts only
/// by flipping the phone face down (`FlipPanicGuard`). Dashboard spec §9's
/// fling between open containers moved here with the count.
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
    required this.openCount,
    required this.onOpenSwitcher,
    required this.onMenu,
    this.onNextContainer,
    this.onPreviousContainer,
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

  /// Open containers, vault-wide (tabs spec §5.1).
  final int openCount;

  /// The count: `2c`.
  final VoidCallback onOpenSwitcher;

  /// ☰ (spec §6.4).
  final VoidCallback onMenu;

  /// Dashboard spec §9: a fling to the left views the next open container,
  /// to the right the previous. Null at that end: a fling that way does
  /// nothing.
  final VoidCallback? onNextContainer;
  final VoidCallback? onPreviousContainer;

  /// The open count's style, which `2c`'s header count shares (restyle v2
  /// §8): the tab role at 600, text-1.
  static TextStyle get openCountStyle => T.tabSelected;

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
  Widget build(BuildContext context) => _Fling(
        onNext: onNextContainer,
        onPrevious: onPreviousContainer,
        child: _bar(context),
      );

  Widget _bar(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      // 8, not 12, at the sides, and no gap before the count (whose 48 dp
      // target already rings its box with space): on a 360 dp phone that
      // leaves the host its six characters, so reload and the shield stay
      // beside it rather than drop under it.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                        boxShadow: C.glow(live ? C.jade : C.warning),
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
                  // than squeeze it a letter at a time. [constraints] are
                  // already inside the pill's padding and border; six
                  // characters of the 16 sp face are about four of its em.
                  final hostRoom = constraints.maxWidth - 8 - 8 - 20 - 8 - 96;
                  final minRoom = MediaQuery.textScalerOf(context).scale(16) * 4;
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
          _OpenCount(count: openCount, onTap: onOpenSwitcher),
          IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: onMenu),
        ],
      ),
    );
  }
}

/// The number of open containers in an outlined box, a 48 dp target named
/// "Open sessions" for screen readers. In text-1, not jade: jade on `2b` is
/// the pill's light.
class _OpenCount extends StatelessWidget {
  const _OpenCount({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Open sessions',
      button: true,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          key: const Key('open-sessions-target'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: C.textPrimary, width: 1.5),
              ),
              // Sized to the number, never stretched to the room it is given.
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text('$count', style: ContainerTopBar.openCountStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashboard spec §9's swipe, on the whole bar: a fling must travel at least
/// the bar's own height, so a tap that moves a little is still a tap. With
/// nowhere to go there is no drag recogniser at all, so every tap on the bar
/// is exactly as it would be without it.
class _Fling extends StatefulWidget {
  const _Fling({required this.onNext, required this.onPrevious, required this.child});

  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final Widget child;

  @override
  State<_Fling> createState() => _FlingState();
}

class _FlingState extends State<_Fling> {
  /// How far the current horizontal drag has gone; left is negative.
  double _travel = 0;

  void _dragEnded() {
    final threshold = context.size?.height ?? double.infinity;
    if (_travel <= -threshold) {
      widget.onNext?.call();
    } else if (_travel >= threshold) {
      widget.onPrevious?.call();
    }
    _travel = 0;
  }

  @override
  Widget build(BuildContext context) {
    final swipes = widget.onNext != null || widget.onPrevious != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: swipes ? (_) => _travel = 0 : null,
      onHorizontalDragUpdate: swipes ? (details) => _travel += details.delta.dx : null,
      onHorizontalDragEnd: swipes ? (_) => _dragEnded() : null,
      child: widget.child,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/monogram.dart';

/// One row of the quick switcher, already reduced to strings. The widget
/// layer does no formatting of its own — see `SessionEntry` in the dashboard
/// for the same pattern.
///
/// [meta] is `'viewing now · $mode'` for the live session and
/// `'background · ${age}'` for the rest. Spec `2c`'s copy for the background
/// case ("background · 2 min", "background · 14 min") spells the unit out —
/// it does not match Plan 1's `relativeAge` output ("2m", "14m"), which is a
/// different screen's convention. The caller formats [meta]; this widget
/// never calls `relativeAge` itself.
class SwitcherEntry {
  const SwitcherEntry({
    required this.siteId,
    required this.name,
    required this.monogram,
    required this.meta,
    required this.live,
  });

  final String siteId;
  final String name;
  final String monogram;
  final String meta;
  final bool live;
}

/// Spec `2c` — the quick switcher drawer. Both destructive actions (wipe,
/// panic) live on this sheet by design and neither gets a confirmation
/// dialog; `3c` establishes that panic simply happens and reports afterwards.
class SwitcherSheet extends StatelessWidget {
  const SwitcherSheet({
    super.key,
    required this.entries,
    required this.workspaceName,
    required this.onCloseSession,
    required this.onCloseAllAndWipe,
    required this.onPanic,
  });

  final List<SwitcherEntry> entries;
  final String workspaceName;
  final void Function(String siteId) onCloseSession;
  final VoidCallback onCloseAllAndWipe;
  final VoidCallback onPanic;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: C.sheet,
        border: Border(top: BorderSide(color: C.line09)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3134),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${entries.length} OPEN SESSIONS',
                      style: ui(
                          size: 10,
                          weight: 500,
                          letterSpacing: 1.0,
                          color: C.jade)),
                  Text(workspaceName.toUpperCase(),
                      style: ui(
                          size: 10,
                          weight: 500,
                          letterSpacing: 0.6,
                          color: C.textFaint)),
                ],
              ),
            ),
            for (var i = 0; i < entries.length; i++)
              _SwitcherRow(
                entries[i],
                isFirst: i == 0,
                showDivider: i != entries.length - 1,
                onClose: () => onCloseSession(entries[i].siteId),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onCloseAllAndWipe,
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: C.button,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('Close all and wipe',
                            style:
                                ui(size: 13.5, weight: 500, color: C.textSecondary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onPanic,
                    child: Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: C.danger.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: C.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text('◉', style: ui(size: 15, color: C.danger)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 3×38 rail on a switcher row. Unlike Plan 1's `StatusRail` (jade or
/// grey — live vs. never-opened), a backgrounded session here is still
/// running, just not the one on screen, so spec `2c` keeps it jade at 45%
/// opacity rather than the grey `StatusRail.live == false` would draw.
class _SessionRail extends StatelessWidget {
  const _SessionRail({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 38,
      decoration: BoxDecoration(
        color: live ? C.jade : C.jade.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SwitcherRow extends StatelessWidget {
  const _SwitcherRow(
    this.entry, {
    required this.isFirst,
    required this.showDivider,
    required this.onClose,
  });

  final SwitcherEntry entry;

  /// The header above already supplies the gap to the first row (`0 18px
  /// 10px`), so the first row's own top padding is 0 — every later row gets
  /// the full 14px spec `2c` draws between rows.
  final bool isFirst;
  final bool showDivider;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, isFirst ? 0 : 14, 18, 14),
          child: Row(
            children: [
              _SessionRail(live: entry.live),
              const SizedBox(width: 12),
              Monogram(entry.monogram),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.name,
                        style: ui(size: 14.5, weight: 500, color: C.textPrimary)),
                    const SizedBox(height: 3),
                    Text(entry.meta, style: ui(size: 10.5, color: C.textFaint)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Text('×', style: ui(size: 16, color: C.textFaint)),
              ),
            ],
          ),
        ),
        if (showDivider) const Hairline(),
      ],
    );
  }
}

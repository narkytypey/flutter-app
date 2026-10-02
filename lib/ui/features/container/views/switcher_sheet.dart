import 'package:flutter/material.dart';

import '../../../../domain/models/switcher_entry.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../../core/widgets/monogram.dart';

/// Spec `2c` — the quick switcher drawer. Both destructive actions (wipe,
/// panic) live on this sheet by design and neither gets a confirmation
/// dialog; `3c` establishes that panic simply happens and reports afterwards.
///
/// Tabs spec §5.1: under a container with two or more pages, a row per page,
/// indented to the container row's text column. A container row taps to view
/// that container, a page row to view that page, and each × closes only its
/// own row's container or page. A hairline falls only between container
/// groups. The body scrolls under the fixed handle, so many pages never
/// overflow the sheet.
class SwitcherSheet extends StatelessWidget {
  const SwitcherSheet({
    super.key,
    required this.entries,
    required this.workspaceName,
    required this.onViewContainer,
    required this.onViewPage,
    required this.onCloseSession,
    required this.onClosePage,
    required this.onCloseAllAndWipe,
    required this.onPanic,
  });

  /// Exactly the listed containers, so the header counts them.
  final List<SwitcherEntry> entries;
  final String workspaceName;
  final void Function(String siteId) onViewContainer;
  final void Function(String siteId, String pageId) onViewPage;
  final void Function(String siteId) onCloseSession;
  final void Function(String siteId, String pageId) onClosePage;
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
                color: C.handle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${entries.length} OPEN SESSIONS',
                            style: ui(
                              size: 10,
                              weight: 500,
                              letterSpacing: 1.0,
                              color: C.jade,
                            ),
                          ),
                          Text(
                            workspaceName.toUpperCase(),
                            style: ui(
                              size: 10,
                              weight: 500,
                              letterSpacing: 0.6,
                              color: C.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < entries.length; i++) ...[
                      _SwitcherRow(
                        entries[i],
                        isFirst: i == 0,
                        onView: () => onViewContainer(entries[i].siteId),
                        onClose: () => onCloseSession(entries[i].siteId),
                      ),
                      for (final page in entries[i].pages)
                        _PageRow(
                          page,
                          onView: () =>
                              onViewPage(entries[i].siteId, page.pageId),
                          onClose: () =>
                              onClosePage(entries[i].siteId, page.pageId),
                        ),
                      // Only between container groups: after a group's last row.
                      if (i != entries.length - 1) const Hairline(),
                    ],
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
                                child: Text(
                                  'Close all and wipe',
                                  style: ui(
                                    size: 13.5,
                                    weight: 500,
                                    color: C.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Semantics(
                            label: 'Panic',
                            button: true,
                            excludeSemantics: true,
                            onTap: onPanic,
                            child: GestureDetector(
                              onTap: onPanic,
                              child: Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: C.danger.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: C.danger.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: const AppIcon(
                                  AppGlyph.panic,
                                  size: 18,
                                  color: C.danger,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
    required this.onView,
    required this.onClose,
  });

  final SwitcherEntry entry;

  /// The header above already supplies the gap to the first row (`0 18px
  /// 10px`), so the first row's own top padding is 0 — every later row gets
  /// the full 14px spec `2c` draws between rows.
  final bool isFirst;
  final VoidCallback onView;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onView,
      child: Padding(
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
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui(size: 14.5, weight: 500, color: C.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    entry.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui(size: 10.5, color: C.textFaint),
                  ),
                ],
              ),
            ),
            // Its own target, so a tap on × never also views the row.
            IconTap(
              glyph: AppGlyph.close,
              label: 'Close',
              onTap: onClose,
              size: 24,
              iconSize: 16,
              color: C.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// One page under its container (tabs spec §5.1): page data only, no rail
/// and no jade. Indented to the container row's text column: rail, gap,
/// monogram, gap.
class _PageRow extends StatelessWidget {
  const _PageRow(this.page, {required this.onView, required this.onClose});

  final SwitcherPage page;
  final VoidCallback onView;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onView,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18 + 3 + 12 + 36 + 12, 0, 18, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    page.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui(
                      size: 13,
                      weight: 500,
                      color: page.current ? C.textPrimary : C.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    page.host,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(size: 10.5, color: C.textFaint),
                  ),
                ],
              ),
            ),
            // Its own target, so a tap on × never also views the page.
            IconTap(
              glyph: AppGlyph.close,
              label: 'Close',
              onTap: onClose,
              size: 24,
              iconSize: 16,
              color: C.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../domain/models/switcher_entry.dart';
import '../../../core/host_text.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/status_rail.dart';
import 'container_top_bar.dart';

/// Spec `2c` — the quick switcher drawer. "Close all and wipe" lives on this
/// sheet with no confirmation dialog. Its panic tile is gone (user's ruling,
/// 2026-10-10): a panic starts only by flipping the phone face down.
///
/// Tabs spec §5.1: under a container with two or more pages, a row per page,
/// indented to the container row's text column. A container row taps to view
/// that container, a page row to view that page, and each × closes only its
/// own row's container or page. A hairline falls only between container
/// groups. The body scrolls under the fixed handle, so many pages never
/// overflow the sheet.
///
/// Restyle v2 §8 `2c`: the header count is set exactly like the top bar's
/// open count; the viewed container has the jade light, the others an edge
/// ring; hosts wrap and are never cut short.
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
  });

  /// Exactly the listed containers, so the header counts them.
  final List<SwitcherEntry> entries;
  final String workspaceName;
  final void Function(String siteId) onViewContainer;
  final void Function(String siteId, String pageId) onViewPage;
  final void Function(String siteId) onCloseSession;
  final void Function(String siteId, String pageId) onClosePage;
  final VoidCallback onCloseAllAndWipe;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: C.sheet,
        border: Border(top: BorderSide(color: C.line)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.sheet)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, -12),
          ),
        ],
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${entries.length} OPEN SESSIONS',
                            style: ContainerTopBar.openCountStyle,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              workspaceName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                              style: T.sectionLabel,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              key: const Key('close-all-and-wipe'),
                              onTap: onCloseAllAndWipe,
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 48),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: C.button,
                                  borderRadius: BorderRadius.circular(R.input),
                                ),
                                child: Text(
                                  'Close all and wipe',
                                  textAlign: TextAlign.center,
                                  style: T.label.copyWith(fontWeight: FontWeight.w500),
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

class _SwitcherRow extends StatelessWidget {
  const _SwitcherRow(
    this.entry, {
    required this.isFirst,
    required this.onView,
    required this.onClose,
  });

  final SwitcherEntry entry;

  /// The header above already supplies the gap to the first row, so the first row's own top padding is 0 — every later row gets
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
        padding: EdgeInsets.fromLTRB(16, isFirst ? 0 : 8, 4, 8),
        child: Row(
          children: [
            // The viewed container's jade light; a background one's edge ring.
            StatusRail(live: entry.live),
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
                    style: T.rowTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(entry.meta, style: T.meta),
                ],
              ),
            ),
            // Its own target, so a tap on × never also views the row.
            IconTap(
              glyph: AppGlyph.close,
              label: 'Close',
              onTap: onClose,
              iconSize: 20,
              color: C.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// One page under its container (tabs spec §5.1): page data only, no light
/// and no jade. Indented to the container row's text column: light, gap,
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
        padding: const EdgeInsets.fromLTRB(16 + 10 + 12 + 36 + 12, 0, 4, 8),
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
                    style: page.current ? T.rowTitle : T.rowTitleIdle,
                  ),
                  const SizedBox(height: 2),
                  // Restyle v2 §1.6: never cut short; it wraps after a dot.
                  HostText(page.host, style: T.metaValue),
                ],
              ),
            ),
            // Its own target, so a tap on × never also views the page.
            IconTap(
              glyph: AppGlyph.close,
              label: 'Close',
              onTap: onClose,
              iconSize: 20,
              color: C.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

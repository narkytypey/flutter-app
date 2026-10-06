import 'package:flutter/material.dart';

import '../../../../domain/models/blocked_tally.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../../core/widgets/monogram.dart';

/// Spec `5c` — a quiet log, not a dashboard of scary numbers. Reachable
/// from the dashboard menu, never pushed as a notification (turn 5's note).
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.tally, this.onBack});

  final BlockedTally tally;
  /// The header's back icon. Null draws none: the dashboard's Today tab
  /// (dashboard spec §4.1).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 4, 8, 16, 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  if (onBack != null) ...[
                    IconTap(
                      glyph: AppGlyph.back,
                      label: 'Back',
                      onTap: onBack,
                      iconSize: 22,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(child: Text('Today', style: T.screenTitle)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  Text('${tally.total}', style: T.display),
                  const SizedBox(height: 4),
                  Text(
                      '${tally.total == 1 ? 'request' : 'requests'} blocked across '
                      '${tally.siteCount} ${tally.siteCount == 1 ? 'site' : 'sites'}',
                      style: T.bodyMuted),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: C.line),
                        bottom: BorderSide(color: C.line),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final category in tally.categories)
                          _CategoryBar(tally: tally, entry: category),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
                    child: Text('BY SITE', style: T.sectionLabel),
                  ),
                  if (tally.sites.isNotEmpty)
                    Group(children: [for (final site in tally.sites) _SiteRow(site: site)]),
                  const SizedBox(height: 20),
                  Text(
                    'Counts are kept in memory only and reset when the app closes.',
                    style: T.sub.copyWith(color: C.textFaint),
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

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.tally, required this.entry});

  final BlockedTally tally;
  final CategoryTally entry;

  @override
  Widget build(BuildContext context) {
    // Restyle v2 §8 (`5c`): a count is not live state, so no bar is jade.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 128,
            child: Text(entry.category.label, style: T.bodyMuted),
          ),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(4)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: categoryFraction(tally, entry.category),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: C.textMuted, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('${entry.count}', textAlign: TextAlign.right, style: T.value),
          ),
        ],
      ),
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site});

  final SiteTally site;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // `open: false` is Monogram's idle treatment, which is what `5c`
            // draws for a site that is being reported on rather than running.
            Monogram(site.monogram, size: 32, radius: R.monogram, fontSize: 13, open: false),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                site.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: T.rowTitle,
              ),
            ),
            const SizedBox(width: 12),
            Text('${site.count}', style: T.value),
          ],
        ),
      ),
    );
  }
}

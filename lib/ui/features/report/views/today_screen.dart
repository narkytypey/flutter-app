import 'package:flutter/material.dart';

import '../../../../domain/models/blocked_tally.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';

/// Spec `5c` — a quiet log, not a dashboard of scary numbers. Reachable
/// from the dashboard menu, never pushed as a notification (turn 5's note).
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.tally, required this.onBack});

  final BlockedTally tally;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Text('‹', style: TextStyle(fontSize: 16, color: C.icon)),
                  ),
                  const SizedBox(width: 10),
                  Text('Today', style: T.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.only(bottom: 22),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${tally.total}', style: ui(size: 34, weight: 600, letterSpacing: -0.68)),
                        const SizedBox(height: 8),
                        Text('requests blocked across ${tally.siteCount} sites',
                            style: ui(size: 13.5, color: C.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: C.line06)),
                    ),
                    child: Column(
                      children: [
                        for (final category in tally.categories)
                          _CategoryBar(tally: tally, entry: category),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
                    child: Text(
                      'BY SITE',
                      style: ui(size: 10.5, weight: 500, letterSpacing: 1.05, color: C.textFaint),
                    ),
                  ),
                  for (final site in tally.sites) _SiteRow(site: site),
                  const SizedBox(height: 20),
                  Text(
                    'Counts are kept in memory only and reset when the app closes.',
                    style: ui(size: 12, height: 1.6, color: C.textDim),
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
    final fillColor = entry.category == BlockedCategory.permissionAsks ? C.warning : C.jade;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(entry.category.label, style: ui(size: 13, color: C.textTertiary)),
          ),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(color: C.barTrack, borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: categoryFraction(tally, entry.category),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${entry.count}',
              textAlign: TextAlign.right,
              style: ui(size: 12.5, weight: 500, color: C.textMuted),
            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // `open: false` is Monogram's idle treatment — `C.raised` on
              // `C.textMuted` — which is what `5c` draws for a site that is
              // being reported on rather than running.
              Monogram(site.monogram, size: 32, radius: 9, fontSize: 12.5, open: false),
              const SizedBox(width: 11),
              Text(site.name, style: ui(size: 14, color: C.textSecondary)),
            ],
          ),
          Text('${site.count}', style: ui(size: 12.5, weight: 500, color: C.textMuted)),
        ],
      ),
    );
  }
}

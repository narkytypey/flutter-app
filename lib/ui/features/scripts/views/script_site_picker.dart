import 'package:flutter/material.dart';

import '../../../../domain/models/site.dart';
import '../../../core/host_text.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/sheet.dart';

/// What `10e`'s "+ Add site" opens. The canvas draws the chip but not this
/// sheet, so its shape is the user's ruling (2026-09-29): no title, one row
/// per site that is not on the script yet — monogram, name, host — and
/// tapping a row reports it. It adds no copy of its own.
///
/// The caller decides which [sites] are offered and closes the sheet.
class ScriptSitePicker extends StatelessWidget {
  const ScriptSitePicker({super.key, required this.sites, required this.onPick});

  final List<Site> sites;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      scrolls: false,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 16),
      children: [
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (var i = 0; i < sites.length; i++)
                _SiteRow(
                  site: sites[i],
                  showDivider: i != sites.length - 1,
                  onTap: () => onPick(sites[i].id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site, required this.showDivider, required this.onTap});

  final Site site;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: showDivider
            ? const BoxDecoration(border: Border(bottom: BorderSide(color: C.lineSoft)))
            : null,
        child: Row(
          children: [
            Monogram(site.monogram),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(site.name, style: T.rowTitle),
                  const SizedBox(height: 2),
                  // Never ellipsized: it wraps after a dot (restyle v2 §1.6).
                  HostText(site.host, style: T.metaValue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/status_rail.dart';
import '../view_models/dashboard_view.dart';

/// One site on the dashboard. Hairline-separated, never a card.
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onLongPress,
  });

  final SessionEntry entry;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final live = entry.live;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line05)),
        ),
        child: IntrinsicHeight(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                StatusRail(live: live),
                const SizedBox(width: 12),
                Monogram(entry.monogram, open: live),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: live ? T.rowTitle : T.rowTitleIdle),
                      const SizedBox(height: 3),
                      Text(
                        entry.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: live ? T.meta : T.metaIdle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  entry.age,
                  style: live
                      ? ui(size: 10.5, color: C.textMuted)
                      : T.metaIdle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

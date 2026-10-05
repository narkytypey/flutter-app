import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// What a long-press on a dashboard row can do. Spec `7b`.
///
/// The spec also draws "Open in Ephemeral", "Duplicate into Work" and
/// "Require PIN to open". None is built, so none is shown (user's ruling,
/// 2026-10-05: hidden until built, not drawn as rows that do nothing). Each
/// comes back with its action.
enum SiteRowAction {
  open,
  editSettings,
  wipeData,
  removeSite,
}

/// Spec `7b` — long-press on a dashboard row.
///
/// The two groups are load-bearing, not decorative. The spec's own title is
/// "wipe sits apart from the rest": a destructive row must never be one
/// mis-tap away from an ordinary one, so [SiteRowAction.wipeData] and
/// [SiteRowAction.removeSite] live in a second [SheetGroup] with its own
/// border. Do not merge them into the first group to save a few pixels.
class SiteRowMenu extends StatelessWidget {
  const SiteRowMenu({
    super.key,
    required this.monogram,
    required this.name,
    required this.subtitle,
    required this.onAction,
    required this.onCancel,
  });

  final String monogram;
  final String name;
  final String subtitle;

  final ValueChanged<SiteRowAction> onAction;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    // Taller than a modal sheet may be on a short phone: scroll, not overflow.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.barTrack,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
              ),
              child: Row(
                children: [
                  Monogram(monogram),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: T.rowTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: ui(size: 11, color: C.textFaint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SheetGroup(
                  children: [
                    SheetRow(label: 'Open', onTap: () => onAction(SiteRowAction.open)),
                    SheetRow(
                      label: 'Edit settings',
                      onTap: () => onAction(SiteRowAction.editSettings),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SheetGroup(
                  children: [
                    SheetRow(
                      label: "Wipe this site's data",
                      labelColor: C.textSecondary,
                      onTap: () => onAction(SiteRowAction.wipeData),
                    ),
                    SheetRow(
                      label: 'Remove site',
                      labelColor: C.danger,
                      onTap: () => onAction(SiteRowAction.removeSite),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                PillButton(label: 'Cancel', height: 50, onTap: onCancel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

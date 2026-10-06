import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/choice_chip.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';

/// One workspace's chip, already reduced to what it shows.
class WorkspaceChip {
  const WorkspaceChip({required this.id, required this.name, required this.selected});

  final String id;
  final String name;

  /// The viewed workspace.
  final bool selected;
}

/// Dashboard spec §4.2: the top of Sites. One chip per workspace, in the
/// vault's order, then `+`, scrolling sideways. A tap views a workspace, a
/// long-press opens its form (`10b`), and `+` makes a new one. Deleting stays
/// in Settings ▸ Workspaces. No jade: the selected chip is an [AppChip]
/// (restyle v2 §5: raised fill, text-1 outline, a leading check). [badge] is the viewed workspace's `WIPES ON EXIT`,
/// fixed at the row's end (plan D3).
class WorkspaceChips extends StatelessWidget {
  const WorkspaceChips({
    super.key,
    required this.chips,
    required this.onPick,
    required this.onEdit,
    required this.onNew,
    this.badge,
  });

  final List<WorkspaceChip> chips;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onEdit;
  final VoidCallback onNew;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(
                    children: [
                      for (final chip in chips) ...[_chip(chip), const SizedBox(width: 8)],
                      IconTap(
                        glyph: AppGlyph.plus,
                        label: 'New workspace',
                        onTap: onNew,
                        size: 48,
                        iconSize: 20,
                        color: C.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              if (badge != null) Text(badge!, style: T.barBadge),
            ],
          ),
        ),
        Hairline(color: C.line),
      ],
    );
  }

  Widget _chip(WorkspaceChip chip) {
    return AppChip(
      label: chip.name,
      selected: chip.selected,
      onTap: () => onPick(chip.id),
      onLongPress: () => onEdit(chip.id),
    );
  }
}

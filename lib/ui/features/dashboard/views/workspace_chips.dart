import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
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
/// in Settings ▸ Workspaces. No jade: the selected chip is drawn like `2a`'s
/// selected mode chip. [badge] is the viewed workspace's `WIPES ON EXIT`,
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
          padding: const EdgeInsets.fromLTRB(0, 10, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 18, right: 8),
                  child: Row(
                    children: [
                      for (final chip in chips) ...[_chip(chip), const SizedBox(width: 8)],
                      IconTap(
                        glyph: AppGlyph.plus,
                        label: 'New workspace',
                        onTap: onNew,
                        size: 32,
                        iconSize: 14,
                        color: C.textMuted,
                        background: C.button,
                        radius: 16,
                      ),
                    ],
                  ),
                ),
              ),
              if (badge != null) Text(badge!, style: T.barBadge),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _chip(WorkspaceChip chip) {
    return Semantics(
      button: true,
      selected: chip.selected,
      child: GestureDetector(
        onTap: () => onPick(chip.id),
        onLongPress: () => onEdit(chip.id),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: chip.selected ? C.selected : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: chip.selected ? C.line10 : C.line07),
          ),
          child: Text(
            chip.name,
            style: ui(
              size: 12.5,
              weight: 500,
              color: chip.selected ? C.textPrimary : C.tabInactive,
            ),
          ),
        ),
      ),
    );
  }
}

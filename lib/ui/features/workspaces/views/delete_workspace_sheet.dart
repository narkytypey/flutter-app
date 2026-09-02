import 'package:flutter/material.dart';

import '../../../../domain/workspace_deletion.dart';
import '../../../../domain/workspace_stats.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Spec `10c` — an itemised list of what goes, typed confirmation.
class DeleteWorkspaceSheet extends StatefulWidget {
  const DeleteWorkspaceSheet({
    super.key,
    required this.workspaceName,
    required this.sitesRemoved,
    required this.storageBytesWiped,
    required this.onCancel,
    required this.onDelete,
  });

  final String workspaceName;
  final int sitesRemoved;
  final int storageBytesWiped;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  State<DeleteWorkspaceSheet> createState() => _DeleteWorkspaceSheetState();
}

class _DeleteWorkspaceSheetState extends State<DeleteWorkspaceSheet> {
  final _controller = TextEditingController();
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final now = confirmsDeletion(_controller.text, widget.workspaceName);
      if (now != _confirmed) setState(() => _confirmed = now);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        // Curly quotes are what the spec draws: `Delete “Work”?`. It is the
        // only curly-quoted string in the canvas file, and the canvas is
        // authoritative over the plan file, which wrote it with straight
        // quotes. Do not "normalise" these to " on a later pass.
        Text('Delete “${widget.workspaceName}”?',
            style: ui(size: 17, weight: 600, letterSpacing: -0.17)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: C.line08)),
            child: Column(
              children: [
                _statRow('Sites removed', '${widget.sitesRemoved}'),
                _statRow('Logins destroyed', '${widget.sitesRemoved}'),
                _statRow('Stored data wiped',
                    wholeMegabytes(widget.storageBytesWiped)),
                _statRow('Custom scripts kept', 'In the script library',
                    muted: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'This cannot be undone and there is no backup unless you made one yourself.',
          style: ui(size: 12.5, height: 1.6, color: C.textMuted),
        ),
        const SizedBox(height: 16),
        Text('Type the name to confirm',
            style: ui(size: 11.5, color: C.textFaint)),
        const SizedBox(height: 8),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.line10),
          ),
          child: TextField(
            controller: _controller,
            style: ui(size: 14, color: C.textSecondary),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: widget.workspaceName,
              hintStyle: ui(size: 14, color: C.textDisabled),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: PillButton(label: 'Cancel', onTap: widget.onCancel)),
            const SizedBox(width: 9),
            Expanded(
              child: _DeleteButton(enabled: _confirmed, onTap: widget.onDelete),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statRow(String label, String value, {bool muted = false}) {
    return Container(
      color: C.surface,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: ui(size: 13, color: C.textTertiary)),
          Text(value,
              style: ui(size: 13, color: muted ? C.textMuted : C.textPrimary)),
        ],
      ),
    );
  }
}

/// Spec `10c`'s Delete button fills `#241C1D` (danger surface) with a
/// `#8A6A62` (danger-muted) label and a 28%-alpha danger border — a
/// combination none of Plan 1's [PillTone] values produce, so it is a small
/// local button rather than a fourth bespoke tone added for one screen.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: C.dangerSurface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: C.danger.withValues(alpha: enabled ? 0.28 : 0.1)),
          ),
          child: Text(
            'Delete',
            style: ui(
                size: 14.5,
                weight: 500,
                color: enabled ? C.dangerMuted : C.textDisabled),
          ),
        ),
      ),
    );
  }
}

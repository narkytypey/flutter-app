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
        Text('Delete “${widget.workspaceName}”?', style: T.sheetTitle),
        const SizedBox(height: S.s4),
        SheetGroup(
          children: [
            _statRow('Sites removed', '${widget.sitesRemoved}'),
            _statRow('Logins destroyed', '${widget.sitesRemoved}'),
            _statRow('Stored data wiped',
                wholeMegabytes(widget.storageBytesWiped)),
            _statRow('Custom scripts kept', 'In the script library',
                muted: true),
          ],
        ),
        const SizedBox(height: S.s4),
        Text(
          'This cannot be undone and there is no backup unless you made one yourself.',
          style: T.sub,
        ),
        const SizedBox(height: S.s4),
        Text('Type the name to confirm', style: T.meta),
        const SizedBox(height: S.s2),
        _SheetInputFrame(
          child: TextField(
            controller: _controller,
            style: T.body,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: widget.workspaceName,
              hintStyle: T.body.copyWith(color: C.textMuted),
            ),
          ),
        ),
        const SizedBox(height: S.s4),
        Row(
          children: [
            Expanded(child: PillButton(label: 'Cancel', onTap: widget.onCancel)),
            const SizedBox(width: S.s2),
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
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: S.s4, vertical: S.s3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: T.sub)),
          const SizedBox(width: S.s3),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: muted ? T.sub : T.sub.copyWith(color: C.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// An input on a sheet (restyle v2 §2.1, §4): the raised tone, radius 14, a
/// 1.5 dp edge border that turns 2 dp text-1 while the field has focus.
class _SheetInputFrame extends StatelessWidget {
  const _SheetInputFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: S.s3),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: C.button,
            borderRadius: BorderRadius.circular(R.input),
            border: Border.all(
              color: focused ? C.textPrimary : C.edge,
              width: focused ? 2 : 1.5,
            ),
          ),
          child: child,
        );
      }),
    );
  }
}

/// Spec `10c`'s Delete (restyle v2 §8): the danger wash with a danger label
/// and, once the typed name matches, a 1.5 dp danger outline. Before that it
/// is inert: a readable tone and no outline (§2.2), so it does not read as
/// something to tap.
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(R.full);
    return Material(
      key: const Key('delete-workspace-button'),
      color: C.dangerSurface,
      borderRadius: r,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: r,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: S.s3, vertical: S.s2),
          decoration: BoxDecoration(
            borderRadius: r,
            border: enabled ? Border.all(color: C.danger, width: 1.5) : null,
          ),
          child: Text(
            'Delete',
            textAlign: TextAlign.center,
            style: T.label.copyWith(color: enabled ? C.danger : C.textMuted),
          ),
        ),
      ),
    );
  }
}

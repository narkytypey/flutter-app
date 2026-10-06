import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/models/workspace.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../container/views/address_edit_bar.dart' show InputFrame;

class WorkspaceFormResult {
  const WorkspaceFormResult({
    required this.name,
    required this.markerIndex,
    required this.storageRule,
    required this.requirePin,
    required this.showInDecoy,
  });

  final String name;
  final int markerIndex;
  final StorageRule storageRule;
  final bool requirePin;
  final bool showInDecoy;
}

/// Spec `10b` — used both to create a workspace and, with the caller passing
/// its current values as `initial*`, to edit one. The spec draws only the
/// create case; [title] is the one thing that visibly changes between them.
class WorkspaceFormScreen extends StatefulWidget {
  const WorkspaceFormScreen({
    super.key,
    required this.title,
    required this.initialName,
    required this.initialMarkerIndex,
    required this.initialStorageRule,
    required this.initialRequirePin,
    required this.initialShowInDecoy,
    required this.onSave,
    required this.onClose,
  });

  final String title;
  final String initialName;
  final int initialMarkerIndex;
  final StorageRule initialStorageRule;
  final bool initialRequirePin;
  final bool initialShowInDecoy;
  /// Save is ignored while a returned future is still running, so a double
  /// tap writes (and pops) once.
  final FutureOr<void> Function(WorkspaceFormResult result) onSave;
  final VoidCallback onClose;

  @override
  State<WorkspaceFormScreen> createState() => _WorkspaceFormScreenState();
}

class _WorkspaceFormScreenState extends State<WorkspaceFormScreen> {
  late final _nameController = TextEditingController(text: widget.initialName);
  late int _markerIndex = widget.initialMarkerIndex;
  late StorageRule _storageRule = widget.initialStorageRule;
  late bool _requirePin = widget.initialRequirePin;
  late bool _showInDecoy = widget.initialShowInDecoy;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    _saving = true;
    try {
      await _submit();
    } finally {
      _saving = false;
    }
  }

  FutureOr<void> _submit() => widget.onSave(WorkspaceFormResult(
      name: _nameController.text,
      markerIndex: _markerIndex,
      storageRule: _storageRule,
      requirePin: _requirePin,
      showInDecoy: _showInDecoy,
    ));


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  IconTap(
                    glyph: AppGlyph.close,
                    label: 'Close',
                    onTap: widget.onClose,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: S.s2),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: T.appBarTitle,
                      ),
                    ),
                  ),
                  _FormSaveAction(onTap: _save),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.s4, S.s4, S.s4, S.s6),
                children: [
                  _fieldLabel('NAME'),
                  const SizedBox(height: S.s2),
                  InputFrame(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: S.s3),
                    child: TextField(
                      controller: _nameController,
                      style: T.body,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: S.s6),
                  _fieldLabel('MARKER'),
                  const SizedBox(height: S.s1),
                  Wrap(
                    spacing: S.s1,
                    children: [
                      for (var i = 0; i < C.markers.length; i++)
                        _MarkerSwatch(
                          key: Key('marker-$i'),
                          index: i,
                          selected: i == _markerIndex,
                          onTap: () => setState(() => _markerIndex = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: S.s5),
                  _fieldLabel('STORAGE'),
                  const SizedBox(height: S.s2),
                  Group(
                    padding: EdgeInsets.zero,
                    children: [
                      _storageOption(
                        title: 'Keep between sessions',
                        subtitle: 'Stays signed in',
                        selected: _storageRule == StorageRule.keep,
                        onTap: () =>
                            setState(() => _storageRule = StorageRule.keep),
                      ),
                      _storageOption(
                        title: 'Wipe when the app closes',
                        subtitle: 'Nothing survives a restart',
                        selected: _storageRule == StorageRule.wipeOnExit,
                        onTap: () => setState(
                            () => _storageRule = StorageRule.wipeOnExit),
                      ),
                    ],
                  ),
                  const SizedBox(height: S.s4),
                  Group(
                    padding: EdgeInsets.zero,
                    children: [
                      _toggleRow(
                        title: 'Ask for PIN to enter',
                        subtitle: 'Applies to the whole workspace',
                        value: _requirePin,
                        onChanged: (v) => setState(() => _requirePin = v),
                      ),
                      _toggleRow(
                        title: 'Show in decoy vault',
                        subtitle: 'Off keeps it invisible behind the second PIN',
                        value: _showInDecoy,
                        onChanged: (v) => setState(() => _showInDecoy = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text, style: T.sectionLabel);

  Widget _storageOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: S.s4, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: selected ? T.rowTitle : T.rowTitleIdle),
                    const SizedBox(height: 2),
                    Text(subtitle, style: T.sub),
                  ],
                ),
              ),
              const SizedBox(width: S.s3),
              _FormRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    // A tap anywhere on the row toggles it, not only on the switch.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: S.s4, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: T.body),
                  const SizedBox(height: 2),
                  Text(subtitle, style: T.sub),
                ],
              ),
            ),
            const SizedBox(width: S.s3),
            AppToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A marker swatch in `10b`'s picker: a 48 dp target around a 32 dp swatch.
/// The chosen one carries a 2 dp text-1 ring and a check, so the choice is
/// never told by colour alone (restyle v2 §1.4).
class _MarkerSwatch extends StatelessWidget {
  const _MarkerSwatch({
    super.key,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(R.monogram),
                border: selected
                    ? Border.all(color: C.textPrimary, width: 2)
                    : null,
              ),
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.markers[index],
                  borderRadius: BorderRadius.circular(R.badge),
                ),
                child: selected
                    ? const AppIcon(AppGlyph.check, size: 16, color: C.bg)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A radio (restyle v2 §5): 20 dp, a 2 dp edge ring; selected, a 2 dp text-1
/// ring around a 10 dp dot. Not jade: a choice is a position.
class _FormRadio extends StatelessWidget {
  const _FormRadio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? C.textPrimary : C.edge, width: 2),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                  color: C.textPrimary, shape: BoxShape.circle),
            )
          : null,
    );
  }
}

/// A centred form's `Save` (`10b`, `10e`): the screen's one jade action, a
/// 48 dp target.
class _FormSaveAction extends StatelessWidget {
  const _FormSaveAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: S.s3),
            child: Center(
              widthFactor: 1,
              child: Text('Save', style: T.label.copyWith(color: C.jade)),
            ),
          ),
        ),
      ),
    );
  }
}

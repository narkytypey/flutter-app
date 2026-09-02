import 'package:flutter/material.dart';

import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';

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
  final ValueChanged<WorkspaceFormResult> onSave;
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

  void _save() {
    widget.onSave(WorkspaceFormResult(
      name: _nameController.text,
      markerIndex: _markerIndex,
      storageRule: _storageRule,
      requirePin: _requirePin,
      showInDecoy: _showInDecoy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Text('×',
                        style: TextStyle(fontSize: 20, color: C.icon)),
                  ),
                  Text(widget.title, style: ui(size: 15, weight: 600)),
                  GestureDetector(
                    onTap: _save,
                    child: Text('Save',
                        style: ui(size: 14, weight: 500, color: C.jade)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                children: [
                  _fieldLabel('NAME'),
                  const SizedBox(height: 8),
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: C.jade.withValues(alpha: 0.35)),
                    ),
                    child: TextField(
                      controller: _nameController,
                      style: ui(size: 14, color: C.textSecondary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _fieldLabel('MARKER'),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      for (var i = 0; i < C.markers.length; i++) ...[
                        if (i != 0) const SizedBox(width: 12),
                        GestureDetector(
                          key: Key('marker-$i'),
                          onTap: () => setState(() => _markerIndex = i),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: C.markers[i],
                              borderRadius: BorderRadius.circular(8),
                              border: i == _markerIndex
                                  ? Border.all(color: C.textPrimary, width: 2)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  _fieldLabel('STORAGE'),
                  const SizedBox(height: 9),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: DecoratedBox(
                      decoration:
                          BoxDecoration(border: Border.all(color: C.line08)),
                      child: Column(
                        children: [
                          _storageOption(
                            title: 'Keep between sessions',
                            subtitle: 'Stays signed in',
                            selected: _storageRule == StorageRule.keep,
                            onTap: () =>
                                setState(() => _storageRule = StorageRule.keep),
                          ),
                          Container(height: 1, color: C.bg),
                          _storageOption(
                            title: 'Wipe when the app closes',
                            subtitle: 'Nothing survives a restart',
                            selected: _storageRule == StorageRule.wipeOnExit,
                            onTap: () => setState(
                                () => _storageRule = StorageRule.wipeOnExit),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style:
          ui(size: 10.5, weight: 600, letterSpacing: 1.05, color: C.textFaint));

  Widget _storageOption({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: C.surface,
        padding: const EdgeInsets.all(13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: ui(
                        size: 13.5,
                        color: selected ? C.textPrimary : C.textTertiary)),
                const SizedBox(height: 3),
                Text(subtitle, style: ui(size: 11, color: C.textFaint)),
              ],
            ),
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.bg,
                border: Border.all(
                    color: selected ? C.jade : C.idleDot,
                    width: selected ? 5 : 1.5),
              ),
            ),
          ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ui(size: 14, color: C.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle, style: ui(size: 11, color: C.textFaint)),
              ],
            ),
          ),
          AppToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

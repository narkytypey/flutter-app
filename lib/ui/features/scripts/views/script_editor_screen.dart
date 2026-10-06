import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/models/user_script.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/icon_tap.dart';

class ScriptSiteChip {
  const ScriptSiteChip({required this.id, required this.name});
  final String id;
  final String name;
}

class ScriptEditorResult {
  const ScriptEditorResult({
    required this.kind,
    required this.code,
    required this.runAtDocumentStart,
  });

  final ScriptKind kind;
  final String code;
  final bool runAtDocumentStart;
}

/// Spec `10e` — code, then where it runs. Renaming a script is not built
/// here: the header shows [title] as static text, matching what the spec
/// draws (no rename control).
class ScriptEditorScreen extends StatefulWidget {
  const ScriptEditorScreen({
    super.key,
    required this.title,
    required this.initialKind,
    required this.initialCode,
    required this.initialRunAtDocumentStart,
    required this.appliedSites,
    required this.onSave,
    required this.onRemoveSite,
    required this.onAddSite,
    required this.onClose,
  });

  final String title;
  final ScriptKind initialKind;
  final String initialCode;
  final bool initialRunAtDocumentStart;
  final List<ScriptSiteChip> appliedSites;
  /// Save is ignored while a returned future is still running, so a double
  /// tap writes (and pops) once.
  final FutureOr<void> Function(ScriptEditorResult result) onSave;
  final void Function(String siteId) onRemoveSite;

  /// Null once every site in the vault is on the script: "+ Add site" is then
  /// dimmed and does nothing, since the picker would have no rows to offer.
  final VoidCallback? onAddSite;
  final VoidCallback onClose;

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  late final _codeController = TextEditingController(text: widget.initialCode);
  late ScriptKind _kind = widget.initialKind;
  late bool _runAtDocumentStart = widget.initialRunAtDocumentStart;

  @override
  void dispose() {
    _codeController.dispose();
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

  FutureOr<void> _submit() => widget.onSave(ScriptEditorResult(
      kind: _kind,
      code: _codeController.text,
      runAtDocumentStart: _runAtDocumentStart,
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
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  IconTap(
                    glyph: AppGlyph.back,
                    label: 'Back',
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
                  _SaveAction(onTap: _save),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.s4, S.s4, S.s4, S.s6),
                children: [
                  Row(
                    children: [
                      Expanded(child: _kindTab(ScriptKind.css, 'CSS')),
                      const SizedBox(width: S.s2),
                      Expanded(child: _kindTab(ScriptKind.js, 'JavaScript')),
                    ],
                  ),
                  const SizedBox(height: S.s4),
                  _CodeEditor(controller: _codeController),
                  const SizedBox(height: S.s6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('RUNS ON', style: T.sectionLabel),
                  ),
                  const SizedBox(height: S.s1),
                  Wrap(
                    spacing: S.s2,
                    children: [
                      for (final site in widget.appliedSites)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onRemoveSite(site.id),
                          child: _chipFrame(
                            outlined: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(site.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: T.sub
                                          .copyWith(color: C.textPrimary)),
                                ),
                                const SizedBox(width: S.s2),
                                Semantics(
                                  label: 'Remove',
                                  button: true,
                                  child: AppIcon(AppGlyph.close,
                                      size: 16, color: C.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onAddSite,
                        // Inert once every site is on the script: a readable
                        // tone and no outline (restyle v2 §2.2), so it does
                        // not read as something to tap.
                        child: _chipFrame(
                          outlined: widget.onAddSite != null,
                          child: Text('+ Add site',
                              style: T.sub.copyWith(
                                  color: widget.onAddSite == null
                                      ? C.textFaint
                                      : C.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: S.s4),
                  // The whole row is the hit target, not just the switch —
                  // the same treatment `FilterListSection` gives its rows.
                  Group(
                    padding: EdgeInsets.zero,
                    children: [
                      GestureDetector(
                        onTap: () => setState(
                            () => _runAtDocumentStart = !_runAtDocumentStart),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 72),
                          padding: const EdgeInsets.symmetric(
                              horizontal: S.s4, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Run before the page paints',
                                        style: T.body),
                                    const SizedBox(height: 2),
                                    Text(
                                        'Prevents a flash of the hidden elements',
                                        style: T.sub),
                                  ],
                                ),
                              ),
                              const SizedBox(width: S.s3),
                              AppToggle(
                                value: _runAtDocumentStart,
                                onChanged: (v) =>
                                    setState(() => _runAtDocumentStart = v),
                              ),
                            ],
                          ),
                        ),
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

  /// A chip (restyle v2 §5): a 48 dp target around a 36 dp chip with a line
  /// outline.
  Widget _chipFrame({required bool outlined, required Widget child}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: outlined ? Border.all(color: C.line) : null,
          ),
          child: child,
        ),
      ),
    );
  }

  /// A segment (restyle v2 §5): selected is a 2 dp text-1 outline and a
  /// check on the raised fill, never jade.
  Widget _kindTab(ScriptKind kind, String label) {
    final selected = _kind == kind;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _kind = kind),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: S.s2, vertical: S.s2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? C.selected : null,
            borderRadius: BorderRadius.circular(R.input),
            border: selected
                ? Border.all(color: C.textPrimary, width: 2)
                : Border.all(color: C.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                AppIcon(AppGlyph.check, size: 16, color: C.textPrimary),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: selected
                        ? T.label
                        : T.label.copyWith(
                            color: C.textMuted, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `10e`'s `Save`: the screen's one jade action, a 48 dp target.
class _SaveAction extends StatelessWidget {
  const _SaveAction({required this.onTap});

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

/// A monospace textarea with a line-number gutter that scrolls with it. The
/// gutter and the field share one outer scroll view, and the field's own
/// scrolling is disabled — two independently-scrolling columns would drift
/// out of sync the moment either one moved.
class _CodeEditor extends StatelessWidget {
  const _CodeEditor({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(R.input),
        border: Border.all(color: C.edge, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    final lineCount = '\n'.allMatches(value.text).length + 1;
                    return Text(
                      List.generate(lineCount, (i) => '${i + 1}').join('\n'),
                      textAlign: TextAlign.right,
                      style: T.code.copyWith(color: C.textFaint),
                    );
                  },
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 12, 12),
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    style: T.code,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

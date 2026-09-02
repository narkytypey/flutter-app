import 'package:flutter/material.dart';

import '../../../../domain/models/user_script.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';

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
  final ValueChanged<ScriptEditorResult> onSave;
  final void Function(String siteId) onRemoveSite;
  final VoidCallback onAddSite;
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

  void _save() {
    widget.onSave(ScriptEditorResult(
      kind: _kind,
      code: _codeController.text,
      runAtDocumentStart: _runAtDocumentStart,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Text('‹',
                        style: TextStyle(fontSize: 16, color: C.icon)),
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
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    children: [
                      Expanded(child: _kindTab(ScriptKind.css, 'CSS')),
                      const SizedBox(width: 8),
                      Expanded(child: _kindTab(ScriptKind.js, 'JavaScript')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _CodeEditor(controller: _codeController),
                  const SizedBox(height: 20),
                  Text('RUNS ON',
                      style: ui(
                          size: 10.5,
                          weight: 600,
                          letterSpacing: 1.05,
                          color: C.textFaint)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final site in widget.appliedSites)
                        GestureDetector(
                          onTap: () => widget.onRemoveSite(site.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: C.button,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${site.name} ×',
                                style: ui(size: 12.5, color: C.textSecondary)),
                          ),
                        ),
                      GestureDetector(
                        onTap: widget.onAddSite,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text('+ Add site',
                              style: ui(size: 12.5, color: C.jade)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // The whole row is the hit target, not just the switch —
                  // the same treatment `FilterListSection` gives its rows.
                  GestureDetector(
                    onTap: () => setState(
                        () => _runAtDocumentStart = !_runAtDocumentStart),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: C.line06)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Run before the page paints',
                                    style: ui(size: 14, color: C.textPrimary)),
                                const SizedBox(height: 3),
                                Text('Prevents a flash of the hidden elements',
                                    style: ui(size: 11.5, color: C.textFaint)),
                              ],
                            ),
                          ),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _kindTab(ScriptKind kind, String label) {
    final selected = _kind == kind;
    return GestureDetector(
      onTap: () => setState(() => _kind = kind),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.selected : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? C.line10 : C.line07),
        ),
        child: Text(label,
            style:
                ui(size: 13, color: selected ? C.textPrimary : C.tabInactive)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line09),
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
                      style:
                          mono(size: 11.5, height: 1.9, color: C.textDisabled),
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
                    style: mono(size: 11.5, height: 1.9, color: C.jadeCode),
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

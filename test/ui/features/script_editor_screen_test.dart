import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/features/scripts/views/script_editor_screen.dart';

import '../../support/glyph_finders.dart';

void main() {
  Finder chip(String name) => find.descendant(
      of: find.byType(ScriptEditorScreen), matching: find.text(name));

  const appliedSites = [
    ScriptSiteChip(id: 's1', name: 'Forum'),
    ScriptSiteChip(id: 's2', name: 'Reader'),
  ];

  Widget host({
    ValueChanged<ScriptEditorResult>? onSave,
    void Function(String siteId)? onRemoveSite,
    VoidCallback? onAddSite,
    VoidCallback? onClose,
    String initialCode = '',
    bool initialRunAtDocumentStart = true,
  }) {
    return MaterialApp(
      home: ScriptEditorScreen(
        title: 'Hide sticky headers',
        initialKind: ScriptKind.css,
        initialCode: initialCode,
        initialRunAtDocumentStart: initialRunAtDocumentStart,
        appliedSites: appliedSites,
        onSave: onSave ?? (_) {},
        onRemoveSite: onRemoveSite ?? (_) {},
        onAddSite: onAddSite ?? () {},
        onClose: onClose ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy and the applied sites verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Hide sticky headers'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('CSS'), findsOneWidget);
    expect(find.text('JavaScript'), findsOneWidget);
    expect(find.text('RUNS ON'), findsOneWidget);
    expect(chip('Forum'), findsOneWidget);
    expect(chip('Reader'), findsOneWidget);
    // Each chip ends in a drawn ×, announced as Remove.
    expect(findGlyph(AppGlyph.close), findsNWidgets(2));
    expect(find.text('+ Add site'), findsOneWidget);
    expect(find.text('Run before the page paints'), findsOneWidget);
    expect(find.text('Prevents a flash of the hidden elements'), findsOneWidget);
  });

  testWidgets('the line gutter tracks the code as it is typed', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a\nb\nc');
    await tester.pump();

    expect(find.text('1\n2\n3'), findsOneWidget);
  });

  testWidgets('Save reports the kind, code and toggle as they stand', (tester) async {
    ScriptEditorResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r, initialRunAtDocumentStart: false));

    await tester.enterText(find.byType(TextField), 'body { color: red; }');
    await tester.tap(find.text('JavaScript'));
    await tester.tap(find.text('Run before the page paints'));
    await tester.tap(find.text('Save'));

    expect(result!.kind, ScriptKind.js);
    expect(result!.code, 'body { color: red; }');
    expect(result!.runAtDocumentStart, isTrue);
  });

  testWidgets('a site chip\'s × reports its own id, Add site is separate', (tester) async {
    final removed = <String>[];
    var adds = 0;
    await tester.pumpWidget(host(onRemoveSite: removed.add, onAddSite: () => adds++));

    await tester.tap(chip('Reader'));
    await tester.tap(find.text('+ Add site'));

    expect(removed, ['s2']);
    expect(adds, 1);
  });

  testWidgets('the × closes without saving', (tester) async {
    var saves = 0;
    var closes = 0;
    await tester.pumpWidget(host(onSave: (_) => saves++, onClose: () => closes++));

    await tester.tap(findIconTap('Back'));

    expect(closes, 1);
    expect(saves, 0);
  });

  testWidgets("a chip's × is named Remove", (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());
    // The chip is the tap target, so its name and the × merge into one
    // button, announced "<site> Remove".
    expect(find.bySemanticsLabel(RegExp(r'^(Forum|Reader)\nRemove$')), findsNWidgets(2));
    semantics.dispose();
  });
}

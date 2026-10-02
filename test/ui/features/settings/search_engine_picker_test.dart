import 'package:container/domain/models/search_engine.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/features/settings/views/search_engine_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

void main() {
  testWidgets('lists the three engines under its title, the current one checked', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchEnginePicker(current: SearchEngine.startpage, onPick: (_) {}),
      ),
    ));

    expect(find.text('Search engine'), findsOneWidget);
    for (final name in ['DuckDuckGo', 'Startpage', 'Brave Search']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(findGlyph(AppGlyph.check), findsOneWidget);
    final startpageRow = find.ancestor(of: find.text('Startpage'), matching: find.byType(Row));
    expect(find.descendant(of: startpageRow.first, matching: findGlyph(AppGlyph.check)),
        findsOneWidget);
  });

  testWidgets('tapping an engine picks it', (tester) async {
    SearchEngine? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchEnginePicker(
          current: SearchEngine.duckDuckGo,
          onPick: (engine) => picked = engine,
        ),
      ),
    ));

    await tester.tap(find.text('Brave Search'));
    expect(picked, SearchEngine.braveSearch);
  });
}

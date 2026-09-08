import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/status_rail.dart';
import 'package:container/ui/features/search/view_models/search_view.dart';
import 'package:container/ui/features/search/views/search_screen.dart';

void main() {
  const forum = SearchResultEntry(
    siteId: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
    host: 'forum.example.com', live: false, workspaceName: 'Personal', markerIndex: 0,
  );
  const bank = SearchResultEntry(
    siteId: 's2', workspaceId: 'w2', name: 'Bank', monogram: 'Bk',
    host: 'bank.example.com', live: true, workspaceName: 'Work', markerIndex: 1,
  );

  Widget host({
    String query = '',
    List<SearchResultEntry> results = const [forum, bank],
    ValueChanged<String>? onQueryChanged,
    void Function(String)? onOpen,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      home: SearchScreen(
        controller: TextEditingController(text: query),
        results: results,
        onQueryChanged: onQueryChanged ?? (_) {},
        onOpen: onOpen ?? (_) {},
        onBack: onBack ?? () {},
      ),
    );
  }

  testWidgets('renders every result: name, host and its workspace', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Bank'), findsOneWidget);
    expect(find.text('bank.example.com'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    // A zero-height StatusRail would render but be invisible — assert every
    // rail actually occupies vertical space.
    for (final rail in tester.widgetList(find.byType(StatusRail))) {
      final size = tester.getSize(find.byWidget(rail));
      expect(size.height, greaterThan(0));
    }

    // The bank entry's markerIndex is 1 — its marker dot must be painted in
    // C.markers[1], not some other/default color.
    final markerFinder = find.byWidgetPredicate((widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).color == C.markers[1]);
    expect(markerFinder, findsOneWidget);
  });

  testWidgets('typing reports the new text', (tester) async {
    final changes = <String>[];
    await tester.pumpWidget(host(onQueryChanged: changes.add));

    await tester.enterText(find.byKey(const Key('search-field')), 'ban');

    expect(changes, ['ban']);
  });

  testWidgets('tapping a row reports its site id', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(host(onOpen: opened.add));

    await tester.tap(find.text('Bank'));

    expect(opened, ['s2']);
  });

  testWidgets('tapping back calls onBack', (tester) async {
    var backTaps = 0;
    await tester.pumpWidget(host(onBack: () => backTaps++));

    await tester.tap(find.text('‹'));

    expect(backTaps, 1);
  });

  testWidgets('a non-empty query with no results shows the no-match message', (tester) async {
    await tester.pumpWidget(host(query: 'zzz', results: const []));

    expect(find.text('No sites match "zzz"'), findsOneWidget);
    expect(find.text('Forum'), findsNothing);
  });
}

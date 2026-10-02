import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/workspaces/views/workspaces_screen.dart';

import '../../support/glyph_finders.dart';

void main() {
  const items = [
    WorkspaceListItem(id: 'ws-personal', name: 'Personal', markerIndex: 0,
        statsLine: '6 sites · cookies kept · 12 MB'),
    WorkspaceListItem(id: 'ws-work', name: 'Work', markerIndex: 1,
        statsLine: '2 sites · cookies kept · 3 MB'),
    WorkspaceListItem(id: 'ws-ephemeral', name: 'Ephemeral', markerIndex: 4,
        statsLine: '1 site · wipes on exit · nothing stored'),
  ];

  Widget host({
    void Function(String id)? onOpen,
    void Function(String id)? onDelete,
    VoidCallback? onNewWorkspace,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      home: WorkspacesScreen(
        items: items,
        onOpen: onOpen ?? (_) {},
        onDelete: onDelete,
        onNewWorkspace: onNewWorkspace ?? () {},
        onBack: onBack ?? () {},
      ),
    );
  }

  testWidgets('renders every workspace and the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('6 sites · cookies kept · 12 MB'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('2 sites · cookies kept · 3 MB'), findsOneWidget);
    expect(find.text('Ephemeral'), findsOneWidget);
    expect(find.text('1 site · wipes on exit · nothing stored'), findsOneWidget);
    expect(find.text('New workspace'), findsOneWidget);
    expect(
      find.text(
        'The same site can live in more than one workspace. Each copy has '
        'its own login and its own history.',
      ),
      findsOneWidget,
    );
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.plus)).color, C.jade);
    expect(tester.getSize(findGlyph(AppGlyph.plus)), const Size(18, 18));
    expect(findGlyph(AppGlyph.forward), findsNWidgets(3));
    expect(findIconTap('Back'), findsOneWidget);
  });

  testWidgets('back reports a tap', (tester) async {
    var backs = 0;
    await tester.pumpWidget(host(onBack: () => backs++));
    await tester.tap(findIconTap('Back'));
    expect(backs, 1);
  });

  testWidgets('tapping a row reports its id, and New workspace is separate', (tester) async {
    final opened = <String>[];
    var newTaps = 0;
    await tester.pumpWidget(host(onOpen: opened.add, onNewWorkspace: () => newTaps++));

    await tester.tap(find.text('Work'));
    await tester.tap(find.text('New workspace'));

    expect(opened, ['ws-work']);
    expect(newTaps, 1);
  });

  testWidgets('long-pressing a row asks to delete that workspace', (tester) async {
    final deleted = <String>[];
    final opened = <String>[];
    await tester.pumpWidget(host(onDelete: deleted.add, onOpen: opened.add));

    await tester.longPress(find.text('Work'));

    expect(deleted, ['ws-work']);
    expect(opened, isEmpty);
  });

  // Found on a device: only the glyphs of "+ New workspace" took a tap. The
  // row runs the screen's width, and a tap anywhere on it opens the form.
  testWidgets('New workspace opens from anywhere on its row', (tester) async {
    var newTaps = 0;
    await tester.pumpWidget(host(onNewWorkspace: () => newTaps++));

    final row = tester.getRect(find.ancestor(
        of: find.text('New workspace'), matching: find.byType(Row)).first);
    final text = tester.getRect(find.text('New workspace'));
    await tester.tapAt(Offset((text.right + row.right) / 2, text.center.dy));

    expect(newTaps, 1);
  });
}

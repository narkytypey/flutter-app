import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/workspaces/views/workspaces_screen.dart';

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
    VoidCallback? onNewWorkspace,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      home: WorkspacesScreen(
        items: items,
        onOpen: onOpen ?? (_) {},
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
}

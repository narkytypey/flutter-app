import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/workspaces/views/delete_workspace_sheet.dart';

void main() {
  Widget host({VoidCallback? onCancel, VoidCallback? onDelete}) {
    return MaterialApp(
      home: Scaffold(
        body: DeleteWorkspaceSheet(
          workspaceName: 'Work',
          sitesRemoved: 2,
          storageBytesWiped: 3 * 1024 * 1024,
          onCancel: onCancel ?? () {},
          onDelete: onDelete ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the spec copy and computed stats verbatim', (tester) async {
    await tester.pumpWidget(host());

    // Curly quotes, not straight ones. The canvas file writes this title as
    // `Delete “Work”?` — the only curly-quoted string in the whole
    // spec — and the canvas is authoritative over the plan file, which
    // transcribed it with straight quotes.
    expect(find.text('Delete “Work”?'), findsOneWidget);
    expect(find.text('Sites removed'), findsOneWidget);
    expect(find.text('Logins destroyed'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('Stored data wiped'), findsOneWidget);
    expect(find.text('3 MB'), findsOneWidget);
    expect(find.text('Custom scripts kept'), findsOneWidget);
    expect(find.text('In the script library'), findsOneWidget);
    expect(
      find.text('This cannot be undone and there is no backup unless you made one yourself.'),
      findsOneWidget,
    );
    expect(find.text('Type the name to confirm'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('Delete is inert until the typed name matches', (tester) async {
    var deletes = 0;
    await tester.pumpWidget(host(onDelete: () => deletes++));

    await tester.tap(find.text('Delete'));
    expect(deletes, 0);

    // `enterText` does not pump a frame, so without these pumps the tap
    // below lands on the previously-built, still-disabled Delete button and
    // the matching name looks like it did nothing.
    await tester.enterText(find.byType(TextField), 'Wor');
    await tester.pump();
    await tester.tap(find.text('Delete'));
    expect(deletes, 0);

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.pump();
    await tester.tap(find.text('Delete'));
    expect(deletes, 1);
  });

  testWidgets('Cancel reports a tap regardless of the typed text', (tester) async {
    var cancels = 0;
    await tester.pumpWidget(host(onCancel: () => cancels++));
    await tester.tap(find.text('Cancel'));
    expect(cancels, 1);
  });
}

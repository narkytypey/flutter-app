import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/workspaces/views/workspace_form_screen.dart';

void main() {
  Widget host({
    ValueChanged<WorkspaceFormResult>? onSave,
    VoidCallback? onClose,
    String initialName = '',
    int initialMarkerIndex = 0,
    StorageRule initialStorageRule = StorageRule.keep,
    bool initialRequirePin = false,
    bool initialShowInDecoy = false,
  }) {
    return MaterialApp(
      home: WorkspaceFormScreen(
        title: 'New workspace',
        initialName: initialName,
        initialMarkerIndex: initialMarkerIndex,
        initialStorageRule: initialStorageRule,
        initialRequirePin: initialRequirePin,
        initialShowInDecoy: initialShowInDecoy,
        onSave: onSave ?? (_) {},
        onClose: onClose ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('New workspace'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('×'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('MARKER'), findsOneWidget);
    expect(find.text('STORAGE'), findsOneWidget);
    expect(find.text('Keep between sessions'), findsOneWidget);
    expect(find.text('Stays signed in'), findsOneWidget);
    expect(find.text('Wipe when the app closes'), findsOneWidget);
    expect(find.text('Nothing survives a restart'), findsOneWidget);
    expect(find.text('Ask for PIN to enter'), findsOneWidget);
    expect(find.text('Applies to the whole workspace'), findsOneWidget);
    expect(find.text('Show in decoy vault'), findsOneWidget);
    expect(find.text('Off keeps it invisible behind the second PIN'), findsOneWidget);
  });

  testWidgets('Save reports the typed name and the defaults untouched', (tester) async {
    WorkspaceFormResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r));

    await tester.enterText(find.byType(TextField), 'Research');
    await tester.tap(find.text('Save'));

    expect(result!.name, 'Research');
    expect(result!.markerIndex, 0);
    expect(result!.storageRule, StorageRule.keep);
    expect(result!.requirePin, isFalse);
    expect(result!.showInDecoy, isFalse);
  });

  testWidgets('picking a marker and the wipe rule changes what Save reports', (tester) async {
    WorkspaceFormResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r, initialName: 'Ephemeral'));

    await tester.tap(find.byKey(const Key('marker-2')));
    await tester.tap(find.text('Wipe when the app closes'));
    await tester.tap(find.text('Save'));

    expect(result!.markerIndex, 2);
    expect(result!.storageRule, StorageRule.wipeOnExit);
  });

  testWidgets('both toggles report their new value', (tester) async {
    WorkspaceFormResult? result;
    await tester.pumpWidget(host(onSave: (r) => result = r, initialName: 'X'));

    final pinRow = find.ancestor(
      of: find.text('Ask for PIN to enter'),
      matching: find.byType(Row),
    ).first;
    final decoyRow = find.ancestor(
      of: find.text('Show in decoy vault'),
      matching: find.byType(Row),
    ).first;
    await tester.tap(find.descendant(of: pinRow, matching: find.byType(GestureDetector)));
    await tester.tap(find.descendant(of: decoyRow, matching: find.byType(GestureDetector)));
    await tester.tap(find.text('Save'));

    expect(result!.requirePin, isTrue);
    expect(result!.showInDecoy, isTrue);
  });

  testWidgets('the × closes without saving', (tester) async {
    var saves = 0;
    var closes = 0;
    await tester.pumpWidget(host(onSave: (_) => saves++, onClose: () => closes++));

    await tester.tap(find.text('×'));

    expect(closes, 1);
    expect(saves, 0);
  });
}

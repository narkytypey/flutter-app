import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/sheet.dart';
import 'package:container/ui/features/dashboard/views/site_row_menu.dart';

void main() {
  Widget host({
    ValueChanged<SiteRowAction>? onAction,
    VoidCallback? onCancel,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SiteRowMenu(
          monogram: 'Fr',
          name: 'Forum',
          subtitle: 'forum.example.com · ephemeral',
          ephemeralWorkspaceName: 'Ephemeral',
          duplicateTargetName: 'Work',
          onAction: onAction ?? (_) {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com · ephemeral'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Open in Ephemeral'), findsOneWidget);
    expect(find.text('Edit settings'), findsOneWidget);
    expect(find.text('Duplicate into Work'), findsOneWidget);
    expect(find.text('Require PIN to open'), findsOneWidget);
    expect(find.text("Wipe this site's data"), findsOneWidget);
    expect(find.text('Remove site'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('destructive actions sit in their own group', (tester) async {
    await tester.pumpWidget(host());

    // Spec 7b: "wipe sits apart from the rest". Two groups, never one.
    expect(find.byType(SheetGroup), findsNWidgets(2));

    final wipeGroup = tester.widget<SheetGroup>(find.ancestor(
      of: find.text("Wipe this site's data"),
      matching: find.byType(SheetGroup),
    ));
    final openGroup = tester.widget<SheetGroup>(find.ancestor(
      of: find.text('Open'),
      matching: find.byType(SheetGroup),
    ));

    expect(identical(wipeGroup, openGroup), isFalse);
    expect(wipeGroup.children.length, 2);
    expect(openGroup.children.length, 5);
  });

  testWidgets('Remove site is the only row drawn in danger colour',
      (tester) async {
    await tester.pumpWidget(host());

    expect(
      tester.widget<Text>(find.text('Remove site')).style!.color,
      C.danger,
    );
    expect(
      tester.widget<Text>(find.text("Wipe this site's data")).style!.color,
      C.textSecondary,
    );
    expect(
      tester.widget<Text>(find.text('Edit settings')).style!.color,
      C.textPrimary,
    );
  });

  testWidgets('workspace names come from the parameters, not hardcoded',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SiteRowMenu(
          monogram: 'Rd',
          name: 'Reader',
          subtitle: 'reader.example.com · Personal',
          ephemeralWorkspaceName: 'Throwaway',
          duplicateTargetName: 'Research',
          onAction: (_) {},
          onCancel: () {},
        ),
      ),
    ));

    expect(find.text('Open in Throwaway'), findsOneWidget);
    expect(find.text('Duplicate into Research'), findsOneWidget);
  });

  testWidgets('every row reports its action and Cancel is separate',
      (tester) async {
    final seen = <SiteRowAction>[];
    var cancelled = 0;
    await tester.pumpWidget(
      host(onAction: seen.add, onCancel: () => cancelled++),
    );

    await tester.tap(find.text('Open'));
    await tester.tap(find.text('Open in Ephemeral'));
    await tester.tap(find.text('Edit settings'));
    await tester.tap(find.text('Duplicate into Work'));
    await tester.tap(find.text('Require PIN to open'));
    await tester.tap(find.text("Wipe this site's data"));
    await tester.tap(find.text('Remove site'));
    await tester.tap(find.text('Cancel'));

    expect(seen, [
      SiteRowAction.open,
      SiteRowAction.openEphemeral,
      SiteRowAction.editSettings,
      SiteRowAction.duplicate,
      SiteRowAction.requirePin,
      SiteRowAction.wipeData,
      SiteRowAction.removeSite,
    ]);
    expect(cancelled, 1);
  });
}

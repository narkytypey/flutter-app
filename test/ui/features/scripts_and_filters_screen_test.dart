import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/ui/features/scripts/views/scripts_and_filters_screen.dart';

void main() {
  final now = DateTime.utc(2026, 8, 30, 9);

  final filterLists = [
    FilterList(id: 'fl-1', name: 'Trackers and ads', ruleCount: 84102,
        updatedAt: now.subtract(const Duration(days: 2)), enabled: true),
  ];

  final scripts = [
    const UserScript(id: 'sc-1', name: 'Hide sticky headers', kind: ScriptKind.css, code: '',
        runAtDocumentStart: true, enabled: true, appliedSiteIds: ['s1', 's2', 's3', 's4']),
    const UserScript(id: 'sc-2', name: 'Auto-expand comments', kind: ScriptKind.js, code: '',
        runAtDocumentStart: false, enabled: false, appliedSiteIds: ['s1']),
  ];

  Widget host({
    ValueChanged<String>? onToggleScript,
    void Function(String id)? onOpenScript,
    VoidCallback? onNewScript,
  }) {
    return MaterialApp(
      home: ScriptsAndFiltersScreen(
        filterLists: filterLists,
        now: now,
        nextUpdateInDays: 5,
        scripts: scripts,
        siteNamesById: const {},
        onToggleFilterList: (_) {},
        onUpdateFilterListsNow: () {},
        onToggleScript: onToggleScript ?? (_) {},
        onOpenScript: onOpenScript ?? (_) {},
        onNewScript: onNewScript ?? () {},
        onBack: () {},
      ),
    );
  }

  testWidgets('renders filter lists and scripts together, verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Scripts and filters'), findsOneWidget);
    expect(find.text('Trackers and ads'), findsOneWidget);
    expect(find.text('MY SCRIPTS'), findsOneWidget);
    expect(find.text('CSS'), findsOneWidget);
    expect(find.text('Hide sticky headers'), findsOneWidget);
    expect(find.text('Applied to 4 sites'), findsOneWidget);
    expect(find.text('JS'), findsOneWidget);
    expect(find.text('Auto-expand comments'), findsOneWidget);
    expect(find.text('Applied to 1 site · runs at load'), findsOneWidget);
    expect(find.text('New script'), findsOneWidget);
  });

  testWidgets('tapping a script row opens it, New script is separate', (tester) async {
    final opened = <String>[];
    var newTaps = 0;
    await tester.pumpWidget(host(onOpenScript: opened.add, onNewScript: () => newTaps++));

    await tester.tap(find.text('Hide sticky headers'));
    await tester.tap(find.text('New script'));

    expect(opened, ['sc-1']);
    expect(newTaps, 1);
  });
}

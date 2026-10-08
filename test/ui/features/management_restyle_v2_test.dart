import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/scripts/views/script_editor_screen.dart';
import 'package:container/ui/features/scripts/views/scripts_and_filters_screen.dart';
import 'package:container/ui/features/workspaces/views/delete_workspace_sheet.dart';
import 'package:container/ui/features/workspaces/views/workspaces_screen.dart';

/// Restyle v2 (Plan 23 Task 3): `10a`–`10e`.
void main() {
  test('the markers are the v2 five: brass, steel, amber, mauve, stone', () {
    expect(C.markers, const [
      Color(0xFFC9B48A),
      Color(0xFF8FA5C8),
      Color(0xFFE0B266),
      Color(0xFFC89BB4),
      Color(0xFFA8A095),
    ]);
    expect(C.markers, isNot(contains(C.jade)));
  });

  testWidgets('10a draws each workspace in its own marker', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: WorkspacesScreen(
        items: const [
          WorkspaceListItem(id: 'a', name: 'Personal', markerIndex: 0, statsLine: 's'),
          WorkspaceListItem(id: 'b', name: 'Ephemeral', markerIndex: 4, statsLine: 's'),
        ],
        onOpen: (_) {},
        onNewWorkspace: () {},
        onBack: () {},
      ),
    ));
    final markers = tester.widgetList<WorkspaceMarker>(find.byType(WorkspaceMarker)).toList();
    expect(markers.map((m) => m.index), [0, 4]);
    Color fill(int i) => ((tester.widget<Container>(find.descendant(
                of: find.byWidget(markers[i]), matching: find.byType(Container)))
            .decoration as BoxDecoration)
        .color)!;
    expect(fill(0), const Color(0xFFC9B48A));
    expect(fill(1), const Color(0xFFA8A095));
  });

  testWidgets('10c Delete sits on the danger wash with a danger label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DeleteWorkspaceSheet(
          workspaceName: 'Work',
          sitesRemoved: 1,
          onCancel: () {},
          onDelete: () {},
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'Work');
    await tester.pump();

    final button = find.byKey(const Key('delete-workspace-button'));
    expect(tester.widget<Material>(button).color, C.dangerSurface);
    final label = tester.widget<Text>(
        find.descendant(of: button, matching: find.text('Delete')));
    expect(label.style!.color, C.danger);
  });

  testWidgets("10d's badge colours are the view's: CSS in code, JS in amber", (tester) async {
    expect(scriptBadgeColor(ScriptKind.css), C.code);
    expect(scriptBadgeColor(ScriptKind.js), C.warning);

    await tester.pumpWidget(MaterialApp(
      home: ScriptsAndFiltersScreen(
        filterLists: const <FilterList>[],
        now: DateTime.utc(2026),
        scripts: const [
          UserScript(id: 'c', name: 'C', kind: ScriptKind.css, code: '',
              runAtDocumentStart: true, enabled: true, appliedSiteIds: []),
          UserScript(id: 'j', name: 'J', kind: ScriptKind.js, code: '',
              runAtDocumentStart: true, enabled: true, appliedSiteIds: []),
        ],
        siteNamesById: const {},
        onToggleFilterList: (_) {},
        onToggleScript: (_) {},
        onOpenScript: (_) {},
        onNewScript: () {},
        onBack: () {},
      ),
    ));
    expect(tester.widget<Text>(find.text('CSS')).style!.color, C.code);
    expect(tester.widget<Text>(find.text('JS')).style!.color, C.warning);
  });

  testWidgets("10e's code is drawn in the code tone, not jade", (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ScriptEditorScreen(
        title: 'T',
        initialKind: ScriptKind.css,
        initialCode: 'a { }',
        initialRunAtDocumentStart: false,
        appliedSites: const [],
        onSave: (_) {},
        onRemoveSite: (_) {},
        onAddSite: () {},
        onClose: () {},
      ),
    ));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.color, C.code);
    expect(field.style!.color, isNot(C.jade));
    expect(field.style!.fontFamily, 'IBMPlexMono');
  });
}

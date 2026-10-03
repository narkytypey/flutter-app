import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/widgets/status_rail.dart';
import 'package:container/ui/features/workspaces/views/workspace_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/glyph_finders.dart';

const _notes = Site(
  id: 's-notes', workspaceId: 'w1', name: 'Notes', monogram: 'Nt',
  url: 'https://notes.example.org', profileId: 'p-notes',
);
const _ledger = Site(
  id: 's-ledger', workspaceId: 'w2', name: 'Ledger', monogram: 'Lg',
  url: 'https://ledger.example.org', profileId: 'p-ledger',
);

void main() {
  testWidgets('a chip per workspace, then +; the first is viewed', (tester) async {
    await pumpDashboard(tester, sites: const [_notes, _ledger]);

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(findIconTap('New workspace'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Ledger'), findsNothing);
  });

  testWidgets('a tap on a chip shows that workspace', (tester) async {
    await pumpDashboard(tester, sites: const [_notes, _ledger]);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets("a long-press opens that workspace's form (10b), and changes nothing else",
      (tester) async {
    await pumpDashboard(tester, sites: const [_notes, _ledger]);

    await tester.longPress(find.text('Work'));
    await tester.pumpAndSettle();

    final form = tester.widget<WorkspaceFormScreen>(find.byType(WorkspaceFormScreen));
    expect(form.title, 'Work');
    expect(form.initialName, 'Work');

    form.onClose();
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget, reason: 'Personal is still the one viewed');
  });

  testWidgets('+ opens a new workspace form', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(findIconTap('New workspace'));
    await tester.pumpAndSettle();

    expect(tester.widget<WorkspaceFormScreen>(find.byType(WorkspaceFormScreen)).title,
        'New workspace');
  });

  testWidgets('an open site is marked by its green rail alone', (tester) async {
    final h = await pumpDashboard(tester, sites: const [_notes]);

    await tester.runAsync(() => h.registry.view(_notes));
    h.registry.showDashboard();
    await tester.pumpAndSettle();

    expect(tester.widget<StatusRail>(find.byType(StatusRail)).live, isTrue);
    expect(find.text('OPEN NOW'), findsNothing);
    expect(find.textContaining('SESSIONS'), findsNothing);
  });

  testWidgets('a wipe-on-exit workspace shows WIPES ON EXIT', (tester) async {
    await pumpDashboard(tester, workspaces: const [
      Workspace(id: 'e', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
    ]);
    expect(find.text('WIPES ON EXIT'), findsOneWidget);
  });
}

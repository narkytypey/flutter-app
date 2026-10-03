import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/views/workspace_menu.dart';

import '../../support/glyph_finders.dart';

void main() {
  test('a keeping workspace is summarised by its site and open counts', () {
    const personal = Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

    expect(workspaceMeta(workspace: personal, siteCount: 6, openCount: 2),
        '6 SITES · 2 OPEN');
    expect(workspaceMeta(workspace: personal, siteCount: 1, openCount: 0),
        '1 SITES · 0 OPEN');
  });

  test('a wipe-on-exit workspace is summarised by its rule', () {
    const ephemeral = Workspace(
        id: 'ws', name: 'Ephemeral', markerIndex: 4,
        storageRule: StorageRule.wipeOnExit);

    expect(workspaceMeta(workspace: ephemeral, siteCount: 1, openCount: 1),
        'WIPES ON EXIT');
  });

  testWidgets('the menu lists every workspace and ticks the selected one',
      (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WorkspaceMenu(
          options: const [
            WorkspaceOption(
                id: 'a', name: 'Personal', meta: '6 SITES · 2 OPEN', selected: true),
            WorkspaceOption(
                id: 'b', name: 'Work', meta: '2 SITES · 1 OPEN', selected: false),
            WorkspaceOption(
                id: 'c', name: 'Ephemeral', meta: 'WIPES ON EXIT', selected: false),
          ],
          onPick: picked.add,
        ),
      ),
    ));

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('WIPES ON EXIT'), findsOneWidget);

    final tick = tester.widget<AppIcon>(findGlyph(AppGlyph.check));
    expect(tick.color, C.jade);

    await tester.tap(find.text('Work'));
    expect(picked, ['b']);
  });

  testWidgets('management rows sit under the workspaces and report their taps',
      (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WorkspaceMenu(
          options: const [
            WorkspaceOption(
                id: 'a', name: 'Personal', meta: '6 SITES · 2 OPEN', selected: true),
          ],
          onPick: (_) {},
          managementOptions: [
            ManagementOption(label: 'Today', onTap: () => tapped.add('Today')),
          ],
        ),
      ),
    ));

    expect(
      tester.getTopLeft(find.text('Today')).dy,
      greaterThan(tester.getTopLeft(find.text('Personal')).dy),
    );
    await tester.tap(find.text('Today'));
    expect(tapped, ['Today']);
  });

  // The dashboard stacks the menu beside its Scaffold, not inside it, so the
  // menu has no Material above it there. Its InkWells threw "No Material
  // widget found" on a device, and the menu drew as an error box.
  testWidgets('the menu opens and takes taps with no Material above it',
      (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Stack(
        children: [
          const Scaffold(backgroundColor: C.bg),
          Align(
            alignment: Alignment.topCenter,
            child: WorkspaceMenu(
              options: const [
                WorkspaceOption(
                    id: 'a', name: 'Personal', meta: '6 SITES · 2 OPEN', selected: true),
                WorkspaceOption(
                    id: 'b', name: 'Work', meta: '2 SITES · 1 OPEN', selected: false),
              ],
              onPick: picked.add,
              managementOptions: [
                ManagementOption(label: 'Today', onTap: () => picked.add('Today')),
              ],
            ),
          ),
        ],
      ),
    ));

    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Work'));
    await tester.tap(find.text('Today'));
    expect(picked, ['b', 'Today']);
  });
}

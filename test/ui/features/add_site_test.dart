import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';

const _workspaces = [
  Workspace(id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
  Workspace(id: 'ws-work', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep),
  Workspace(id: 'ws-ephemeral', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
];

Future<void> _pump(WidgetTester tester, {ValueChanged<Site>? onSave}) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  return tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(workspaces: _workspaces, onSave: onSave ?? (_) {}),
  ));
}

void main() {
  testWidgets('the header and all four tabs are visible from the start',
      (tester) async {
    await _pump(tester);

    expect(find.text('Add site'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    for (final tab in ['Basics', 'Network', 'Privacy', 'Appearance']) {
      expect(find.text(tab), findsOneWidget);
    }
  });

  testWidgets('Basics shows address, name, workspace chips and cookie choice',
      (tester) async {
    await _pump(tester);

    expect(find.text('ADDRESS'), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('WORKSPACE'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Ephemeral'), findsOneWidget);
    expect(find.text('Keep for this site'), findsOneWidget);
    expect(find.text('Wipe on exit'), findsOneWidget);
  });

  testWidgets('the name field feeds a live monogram suggestion', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byKey(const Key('add-site-name')), 'Forum');
    await tester.pump();

    expect(find.text('Fr'), findsOneWidget);
  });

  testWidgets('Network tab shows proxy controls', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();

    expect(find.text('Route through proxy'), findsOneWidget);
    expect(find.text('This site only'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('HOST'), findsOneWidget);
    expect(find.text('PORT'), findsOneWidget);
    expect(find.text('Block WebRTC'), findsOneWidget);
    expect(find.text('Prevents real IP leaking past the proxy'), findsOneWidget);
    expect(find.text('Block trackers and ads'), findsOneWidget);
  });

  testWidgets('Privacy tab shows hardware off by default and shields',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();

    expect(find.text('HARDWARE · ALL OFF BY DEFAULT'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Microphone'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Clipboard'), findsOneWidget);
    expect(find.text('SHIELDS'), findsOneWidget);
    expect(find.text('Anti-fingerprinting'), findsOneWidget);
    expect(find.text('Show in decoy vault'), findsOneWidget);
  });

  testWidgets('Appearance tab shows user agent, dark mode and custom code',
      (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.text('USER AGENT'), findsOneWidget);
    expect(find.text('Force dark mode'), findsOneWidget);
    expect(find.text('Open in reader mode'), findsOneWidget);
    expect(find.text('Page zoom'), findsOneWidget);
    expect(find.text('CUSTOM CSS'), findsOneWidget);
    expect(find.text('CUSTOM JS'), findsOneWidget);
  });

  testWidgets('saving builds a Site with the entered fields and shield defaults',
      (tester) async {
    Site? saved;
    await _pump(tester, onSave: (s) => saved = s);

    await tester.enterText(find.byKey(const Key('add-site-address')),
        'https://forum.example.com');
    await tester.enterText(find.byKey(const Key('add-site-name')), 'Forum');
    await tester.tap(find.text('Work'));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.url, 'https://forum.example.com');
    expect(saved!.name, 'Forum');
    expect(saved!.monogram, 'Fr');
    expect(saved!.workspaceId, 'ws-work');
    // Shield defaults from spec 2a, matched by Task 1's Site defaults.
    expect(saved!.blockWebRtc, isTrue);
    expect(saved!.blockTrackers, isTrue);
    expect(saved!.antiFingerprinting, isTrue);
    expect(saved!.allowCamera, isFalse);
    expect(saved!.allowMicrophone, isFalse);
    expect(saved!.allowLocation, isFalse);
    expect(saved!.allowClipboard, isFalse);
    expect(saved!.showInDecoy, isFalse);
    expect(saved!.forceDark, isTrue);
    expect(saved!.openInReader, isFalse);
    expect(saved!.profileId, isNotEmpty);
  });

  testWidgets('editing an existing site preserves its id and profile id',
      (tester) async {
    const existing = Site(
      id: 'st-forum',
      workspaceId: 'ws-personal',
      name: 'Forum',
      monogram: 'Fr',
      url: 'https://forum.example.com',
      profileId: 'existing-profile',
    );
    Site? saved;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(428, 1400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: AddSiteScreen(
        initial: existing,
        workspaces: _workspaces,
        onSave: (s) => saved = s,
      ),
    ));

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved!.id, 'st-forum');
    expect(saved!.profileId, 'existing-profile');
  });
}

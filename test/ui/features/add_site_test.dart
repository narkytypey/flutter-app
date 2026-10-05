import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';

import '../../support/glyph_finders.dart';

const _workspaces = [
  Workspace(id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
  Workspace(id: 'ws-work', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep),
  Workspace(id: 'ws-ephemeral', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
];

Future<void> _pump(WidgetTester tester,
    {FutureOr<void> Function(Site site)? onSave, String? initialWorkspaceId,
    ProxyRoute defaultRoute = ProxyRoute.direct, Site? initial}) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  return tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(
      initial: initial,
      workspaces: _workspaces,
      initialWorkspaceId: initialWorkspaceId,
      defaultRoute: defaultRoute,
      onSave: onSave ?? (_) {},
    ),
  ));
}

/// Whether the field under [key] holds focus: the keyboard is up on it.
bool _focused(WidgetTester tester, String key) => tester
    .widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)))
    .focusNode
    .hasFocus;

void main() {
  testWidgets('the header and all four tabs are visible from the start',
      (tester) async {
    await _pump(tester);

    expect(find.text('Add site'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    for (final tab in ['Basics', 'Network', 'Privacy', 'Appearance']) {
      expect(find.text(tab), findsOneWidget);
    }
    expect(tester.getSize(findIconTap('Close')), const Size(24, 24));
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

  testWidgets('more than three workspaces scroll sideways, each name whole',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    final many = [
      for (var i = 0; i < 6; i++)
        Workspace(
            id: 'ws-$i', name: 'Workspace $i', markerIndex: i % 5, storageRule: StorageRule.keep),
    ];
    Site? saved;
    await tester.pumpWidget(MaterialApp(
      home: AddSiteScreen(workspaces: many, onSave: (site) => saved = site),
    ));

    expect(find.byKey(const Key('workspace-chips-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const Key('add-site-address')), 'example.com');
    await tester.ensureVisible(find.text('Workspace 5'));
    await tester.tap(find.text('Workspace 5'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved?.workspaceId, 'ws-5');
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

  // Found on a device: a dropped keystroke saved `ttps://duckduckgo.com`, which
  // the engine will never load. The form now saves an address the way the
  // address bar loads one, and a site that is not one cannot be saved.
  group('the address is saved as the address bar would load it', () {
    Future<Site?> saveWith(WidgetTester tester, String address) async {
      Site? saved;
      await _pump(tester, onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), address);
      await tester.enterText(find.byKey(const Key('add-site-name')), 'Forum');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      return saved;
    }

    testWidgets('a bare host gains https', (tester) async {
      expect((await saveWith(tester, 'forum.example.com/latest'))!.url,
          'https://forum.example.com/latest');
    });

    testWidgets('surrounding spaces are dropped', (tester) async {
      expect((await saveWith(tester, '  https://forum.example.com  '))!.url,
          'https://forum.example.com');
    });

    for (final address in [
      'ttps://duckduckgo.com',
      'javascript:alert(1)',
      'file:///sdcard/a.html',
      'forum example',
      '',
    ]) {
      testWidgets('"$address" is not saved, and Save is dimmed', (tester) async {
        expect(await saveWith(tester, address), isNull);
        final save = tester.widget<Opacity>(
            find.ancestor(of: find.text('Save'), matching: find.byType(Opacity)).first);
        expect(save.opacity, lessThan(1));
      });
    }
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

  // Found on a device: the × was a bare glyph with no tap handler, so only
  // Save or system back left the form. Spec `2a` draws it like `10b`'s,
  // whose × pops without saving.
  testWidgets('× leaves the form without saving', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(428, 1400);
    tester.view.devicePixelRatio = 1;
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (_) => AddSiteScreen(workspaces: _workspaces, onSave: (_) => saves++),
          )),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add-site-name')), 'Forum');

    await tester.tap(findIconTap('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Add site'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(saves, 0);
  });

  group('defaults (dashboard spec §6)', () {
    const forum = Site(
      id: 's1', workspaceId: 'ws-personal', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
    );
    const socks = ProxyRoute(
        mode: ProxyMode.socks5, host: '10.0.2.2', port: 1080, user: 'alice', password: 'pw');

    testWidgets('a new site opens with the keyboard up on ADDRESS', (tester) async {
      await _pump(tester);
      await tester.pump();
      expect(_focused(tester, 'add-site-address'), isTrue);
    });

    testWidgets('an edited site does not', (tester) async {
      await _pump(tester, initial: forum);
      await tester.pump();
      expect(_focused(tester, 'add-site-address'), isFalse);
    });

    testWidgets('WORKSPACE starts on the one given', (tester) async {
      Site? saved;
      await _pump(tester, initialWorkspaceId: 'ws-work', onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.workspaceId, 'ws-work');
    });

    testWidgets('a workspace that is not there falls back to the first', (tester) async {
      Site? saved;
      await _pump(tester, initialWorkspaceId: 'gone', onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.workspaceId, 'ws-personal');
    });

    testWidgets('an empty NAME saves as the host', (tester) async {
      Site? saved;
      await _pump(tester, onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'example.com');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.name, 'example.com');
    });

    testWidgets("a new site's Network tab starts from the default route", (tester) async {
      Site? saved;
      await _pump(tester, defaultRoute: socks, onSave: (s) => saved = s);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('10.0.2.2'), findsOneWidget);
      expect(find.text('1080'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);

      await tester.tap(find.text('Basics'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect((saved!.proxyMode, saved!.proxyHost, saved!.proxyPort, saved!.proxyUser),
          (ProxyMode.socks5, '10.0.2.2', 1080, 'alice'));
    });

    testWidgets('an HTTP default with a login per site seeds the Network tab', (tester) async {
      Site? saved;
      await _pump(
        tester,
        defaultRoute: const ProxyRoute(
            mode: ProxyMode.http, host: 'proxy.lan', port: 3128, loginPerSite: true),
        onSave: (s) => saved = s,
      );
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('proxy.lan'), findsOneWidget);
      expect(find.text('3128'), findsOneWidget);

      await tester.tap(find.text('Basics'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect((saved!.proxyMode, saved!.proxyHost, saved!.proxyPort), (ProxyMode.http, 'proxy.lan', 3128));
      expect(saved!.proxyLoginPerSite, isTrue);
      expect(saved!.proxyUser, isNull);
    });

    testWidgets('an edited site shows its own route, not the default', (tester) async {
      await _pump(tester, initial: forum, defaultRoute: socks);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('10.0.2.2'), findsNothing);
      expect(find.text('Separate login per site'), findsNothing, reason: 'the proxy is off');
    });
  });

  testWidgets('a second Save while the first is still saving is ignored', (tester) async {
    final saves = <Site>[];
    final pending = Completer<void>();
    await _pump(tester, onSave: (site) {
      saves.add(site);
      return pending.future;
    });
    await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saves, hasLength(1));

    pending.complete();
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saves, hasLength(2), reason: 'Save works again once the first is done');
  });

  testWidgets('a form with no workspaces opens without crashing and does not save',
      (tester) async {
    final saves = <Site>[];
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(428, 1400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: AddSiteScreen(workspaces: const [], onSave: saves.add),
    ));
    await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(saves, isEmpty);
  });
}

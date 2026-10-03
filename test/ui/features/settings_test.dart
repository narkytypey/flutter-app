import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/typography.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/core/widgets/setting_row.dart';
import 'package:container/ui/features/settings/views/settings_screen.dart';

import '../../support/glyph_finders.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool decoyConfigured,
    bool biometricsAvailable = true,
  }) {
    // `2d` is a long scrolling list. The default 800x600 test surface is
    // shorter than its content, so the sliver never builds the PANIC rows or
    // the footer into the Element tree and `find.text` sees zero of them —
    // an existence problem, not a visibility one. Same class of bug as
    // cross-plan issue #10.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: biometricsAvailable,
        autoLockLabel: 'After 1 min',
        decoyEnabled: decoyConfigured,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        searchEngineName: 'DuckDuckGo',
        securityLevelName: 'Standard',
        defaultRouteLabel: 'SOCKS5 · 127.0.0.1:9050', defaultRouteMono: true,
        onChanged: (_, __) {},
        onTap: (_) {},
        onBack: () {},
      ),
    ));
  }

  testWidgets('the lock and panic sections read verbatim', (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(find.text('LOCK'), findsOneWidget);
    expect(find.text('Unlock with biometrics'), findsOneWidget);
    expect(find.text('PIN always available as fallback'), findsOneWidget);
    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('After 1 min'), findsOneWidget);
    expect(find.text('Change main PIN'), findsOneWidget);

    expect(find.text('PANIC'), findsOneWidget);
    expect(find.text('Trigger by flipping face down'), findsOneWidget);
    expect(find.text('Uses the accelerometer'), findsOneWidget);
    expect(find.text('On panic'), findsOneWidget);
    expect(find.text('Wipe + lock'), findsOneWidget);
  });

  testWidgets(
      'the biometrics toggle is non-interactive when biometrics is unavailable',
      (tester) async {
    await pump(tester, decoyConfigured: true, biometricsAvailable: false);

    final toggle = tester.widget<AppToggle>(find.byType(AppToggle).first);
    expect(toggle.onChanged, isNull);
  });

  testWidgets(
      'the biometrics toggle is interactive when biometrics is available',
      (tester) async {
    await pump(tester, decoyConfigured: true, biometricsAvailable: true);

    final toggle = tester.widget<AppToggle>(find.byType(AppToggle).first);
    expect(toggle.onChanged, isNotNull);
  });

  testWidgets('the vault section appears when a decoy is configured',
      (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(find.text('VAULT'), findsOneWidget);
    expect(find.text('Decoy vault'), findsOneWidget);
    expect(find.text('A second PIN opens a harmless board'), findsOneWidget);
    expect(find.text('Sites shown in decoy'), findsOneWidget);
    expect(find.text('4 selected'), findsOneWidget);
    expect(find.text('Hide from app switcher'), findsOneWidget);
  });

  testWidgets('the footer states the privacy position', (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(
      find.text('Nothing leaves this device. There is no account and no sync.'),
      findsOneWidget,
    );
  });

  testWidgets('the re-sync row appears in the VAULT section and is tappable',
      (tester) async {
    var tapped = '';
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: true,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        searchEngineName: 'DuckDuckGo',
        securityLevelName: 'Standard',
        onChanged: (_, __) {},
        onTap: (key) => tapped = key,
        onBack: () {},
      ),
    ));

    expect(find.text('Re-sync decoy now'), findsOneWidget);
    await tester.tap(find.text('Re-sync decoy now'));

    expect(tapped, 'resyncDecoy');
  });

  testWidgets('the browsing section follows manage and names the engine', (tester) async {
    var tapped = '';
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: true,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        searchEngineName: 'Startpage',
        securityLevelName: 'Standard',
        onChanged: (_, __) {},
        onTap: (key) => tapped = key,
        onBack: () {},
      ),
    ));

    final manage = tester.getTopLeft(find.text('MANAGE')).dy;
    final browsing = tester.getTopLeft(find.text('BROWSING')).dy;
    final vault = tester.getTopLeft(find.text('VAULT')).dy;
    expect(browsing, greaterThan(manage));
    expect(browsing, lessThan(vault));
    expect(find.text('Startpage'), findsOneWidget);

    await tester.tap(find.text('Search engine'));
    expect(tapped, 'searchEngine');
  });

  // User's rulings, 2026-09-30: rows whose value cannot change are shown, not
  // offered.

  AppToggle toggleIn(WidgetTester tester, String title) => tester.widget<AppToggle>(find.descendant(
        of: find.ancestor(of: find.text(title), matching: find.byType(SettingRow)),
        matching: find.byType(AppToggle),
      ));

  testWidgets('Hide from app switcher is on and cannot be switched off', (tester) async {
    await pump(tester, decoyConfigured: true);
    final toggle = toggleIn(tester, 'Hide from app switcher');
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNull);
  });

  testWidgets('the Decoy vault switch is on and cannot be switched off', (tester) async {
    await pump(tester, decoyConfigured: true);
    final toggle = toggleIn(tester, 'Decoy vault');
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNull);
  });

  testWidgets('On panic shows its value and reports no tap', (tester) async {
    final tapped = <String>[];
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: true,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        searchEngineName: 'DuckDuckGo',
        securityLevelName: 'Standard',
        onChanged: (_, __) {},
        onTap: tapped.add,
        onBack: () {},
      ),
    ));
    await tester.tap(find.text('On panic'));
    await tester.tap(find.text('Sites shown in decoy'));
    expect(tapped, ['decoySites']);
  });

  testWidgets('an inert switch is drawn dimmed, a live one is not', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [AppToggle(value: true), AppToggle(value: true, onChanged: _ignore)]),
    ));
    final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).map((o) => o.opacity).toList();
    expect(opacities, hasLength(2));
    expect(opacities.first, lessThan(1));
    expect(opacities.last, 1);
  });
  testWidgets('the back icon reports a tap, and rows that open something end in a chevron',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    var backs = 0;
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: true,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        searchEngineName: 'DuckDuckGo',
        securityLevelName: 'Standard',
        onChanged: (_, __) {},
        onTap: (_) {},
        onBack: () => backs++,
      ),
    ));

    expect(tester.getSize(findGlyph(AppGlyph.back)), const Size(18, 18));
    await tester.tap(findIconTap('Back'));
    expect(backs, 1);
    expect(findGlyph(AppGlyph.forward), findsWidgets);
    expect(tester.getSize(findGlyph(AppGlyph.forward).first), const Size(16, 16));
  });

  testWidgets('BROWSING has Default route, its proxy value in mono, and it reports a tap',
      (tester) async {
    final taps = <String>[];
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: false, biometricsAvailable: true, autoLockLabel: 'After 1 min',
        decoyEnabled: false, decoySiteCount: 0, hideFromSwitcher: true, panicOnFlip: false,
        onPanicLabel: 'Wipe + lock', searchEngineName: 'DuckDuckGo', securityLevelName: 'Standard',
        defaultRouteLabel: 'SOCKS5 · 127.0.0.1:9050', defaultRouteMono: true,
        onChanged: (_, __) {}, onTap: taps.add, onBack: () {},
      ),
    ));

    expect(find.text('Default route'), findsOneWidget);
    final value = tester.widget<Text>(find.text('SOCKS5 · 127.0.0.1:9050'));
    expect(value.style!.fontFamily, mono(size: 12).fontFamily);
    await tester.tap(find.text('Default route'));
    expect(taps, ['defaultRoute']);
  });

  testWidgets('with no onBack it draws no back icon: the dashboard tab (spec §4.1)', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: false, biometricsAvailable: true, autoLockLabel: 'After 1 min',
        decoyEnabled: false, decoySiteCount: 0, hideFromSwitcher: true, panicOnFlip: false,
        onPanicLabel: 'Wipe + lock', searchEngineName: 'DuckDuckGo', securityLevelName: 'Standard',
        onChanged: (_, __) {}, onTap: (_) {},
      ),
    ));

    expect(find.text('Settings'), findsOneWidget);
    expect(findIconTap('Back'), findsNothing);
  });
}

void _ignore(bool _) {}

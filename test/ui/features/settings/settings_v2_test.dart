import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/security_level.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/group.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/settings/views/auto_lock_picker.dart';
import 'package:container/ui/features/settings/views/search_engine_picker.dart';
import 'package:container/ui/features/settings/views/security_level_picker.dart';
import 'package:container/ui/features/settings/views/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

/// Every colour a widget under [root] paints with: text styles, box fills and
/// borders, icons.
List<Color> paintedColours(WidgetTester tester, Finder root) {
  final colours = <Color>[];
  void decoration(Decoration? d) {
    if (d is! BoxDecoration) return;
    if (d.color != null) colours.add(d.color!);
    final border = d.border;
    if (border is Border) {
      for (final side in [border.top, border.right, border.bottom, border.left]) {
        if (side.width > 0 && side.style != BorderStyle.none) colours.add(side.color);
      }
    }
  }

  for (final w in tester.widgetList(find.descendant(of: root, matching: find.byWidgetPredicate((_) => true)))) {
    if (w is Text && w.style?.color != null) colours.add(w.style!.color!);
    if (w is Container) decoration(w.decoration);
    if (w is DecoratedBox) decoration(w.decoration);
    if (w is AppIcon) colours.add(w.color);
  }
  return colours;
}

void main() {
  Future<void> pumpSettings(WidgetTester tester, {required bool decoy, bool onBack = true}) {
    tester.view.physicalSize = const Size(500, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: decoy,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: true,
        onPanicLabel: 'Wipe + lock',
        searchEngineName: 'DuckDuckGo',
        securityLevelName: 'Standard',
        defaultRouteLabel: 'SOCKS5 · 127.0.0.1:9050',
        defaultRouteMono: true,
        onChanged: (_, __) {},
        onTap: (_) {},
        onBack: onBack ? () {} : null,
      ),
    ));
  }

  Finder groupOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Group));

  testWidgets('v2: every section is a Group, one per section label', (tester) async {
    await pumpSettings(tester, decoy: true);

    expect(find.byType(Group), findsNWidgets(5));
    for (final rows in [
      ['Unlock with biometrics', 'Auto-lock', 'Change main PIN'],
      ['Workspaces', 'Scripts and filters'],
      ['Search engine', 'Default route', 'Security level'],
      ['Decoy vault', 'Sites shown in decoy', 'Re-sync decoy now', 'Hide from app switcher'],
      ['Trigger by flipping face down', 'On panic'],
    ]) {
      final group = groupOf(rows.first);
      expect(group, findsOneWidget, reason: rows.first);
      for (final title in rows.skip(1)) {
        expect(groupOf(title).evaluate().single.widget, same(group.evaluate().single.widget),
            reason: title);
      }
    }
    // Each label sits above its own group.
    for (final (label, first) in [
      ('LOCK', 'Unlock with biometrics'),
      ('MANAGE', 'Workspaces'),
      ('BROWSING', 'Search engine'),
      ('VAULT', 'Decoy vault'),
      ('PANIC', 'Trigger by flipping face down'),
    ]) {
      expect(tester.getBottomLeft(find.text(label)).dy,
          lessThanOrEqualTo(tester.getTopLeft(groupOf(first)).dy), reason: label);
    }
  });

  testWidgets('v2: the decoy (no VAULT) variant has four groups, the same widgets',
      (tester) async {
    await pumpSettings(tester, decoy: false);
    expect(find.byType(Group), findsNWidgets(4));
    expect(find.text('VAULT'), findsNothing);
  });

  testWidgets('v2: nothing on 2d paints jade, switches on included', (tester) async {
    await pumpSettings(tester, decoy: true);
    expect(paintedColours(tester, find.byType(SettingsScreen)), isNot(contains(C.jade)));
  });

  testWidgets('v2: the back icon is a 48 dp target', (tester) async {
    await pumpSettings(tester, decoy: false);
    expect(tester.getSize(findIconTap('Back')), const Size(48, 48));
    expect(tester.widget<IconTap>(findIconTap('Back')).size, 48);
  });

  for (final (name, picker) in <(String, Widget)>[
    ('Auto-lock', AutoLockPicker(current: AutoLockPolicy.fiveMinutes, onPick: (_) {})),
    ('Search engine', SearchEnginePicker(current: SearchEngine.values.first, onPick: (_) {})),
    ('Security level', SecurityLevelPicker.vault(current: SecurityLevel.values.first, onPick: (_) {})),
  ]) {
    testWidgets('v2: $name picker checks in text-1, never jade, rows ≥ 56 dp', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: picker)));
      final check = tester.widget<AppIcon>(findGlyph(AppGlyph.check));
      expect(check.color, C.textPrimary);
      expect(paintedColours(tester, find.byWidget(picker)), isNot(contains(C.jade)));
      final rowHeight = tester.getSize(find.ancestor(
              of: findGlyph(AppGlyph.check), matching: find.byType(GestureDetector))
          .first)
          .height;
      expect(rowHeight, greaterThanOrEqualTo(56));
    });
  }
}

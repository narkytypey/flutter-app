import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the set is spec §6.6's fifteen glyphs, the restyle's eight, the dashboard's three, then restyle v2's eight", () {
    expect(AppGlyph.values.map((g) => g.name), [
      'back', 'forward', 'reload', 'stop', 'shield', 'panic', 'menu', 'find',
      'reader', 'link', 'search', 'globe', 'chevronUp', 'chevronDown', 'close',
      'check', 'plus', 'more', 'vault', 'fingerprint', 'backspace', 'refused',
      'contrast', 'sites', 'today', 'settings',
      // Restyle v2 (spec §6).
      'shieldHalf', 'shieldFull', 'sitesFilled', 'todayFilled', 'settingsFilled',
      'caseSolid', 'caseBroken', 'caseDouble',
    ]);
  });

  testWidgets('every glyph paints, at the size it is given', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Wrap(children: [
          for (final glyph in AppGlyph.values) AppIcon(glyph, size: 24),
          const AppIcon(AppGlyph.back, size: 13, color: C.danger),
        ]),
      ),
    ));

    expect(tester.takeException(), isNull);
    for (final glyph in AppGlyph.values) {
      final icon = find.byWidgetPredicate(
          (w) => w is AppIcon && w.glyph == glyph && w.size == 24);
      expect(tester.getSize(icon), const Size(24, 24), reason: glyph.name);
    }
    expect(tester.getSize(find.byWidgetPredicate((w) => w is AppIcon && w.size == 13)),
        const Size(13, 13));
  });

  testWidgets('the restyle glyphs paint at small and large sizes', (tester) async {
    const added = [
      AppGlyph.check, AppGlyph.plus, AppGlyph.more, AppGlyph.vault,
      AppGlyph.fingerprint, AppGlyph.backspace, AppGlyph.refused, AppGlyph.contrast,
    ];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Wrap(children: [
          for (final glyph in added) ...[
            AppIcon(glyph, size: 12, color: C.jade),
            AppIcon(glyph, size: 28, color: C.danger),
          ],
        ]),
      ),
    ));

    expect(tester.takeException(), isNull);
    for (final glyph in added) {
      final sizes = tester
          .widgetList<AppIcon>(find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph))
          .map((icon) => icon.size);
      expect(sizes, [12, 28], reason: glyph.name);
    }
  });

  test('the painter repaints only for a new glyph or colour', () {
    const painter = AppIconPainter(AppGlyph.back, C.icon);
    expect(painter.shouldRepaint(const AppIconPainter(AppGlyph.back, C.icon)), isFalse);
    expect(painter.shouldRepaint(const AppIconPainter(AppGlyph.forward, C.icon)), isTrue);
    expect(painter.shouldRepaint(const AppIconPainter(AppGlyph.back, C.textDisabled)), isTrue);
  });

  testWidgets('an icon button with no tap is dimmed and inert', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          const IconTap(glyph: AppGlyph.back, label: 'Back', onTap: null),
          IconTap(glyph: AppGlyph.forward, label: 'Forward', onTap: () => taps++),
        ]),
      ),
    ));

    AppIcon icon(AppGlyph glyph) => tester.widget<AppIcon>(
        find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph));
    expect(icon(AppGlyph.back).color, C.textDisabled);
    expect(icon(AppGlyph.forward).color, C.icon);

    await tester.tap(find.byWidgetPredicate((w) => w is IconTap && w.label == 'Back'),
        warnIfMissed: false);
    await tester.tap(find.byWidgetPredicate((w) => w is IconTap && w.label == 'Forward'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(IconTap).first), const Size(40, 40));
  });

  testWidgets('the restyle v2 glyphs paint at small and large sizes', (tester) async {
    const added = [
      AppGlyph.shieldHalf, AppGlyph.shieldFull, AppGlyph.sitesFilled, AppGlyph.todayFilled,
      AppGlyph.settingsFilled, AppGlyph.caseSolid, AppGlyph.caseBroken, AppGlyph.caseDouble,
      AppGlyph.vault,
    ];
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Wrap(children: [
          for (final glyph in added) ...[
            AppIcon(glyph, size: 14, color: C.textMuted),
            AppIcon(glyph, size: 48, color: C.textPrimary),
          ],
        ]),
      ),
    ));

    expect(tester.takeException(), isNull);
    for (final glyph in added) {
      final icon = find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph && w.size == 48);
      expect(tester.getSize(icon), const Size(48, 48), reason: glyph.name);
    }
  });

  testWidgets('an icon button names itself for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: () {}),
      ),
    ));

    expect(find.bySemanticsLabel('Menu'), findsOneWidget);
    semantics.dispose();
  });
}

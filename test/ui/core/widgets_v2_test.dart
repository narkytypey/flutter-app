import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/core/widgets/choice_chip.dart';
import 'package:container/ui/core/widgets/group.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/core/widgets/step_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glyph_finders.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))));

/// Every colour any [BoxDecoration] under [of] paints, fill or border.
List<Color> _paints(WidgetTester tester, Finder of) {
  final colours = <Color>[];
  for (final c in tester.widgetList<Container>(find.descendant(of: of, matching: find.byType(Container)))) {
    if (c.color != null) colours.add(c.color!);
    final d = c.decoration;
    if (d is BoxDecoration) {
      if (d.color != null) colours.add(d.color!);
      final b = d.border;
      if (b is Border) colours.add(b.top.color);
    }
  }
  return colours;
}

void main() {
  testWidgets('an on switch is a light track with a checked knob, never jade', (tester) async {
    await _pump(tester, AppToggle(value: true, onChanged: (_) {}));
    expect(tester.getSize(find.byType(AppToggle)), const Size(52, 32));
    expect(_paints(tester, find.byType(AppToggle)), isNot(contains(C.jade)));
    expect(_paints(tester, find.byType(AppToggle)), contains(C.textPrimary));
    expect(findGlyph(AppGlyph.check), findsOneWidget);
  });

  testWidgets('an off switch is unfilled with an edge outline', (tester) async {
    await _pump(tester, AppToggle(value: false, onChanged: (_) {}));
    final track = tester.widget<Container>(find.descendant(
        of: find.byType(AppToggle), matching: find.byType(Container)).first);
    final d = track.decoration! as BoxDecoration;
    expect(d.color, isNull);
    expect((d.border! as Border).top.color, C.edge);
    expect(findGlyph(AppGlyph.check), findsNothing);
  });

  testWidgets('IconTap is a 48 dp target by default', (tester) async {
    await _pump(tester, IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: () {}));
    expect(tester.getSize(find.byType(IconTap)), const Size(48, 48));
  });

  testWidgets('PIN dots are 14 dp, and a wrong PIN rings them in danger', (tester) async {
    await _pump(tester, const PinDots(filled: 0, error: true));
    final dots = tester.widgetList<Container>(
        find.descendant(of: find.byType(PinDots), matching: find.byType(Container)));
    for (final dot in dots) {
      expect((dot.decoration! as BoxDecoration).border, isA<Border>());
      expect(((dot.decoration! as BoxDecoration).border! as Border).top.color, C.danger);
    }
    expect(tester.getSize(find.descendant(
        of: find.byType(PinDots), matching: find.byType(Container)).first), const Size(14, 14));
  });

  testWidgets('a selected chip shows a check and a text-1 outline; others do not', (tester) async {
    await _pump(tester, Row(mainAxisSize: MainAxisSize.min, children: [
      AppChip(label: 'Personal', selected: true, onTap: () {}),
      AppChip(label: 'Work', selected: false, onTap: () {}),
    ]));
    expect(findGlyph(AppGlyph.check), findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(AppChip, 'Personal'), matching: findGlyph(AppGlyph.check)),
        findsOneWidget);
    expect(_paints(tester, find.widgetWithText(AppChip, 'Personal')), contains(C.textPrimary));
    expect(_paints(tester, find.widgetWithText(AppChip, 'Work')), contains(C.line));
    expect(tester.getSize(find.widgetWithText(AppChip, 'Work')).height, greaterThanOrEqualTo(48));
  });

  testWidgets('a group is the group tone, outlined, with soft rules between rows', (tester) async {
    await _pump(tester, const SizedBox(width: 300, child: Group(children: [Text('a'), Text('b')])));
    final box = tester.widget<DecoratedBox>(find.descendant(
        of: find.byType(Group), matching: find.byType(DecoratedBox)).first);
    final d = box.decoration as BoxDecoration;
    expect(d.color, C.surface);
    expect((d.border! as Border).top.color, C.line);
    expect(d.borderRadius, BorderRadius.circular(18));
    expect(_paints(tester, find.byType(Group)), contains(C.lineSoft));
  });

  testWidgets('a primary pill is at least 52 dp; a danger text button has no fill or outline', (tester) async {
    await _pump(tester, Column(mainAxisSize: MainAxisSize.min, children: [
      PillButton(label: 'Try again', tone: PillTone.primary, onTap: () {}),
      PillButton(label: 'Open without the tunnel', tone: PillTone.dangerText, onTap: () {}),
      PillButton(label: 'Small', height: 28, onTap: () {}),
    ]));
    expect(tester.getSize(find.widgetWithText(PillButton, 'Try again')).height, greaterThanOrEqualTo(52));
    expect(tester.getSize(find.widgetWithText(PillButton, 'Small')).height, greaterThanOrEqualTo(48));
    final label = tester.widget<Text>(find.text('Open without the tunnel'));
    expect(label.style!.color, C.danger);
    final material = tester.widget<Material>(find.descendant(
        of: find.widgetWithText(PillButton, 'Open without the tunnel'), matching: find.byType(Material)).first);
    expect(material.color, const Color(0x00000000));
    final box = tester.widget<Container>(find.descendant(
        of: find.widgetWithText(PillButton, 'Open without the tunnel'), matching: find.byType(Container)).first);
    expect((box.decoration! as BoxDecoration).border, isNull);
  });

  testWidgets('the setup step bar uses no jade', (tester) async {
    await _pump(tester, const SizedBox(width: 300, child: StepProgress(step: 2)));
    final colours = _paints(tester, find.byType(StepProgress));
    expect(colours, isNot(contains(C.jade)));
    expect(colours, containsAll([C.textPrimary, C.edge]));
  });
}

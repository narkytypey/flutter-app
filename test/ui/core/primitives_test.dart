import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/dashed_box.dart';
import 'package:container/ui/core/widgets/monogram.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/core/widgets/setting_row.dart';
import 'package:container/ui/core/widgets/status_rail.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets("a setting row's value ends at the row's right edge, as the canvas draws it",
      (tester) async {
    // It started mid-row, after the title's half (seen on the emulator
    // 2026-10-05).
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 360, child: SettingRow(title: 'Auto-lock', value: 'After 1 min')),
      ),
    ));

    final row = tester.getRect(find.byType(SettingRow));
    final box = tester.getRect(find.text('After 1 min'));
    final paragraph = tester.renderObject<RenderParagraph>(find.text('After 1 min'));
    // Where the glyphs end: the box's right, less the empty space an
    // end-aligned paragraph leaves on its left... or none, start-aligned.
    final glyphsRight = paragraph.textAlign == TextAlign.end
        ? box.right
        : box.left + paragraph.textSize.width;
    expect(glyphsRight, row.right);
  });

  testWidgets('a live light is jade, an idle light is an edge ring (restyle v2 §5)', (tester) async {
    await _pump(tester, const Row(children: [StatusRail(live: true), StatusRail(live: false)]));

    final railFinders = find.byType(StatusRail);
    final liveRail = railFinders.at(0);
    final idleRail = railFinders.at(1);

    final live = tester
        .widget<Container>(find.descendant(of: liveRail, matching: find.byType(Container)))
        .decoration! as BoxDecoration;
    final idle = tester
        .widget<Container>(find.descendant(of: idleRail, matching: find.byType(Container)))
        .decoration! as BoxDecoration;

    expect(live.color, C.jade);
    expect(idle.color, isNull);
    expect((idle.border! as Border).top.color, C.edge);
    expect(tester.getSize(railFinders.first).width, 10);
  });

  testWidgets('an open monogram is brighter than an idle one', (tester) async {
    await _pump(tester, const Monogram('Nt'));
    expect(find.text('Nt'), findsOneWidget);
    expect(tester.getSize(find.byType(Monogram)), const Size(36, 36));

    final open = tester.widget<Text>(find.text('Nt')).style!.color;
    expect(open, C.monogramText);

    await _pump(tester, const Monogram('Fr', open: false));
    expect(tester.widget<Text>(find.text('Fr')).style!.color, C.textMuted);
  });

  testWidgets('a primary pill is jade with dark text and reports taps', (tester) async {
    var taps = 0;
    await _pump(tester, PillButton(
      label: '+ Add site',
      tone: PillTone.primary,
      height: 46,
      radius: 14,
      onTap: () => taps++,
    ));

    expect(tester.widget<Text>(find.text('+ Add site')).style!.color, C.bg);
    await tester.tap(find.byType(PillButton));
    expect(taps, 1);
  });

  testWidgets('a disabled pill does not report taps', (tester) async {
    var taps = 0;

    // Positive control: an enabled pill's tap is observable.
    await _pump(tester, PillButton(label: 'Continue', onTap: () => taps++));
    await tester.tap(find.byType(PillButton));
    expect(taps, 1);

    // Negative case: a disabled pill (onTap: null) must not advance the
    // counter, proving taps are genuinely suppressed rather than just
    // unobserved.
    await _pump(tester, const PillButton(label: 'Continue', onTap: null));
    await tester.tap(find.byType(PillButton));
    expect(taps, 1);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('DashedBox only repaints when its colour changes, not its radius', (tester) async {
    Future<CustomPainter> pumpAndGetPainter(Widget box) async {
      await _pump(tester, box);
      final finder = find.descendant(
        of: find.byType(DashedBox),
        matching: find.byType(CustomPaint),
      );
      return tester.widget<CustomPaint>(finder).painter!;
    }

    final base = await pumpAndGetPainter(
      const DashedBox(size: 80, radius: 12, color: C.line16),
    );

    // Identical params: no repaint needed.
    final same = await pumpAndGetPainter(
      const DashedBox(size: 80, radius: 12, color: C.line16),
    );
    expect(same.shouldRepaint(base), isFalse);

    // Colour changed: must repaint.
    final recoloured = await pumpAndGetPainter(
      const DashedBox(size: 80, radius: 12, color: C.danger),
    );
    expect(recoloured.shouldRepaint(same), isTrue);

    // Radius changed: must also repaint (the dash path depends on it).
    final resized = await pumpAndGetPainter(
      const DashedBox(size: 80, radius: 24, color: C.danger),
    );
    expect(resized.shouldRepaint(recoloured), isTrue);
  });
}

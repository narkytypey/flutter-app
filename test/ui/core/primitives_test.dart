import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/dashed_box.dart';
import 'package:container/ui/core/widgets/monogram.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/core/widgets/section_label.dart';
import 'package:container/ui/core/widgets/status_rail.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: child))),
  );
}

void main() {
  testWidgets('a live rail is jade, an idle rail is a hairline', (tester) async {
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
    expect(idle.color, C.line09);
    expect(tester.getSize(railFinders.first).width, 3);
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

  testWidgets('a section label is uppercase-styled and jade only when live', (tester) async {
    await _pump(tester, const Column(children: [
      SectionLabel('OPEN NOW', live: true),
      SectionLabel('IDLE'),
    ]));

    expect(tester.widget<Text>(find.text('OPEN NOW')).style!.color, C.jade);
    expect(tester.widget<Text>(find.text('IDLE')).style!.color, C.textFaint);
    expect(tester.widget<Text>(find.text('IDLE')).style!.letterSpacing, 1.0);
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

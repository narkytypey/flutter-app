import 'package:container/domain/models/open_step.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/features/container/views/opening_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/glyph_finders.dart';

void main() {
  testWidgets('shows the checklist and the tunnel promise', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OpeningBody(
        host: 'forum.example.com',
        steps: const [
          OpenStep('Fresh session, no shared cookies', OpenStepState.done),
          OpenStep('Filter lists loaded', OpenStepState.done),
          OpenStep('Fingerprint noise injected', OpenStepState.done),
          OpenStep('Connecting through 127.0.0.1:9050', OpenStepState.running),
        ],
        progress: 0.58,
        onCancel: () {},
      ),
    ));

    expect(find.text('Starting a clean container'), findsOneWidget);
    expect(find.text('Nothing loads until the tunnel is up.'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Connecting through 127.0.0.1:9050'), findsOneWidget);
    expect(findGlyph(AppGlyph.check), findsNWidgets(3));
  });

  // Restyle v2 §8 `8a` (Plan 21 Task 5): the route line wraps, never spills.
  testWidgets('v2: at 320 x 568 and 2.0 the Connecting through line does not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(2.0)),
        child: OpeningBody(
          host: 'forum.example.com',
          steps: const [
            OpenStep('Fresh session, no shared cookies', OpenStepState.done),
            OpenStep('Filter lists loaded', OpenStepState.done),
            OpenStep('Fingerprint noise injected', OpenStepState.done),
            OpenStep('Connecting through 127.0.0.1:9050', OpenStepState.running),
          ],
          progress: 0.58,
          onCancel: () {},
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final line = tester.renderObject<RenderParagraph>(find.descendant(
        of: find.text('Connecting through 127.0.0.1:9050'), matching: find.byType(RichText)));
    expect(line.didExceedMaxLines, isFalse);
    expect(tester.getTopRight(find.text('Connecting through 127.0.0.1:9050')).dx,
        lessThanOrEqualTo(320));
    // Nothing on 8a is jade: nothing is live yet.
    for (final icon in tester.widgetList<AppIcon>(find.byType(AppIcon))) {
      expect(icon.color, isNot(const Color(0xFF7FC8A9)));
    }
  });
}

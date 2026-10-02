import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/panic/views/panic_screen.dart';

import '../../support/glyph_finders.dart';

void main() {
  testWidgets('panic reports what happened, in past tense', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(
        report: const PanicReport(sessionsDestroyed: 3),
        onUnlock: () {},
      ),
    ));

    expect(find.text('Everything closed'), findsOneWidget);
    expect(
      find.text('3 sessions destroyed, temporary storage wiped, app locked.'),
      findsOneWidget,
    );
    expect(find.text('WEBVIEWS'), findsOneWidget);
    expect(find.text('DESTROYED'), findsOneWidget);
    expect(find.text('EPHEMERAL DATA'), findsOneWidget);
    expect(find.text('WIPED'), findsOneWidget);
    expect(find.text('MEMORY'), findsOneWidget);
    expect(find.text('CLEARED'), findsOneWidget);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.panic)).color, C.danger);
    expect(tester.getSize(findGlyph(AppGlyph.panic)), const Size(20, 20));
  });

  testWidgets('there is no confirmation step anywhere on the screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(
        report: const PanicReport(sessionsDestroyed: 1),
        onUnlock: () {},
      ),
    ));

    // Spec 3c: "no confirmation dialog, it just happens and reports after".
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(find.textContaining('Are you sure'), findsNothing);
    expect(find.text('Unlock'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/in_page/views/tunnel_dropped_screen.dart';

import '../../../support/glyph_finders.dart';

void main() {
  Widget host({VoidCallback? onReconnect, VoidCallback? onCloseAndWipe}) {
    return MaterialApp(
      home: TunnelDroppedScreen(
        host: 'forum.example.com',
        droppedAgoLabel: '4 seconds ago',
        onReconnect: onReconnect ?? () {},
        onCloseAndWipe: onCloseAndWipe ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Tunnel dropped'), findsOneWidget);
    expect(
      find.text(
        'The page is paused. Nothing further has been requested since the '
        'connection failed 4 seconds ago.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reconnect'), findsOneWidget);
    expect(find.text('Close and wipe'), findsOneWidget);
    // The top bar's marks stay decoration, as the canvas draws them: undimmed
    // and unlabelled (restyle spec §8).
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.back)).color, C.icon);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.reload)).color, C.icon);
    expect(findIconTap('Back'), findsNothing);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.refused)).color, C.danger);
    expect(tester.getSize(findGlyph(AppGlyph.refused)), const Size(16, 16));
  });

  testWidgets('each button reports its own callback', (tester) async {
    var reconnected = 0;
    var wiped = 0;
    await tester.pumpWidget(host(
      onReconnect: () => reconnected++,
      onCloseAndWipe: () => wiped++,
    ));

    await tester.tap(find.text('Reconnect'));
    await tester.tap(find.text('Close and wipe'));

    expect(reconnected, 1);
    expect(wiped, 1);
  });
}

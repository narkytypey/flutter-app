import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/features/in_page/views/site_sheet.dart';

void main() {
  Widget host({
    bool forceDark = true,
    bool desktopView = false,
    VoidCallback? onEdit,
    ValueChanged<bool>? onForceDarkChanged,
    ValueChanged<bool>? onDesktopViewChanged,
    VoidCallback? onCloseAndWipe,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SiteSheet(
          monogram: 'Fr',
          name: 'Forum',
          subtitle: 'forum.example.com · Personal',
          proxyDescriptor: 'SOCKS5 · 127.0.0.1:9050',
          cookiesDescriptor: 'Wipe on exit',
          blockedCount: 164,
          forceDark: forceDark,
          desktopView: desktopView,
          onEdit: onEdit ?? () {},
          onForceDarkChanged: onForceDarkChanged ?? (_) {},
          onDesktopViewChanged: onDesktopViewChanged ?? (_) {},
          onCloseAndWipe: onCloseAndWipe ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the spec copy and values verbatim', (tester) async {
    await tester.pumpWidget(host());

    expect(find.byKey(const Key('sheet-handle')), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Proxy'), findsOneWidget);
    expect(find.text('SOCKS5 · 127.0.0.1:9050'), findsOneWidget);
    expect(find.text('Cookies'), findsOneWidget);
    expect(find.text('Wipe on exit'), findsOneWidget);
    expect(find.text('Blocked here'), findsOneWidget);
    expect(find.text('164 requests'), findsOneWidget);
    expect(find.text('Force dark mode'), findsOneWidget);
    expect(find.text('Desktop view'), findsOneWidget);
    expect(find.text('Close and wipe this session'), findsOneWidget);
  });

  testWidgets('Edit reports a tap', (tester) async {
    var edits = 0;
    await tester.pumpWidget(host(onEdit: () => edits++));
    await tester.tap(find.text('Edit'));
    expect(edits, 1);
  });

  testWidgets('each toggle reports its new value, not just that it changed', (tester) async {
    bool? forceDarkSeen;
    bool? desktopViewSeen;
    await tester.pumpWidget(host(
      forceDark: true,
      desktopView: false,
      onForceDarkChanged: (v) => forceDarkSeen = v,
      onDesktopViewChanged: (v) => desktopViewSeen = v,
    ));

    final forceDarkRow = find.ancestor(
      of: find.text('Force dark mode'),
      matching: find.byType(Row),
    ).first;
    final desktopViewRow = find.ancestor(
      of: find.text('Desktop view'),
      matching: find.byType(Row),
    ).first;

    // Tap the toggle by its own type, never by whatever it happens to be
    // built from. `AppToggle` is Plan 2's widget; a test reaching for its
    // inner `GestureDetector` passes today and breaks the moment Plan 2
    // rebuilds it on an `InkWell` — failing here, looking like a bug here.
    await tester.tap(find.descendant(of: forceDarkRow, matching: find.byType(AppToggle)));
    await tester.tap(find.descendant(of: desktopViewRow, matching: find.byType(AppToggle)));

    expect(forceDarkSeen, isFalse); // was on, tapped once -> off
    expect(desktopViewSeen, isTrue); // was off, tapped once -> on
  });

  testWidgets('Close and wipe reports a tap', (tester) async {
    var wiped = 0;
    await tester.pumpWidget(host(onCloseAndWipe: () => wiped++));
    await tester.tap(find.text('Close and wipe this session'));
    expect(wiped, 1);
  });
}

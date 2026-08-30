import 'package:container/ui/features/container/views/container_screen.dart';
import 'package:container/ui/features/container/views/switcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _screen({
  bool live = true,
  int openCount = 3,
  VoidCallback? onBack,
  VoidCallback? onReload,
  VoidCallback? onPanic,
}) {
  return MaterialApp(
    home: ContainerScreen(
      host: 'forum.example.com',
      routeLabel: 'SOCKS5',
      live: live,
      openCount: openCount,
      body: const SizedBox.shrink(),
      entries: const [
        SwitcherEntry(
          siteId: 's1',
          name: 'Forum',
          monogram: 'Fr',
          meta: 'viewing now · socks5',
          live: true,
        ),
      ],
      workspaceName: 'Personal',
      onBack: onBack ?? () {},
      onReload: onReload ?? () {},
      onPanic: onPanic ?? () {},
      onCloseSession: (_) {},
      onCloseAllAndWipe: () {},
      onReaderMode: () {},
      onFilters: () {},
      onMenu: () {},
      onMore: () {},
    ),
  );
}

void main() {
  testWidgets('shows the host, the route label and the open count',
      (tester) async {
    await tester.pumpWidget(_screen());

    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(find.text('3 OPEN'), findsOneWidget);
  });

  testWidgets('a direct site shows no route label', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpWidget(MaterialApp(
      home: ContainerScreen(
        host: 'notes.example.org',
        routeLabel: '',
        live: true,
        openCount: 1,
        body: const SizedBox.shrink(),
        entries: const [],
        workspaceName: 'Personal',
        onBack: () {},
        onReload: () {},
        onPanic: () {},
        onCloseSession: (_) {},
        onCloseAllAndWipe: () {},
        onReaderMode: () {},
        onFilters: () {},
        onMenu: () {},
        onMore: () {},
      ),
    ));

    expect(find.text('SOCKS5'), findsNothing);
  });

  testWidgets('the back button reports a tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_screen(onBack: () => tapped = true));

    await tester.tap(find.text('‹'));
    expect(tapped, isTrue);
  });

  testWidgets('the panic square reports a tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_screen(onPanic: () => tapped = true));

    await tester.tap(find.text('◉'));
    expect(tapped, isTrue);
  });

  testWidgets('tapping the open-count pill opens the switcher sheet',
      (tester) async {
    await tester.pumpWidget(_screen());

    await tester.tap(find.text('3 OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('1 OPEN SESSIONS'), findsOneWidget);
    expect(find.text('viewing now · socks5'), findsOneWidget);
  });
}

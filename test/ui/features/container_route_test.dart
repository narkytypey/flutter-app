import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/reader_article.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/container/views/container_route.dart';
import 'package:container/ui/features/in_page/views/proxy_unreachable_screen.dart';
import 'package:container/ui/features/in_page/views/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site() => Site(
      id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'a' * 32,
      proxyMode: ProxyMode.direct,
    );

Future<void> _pump(WidgetTester tester, FakeContainerEngine engine, Site site) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [containerEngineProvider.overrideWithValue(engine)],
    child: MaterialApp(home: ContainerRoute(site: site)),
  ));
}

void main() {
  testWidgets('opening a site shows the checklist, then the container', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    // sessionForSiteProvider is still AsyncLoading for exactly the first
    // frame — [FakeContainerEngine.open] already ran synchronously inside
    // initState by this point, but the provider's `liveSessions()` snapshot
    // needs one microtask hop to resolve, so the very first frame is
    // guaranteed to be the opening checklist.
    expect(find.text('Starting a clean container'), findsOneWidget);

    await tester.pump();
    expect(find.text('forum.example.com'), findsOneWidget);
  });

  testWidgets('a refused route pushes ProxyUnreachableScreen', (tester) async {
    final engine = FakeContainerEngine(proxyReachable: false);
    await _pump(tester, engine, _site().copyWith(
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
    ));
    await tester.pumpAndSettle();
    expect(find.byType(ProxyUnreachableScreen), findsOneWidget);
  });

  testWidgets('a tunnel_dropped event overlays TunnelDroppedScreen on the still-live page', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitTunnelDropped(TunnelDroppedEvent(
      siteId: 's1', host: 'forum.example.com', droppedAt: DateTime(2026, 9, 2),
    ));
    // Two pumps, not one: the broadcast StreamController's `.add()` only
    // schedules delivery to `_tunnelSub`'s listener as a microtask, and that
    // microtask runs after this pump's frame has already been built —
    // verified empirically (a single `pump()` here leaves the overlay
    // absent). `pumpAndSettle()` would also work but hides how many frames
    // this genuinely takes; two explicit pumps keeps that visible.
    await tester.pump();
    await tester.pump();
    expect(find.text('Tunnel dropped'), findsOneWidget);
  });

  testWidgets('tapping reader mode with a real article pushes ReaderScreen', (tester) async {
    final engine = FakeContainerEngine()
      ..articleToReturn = const ReaderArticle(
        host: 'forum.example.com', title: 'A thread', paragraphs: ['Hello.'], minutesToRead: 1,
      );
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await tester.tap(find.text('◑'));
    await tester.pumpAndSettle();

    expect(find.text('A thread'), findsOneWidget);
  });

  testWidgets('tapping reader mode with no article does nothing', (tester) async {
    final engine = FakeContainerEngine(); // articleToReturn stays null
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await tester.tap(find.text('◑'));
    await tester.pumpAndSettle();

    expect(find.byType(ReaderScreen), findsNothing);
  });
}

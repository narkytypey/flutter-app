import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/held_download.dart';
import 'package:container/domain/models/reader_article.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show siteRepositoryProvider, workspacesProvider;
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/container/views/container_route.dart';
import 'package:container/ui/features/container/views/container_web_view.dart';
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

/// Records every upsert, so a test can assert on what was persisted.
class _RecordingSiteRepository implements SiteRepository {
  final upserts = <Site>[];

  @override
  Future<void> upsert(Site site) async => upserts.add(site);
  @override
  Future<List<Site>> all() => throw UnimplementedError();
  @override
  Future<List<Site>> inWorkspace(String workspaceId) => throw UnimplementedError();
  @override
  Future<Site?> byId(String id) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  @override
  Future<void> touch(String id, DateTime at) => throw UnimplementedError();
}

const _workspace = Workspace(
    id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

Future<void> _pump(
  WidgetTester tester,
  FakeContainerEngine engine,
  Site site, {
  SiteRepository? sites,
}) async {
  // A modal bottom sheet is capped at 9/16 of the surface height, so the
  // default 800x600 canvas leaves HeldDownloadSheet ~294px where its fixed
  // column needs ~357px. Only the height is raised here: the container
  // screen's own rows need the default 800 width, and narrowing to a phone
  // width overflows all five of the older tests in this file.
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      if (sites != null) siteRepositoryProvider.overrideWithValue(sites),
      workspacesProvider.overrideWith((ref) async => const [_workspace]),
    ],
    child: MaterialApp(home: ContainerRoute(site: site)),
  ));
}

void main() {
  testWidgets('the site sheet describes the route as spec 6c does', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site().copyWith(
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      cookiePolicy: CookiePolicy.wipeOnExit,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();

    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('SOCKS5 · 127.0.0.1:9050'), findsOneWidget);
    expect(find.text('Wipe on exit'), findsOneWidget);
  });

  // Both switches in one sheet: the second save must carry the first change,
  // not overwrite it with the site as it was when the route was pushed.
  testWidgets('site sheet toggles persist and accumulate', (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _site(), sites: sites);
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppToggle).at(0)); // Force dark mode, on by default
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppToggle).at(1)); // Desktop view
    await tester.pumpAndSettle();

    expect(sites.upserts, hasLength(2));
    expect(sites.upserts.last.forceDark, isFalse);
    expect(sites.upserts.last.userAgentMode, UserAgentMode.desktop);
    final toggles = tester.widgetList<AppToggle>(find.byType(AppToggle)).toList();
    expect(toggles[0].value, isFalse);
    expect(toggles[1].value, isTrue);
  });

  testWidgets("the site sheet's Edit opens the add-site form on this site", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), sites: _RecordingSiteRepository());
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(tester.widget<AddSiteScreen>(find.byType(AddSiteScreen)).initial?.id, 's1');
  });

  testWidgets('close and wipe from the site sheet wipes this profile', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close and wipe this session'));
    await tester.pumpAndSettle();

    expect(engine.closed, contains('s1'));
    expect(engine.wiped, contains('a' * 32));
  });

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
    await tester.pump();
    expect(find.text('forum.example.com'), findsOneWidget);
  });

  // The real engine reports `opening` until the native view's first load
  // finishes, and that view only exists once ContainerWebView is built. A
  // route that waits for `live` before building it never gets there — on a
  // device every site sat on the checklist forever.
  testWidgets('while opening, the page view is already built under the checklist', (tester) async {
    final engine = FakeContainerEngine(opensLive: false);
    await _pump(tester, engine, _site());
    await tester.pump();
    await tester.pump();

    expect(find.text('Starting a clean container'), findsOneWidget);
    expect(find.byType(ContainerWebView), findsOneWidget);
  });

  // Rebuilding the view on the handoff would dispose the native WebView —
  // which, for a wipe-on-exit site, destroys its profile — and load the page
  // a second time.
  testWidgets('going live reveals the same page view rather than a new one', (tester) async {
    final engine = FakeContainerEngine(opensLive: false);
    await _pump(tester, engine, _site());
    await tester.pump();
    await tester.pump();
    final before = tester.state(find.byType(PlatformViewLink));

    engine.markLive('s1');
    await tester.pump();
    await tester.pump();

    expect(find.text('Starting a clean container'), findsNothing);
    expect(tester.state(find.byType(PlatformViewLink)), same(before));
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

  testWidgets('tapping a held-download sheet action resolves the download with its requestId', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitDownload(const HeldDownloadEvent(
      siteId: 's1', requestId: 'req-1',
      download: HeldDownload(
        fileName: 'notes.pdf', sizeBytes: 1024,
        sourceHost: 'forum.example.com', kindLabel: 'PDF',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep inside this container'));
    await tester.pumpAndSettle();

    expect(engine.resolvedDownloads.single.requestId, 'req-1');
    expect(engine.resolvedDownloads.single.decision, DownloadDecision.keepInContainer);
  });

  testWidgets('a download_result event shows the matching snackbar for each outcome', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitDownload(const HeldDownloadEvent(
      siteId: 's1', requestId: 'req-1',
      download: HeldDownload(
        fileName: 'a.pdf', sizeBytes: 100,
        sourceHost: 'forum.example.com', kindLabel: 'PDF',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep inside this container'));
    await tester.pumpAndSettle();

    // Two pumps per emit, for the same reason the tunnel_dropped test above
    // needs them: the broadcast stream delivers to the listener as a
    // microtask that runs after the current pump's frame is already built,
    // so the SnackBar is only in the tree by the second frame.
    engine.emitDownloadResult(const DownloadResult(requestId: 'req-1', outcome: DownloadOutcome.saved));
    await tester.pump();
    await tester.pump();
    expect(find.text('Saved to Downloads'), findsOneWidget);

    await _drainSnackBar(tester);
    engine.emitDownloadResult(const DownloadResult(requestId: 'req-1', outcome: DownloadOutcome.kept));
    await tester.pump();
    await tester.pump();
    expect(find.text('Kept in this container'), findsOneWidget);

    await _drainSnackBar(tester);
    engine.emitDownloadResult(const DownloadResult(
      requestId: 'req-1', outcome: DownloadOutcome.failed, reason: RouteFailure.proxyUnreachable,
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text(refusalMessage(RouteFailure.proxyUnreachable)), findsOneWidget);
  });
}

/// ScaffoldMessenger queues SnackBars rather than overlapping them, so the
/// current one must be fully gone before the next emit can show.
///
/// The order here matters and is not the obvious one. A bare
/// `pump(Duration(seconds: 5))` does *not* dismiss a SnackBar that is still
/// animating in: that frame completes the entrance animation, and only then
/// is the 4s display timer scheduled — measured from that frame, so it is
/// still pending afterwards. Settle the entrance first, then jump the timer,
/// then settle the exit.
Future<void> _drainSnackBar(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

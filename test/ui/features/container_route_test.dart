import 'dart:async';

import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/container_session.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/domain/models/find_result.dart';
import 'package:container/domain/models/held_download.dart';
import 'package:container/domain/models/monogram_suggestion.dart';
import 'package:container/domain/models/navigation_state.dart';
import 'package:container/domain/models/reader_article.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/container/view_models/throwaway_sites.dart';
import 'package:container/ui/features/container/views/address_suggestions.dart';
import 'package:container/ui/features/container/views/container_route.dart';
import 'package:container/ui/features/container/views/container_web_view.dart';
import 'package:container/ui/features/container/views/find_bar.dart';
import 'package:container/ui/features/container/views/switcher_sheet.dart';
import 'package:container/ui/features/container/views/throwaway_save_bar.dart';
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart'
    show siteLookupProvider;
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show databaseProvider, openSiteIdsProvider, siteRepositoryProvider, workspacesProvider;
import 'package:container/ui/features/in_page/views/proxy_unreachable_screen.dart';
import 'package:container/ui/features/in_page/views/reader_screen.dart';
import 'package:container/ui/features/report/views/today_route.dart';
import 'package:container/ui/features/scripts/views/scripts_route.dart';
import 'package:container/ui/features/search/view_models/providers.dart' show allSitesProvider;
import 'package:container/ui/features/settings/view_models/providers.dart'
    show searchEngineProvider;
import 'package:container/ui/features/settings/views/settings_route.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show biometricServiceProvider;
import 'package:container/ui/features/workspaces/views/workspaces_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data/bundled_filter_lists_test.dart' show FakeBundle;
import 'shell/session_controller_test.dart' show FakeBiometricService;

Site _site() => Site(
      id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'a' * 32,
      proxyMode: ProxyMode.direct,
    );

Site _throwaway() => Site(
      id: 't1', workspaceId: 'w', name: 'news.example.org', monogram: 'Nw',
      url: 'https://news.example.org', profileId: 'c' * 32,
      cookiePolicy: CookiePolicy.wipeOnExit,
    );

/// Holds an [open] back until the test releases it — the real engine's open
/// returns only after a worker thread has decided the route.
class _GatedEngine extends FakeContainerEngine {
  _GatedEngine({super.opensLive});

  Completer<void>? _gate;

  Completer<void> holdNextOpen() => _gate = Completer<void>();

  @override
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
    String? initialUrl,
  }) async {
    final gate = _gate;
    _gate = null;
    if (gate != null) await gate.future;
    return super.open(site, extras: extras, throwaway: throwaway, initialUrl: initialUrl);
  }
}

/// Records every upsert, so a test can assert on what was persisted.
class _RecordingSiteRepository implements SiteRepository {
  _RecordingSiteRepository({this.events});

  final upserts = <Site>[];

  /// Shared with [_LoggingEngine], so a test can pin the order of a save.
  final List<String>? events;

  @override
  Future<void> upsert(Site site) async {
    upserts.add(site);
    events?.add('upsert ${site.id}');
  }
  /// What the vault holds now. [_pump] fills it with its `saved` sites unless a
  /// test set it, so a test can make it differ from the address bar's copy.
  List<Site>? stored;

  @override
  Future<List<Site>> all() async => stored ?? (throw UnimplementedError());
  @override
  Future<List<Site>> inWorkspace(String workspaceId) => throw UnimplementedError();
  @override
  Future<Site?> byId(String id) => throw UnimplementedError();
  @override
  Future<void> delete(String id) => throw UnimplementedError();
  /// Sites marked visited: what `openSite` records.
  final touched = <String>[];

  @override
  Future<void> touch(String id, DateTime at) async => touched.add(id);

  /// `8b`'s "Last worked", by site id.
  final worked = <String, DateTime?>{};

  @override
  Future<DateTime?> lastWorked(String id) async => worked[id];
  @override
  Future<void> setLastWorked(String id, DateTime? at) async => worked[id] = at;
}

/// Logs `keep` into the same list the repository logs its upserts to.
class _LoggingEngine extends FakeContainerEngine {
  _LoggingEngine(this.events);

  final List<String> events;

  @override
  Future<void> keep(String siteId) async {
    events.add('keep $siteId');
    await super.keep(siteId);
  }
}

/// The real registry empties itself on leaving `SessionOpen`, which needs a
/// session this file does not build.
class _Throwaways extends ThrowawaySites {
  _Throwaways(this.initial);

  final List<Site> initial;

  @override
  List<Site> build() => initial;
}

List<Site> _registry(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(throwawaySitesProvider);

Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

/// What the platform sends for a system back gesture.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Lets real database IO finish, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Answers `flutter/platform_views` for a test that lets real async work run;
/// the first test in this file explains why an unanswered create is fatal.
void _standInForPlatformViews(WidgetTester tester) {
  const platformViews = MethodChannel('flutter/platform_views');
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(platformViews, (call) async => null);
  addTearDown(() =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(platformViews, null));
}

/// A SOCKS5 forum: a throwaway typed in it goes out on the same proxy.
Site _socksSite() => _site().copyWith(
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050);

const _market = Site(
  id: 'm1', workspaceId: 'w', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
);

/// Taps [pill], the forum's by default, and types [text] into the address field.
Future<void> _typeAddress(WidgetTester tester, String text,
    {String pill = 'forum.example.com'}) async {
  await tester.tap(find.text(pill));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

const _workspace = Workspace(
    id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

/// Stands in for the dashboard when [_pump] is given `overHome: true`.
const _homeMarker = 'Home route';

Future<void> _pump(
  WidgetTester tester,
  FakeContainerEngine engine,
  Site site, {
  SiteRepository? sites,
  bool realExtras = false,
  List<Override> overrides = const [],
  bool overHome = false,
  bool throwaway = false,
  String? initialUrl,
  List<Site> throwaways = const [],
  Size size = const Size(800, 1600),
  List<Site> saved = const [],
  SearchEngine searchEngine = SearchEngine.duckDuckGo,
  void Function()? onSavedRead,
}) async {
  // A modal bottom sheet is capped at 9/16 of the surface height, so the
  // default 800x600 canvas leaves HeldDownloadSheet ~294px where its fixed
  // column needs ~357px: hence the tall default. A test about a phone
  // passes [size].
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final navigator = GlobalKey<NavigatorState>();
  Widget route() => ContainerRoute(site: site, initialUrl: initialUrl, throwaway: throwaway);
  // The vault holds what the address bar suggests from, unless a test says
  // otherwise.
  final repository = sites ?? _RecordingSiteRepository();
  if (repository is _RecordingSiteRepository) repository.stored ??= saved;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      siteRepositoryProvider.overrideWithValue(repository),
      workspacesProvider.overrideWith((ref) async => const [_workspace]),
      throwawaySitesProvider.overrideWith(() => _Throwaways(throwaways)),
      // Today's tally, which the ☰ menu shows, looks each session's site up
      // in the vault. These tests have no vault.
      siteLookupProvider.overrideWithValue((_) async => null),
      // What the address bar suggests from: this vault's sites and engine.
      allSitesProvider.overrideWith((ref) async {
        onSavedRead?.call();
        return saved;
      }),
      searchEngineProvider.overrideWith((ref) async => searchEngine),
      if (!realExtras)
        engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
      ...overrides,
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      home: overHome ? const Scaffold(body: Text(_homeMarker)) : route(),
    ),
  ));
  // Pushed the way the dashboard pushes it, so a test can see whether leaving
  // the container lands back on what was underneath.
  if (overHome) {
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => route()));
  }
}

void main() {
  testWidgets("opening sends the vault's enabled rules and this site's scripts", (tester) async {
    sqfliteFfiInit();
    final database = (await tester.runAsync(
        () => AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)))!;
    addTearDown(() => tester.runAsync(database.close));
    final lists = [
      BundledFilterList(
        id: 'fl-a', name: 'A', enabledByDefault: true,
        category: FilterListCategory.trackers, asset: 'a.txt',
        updatedAt: DateTime.utc(2026, 9, 28),
      ),
    ];
    final rules = BundledFilterRules(FakeBundle({'a.txt': '||t.example^\n'}), lists: lists);
    await tester.runAsync(() async {
      await syncBundledFilterLists(database, rules);
      // script_sites.site_id has a foreign key on sites(id); the site this
      // script is applied to must exist in this same database first.
      await SqliteWorkspaceRepository(database).upsert(_workspace);
      await SqliteSiteRepository(database).upsert(_site());
      await SqliteScriptRepository(database).upsert(const UserScript(
        id: 'sc', name: 'Hide', kind: ScriptKind.css, code: 'header{display:none}',
        runAtDocumentStart: true, enabled: true, appliedSiteIds: ['s1'],
      ));
    });

    // This test's `_open` awaits a real database round trip before the
    // session goes live, so the loop below drives it via `runAsync`. That
    // moves ContainerWebView's `PlatformViewLink.create()` call onto a real
    // async gap too, where its normally-forever-pending platform channel
    // call actually settles — with no handler registered, as
    // MissingPluginException, unhandled, and fatal to the test. No other
    // test in this file awaits real IO before going live, so none of them
    // hit this. What this test asserts on is `engine.openedExtras`, not
    // native view creation, so it stands in for the platform here.
    const platformViews = MethodChannel('flutter/platform_views');
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(platformViews, (call) async => null);
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(platformViews, null));

    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), realExtras: true, overrides: [
      databaseProvider.overrideWithValue(database),
      bundledFilterRulesProvider.overrideWithValue(rules),
    ]);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    final extras = engine.openedExtras['s1']!;
    expect(extras.filterRules, {'trackers': ['||t.example^']});
    expect(extras.userScripts.single.code, 'header{display:none}');
  });

  testWidgets('the site sheet describes the route as spec 6c does', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site().copyWith(
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      cookiePolicy: CookiePolicy.wipeOnExit,
    ));
    await tester.pumpAndSettle();

    await tester.tap(_icon('Site details'));
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

    await tester.tap(_icon('Site details'));
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

  // Every write to a site refreshes the address bar's copy of the vault's
  // sites, so a suggestion's tag says where it really opens.
  group("the address bar's sites are read again after", () {
    Future<int> readsAfter(WidgetTester tester, Future<void> Function() act) async {
      var reads = 0;
      await _pump(tester, FakeContainerEngine(), _site(),
          sites: _RecordingSiteRepository(), saved: [_site(), _market], overHome: true,
          onSavedRead: () => reads++);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      await container.read(allSitesProvider.future);
      final before = reads;
      await act();
      await container.read(allSitesProvider.future);
      return reads - before;
    }

    testWidgets("a switch in this site's sheet (6c)", (tester) async {
      final reads = await readsAfter(tester, () async {
        await tester.tap(_icon('Site details'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(AppToggle).at(0));
        await tester.pumpAndSettle();
      });
      expect(reads, greaterThan(0));
    });

    testWidgets("this site's Edit, saved", (tester) async {
      final reads = await readsAfter(tester, () async {
        await tester.tap(_icon('Site details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      });
      expect(reads, greaterThan(0));
    });

    testWidgets('close and wipe, which gives this site a fresh profile', (tester) async {
      final reads = await readsAfter(tester, () async {
        await tester.tap(_icon('Site details'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close and wipe this session'));
        await tester.pumpAndSettle();
      });
      expect(reads, greaterThan(0));
    });
  });

  testWidgets("the site sheet's Edit opens the add-site form on this site", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), sites: _RecordingSiteRepository());
    await tester.pumpAndSettle();

    await tester.tap(_icon('Site details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(tester.widget<AddSiteScreen>(find.byType(AddSiteScreen)).initial?.id, 's1');
  });

  testWidgets('close and wipe from the site sheet wipes this profile', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), sites: _RecordingSiteRepository());
    await tester.pumpAndSettle();

    await tester.tap(_icon('Site details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close and wipe this session'));
    await tester.pumpAndSettle();

    expect(engine.closed, contains('s1'));
    expect(engine.wiped, contains('a' * 32));
  });

  // The switcher is a modal sheet on top of this route. Popping "the top
  // route" once closes only the sheet and leaves the user on this site's
  // opening checklist, its session already gone.
  testWidgets('close all and wipe from the switcher returns to the route underneath', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), sites: _RecordingSiteRepository(), overHome: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close all and wipe'));
    await tester.pumpAndSettle();

    expect(engine.closed, contains('s1'));
    expect(engine.wiped, contains('a' * 32));
    expect(find.byType(SwitcherSheet), findsNothing);
    expect(find.byType(ContainerRoute), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
  });

  testWidgets("closing this site's own session from the switcher returns to the route underneath", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(SwitcherSheet), matching: find.text('×'),
    ));
    await tester.pumpAndSettle();

    expect(engine.closed, ['s1']);
    expect(find.byType(SwitcherSheet), findsNothing);
    expect(find.byType(ContainerRoute), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
  });

  // The dashboard's OPEN NOW rows and session count, search's live rail and
  // `9c`'s closed-session count all read openSiteIdsProvider. A session
  // closed here but left in it went on reading as open. Seen on the emulator.
  Future<Set<String>> openIdsAfterClosing(
      WidgetTester tester, Future<void> Function() close) async {
    final engine = FakeContainerEngine();
    // A wipe writes the site's fresh profile back to the vault.
    await _pump(tester, engine, _site(), sites: _RecordingSiteRepository(), overHome: true, overrides: [
      openSiteIdsProvider.overrideWith((ref) => {'s1', 'other'}),
    ]);
    await tester.pumpAndSettle();
    await close();
    await tester.pumpAndSettle();
    expect(engine.closed, contains('s1'));
    return ProviderScope.containerOf(tester.element(find.text(_homeMarker)))
        .read(openSiteIdsProvider);
  }

  testWidgets("closing this site's session from the switcher stops it reading as open",
      (tester) async {
    final open = await openIdsAfterClosing(tester, () async {
      await tester.tap(find.text('1 OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(SwitcherSheet), matching: find.text('×'),
      ));
    });
    expect(open, {'other'});
  });

  testWidgets('close all and wipe from the switcher stops the site reading as open',
      (tester) async {
    final open = await openIdsAfterClosing(tester, () async {
      await tester.tap(find.text('1 OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close all and wipe'));
    });
    expect(open, {'other'});
  });

  testWidgets("close and wipe from the site sheet stops the site reading as open",
      (tester) async {
    final open = await openIdsAfterClosing(tester, () async {
      await tester.tap(_icon('Site details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close and wipe this session'));
    });
    expect(open, {'other'});
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

  // A site reopened while its last session is still open used to build its
  // page view against that old session: the native view factory binds to
  // whatever session the site has when the view is created, so the page
  // loaded under the settings it was *last* opened with. Switched from direct
  // to a proxy, it went out direct; and the new session never went live, so
  // the route hung on "Connecting through …". Seen on a device.
  testWidgets('a reopened site builds no page view until its own open returns', (tester) async {
    final engine = _GatedEngine(opensLive: false);
    // What the previous visit left behind: a session still registered.
    await engine.open(_site());
    engine.markLive('s1');

    final gate = engine.holdNextOpen();
    await _pump(tester, engine, _site());
    await tester.pump();
    await tester.pump();

    expect(find.byType(ContainerWebView), findsNothing);
    expect(find.text('Starting a clean container'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump();

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

  // Spec 8b. Its three buttons once each popped the container's own context,
  // gone by then because 8b replaced the route: tapping them did nothing.
  // Seen on the emulator, 2026-10-02.
  group('8b, a refused open', () {
    Future<(FakeContainerEngine, _RecordingSiteRepository)> refuse(WidgetTester tester,
        {List<Override> overrides = const []}) async {
      final engine = FakeContainerEngine(proxyReachable: false);
      final sites = _RecordingSiteRepository();
      await _pump(tester, engine, _socksSite(),
          sites: sites, overHome: true, overrides: overrides);
      await tester.pumpAndSettle();
      expect(find.byType(ProxyUnreachableScreen), findsOneWidget);
      return (engine, sites);
    }

    testWidgets('Try again opens the site again', (tester) async {
      final (engine, _) = await refuse(tester);

      engine.proxyReachable = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(ProxyUnreachableScreen), findsNothing);
      expect(find.byType(ContainerWebView), findsOneWidget);
      expect(engine.openedSites['s1']!.proxyMode, ProxyMode.socks5);
    });

    testWidgets('Try again that is refused again shows 8b again', (tester) async {
      await refuse(tester);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(ProxyUnreachableScreen), findsOneWidget);
    });

    testWidgets("Change proxy settings opens the site's form on its Network tab; "
        'saving writes the site and opens it with the new settings', (tester) async {
      final (engine, sites) = await refuse(tester);

      await tester.tap(find.text('Change proxy settings'));
      await tester.pumpAndSettle();
      expect(find.byType(AddSiteScreen), findsOneWidget);
      expect(find.byKey(const Key('proxy-enabled')), findsOneWidget);

      await tester.tap(find.byKey(const Key('proxy-enabled'))); // proxy off: direct
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(sites.upserts.single.proxyMode, ProxyMode.direct);
      expect(engine.openedSites['s1']!.proxyMode, ProxyMode.direct);
      expect(find.byType(AddSiteScreen), findsNothing);
      expect(find.byType(ProxyUnreachableScreen), findsNothing);
      expect(find.byType(ContainerWebView), findsOneWidget);
    });

    testWidgets('leaving the form without saving returns to 8b', (tester) async {
      final (_, sites) = await refuse(tester);

      await tester.tap(find.text('Change proxy settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('×'));
      await tester.pumpAndSettle();

      expect(find.byType(ProxyUnreachableScreen), findsOneWidget);
      expect(sites.upserts, isEmpty);
    });

    testWidgets('Open without the tunnel opens this visit direct and saves nothing',
        (tester) async {
      final (engine, sites) = await refuse(tester);

      await tester.tap(find.text('Open without the tunnel'));
      await tester.pumpAndSettle();

      final opened = engine.openedSites['s1']!;
      expect(opened.proxyMode, ProxyMode.direct);
      expect(opened.proxyHost, isNull);
      expect(opened.proxyPort, isNull);
      expect(opened.profileId, _socksSite().profileId, reason: 'the site\'s own container');
      expect(sites.upserts, isEmpty);
      expect(find.byType(ProxyUnreachableScreen), findsNothing);
      expect(find.text('SOCKS5'), findsNothing, reason: 'no route label on a direct visit');
    });

    testWidgets('a direct visit does not count as the tunnel working', (tester) async {
      final (_, sites) = await refuse(tester);

      await tester.tap(find.text('Open without the tunnel'));
      await tester.pumpAndSettle();

      expect(sites.worked['s1'], isNull);
    });

    testWidgets('a refused site stops reading as open, and its session is closed',
        (tester) async {
      final (engine, _) = await refuse(tester, overrides: [
        openSiteIdsProvider.overrideWith((ref) => {'s1', 'other'}),
      ]);

      expect(engine.closed, contains('s1'));
      final open = ProviderScope.containerOf(tester.element(find.byType(ProxyUnreachableScreen)))
          .read(openSiteIdsProvider);
      expect(open, {'other'});
    });

    testWidgets('trying again puts the site back under OPEN NOW', (tester) async {
      final (engine, _) = await refuse(tester, overrides: [
        openSiteIdsProvider.overrideWith((ref) => {'s1'}),
      ]);

      engine.proxyReachable = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      final open = ProviderScope.containerOf(tester.element(find.byType(ContainerRoute)))
          .read(openSiteIdsProvider);
      expect(open, {'s1'});
    });

    testWidgets('Last worked reads never on this device for a site that never worked',
        (tester) async {
      await refuse(tester);

      expect(find.text('never on this device'), findsOneWidget);
    });

    testWidgets('Last worked reads how long ago the site last went live', (tester) async {
      final engine = FakeContainerEngine(proxyReachable: false);
      final sites = _RecordingSiteRepository()
        ..worked['s1'] = DateTime.now().subtract(const Duration(hours: 2, minutes: 5));
      await _pump(tester, engine, _socksSite(), sites: sites);
      await tester.pumpAndSettle();

      expect(find.text('2 hours ago'), findsOneWidget);
    });

    testWidgets('a throwaway refused and tried again is still a throwaway', (tester) async {
      final engine = FakeContainerEngine(proxyReachable: false);
      final throwaway = _throwaway().copyWith(
          proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050);
      await _pump(tester, engine, throwaway, throwaway: true, throwaways: [throwaway]);
      await tester.pumpAndSettle();
      expect(find.byType(ProxyUnreachableScreen), findsOneWidget);
      expect(engine.closed, isEmpty, reason: 'a throwaway closes when it is left');

      engine.proxyReachable = true;
      engine.openedAsThrowaway.clear();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(engine.openedAsThrowaway, {'t1'});
      expect(_registry(tester).map((s) => s.id), ['t1']);
    });

    // As Edit on a throwaway does: its form saves it.
    testWidgets("a throwaway's Change proxy settings saves it as a site, then opens it",
        (tester) async {
      final engine = FakeContainerEngine(proxyReachable: false);
      final sites = _RecordingSiteRepository();
      final throwaway = _throwaway().copyWith(
          proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050);
      await _pump(tester, engine, throwaway,
          sites: sites, throwaway: true, throwaways: [throwaway]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Change proxy settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proxy-enabled')));
      await tester.pump();
      engine.openedAsThrowaway.clear();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(sites.upserts.single.id, 't1');
      expect(sites.upserts.single.cookiePolicy, CookiePolicy.keep,
          reason: 'as "Save as a site" starts it');
      expect(engine.kept, ['t1']);
      expect(_registry(tester), isEmpty);
      expect(engine.openedAsThrowaway, isEmpty, reason: 'reopened as the saved site');
      expect(engine.openedSites['t1']!.proxyMode, ProxyMode.direct);
      expect(find.byType(ContainerWebView), findsOneWidget);
    });

    testWidgets("a throwaway typed during a direct visit keeps the site's own route",
        (tester) async {
      await refuse(tester);
      await tester.tap(find.text('Open without the tunnel'));
      await tester.pumpAndSettle();

      await _typeAddress(tester, 'news.example.org');

      expect(find.textContaining('THROWAWAY · SOCKS5'), findsWidgets);
    });
  });

  testWidgets('a site that goes live records when it last worked', (tester) async {
    final engine = FakeContainerEngine(opensLive: false);
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _site(), sites: sites);
    await tester.pumpAndSettle();
    expect(sites.worked['s1'], isNull, reason: 'not before the first load');

    engine.markLive('s1');
    await tester.pumpAndSettle();

    expect(sites.worked['s1'], isNotNull);
  });

  testWidgets('a site already live when its open returns records it too', (tester) async {
    final sites = _RecordingSiteRepository();
    await _pump(tester, FakeContainerEngine(), _site(), sites: sites);
    await tester.pumpAndSettle();

    expect(sites.worked['s1'], isNotNull);
  });

  testWidgets('a throwaway records nothing in the vault', (tester) async {
    final sites = _RecordingSiteRepository();
    await _pump(tester, FakeContainerEngine(), _throwaway(),
        sites: sites, throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    expect(sites.worked, isEmpty);
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

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reader'));
    await tester.pumpAndSettle();

    expect(find.text('A thread'), findsOneWidget);
  });

  testWidgets('tapping reader mode with no article does nothing', (tester) async {
    final engine = FakeContainerEngine(); // articleToReturn stays null
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reader'));
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

  testWidgets('a throwaway is opened as one', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true);
    await tester.pumpAndSettle();

    expect(engine.openedAsThrowaway, {'t1'});
  });

  testWidgets('a plain open has no typed address', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    expect(engine.openedInitialUrls, {'s1': null});
  });

  testWidgets('a saved site opened at a typed address loads it, and saves nothing', (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _site(), sites: sites,
        initialUrl: 'https://forum.example.com/t/9');
    await tester.pumpAndSettle();

    // The session keeps the stored address, which scopes its scripts and
    // names it in every prompt; the typed one is only the first load.
    expect(engine.openedSites['s1']!.url, 'https://forum.example.com');
    expect(engine.openedInitialUrls['s1'], 'https://forum.example.com/t/9');
    expect(engine.openedAsThrowaway, isEmpty);
    expect(sites.upserts, isEmpty);
  });

  testWidgets('leaving a throwaway closes its session', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true, overHome: true);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(ContainerRoute))).pop();
    await tester.pumpAndSettle();

    expect(engine.closed, ['t1']);
  });

  testWidgets('leaving a saved site leaves its session open', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(ContainerRoute))).pop();
    await tester.pumpAndSettle();

    expect(engine.closed, isEmpty);
  });

  // Review Focus 4: a lock or panic disposes the open vault's navigator, and
  // every route in it, without popping anything.
  testWidgets('a throwaway torn down with its navigator is closed too', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());

    expect(engine.closed, ['t1']);
  });

  testWidgets("a throwaway's site sheet changes nothing in the vault", (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    await tester.tap(_icon('Site details'));
    await tester.pumpAndSettle();
    // No workspace until it is saved.
    expect(find.text('news.example.org · Personal'), findsNothing);
    await tester.tap(find.byType(AppToggle).at(0)); // Force dark mode
    await tester.pumpAndSettle();

    expect(sites.upserts, isEmpty);
    expect(tester.widget<AppToggle>(find.byType(AppToggle).at(0)).value, isFalse);
  });

  testWidgets('Edit on a throwaway saves it: the row first, then its profile kept', (tester) async {
    final events = <String>[];
    final engine = _LoggingEngine(events);
    final sites = _RecordingSiteRepository(events: events);
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    await tester.tap(_icon('Site details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final form = tester.widget<AddSiteScreen>(find.byType(AddSiteScreen));
    expect(form.initial!.id, 't1');
    expect(form.initial!.profileId, 'c' * 32);
    expect(form.initial!.url, 'https://news.example.org');
    expect(form.initial!.cookiePolicy, CookiePolicy.keep);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(events, ['upsert t1', 'keep t1']);
    expect(_registry(tester), isEmpty);
  });

  // Saved, it is a site like any other: leaving it must not close — and so
  // wipe — the login just kept.
  testWidgets('a saved throwaway is not closed when left', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), sites: _RecordingSiteRepository(),
        throwaway: true, throwaways: [_throwaway()], overHome: true);
    await tester.pumpAndSettle();

    await tester.tap(_icon('Site details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ContainerRoute))).pop();
    await tester.pumpAndSettle();

    expect(engine.kept, ['t1']);
    expect(engine.closed, isEmpty);
  });

  testWidgets('saving with Wipe on exit picked keeps nothing', (tester) async {
    final events = <String>[];
    final engine = _LoggingEngine(events);
    final sites = _RecordingSiteRepository(events: events);
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    await tester.tap(_icon('Site details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wipe on exit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(events, ['upsert t1']);
    expect(sites.upserts.single.cookiePolicy, CookiePolicy.wipeOnExit);
  });

  testWidgets('the pill follows the page, falling back to the site when the page has no host', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    expect(find.text('forum.example.com'), findsOneWidget);
    // There is no DIRECT label; the route used to pass one.
    expect(find.text('DIRECT'), findsNothing);

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://elsewhere.example.net/a'));
    await tester.pumpAndSettle();
    expect(find.text('elsewhere.example.net'), findsOneWidget);

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'about:blank'));
    await tester.pumpAndSettle();
    expect(find.text('forum.example.com'), findsOneWidget);
  });

  testWidgets("back, forward and stop act on this container's page", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    await tester.tap(_icon('Back'), warnIfMissed: false);
    expect(engine.wentBack, isEmpty);
    expect(_icon('Stop'), findsNothing);

    engine.emitNavigation(const NavigationState(
      siteId: 's1', url: 'https://forum.example.com/t/9',
      canGoBack: true, canGoForward: true, loading: true, progress: 50,
    ));
    await tester.pumpAndSettle();
    await tester.tap(_icon('Back'));
    await tester.tap(_icon('Forward'));
    await tester.tap(_icon('Stop'));

    expect(engine.wentBack, ['s1']);
    expect(engine.wentForward, ['s1']);
    expect(engine.stopped, ['s1']);
  });

  testWidgets('system back goes back in the page first, then leaves the container', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true);
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 's1', url: 'https://forum.example.com/t/9', canGoBack: true));
    await tester.pumpAndSettle();

    await _systemBack(tester);
    expect(engine.wentBack, ['s1']);
    expect(find.byType(ContainerRoute), findsOneWidget);

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/'));
    await tester.pumpAndSettle();
    await _systemBack(tester);

    expect(find.byType(ContainerRoute), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
    // A saved site's session stays open in the background, as before.
    expect(engine.closed, isEmpty);
  });

  testWidgets("the menu's rows open their screens over this container, and All sites leaves it", (tester) async {
    sqfliteFfiInit();
    final database = (await tester.runAsync(
        () => AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)))!;
    addTearDown(() => tester.runAsync(database.close));
    _standInForPlatformViews(tester);
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true, overrides: [
      databaseProvider.overrideWithValue(database),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
    ]);
    await tester.pumpAndSettle();

    for (final (row, screen) in [
      ('Today', TodayRoute),
      ('Scripts and filters', ScriptsRoute),
      ('Workspaces', WorkspacesRoute),
      ('Settings', SettingsRoute),
    ]) {
      await tester.tap(_icon('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byType(screen), findsOneWidget, reason: row);

      Navigator.of(tester.element(find.byType(screen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ContainerRoute), findsOneWidget, reason: row);
    }

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All sites'));
    await tester.pumpAndSettle();

    expect(find.byType(ContainerRoute), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
  });

  testWidgets('Copy link copies the page address, and says so', (tester) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<Object?, Object?>)['text']);
      }
      return null;
    });
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/t/9'));
    await tester.pumpAndSettle();

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(copied, ['https://forum.example.com/t/9']);
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets("find in page searches this page, shows this page's count, and clears on close", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pump();
    expect(engine.findQueries, [(siteId: 's1', query: 'fox')]);

    engine.emitFindResult(const FindResult(siteId: 's1', activeMatch: 0, matchCount: 4));
    engine.emitFindResult(const FindResult(siteId: 'other', activeMatch: 0, matchCount: 9));
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);

    await tester.tap(_icon('Next match'));
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();

    expect(engine.findSteps, [(siteId: 's1', forward: true)]);
    expect(engine.clearedFind, ['s1']);
    expect(find.byType(FindBar), findsNothing);
  });

  testWidgets('a throwaway offers the save bar after its first finished load; saving writes the row, then keeps it', (tester) async {
    final events = <String>[];
    final engine = _LoggingEngine(events);
    final sites = _RecordingSiteRepository(events: events);
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: 'https://news.example.org/', loading: true, progress: 30));
    await tester.pumpAndSettle();
    expect(find.byType(ThrowawaySaveBar), findsNothing);

    engine.emitNavigation(const NavigationState(siteId: 't1', url: 'https://news.example.org/today'));
    await tester.pumpAndSettle();
    expect(find.text('Not saved · wiped when you close it'), findsOneWidget);

    await tester.tap(find.text('Save as a site'));
    await tester.pumpAndSettle();
    expect(tester.widget<AddSiteScreen>(find.byType(AddSiteScreen)).initial!.url,
        'https://news.example.org/today');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(events, ['upsert t1', 'keep t1']);
    expect(find.byType(ThrowawaySaveBar), findsNothing);
  });

  testWidgets('saving a throwaway that moved to another site names that site', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), sites: _RecordingSiteRepository(),
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: 'https://elsewhere.example.net/a', loading: true, progress: 30));
    engine.emitNavigation(const NavigationState(siteId: 't1', url: 'https://elsewhere.example.net/a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save as a site'));
    await tester.pumpAndSettle();

    final initial = tester.widget<AddSiteScreen>(find.byType(AddSiteScreen)).initial!;
    expect(initial.name, 'elsewhere.example.net');
    expect(initial.monogram, suggestMonogram('elsewhere.example.net'));
    expect(initial.url, 'https://elsewhere.example.net/a');
  });

  testWidgets('a saved site never shows the save bar', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/'));
    await tester.pumpAndSettle();

    expect(find.byType(ThrowawaySaveBar), findsNothing);
  });

  testWidgets('dismissing the save bar hides it for this throwaway', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(siteId: 't1', url: 'https://news.example.org/'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-bar-dismiss')));
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(siteId: 't1', url: 'https://news.example.org/next'));
    await tester.pumpAndSettle();

    expect(find.byType(ThrowawaySaveBar), findsNothing);
  });

  // Review Focus 5.
  testWidgets('at 360 wide a throwaway with a long host, a route, a load and the save bar fits, and so do its menu and find bar', (tester) async {
    const url = 'https://a-rather-long-subdomain-for-a-phone.news.example.org';
    final engine = FakeContainerEngine();
    final site = _throwaway().copyWith(
      url: url, proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
    );
    await _pump(tester, engine, site, throwaway: true, throwaways: [site]);
    await tester.pumpAndSettle();
    // Phone width once live: this is about the container's chrome. `8a`'s
    // checklist, shown for the first frames, is outside this plan.
    tester.view.physicalSize = const Size(360, 740);
    await tester.pump();
    engine.emitNavigation(const NavigationState(siteId: 't1', url: '$url/'));
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: '$url/today', loading: true, progress: 40));
    await tester.pumpAndSettle();

    expect(find.byType(ThrowawaySaveBar), findsOneWidget);
    expect(_icon('Stop'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Review Focus 1: rebuilding the page view disposes the native WebView,
  // which wipes a throwaway.
  testWidgets('the page view outlives every change of chrome', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();
    final page = tester.state(find.byType(PlatformViewLink));

    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: 'https://news.example.org/', loading: true, progress: 20));
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: 'https://news.example.org/', canGoBack: true));
    await tester.pumpAndSettle();
    expect(find.byType(ThrowawaySaveBar), findsOneWidget);
    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-bar-dismiss')));
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(PlatformViewLink)), same(page));
    expect(engine.closed, isEmpty);
  });

  testWidgets("an address on this container's own host loads here, in place", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'forum.example.com/latest');
    expect(find.text('THIS CONTAINER'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(engine.loaded, [(siteId: 's1', url: 'https://forum.example.com/latest')]);
    expect(engine.openedSites.keys, ['s1']);
    expect(find.byType(AddressSuggestions), findsNothing);
  });

  testWidgets("a saved site's address opens its own container over this one, at that address", (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _site(), sites: sites, saved: [_site(), _market], overHome: true);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'market.example.com/deals');
    expect(find.text('ITS OWN CONTAINER'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(engine.openedSites['m1']!.url, 'https://market.example.com');
    expect(engine.openedInitialUrls['m1'], 'https://market.example.com/deals');
    expect(engine.openedAsThrowaway, isEmpty);
    // Marked open and visited, as the dashboard opens a site; its stored
    // address is untouched.
    expect(sites.touched, ['m1']);
    expect(sites.upserts, isEmpty);
    expect(ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(openSiteIdsProvider), contains('m1'));

    await _systemBack(tester);
    expect(find.text('forum.example.com'), findsOneWidget);
    // Left, a saved site's session stays open in the background.
    expect(engine.closed, isEmpty);
  });

  // User's ruling, 2026-10-02: one container per site. A second one would
  // take over the native session and leave the lower one acting on nothing.
  testWidgets("a saved site's address returns to its container lower in the stack, at that address", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(),
        sites: _RecordingSiteRepository(), saved: [_site(), _market], overHome: true);
    await tester.pumpAndSettle();
    await _typeAddress(tester, 'market.example.com/deals');
    expect(find.text('ITS OWN CONTAINER'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    expect(find.byType(ContainerRoute, skipOffstage: false), findsNWidgets(2));

    await _typeAddress(tester, 'forum.example.com/new', pill: 'market.example.com');
    expect(find.text('ITS OWN CONTAINER'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    // Back on the first container, which loads the address in place.
    expect(find.byType(ContainerRoute, skipOffstage: false), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(engine.loaded, [(siteId: 's1', url: 'https://forum.example.com/new')]);
    expect(engine.openedInitialUrls['s1'], isNull);
    // The container left on the way down is a saved site: its session stays open.
    expect(engine.closed, isEmpty);

    await _systemBack(tester);
    expect(find.text(_homeMarker), findsOneWidget);
  });

  // The address bar's list of saved sites is a copy that can be out of date:
  // a removed site went on being suggested, and opening it brought it back.
  testWidgets("a saved site removed since the address bar read the vault opens a throwaway, not its container",
      (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository()..stored = [_site()];
    await _pump(tester, engine, _site(), sites: sites, saved: [_site(), _market], overHome: true);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'market.example.com/deals');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(engine.openedSites.containsKey('m1'), isFalse);
    expect(sites.touched, isEmpty);
    final id = engine.openedAsThrowaway.single;
    expect(engine.openedSites[id]!.url, 'https://market.example.com/deals');
  });

  // Opening it from the stale copy used its old route, and the profile a
  // wipe had already rotated away from.
  testWidgets("a saved site opens as the vault holds it now, not as the address bar's copy had it",
      (tester) async {
    final engine = FakeContainerEngine();
    final now = _market.copyWith(
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      profileId: 'cccccccccccccccccccccccccccccccc',
    );
    final sites = _RecordingSiteRepository()..stored = [_site(), now];
    await _pump(tester, engine, _site(), sites: sites, saved: [_site(), _market], overHome: true);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'market.example.com/deals');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    final opened = engine.openedSites['m1']!;
    expect((opened.proxyMode, opened.proxyHost, opened.proxyPort),
        (ProxyMode.socks5, '127.0.0.1', 9050));
    expect(opened.profileId, 'cccccccccccccccccccccccccccccccc');
  });

  testWidgets("anything else opens a throwaway on this container's route; leaving it closes and forgets it", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _socksSite(), overHome: true);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'news.example.org/today');
    // The address row and the search row both open a throwaway on SOCKS5.
    expect(find.text('THROWAWAY · SOCKS5'), findsNWidgets(2));
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    final id = engine.openedAsThrowaway.single;
    final opened = engine.openedSites[id]!;
    expect(opened.url, 'https://news.example.org/today');
    expect((opened.proxyMode, opened.proxyHost, opened.proxyPort),
        (ProxyMode.socks5, '127.0.0.1', 9050));
    expect(opened.cookiePolicy, CookiePolicy.wipeOnExit);
    expect(_registry(tester).map((site) => site.id), [id]);

    await _systemBack(tester);

    // Its route closed its session, which wipes it natively.
    expect(engine.closed, [id]);
    expect(_registry(tester), isEmpty);
    expect(find.byType(ContainerRoute), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
  });

  testWidgets('suggestions come from this vault only, and name the chosen engine', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(),
        saved: [_site(), _market], searchEngine: SearchEngine.startpage);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'market');

    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('market.example.com · Personal'), findsOneWidget);
    expect(find.text('Search Startpage for “market”'), findsOneWidget);
    expect(find.text('Nothing is fetched while you type.'), findsOneWidget);
  });

  // Review Focus 2.
  testWidgets('back while typing leaves editing, and neither goes back nor leaves', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true);
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 's1', url: 'https://forum.example.com/t/9', canGoBack: true));
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'news');
    await _systemBack(tester);

    expect(find.byType(AddressSuggestions), findsNothing);
    expect(engine.wentBack, isEmpty);
    expect(engine.loaded, isEmpty);
    expect(find.byType(ContainerRoute), findsOneWidget);
  });

  // A saved site keeps its row through a close-and-wipe, under a new profile:
  // reopened under the old one, the rest of the wipe waiting in the
  // pending-deletion journal would be called off. See `wipeSavedSite`.
  group('close and wipe gives a saved site a fresh profile', () {
    void expectRotated(FakeContainerEngine engine, _RecordingSiteRepository sites) {
      expect(engine.wiped, contains('a' * 32));
      expect(sites.upserts.last.id, 's1');
      expect(sites.upserts.last.profileId, isNot('a' * 32));
    }

    testWidgets("from the site sheet (6c)", (tester) async {
      final engine = FakeContainerEngine();
      final sites = _RecordingSiteRepository();
      await _pump(tester, engine, _site(), sites: sites);
      await tester.pumpAndSettle();

      await tester.tap(_icon('Site details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close and wipe this session'));
      await tester.pumpAndSettle();

      expectRotated(engine, sites);
    });

    testWidgets('from the switcher (2c)', (tester) async {
      final engine = FakeContainerEngine();
      final sites = _RecordingSiteRepository();
      await _pump(tester, engine, _site(), sites: sites, overHome: true);
      await tester.pumpAndSettle();

      await tester.tap(find.text('1 OPEN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close all and wipe'));
      await tester.pumpAndSettle();

      expectRotated(engine, sites);
    });

    testWidgets('from the tunnel-dropped screen (8c)', (tester) async {
      final engine = FakeContainerEngine();
      final sites = _RecordingSiteRepository();
      await _pump(tester, engine, _site(), sites: sites, overHome: true);
      await tester.pumpAndSettle();
      engine.emitTunnelDropped(TunnelDroppedEvent(
        siteId: 's1', host: 'forum.example.com', droppedAt: DateTime(2026, 9, 30),
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Close and wipe'));
      await tester.pumpAndSettle();

      expectRotated(engine, sites);
    });

    // A throwaway has no row: its profile is journaled from before it exists
    // and wiped with it.
    testWidgets('but never writes a throwaway into the vault', (tester) async {
      final engine = FakeContainerEngine();
      final sites = _RecordingSiteRepository();
      await _pump(tester, engine, _throwaway(), sites: sites, throwaway: true, throwaways: [_throwaway()]);
      await tester.pumpAndSettle();

      await tester.tap(_icon('Site details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close and wipe this session'));
      await tester.pumpAndSettle();

      expect(engine.wiped, contains('c' * 32));
      expect(sites.upserts, isEmpty);
    });
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

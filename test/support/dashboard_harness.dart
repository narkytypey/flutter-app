import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/container/view_models/open_containers.dart';
import 'package:container/ui/features/container/view_models/providers.dart'
    show containerEngineProvider, engineExtrasBuilderProvider;
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart'
    show siteLookupProvider;
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:container/ui/features/dashboard/views/dashboard_tab_bar.dart';
import 'package:container/ui/features/settings/view_models/providers.dart'
    show autoLockProvider, settingsRepositoryProvider;
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show Session, SessionController, SessionUnconfigured, biometricServiceProvider, sessionProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/features/shell/session_controller_test.dart' show FakeBiometricService;

const personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep, sortIndex: 0);
const work =
    Workspace(id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep, sortIndex: 1);

/// The registry watches the session only to empty itself on leaving
/// `SessionOpen`, which these tests never do.
class _Session extends SessionController {
  @override
  Session build() => const SessionUnconfigured();
}

/// The open vault's sites, in memory. A write changes what the next read
/// returns, as the vault would.
class FakeSites implements SiteRepository {
  FakeSites(List<Site> rows) : rows = [...rows];

  final List<Site> rows;
  final upserts = <Site>[];

  @override
  Future<List<Site>> all() async => [...rows];
  @override
  Future<List<Site>> inWorkspace(String workspaceId) async =>
      rows.where((s) => s.workspaceId == workspaceId).toList();
  @override
  Future<Site?> byId(String id) async => rows.where((s) => s.id == id).firstOrNull;
  @override
  Future<void> upsert(Site site) async {
    upserts.add(site);
    rows.removeWhere((s) => s.id == site.id);
    rows.add(site);
  }

  @override
  Future<void> delete(String id) async => rows.removeWhere((s) => s.id == id);
  @override
  Future<void> touch(String id, DateTime at) async {
    final i = rows.indexWhere((s) => s.id == id);
    if (i >= 0) rows[i] = rows[i].copyWith(lastVisitedAt: at);
  }

  @override
  Future<DateTime?> lastWorked(String id) async => null;
  @override
  Future<void> setLastWorked(String id, DateTime? at) async {}
}

/// The open vault's `app_settings`, in memory.
class FakeSettings implements SettingsRepository {
  FakeSettings(Map<String, String> values) : values = {...values};

  final Map<String, String> values;

  @override
  Future<bool> getBool(String key, {bool fallback = false}) async =>
      values.containsKey(key) ? values[key] == 'true' : fallback;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = '$value';
  @override
  Future<String?> getString(String key, {String? fallback}) async => values[key] ?? fallback;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

class DashboardHarness {
  DashboardHarness(this.container, this.engine, this.sites, this.settings);

  final ProviderContainer container;
  final FakeContainerEngine engine;
  final FakeSites sites;
  final FakeSettings settings;

  OpenContainersState get tabs => container.read(openContainersProvider);
  OpenContainers get registry => container.read(openContainersProvider.notifier);
}

/// The real [DashboardScreen], every tab included, over in-memory fakes: no
/// database, no platform. A container shown from it creates a platform view,
/// which is answered here.
Future<DashboardHarness> pumpDashboard(
  WidgetTester tester, {
  List<Workspace> workspaces = const [personal, work],
  List<Site> sites = const [],
  Map<String, String> settings = const {},
  List<Override> overrides = const [],
}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  const platformViews = MethodChannel('flutter/platform_views');
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(platformViews, (call) async => null);
  addTearDown(() =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(platformViews, null));

  final engine = FakeContainerEngine();
  final fakeSites = FakeSites(sites);
  final fakeSettings = FakeSettings(settings);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
      sessionProvider.overrideWith(_Session.new),
      siteRepositoryProvider.overrideWithValue(fakeSites),
      workspacesProvider.overrideWith((ref) async => workspaces),
      settingsRepositoryProvider.overrideWithValue(fakeSettings),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      autoLockProvider.overrideWith((ref) async => AutoLockPolicy.oneMinute),
      siteLookupProvider.overrideWithValue((_) async => null),
      ...overrides,
    ],
    child: const MaterialApp(home: DashboardScreen()),
  ));
  await tester.pumpAndSettle();
  return DashboardHarness(
    ProviderScope.containerOf(tester.element(find.byType(DashboardScreen))),
    engine,
    fakeSites,
    fakeSettings,
  );
}

/// Taps the tab labelled [label] in the dashboard's tab bar.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(DashboardTabBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// What the platform sends for a system back gesture.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

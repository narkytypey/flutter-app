import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/app.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show dashboardProvider, workspacesProvider;
import 'package:container/ui/features/search/view_models/providers.dart'
    show allSitesProvider;
import 'package:container/ui/features/settings/view_models/providers.dart'
    show defaultRouteProvider, searchEngineProvider;
import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:container/ui/features/lock/views/lock_screen.dart';
import 'package:container/ui/features/panic/views/panic_screen.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:container/ui/features/shell/views/app_gate.dart';

import 'session_controller_test.dart' show FakeBiometricService;

const _pushed = 'A SCREEN PUSHED OVER THE DASHBOARD';

void main() {
  setUpAll(sqfliteFfiInit);

  /// The real shell — `ContainerApp(home: AppGate())`, exactly as `main()`
  /// builds it — with a vault open, sitting on the dashboard.
  Future<ProviderContainer> openVault(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = (await tester.runAsync(
      () => AppDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      ),
    ))!;
    addTearDown(() => tester.runAsync(database.close));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialSessionProvider.overrideWithValue(
            SessionOpen(
              vault: VaultId.a,
              database: database,
              dataKey: Uint8List(32),
            ),
          ),
          biometricServiceProvider.overrideWithValue(FakeBiometricService()),
          // Never resolves: the dashboard stays on its loading surface, which
          // is all these tests need from it.
          dashboardProvider.overrideWith(
            (ref) => Completer<DashboardView>().future,
          ),
          // The Sites tab also reads these; answered at once, they start no
          // database work (and no timer) of their own.
          workspacesProvider.overrideWith((ref) async => const <Workspace>[]),
          allSitesProvider.overrideWith((ref) async => const <Site>[]),
          searchEngineProvider.overrideWith(
            (ref) async => SearchEngine.duckDuckGo,
          ),
          defaultRouteProvider.overrideWith((ref) async => ProxyRoute.direct),
        ],
        child: const ContainerApp(home: AppGate()),
      ),
    );

    return ProviderScope.containerOf(
      tester.element(find.byType(AppGate, skipOffstage: false)),
    );
  }

  /// Pushes the way the dashboard itself does — `Navigator.push(context, …)`
  /// from the dashboard's own context — onto whichever navigator that
  /// context actually reaches.
  Future<void> pushFromDashboard(WidgetTester tester) async {
    Navigator.of(tester.element(find.byType(DashboardScreen))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text(_pushed)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_pushed), findsOneWidget);
  }

  testWidgets(
    'returning within the grace period — the 9b lock — covers a pushed screen',
    (tester) async {
      final container = await openVault(tester);
      await pushFromDashboard(tester);

      container
          .read(sessionProvider.notifier)
          .debugHandleReturn(ReturnDestination.board);
      await tester.pumpAndSettle();

      expect(find.text(_pushed, skipOffstage: false), findsNothing);
      expect(find.byType(LockScreen), findsOneWidget);
    },
  );

  testWidgets(
    'returning past the timer — the 9c lock — covers a pushed screen',
    (tester) async {
      final container = await openVault(tester);
      await pushFromDashboard(tester);

      container
          .read(sessionProvider.notifier)
          .debugHandleReturn(ReturnDestination.pin);
      await tester.pumpAndSettle();

      expect(find.text(_pushed, skipOffstage: false), findsNothing);
      expect(find.byType(LockScreen), findsOneWidget);
    },
  );

  testWidgets('panic covers a pushed screen with its report', (tester) async {
    final container = await openVault(tester);
    await pushFromDashboard(tester);

    container
        .read(sessionProvider.notifier)
        .panicked(const PanicReport(sessionsDestroyed: 1));
    await tester.pumpAndSettle();

    expect(find.text(_pushed, skipOffstage: false), findsNothing);
    expect(find.byType(PanicScreen), findsOneWidget);
  });

  testWidgets(
    'a snackbar raised while open does not survive onto the lock screen',
    (tester) async {
      final container = await openVault(tester);
      // The real string a decoy-coercion scenario can least afford to leak.
      ScaffoldMessenger.of(tester.element(find.byType(DashboardScreen)))
          .showSnackBar(const SnackBar(content: Text('Decoy vault synced')));
      await tester.pumpAndSettle();
      expect(find.text('Decoy vault synced'), findsOneWidget);

      container
          .read(sessionProvider.notifier)
          .debugHandleReturn(ReturnDestination.board);
      await tester.pumpAndSettle();

      expect(
        find.text('Decoy vault synced', skipOffstage: false),
        findsNothing,
      );
      expect(find.byType(LockScreen), findsOneWidget);
    },
  );

  testWidgets('Android back still pops a pushed screen back to the dashboard', (
    tester,
  ) async {
    await openVault(tester);
    await pushFromDashboard(tester);

    // What the platform sends for a system back gesture.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pumpAndSettle();

    expect(find.text(_pushed), findsNothing);
    expect(find.byType(DashboardScreen), findsOneWidget);
  });
}

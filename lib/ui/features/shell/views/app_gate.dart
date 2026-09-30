import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/views/dashboard_screen.dart';
import '../../lock/views/lock_screen.dart';
import '../../panic/views/panic_screen.dart';
import '../view_models/session_controller.dart';
import 'flip_panic_guard.dart';
import 'setup_flow.dart';

/// Decides what the app shows: setup on a fresh device, the lock screen when
/// locked, the dashboard when open.
///
/// The dashboard is never constructed while locked. Building it behind an
/// opacity or an overlay would leave a rendered board one screenshot away, and
/// the whole point of `9a` is that there is nothing to capture.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return switch (session) {
      SessionUnconfigured() => const SetupFlow(),
      SessionLocked() => const LockScreen(),
      // Keyed by the connection, not by which vault it is: a new connection
      // gets a fresh subtree, and nothing here asks which vault that is.
      SessionOpen(:final database) => _OpenVault(key: ObjectKey(database)),
      SessionPanicked(:final report) => PanicScreen(
        report: report,
        onUnlock: () => ref.read(sessionProvider.notifier).dismissPanicReport(),
      ),
    };
  }
}

/// Everything an open vault puts on screen lives in here: the dashboard, and
/// every container, sheet, screen and snackbar opened from it.
///
/// `AppGate` is `MaterialApp.home`, so without this subtree the dashboard's
/// pushes land on the app's root navigator, *above* `AppGate` rather than
/// inside it. Swapping `AppGate` to `LockScreen` or `PanicScreen` then only
/// replaces the bottom route, and a pushed container stays on top — live,
/// with no PIN asked. The root `ScaffoldMessenger` has the same problem: a
/// queued snackbar would carry over onto the lock screen. Giving the open
/// vault its own [Navigator] and [ScaffoldMessenger] makes leaving
/// `SessionOpen` tear all of it down, for every reason it can happen, with
/// no listener that has to remember to pop anything.
///
/// The cost is `9b`'s: a return within the grace period still shows the
/// lock screen, but the containers open behind it are closed, and unlocking
/// lands on the dashboard rather than back inside a site.
class _OpenVault extends StatefulWidget {
  const _OpenVault({super.key});

  @override
  State<_OpenVault> createState() => _OpenVaultState();
}

class _OpenVaultState extends State<_OpenVault> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // While this vault is open and its switch is on, a flip panics.
    return FlipPanicGuard(
      child: ScaffoldMessenger(
        // Android back reaches the root navigator, which holds only AppGate.
        // Hand it to this one whenever it has something of its own to pop; at
        // the dashboard, back falls through and backgrounds the app as before.
        child: NavigatorPopHandler<Object?>(
          onPopWithResult: (_) => _navigator.currentState?.maybePop(),
          child: Navigator(
            key: _navigator,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const DashboardScreen(),
            ),
          ),
        ),
      ),
    );
  }
}

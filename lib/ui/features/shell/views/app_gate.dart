import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/views/dashboard_screen.dart';
import '../../lock/views/lock_screen.dart';
import '../../panic/views/panic_screen.dart';
import '../view_models/session_controller.dart';
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
      SessionOpen() => const DashboardScreen(),
      SessionPanicked(:final report) => PanicScreen(
          report: report,
          onUnlock: () => ref.read(sessionProvider.notifier).dismissPanicReport(),
        ),
    };
  }
}

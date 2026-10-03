import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/view_models/blocked_tally_controller.dart';
import 'today_screen.dart';

/// [TodayScreen] fed from the live tally, so it keeps counting while open.
/// Pushed from ☰ with a back icon. The dashboard's tab has none ([showBack]
/// false, dashboard spec §4.1).
class TodayRoute extends ConsumerWidget {
  const TodayRoute({super.key, this.showBack = true});

  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TodayScreen(
      tally: ref.watch(blockedTallyProvider),
      onBack: showBack ? () => Navigator.pop(context) : null,
    );
  }
}

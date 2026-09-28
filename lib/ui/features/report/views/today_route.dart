import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/view_models/blocked_tally_controller.dart';
import 'today_screen.dart';

/// [TodayScreen] fed from the live tally, so it keeps counting while open.
class TodayRoute extends ConsumerWidget {
  const TodayRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TodayScreen(
      tally: ref.watch(blockedTallyProvider),
      onBack: () => Navigator.pop(context),
    );
  }
}

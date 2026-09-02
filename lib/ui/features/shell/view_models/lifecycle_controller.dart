import 'package:flutter/widgets.dart';

import '../../../../domain/models/lock_state.dart';

/// Watches focus and reports where the user is coming back from.
///
/// Two mechanisms, deliberately not one: masking happens the instant focus is
/// lost, and the timer only chooses which of the two locked destinations
/// (`9b` or `9c`) the user lands on. Wiring the mask to the timer would leave
/// the board visible in recents for the length of the grace period, which is
/// the exact failure turn 9 calls out — and skipping the lock screen entirely
/// on a quick return would defeat the point of masking it in the first place.
class LifecycleController with WidgetsBindingObserver {
  LifecycleController({
    required this.policy,
    required this.onMaskChanged,
    required this.onReturn,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AutoLockPolicy policy;
  final ValueChanged<bool> onMaskChanged;
  final ValueChanged<ReturnDestination> onReturn;
  final DateTime Function() _clock;

  DateTime? _leftAt;

  void start() => WidgetsBinding.instance.addObserver(this);
  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_leftAt == null) {
          _leftAt = _clock();
          onMaskChanged(true);
        }
      case AppLifecycleState.resumed:
        final left = _leftAt;
        _leftAt = null;
        onMaskChanged(false);
        if (left != null) {
          onReturn(policy.destinationFor(_clock().difference(left)));
        }
      case AppLifecycleState.detached:
        break;
    }
  }
}

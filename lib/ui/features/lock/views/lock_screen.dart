import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/view_models/session_controller.dart';
import '../view_models/lock_controller.dart';
import 'lock_body.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  late final LockController _pin;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _pin = LockController(onSubmit: _submit)..addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _pin
      ..removeListener(_onPinChanged)
      ..dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _onPinChanged() => setState(() {});

  Future<void> _submit(String pin) =>
      ref.read(sessionProvider.notifier).unlock(pin);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session is! SessionLocked) {
      // AppGate only ever mounts LockScreen while locked.
      return const SizedBox.shrink();
    }

    _syncTicker(session);

    final deadline = session.lockDeadline;
    final secondsUntilLock =
        deadline == null ? 0 : max(0, deadline.difference(DateTime.now()).inSeconds);

    return LockBody(
      mood: session.mood,
      filled: _pin.value.filled,
      triesLeft: session.gate.triesLeft,
      openSessions: session.openSessionCount,
      secondsUntilLock: secondsUntilLock,
      onKey: _pin.onKey,
      // Known gap (see this plan's "Known gaps"): biometric unlock is not
      // wired to a Keystore-gated key yet, so there is nothing safe for
      // this to do.
      onBiometric: () {},
    );
  }

  void _syncTicker(SessionLocked session) {
    final shouldTick =
        session.mood == LockMood.welcomeBack && session.lockDeadline != null;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (session.lockDeadline!.isBefore(DateTime.now())) {
          ref.read(sessionProvider.notifier).graceExpired();
        } else {
          setState(() {});
        }
      });
    } else if (!shouldTick && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }
}

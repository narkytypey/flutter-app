import 'dart:async';

import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/services/flip_service.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/features/container/view_models/providers.dart'
    show panicServiceProvider;
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/settings/view_models/providers.dart'
    show panicOnFlipProvider;
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:container/ui/features/shell/views/flip_panic_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFlips implements FlipService {
  final calls = <String>[];
  final _flips = StreamController<void>.broadcast();

  void flip() => _flips.add(null);

  @override
  Stream<void> get flips => _flips.stream;

  @override
  Future<bool> start() async {
    calls.add('start');
    return true;
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

class _FakePanic implements PanicService {
  var triggered = 0;

  @override
  Future<PanicReport> trigger() async {
    triggered++;
    return const PanicReport(sessionsDestroyed: 0);
  }
}

/// Settings' "Trigger by flipping face down" (user's ruling, 2026-09-30):
/// while a vault is open and the switch is on, a flip runs the same panic as
/// the button.
void main() {
  late _FakeFlips flips;
  late _FakePanic panic;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {required bool on}) async {
    flips = _FakeFlips();
    panic = _FakePanic();
    container = ProviderContainer(overrides: [
      flipServiceProvider.overrideWithValue(flips),
      panicServiceProvider.overrideWithValue(panic),
      panicOnFlipProvider.overrideWith((ref) async => on),
      initialSessionProvider.overrideWithValue(
          const SessionLocked(mood: LockMood.normal, gate: AttemptGate())),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: FlipPanicGuard(child: Text('vault'))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('on: listens, and a flip panics', (tester) async {
    await pump(tester, on: true);
    expect(flips.calls, ['start']);

    flips.flip();
    await tester.pumpAndSettle();

    expect(panic.triggered, 1);
    expect(container.read(sessionProvider), isA<SessionPanicked>());
  });

  testWidgets('off: never listens, and nothing panics', (tester) async {
    await pump(tester, on: false);
    flips.flip();
    await tester.pumpAndSettle();

    expect(flips.calls, isNot(contains('start')));
    expect(panic.triggered, 0);
  });

  testWidgets('leaving the open vault stops listening', (tester) async {
    await pump(tester, on: true);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Text('locked')),
    ));
    await tester.pumpAndSettle();

    expect(flips.calls, ['start', 'stop']);
  });
}

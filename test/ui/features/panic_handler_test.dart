import 'dart:async';

import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/features/container/view_models/providers.dart'
    show panic, panicServiceProvider;
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SlowPanic implements PanicService {
  final done = Completer<PanicReport>();

  @override
  Future<PanicReport> trigger() => done.future;
}

class _PanicButton extends ConsumerWidget {
  const _PanicButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TextButton(onPressed: () => panic(ref), child: const Text('Panic'));
}

void main() {
  // Panic closes every container, and closing the viewed one disposes the
  // container route whose button started it. On a device that left the app
  // on the dashboard's "database_closed" error, never reaching 3c.
  testWidgets('panic reaches 3c after the widget that started it is gone',
      (tester) async {
    final service = _SlowPanic();
    final container = ProviderContainer(overrides: [
      panicServiceProvider.overrideWithValue(service),
      initialSessionProvider.overrideWithValue(
          const SessionLocked(mood: LockMood.normal, gate: AttemptGate())),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: _PanicButton()),
    ));

    await tester.tap(find.text('Panic'));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Text('closed')),
    ));
    service.done.complete(const PanicReport(sessionsDestroyed: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(container.read(sessionProvider), isA<SessionPanicked>());
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';

void main() {
  final t0 = DateTime(2026, 8, 30, 9, 10);

  test('a fresh gate allows five tries and is not locked', () {
    const gate = AttemptGate();
    expect(gate.triesLeft, 5);
    expect(gate.lockedAt(t0), isFalse);
  });

  test('each failure spends one try', () {
    var gate = const AttemptGate();
    gate = gate.recordFailure(t0);
    expect(gate.triesLeft, 4);
    gate = gate.recordFailure(t0);
    expect(gate.triesLeft, 3);
  });

  test('the fifth failure locks for thirty seconds', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }

    expect(gate.triesLeft, 0);
    expect(gate.lockedAt(t0), isTrue);
    expect(gate.remainingAt(t0), const Duration(seconds: 30));
    expect(gate.lockedAt(t0.add(const Duration(seconds: 29))), isTrue);
    expect(gate.lockedAt(t0.add(const Duration(seconds: 30))), isFalse);
  });

  test('the penalty repeats for every further failure', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }
    final later = t0.add(const Duration(seconds: 31));
    gate = gate.recordFailure(later);

    expect(gate.lockedAt(later), isTrue);
    expect(gate.remainingAt(later), const Duration(seconds: 30));
  });

  test('a success clears everything', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }

    gate = gate.reset();
    expect(gate.triesLeft, 5);
    expect(gate.lockedAt(t0), isFalse);
  });

  test('a clock that moves backwards does not shorten the penalty', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }

    expect(gate.lockedAt(t0.subtract(const Duration(hours: 2))), isTrue);
  });
}

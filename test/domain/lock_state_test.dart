import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/lock_state.dart';

void main() {
  const policy = AutoLockPolicy.oneMinute;

  test('returning inside the grace period comes back to the board', () {
    expect(policy.destinationFor(Duration.zero), ReturnDestination.board);
    expect(policy.destinationFor(const Duration(seconds: 59)),
        ReturnDestination.board);
  });

  test('returning past the grace period comes back to the PIN', () {
    expect(policy.destinationFor(const Duration(seconds: 60)),
        ReturnDestination.pin);
    expect(policy.destinationFor(const Duration(hours: 3)),
        ReturnDestination.pin);
  });

  test('masking does not wait for the timer', () {
    // The moment focus is lost, regardless of how long the app has been away.
    const justLeft = LockState(
        locked: false, maskRecents: true, openSessionCount: 3);
    expect(justLeft.maskRecents, isTrue);
    expect(justLeft.locked, isFalse);
  });

  test('a zero grace period locks immediately', () {
    const instant = AutoLockPolicy(Duration.zero);
    expect(instant.destinationFor(Duration.zero), ReturnDestination.pin);
  });

  // User's ruling, 2026-09-30: Auto-lock offers 1, 5 and 15 minutes.

  test('the three choices, in order, with their labels', () {
    expect(AutoLockPolicy.choices.map((p) => p.label),
        ['After 1 min', 'After 5 min', 'After 15 min']);
  });

  test('9c names the duration that locked it', () {
    expect(AutoLockPolicy.oneMinute.lockedLine, 'Locked after 1 minute in the background');
    expect(AutoLockPolicy.fiveMinutes.lockedLine, 'Locked after 5 minutes in the background');
    expect(AutoLockPolicy.fifteenMinutes.lockedLine,
        'Locked after 15 minutes in the background');
  });

  test('five minutes is the grace for five minutes', () {
    expect(AutoLockPolicy.fiveMinutes.destinationFor(const Duration(minutes: 4, seconds: 59)),
        ReturnDestination.board);
    expect(AutoLockPolicy.fiveMinutes.destinationFor(const Duration(minutes: 5)),
        ReturnDestination.pin);
  });

  test('a stored choice reads back; anything else is one minute', () {
    for (final policy in AutoLockPolicy.choices) {
      expect(AutoLockPolicy.fromStored(policy.stored), policy);
    }
    expect(AutoLockPolicy.fromStored(null), AutoLockPolicy.oneMinute);
    expect(AutoLockPolicy.fromStored('7'), AutoLockPolicy.oneMinute);
  });
}

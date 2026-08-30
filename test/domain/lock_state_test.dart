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
}

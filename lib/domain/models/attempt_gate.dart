/// Counts wrong PINs and imposes the delay `4c` promises: "After 5 wrong tries
/// the app waits 30 seconds before accepting another."
///
/// This gate knows nothing about which PIN was entered or which vault it might
/// belong to. It counts failures to unwrap, and a failure to unwrap is
/// indistinguishable from a PIN for a vault that does not exist — which is the
/// property the decoy depends on.
class AttemptGate {
  const AttemptGate({this.failures = 0, this.lockedUntil});

  final int failures;
  final DateTime? lockedUntil;

  static const maxTries = 5;
  static const penalty = Duration(seconds: 30);

  /// None left once [maxTries] is reached: from then on [recordFailure]
  /// re-locks on every failure, so there is no budget to count down again.
  int get triesLeft => failures >= maxTries ? 0 : maxTries - failures;

  bool lockedAt(DateTime now) {
    final until = lockedUntil;
    return until != null && now.isBefore(until);
  }

  Duration remainingAt(DateTime now) {
    final until = lockedUntil;
    if (until == null || !now.isBefore(until)) return Duration.zero;
    return until.difference(now);
  }

  AttemptGate recordFailure(DateTime now) {
    final total = failures + 1;
    final locking = total >= maxTries;
    return AttemptGate(
      failures: total,
      lockedUntil: locking ? now.add(penalty) : lockedUntil,
    );
  }

  AttemptGate reset() => const AttemptGate();
}

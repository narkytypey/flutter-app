/// Where the user lands when they come back to the app.
enum ReturnDestination { board, pin }

/// How long the app may sit in the background before the PIN is required
/// again. Default is "After 1 min" (spec `2d`).
///
/// This policy decides the destination and nothing else. It does not decide
/// whether the app is masked in recents — that happens the instant focus is
/// lost, independently of any timer (spec turn 9).
class AutoLockPolicy {
  const AutoLockPolicy(this.grace);

  final Duration grace;

  static const oneMinute = AutoLockPolicy(Duration(minutes: 1));

  ReturnDestination destinationFor(Duration away) =>
      away < grace ? ReturnDestination.board : ReturnDestination.pin;
}

class LockState {
  const LockState({
    required this.locked,
    required this.maskRecents,
    required this.openSessionCount,
    this.secondsUntilLock,
  });

  final bool locked;

  /// True from the moment focus is lost until it is regained.
  final bool maskRecents;

  /// Drives `9b`'s "3 sessions still open · locks in 40s".
  final int openSessionCount;
  final int? secondsUntilLock;
}

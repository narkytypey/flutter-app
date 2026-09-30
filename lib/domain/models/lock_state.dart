/// Where the user lands when they come back to the app.
enum ReturnDestination { board, pin }

/// How long the app may sit in the background before the PIN is required
/// again. Default is "After 1 min" (spec `2d`); the user's ruling of
/// 2026-09-30 adds 5 and 15 minutes ([choices]), chosen per vault.
///
/// This policy decides the destination and nothing else. It does not decide
/// whether the app is masked in recents — that happens the instant focus is
/// lost, independently of any timer (spec turn 9).
class AutoLockPolicy {
  const AutoLockPolicy(this.grace);

  final Duration grace;

  static const oneMinute = AutoLockPolicy(Duration(minutes: 1));
  static const fiveMinutes = AutoLockPolicy(Duration(minutes: 5));
  static const fifteenMinutes = AutoLockPolicy(Duration(minutes: 15));

  /// What the Auto-lock picker offers, in order.
  static const choices = [oneMinute, fiveMinutes, fifteenMinutes];

  /// The picker's and `2d`'s wording: `After 1 min`.
  String get label => 'After ${grace.inMinutes} min';

  /// `9c`'s line: `Locked after 1 minute in the background`, `5 minutes`.
  String get lockedLine {
    final minutes = grace.inMinutes;
    return 'Locked after $minutes ${minutes == 1 ? 'minute' : 'minutes'} in the background';
  }

  /// The vault's `auto_lock` setting: whole minutes.
  String get stored => '${grace.inMinutes}';

  /// Reads the `auto_lock` setting. Anything but a [choices] value, including
  /// no setting at all, is the default.
  static AutoLockPolicy fromStored(String? value) =>
      choices.firstWhere((policy) => policy.stored == value, orElse: () => oneMinute);

  ReturnDestination destinationFor(Duration away) =>
      away < grace ? ReturnDestination.board : ReturnDestination.pin;

  @override
  bool operator ==(Object other) => other is AutoLockPolicy && other.grace == grace;

  @override
  int get hashCode => grace.hashCode;
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

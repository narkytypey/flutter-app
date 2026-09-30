/// The accelerometer's "face down for two seconds" signal, for Settings'
/// "Trigger by flipping face down" (user's ruling, 2026-09-30).
abstract interface class FlipService {
  /// Starts listening. False when the phone has no accelerometer.
  Future<bool> start();

  Future<void> stop();

  /// One event per flip, while started.
  Stream<void> get flips;
}

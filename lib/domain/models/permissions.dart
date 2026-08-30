/// Hardware a site can ask for. The list is spec `2a`'s
/// "HARDWARE · ALL OFF BY DEFAULT" block, in its order.
enum PermissionKind {
  camera('your camera'),
  microphone('your microphone'),
  location('your location'),
  clipboard('your clipboard');

  const PermissionKind(this.phrase);

  /// The possessive fragment that completes spec `6a`'s title:
  /// "meet.example.com wants your microphone".
  final String phrase;
}

/// What the user chose. Spec `6a` is titled "one time by default, never
/// remembered silently", and these are the only three outcomes it draws.
///
/// Neither allow option is persisted. [allowOnce] covers a single use and
/// [allowWhileOpen] expires when the session closes, so a restart always
/// returns to blocked. There is deliberately no "always allow" — a permanent
/// grant would need UI the spec does not draw, and a grant the user cannot
/// see is exactly what "never remembered silently" forbids.
enum PermissionDecision { allowOnce, allowWhileOpen, keepBlocked }

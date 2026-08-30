/// Runtime-only. Never persisted — Plan 1's rule: sessions do not survive the
/// app closing.
enum SessionPhase { opening, live, background, refused }

class ContainerSession {
  const ContainerSession({
    required this.siteId,
    required this.phase,
    this.lastActiveAt,
    this.blockedCount = 0,
  });

  final String siteId;
  final SessionPhase phase;
  final DateTime? lastActiveAt;

  /// Rules matched in this session. Feeds spec `2a`'s "42 rules matched today"
  /// and fills Plan 1's `leakCountProvider` seam.
  final int blockedCount;

  ContainerSession copyWith({
    SessionPhase? phase,
    DateTime? lastActiveAt,
    int? blockedCount,
  }) =>
      ContainerSession(
        siteId: siteId,
        phase: phase ?? this.phase,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        blockedCount: blockedCount ?? this.blockedCount,
      );
}

import 'route_decision.dart' show RouteFailure;
import 'blocked_tally.dart' show BlockedCategory;

/// Runtime-only. Never persisted — Plan 1's rule: sessions do not survive the
/// app closing.
enum SessionPhase { opening, live, background, refused }

class ContainerSession {
  const ContainerSession({
    required this.siteId,
    required this.phase,
    this.lastActiveAt,
    this.blockedCount = 0,
    this.categoryCounts = const {},
    this.failure,
  });

  final String siteId;
  final SessionPhase phase;
  final DateTime? lastActiveAt;

  /// Rules matched in this session. Feeds spec `2a`'s "42 rules matched today"
  /// and fills Plan 1's `leakCountProvider` seam.
  final int blockedCount;

  /// Cumulative blocks for this session, broken down by [BlockedCategory].
  /// Feeds Task 7's `BlockedTallyController`. A category absent from the map
  /// means zero, not unknown — mirrors `categoryFraction`'s own
  /// partial-list tolerance in `blocked_tally.dart`.
  final Map<BlockedCategory, int> categoryCounts;

  /// Only set when [phase] is [SessionPhase.refused]. `null` in every other
  /// phase, and also `null` for a refusal the platform could not classify.
  final RouteFailure? failure;

  ContainerSession copyWith({
    SessionPhase? phase,
    DateTime? lastActiveAt,
    int? blockedCount,
    Map<BlockedCategory, int>? categoryCounts,
    RouteFailure? failure,
  }) =>
      ContainerSession(
        siteId: siteId,
        phase: phase ?? this.phase,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        blockedCount: blockedCount ?? this.blockedCount,
        categoryCounts: categoryCounts ?? this.categoryCounts,
        failure: failure ?? this.failure,
      );
}

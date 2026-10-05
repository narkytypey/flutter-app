import 'route_decision.dart' show RouteFailure;
import 'blocked_tally.dart' show BlockedCategory;
import 'open_page.dart';
import 'permissions.dart';

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
    this.pages = const [],
    this.grants = const {},
  });

  final String siteId;
  final SessionPhase phase;
  final DateTime? lastActiveAt;

  /// Requests blocked in this session, every category. Feeds the blocked
  /// tally, whose trackers and ads per site are `2a`'s "N rules matched
  /// today".
  final int blockedCount;

  /// Cumulative blocks for this session, broken down by [BlockedCategory].
  /// Feeds Task 7's `BlockedTallyController`. A category absent from the map
  /// means zero, not unknown — mirrors `categoryFraction`'s own
  /// partial-list tolerance in `blocked_tally.dart`.
  final Map<BlockedCategory, int> categoryCounts;

  /// Only set when [phase] is [SessionPhase.refused]. `null` in every other
  /// phase, and also `null` for a refusal the platform could not classify.
  final RouteFailure? failure;

  /// In opening order; empty for a refused open.
  final List<OpenPage> pages;

  /// "Allow while this site is open" grants in this session (spec §3).
  /// Never "allow once", never clipboard.
  final Set<PermissionKind> grants;

  ContainerSession copyWith({
    SessionPhase? phase,
    DateTime? lastActiveAt,
    int? blockedCount,
    Map<BlockedCategory, int>? categoryCounts,
    RouteFailure? failure,
    List<OpenPage>? pages,
    Set<PermissionKind>? grants,
  }) =>
      ContainerSession(
        siteId: siteId,
        phase: phase ?? this.phase,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
        blockedCount: blockedCount ?? this.blockedCount,
        categoryCounts: categoryCounts ?? this.categoryCounts,
        failure: failure ?? this.failure,
        pages: pages ?? this.pages,
        grants: grants ?? this.grants,
      );
}

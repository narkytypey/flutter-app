import 'blocked_tally.dart' show BlockedCategory;

/// The two kinds of rule set a filter list can be. A subset of
/// [BlockedCategory] — `fingerprinting` and `permissionAsks` are not
/// list-driven, they come from `Shields.kt` and the permission-deny path
/// respectively (spec §4).
enum FilterListCategory {
  trackers,
  ads;

  BlockedCategory get blockedCategory => switch (this) {
        FilterListCategory.trackers => BlockedCategory.trackers,
        FilterListCategory.ads => BlockedCategory.ads,
      };
}

class FilterList {
  const FilterList({
    required this.id,
    required this.name,
    required this.ruleCount,
    required this.updatedAt,
    required this.enabled,
    required this.category,
  });

  final String id;
  final String name;
  final int ruleCount;
  final DateTime updatedAt;
  final bool enabled;
  final FilterListCategory category;
}

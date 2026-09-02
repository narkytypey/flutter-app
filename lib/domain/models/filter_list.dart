class FilterList {
  const FilterList({
    required this.id,
    required this.name,
    required this.ruleCount,
    required this.updatedAt,
    required this.enabled,
  });

  final String id;
  final String name;
  final int ruleCount;
  final DateTime updatedAt;
  final bool enabled;
}

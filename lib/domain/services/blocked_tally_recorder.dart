import '../models/blocked_tally.dart';

/// Accumulates category and per-site counts across the process lifetime.
/// Deliberately not a [ChangeNotifier] or Riverpod class itself — kept as
/// plain, host-testable state, per `blocked_tally.dart`'s own promise that
/// this is memory-only and resets on process death; the Riverpod-aware
/// controller that reads live engine events lives in Task 7.
class BlockedTallyRecorder {
  final _categories = <BlockedCategory, int>{};
  final _sites = <String, _SiteCount>{};

  void recordCategory(BlockedCategory category, int delta) {
    if (delta <= 0) return;
    _categories[category] = (_categories[category] ?? 0) + delta;
  }

  void recordSite({
    required String siteId,
    required String monogram,
    required String name,
    required int count,
  }) {
    if (count <= 0) return;
    final existing = _sites[siteId];
    _sites[siteId] = _SiteCount(
      monogram: monogram,
      name: name,
      count: (existing?.count ?? 0) + count,
    );
  }

  BlockedTally snapshot() => BlockedTally(
        categories: [
          for (final entry in _categories.entries)
            CategoryTally(category: entry.key, count: entry.value),
        ],
        sites: [
          for (final entry in _sites.values)
            SiteTally(monogram: entry.monogram, name: entry.name, count: entry.count),
        ],
      );
}

class _SiteCount {
  const _SiteCount({required this.monogram, required this.name, required this.count});
  final String monogram;
  final String name;
  final int count;
}

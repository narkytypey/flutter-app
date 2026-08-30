/// What a category of request was blocked for. Order matches spec `5c`.
enum BlockedCategory {
  trackers('Trackers'),
  ads('Ads'),
  fingerprinting('Fingerprinting'),
  permissionAsks('Permission asks');

  const BlockedCategory(this.label);
  final String label;
}

class CategoryTally {
  const CategoryTally({required this.category, required this.count});
  final BlockedCategory category;
  final int count;
}

class SiteTally {
  const SiteTally({required this.monogram, required this.name, required this.count});
  final String monogram;
  final String name;
  final int count;
}

/// Everything the Today screen shows. Spec `5c`: "Counts are kept in memory
/// only and reset when the app closes." This class carries that promise by
/// construction — it is a plain immutable value with no `toMap`, no
/// `fromMap`, and no repository anywhere in this plan. A table for it would
/// be exactly the persistence the spec forbids, so none is written.
class BlockedTally {
  const BlockedTally({required this.categories, required this.sites});

  final List<CategoryTally> categories;
  final List<SiteTally> sites;

  int get total => categories.fold(0, (sum, c) => sum + c.count);
  int get siteCount => sites.length;
}

/// The bar width for [category], relative to the largest category in
/// [tally]. The spec's own mock draws 74% / 33% / 9% / 3% for counts of
/// 198 / 88 / 24 / 2 — percentages that do not correspond to any ratio of
/// those numbers, so they read as presentation-only. This computes a real
/// one instead: the largest category always fills the track.
double categoryFraction(BlockedTally tally, BlockedCategory category) {
  if (tally.categories.isEmpty) return 0;
  final max = tally.categories.map((c) => c.count).reduce((a, b) => a > b ? a : b);
  if (max == 0) return 0;
  // A category simply absent from a non-empty tally is not an error. The
  // first real feed for this screen is Plan 3's `FilterEngine`, which counts
  // total blocks and does not yet tag them by reason (CLAUDE.md carries
  // "FilterEngine category tagging" as unassigned work) — so a partial list
  // is what it will hand over, and an unguarded `firstWhere` would throw on
  // the day it does.
  final entry = tally.categories.firstWhere(
    (c) => c.category == category,
    orElse: () => CategoryTally(category: category, count: 0),
  );
  return entry.count / max;
}

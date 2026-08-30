import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/blocked_tally.dart';

BlockedTally _tally() => const BlockedTally(
      categories: [
        CategoryTally(category: BlockedCategory.trackers, count: 198),
        CategoryTally(category: BlockedCategory.ads, count: 88),
        CategoryTally(category: BlockedCategory.fingerprinting, count: 24),
        CategoryTally(category: BlockedCategory.permissionAsks, count: 2),
      ],
      sites: [
        SiteTally(monogram: 'Fr', name: 'Forum', count: 164),
        SiteTally(monogram: 'Mk', name: 'Marketplace', count: 97),
        SiteTally(monogram: 'Rd', name: 'Reader', count: 39),
        SiteTally(monogram: 'Wm', name: 'Webmail', count: 12),
      ],
    );

void main() {
  test('total sums every category, matching the spec\'s 312', () {
    expect(_tally().total, 312);
  });

  test('site count is the number of sites tallied, matching the spec\'s 4', () {
    expect(_tally().siteCount, 4);
  });

  test('the largest category gets the full-width bar', () {
    expect(categoryFraction(_tally(), BlockedCategory.trackers), 1.0);
  });

  test('smaller categories scale relative to the largest, not to the total', () {
    final tally = _tally();
    expect(categoryFraction(tally, BlockedCategory.ads), closeTo(88 / 198, 0.0001));
    expect(categoryFraction(tally, BlockedCategory.fingerprinting), closeTo(24 / 198, 0.0001));
    expect(categoryFraction(tally, BlockedCategory.permissionAsks), closeTo(2 / 198, 0.0001));
  });

  test('a category missing from a non-empty tally reads as zero, not a crash', () {
    const partial = BlockedTally(
      categories: [CategoryTally(category: BlockedCategory.trackers, count: 9)],
      sites: [],
    );
    expect(categoryFraction(partial, BlockedCategory.ads), 0);
  });

  test('an empty tally has no total and does not divide by zero', () {
    const empty = BlockedTally(categories: [], sites: []);
    expect(empty.total, 0);
    expect(empty.siteCount, 0);
    expect(categoryFraction(empty, BlockedCategory.trackers), 0);
  });
}

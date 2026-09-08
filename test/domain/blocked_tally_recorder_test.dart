import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/services/blocked_tally_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('categories accumulate across multiple record calls', () {
    final recorder = BlockedTallyRecorder();
    recorder.recordCategory(BlockedCategory.trackers, 12);
    recorder.recordCategory(BlockedCategory.trackers, 3);
    recorder.recordCategory(BlockedCategory.ads, 5);

    final tally = recorder.snapshot();
    final trackers =
        tally.categories.firstWhere((c) => c.category == BlockedCategory.trackers);
    expect(trackers.count, 15);
    expect(tally.total, 20);
  });

  test('a zero or negative delta is not recorded', () {
    final recorder = BlockedTallyRecorder();
    recorder.recordCategory(BlockedCategory.trackers, 0);
    recorder.recordCategory(BlockedCategory.trackers, -1);
    expect(recorder.snapshot().categories, isEmpty);
  });

  test('sites accumulate by id and keep the latest name and monogram', () {
    final recorder = BlockedTallyRecorder();
    recorder.recordSite(siteId: 's1', monogram: 'Fr', name: 'Forum', count: 4);
    recorder.recordSite(siteId: 's1', monogram: 'Fr', name: 'Forum', count: 6);
    recorder.recordSite(siteId: 's2', monogram: 'Nt', name: 'Notes', count: 1);

    final tally = recorder.snapshot();
    expect(tally.siteCount, 2);
    final forum = tally.sites.firstWhere((s) => s.name == 'Forum');
    expect(forum.count, 10);
  });
}

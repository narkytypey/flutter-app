import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/workspace_stats.dart';

void main() {
  test('whole-number megabytes, matching the spec\'s "12 MB"', () {
    expect(wholeMegabytes(12 * 1024 * 1024), '12 MB');
    expect(wholeMegabytes(3 * 1024 * 1024), '3 MB');
  });

  test('a kept workspace states sites, cookie policy and size', () {
    expect(
      workspaceStatsLine(
        storageRule: StorageRule.keep,
        siteCount: 6,
        storageBytes: 12 * 1024 * 1024,
      ),
      '6 sites · cookies kept · 12 MB',
    );
    expect(
      workspaceStatsLine(
        storageRule: StorageRule.keep,
        siteCount: 2,
        storageBytes: 3 * 1024 * 1024,
      ),
      '2 sites · cookies kept · 3 MB',
    );
  });

  test('a single site reads as singular, matching the spec\'s "1 site"', () {
    expect(
      workspaceStatsLine(storageRule: StorageRule.keep, siteCount: 1, storageBytes: 0),
      '1 site · cookies kept · 0 MB',
    );
  });

  test('an ephemeral workspace never reports a size', () {
    expect(
      workspaceStatsLine(
        storageRule: StorageRule.wipeOnExit,
        siteCount: 1,
        storageBytes: 999999999,
      ),
      '1 site · wipes on exit · nothing stored',
    );
  });
}

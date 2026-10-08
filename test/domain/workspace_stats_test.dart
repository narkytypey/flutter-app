import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/workspace_stats.dart';

void main() {
  // The user's ruling of 2026-10-08: no screen shows a real byte count until
  // the threat model allows one, and `bytesFor` was a fake returning 0, so
  // every workspace read "0 MB" in both vaults. The size is gone; the storage
  // rule stays, since it is what tells the two kinds of workspace apart.
  test('a kept workspace states its sites and cookie policy, with no size', () {
    expect(
      workspaceStatsLine(storageRule: StorageRule.keep, siteCount: 6),
      '6 sites · cookies kept',
    );
  });

  test('a single site reads as singular, matching the spec\'s "1 site"', () {
    expect(
      workspaceStatsLine(storageRule: StorageRule.keep, siteCount: 1),
      '1 site · cookies kept',
    );
  });

  test('an ephemeral workspace says what it does with storage', () {
    expect(
      workspaceStatsLine(storageRule: StorageRule.wipeOnExit, siteCount: 1),
      '1 site · wipes on exit · nothing stored',
    );
  });
}

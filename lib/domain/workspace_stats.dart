import 'models/workspace.dart';

/// The stats line under a workspace's name in `10a`'s list.
///
/// It carries no byte count. The user's ruling of 2026-10-08: no screen shows
/// a real stored-data size until the threat model allows one, because a
/// lightly used decoy would read a small number beside a real vault's large
/// one. Until that ruling, `WorkspaceStorageService` was a fake returning 0,
/// so `10a` and `10c` showed "0 MB" in every workspace of both vaults — a
/// number that was never true. Bringing a size back needs the threat-model
/// ruling first, not just an implementation of `bytesFor`.
///
/// The storage *rule* stays: it is what tells a wipe-on-exit workspace from
/// one that keeps cookies, and it is not a measurement of anything.
String workspaceStatsLine({
  required StorageRule storageRule,
  required int siteCount,
}) {
  final siteWord = siteCount == 1 ? 'site' : 'sites';
  if (storageRule == StorageRule.wipeOnExit) {
    return '$siteCount $siteWord · wipes on exit · nothing stored';
  }
  return '$siteCount $siteWord · cookies kept';
}

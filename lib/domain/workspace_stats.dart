import 'models/workspace.dart';

/// Rounded to the nearest whole megabyte — spec `10a` shows "12 MB", never
/// "12.0 MB". A dedicated rounder rather than reusing Plan 4's `formatBytes`,
/// which always keeps one decimal; the two screens want different precision
/// for the same underlying byte count.
String wholeMegabytes(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

/// The stats line under a workspace's name in `10a`'s list.
String workspaceStatsLine({
  required StorageRule storageRule,
  required int siteCount,
  required int storageBytes,
}) {
  final siteWord = siteCount == 1 ? 'site' : 'sites';
  final ruleClause =
      storageRule == StorageRule.wipeOnExit ? 'wipes on exit' : 'cookies kept';
  final storageClause = storageRule == StorageRule.wipeOnExit
      ? 'nothing stored'
      : wholeMegabytes(storageBytes);
  return '$siteCount $siteWord · $ruleClause · $storageClause';
}

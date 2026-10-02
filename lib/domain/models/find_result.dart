/// The page's finished count for a find in page (spec §6.5).
class FindResult {
  const FindResult({
    required this.siteId,
    required this.pageId,
    required this.activeMatch,
    required this.matchCount,
  });

  final String siteId;

  /// The page it is about (tabs spec §3.1).
  final String pageId;

  /// Zero-based, as WebView reports it; the find bar shows it plus one.
  final int activeMatch;
  final int matchCount;
}

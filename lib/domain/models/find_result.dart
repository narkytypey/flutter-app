/// The page's finished count for a find in page (spec §6.5).
class FindResult {
  const FindResult({
    required this.siteId,
    required this.activeMatch,
    required this.matchCount,
  });

  final String siteId;

  /// Zero-based, as WebView reports it; the find bar shows it plus one.
  final int activeMatch;
  final int matchCount;
}

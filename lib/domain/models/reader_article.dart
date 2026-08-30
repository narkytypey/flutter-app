/// The content of one reader-mode page. Plan 3's `Site.openInReader` decides
/// *whether* a site opens here; producing an [ReaderArticle] from a live page
/// (readability extraction) is not this plan's job and is not attempted —
/// this plan only renders one, however it was built.
class ReaderArticle {
  const ReaderArticle({
    required this.host,
    required this.title,
    required this.paragraphs,
    required this.minutesToRead,
  });

  final String host;
  final String title;
  final List<String> paragraphs;
  final int minutesToRead;

  /// Spec `6b`'s header label: "READER · 6 MIN".
  String get readingLabel => 'READER · $minutesToRead MIN';
}

/// One page of an open container (tabs spec §0): one WebView, on its
/// container's profile and route. Runtime only — never written anywhere.
class OpenPage {
  const OpenPage({required this.pageId, this.openerPageId});

  /// Random, made natively, never reused.
  final String pageId;

  /// The page whose link opened this one, in the same container; null for a
  /// container's first page.
  final String? openerPageId;

  @override
  bool operator ==(Object other) =>
      other is OpenPage && other.pageId == pageId && other.openerPageId == openerPageId;

  @override
  int get hashCode => Object.hash(pageId, openerPageId);
}

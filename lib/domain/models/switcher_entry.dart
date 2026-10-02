/// One page row under a container in `2c` (tabs spec §5.1): page data only.
class SwitcherPage {
  const SwitcherPage({
    required this.pageId,
    required this.title,
    required this.host,
    required this.current,
  });

  final String pageId;

  /// The page's title, or its host when it has none.
  final String title;
  final String host;

  /// The container's last viewed page — primary text; the rest are muted.
  final bool current;
}

/// One container row of the quick switcher, already reduced to strings.
/// [meta] is `'viewing now · $mode'` for the viewed container and
/// `'background · $age'` for the rest (see `backgroundAge`).
class SwitcherEntry {
  const SwitcherEntry({
    required this.siteId,
    required this.name,
    required this.monogram,
    required this.meta,
    required this.live,
    this.pages = const [],
  });

  final String siteId;
  final String name;
  final String monogram;
  final String meta;
  final bool live;

  /// Empty unless the container has two or more pages.
  final List<SwitcherPage> pages;
}

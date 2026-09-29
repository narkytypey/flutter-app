/// The fixed list in Settings (spec §4.2, §6.7). No custom engines, no
/// suggestions.
///
/// Mullvad Leta is not here: it shut down on 2025-11-27, and the spec drops
/// an engine that no longer works rather than ship it broken.
enum SearchEngine {
  duckDuckGo('DuckDuckGo', 'https://duckduckgo.com/?q='),
  startpage('Startpage', 'https://www.startpage.com/sp/search?query='),
  braveSearch('Brave Search', 'https://search.brave.com/search?q=');

  const SearchEngine(this.label, this.template);

  /// The engine's name as the picker and the search row show it (spec §7).
  final String label;

  /// The results address, missing only the encoded query.
  final String template;

  /// The results page for [query]. Nothing is sent until the user opens it.
  Uri resultsFor(String query) =>
      Uri.parse('$template${Uri.encodeQueryComponent(query)}');

  /// Shown under the search row.
  String get host => Uri.parse(template).host;

  /// Reads the stored `search_engine` setting. Anything unknown — including
  /// no setting at all — is the default.
  static SearchEngine fromStored(String? name) {
    for (final engine in values) {
      if (engine.name == name) return engine;
    }
    return duckDuckGo;
  }
}

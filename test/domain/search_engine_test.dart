import 'package:container/domain/models/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each engine builds its results address with the query encoded', () {
    expect(SearchEngine.duckDuckGo.resultsFor('privacy tools').toString(),
        'https://duckduckgo.com/?q=privacy+tools');
    expect(SearchEngine.startpage.resultsFor('a&b').toString(),
        'https://www.startpage.com/sp/search?query=a%26b');
    expect(SearchEngine.braveSearch.resultsFor('café #1').toString(),
        'https://search.brave.com/search?q=caf%C3%A9+%231');
  });

  test('the picker lists the three engines by their spec names; Mullvad Leta is gone', () {
    expect(SearchEngine.values.map((e) => e.label),
        ['DuckDuckGo', 'Startpage', 'Brave Search']);
    expect(SearchEngine.values.map((e) => e.name), isNot(contains('mullvadLeta')));
  });

  test('each engine names its own host, shown under the search row', () {
    expect(SearchEngine.values.map((e) => e.host),
        ['duckduckgo.com', 'www.startpage.com', 'search.brave.com']);
  });

  test('a stored engine reads back; anything else is DuckDuckGo', () {
    expect(SearchEngine.fromStored('braveSearch'), SearchEngine.braveSearch);
    expect(SearchEngine.fromStored('startpage'), SearchEngine.startpage);
    expect(SearchEngine.fromStored(null), SearchEngine.duckDuckGo);
    expect(SearchEngine.fromStored(''), SearchEngine.duckDuckGo);
    expect(SearchEngine.fromStored('mullvadLeta'), SearchEngine.duckDuckGo);
  });
}

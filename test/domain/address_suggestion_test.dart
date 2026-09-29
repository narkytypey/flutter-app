import 'package:container/domain/models/address_suggestion.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const _personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);
const _work = Workspace(
    id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep);

final _forum = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
  lastVisitedAt: DateTime(2026, 9, 20),
);
final _market = Site(
  id: 'market', workspaceId: 'w1', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'p2',
  lastVisitedAt: DateTime(2026, 9, 10),
);

List<AddressSuggestion> _for(
  String text, {
  Site? current,
  List<Site>? saved,
  SearchEngine engine = SearchEngine.duckDuckGo,
}) =>
    suggestionsFor(
      text: text,
      current: current ?? _forum,
      saved: saved ?? [_forum, _market],
      workspaces: const [_personal, _work],
      engine: engine,
    );

void main() {
  test('a word lists the saved sites it matches, then the search row', () {
    final rows = _for('market');
    expect(rows.map((r) => r.kind), [SuggestionKind.savedSite, SuggestionKind.search]);

    final saved = rows.first;
    expect(saved.primary, 'Marketplace');
    expect(saved.secondary, 'market.example.com · Personal');
    expect(saved.monogram, 'Mk');
    expect(saved.tag, 'ITS OWN CONTAINER');

    final search = rows.last;
    expect(search.primary, 'Search DuckDuckGo for “market”');
    expect(search.secondary, 'duckduckgo.com');
    expect(search.tag, 'THROWAWAY · SOCKS5');
    expect(search.monogram, isNull);
  });

  test('an address lists the address row before the search row', () {
    final rows = _for('news.example.org/today');
    expect(rows.map((r) => r.kind), [SuggestionKind.address, SuggestionKind.search]);
    expect(rows.first.primary, 'news.example.org/today');
    expect(rows.first.secondary, 'not saved');
    expect(rows.first.tag, 'THROWAWAY · SOCKS5');
    expect(rows.first.destination.url.toString(), 'https://news.example.org/today');
  });

  test('this container\'s own site is tagged THIS CONTAINER, at its saved address', () {
    final row = _for('forum').first;
    expect(row.tag, 'THIS CONTAINER');
    expect(row.destination, isA<ThisContainer>());
    expect(row.destination.url.toString(), 'https://forum.example.com');
  });

  test("a saved row opens that site's own saved address, not the typed text", () {
    final row = _for('mark').first;
    expect((row.destination as SavedSiteContainer).site.id, 'market');
    expect(row.destination.url.toString(), 'https://market.example.com');
  });

  test('at most five saved sites, most recently visited first', () {
    final shops = [
      for (var i = 0; i < 7; i++)
        Site(
          id: 's$i', workspaceId: 'w1', name: 'Shop $i', monogram: 'Sh',
          url: 'https://shop$i.example.com', profileId: 'p$i',
          lastVisitedAt: DateTime(2026, 9, 1 + i),
        ),
    ];
    final rows = _for('shop', saved: shops)
        .where((r) => r.kind == SuggestionKind.savedSite);
    expect(rows.map((r) => r.primary),
        ['Shop 6', 'Shop 5', 'Shop 4', 'Shop 3', 'Shop 2']);
  });

  test('a direct throwaway is tagged THROWAWAY alone; an http one is named', () {
    expect(_for('x.example.net', current: _market).first.tag, 'THROWAWAY');
    final http = _forum.copyWith(
        proxyMode: ProxyMode.http, proxyHost: '10.0.2.2', proxyPort: 8888);
    expect(_for('x.example.net', current: http).first.tag, 'THROWAWAY · HTTP');
  });

  test("a search whose engine is a saved site is tagged for that site's container", () {
    const duck = Site(
      id: 'ddg', workspaceId: 'w2', name: 'Duck', monogram: 'Dk',
      url: 'https://duckduckgo.com', profileId: 'p9',
    );
    expect(_for('market', saved: [_forum, _market, duck]).last.tag,
        'ITS OWN CONTAINER');
  });

  test('the chosen engine names the search row', () {
    expect(_for('x y', engine: SearchEngine.braveSearch).single.primary,
        'Search Brave Search for “x y”');
  });

  test('nothing typed suggests nothing', () {
    expect(_for('   '), isEmpty);
  });
}

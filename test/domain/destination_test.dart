import 'package:container/domain/models/address_input.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(
  String id,
  String url, {
  String workspaceId = 'w1',
  DateTime? visited,
  ProxyMode mode = ProxyMode.direct,
  String? proxyHost,
  int? proxyPort,
}) =>
    Site(
      id: id, workspaceId: workspaceId, name: id, monogram: 'Xx', url: url,
      profileId: 'p-$id', proxyMode: mode, proxyHost: proxyHost,
      proxyPort: proxyPort, lastVisitedAt: visited,
    );

final _forum = _site('forum', 'https://forum.example.com',
    mode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050);

Destination _resolve(String raw, {Site? current, List<Site> saved = const []}) =>
    resolveDestination(
      input: parseAddressInput(raw),
      current: current ?? _forum,
      saved: saved,
      engine: SearchEngine.duckDuckGo,
    );

void main() {
  test("this container's own host stays in this container", () {
    final destination = _resolve('forum.example.com/latest');
    expect(destination, isA<ThisContainer>());
    expect(destination.url.toString(), 'https://forum.example.com/latest');
  });

  test('a leading www. and letter case do not change the host', () {
    expect(_resolve('WWW.Forum.Example.com/x'), isA<ThisContainer>());
    final market = _site('market', 'https://www.market.example.com');
    expect(_resolve('market.example.com', saved: [market]), isA<SavedSiteContainer>());
  });

  test('a subdomain is a different host', () {
    expect(_resolve('mail.forum.example.com'), isA<Throwaway>());
  });

  test("a saved site's host opens its own container at the typed address", () {
    final market = _site('market', 'https://market.example.com');
    final destination = _resolve('market.example.com/deals', saved: [market]);
    expect((destination as SavedSiteContainer).site.id, 'market');
    expect(destination.url.toString(), 'https://market.example.com/deals');
  });

  test('ties go to this workspace first, then the most recent visit', () {
    final older = _site('a', 'https://news.example.org',
        workspaceId: 'w2', visited: DateTime(2026, 9, 1));
    final newer = _site('b', 'https://news.example.org',
        workspaceId: 'w2', visited: DateTime(2026, 9, 20));
    final here = _site('c', 'https://news.example.org',
        workspaceId: 'w1', visited: DateTime(2026, 8, 1));
    final never = _site('d', 'https://news.example.org', workspaceId: 'w2');

    SavedSiteContainer pick(List<Site> saved) =>
        _resolve('news.example.org', saved: saved) as SavedSiteContainer;

    expect(pick([older, newer]).site.id, 'b');
    expect(pick([older, newer, here]).site.id, 'c');
    expect(pick([never, older]).site.id, 'a');
  });

  test("a search opens the engine's results, in the engine's own container if saved", () {
    final search = _resolve('privacy tools');
    expect(search, isA<Throwaway>());
    expect(search.url.toString(), 'https://duckduckgo.com/?q=privacy+tools');

    final duck = _site('ddg', 'https://duckduckgo.com');
    expect(_resolve('privacy tools', saved: [duck]), isA<SavedSiteContainer>());
  });

  test('a throwaway inherits the route exactly: direct, SOCKS5 or http', () {
    final direct = _site('d', 'https://d.example.com');
    final http = _site('h', 'https://h.example.com',
        mode: ProxyMode.http, proxyHost: '10.0.2.2', proxyPort: 8888);
    for (final current in [direct, _forum, http]) {
      final destination =
          _resolve('elsewhere.example.net', current: current) as Throwaway;
      expect(destination.mode, current.proxyMode, reason: current.id);
      expect(destination.proxyHost, current.proxyHost, reason: current.id);
      expect(destination.proxyPort, current.proxyPort, reason: current.id);
    }
  });

  test('nothing typed has no destination', () {
    expect(
      () => resolveDestination(
        input: const AddressEmpty(),
        current: _forum,
        saved: const [],
        engine: SearchEngine.duckDuckGo,
      ),
      throwsArgumentError,
    );
  });
}

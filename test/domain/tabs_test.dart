import 'package:container/domain/models/navigation_state.dart';
import 'package:container/domain/models/open_container.dart';
import 'package:container/domain/models/open_page.dart';
import 'package:container/domain/models/route_decision.dart' show RouteFailure;
import 'package:container/domain/models/site.dart';
import 'package:container/domain/tabs.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(String id, {String url = 'https://example.com/', ProxyMode mode = ProxyMode.direct}) =>
    Site(
      id: id,
      workspaceId: 'ws',
      name: 'Site $id',
      monogram: id.toUpperCase(),
      url: url,
      profileId: 'p-$id',
      proxyMode: mode,
    );

OpenContainer _container(
  String id, {
  DateTime? lastViewedAt,
  bool throwaway = false,
  String? openerSiteId,
  List<OpenPage> pages = const [],
  List<String> viewOrder = const [],
  Refusal? refusal,
  String url = 'https://example.com/',
  ProxyMode mode = ProxyMode.direct,
}) {
  final site = _site(id, url: url, mode: mode);
  return OpenContainer(
    site: site,
    opened: site,
    lastViewedAt: lastViewedAt ?? DateTime(2026, 10, 2, 12),
    throwaway: throwaway,
    openerSiteId: openerSiteId,
    pages: pages,
    viewOrder: viewOrder,
    refusal: refusal,
  );
}

const _refused = Refusal(failure: RouteFailure.proxyUnreachable);

void main() {
  group('backgroundAge', () {
    final then = DateTime(2026, 10, 2, 12);

    test('0 s reads now', () {
      expect(backgroundAge(then, then), 'now');
    });

    test('59 s reads now', () {
      expect(backgroundAge(then.add(const Duration(seconds: 59)), then), 'now');
    });

    test('60 s reads 1 min', () {
      expect(backgroundAge(then.add(const Duration(seconds: 60)), then), '1 min');
    });

    test('59 min reads 59 min', () {
      expect(backgroundAge(then.add(const Duration(minutes: 59)), then), '59 min');
    });

    test('60 min reads 1 h', () {
      expect(backgroundAge(then.add(const Duration(minutes: 60)), then), '1 h');
    });

    test('135 min reads 2 h', () {
      expect(backgroundAge(then.add(const Duration(minutes: 135)), then), '2 h');
    });

    test('a future time reads now', () {
      expect(backgroundAge(then, then.add(const Duration(minutes: 5))), 'now');
    });
  });

  group('routeOrCookiePolicyChanged', () {
    final base = _site('a').copyWith(
      proxyMode: ProxyMode.socks5,
      proxyHost: '10.0.2.2',
      proxyPort: 1080,
      proxyUser: 'user',
      proxyPassword: 'secret',
    );

    final changes = <String, Site>{
      'proxyMode': base.copyWith(proxyMode: ProxyMode.http),
      'proxyHost': base.copyWith(proxyHost: '10.0.2.3'),
      'proxyPort': base.copyWith(proxyPort: 1081),
      'proxyUser': base.copyWith(proxyUser: 'other'),
      'proxyPassword': base.copyWith(proxyPassword: 'other'),
      'proxyLoginPerSite': base.copyWith(proxyLoginPerSite: true),
      'cookiePolicy': base.copyWith(cookiePolicy: CookiePolicy.wipeOnExit),
    };
    for (final MapEntry(key: field, value: after) in changes.entries) {
      test('true when only $field changed', () {
        expect(routeOrCookiePolicyChanged(base, after), isTrue);
      });
    }

    test('false for forceDark, userAgentMode, name, customJs and pageZoom', () {
      final after = base.copyWith(
        forceDark: !base.forceDark,
        userAgentMode: UserAgentMode.desktop,
        name: 'Renamed',
        customJs: 'console.log(1);',
        pageZoom: 150,
      );
      expect(routeOrCookiePolicyChanged(base, after), isFalse);
    });

    test('false for an identical copy', () {
      expect(routeOrCookiePolicyChanged(base, base.copyWith()), isFalse);
    });
  });

  group('backTarget', () {
    const first = OpenPage(pageId: 'p1');
    const link = OpenPage(pageId: 'p2', openerPageId: 'p1');
    final early = DateTime(2026, 10, 2, 11);
    final late = DateTime(2026, 10, 2, 12);

    test('canGoBack goes back in the page', () {
      final c = _container('a', pages: const [first, link]);
      expect(
        backTarget(canGoBack: true, container: c, pageId: 'p2', others: const {}),
        isA<BackInPage>(),
      );
    });

    test('a link page whose opener is open closes to its opener', () {
      final c = _container('a', pages: const [first, link]);
      final target = backTarget(canGoBack: false, container: c, pageId: 'p2', others: const {});
      expect(target, isA<ClosePageToOpener>());
      expect((target as ClosePageToOpener).openerPageId, 'p1');
    });

    test('a link page whose opener is closed, on a saved container, leaves to the dashboard', () {
      final c = _container('a', pages: const [link]);
      expect(
        backTarget(canGoBack: false, container: c, pageId: 'p2', others: {'b': late}),
        isA<LeaveToDashboard>(),
      );
    });

    test('a saved first page leaves to the dashboard', () {
      final c = _container('a', pages: const [first]);
      expect(
        backTarget(canGoBack: false, container: c, pageId: 'p1', others: {'b': late}),
        isA<LeaveToDashboard>(),
      );
    });

    test('a throwaway shows its opener container, even when another is more recent', () {
      final c = _container('t', throwaway: true, openerSiteId: 'b', pages: const [first]);
      final target = backTarget(
        canGoBack: false,
        container: c,
        pageId: 'p1',
        others: {'b': early, 'c': late},
      );
      expect(target, isA<ViewContainer>());
      expect((target as ViewContainer).siteId, 'b');
    });

    test('a throwaway whose opener is not open shows the most recent other', () {
      final c = _container('t', throwaway: true, openerSiteId: 'gone', pages: const [first]);
      final target = backTarget(
        canGoBack: false,
        container: c,
        pageId: 'p1',
        others: {'b': late, 'c': early},
      );
      expect(target, isA<ViewContainer>());
      expect((target as ViewContainer).siteId, 'b');
    });

    test('a throwaway with nothing else open is closed to the dashboard', () {
      final c = _container('t', throwaway: true, openerSiteId: 'b', pages: const [first]);
      expect(
        backTarget(canGoBack: false, container: c, pageId: 'p1', others: const {}),
        isA<CloseThrowawayToDashboard>(),
      );
    });

    test('a throwaway opened from the dashboard is closed to it, even with others open', () {
      final c = _container('t', throwaway: true, pages: const [first]);
      expect(
        backTarget(canGoBack: false, container: c, pageId: 'p1', others: {'b': late}),
        isA<CloseThrowawayToDashboard>(),
      );
    });
  });

  group('OpenContainer.viewedPageId', () {
    const p1 = OpenPage(pageId: 'p1');
    const p2 = OpenPage(pageId: 'p2', openerPageId: 'p1');

    test('is the head of viewOrder when that page is open', () {
      final c = _container('a', pages: const [p1, p2], viewOrder: const ['p2', 'p1']);
      expect(c.viewedPageId, 'p2');
    });

    test('skips ids no longer in pages', () {
      final c = _container('a', pages: const [p1, p2], viewOrder: const ['gone', 'p2', 'p1']);
      expect(c.viewedPageId, 'p2');
    });

    test('falls back to the first page', () {
      final c = _container('a', pages: const [p1, p2], viewOrder: const ['gone']);
      expect(c.viewedPageId, 'p1');
    });

    test('is null with no pages', () {
      final c = _container('a', viewOrder: const ['gone']);
      expect(c.viewedPageId, isNull);
    });
  });

  group('OpenContainer.listed', () {
    test('a saved container with a refusal is not listed', () {
      expect(_container('a', refusal: _refused).listed, isFalse);
      expect(_container('a').listed, isTrue);
    });

    test('a throwaway with a refusal is listed', () {
      expect(_container('t', throwaway: true, refusal: _refused).listed, isTrue);
    });
  });

  group('switcherEntries', () {
    final now = DateTime(2026, 10, 2, 12, 30);
    const p1 = OpenPage(pageId: 'p1');
    const p2 = OpenPage(pageId: 'p2', openerPageId: 'p1');
    const p3 = OpenPage(pageId: 'p3', openerPageId: 'p1');

    test('the viewed container first, then most recently viewed', () {
      final entries = switcherEntries(
        containers: [
          _container('old', lastViewedAt: now.subtract(const Duration(minutes: 30))),
          _container('viewed', lastViewedAt: now.subtract(const Duration(hours: 2))),
          _container('recent', lastViewedAt: now.subtract(const Duration(minutes: 2))),
        ],
        viewedSiteId: 'viewed',
        navigation: const {},
        now: now,
      );
      expect([for (final e in entries) e.siteId], ['viewed', 'recent', 'old']);
      expect([for (final e in entries) e.live], [true, false, false]);
    });

    test('meta reads viewing now · <mode> and background · <age>', () {
      final socks = switcherEntries(
        containers: [
          _container('a', mode: ProxyMode.socks5),
          _container('b', lastViewedAt: now.subtract(const Duration(minutes: 2))),
        ],
        viewedSiteId: 'a',
        navigation: const {},
        now: now,
      );
      expect(socks.map((e) => e.meta), ['viewing now · socks5', 'background · 2 min']);

      final direct = switcherEntries(
        containers: [_container('c')],
        viewedSiteId: 'c',
        navigation: const {},
        now: now,
      );
      expect(direct.single.meta, 'viewing now · direct');
    });

    test('an unlisted refused saved container is left out', () {
      final entries = switcherEntries(
        containers: [
          _container('a'),
          _container('refused', refusal: _refused),
          _container('t', throwaway: true, refusal: _refused),
        ],
        viewedSiteId: 'a',
        navigation: const {},
        now: now,
      );
      expect([for (final e in entries) e.siteId], ['a', 't']);
    });

    test('no page rows for one page', () {
      final entries = switcherEntries(
        containers: [_container('a', pages: const [p1])],
        viewedSiteId: 'a',
        navigation: const {},
        now: now,
      );
      expect(entries.single.pages, isEmpty);
    });

    test('page rows in opening order for two', () {
      final entries = switcherEntries(
        containers: [
          _container('a', pages: const [p1, p2], viewOrder: const ['p2', 'p1']),
        ],
        viewedSiteId: 'a',
        navigation: const {
          'p1': NavigationState(siteId: 'a', pageId: 'p1', url: 'https://one.example/', title: 'One'),
          'p2': NavigationState(siteId: 'a', pageId: 'p2', url: 'https://two.example/', title: 'Two'),
        },
        now: now,
      );
      final pages = entries.single.pages;
      expect([for (final p in pages) p.pageId], ['p1', 'p2']);
      expect([for (final p in pages) p.title], ['One', 'Two']);
      expect([for (final p in pages) p.host], ['one.example', 'two.example']);
    });

    test('a page with an empty title shows its host as the title', () {
      final entries = switcherEntries(
        containers: [_container('a', pages: const [p1, p2])],
        viewedSiteId: 'a',
        navigation: const {
          'p1': NavigationState(siteId: 'a', pageId: 'p1', url: 'https://one.example/', title: 'One'),
          'p2': NavigationState(siteId: 'a', pageId: 'p2', url: 'https://two.example/x', title: '   '),
        },
        now: now,
      );
      final row = entries.single.pages[1];
      expect(row.title, 'two.example');
      expect(row.host, 'two.example');
    });

    test('a page with no navigation yet shows the container host', () {
      final entries = switcherEntries(
        containers: [
          _container('a', url: 'https://forum.example.com/threads', pages: const [p1, p2]),
        ],
        viewedSiteId: 'a',
        navigation: const {
          'p1': NavigationState(siteId: 'a', pageId: 'p1', url: 'https://one.example/', title: 'One'),
        },
        now: now,
      );
      final row = entries.single.pages[1];
      expect(row.title, 'forum.example.com');
      expect(row.host, 'forum.example.com');
    });

    test('current only on the last viewed page', () {
      final entries = switcherEntries(
        containers: [
          _container('a', pages: const [p1, p2, p3], viewOrder: const ['p3', 'p1']),
        ],
        viewedSiteId: 'a',
        navigation: const {},
        now: now,
      );
      expect([for (final p in entries.single.pages) p.current], [false, false, true]);
    });
  });
}

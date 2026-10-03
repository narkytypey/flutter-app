import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fromForm applies ruling 8', () {
    test('a typed login is kept on a proxy, the password exactly as typed', () {
      final route = ProxyRoute.fromForm(
          mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: ' s3cret ');
      expect(route, const ProxyRoute(
          mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: ' s3cret '));
    });

    test('per-site login drops a typed one', () {
      final route = ProxyRoute.fromForm(
          mode: ProxyMode.http, host: 'h', port: 1, user: 'alice', password: 'x', loginPerSite: true);
      expect(route.user, isNull);
      expect(route.password, isNull);
      expect(route.loginPerSite, isTrue);
    });

    test('a password without a user is not kept', () {
      final route = ProxyRoute.fromForm(mode: ProxyMode.socks5, host: 'h', port: 1, password: 'x');
      expect(route.password, isNull);
    });

    test('direct keeps no address, no login and no per-site choice', () {
      final route = ProxyRoute.fromForm(
          mode: ProxyMode.direct, host: 'h', port: 1, user: 'a', password: 'b', loginPerSite: true);
      expect(route, ProxyRoute.direct);
    });
  });

  test("of(site) is the site's own route", () {
    const site = Site(
      id: 's', workspaceId: 'w', name: 'S', monogram: 'S', url: 'https://s.example', profileId: 'p',
      proxyMode: ProxyMode.http, proxyHost: '10.0.0.1', proxyPort: 8080,
      proxyUser: 'u', proxyPassword: 'pw',
    );
    expect(ProxyRoute.of(site), const ProxyRoute(
        mode: ProxyMode.http, host: '10.0.0.1', port: 8080, user: 'u', password: 'pw'));
  });

  test("the row value: Direct, or the mode and address (spec §8)", () {
    expect(ProxyRoute.direct.label, 'Direct');
    expect(const ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050).label,
        'SOCKS5 · 127.0.0.1:9050');
    expect(const ProxyRoute(mode: ProxyMode.http, host: 'proxy.lan', port: 3128).label,
        'HTTP · proxy.lan:3128');
    expect(ProxyRoute.unreadable.label, 'SOCKS5');
    expect(const ProxyRoute(mode: ProxyMode.socks5, host: '', port: 9050).label, 'SOCKS5');
  });

  test('a route survives being stored and read back', () {
    const route = ProxyRoute(
        mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw');
    expect(ProxyRoute.fromStored(route.toStored()), route);
    const perSite = ProxyRoute(mode: ProxyMode.http, host: 'h', port: 1, loginPerSite: true);
    expect(ProxyRoute.fromStored(perSite.toStored()), perSite);
  });

  test('nothing stored is Direct', () {
    expect(ProxyRoute.fromStored(null), ProxyRoute.direct);
  });

  test('a stored route that cannot be read is refused, never direct', () {
    for (final stored in ['{not json', '[]', '{"mode":"tor","host":"h","port":1}', '{"mode":7}']) {
      final route = ProxyRoute.fromStored(stored);
      expect(route, ProxyRoute.unreadable, reason: stored);
      expect(route.mode, isNot(ProxyMode.direct), reason: stored);
      expect(route.host, isNull, reason: 'no address: every open refuses it (8b)');
    }
  });
}

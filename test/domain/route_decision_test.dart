import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site({
  ProxyMode mode = ProxyMode.socks5,
  String? host = '127.0.0.1',
  int? port = 9050,
}) =>
    Site(
      id: 's',
      workspaceId: 'w',
      name: 'Forum',
      monogram: 'Fr',
      url: 'https://forum.example.com',
      profileId: 'a' * 32,
      proxyMode: mode,
      proxyHost: host,
      proxyPort: port,
    );

void main() {
  test('a direct site routes direct', () {
    expect(resolveRoute(_site(mode: ProxyMode.direct), proxyReachable: false),
        isA<RouteDirect>());
  });

  test('a proxied site with a reachable proxy routes through it', () {
    final decision = resolveRoute(_site(), proxyReachable: true);
    expect(decision, isA<RouteProxy>());
    decision as RouteProxy;
    expect(decision.host, '127.0.0.1');
    expect(decision.port, 9050);
    expect(decision.mode, ProxyMode.socks5);
  });

  test('a proxied site with an unreachable proxy REFUSES, never direct', () {
    final decision = resolveRoute(_site(), proxyReachable: false);
    expect(decision, isA<RouteRefused>());
    expect((decision as RouteRefused).failure, RouteFailure.proxyUnreachable);
  });

  test('a proxied site with no host refuses as misconfigured', () {
    final decision = resolveRoute(_site(host: null), proxyReachable: true);
    expect((decision as RouteRefused).failure, RouteFailure.misconfigured);
  });

  test('an http-proxy site routes through the proxy, mode intact', () {
    // Android has no HTTP-proxy support in java.net.Socket, but the native
    // Router no longer needs it: HttpConnectTunnel issues the CONNECT by
    // hand. This model must agree, or the site would be refused here before
    // the engine ever got the chance.
    final decision = resolveRoute(_site(mode: ProxyMode.http), proxyReachable: true);
    expect(decision, isA<RouteProxy>());
    decision as RouteProxy;
    expect(decision.host, '127.0.0.1');
    expect(decision.port, 9050);
    expect(decision.mode, ProxyMode.http);
  });

  test('unreachable and refused read differently to the user', () {
    expect(refusalMessage(RouteFailure.proxyUnreachable),
        isNot(refusalMessage(RouteFailure.proxyRefused)));
  });

  group('Tor', () {
    const site = Site(
      id: 's', workspaceId: 'w', name: 'n', monogram: 'Nn',
      url: 'https://a.example', profileId: 'p', proxyMode: ProxyMode.tor,
    );

    test('Tor up routes through Tor', () {
      expect(resolveRoute(site, proxyReachable: true), isA<RouteTor>());
    });

    test('Tor down is refused as torFailed, never direct', () {
      final decision = resolveRoute(site, proxyReachable: false);
      expect((decision as RouteRefused).failure, RouteFailure.torFailed);
    });

    test('its refusal reads Tor did not connect', () {
      expect(refusalMessage(RouteFailure.torFailed), 'Tor did not connect');
    });
  });
}

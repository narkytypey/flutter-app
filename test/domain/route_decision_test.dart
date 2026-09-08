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

  test('an http-proxy site refuses, because Android cannot open one at all', () {
    // AOSP removed HTTP-proxy support from java.net.Socket, so the native
    // Router cannot honour ProxyMode.http on any device. Refusing at resolve
    // time keeps this model honest with the engine, and means the user is
    // told the configuration is wrong instead of being shown a spurious
    // "destination did not respond" after the request fails late.
    final decision = resolveRoute(_site(mode: ProxyMode.http), proxyReachable: true);
    expect(decision, isA<RouteRefused>());
    expect((decision as RouteRefused).failure, RouteFailure.misconfigured);
  });

  test('unreachable and refused read differently to the user', () {
    expect(refusalMessage(RouteFailure.proxyUnreachable),
        isNot(refusalMessage(RouteFailure.proxyRefused)));
  });
}

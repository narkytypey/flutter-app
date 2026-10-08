import 'package:container/domain/models/route_display.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(ProxyMode mode, {String url = 'https://forum.example.com', String? host, int? port}) => Site(
      id: 's', workspaceId: 'w', name: 'Forum', monogram: 'Fr', url: url,
      profileId: 'p', proxyMode: mode, proxyHost: host, proxyPort: port,
    );

void main() {
  // Plan D6: Tor is a name, so it reads `Tor` wherever a route is named.
  test('the top bar names no direct route, Tor as Tor, and proxies in capitals', () {
    expect(topBarRouteLabel(ProxyMode.direct, CaseKind.keep), '');
    expect(topBarRouteLabel(ProxyMode.socks5, CaseKind.keep), 'SOCKS5');
    expect(topBarRouteLabel(ProxyMode.http, CaseKind.keep), 'HTTP');
    expect(topBarRouteLabel(ProxyMode.tor, CaseKind.keep), 'Tor');
  });

  // The user's ruling of 2026-10-08 (restyle v2 spec §12 Q4): the pill says
  // the case in words as well as in the case mark's shape. No new word —
  // `THROWAWAY` is `address_suggestion.dart`'s tag and `Wipe on exit` is `2a`
  // and `6c`'s copy — and the all-capitals tag keeps saying `TOR`, which is
  // the rule this file already states for the throwaway tag.
  test('a throwaway says so in the pill, with its route', () {
    expect(topBarRouteLabel(ProxyMode.direct, CaseKind.throwaway), 'THROWAWAY');
    expect(topBarRouteLabel(ProxyMode.socks5, CaseKind.throwaway), 'THROWAWAY · SOCKS5');
    expect(topBarRouteLabel(ProxyMode.http, CaseKind.throwaway), 'THROWAWAY · HTTP');
    expect(topBarRouteLabel(ProxyMode.tor, CaseKind.throwaway), 'THROWAWAY · TOR');
  });

  test('a wipe-on-exit site says so in the pill, with its route', () {
    expect(topBarRouteLabel(ProxyMode.direct, CaseKind.wipe), 'WIPE ON EXIT');
    expect(topBarRouteLabel(ProxyMode.socks5, CaseKind.wipe), 'WIPE ON EXIT · SOCKS5');
    expect(topBarRouteLabel(ProxyMode.http, CaseKind.wipe), 'WIPE ON EXIT · HTTP');
    expect(topBarRouteLabel(ProxyMode.tor, CaseKind.wipe), 'WIPE ON EXIT · TOR');
  });

  test("2c's line names Tor as Tor and the rest as before", () {
    expect(switcherRouteName(ProxyMode.socks5), 'socks5');
    expect(switcherRouteName(ProxyMode.direct), 'direct');
    expect(switcherRouteName(ProxyMode.tor), 'Tor');
  });

  test("6c's proxy row", () {
    expect(proxyDescriptor(_site(ProxyMode.direct)), 'Direct');
    expect(proxyDescriptor(_site(ProxyMode.socks5, host: '127.0.0.1', port: 9050)), 'SOCKS5 · 127.0.0.1:9050');
    expect(proxyDescriptor(_site(ProxyMode.http, host: 'proxy.lan', port: 3128)), 'HTTP · proxy.lan:3128');
    expect(proxyDescriptor(_site(ProxyMode.tor)), 'Tor');
  });

  test("8b's Tunnel row", () {
    expect(tunnelDescriptor(_site(ProxyMode.tor)), 'Tor');
    expect(tunnelDescriptor(_site(ProxyMode.socks5, host: '127.0.0.1', port: 9050)), 'socks5 · 127.0.0.1:9050');
    expect(tunnelDescriptor(_site(ProxyMode.socks5)), 'no proxy');
  });

  // Spec §5.6.
  test('an onion address is never offered without the tunnel; a proxied one is', () {
    expect(canOpenWithoutTunnel(_site(ProxyMode.tor, url: 'http://abc.onion/')), isFalse);
    expect(canOpenWithoutTunnel(_site(ProxyMode.tor)), isTrue);
    expect(canOpenWithoutTunnel(_site(ProxyMode.socks5, host: 'h', port: 1)), isTrue);
  });

  test('a direct site has no tunnel to open without', () {
    expect(canOpenWithoutTunnel(_site(ProxyMode.direct)), isFalse);
  });

  // Spec §5.4.
  test('WebRTC is locked on Tor only', () {
    expect(webRtcLocked(ProxyMode.tor), isTrue);
    for (final mode in [ProxyMode.direct, ProxyMode.socks5, ProxyMode.http]) {
      expect(webRtcLocked(mode), isFalse);
    }
  });
}

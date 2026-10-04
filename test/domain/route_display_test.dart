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
    expect(topBarRouteLabel(ProxyMode.direct), '');
    expect(topBarRouteLabel(ProxyMode.socks5), 'SOCKS5');
    expect(topBarRouteLabel(ProxyMode.http), 'HTTP');
    expect(topBarRouteLabel(ProxyMode.tor), 'Tor');
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
  test('an onion address is never offered without the tunnel; any other is', () {
    expect(canOpenWithoutTunnel(_site(ProxyMode.tor, url: 'http://abc.onion/')), isFalse);
    expect(canOpenWithoutTunnel(_site(ProxyMode.tor)), isTrue);
    expect(canOpenWithoutTunnel(_site(ProxyMode.socks5, host: 'h', port: 1)), isTrue);
  });

  // Spec §5.4.
  test('WebRTC is locked on Tor only', () {
    expect(webRtcLocked(ProxyMode.tor), isTrue);
    for (final mode in [ProxyMode.direct, ProxyMode.socks5, ProxyMode.http]) {
      expect(webRtcLocked(mode), isFalse);
    }
  });
}

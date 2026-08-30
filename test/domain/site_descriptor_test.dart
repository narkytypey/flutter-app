import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/site_descriptor.dart';

Site _site({
  CookiePolicy cookies = CookiePolicy.keep,
  ProxyMode proxy = ProxyMode.direct,
  bool requirePin = false,
}) {
  return Site(
    id: 's',
    workspaceId: 'w',
    name: 'Site',
    monogram: 'St',
    url: 'https://example.com',
    profileId: 'p',
    cookiePolicy: cookies,
    proxyMode: proxy,
    requirePin: requirePin,
  );
}

void main() {
  test('a plain site reads as direct', () {
    expect(siteDescriptor(_site()), 'direct');
  });

  test('a proxied site names its scheme', () {
    expect(siteDescriptor(_site(proxy: ProxyMode.socks5)), 'socks5');
    expect(siteDescriptor(_site(proxy: ProxyMode.http)), 'http');
  });

  test('wiping cookies reads as ephemeral and outranks the proxy', () {
    expect(siteDescriptor(_site(cookies: CookiePolicy.wipeOnExit)), 'ephemeral');
    expect(
      siteDescriptor(_site(cookies: CookiePolicy.wipeOnExit, proxy: ProxyMode.socks5)),
      'ephemeral',
    );
  });

  test('a PIN requirement outranks everything', () {
    expect(
      siteDescriptor(_site(
        requirePin: true,
        cookies: CookiePolicy.wipeOnExit,
        proxy: ProxyMode.socks5,
      )),
      'pin required',
    );
  });
}

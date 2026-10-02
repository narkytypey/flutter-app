import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // `8b`'s "Open without the tunnel": one direct visit in the site's own
  // container, and nothing of the proxy carried into it.
  test('withoutProxy drops the proxy and its login, and keeps everything else', () {
    final site = Site(
      id: 's1', workspaceId: 'ws', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      proxyUser: 'alice', proxyPassword: 's3cret', proxyLoginPerSite: true,
      cookiePolicy: CookiePolicy.wipeOnExit, blockTrackers: false, allowCamera: true,
      userAgentMode: UserAgentMode.desktop, forceDark: false, pageZoom: 120,
      customCss: 'a{}', customJs: 'x()', requirePin: true, showInDecoy: true,
      lastVisitedAt: DateTime.utc(2026, 10, 2), sortIndex: 4,
    );

    final direct = site.withoutProxy();

    expect(direct.proxyMode, ProxyMode.direct);
    expect(direct.proxyHost, isNull);
    expect(direct.proxyPort, isNull);
    expect(direct.proxyUser, isNull);
    expect(direct.proxyPassword, isNull);
    expect(direct.proxyLoginPerSite, isFalse);

    expect(direct.id, 's1');
    expect(direct.profileId, 'p1');
    expect(direct.url, site.url);
    expect(direct.cookiePolicy, CookiePolicy.wipeOnExit);
    expect(direct.blockTrackers, isFalse);
    expect(direct.allowCamera, isTrue);
    expect(direct.userAgentMode, UserAgentMode.desktop);
    expect(direct.forceDark, isFalse);
    expect(direct.pageZoom, 120);
    expect(direct.customCss, 'a{}');
    expect(direct.customJs, 'x()');
    expect(direct.requirePin, isTrue);
    expect(direct.showInDecoy, isTrue);
    expect(direct.lastVisitedAt, site.lastVisitedAt);
    expect(direct.sortIndex, 4);
  });
}

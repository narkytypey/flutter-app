import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/add_site/view_models/add_site_view.dart';
import 'package:flutter_test/flutter_test.dart';

Site _build({required String url, ProxyMode mode = ProxyMode.direct, String? host, int? port}) => buildSite(
      initial: null, url: url, name: 'Hidden', monogram: 'Hd', workspaceId: 'w',
      cookiePolicy: CookiePolicy.keep, proxyMode: mode, proxyHost: host, proxyPort: port,
      blockWebRtc: true, blockTrackers: true, antiFingerprinting: true,
      allowCamera: false, allowMicrophone: false, allowLocation: false, allowClipboard: false,
      requirePin: false, showInDecoy: false, userAgentMode: UserAgentMode.android,
      forceDark: true, openInReader: false, pageZoom: 100, customCss: '', customJs: '',
    );

void main() {
  group('buildSite', () {
    test('a Tor site keeps no address and no typed login', () {
      final site = _build(url: 'https://example.com', mode: ProxyMode.tor, host: '127.0.0.1', port: 9050);
      expect(site.proxyMode, ProxyMode.tor);
      expect(site.proxyHost, isNull);
      expect(site.proxyPort, isNull);
      expect(site.proxyUser, isNull);
    });

    // Spec §5.3, plan D7.
    test('an onion address is never saved on Direct', () {
      final site = _build(url: 'http://abc.onion/');
      expect(site.proxyMode, ProxyMode.tor);
      expect(site.proxyHost, isNull);
    });

    test('an onion address on a proxy keeps that proxy', () {
      final site = _build(url: 'http://abc.onion/', mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050);
      expect(site.proxyMode, ProxyMode.socks5);
      expect(site.proxyPort, 9050);
    });
  });
}

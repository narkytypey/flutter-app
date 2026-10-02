import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/throwaway.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:flutter_test/flutter_test.dart';

/// A site with every setting moved off its default, so inheritance shows.
final _current = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p-forum',
  blockWebRtc: false, blockTrackers: false, antiFingerprinting: false,
  allowCamera: true, allowMicrophone: true, allowLocation: true,
  allowClipboard: true, userAgentMode: UserAgentMode.desktop,
  forceDark: false, openInReader: true, pageZoom: 150,
  customCss: 'a{}', customJs: 'x()', cookiePolicy: CookiePolicy.keep,
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
  proxyUser: 'alice', proxyPassword: 's3cret',
  requirePin: true, showInDecoy: true,
  lastVisitedAt: DateTime(2026, 9, 1), sortIndex: 4,
);

Site _build() {
  final destination = destinationFor(
    Uri.parse('https://news.example.org/today'),
    current: _current,
    saved: const [],
  ) as Throwaway;
  var next = 0;
  return buildThrowaway(
    destination: destination,
    current: _current,
    newId: () => 'id${next++}',
  );
}

void main() {
  test('only the route is inherited; everything else is the safe default', () {
    final throwaway = _build();
    const defaults = Site(
        id: '', workspaceId: '', name: '', monogram: '', url: '', profileId: '');

    expect(throwaway.id, 'id0');
    expect(throwaway.profileId, 'id1');
    expect(throwaway.workspaceId, 'w1');
    expect(throwaway.name, 'news.example.org');
    expect(throwaway.monogram, 'Nw');
    expect(throwaway.url, 'https://news.example.org/today');
    expect(throwaway.cookiePolicy, CookiePolicy.wipeOnExit);
    expect(throwaway.proxyMode, ProxyMode.socks5);
    expect(throwaway.proxyHost, '127.0.0.1');
    expect(throwaway.proxyPort, 9050);
    expect(throwaway.proxyUser, 'alice');
    expect(throwaway.proxyPassword, 's3cret');
    expect(throwaway.proxyLoginPerSite, isFalse);

    expect(throwaway.blockWebRtc, defaults.blockWebRtc);
    expect(throwaway.blockTrackers, defaults.blockTrackers);
    expect(throwaway.antiFingerprinting, defaults.antiFingerprinting);
    expect(throwaway.allowCamera, defaults.allowCamera);
    expect(throwaway.allowMicrophone, defaults.allowMicrophone);
    expect(throwaway.allowLocation, defaults.allowLocation);
    expect(throwaway.allowClipboard, defaults.allowClipboard);
    expect(throwaway.userAgentMode, defaults.userAgentMode);
    expect(throwaway.forceDark, defaults.forceDark);
    expect(throwaway.openInReader, defaults.openInReader);
    expect(throwaway.pageZoom, defaults.pageZoom);
    expect(throwaway.customCss, defaults.customCss);
    expect(throwaway.customJs, defaults.customJs);
    expect(throwaway.requirePin, defaults.requirePin);
    expect(throwaway.showInDecoy, defaults.showInDecoy);
    expect(throwaway.lastVisitedAt, isNull);
    expect(throwaway.sortIndex, 0);
  });

  test('a throwaway from a per-site container is per-site, on its own profile', () {
    final destination = destinationFor(
      Uri.parse('https://news.example.org/today'),
      current: _current.copyWith(proxyLoginPerSite: true),
      saved: const [],
    ) as Throwaway;
    var next = 0;
    final throwaway = buildThrowaway(
        destination: destination, current: _current, newId: () => 'id${next++}');

    expect(throwaway.proxyLoginPerSite, isTrue);
    expect(throwaway.profileId, isNot(_current.profileId),
        reason: 'its own profile id gives it its own login (spec §4)');
  });

  test('it never takes a library script applied to the site it was typed in', () {
    const script = UserScript(
      id: 'sc', name: 'Hide', kind: ScriptKind.css, code: 'a{}',
      runAtDocumentStart: false, enabled: true, appliedSiteIds: ['forum'],
    );
    expect(selectUserScripts(_build(), const [script]), isEmpty);
  });
}

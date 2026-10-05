import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/route_failure_copy.dart';

void main() {
  test('the one failure the spec draws gets its exact pinned headline', () {
    expect(proxyFailureHeadline(RouteFailure.proxyUnreachable), 'Proxy did not answer');
  });

  test('every other failure headlines with Plan 3\'s refusalMessage', () {
    for (final failure in RouteFailure.values) {
      if (failure == RouteFailure.proxyUnreachable) continue;
      expect(proxyFailureHeadline(failure), refusalMessage(failure));
    }
  });

  test('the pinned detail sentence matches the spec\'s Forum example verbatim', () {
    expect(
      proxyFailureDetail(
        RouteFailure.proxyUnreachable,
        siteName: 'Forum',
        tunnelDescriptor: 'SOCKS5 at 127.0.0.1:9050',
      ),
      'Forum is set to go through SOCKS5 at 127.0.0.1:9050 and nothing is '
      'listening there. The page was not loaded, so no request left your device.',
    );
  });

  test('every failure with a tunnel names the site and ends on the same reassurance', () {
    for (final failure in RouteFailure.values) {
      if (failure == RouteFailure.misconfigured ||
          failure == RouteFailure.unsupported ||
          failure == RouteFailure.openFailed) {
        continue;
      }
      final detail = proxyFailureDetail(failure, siteName: 'Forum', tunnelDescriptor: 'the tunnel');
      expect(detail, contains('Forum'));
      expect(detail, endsWith('The page was not loaded, so no request left your device.'));
    }
  });

  test('unsupported says what is wrong and what to do, in the approved words', () {
    // P2 spec §3.3, approved by the user on 2026-09-30.
    expect(proxyFailureHeadline(RouteFailure.unsupported), 'This phone cannot route sites through a proxy');
    expect(
      proxyFailureDetail(RouteFailure.unsupported, siteName: 'Forum', tunnelDescriptor: 'the tunnel'),
      'Update Android System WebView to open proxied sites.',
    );
  });

  test('a failed open says so, in the approved words, and names no tunnel', () {
    // User's ruling, 2026-10-05: the app's own failure, not the network's.
    expect(proxyFailureHeadline(RouteFailure.openFailed), 'This site could not be opened');
    expect(
      proxyFailureDetail(RouteFailure.openFailed, siteName: 'Forum', tunnelDescriptor: 'the tunnel'),
      'Something went wrong before the page loaded. '
      'The page was not loaded, so no request left your device.',
    );
  });

  test('misconfigured has no detail sentence, because the spec writes none', () {
    // Its headline already says there is no proxy configured; the generic
    // sentence would then name the tunnel the site goes through. Rather than
    // invent copy the spec never wrote, the screen shows the headline alone.
    expect(
      proxyFailureDetail(
        RouteFailure.misconfigured,
        siteName: 'Forum',
        tunnelDescriptor: 'the tunnel',
      ),
      isNull,
    );
  });

  test('a rejected login has its own headline and the generic sentence', () {
    expect(proxyFailureHeadline(RouteFailure.proxyLoginRejected), 'The proxy rejected the login');
    expect(
      proxyFailureDetail(RouteFailure.proxyLoginRejected,
          siteName: 'Forum', tunnelDescriptor: 'socks5 · 127.0.0.1:9050'),
      'Forum is set to go through socks5 · 127.0.0.1:9050, which did not complete '
      'the connection. The page was not loaded, so no request left your device.',
    );
  });

  test("Tor's failure has the approved headline and sentence", () {
    // Built-in Tor spec §7, approved word for word on 2026-10-04.
    expect(proxyFailureHeadline(RouteFailure.torFailed), 'Tor did not connect');
    expect(
      proxyFailureDetail(RouteFailure.torFailed, siteName: 'Forum', tunnelDescriptor: 'Tor'),
      'Forum is set to go through Tor, which could not reach the Tor network. '
      'The page was not loaded, so no request left your device.',
    );
  });
}

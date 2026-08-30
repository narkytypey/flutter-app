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
      if (failure == RouteFailure.misconfigured) continue;
      final detail = proxyFailureDetail(failure, siteName: 'Forum', tunnelDescriptor: 'the tunnel');
      expect(detail, contains('Forum'));
      expect(detail, endsWith('The page was not loaded, so no request left your device.'));
    }
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
}

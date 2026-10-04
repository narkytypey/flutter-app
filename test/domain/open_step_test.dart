import 'package:container/domain/models/open_step.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site({
  ProxyMode mode = ProxyMode.socks5,
  bool trackers = true,
  bool fingerprint = true,
}) =>
    Site(
      id: 's',
      workspaceId: 'w',
      name: 'Forum',
      monogram: 'Fr',
      url: 'https://forum.example.com',
      profileId: 'a' * 32,
      proxyMode: mode,
      proxyHost: '127.0.0.1',
      proxyPort: 9050,
      blockTrackers: trackers,
      antiFingerprinting: fingerprint,
    );

void main() {
  test('the checklist names the real endpoint', () {
    final steps = openStepsFor(_site());
    expect(steps.map((s) => s.label), [
      'Fresh session, no shared cookies',
      'Filter lists loaded',
      'Fingerprint noise injected',
      'Connecting through 127.0.0.1:9050',
    ]);
  });

  test('a direct site shows no tunnel line', () {
    final steps = openStepsFor(_site(mode: ProxyMode.direct));
    expect(steps.any((s) => s.label.startsWith('Connecting')), isFalse);
  });

  test('shields that are off do not appear', () {
    final steps = openStepsFor(_site(trackers: false, fingerprint: false));
    expect(steps, hasLength(2));
  });

  group('Tor', () {
    test('a Tor site connects to Tor, not to an address', () {
      final steps = openStepsFor(_site(mode: ProxyMode.tor));
      expect(steps.last.label, 'Connecting to Tor');
      expect(steps.any((s) => s.label.startsWith('Connecting through')), isFalse);
    });

    test("it shows Tor's own percentage while Tor starts", () {
      expect(openStepsFor(_site(mode: ProxyMode.tor), torPercent: 45).last.label, 'Connecting to Tor · 45%');
    });

    // Review Focus 5: 0 has nothing to say, and 100 is a start already over.
    test('no percentage before a report, at 0 or at 100', () {
      expect(torStepLabel(null), 'Connecting to Tor');
      expect(torStepLabel(0), 'Connecting to Tor');
      expect(torStepLabel(100), 'Connecting to Tor');
      expect(torStepLabel(99), 'Connecting to Tor · 99%');
    });

    test('a percentage is ignored for any other route', () {
      expect(openStepsFor(_site(), torPercent: 45).last.label, 'Connecting through 127.0.0.1:9050');
    });
  });
}

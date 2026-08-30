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
}

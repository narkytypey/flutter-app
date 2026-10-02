// test/domain/security_level_test.dart
import 'package:container/domain/models/security_level.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = Site(
  id: 's', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p',
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
  proxyUser: 'alice', proxyPassword: 'pw', blockWebRtc: false,
);

void main() {
  test('the copy is spec §5, verbatim', () {
    expect(SecurityLevel.values.map((l) => l.label), ['Standard', 'Safer', 'Safest']);
    expect(SecurityLevel.values.map((l) => l.meta), ['STANDARD', 'SAFER', 'SAFEST']);
    expect(SecurityLevel.values.map((l) => l.description), [
      'Every site feature is on',
      'JavaScript off on http pages · no WebGL or WebAssembly',
      'JavaScript and images off on every page',
    ]);
  });

  test('a stored name reads back; nothing stored is null; anything else is safest', () {
    for (final level in SecurityLevel.values) {
      expect(SecurityLevel.fromStored(level.name), level);
    }
    expect(SecurityLevel.fromStored(null), isNull);
    expect(SecurityLevel.fromStored('Safer'), SecurityLevel.safest, reason: 'fails closed');
    expect(SecurityLevel.fromStored(''), SecurityLevel.safest);
  });

  test('the vault default is Standard until one is stored, and fails closed', () {
    expect(SecurityLevel.vaultDefaultFrom(null), SecurityLevel.standard);
    expect(SecurityLevel.vaultDefaultFrom('safer'), SecurityLevel.safer);
    expect(SecurityLevel.vaultDefaultFrom('bogus'), SecurityLevel.safest);
  });

  test('a site follows the default until it has its own level', () {
    expect(effectiveLevel(_site, SecurityLevel.safer), SecurityLevel.safer);
    final own = _site.withSecurityLevel(SecurityLevel.safest);
    expect(effectiveLevel(own, SecurityLevel.standard), SecurityLevel.safest);
  });

  test("6c's value marks a followed default", () {
    expect(securityLevelValue(_site, SecurityLevel.standard), 'Standard · default');
    expect(securityLevelValue(_site.withSecurityLevel(SecurityLevel.safer), SecurityLevel.standard),
        'Safer');
  });

  test('withSecurityLevel sets and clears, and keeps every other field', () {
    final set = _site.withSecurityLevel(SecurityLevel.safer);
    expect(set.securityLevel, SecurityLevel.safer);
    final cleared = set.withSecurityLevel(null);
    expect(cleared.securityLevel, isNull);
    expect(cleared.proxyUser, 'alice');
    expect(cleared.proxyPort, 9050);
    expect(cleared.blockWebRtc, isFalse);
    expect(cleared.profileId, 'p');
  });

  test('copyWith and withoutProxy keep the level', () {
    final own = _site.withSecurityLevel(SecurityLevel.safest);
    expect(own.copyWith(profileId: 'q').securityLevel, SecurityLevel.safest);
    expect(own.withoutProxy().securityLevel, SecurityLevel.safest);
  });

  test('a new site follows the default', () {
    expect(_site.securityLevel, isNull);
  });
}

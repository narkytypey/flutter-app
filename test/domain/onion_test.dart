import 'package:container/domain/onion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Review Focus 4.
  test('an onion host is one in any case, with or without a trailing dot', () {
    expect(isOnionHost('duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion'), isTrue);
    expect(isOnionHost('ABC.ONION.'), isTrue);
    expect(isOnionHost('www.abc.onion'), isTrue);
    expect(isOnionHost('onion'), isTrue);
  });

  test('other hosts are not', () {
    expect(isOnionHost('onion.example.com'), isFalse);
    expect(isOnionHost('example.com'), isFalse);
    expect(isOnionHost('notonion'), isFalse);
    expect(isOnionHost(''), isFalse);
  });
}

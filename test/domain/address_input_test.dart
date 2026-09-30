import 'package:container/domain/models/address_input.dart';
import 'package:flutter_test/flutter_test.dart';

String? _url(String raw) {
  final input = parseAddressInput(raw);
  return input is AddressUrl ? input.url.toString() : null;
}

String? _search(String raw) {
  final input = parseAddressInput(raw);
  return input is AddressSearch ? input.query : null;
}

void main() {
  test('nothing but whitespace is empty', () {
    expect(parseAddressInput(''), isA<AddressEmpty>());
    expect(parseAddressInput('   \t'), isA<AddressEmpty>());
  });

  test('anything containing whitespace is a search, trimmed', () {
    expect(_search('  privacy tools  '), 'privacy tools');
    expect(_search('example.com/a b'), 'example.com/a b');
  });

  test('an explicit http or https address is kept as typed, never upgraded', () {
    expect(_url('https://forum.example.com/t/1?page=2#top'),
        'https://forum.example.com/t/1?page=2#top');
    expect(_url('http://forum.example.com'), 'http://forum.example.com');
  });

  test('an explicit http or https scheme with no host is a search', () {
    expect(_search('https://'), 'https://');
    expect(_search('http:///path'), 'http:///path');
  });

  test('every other scheme is a search, never an address', () {
    for (final raw in [
      'javascript:alert(1)',
      'file:///etc/hosts',
      'about:blank',
      'intent://scan/#Intent;scheme=zxing;end',
      'content://media/external/images/1',
      'data:text/html,hi',
      'mailto:a@example.com',
      'ftp://example.com',
    ]) {
      expect(parseAddressInput(raw), isA<AddressSearch>(), reason: raw);
    }
  });

  // Review Focus 3.
  test('case and surrounding whitespace do not smuggle a scheme through', () {
    for (final raw in [
      '  JavaScript:alert(1)',
      'JAVASCRIPT:alert(document.cookie)',
      'FILE:///etc/hosts',
      'http://javascript:alert(1)',
    ]) {
      expect(parseAddressInput(raw), isA<AddressSearch>(), reason: raw);
    }
  });

  test('a bare host is tried over https', () {
    expect(_url('forum.example.com'), 'https://forum.example.com');
    expect(_url('  Forum.Example.COM  '), 'https://forum.example.com');
  });

  test('ports, paths, queries and fragments come along', () {
    expect(_url('example.com:8080/a/b?c=1#d'), 'https://example.com:8080/a/b?c=1#d');
    expect(_url('example.com?q=1'), 'https://example.com?q=1');
  });

  test('localhost and IPv4 literals are addresses', () {
    expect(_url('localhost'), 'https://localhost');
    expect(_url('localhost:3000/api'), 'https://localhost:3000/api');
    expect(_url('192.168.1.10'), 'https://192.168.1.10');
    expect(_url('10.0.2.2:8888/x'), 'https://10.0.2.2:8888/x');
  });

  test('what only looks like a host is a search', () {
    for (final raw in [
      'example',
      'example.c',
      'example.123',
      '999.1.1.1',
      'example.com:99999',
      'user@example.com',
      '-bad.example.com',
    ]) {
      expect(parseAddressInput(raw), isA<AddressSearch>(), reason: raw);
    }
  });
}

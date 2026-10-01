import 'package:container/domain/idn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Vectors from RFC 3492 §7.1 and the IANA IDN test TLDs.
  test('a Unicode label becomes xn-- plus its punycode', () {
    expect(hostToAscii('münchen.de'), 'xn--mnchen-3ya.de');
    expect(hostToAscii('bücher.example'), 'xn--bcher-kva.example');
    expect(hostToAscii('ü.com'), 'xn--tda.com');
    expect(hostToAscii('例子.测试'), 'xn--fsqu00a.xn--0zwm56d');
    expect(hostToAscii('пример.испытание'), 'xn--e1afmkfd.xn--80akhbyknj4f');
  });

  test('ASCII labels pass through, lower-cased', () {
    expect(hostToAscii('Forum.Example.COM'), 'forum.example.com');
    expect(hostToAscii('MÜNCHEN.DE'), 'xn--mnchen-3ya.de');
  });

  test('a label longer than 63 once encoded has no ASCII form', () {
    expect(hostToAscii('${'ü' * 60}.de'), isNull);
  });
}

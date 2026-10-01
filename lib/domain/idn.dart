/// A host's ASCII form, as DNS and the engine see it (user's ruling,
/// 2026-10-02: a typed Unicode host opens as an address). Pure Dart, no
/// dependency.
///
/// Each label is lower-cased; a label with any non-ASCII character becomes
/// `xn--` plus its punycode (RFC 3492). Null when an encoded label is longer
/// than 63 characters, which DNS cannot carry. Not full IDNA: there is no
/// Unicode normalization or mapping beyond lower-casing, so input is taken as
/// the keyboard composed it.
String? hostToAscii(String host) {
  final labels = <String>[];
  for (final label in host.toLowerCase().split('.')) {
    final ascii = label.runes.every((c) => c < 0x80) ? label : 'xn--${_punycode(label)}';
    if (ascii.length > 63) return null;
    labels.add(ascii);
  }
  return labels.join('.');
}

// RFC 3492 §5 parameters.
const _base = 36, _tMin = 1, _tMax = 26, _skew = 38, _damp = 700;
const _initialBias = 72, _initialN = 0x80;

/// RFC 3492 §6.3, the encoding procedure.
String _punycode(String label) {
  final input = label.runes.toList();
  final out = StringBuffer();
  for (final c in input) {
    if (c < 0x80) out.writeCharCode(c);
  }
  final basic = out.length;
  var handled = basic;
  if (basic > 0) out.write('-');

  var n = _initialN, delta = 0, bias = _initialBias;
  while (handled < input.length) {
    final m = input.where((c) => c >= n).reduce((a, b) => a < b ? a : b);
    delta += (m - n) * (handled + 1);
    n = m;
    for (final c in input) {
      if (c < n) delta++;
      if (c != n) continue;
      var q = delta;
      for (var k = _base; ; k += _base) {
        final t = k <= bias ? _tMin : (k >= bias + _tMax ? _tMax : k - bias);
        if (q < t) break;
        out.writeCharCode(_digit(t + (q - t) % (_base - t)));
        q = (q - t) ~/ (_base - t);
      }
      out.writeCharCode(_digit(q));
      bias = _adapt(delta, handled + 1, handled == basic);
      delta = 0;
      handled++;
    }
    delta++;
    n++;
  }
  return out.toString();
}

int _digit(int d) => d < 26 ? 0x61 + d : 0x30 + d - 26;

int _adapt(int delta, int points, bool first) {
  delta = first ? delta ~/ _damp : delta ~/ 2;
  delta += delta ~/ points;
  var k = 0;
  while (delta > ((_base - _tMin) * _tMax) ~/ 2) {
    delta ~/= _base - _tMin;
    k += _base;
  }
  return k + (_base - _tMin + 1) * delta ~/ (delta + _skew);
}

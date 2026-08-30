const _vowels = {'a', 'e', 'i', 'o', 'u'};

/// Suggests the two-letter monogram for a newly added site: the first letter,
/// then the next consonant after it.
///
/// This is only a suggestion. `Site.monogram` is stored, and the Add site
/// screen lets the user replace it — which is why the seeded sites can carry
/// the design's hand-picked values (`Webmail` → `Wm`) that no rule produces.
String suggestMonogram(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';

  final first = trimmed[0].toUpperCase();
  if (trimmed.length == 1) return first;

  for (var i = 1; i < trimmed.length; i++) {
    final ch = trimmed[i].toLowerCase();
    if (!_isLetter(ch)) continue;
    if (!_vowels.contains(ch)) return '$first$ch';
  }

  return '$first${trimmed[1].toLowerCase()}';
}

bool _isLetter(String ch) {
  final c = ch.codeUnitAt(0);
  return c >= 0x61 && c <= 0x7A;
}

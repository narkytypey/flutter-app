import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Restyle spec §6: every icon is an `AppIcon`. These are the glyphs the
/// restyle replaced. One inside a string literal means a mark is being drawn
/// as text again.
///
/// Typographic characters that copy uses are deliberately absent, so copy
/// passes: `·` ("13.0 KB · from …"), `—`, `→`, `“ ”`, and `+` (`+ Add site`
/// is a label, user's ruling 2026-10-02).
const iconGlyphs = '‹›×⟳◑◉◇☉⛌✓⋯▲▼⌕☰≡⌫';

/// `⌫` is the keypad's key *value*, compared as data. Only these files may
/// hold it.
const keyValueFiles = {
  'lib/ui/core/widgets/pin_keypad.dart',
  'lib/ui/features/lock/view_models/lock_controller.dart',
  'lib/ui/features/shell/views/setup_flow.dart',
  'lib/ui/features/settings/views/change_pin_route.dart',
};

/// One open string literal, or one `${…}` inside a string.
sealed class _Frame {}

class _Str extends _Frame {
  _Str(this.quote, {required this.triple, required this.raw});
  final String quote;
  final bool triple;
  final bool raw;
}

class _Interp extends _Frame {
  int braces = 0;
}

final _escape = RegExp(r'^u(?:\{([0-9a-fA-F]+)\}|([0-9a-fA-F]{4}))');
final _identifier = RegExp(r'[A-Za-z0-9_$]');

/// Splits Dart [source] into, per line, its code (outside strings and
/// comments) and the text inside its string literals. It follows the
/// language far enough not to be fooled: a `//` inside a string is not a
/// comment; `/* … */` is; a string nested in a `${…}` is a string again; a
/// triple-quoted string runs across lines; and a backslash-u escape (outside
/// a raw string) counts as the character it names.
List<({String code, String literals})> scanSource(String source) {
  final lines = <({String code, String literals})>[];
  var code = StringBuffer();
  var literals = StringBuffer();
  final stack = <_Frame>[];
  var lineComment = false;
  var blockComment = false;

  for (var i = 0; i < source.length; i++) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';
    if (c == '\n') {
      lines.add((code: code.toString(), literals: literals.toString()));
      code = StringBuffer();
      literals = StringBuffer();
      lineComment = false;
      // A single-quoted string cannot cross a line: drop an unclosed one
      // rather than let a stray quote swallow the rest of the file.
      while (stack.isNotEmpty) {
        final last = stack.last;
        if (last is _Str && last.triple) break;
        stack.removeLast();
      }
      continue;
    }
    final top = stack.isEmpty ? null : stack.last;
    if (top is _Str) {
      if (!top.raw && c == r'\') {
        final match = _escape.firstMatch(source.substring(i + 1));
        if (match != null) {
          literals.writeCharCode(int.parse(match.group(1) ?? match.group(2)!, radix: 16));
          i += match.group(0)!.length;
        } else {
          i++;
        }
      } else if (!top.raw && c == r'$' && next == '{') {
        stack.add(_Interp());
        i++;
      } else if (top.triple ? source.startsWith(top.quote * 3, i) : c == top.quote) {
        stack.removeLast();
        if (top.triple) i += 2;
      } else {
        literals.write(c);
      }
      continue;
    }
    // Code: at top level, or inside a `${…}`.
    if (lineComment) continue;
    if (blockComment) {
      if (c == '*' && next == '/') {
        blockComment = false;
        i++;
      }
      continue;
    }
    if (c == '/' && next == '/') {
      lineComment = true;
      continue;
    }
    if (c == '/' && next == '*') {
      blockComment = true;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 &&
          source[i - 1] == 'r' &&
          (i < 2 || !_identifier.hasMatch(source[i - 2]));
      final triple = source.startsWith(c * 3, i);
      stack.add(_Str(c, triple: triple, raw: raw));
      if (triple) i += 2;
      continue;
    }
    if (top is _Interp) {
      if (c == '{') top.braces++;
      if (c == '}') {
        if (top.braces == 0) {
          stack.removeLast();
          continue;
        }
        top.braces--;
      }
    }
    code.write(c);
  }
  lines.add((code: code.toString(), literals: literals.toString()));
  return lines;
}

/// Every glyph or `Icons.` use in [source], as `path:line: what`.
List<String> offences(String path, String source) {
  final found = <String>[];
  final lines = scanSource(source);
  for (var n = 0; n < lines.length; n++) {
    final (:code, :literals) = lines[n];
    if (code.contains('Icons.')) found.add('$path:${n + 1}: Icons.');
    for (final rune in literals.runes) {
      final glyph = String.fromCharCode(rune);
      if (!iconGlyphs.contains(glyph)) continue;
      if (glyph == '⌫' && keyValueFiles.contains(path)) continue;
      found.add('$path:${n + 1}: $glyph');
    }
  }
  return found;
}

void main() {
  test('nothing in lib/ draws a glyph or a Material icon', () {
    final found = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      found.addAll(offences(path, entity.readAsStringSync()));
    }
    expect(found, isEmpty, reason: 'Draw these with AppIcon (restyle spec §6).');
  });

  group('the scanner', () {
    List<String> scan(String line, {String path = 'lib/ui/x.dart'}) =>
        offences(path, line);

    test('rejects a glyph drawn as text, in either quote', () {
      expect(scan("child: Text('‹', style: s),"), hasLength(1));
      expect(scan('child: Text("◉"),'), hasLength(1));
      expect(scan("Text('\\u2039')"), hasLength(1));
      expect(scan("Text('\\u{203A}')"), hasLength(1));
    });

    test('rejects a Material icon in code, not in a string', () {
      expect(scan('const Icon(Icons.check, size: 15),'), hasLength(1));
      expect(scan("Text('Icons.check')"), isEmpty);
    });

    test('accepts the typographic characters copy uses', () {
      expect(scan("Text('13.0 KB · from forum.example.com')"), isEmpty);
      expect(scan("Text('Delete “Work”?')"), isEmpty);
      expect(scan("Text('a — b → c')"), isEmpty);
      expect(scan("label: '+ Add site',"), isEmpty);
    });

    test('ignores comments, but not a // inside a string', () {
      expect(scan("/// The `‹` glyph is gone."), isEmpty);
      expect(scan("final u = 'https://x'; // was ‹"), isEmpty);
      expect(scan("Text('https://x ‹')"), hasLength(1));
    });

    test('finds a glyph in a string nested inside an interpolation', () {
      expect(scan(r"Text('${open ? '▲' : '▼'}')"), hasLength(2));
      expect(scan(r"Text('${count} OPEN ${'›'}')"), hasLength(1));
      expect(scan(r"Text('${{'a': 1}['a']} · ok')"), isEmpty);
      expect(scan(r"final s = '$name ›';"), hasLength(1));
    });

    test("finds a glyph on a triple-quoted string's later lines, naming that line", () {
      expect(offences('lib/ui/x.dart', "final s = '''\nfirst\nsecond ‹\n''';"),
          ['lib/ui/x.dart:3: ‹']);
    });

    test('ignores block comments, and reads raw strings literally', () {
      expect(scan('/* the ‹ glyph */ final x = 1;'), isEmpty);
      expect(scan(r"final p = r'\u2039';"), isEmpty);
      expect(scan(r"final p = r'\d‹';"), hasLength(1));
    });

    test('allows ⌫ only as the keypad key value, in its four files', () {
      expect(scan("if (key == '⌫') {", path: 'lib/ui/core/widgets/pin_keypad.dart'), isEmpty);
      expect(scan("if (key == '⌫') {", path: 'lib/ui/features/lock/view_models/lock_controller.dart'),
          isEmpty);
      expect(scan("Text('⌫')", path: 'lib/ui/features/report/views/today_screen.dart'),
          hasLength(1));
    });
  });
}

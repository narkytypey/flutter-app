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

/// Splits one line of Dart into its code (outside strings and comments) and
/// the text inside its string literals. A `//` inside a string is not a
/// comment; everything after a `//` outside one is. A `‹`-style escape
/// counts as the character it names.
({String code, String literals}) scanLine(String line) {
  final code = StringBuffer();
  final literals = StringBuffer();
  final escape = RegExp(r'^u(?:\{([0-9a-fA-F]+)\}|([0-9a-fA-F]{4}))');
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote == null) {
      if (c == '/' && i + 1 < line.length && line[i + 1] == '/') break;
      if (c == "'" || c == '"') {
        quote = c;
      } else {
        code.write(c);
      }
    } else if (c == r'\') {
      final match = escape.firstMatch(line.substring(i + 1));
      if (match != null) {
        literals.writeCharCode(int.parse(match.group(1) ?? match.group(2)!, radix: 16));
        i += match.group(0)!.length;
      } else {
        i++;
      }
    } else if (c == quote) {
      quote = null;
    } else {
      literals.write(c);
    }
  }
  return (code: code.toString(), literals: literals.toString());
}

/// Every glyph or `Icons.` use in [source], as `path:line: what`.
List<String> offences(String path, String source) {
  final found = <String>[];
  final lines = source.split('\n');
  for (var n = 0; n < lines.length; n++) {
    final (:code, :literals) = scanLine(lines[n]);
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

    test('allows ⌫ only as the keypad key value, in its four files', () {
      expect(scan("if (key == '⌫') {", path: 'lib/ui/core/widgets/pin_keypad.dart'), isEmpty);
      expect(scan("if (key == '⌫') {", path: 'lib/ui/features/lock/view_models/lock_controller.dart'),
          isEmpty);
      expect(scan("Text('⌫')", path: 'lib/ui/features/report/views/today_screen.dart'),
          hasLength(1));
    });
  });
}

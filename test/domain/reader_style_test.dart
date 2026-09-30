import 'package:container/domain/models/reader_style.dart';
import 'package:flutter_test/flutter_test.dart';

/// User's ruling, 2026-09-30: reader mode's Aa cycles three text sizes and ◑
/// switches to a softer dark pair. Dark only: there is no light reader.
void main() {
  test('starts at the standard size and colours', () {
    expect(ReaderStyle.standard.size, ReaderTextSize.standard);
    expect(ReaderStyle.standard.soft, isFalse);
  });

  test('Aa cycles standard, larger, largest and back', () {
    var style = ReaderStyle.standard;
    final seen = <ReaderTextSize>[];
    for (var i = 0; i < 4; i++) {
      style = style.withNextSize();
      seen.add(style.size);
    }
    expect(seen, [ReaderTextSize.larger, ReaderTextSize.largest, ReaderTextSize.standard, ReaderTextSize.larger]);
  });

  test('each size is bigger than the last, starting at the spec\'s 15.5 and 25', () {
    expect(ReaderTextSize.standard.body, 15.5);
    expect(ReaderTextSize.standard.title, 25);
    expect(ReaderTextSize.larger.body, greaterThan(15.5));
    expect(ReaderTextSize.largest.body, greaterThan(ReaderTextSize.larger.body));
    expect(ReaderTextSize.largest.title, greaterThan(ReaderTextSize.larger.title));
  });

  test('◑ toggles the soft colours and keeps the size', () {
    final style = ReaderStyle.standard.withNextSize().withToggledContrast();
    expect(style.soft, isTrue);
    expect(style.size, ReaderTextSize.larger);
    expect(style.withToggledContrast().soft, isFalse);
  });

  test('a stored style reads back; anything else is the standard one', () {
    const style = ReaderStyle(size: ReaderTextSize.largest, soft: true);
    final back = ReaderStyle.fromStored(size: style.storedSize, contrast: style.storedContrast);
    expect(back.size, ReaderTextSize.largest);
    expect(back.soft, isTrue);
    final fallback = ReaderStyle.fromStored(size: null, contrast: 'bright');
    expect(fallback.size, ReaderTextSize.standard);
    expect(fallback.soft, isFalse);
  });
}

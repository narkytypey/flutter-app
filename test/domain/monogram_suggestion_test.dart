import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/monogram_suggestion.dart';

void main() {
  test('the suggestion is the first letter plus the next consonant', () {
    expect(suggestMonogram('Notes'), 'Nt');
    expect(suggestMonogram('Forum'), 'Fr');
    expect(suggestMonogram('Reader'), 'Rd');
    expect(suggestMonogram('Wiki'), 'Wk');
    expect(suggestMonogram('News'), 'Nw');
    expect(suggestMonogram('Weather'), 'Wt');
    expect(suggestMonogram('Recipes'), 'Rc');
  });

  test('a name with no second consonant falls back to its first two letters', () {
    expect(suggestMonogram('Idea'), 'Id');
    expect(suggestMonogram('Ai'), 'Ai');
  });

  test('a single-letter name doubles nothing', () {
    expect(suggestMonogram('X'), 'X');
  });

  test('leading whitespace and empty names are handled', () {
    expect(suggestMonogram('  scratch tab'), 'Sc');
    expect(suggestMonogram(''), '');
    expect(suggestMonogram('   '), '');
  });
}

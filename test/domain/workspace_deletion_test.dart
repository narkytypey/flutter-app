import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/workspace_deletion.dart';

void main() {
  test('the typed name must match exactly', () {
    expect(confirmsDeletion('Work', 'Work'), isTrue);
  });

  test('a partial or wrong name does not confirm', () {
    expect(confirmsDeletion('Wor', 'Work'), isFalse);
    expect(confirmsDeletion('work', 'Work'), isFalse);
    expect(confirmsDeletion('', 'Work'), isFalse);
  });

  test('surrounding whitespace is trimmed, but internal case is not', () {
    expect(confirmsDeletion('  Work  ', 'Work'), isTrue);
    expect(confirmsDeletion('WORK', 'Work'), isFalse);
  });
}

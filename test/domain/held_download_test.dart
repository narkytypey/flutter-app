import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/held_download.dart';

void main() {
  test('formats megabytes at one decimal, matching the spec\'s "1.4 MB"', () {
    expect(formatBytes(1468006), '1.4 MB');
  });

  test('formats kilobytes at one decimal', () {
    expect(formatBytes(2048), '2.0 KB');
  });

  test('formats sub-kilobyte sizes as whole bytes', () {
    expect(formatBytes(512), '512 B');
  });
}

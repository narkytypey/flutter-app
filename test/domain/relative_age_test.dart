import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/relative_age.dart';

void main() {
  final now = DateTime(2026, 8, 30, 9, 10);

  String ago(Duration d) => relativeAge(now, now.subtract(d));

  test('anything under a minute reads as now', () {
    expect(ago(Duration.zero), 'now');
    expect(ago(const Duration(seconds: 59)), 'now');
  });

  test('minutes, hours, days and weeks each get their own unit', () {
    expect(ago(const Duration(minutes: 1)), '1m');
    expect(ago(const Duration(minutes: 14)), '14m');
    expect(ago(const Duration(minutes: 59)), '59m');
    expect(ago(const Duration(hours: 2)), '2h');
    expect(ago(const Duration(hours: 23)), '23h');
    expect(ago(const Duration(days: 1)), '1d');
    expect(ago(const Duration(days: 5)), '5d');
    expect(ago(const Duration(days: 6)), '6d');
    expect(ago(const Duration(days: 7)), '1w');
    expect(ago(const Duration(days: 14)), '2w');
  });

  test('a site that has never been opened has no age', () {
    expect(relativeAge(now, null), '');
  });

  test('a clock that has gone backwards does not produce a negative age', () {
    expect(relativeAge(now, now.add(const Duration(hours: 3))), 'now');
  });
}

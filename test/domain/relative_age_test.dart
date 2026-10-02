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

  group('lastWorkedLabel (spec 8b: "2 hours ago")', () {
    String worked(Duration d) => lastWorkedLabel(now, now.subtract(d));

    test('a site that never worked says so', () {
      expect(lastWorkedLabel(now, null), 'never on this device');
    });

    test('under a minute, and a clock gone backwards, read as just now', () {
      expect(worked(const Duration(seconds: 59)), 'just now');
      expect(lastWorkedLabel(now, now.add(const Duration(hours: 3))), 'just now');
    });

    test('minutes, hours and days are spelled out, singular for one', () {
      expect(worked(const Duration(minutes: 1)), '1 minute ago');
      expect(worked(const Duration(minutes: 14)), '14 minutes ago');
      expect(worked(const Duration(hours: 1)), '1 hour ago');
      expect(worked(const Duration(hours: 2)), '2 hours ago');
      expect(worked(const Duration(hours: 23, minutes: 59)), '23 hours ago');
      expect(worked(const Duration(days: 1)), '1 day ago');
      expect(worked(const Duration(days: 40)), '40 days ago');
    });
  });
}

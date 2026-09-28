// test/data/bundled_filter_lists_test.dart
import 'dart:convert';

import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves [files] by asset key and counts loads, so caching is observable.
class FakeBundle extends CachingAssetBundle {
  FakeBundle(this.files);
  final Map<String, String> files;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    final text = files[key];
    if (text == null) throw FlutterError('No asset $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseRules', () {
    test('keeps ||host^ rules and skips comments, blanks and other syntax', () {
      final rules = parseRules(
        '! a comment\n\n||a.example^\n  ||b.example^  \n/ads/*\n@@||c.example^\n',
        defaultCategory: 'trackers',
      );
      expect(rules, {'trackers': ['||a.example^', '||b.example^']});
    });

    test('a category directive switches the category of the rules after it', () {
      final rules = parseRules(
        '||t.example^\n! category: ads\n||a.example^\n!category:trackers\n||t2.example^\n',
        defaultCategory: 'trackers',
      );
      expect(rules, {
        'trackers': ['||t.example^', '||t2.example^'],
        'ads': ['||a.example^'],
      });
    });

    test('Windows line endings parse the same', () {
      expect(parseRules('||a.example^\r\n||b.example^\r\n', defaultCategory: 'ads'),
          {'ads': ['||a.example^', '||b.example^']});
    });
  });

  group('BundledFilterRules', () {
    final list = BundledFilterList(
      id: 'fl-x', name: 'X', enabledByDefault: true,
      category: FilterListCategory.ads, asset: 'x.txt',
      updatedAt: DateTime.utc(2026, 9, 28),
    );

    test('parses a list with its own category as the default', () async {
      final rules = BundledFilterRules(FakeBundle({'x.txt': '||a.example^\n'}), lists: [list]);
      expect(await rules.rulesFor(list), {'ads': ['||a.example^']});
      expect(await rules.ruleCount(list), 1);
    });

    test('loads each file once', () async {
      final bundle = FakeBundle({'x.txt': '||a.example^\n'});
      final rules = BundledFilterRules(bundle, lists: [list]);
      await rules.rulesFor(list);
      await rules.ruleCount(list);
      expect(bundle.loads, 1);
    });

    test('a missing file throws rather than reading as empty', () async {
      final rules = BundledFilterRules(FakeBundle({}), lists: [list]);
      expect(rules.rulesFor(list), throwsA(isA<FlutterError>()));
    });
  });

  // Packaging: every list the app claims to ship must load, have rules, and
  // use only the two categories the engine reports.
  test('every bundled list ships a file with rules in known categories', () async {
    final rules = BundledFilterRules(rootBundle);
    expect(bundledFilterLists.map((l) => l.id), ['fl-trackers', 'fl-cookies', 'fl-social']);
    for (final list in bundledFilterLists) {
      final byCategory = await rules.rulesFor(list);
      expect(await rules.ruleCount(list), greaterThan(0), reason: list.asset);
      expect(byCategory.keys.toSet().difference({'trackers', 'ads'}), isEmpty, reason: list.asset);
    }
    final trackersAndAds = await rules.rulesFor(bundledFilterLists.first);
    expect(trackersAndAds.keys.toSet(), {'trackers', 'ads'});
  });

  test('the spec names and default switches', () {
    expect(bundledFilterLists.map((l) => l.name),
        ['Trackers and ads', 'Cookie notices', 'Social embeds']);
    expect(bundledFilterLists.map((l) => l.enabledByDefault), [true, true, false]);
  });
}

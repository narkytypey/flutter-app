import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/models/filter_list.dart' show FilterListCategory;

/// One filter list that ships inside the app. Its rules live in [asset] and
/// change only with an app update — nothing is ever downloaded (spec
/// `2026-09-28-filter-lists-and-scripts-design.md`).
class BundledFilterList {
  const BundledFilterList({
    required this.id,
    required this.name,
    required this.enabledByDefault,
    required this.category,
    required this.asset,
    required this.updatedAt,
  });

  final String id;

  /// Spec `10d`'s row name, verbatim.
  final String name;
  final bool enabledByDefault;

  /// Category for rules before any `! category:` directive in [asset].
  final FilterListCategory category;
  final String asset;

  /// When [asset] last changed — written by hand, bumped with the file.
  final DateTime updatedAt;
}

/// Every list the app ships, in the order `10d` shows them.
final bundledFilterLists = [
  BundledFilterList(
    id: 'fl-trackers',
    name: 'Trackers and ads',
    enabledByDefault: true,
    category: FilterListCategory.trackers,
    asset: 'assets/filters/trackers_and_ads.txt',
    updatedAt: DateTime.utc(2026, 9, 28),
  ),
  BundledFilterList(
    id: 'fl-cookies',
    name: 'Cookie notices',
    enabledByDefault: true,
    category: FilterListCategory.trackers,
    asset: 'assets/filters/cookie_notices.txt',
    updatedAt: DateTime.utc(2026, 9, 28),
  ),
  BundledFilterList(
    id: 'fl-social',
    name: 'Social embeds',
    enabledByDefault: false,
    category: FilterListCategory.ads,
    asset: 'assets/filters/social_embeds.txt',
    updatedAt: DateTime.utc(2026, 9, 28),
  ),
];

final _categoryDirective = RegExp(r'^!\s*category:\s*([a-z]+)\s*$');

/// The `||host^` rules in [text], by category. `!` lines are comments,
/// except `! category: <name>`, which sets the category of the rules after
/// it. Anything that is not a `||host^` rule is skipped — it is the only
/// syntax Kotlin's `FilterEngine` understands.
Map<String, List<String>> parseRules(String text, {required String defaultCategory}) {
  final rules = <String, List<String>>{};
  var category = defaultCategory;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('!')) {
      final directive = _categoryDirective.firstMatch(line);
      if (directive != null) category = directive.group(1)!;
      continue;
    }
    if (line.startsWith('||') && line.endsWith('^')) {
      (rules[category] ??= []).add(line);
    }
  }
  return rules;
}

/// Loads and parses [lists]' files through [_bundle], each once.
class BundledFilterRules {
  BundledFilterRules(this._bundle, {List<BundledFilterList>? lists})
      : lists = lists ?? bundledFilterLists;

  final AssetBundle _bundle;
  final List<BundledFilterList> lists;
  final _cache = <String, Map<String, List<String>>>{};

  Future<Map<String, List<String>>> rulesFor(BundledFilterList list) async {
    final cached = _cache[list.id];
    if (cached != null) return cached;
    final text = await _bundle.loadString(list.asset, cache: false);
    return _cache[list.id] = parseRules(text, defaultCategory: list.category.name);
  }

  Future<int> ruleCount(BundledFilterList list) async =>
      (await rulesFor(list)).values.fold<int>(0, (sum, rules) => sum + rules.length);
}

/// The app's own bundle. Tests pass their own [BundledFilterRules] instead.
final defaultBundledFilterRules = BundledFilterRules(rootBundle);

# Filter Lists and Scripts Reach the Engine — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Scripts and filters switches (`10d`/`10e`) change what a page actually loads: enabled filter lists feed each site's blocker, and enabled library scripts are injected into the sites they apply to.

**Architecture:** Three real rule files ship as Flutter assets. Every vault keeps one row per bundled list, synced when it opens. When a site opens, Dart reads the open vault's enabled lists and applicable scripts and sends their content to Kotlin in the `open` call (`EngineExtras`); Kotlin builds the site's `FilterEngine` from it and injects each script separately, scoped to the site's origin. Kotlin keeps no filter state and reads no rule assets.

**Tech Stack:** Flutter/Dart 3, `flutter_riverpod`, `sqflite_sqlcipher` (+ `sqflite_common_ffi` in tests), Kotlin, `androidx.webkit` (`WebViewCompat.addDocumentStartJavaScript`), JUnit 4.

**Spec:** `docs/superpowers/specs/2026-09-28-filter-lists-and-scripts-design.md`

## Global Constraints

- **No network requests of the app's own.** Lists change only with an app update; "Update now" stays a no-op.
- **Two-vault model:** lists and scripts are read from the open vault only; nothing engine-wide may hold one vault's settings.
- **Changes apply on the next open**, never to a live session.
- **Never open a site quietly unfiltered:** if the vault's lists/scripts or a bundled file cannot be read at open, the open fails.
- **Never paraphrase or invent user-facing copy.** This plan adds none. List names are the spec's: "Trackers and ads", "Cookie notices", "Social embeds".
- **Categories are exactly `trackers` and `ads`** — the only two Kotlin's `Session.toMap` reports.
- **Engine boundary:** another session owns the container UI. The only UI file touched is `lib/ui/features/container/views/container_route.dart`, and only `_open`.
- **Kotlin tests:** from `android/`, `./gradlew :app:testDebugUnitTest` (Windows: `gradlew.bat`). Read counts from `build/app/test-results/testDebugUnitTest/TEST-*.xml`, not from `BUILD SUCCESSFUL`. `android/gradlew*` and `android/gradle/wrapper/` are git-ignored; in a fresh worktree copy them from the main checkout first.
- **`flutter analyze` and `flutter test` never compile Kotlin.** `flutter build apk --debug` (zero `e:` lines) is the only check that does.

## Review Focus

1. **A vault that already has `filter_lists` rows** (mock-seeded in a test build, or toggled by the user) — sync must refresh name/count/date and keep `enabled` exactly as the user left it. Pinned in Task 2.
2. **CSS containing `'`, `\`, newlines** — must reach the page as the same text, not break the injected source. Pinned in Task 4.
3. **A JS script ending in a `//` line comment, run at load** — the wrapper's closing `});` must not be commented out. Pinned in Task 4.
4. **Site URLs with an explicit default port, upper-case host, or a non-http scheme** — the origin rule must normalize the first two and refuse the third. Pinned in Task 4.
5. **Every list switched off** — the site opens with nothing blocked (not with the old hardcoded lists). Pinned in Task 3 (Dart) and Task 4 (Kotlin).

---

## File Structure

| File | Responsibility |
|---|---|
| `assets/filters/trackers_and_ads.txt` (new) | Rules for "Trackers and ads", split with `! category:` |
| `assets/filters/cookie_notices.txt` (new) | Rules for "Cookie notices" |
| `assets/filters/social_embeds.txt` (new) | Rules for "Social embeds" |
| `pubspec.yaml` | Declare `assets/filters/` |
| `lib/data/services/bundled_filter_lists.dart` (new) | `BundledFilterList`, `bundledFilterLists`, `parseRules`, `BundledFilterRules`, `defaultBundledFilterRules` |
| `lib/data/repositories/filter_list_repository_sqlite.dart` | `syncBundledFilterLists` replaces `seedFilterListsIfEmpty` |
| `lib/data/services/encrypted_database.dart` | `openEncrypted` syncs lists after opening |
| `lib/domain/models/engine_extras.dart` (new) | `InjectedScript`, `EngineExtras`, `selectUserScripts` |
| `lib/data/services/engine_extras_builder.dart` (new) | `engineExtrasFor` — vault + bundle → `EngineExtras` |
| `lib/data/services/container_engine.dart` / `container_engine_channel.dart` / `fake_container_engine.dart` | `open(site, {extras})` |
| `lib/ui/features/container/view_models/providers.dart` | `bundledFilterRulesProvider`, `engineExtrasBuilderProvider` |
| `lib/ui/features/container/views/container_route.dart` | `_open` builds extras first |
| `android/.../engine/SiteConfig.kt` | `filterRules`, `userScripts`, `InjectedScript`, `injectedScriptsFrom` |
| `android/.../engine/UserScriptJs.kt` (new) | `UserScriptJs.wrap`, `originRuleFor` |
| `android/.../engine/Shields.kt` | Inject each script scoped to the origin |
| `android/.../engine/EngineChannel.kt` | `configFrom` reads the new keys; `Session(config)` from `config.filterRules`; asset reading deleted |
| `android/app/src/main/assets/filters/` | Deleted |

---

### Task 1: Bundled rule files and their loader

**Files:**
- Create: `assets/filters/trackers_and_ads.txt`, `assets/filters/cookie_notices.txt`, `assets/filters/social_embeds.txt`
- Modify: `pubspec.yaml` (the `flutter:` section)
- Create: `lib/data/services/bundled_filter_lists.dart`
- Test: `test/data/bundled_filter_lists_test.dart`

**Interfaces:**
- Consumes: `FilterListCategory` (`lib/domain/models/filter_list.dart`, values `trackers`, `ads`).
- Produces:
  - `class BundledFilterList { String id; String name; bool enabledByDefault; FilterListCategory category; String asset; DateTime updatedAt; }`
  - `final List<BundledFilterList> bundledFilterLists` — ids `fl-trackers`, `fl-cookies`, `fl-social`, in that order.
  - `Map<String, List<String>> parseRules(String text, {required String defaultCategory})`
  - `class BundledFilterRules { BundledFilterRules(AssetBundle bundle, {List<BundledFilterList>? lists}); List<BundledFilterList> lists; Future<Map<String, List<String>>> rulesFor(BundledFilterList list); Future<int> ruleCount(BundledFilterList list); }`
  - `final BundledFilterRules defaultBundledFilterRules` (over `rootBundle`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/bundled_filter_lists_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/domain/models/filter_list.dart';
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/bundled_filter_lists_test.dart`
Expected: FAIL — compile error, `bundled_filter_lists.dart` does not exist.

- [ ] **Step 3: Write the three rule files**

```text
# assets/filters/trackers_and_ads.txt
! Trackers and ads (spec 10d). `||host^` domain rules only — see FilterEngine.kt.
! Bump this list's updatedAt in bundled_filter_lists.dart whenever it changes.
! category: trackers
||doubleclick.net^
||googlesyndication.com^
||googletagmanager.com^
||googletagservices.com^
||google-analytics.com^
||googleadservices.com^
||adservice.google.com^
||facebook.net^
||connect.facebook.net^
||amazon-adsystem.com^
||scorecardresearch.com^
||quantserve.com^
||adnxs.com^
||taboola.com^
||outbrain.com^
||criteo.com^
||hotjar.com^
||mixpanel.com^
||segment.io^
||branch.io^
! category: ads
||pubmatic.com^
||rubiconproject.com^
```

(Remove the leading `# path` line — it only labels the block here. Same for the next two.)

```text
# assets/filters/cookie_notices.txt
! Cookie notices (spec 10d). Consent-management platforms: blocking the
! loader removes the banner. Specific hosts, so a CMP vendor's own website
! and the privacy policies some host (iubenda) keep working.
! Bump this list's updatedAt in bundled_filter_lists.dart whenever it changes.
||cdn.cookielaw.org^
||cookie-cdn.cookiepro.com^
||geolocation.onetrust.com^
||consent.cookiebot.com^
||consentcdn.cookiebot.com^
||cmp.quantcast.com^
||consensu.org^
||consent.trustarc.com^
||app.usercentrics.eu^
||privacy-proxy.usercentrics.eu^
||sdk.privacy-center.org^
||cdn.iubenda.com^
||cmp.osano.com^
||cdn-cookieyes.com^
||app.termly.io^
||cdn.consentmanager.net^
||cdn.cookie-script.com^
||consent.cookiefirst.com^
||cdn.cookiehub.eu^
||cc.cdn.civiccomputing.com^
||cdn.privacy-mgmt.com^
||cmp.inmobi.com^
```

```text
# assets/filters/social_embeds.txt
! Social embeds (spec 10d). Widget and SDK hosts only — the networks'
! own sites stay reachable; this stops their embeds on other pages.
! Bump this list's updatedAt in bundled_filter_lists.dart whenever it changes.
||platform.twitter.com^
||syndication.twitter.com^
||platform.x.com^
||connect.facebook.net^
||platform.linkedin.com^
||assets.pinterest.com^
||platform.instagram.com^
||embed.reddit.com^
||embed.redditmedia.com^
||platform.tumblr.com^
||s7.addthis.com^
||static.addtoany.com^
||platform-api.sharethis.com^
```

- [ ] **Step 4: Declare the assets**

In `pubspec.yaml`, directly under the `flutter:` key (beside `uses-material-design`, above `fonts:`), add:

```yaml
  assets:
    - assets/filters/
```

- [ ] **Step 5: Write the loader**

```dart
// lib/data/services/bundled_filter_lists.dart
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
```

- [ ] **Step 6: Run to verify it passes**

Run: `flutter test test/data/bundled_filter_lists_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 7: Commit**

```bash
git add assets/filters pubspec.yaml lib/data/services/bundled_filter_lists.dart test/data/bundled_filter_lists_test.dart
git commit -m "feat: ship real rule files for the three filter lists"
```

---

### Task 2: Every vault keeps its lists in step with the bundle

**Files:**
- Modify: `lib/data/repositories/filter_list_repository_sqlite.dart` (delete `seedFilterListsIfEmpty`, add `syncBundledFilterLists`)
- Modify: `lib/data/services/encrypted_database.dart`
- Modify: `test/data/filter_list_repository_test.dart`, `test/data/filter_list_category_migration_test.dart`, `test/ui/features/scripts/scripts_route_test.dart`
- Test: `test/data/sync_bundled_filter_lists_test.dart`

**Interfaces:**
- Consumes: `BundledFilterRules`, `bundledFilterLists` (Task 1).
- Produces:
  - `Future<void> syncBundledFilterLists(AppDatabase database, BundledFilterRules rules)`
  - `Future<AppDatabase> openEncrypted({required String path, required Uint8List dataKey, BundledFilterRules? filterRules, DatabaseFactory? factory})` — the two new parameters are for tests; production calls are unchanged.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/sync_bundled_filter_lists_test.dart
import 'dart:typed_data';

import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/data/services/encrypted_database.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'bundled_filter_lists_test.dart' show FakeBundle;

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  final lists = [
    BundledFilterList(
      id: 'fl-a', name: 'List A', enabledByDefault: true,
      category: FilterListCategory.trackers, asset: 'a.txt',
      updatedAt: DateTime.utc(2026, 9, 28),
    ),
    BundledFilterList(
      id: 'fl-b', name: 'List B', enabledByDefault: false,
      category: FilterListCategory.ads, asset: 'b.txt',
      updatedAt: DateTime.utc(2026, 9, 20),
    ),
  ];
  final rules = BundledFilterRules(
    FakeBundle({'a.txt': '||1.example^\n||2.example^\n', 'b.txt': '||3.example^\n'}),
    lists: lists,
  );

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
  });

  tearDown(() => database.close());

  Future<List<FilterList>> all() => SqliteFilterListRepository(database).all();

  test('a vault without lists gets every bundled list with its default switch', () async {
    await syncBundledFilterLists(database, rules);

    final synced = await all();
    expect(synced.map((l) => l.id), ['fl-a', 'fl-b']);
    expect(synced.map((l) => l.name), ['List A', 'List B']);
    expect(synced.map((l) => l.ruleCount), [2, 1]);
    expect(synced.map((l) => l.enabled), [true, false]);
    expect(synced.map((l) => l.category), [FilterListCategory.trackers, FilterListCategory.ads]);
    expect(synced.first.updatedAt, DateTime.utc(2026, 9, 28));
  });

  // Review Focus 1: rows already present — the spec's old mock seed, or a
  // switch the user flipped — keep their switch; everything else is the
  // bundle's.
  test('an existing row is refreshed from the bundle and keeps its switch', () async {
    await database.db.insert('filter_lists', {
      'id': 'fl-a', 'name': 'Old name', 'rule_count': 84102,
      'updated_at': 0, 'enabled': 0, 'category': 'ads',
    });

    await syncBundledFilterLists(database, rules);

    final a = (await all()).firstWhere((l) => l.id == 'fl-a');
    expect(a.name, 'List A');
    expect(a.ruleCount, 2);
    expect(a.updatedAt, DateTime.utc(2026, 9, 28));
    expect(a.category, FilterListCategory.trackers);
    expect(a.enabled, isFalse);
  });

  test('syncing twice changes nothing', () async {
    await syncBundledFilterLists(database, rules);
    await SqliteFilterListRepository(database).setEnabled('fl-b', true);
    await syncBundledFilterLists(database, rules);

    final synced = await all();
    expect(synced, hasLength(2));
    expect(synced.map((l) => l.enabled), [true, true]);
  });

  test('a row the bundle does not know is left alone', () async {
    await database.db.insert('filter_lists', {
      'id': 'fl-legacy', 'name': 'Legacy', 'rule_count': 5,
      'updated_at': 0, 'enabled': 1, 'category': 'trackers',
    });

    await syncBundledFilterLists(database, rules);

    final legacy = (await all()).firstWhere((l) => l.id == 'fl-legacy');
    expect(legacy.name, 'Legacy');
    expect(legacy.ruleCount, 5);
  });

  test('opening a vault syncs its lists', () async {
    final opened = await openEncrypted(
      path: inMemoryDatabasePath,
      dataKey: Uint8List(32),
      filterRules: rules,
      factory: databaseFactoryFfi,
    );
    addTearDown(opened.close);

    expect((await SqliteFilterListRepository(opened).all()).map((l) => l.id), ['fl-a', 'fl-b']);
  });

  // A broken bundle must not lock the owner out of their vault. Opening a
  // site still fails closed later (Task 3), so nothing loads unfiltered.
  test('a list that cannot be read does not stop the vault opening', () async {
    final broken = BundledFilterRules(FakeBundle({}), lists: lists);

    final opened = await openEncrypted(
      path: inMemoryDatabasePath,
      dataKey: Uint8List(32),
      filterRules: broken,
      factory: databaseFactoryFfi,
    );
    addTearDown(opened.close);

    expect(await SqliteFilterListRepository(opened).all(), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/sync_bundled_filter_lists_test.dart`
Expected: FAIL — `syncBundledFilterLists` is not defined, `openEncrypted` has no `filterRules`/`factory` parameters.

- [ ] **Step 3: Replace the seeder with the sync**

In `lib/data/repositories/filter_list_repository_sqlite.dart`, delete `seedFilterListsIfEmpty` and its doc comment (everything from `/// Seeds the three lists spec` to the end of the file), and add:

```dart
/// Brings [database]'s `filter_lists` rows into line with the lists that
/// ship in the app. A missing list is added with its default switch; an
/// existing one takes the bundle's name, rule count, date and category but
/// keeps the switch the owner set. Rows the bundle does not know are left
/// alone. Runs on every vault open, so an app update reaches every vault —
/// the decoy included, which is its own store.
Future<void> syncBundledFilterLists(AppDatabase database, BundledFilterRules rules) async {
  final db = database.db;
  for (final list in rules.lists) {
    final fields = <String, Object>{
      'name': list.name,
      'rule_count': await rules.ruleCount(list),
      'updated_at': list.updatedAt.millisecondsSinceEpoch,
      'category': list.category.name,
    };
    final updated =
        await db.update('filter_lists', fields, where: 'id = ?', whereArgs: [list.id]);
    if (updated == 0) {
      await db.insert('filter_lists', {
        'id': list.id,
        ...fields,
        'enabled': list.enabledByDefault ? 1 : 0,
      });
    }
  }
}
```

and add the import `import '../services/bundled_filter_lists.dart' show BundledFilterRules;`.

- [ ] **Step 4: Sync on open**

Replace `lib/data/services/encrypted_database.dart`'s function with:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite_sqlcipher/sqflite.dart' show DatabaseFactory;

import '../repositories/filter_list_repository_sqlite.dart' show syncBundledFilterLists;
import 'app_database.dart';
import 'bundled_filter_lists.dart';

/// Opens a vault's store under its data key. The key is passed as base64
/// because SQLCipher takes a passphrase string; it is never derived from
/// anything the user typed, only unwrapped.
///
/// Then brings the vault's filter lists into line with the bundle. A failure
/// there is logged and the vault still opens: a packaging defect must not
/// lock the owner out. Nothing loads unfiltered because of it — opening a
/// site reads the bundle itself and fails if it cannot.
Future<AppDatabase> openEncrypted({
  required String path,
  required Uint8List dataKey,
  BundledFilterRules? filterRules,
  DatabaseFactory? factory,
}) async {
  final database = await AppDatabase.open(
    path: path,
    password: base64Encode(dataKey),
    factory: factory,
  );
  try {
    await syncBundledFilterLists(database, filterRules ?? defaultBundledFilterRules);
  } catch (error) {
    debugPrint('Filter lists not synced: $error');
  }
  return database;
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/data/sync_bundled_filter_lists_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 6: Move the old seeder's callers to the sync**

`test/data/filter_list_repository_test.dart` — replace its first two tests ("a fresh database seeds the three lists from the spec", "seeding twice does not duplicate anything") with nothing (Step 1's file covers both), and in the remaining tests replace each `await seedFilterListsIfEmpty(database, now: fixedNow);` / `await seedFilterListsIfEmpty(upgraded, now: fixedNow);` with the same call to `syncBundledFilterLists(<db>, defaultBundledFilterRules)`. Add at the top of `main()`: `TestWidgetsFlutterBinding.ensureInitialized();`, add the import `import 'package:container/data/services/bundled_filter_lists.dart';`, and delete the now-unused `fixedNow`. The migration test's `expect(... .length, 3)` stays correct (three bundled lists).

`test/data/filter_list_category_migration_test.dart` — in the first test replace `await seedFilterListsIfEmpty(database);` with `await syncBundledFilterLists(database, defaultBundledFilterRules);`, add `TestWidgetsFlutterBinding.ensureInitialized();` as the first line of `main()`, and add the bundled import. Its assertions (trackers/trackers/ads) hold.

`test/ui/features/scripts/scripts_route_test.dart` — replace `await seedFilterListsIfEmpty(database);` with `await syncBundledFilterLists(database, defaultBundledFilterRules);` and add the import `import 'package:container/data/services/bundled_filter_lists.dart';`. Its assertions ('Cookie notices' shown, 'Social embeds' starts off) hold.

- [ ] **Step 7: Run the whole suite**

Run: `flutter analyze` then `flutter test`
Expected: `No issues found!`; all tests pass. `grep -rn seedFilterListsIfEmpty lib test` prints nothing.

- [ ] **Step 8: Commit**

```bash
git add lib/data test/data test/ui/features/scripts/scripts_route_test.dart
git commit -m "feat: keep every vault's filter lists in step with the bundle"
```

---

### Task 3: Dart sends each site its lists and scripts

**Files:**
- Create: `lib/domain/models/engine_extras.dart`
- Create: `lib/data/services/engine_extras_builder.dart`
- Modify: `lib/data/services/container_engine.dart`, `lib/data/services/container_engine_channel.dart`, `lib/data/services/fake_container_engine.dart`
- Modify: `lib/ui/features/container/view_models/providers.dart`
- Modify: `lib/ui/features/container/views/container_route.dart` (`_open` only)
- Modify: `test/ui/features/container_route_test.dart` (`_pump` override + one test)
- Test: `test/data/engine_extras_builder_test.dart`

**Interfaces:**
- Consumes: `BundledFilterRules`, `syncBundledFilterLists` (Tasks 1–2); `FilterListRepository`, `ScriptRepository`, `filterListRepositoryProvider`, `scriptRepositoryProvider` (`lib/ui/features/scripts/view_models/providers.dart`); `UserScript`, `ScriptKind` (`lib/domain/models/user_script.dart`).
- Produces:
  - `class InjectedScript { ScriptKind kind; String code; bool atDocumentStart; InjectedScript.from(UserScript); Map<String, Object> toMap(); }` — map keys `kind` (`'css'|'js'`), `code`, `atDocumentStart`.
  - `class EngineExtras { Map<String, List<String>> filterRules; List<InjectedScript> userScripts; static const none; }`
  - `List<UserScript> selectUserScripts(Site site, List<UserScript> scripts)`
  - `Future<EngineExtras> engineExtrasFor(Site site, {required FilterListRepository filterLists, required ScriptRepository scripts, required BundledFilterRules rules})`
  - `ContainerEngine.open(Site site, {EngineExtras extras = EngineExtras.none})`; channel map keys `filterRules`, `userScripts`.
  - `FakeContainerEngine.openedExtras` — `Map<String, EngineExtras>` by site id.
  - `bundledFilterRulesProvider`, `engineExtrasBuilderProvider` (`Provider<Future<EngineExtras> Function(Site)>`).

- [ ] **Step 1: Write the failing builder tests**

```dart
// test/data/engine_extras_builder_test.dart
import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/data/services/engine_extras_builder.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'bundled_filter_lists_test.dart' show FakeBundle;

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;

  final lists = [
    BundledFilterList(
      id: 'fl-a', name: 'A', enabledByDefault: true,
      category: FilterListCategory.trackers, asset: 'a.txt',
      updatedAt: DateTime.utc(2026, 9, 28),
    ),
    BundledFilterList(
      id: 'fl-b', name: 'B', enabledByDefault: true,
      category: FilterListCategory.ads, asset: 'b.txt',
      updatedAt: DateTime.utc(2026, 9, 28),
    ),
  ];
  final rules = BundledFilterRules(
    FakeBundle({
      'a.txt': '||t1.example^\n! category: ads\n||a1.example^\n',
      'b.txt': '||a2.example^\n',
    }),
    lists: lists,
  );

  const site = Site(
    id: 'forum', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
    url: 'https://forum.example.com', profileId: 'p',
  );

  UserScript script(String id, {bool enabled = true, List<String> sites = const ['forum']}) =>
      UserScript(
        id: id, name: id, kind: ScriptKind.css, code: '/* $id */',
        runAtDocumentStart: true, enabled: enabled, appliedSiteIds: sites,
      );

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
        id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep));
    await SqliteSiteRepository(database).upsert(site);
    await SqliteSiteRepository(database).upsert(site.copyWith(id: 'news'));
    await syncBundledFilterLists(database, rules);
  });

  tearDown(() => database.close());

  Future<EngineExtras> build() => engineExtrasFor(
        site,
        filterLists: SqliteFilterListRepository(database),
        scripts: SqliteScriptRepository(database),
        rules: rules,
      );

  test('enabled lists are merged by category', () async {
    final extras = await build();
    expect(extras.filterRules, {
      'trackers': ['||t1.example^'],
      'ads': ['||a1.example^', '||a2.example^'],
    });
  });

  test('a disabled list contributes nothing', () async {
    await SqliteFilterListRepository(database).setEnabled('fl-a', false);
    expect((await build()).filterRules, {'ads': ['||a2.example^']});
  });

  // Review Focus 5: everything off means nothing blocked — not a fallback.
  test('every list off sends no rules at all', () async {
    await SqliteFilterListRepository(database).setEnabled('fl-a', false);
    await SqliteFilterListRepository(database).setEnabled('fl-b', false);
    expect((await build()).filterRules, isEmpty);
  });

  test('a vault row with no bundled file is ignored', () async {
    await database.db.insert('filter_lists', {
      'id': 'fl-legacy', 'name': 'Legacy', 'rule_count': 1,
      'updated_at': 0, 'enabled': 1, 'category': 'trackers',
    });
    expect((await build()).filterRules['trackers'], ['||t1.example^']);
  });

  test("only enabled scripts applied to this site are sent, in library order", () async {
    final repo = SqliteScriptRepository(database);
    await repo.upsert(script('first'));
    await repo.upsert(script('off', enabled: false));
    await repo.upsert(script('elsewhere', sites: ['news']));
    await repo.upsert(script('second', sites: ['news', 'forum']));

    final sent = (await build()).userScripts;
    expect(sent.map((s) => s.code), ['/* first */', '/* second */']);
    expect(sent.first.toMap(), {'kind': 'css', 'code': '/* first */', 'atDocumentStart': true});
  });

  test('selectUserScripts matches on enabled and site', () {
    final picked = selectUserScripts(site, [
      script('a'), script('b', enabled: false), script('c', sites: ['news']),
    ]);
    expect(picked.map((s) => s.id), ['a']);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/engine_extras_builder_test.dart`
Expected: FAIL — `engine_extras.dart` / `engine_extras_builder.dart` do not exist.

- [ ] **Step 3: Write the model and the builder**

```dart
// lib/domain/models/engine_extras.dart
import 'site.dart';
import 'user_script.dart';

/// A library script as the engine receives it.
class InjectedScript {
  const InjectedScript({
    required this.kind,
    required this.code,
    required this.atDocumentStart,
  });

  InjectedScript.from(UserScript script)
      : kind = script.kind,
        code = script.code,
        atDocumentStart = script.runAtDocumentStart;

  final ScriptKind kind;
  final String code;
  final bool atDocumentStart;

  Map<String, Object> toMap() =>
      {'kind': kind.name, 'code': code, 'atDocumentStart': atDocumentStart};
}

/// What a site opens with beyond its own settings, read from the open vault:
/// the enabled filter lists' rules by category, and the library scripts
/// applied to it. Empty means nothing blocked and nothing injected.
class EngineExtras {
  const EngineExtras({this.filterRules = const {}, this.userScripts = const []});

  static const none = EngineExtras();

  final Map<String, List<String>> filterRules;
  final List<InjectedScript> userScripts;
}

/// The library scripts that run on [site]: switched on and applied to it,
/// in library order.
List<UserScript> selectUserScripts(Site site, List<UserScript> scripts) => [
      for (final script in scripts)
        if (script.enabled && script.appliedSiteIds.contains(site.id)) script,
    ];
```

```dart
// lib/data/services/engine_extras_builder.dart
import '../../domain/models/engine_extras.dart';
import '../../domain/models/site.dart';
import '../../domain/repositories/filter_list_repository.dart';
import '../../domain/repositories/script_repository.dart';
import 'bundled_filter_lists.dart';

/// Reads the open vault's enabled lists and [site]'s scripts. Throws if the
/// vault or a bundled file cannot be read — the caller must not open the
/// site then, rather than open it unfiltered.
Future<EngineExtras> engineExtrasFor(
  Site site, {
  required FilterListRepository filterLists,
  required ScriptRepository scripts,
  required BundledFilterRules rules,
}) async {
  final enabled = {
    for (final list in await filterLists.all())
      if (list.enabled) list.id,
  };
  final filterRules = <String, List<String>>{};
  for (final list in rules.lists) {
    if (!enabled.contains(list.id)) continue;
    (await rules.rulesFor(list)).forEach((category, listRules) {
      (filterRules[category] ??= []).addAll(listRules);
    });
  }
  return EngineExtras(
    filterRules: filterRules,
    userScripts: [
      for (final script in selectUserScripts(site, await scripts.all()))
        InjectedScript.from(script),
    ],
  );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/engine_extras_builder_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Carry the extras through `open`**

`lib/data/services/container_engine.dart` — add `import '../../domain/models/engine_extras.dart';` and change the method to:

```dart
  /// Creates the profile if absent and begins loading. Emits progress on
  /// [sessions]. Completes when the page is live or the route was refused.
  /// [extras] is the open vault's filter rules and scripts for this site.
  Future<ContainerSession> open(Site site, {EngineExtras extras = EngineExtras.none});
```

`lib/data/services/container_engine_channel.dart` — same import; change the signature to `Future<ContainerSession> open(Site site, {EngineExtras extras = EngineExtras.none}) async {` and add two entries after `'wipeOnExit': ...`:

```dart
      'filterRules': extras.filterRules,
      'userScripts': [for (final script in extras.userScripts) script.toMap()],
```

`lib/data/services/fake_container_engine.dart` — same import; add a field beside `closed`:

```dart
  /// The extras each site was last opened with, by site id.
  final openedExtras = <String, EngineExtras>{};
```

and change `open` to `Future<ContainerSession> open(Site site, {EngineExtras extras = EngineExtras.none}) async {` with `openedExtras[site.id] = extras;` as its first line.

- [ ] **Step 6: Write the failing route test**

In `test/ui/features/container_route_test.dart`:

1. Add imports:

```dart
import 'package:container/data/repositories/filter_list_repository_sqlite.dart';
import 'package:container/data/repositories/script_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/bundled_filter_lists.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../data/bundled_filter_lists_test.dart' show FakeBundle;
```

and change the existing dashboard-providers import's `show` list to `show databaseProvider, siteRepositoryProvider, workspacesProvider`.

2. In `_pump`, add a parameter `bool realExtras = false,` and, inside `overrides`, add:

```dart
      if (!realExtras)
        engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
```

3. Add this test at the top of `main()`:

```dart
  testWidgets("opening sends the vault's enabled rules and this site's scripts", (tester) async {
    sqfliteFfiInit();
    final database = (await tester.runAsync(
        () => AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)))!;
    addTearDown(() => tester.runAsync(database.close));
    final lists = [
      BundledFilterList(
        id: 'fl-a', name: 'A', enabledByDefault: true,
        category: FilterListCategory.trackers, asset: 'a.txt',
        updatedAt: DateTime.utc(2026, 9, 28),
      ),
    ];
    final rules = BundledFilterRules(FakeBundle({'a.txt': '||t.example^\n'}), lists: lists);
    await tester.runAsync(() async {
      await syncBundledFilterLists(database, rules);
      await SqliteScriptRepository(database).upsert(const UserScript(
        id: 'sc', name: 'Hide', kind: ScriptKind.css, code: 'header{display:none}',
        runAtDocumentStart: true, enabled: true, appliedSiteIds: ['s1'],
      ));
    });

    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), realExtras: true, overrides: [
      databaseProvider.overrideWithValue(database),
      bundledFilterRulesProvider.overrideWithValue(rules),
    ]);
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    final extras = engine.openedExtras['s1']!;
    expect(extras.filterRules, {'trackers': ['||t.example^']});
    expect(extras.userScripts.single.code, 'header{display:none}');
  });
```

and give `_pump` one more parameter, `List<Override> overrides = const [],`, spread into its `overrides` list with `...overrides,`. Import `FilterListCategory` via `import 'package:container/domain/models/filter_list.dart';`.

Run: `flutter test test/ui/features/container_route_test.dart`
Expected: FAIL — `engineExtrasBuilderProvider` / `bundledFilterRulesProvider` are not defined.

- [ ] **Step 7: Add the providers and route the open through them**

In `lib/ui/features/container/view_models/providers.dart` add imports:

```dart
import '../../../../data/services/bundled_filter_lists.dart';
import '../../../../data/services/engine_extras_builder.dart';
import '../../../../domain/models/engine_extras.dart';
import '../../../../domain/models/site.dart';
import '../../scripts/view_models/providers.dart'
    show filterListRepositoryProvider, scriptRepositoryProvider;
```

and below `containerEngineProvider`:

```dart
final bundledFilterRulesProvider =
    Provider<BundledFilterRules>((ref) => defaultBundledFilterRules);

/// What a site opens with from the open vault — its enabled filter lists'
/// rules and its library scripts. A function rather than a value so every
/// open reads the vault as it is now; widget tests with no vault override it.
final engineExtrasBuilderProvider = Provider<Future<EngineExtras> Function(Site)>((ref) {
  return (site) => engineExtrasFor(
        site,
        filterLists: ref.read(filterListRepositoryProvider),
        scripts: ref.read(scriptRepositoryProvider),
        rules: ref.read(bundledFilterRulesProvider),
      );
});
```

In `lib/ui/features/container/views/container_route.dart`, replace `_open`'s last line with:

```dart
    // Read before opening, and a failure here stops the open: a site is
    // never opened without the lists and scripts its vault says it gets.
    final extras = await ref.read(engineExtrasBuilderProvider)(widget.site);
    if (!mounted) return;
    await ref.read(containerEngineProvider).open(widget.site, extras: extras);
```

- [ ] **Step 8: Run to verify it passes**

Run: `flutter test test/ui/features/container_route_test.dart`
Expected: PASS, all tests including the new one.

- [ ] **Step 9: Run everything and commit**

Run: `flutter analyze` then `flutter test`
Expected: `No issues found!`; all tests pass.

```bash
git add lib/domain/models/engine_extras.dart lib/data/services lib/ui/features/container test/data/engine_extras_builder_test.dart test/ui/features/container_route_test.dart
git commit -m "feat: send each site its vault's enabled rules and scripts on open"
```

---

### Task 4: Kotlin builds the blocker from them and injects each script

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/SiteConfig.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/UserScriptJs.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Shields.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`
- Delete: `android/app/src/main/assets/filters/` (both files)
- Test: `android/app/src/test/kotlin/com/mono/container/engine/UserScriptJsTest.kt`, `.../InjectedScriptsFromTest.kt`, `.../FilterEngineTest.kt` (one test added)

**Interfaces:**
- Consumes: the `open` map keys `filterRules` (`Map<String, List<String>>`) and `userScripts` (`List<Map>` with `kind`, `code`, `atDocumentStart`) from Task 3.
- Produces:
  - `SiteConfig.filterRules: Map<String, List<String>> = emptyMap()`, `SiteConfig.userScripts: List<InjectedScript> = emptyList()`
  - `data class InjectedScript(val kind: String, val code: String, val atDocumentStart: Boolean)`
  - `fun injectedScriptsFrom(raw: List<Map<String, Any?>>?): List<InjectedScript>`
  - `object UserScriptJs { fun wrap(kind: String, code: String, atDocumentStart: Boolean): String? }`
  - `fun originRuleFor(url: String): String?`
  - `class Session(val config: SiteConfig)` (the `rulesByCategory` parameter is gone)

- [ ] **Step 1: Write the failing JVM tests**

```kotlin
// android/app/src/test/kotlin/com/mono/container/engine/UserScriptJsTest.kt
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UserScriptJsTest {

    @Test fun `css at document start adds the style before paint`() {
        val js = UserScriptJs.wrap("css", "header{display:none}", atDocumentStart = true)!!
        assertTrue(js.startsWith("(function(){var add=function(){"))
        assertTrue(js.contains("s.textContent='header{display:none}'"))
        assertTrue(js.contains("if(document.documentElement){add();}else{document.addEventListener('DOMContentLoaded',add);}"))
    }

    @Test fun `css at load adds the style on DOMContentLoaded`() {
        val js = UserScriptJs.wrap("css", "a{}", atDocumentStart = false)!!
        assertTrue(js.startsWith("document.addEventListener('DOMContentLoaded',function(){"))
        assertTrue(js.contains("s.textContent='a{}'"))
    }

    // Review Focus 2.
    @Test fun `css quotes, backslashes and newlines are escaped`() {
        val js = UserScriptJs.wrap("css", "a::after{content:'\\\\'}\nb{}", atDocumentStart = false)!!
        assertTrue(js.contains("s.textContent='a::after{content:\\'\\\\\\\\\\'}\\nb{}'"))
    }

    @Test fun `js at document start is the code as written`() {
        assertEquals("window.x=1;\n", UserScriptJs.wrap("js", "window.x=1;", atDocumentStart = true))
    }

    // Review Focus 3: a trailing line comment must not swallow the closer.
    @Test fun `js at load puts the closer on its own line`() {
        assertEquals(
            "document.addEventListener('DOMContentLoaded',function(){\nrun() // go\n});",
            UserScriptJs.wrap("js", "run() // go", atDocumentStart = false),
        )
    }

    @Test fun `an unknown kind yields nothing`() {
        assertNull(UserScriptJs.wrap("wasm", "x", atDocumentStart = true))
    }

    @Test fun `origin rule is scheme and host`() {
        assertEquals("https://forum.example.com", originRuleFor("https://forum.example.com/thread/1?x=2"))
        assertEquals("http://forum.example.com", originRuleFor("http://forum.example.com"))
    }

    // Review Focus 4.
    @Test fun `origin rule normalizes default ports and case`() {
        assertEquals("https://forum.example.com", originRuleFor("https://Forum.Example.com:443/"))
        assertEquals("http://forum.example.com", originRuleFor("HTTP://forum.example.com:80"))
        assertEquals("https://forum.example.com:8443", originRuleFor("https://forum.example.com:8443/a"))
    }

    @Test fun `origin rule refuses what is not an http page`() {
        assertNull(originRuleFor("file:///sdcard/a.html"))
        assertNull(originRuleFor("not a url"))
        assertNull(originRuleFor("https:///no-host"))
    }
}
```

```kotlin
// android/app/src/test/kotlin/com/mono/container/engine/InjectedScriptsFromTest.kt
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

class InjectedScriptsFromTest {

    @Test fun `reads each script in order`() {
        val scripts = injectedScriptsFrom(listOf(
            mapOf("kind" to "css", "code" to "a{}", "atDocumentStart" to true),
            mapOf("kind" to "js", "code" to "x()", "atDocumentStart" to false),
        ))
        assertEquals(listOf(
            InjectedScript("css", "a{}", true),
            InjectedScript("js", "x()", false),
        ), scripts)
    }

    @Test fun `absent means none, and a malformed entry is skipped`() {
        assertEquals(emptyList<InjectedScript>(), injectedScriptsFrom(null))
        assertEquals(
            listOf(InjectedScript("js", "ok()", false)),
            injectedScriptsFrom(listOf(mapOf("kind" to "css"), mapOf("kind" to "js", "code" to "ok()"))),
        )
    }
}
```

Add to `FilterEngineTest.kt` (Review Focus 5):

```kotlin
    @Test fun `no rules blocks nothing`() {
        assertNull(FilterEngine(emptyMap()).matches("https://doubleclick.net/pixel"))
    }
```

- [ ] **Step 2: Run to verify they fail**

Run (from `android/`): `./gradlew :app:testDebugUnitTest`
Expected: FAIL — compilation errors: `UserScriptJs`, `originRuleFor`, `InjectedScript`, `injectedScriptsFrom` unresolved.

- [ ] **Step 3: Extend `SiteConfig`**

In `SiteConfig.kt`, add two fields after `wipeOnExit` (defaults keep `RouterTest`'s constructor call compiling):

```kotlin
    val wipeOnExit: Boolean,
    /** The open vault's enabled filter lists' `||host^` rules, by category.
     *  Chosen by Dart; empty blocks nothing. */
    val filterRules: Map<String, List<String>> = emptyMap(),
    /** The library scripts applied to this site, in library order. */
    val userScripts: List<InjectedScript> = emptyList(),
)

/** One library script as Dart sends it: `kind` is `css` or `js`. */
data class InjectedScript(val kind: String, val code: String, val atDocumentStart: Boolean)

/** Reads the `userScripts` argument. An entry without a kind or code is
 *  skipped rather than failing the whole open. */
fun injectedScriptsFrom(raw: List<Map<String, Any?>>?): List<InjectedScript> =
    raw.orEmpty().mapNotNull { entry ->
        val kind = entry["kind"] as? String ?: return@mapNotNull null
        val code = entry["code"] as? String ?: return@mapNotNull null
        InjectedScript(kind, code, entry["atDocumentStart"] as? Boolean ?: false)
    }
```

- [ ] **Step 4: Write `UserScriptJs.kt`**

```kotlin
package com.mono.container.engine

import java.net.URI

/**
 * The injected source for one library script (spec
 * `2026-09-28-filter-lists-and-scripts-design.md`, "Timing"). Each script is
 * injected on its own, so an error in one cannot stop another, and code is
 * placed as written — never through `eval`, which a page's
 * Content-Security-Policy would block.
 */
object UserScriptJs {
    fun wrap(kind: String, code: String, atDocumentStart: Boolean): String? = when (kind) {
        "css" -> css(code, atDocumentStart)
        "js" -> js(code, atDocumentStart)
        else -> null
    }

    private fun css(code: String, atDocumentStart: Boolean): String {
        val add = "function(){var s=document.createElement('style');" +
            "s.textContent=${code.asJsString()};" +
            "(document.head||document.documentElement).appendChild(s);}"
        return if (atDocumentStart) {
            "(function(){var add=$add;" +
                "if(document.documentElement){add();}else{document.addEventListener('DOMContentLoaded',add);}})();"
        } else {
            "document.addEventListener('DOMContentLoaded',$add);"
        }
    }

    // The closer goes on its own line so a trailing `//` comment in [code]
    // cannot comment it out.
    private fun js(code: String, atDocumentStart: Boolean): String =
        if (atDocumentStart) "$code\n"
        else "document.addEventListener('DOMContentLoaded',function(){\n$code\n});"
}

/**
 * The `allowedOriginRules` entry that confines a library script to its
 * site: `scheme://host`, with the port only when it is not the default.
 * Null — and so no injection — for anything that is not an http(s) URL.
 */
fun originRuleFor(url: String): String? {
    val uri = runCatching { URI(url) }.getOrNull() ?: return null
    val scheme = uri.scheme?.lowercase() ?: return null
    if (scheme != "http" && scheme != "https") return null
    val host = uri.host?.lowercase() ?: return null
    val defaultPort = if (scheme == "https") 443 else 80
    return if (uri.port == -1 || uri.port == defaultPort) "$scheme://$host" else "$scheme://$host:${uri.port}"
}
```

- [ ] **Step 5: Run the JVM tests**

Run (from `android/`): `./gradlew :app:testDebugUnitTest`
Expected: PASS. Read `build/app/test-results/testDebugUnitTest/TEST-com.mono.container.engine.UserScriptJsTest.xml` (`tests="9" failures="0"`), `...InjectedScriptsFromTest.xml` (`tests="2"`), `...FilterEngineTest.xml` (one more test than before, `failures="0"`).

- [ ] **Step 6: Inject in `Shields`, read the keys, build the blocker from them**

`Shields.kt` — at the end of `apply`, after the existing `addDocumentStartJavaScript(webView, js, setOf("*"))` call:

```kotlin
        // Library scripts: one injection each, confined to the site's own
        // origin (Shields above runs everywhere). No origin, no scripts.
        val origin = originRuleFor(config.url) ?: return
        for (script in config.userScripts) {
            val source = UserScriptJs.wrap(script.kind, script.code, script.atDocumentStart) ?: continue
            androidx.webkit.WebViewCompat.addDocumentStartJavaScript(webView, source, setOf(origin))
        }
```

`EngineChannel.kt`:
1. `class Session(val config: SiteConfig, rulesByCategory: Map<String, List<String>>) {` → `class Session(val config: SiteConfig) {`, and `val filters = FilterEngine(rulesByCategory)` → `val filters = FilterEngine(config.filterRules)`. Update the doc comment above `Session` to add: "Its rules are the open vault's enabled lists, sent by Dart with each open."
2. Delete the `rulesByCategory` lazy property and the `readAsset` function.
3. Replace both `Session(config, rulesByCategory)` with `Session(config)`.
4. In `configFrom`, after `wipeOnExit = ...`, add:

```kotlin
        filterRules = call.argument<Map<String, List<String>>>("filterRules") ?: emptyMap(),
        userScripts = injectedScriptsFrom(call.argument<List<Map<String, Any?>>>("userScripts")),
```

Delete `android/app/src/main/assets/filters/default_trackers.txt` and `default_ads.txt` (`git rm -r android/app/src/main/assets/filters`).

- [ ] **Step 7: Verify the Kotlin compiles and every check passes**

Run (from `android/`): `./gradlew :app:testDebugUnitTest` — Expected: PASS, counts as in Step 5.
Run (from the repo root): `flutter build apk --debug` — Expected: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`, and `grep -c "^e:"` on its output prints `0`.
Run: `grep -rn "readAsset\|rulesByCategory\|default_trackers" android/app/src/main` — Expected: no output.
Run: `flutter analyze` and `flutter test` — Expected: clean; all pass.

- [ ] **Step 8: Commit**

```bash
git add -A android/app/src
git commit -m "feat: build each site's blocker from its lists and inject its scripts"
```

---

### Task 5: Verify on the emulator and record the result

**Files:**
- Modify: `CLAUDE.md` (plan table row; Plan 5 gaps note)
- Modify: `docs/superpowers/plans/2026-08-30-isolated-web-container-05-workspaces-and-scripts.md` (Known gaps)
- Modify: this plan (append "Verification" and "Known gaps")

**Interfaces:**
- Consumes: everything above. Produces: documentation only.

- [ ] **Step 1: Install on the emulator**

Run: `flutter build apk --debug` then `adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
If no emulator or device is attached (`adb devices` lists none), record Steps 2–3 as **UNREACHABLE** in Step 4 and do not claim them.

- [ ] **Step 2: Filter list check**

Add a direct site whose URL is `https://platform.twitter.com/widgets.js` — a
Social embeds host and in no other list. The main-frame request goes through
the same blocker as a page's sub-requests, so the site's own count shows
whether the list applied. (A local `http://` test page would not work: the
app declares no cleartext exception, so Android refuses it before any
embed request is made.)

1. With Social embeds **off** (the default), open the site. The script's
   text loads. Close it and open Today from the dashboard menu: no Ads count.
2. In Settings → Scripts and filters, turn Social embeds **on**. Reopen the
   site: it is blocked (empty page). Today's Ads row now reads at least 1.
3. Turn Trackers and ads **off** as well and open any site that loads
   `googletagmanager.com` (most news sites): no Trackers count accrues from
   it — the old hardcoded lists are gone.

Screenshots are black under `FLAG_SECURE`; read the UI with
`adb shell uiautomator dump /sdcard/window_dump.xml` and
`adb pull /sdcard/window_dump.xml`.

- [ ] **Step 3: Script check**

Applying a script to a site needs the script editor's "+ Add site" picker,
which is not built (UI — the other session's area), and the vault is
encrypted, so it cannot be written from `adb` either. Check whether the
picker exists on `main` by then:

- **If it does:** create a JS script with code
  `console.log('container-script-ran')`, apply it to any https site, reopen
  that site, and confirm `adb logcat -d | grep container-script-ran` prints
  a line. Then create a CSS script `body{background:#ff0000 !important}`
  with "Run before the page paints" on, apply it, reopen, and confirm in the
  UI dump or visually on a non-secure build that the background changed.
- **If it does not:** record the script check as **BLOCKED: no site
  picker**. The injection path is then covered only by the JVM tests
  (`UserScriptJsTest`, `InjectedScriptsFromTest`) and Task 3's Dart tests.

- [ ] **Step 4: Record what was and was not verified**

Append to this plan:

```markdown
## Verification

<date>. JVM tests <n>/<n> (from the JUnit XML), `flutter analyze` clean,
`flutter test` <n>/<n>, `flutter build apk --debug` succeeding with zero
`e:` lines. Emulator: filter-list check <PASSED | UNREACHABLE: reason>;
script check <PASSED | BLOCKED: no site picker | UNREACHABLE: reason>.

## Known gaps

- Script scope is exactly the site's origin: a site that redirects to
  another host (e.g. `example.com` → `www.example.com`) does not get its
  scripts on the redirected host.
- A script can only be attached to sites through data this app's UI cannot
  yet write — the editor's "+ Add site" picker is unbuilt (UI; the other
  session's area). Scripts applied before that exists: none.
- "Next check in N days" counts down from the bundled files' release date
  and reaches 0 a week after each app release; nothing ever checks.
- Changes apply on the next open; open sites keep what they opened with.
- If a site's extras cannot be built (vault read or bundle failure), the
  route stays on the opening checklist until Cancel — there is no copy for
  this failure in the spec.
```

- [ ] **Step 5: Update the two docs**

`CLAUDE.md` — add a table row after Plan 10:

```markdown
| 11 — Filter lists and scripts | `2026-09-28-filter-lists-and-scripts.md` | **Done** (<date>) | Makes `10d`/`10e` real: three bundled rule files (`assets/filters/`), synced into every vault on open (`syncBundledFilterLists`, replacing the mock `seedFilterListsIfEmpty`); on open Dart sends the vault's enabled rules and the site's library scripts (`EngineExtras`), Kotlin builds the site's `FilterEngine` from them and injects each script separately, scoped to the site's origin (`UserScriptJs`). Implements `docs/superpowers/specs/2026-09-28-filter-lists-and-scripts-design.md`. See the plan's Verification and Known gaps. |
```

Plan 5's Known gaps — append to the `FilterList.enabled` and `UserScript.code` bullets: `**Fixed <date> by Plan 11** (`2026-09-28-filter-lists-and-scripts.md`).`

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md docs/superpowers/plans
git commit -m "docs: record filter lists and scripts reaching the engine"
```

# Isolated Web Container — Plan 12: Browser Chrome and Navigation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. This plan is meant to be executed inline by one agent with `superpowers:executing-plans`, in a git worktree on branch `plan-12-browser-chrome`.

**Goal:** Rebuild the container screen (`2b`) as layout C: a real browser around each isolated site, with in-page back/forward/stop and load progress, an address bar that opens this container, a saved site's own container, or an in-memory **throwaway** container on the same route, find in page, a ☰ menu, drawn line icons, and a search-engine setting in `2d`.

**Architecture:** Pure-Dart domain code decides what typed text means and where it opens (`parseAddressInput`, `SearchEngine`, `resolveDestination`, `suggestionsFor`, `buildThrowaway`). Kotlin's `ContainerView` reports every page change as a `navigation` event and every finished find as a `find_result` event, and gains `goBack`/`goForward`/`stop`/`loadUrl`/`find`/`findNext`/`clearFind`/`navigationState`/`keep`; a throwaway's profile id is journaled in `filesDir/throwaway-profiles` so a crash cannot leak it. In Dart, `ContainerRoute` owns the engine and the route stack (a saved site or a throwaway is **pushed** on the nested `_OpenVault` navigator), while a stateful `ContainerScreen` owns only which chrome shows — top bar, address editing, or find bar — around a page view whose position in the tree never changes.

**Tech Stack:** Flutter/Dart 3, `flutter_riverpod` 2.6, `sqflite_sqlcipher` (+ `sqflite_common_ffi` in tests), Kotlin, `androidx.webkit` 1.12 (`WebView.findAllAsync`, `setFindListener`), JUnit 4. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-28-browser-chrome-design.md` ("Browser chrome and navigation", project 1 of 4; supersedes canvas screen `2b`). Read it alongside this plan. Its §1 prerequisite (the nested `_OpenVault` navigator, `6a5f013`) is merged into `main`, and its §10 coordination note is resolved: Plan 11 (filter lists and scripts) is merged, so this plan is written against `main` as it is — `5934881`, which also carries the script editor's site picker and `closeSite` (a session closed from a container stops reading as open, `1f7f9a3`). Every close path this plan rewrites keeps its `closeSite` call.

## Global Constraints

From `CLAUDE.md` and the spec; every task's requirements include these.

- **Copy is verbatim.** Only strings in spec §7 or `Sandbox Container -canvas-.dc.html`. Never invent, paraphrase or re-capitalise. A step that would need a string found in neither is listed under "Design questions" below and built so it does not need it.
- **Jade `#7FC8A9` (`C.jade`)** means live state or the single affirmative action. The load line is `C.textMuted`, the address cursor `C.textPrimary`, the save bar neutral. Jade stays on the live dot.
- **No network requests of the app's own.** Suggestions come only from the open vault; nothing is fetched while typing. A search reaches the engine only when the user opens the search row.
- **Two-vault model.** Nothing asks which vault is open. Throwaways live in memory and are cleared on every transition out of `SessionOpen`, so a throwaway from one vault can never be seen from the other.
- **The interceptor never falls back to direct.** A throwaway inherits the current container's route exactly — `proxyMode`, `proxyHost`, `proxyPort`.
- **`loadUrl` refuses every scheme but `http`/`https`** on the Kotlin side too, even though the Dart parser never produces another.
- **Every `ContainerRoute` push lands on the nested `_OpenVault` navigator:** `Navigator.push(context, …)` from inside the open vault, never `rootNavigator`, and never `useRootNavigator: true` on a sheet or dialog (`CLAUDE.md` Device verification, `6a5f013`).
- **`ContainerRoute` never builds the page view off a session it did not open itself** (`_openReturned`, `5b53462`). A pushed saved-site container and a throwaway keep that property.
- **The page view's position in the tree never changes.** Rebuilding `ContainerWebView` disposes the native WebView — which wipes a throwaway and reloads anything else. Chrome that comes and goes is swapped above the page or stacked after it, never inserted before it.
- **`ProfileManager.wipe` journals an in-use profile** (`PendingDeletions.kt`) instead of deleting it. The throwaway journal is a second, separate file that works with that one; it replaces nothing. Don't "simplify" `wipe` back to a bare `deleteProfile`.
- **`androidx.webkit`'s `ProfileStore` is UI-thread-only; proxy probing never runs on the main thread** (`a42896d`).
- **No provider is modified from `dispose()`.** Riverpod throws for a provider changed while the widget tree is locked. `ContainerRoute.dispose` only calls the engine it captured in `initState`.
- **Kotlin tests:** `android/gradlew*` and `android/gradle/wrapper/gradle-wrapper.jar` are git-ignored; `flutter build apk --debug` writes them (and `android/local.properties`), so run it once before the first Kotlin test run in a fresh worktree. Then, from `android/`: `./gradlew :app:testDebugUnitTest` (Windows cmd/PowerShell: `.\gradlew.bat :app:testDebugUnitTest`). Read counts from `build/app/test-results/testDebugUnitTest/TEST-*.xml`, never from `BUILD SUCCESSFUL`.
- **`flutter analyze` and `flutter test` never compile `android/…/engine/`.** Every task that touches Kotlin also runs `flutter build apk --debug` and requires zero lines starting `e:`.
- **Every task ends green:** `flutter analyze` reports "No issues found!" (it fails on infos too — if it asks for a `const` in code this task added, add it), `flutter test` passes in full, and a Kotlin task also passes its JVM tests and the APK build. One commit per task, in the repo's `feat:`/`fix:`/`test:`/`docs:` style.

## Deviations from the spec (deliberate)

1. **Mullvad Leta is dropped.** It shut down on 2025-11-27 (<https://mullvad.net/en/blog/2025/11/6/shutting-down-our-search-proxy-leta>; `leta.mullvad.net` says so). Spec §4.2's own rule: "Any engine that no longer works is dropped from the enum rather than shipped broken." So `enum SearchEngine { duckDuckGo, startpage, braveSearch }` and the picker lists three names. A stored value of `mullvadLeta` (none can exist) reads as the default. Brave Search's template answered HTTP 200 during planning; Startpage's GET template could not be reached from the planning machine (a network restriction, not evidence it is wrong), so it is kept and checked on the emulator in Task 14.
2. **`AppIcon` is a widget; its `CustomPainter` is `AppIconPainter`.** Spec §6.6 calls `AppIcon` "a `CustomPainter`". Every caller wants a sized widget, so the widget takes the name and the painter sits behind it. `IconTap` (a 40px round or square tap target drawn as one icon, with its screen-reader label) is added beside it so every chrome button shares one implementation.
3. **The start sweep keeps a throwaway whose wipe throws.** Spec §5.4 says every listed id is wiped "and then the file is cleared". An id whose wipe failed is left listed for the next start instead of being forgotten with nothing wiped.
4. **`ContainerRoute` closes a throwaway's native session when the route is disposed** (popped, or torn down by a lock or panic). Spec §5.2 names only `ContainerView.dispose`'s `wipeOnExit` path; that path still does the wipe, and the close guarantees it runs even if Flutter's platform-view teardown lags, and stops the native session list from carrying a dead throwaway. A saved site's session is left open on pop, as today.
5. **`suggestionsFor` also takes the vault's workspaces**, so a saved-site row's mono line can read `host · Workspace` (the brainstorm mockup's `market.example.com · Personal`, and `6c`'s own subtitle format). Plan 7's name/host matching moves to `lib/domain/site_search.dart` (`sitesMatching`) so domain code can reuse it; `searchResults` now calls it, unchanged in behaviour.
6. **The route passed `DIRECT` as the pill's route label** for a direct site, contradicting `ContainerTopBar`'s own contract and §4.4's "there is no DIRECT label". Rewiring the route passes an empty label for a direct site.
7. **`SettingsRoute` becomes public.** Today it is `_SettingsRoute` inside `dashboard_screen.dart`; the ☰ menu's `Settings` row needs it, so it moves to `lib/ui/features/settings/views/settings_route.dart` with `settingsDestination`.
8. **Opening a saved site from the address bar marks it open and records the visit** (`openSite`), exactly as the dashboard and search already do.
9. **The address and find fields ask the keyboard not to learn** (`enableIMEPersonalizedLearning: false`, `autocorrect: false`, `enableSuggestions: false`). Not in the spec; it keeps typed addresses out of the keyboard app's dictionary, in the spirit of "nothing leaves this device".

## Decisions this plan makes where the spec is silent

Each is behaviour, not copy; flag any the user disagrees with.

- **`6c` on a throwaway** (the shield opens `6c` for every container): its two switches change only the running page's record in memory — a throwaway never reopens, and writing it to the vault would break §5.1 — and its `Edit` runs the save flow (`Save as a site`), since editing a throwaway means saving it. Its subtitle shows the host alone, like the ☰ header (§6.4).
- **System back also closes the find bar.** §6.2 only says back leaves address editing. Back while finding closes find; it never goes back in history under an open find bar.
- **The pill falls back to the saved site's host** whenever the page's URL has no host (`about:blank`, a failed load), not only before the first event.
- **The `Search engine` row shows no value while the setting loads** rather than guessing a name.
- **The picker's check is `Icons.check` at 15px in `C.jade`**, the existing precedent for a selected row (`workspace_menu.dart`).
- **The ☰ sheet opens with `isScrollControlled: true`.** Its content (~460px) is taller than a modal sheet's default 9/16 height cap on a 360×740 phone.
- **Editing starts with the current address's suggestions already listed** — the address row (`THIS CONTAINER`) and the search row — rather than an empty list until the first keystroke.
- **Submitting with nothing typed leaves editing**, like back: there is no address row and no search row to open.
- **A tap on a section label or the footer of the suggestions leaves editing**, like any tap that is not on a row.
- **Previous and next match are dimmed and inert until the page reports a match**, and the count is dropped whenever the find text changes, until the page reports the new one.
- **`sessionForSiteProvider` and `navigationForSiteProvider` are auto-disposed with their route.** A throwaway's id is never seen again, so a family kept for the app's life would hold one engine subscription per throwaway ever opened; and a site opened again starts from its new page, not the last visit's address and history.
- **The save bar's "hairline below" is the bottom bar's own**, not a second line drawn under it.
- **The ☰ rows end in the drawn `forward` chevron**, not `2d`'s `›` glyph: they are a new widget, and §6.6 draws the new widgets' icons.

## Design questions (not invented; built so no step needs an answer)

1. **The save bar's × has no screen-reader label.** Spec §7's label list has none for it, so it ships unlabelled (tests find it by `Key('save-bar-dismiss')`). Which label, if any?
2. **Typing the address of a saved site that already has a container lower in this stack** pushes a second container for it (spec §5.2: "push a new `ContainerRoute`"). The engine keys sessions by site id, so the newer open replaces the native session; once the top one is popped, the lower one's back, forward, reload and find act on nothing until it is reopened. Should the address bar instead return to the existing container? Implemented as specified; recorded in Known gaps.
3. **The rulings above on `6c` for a throwaway and on back closing find** are the spec's to confirm.
4. **A Unicode host typed bare (`münchen.de`) is searched for**, because §4.1's bare-host rule only admits letter/digit/hyphen labels. Should IDN hosts be typeable?

## Review Focus

The five inputs or failure modes the spec implies, no spec-listed test exercises, and a person using this is most likely to hit. Each has a test in the task named.

1. **The page view rebuilt when the chrome changes mode** — editing, find, the save bar appearing or being dismissed. A rebuild disposes the native WebView, which *wipes a throwaway* and reloads a saved site. Expect the same view state throughout. Pinned in Tasks 12 and 13 (`ContainerScreen` and `ContainerRoute` tests).
2. **System back while editing or finding.** Expect it to leave editing (or close find) without navigating in the page and without popping the container. Pinned in Tasks 12 and 13.
3. **A dangerous scheme hidden by case or whitespace** — `  JavaScript:alert(1)`, `FILE:///etc/hosts`, `http://javascript:alert(1)` — and, on the Kotlin side, ` https://…` with a leading space or `JAVASCRIPT:`. Expect a search in Dart and a refusal in Kotlin, never a load. Pinned in Tasks 1 and 6.
4. **A throwaway torn down by a lock or panic rather than popped.** Expect its native session closed (so its view is disposed and wiped) exactly as a pop does. Pinned in Task 8.
5. **A 360-wide phone with a long host, a route label, a load in progress and the save bar.** Expect no overflow in the top bar, the address and find bars, the save bar or the ☰ sheet. Pinned in Tasks 10–13.

## Before Task 1: baseline

- [ ] **Step 1: Create the worktree** with `superpowers:using-git-worktrees`, branch `plan-12-browser-chrome` from `main` (`5934881` or later).
- [ ] **Step 2: Make the worktree buildable offline.** This machine cannot reach GitHub (`CLAUDE.md`, "Working on this repo"): the `sqlite3` package's native-assets hook downloads from it, so `flutter test` in a fresh worktree fails with "Building native assets failed" until the main checkout's hook output is copied in. From the worktree root: `mkdir -p .dart_tool && cp -r /c/Users/Metin/Desktop/flutter-app/.dart_tool/hooks_runner .dart_tool/`. Flutter and Gradle commands need the Bash sandbox disabled.
- [ ] **Step 3: Record the baseline** in the worktree:

```bash
flutter pub get
flutter build apk --debug 2>&1 | tee build/apk-build.log
grep -c '^e:' build/apk-build.log    # expect 0
flutter analyze                      # expect "No issues found!"
flutter test                         # note the final "+N: All tests passed!" — call it D0
(cd android && ./gradlew :app:testDebugUnitTest)
grep -ho '<testsuite [^>]*' build/app/test-results/testDebugUnitTest/TEST-*.xml \
  | sed -E 's/.* tests="([0-9]+)".* failures="([0-9]+)" errors="([0-9]+)".*/\1 \2 \3/' \
  | awk '{t+=$1; f+=$2; e+=$3} END {print t" tests, "f" failures, "e" errors"}'
                                     # call the test total K0; failures and errors must be 0
```

Every later "Kotlin counts" check uses the same `grep | sed | awk` line. This plan adds 118 Dart tests (it rewrites `container_screen_test.dart`, whose 5 tests are replaced by 14) and 21 Kotlin tests: the final totals are D0 + 118 and K0 + 21.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/domain/models/address_input.dart` (new) | `AddressInput` (`AddressUrl`/`AddressSearch`/`AddressEmpty`), `parseAddressInput` — §4.1 |
| `lib/domain/models/search_engine.dart` (new) | `SearchEngine` enum: label, template, `resultsFor`, `host`, `fromStored` — §4.2 |
| `lib/domain/models/destination.dart` (new) | `Destination` (`ThisContainer`/`SavedSiteContainer`/`Throwaway`), `normalizeHost`, `resolveDestination`, `destinationFor` — §4.3 |
| `lib/domain/models/throwaway.dart` (new) | `buildThrowaway` — §5.1 |
| `lib/domain/site_search.dart` (new) | `sitesMatching` — Plan 7's name/host match and recency order, shared |
| `lib/domain/models/address_suggestion.dart` (new) | `AddressSuggestion`, `SuggestionKind`, `destinationTag`, `suggestionsFor` — §4.4 |
| `lib/ui/features/search/view_models/search_view.dart` | `searchResults` calls `sitesMatching` |
| `lib/domain/repositories/repositories.dart`, `lib/data/repositories/settings_repository_sqlite.dart` | `getString`/`setString` |
| `lib/ui/features/settings/view_models/providers.dart` | `searchEngineProvider`, `SettingsController.setSearchEngine` |
| `lib/ui/features/settings/views/settings_screen.dart` | `BROWSING` section, `Search engine` row — §6.7 |
| `lib/ui/features/settings/views/search_engine_picker.dart` (new) | The `Search engine` sheet |
| `lib/ui/features/settings/views/settings_route.dart` (new) | `SettingsRoute` and `settingsDestination`, moved out of `dashboard_screen.dart` |
| `lib/ui/core/icons.dart` (new) | `AppGlyph`, `AppIcon`, `AppIconPainter` — §6.6 |
| `lib/ui/core/widgets/icon_tap.dart` (new) | `IconTap`: one icon as a labelled tap target |
| `lib/ui/core/widgets/pill_button.dart` | Optional `padding`, for a pill that sizes to its label (the save bar's) |
| `lib/domain/models/navigation_state.dart`, `find_result.dart` (new) | `NavigationState`, `FindResult` — §3.2 |
| `lib/data/services/container_engine.dart`, `container_engine_channel.dart`, `fake_container_engine.dart` | Navigation, find, in-page controls, `keep`, `open(throwaway:)` |
| `lib/ui/features/container/view_models/subscribe_then_snapshot.dart` (new) | The subscribe-first-then-snapshot helper extracted from `sessionForSiteProvider` |
| `lib/ui/features/container/view_models/providers.dart` | `sessionForSiteProvider` uses the helper; `navigationForSiteProvider`; both auto-disposed |
| `lib/ui/features/container/view_models/throwaway_sites.dart` (new) | `ThrowawaySites`, `throwawaySitesProvider` — §5.1 |
| `android/…/engine/Navigation.kt` (new) | `NavigationSnapshot`, `NavigationTracker`, `findResultEvent`, `isLoadableUrl` |
| `android/…/engine/ThrowawayJournal.kt` (new) | `ThrowawayJournal`, `wipeThenForget`, `keepThrowaway` — §5.4 |
| `android/…/engine/RequestInterceptor.kt` | `PageCallbacks`; `clientFor` reports page start/finish/history |
| `android/…/engine/Shields.kt` | `chromeClientFor` reports progress and title |
| `android/…/engine/ContainerView.kt` | Navigation state, find listener, in-page controls, wipe via the journal |
| `android/…/engine/ContainerViewFactory.kt` | Wires the view's reports to the channel |
| `android/…/engine/EngineChannel.kt` | New methods and events; `open(throwaway)`; `keep`; `wipeAll` clears the journal |
| `android/…/engine/ProfileManager.kt` | `sweepThrowaways` |
| `android/…/MainActivity.kt` | Creates and sweeps the throwaway journal at start |
| `lib/ui/features/container/views/load_line.dart` (new) | `LoadLine` — §6.1 |
| `lib/ui/features/container/views/panic_square.dart` (new) | `PanicSquare` |
| `lib/ui/features/container/views/container_bottom_bar.dart` (new) | `ContainerBottomBar` — §6.1 |
| `lib/ui/features/container/views/find_bar.dart` (new) | `FindBar` — §6.5 |
| `lib/ui/features/container/views/throwaway_save_bar.dart` (new) | `ThrowawaySaveBar` — §6.3 |
| `lib/ui/features/container/views/address_edit_bar.dart` (new) | The pill as a text field — §6.2 |
| `lib/ui/features/container/views/address_suggestions.dart` (new) | `AddressSuggestions` — §6.2 |
| `lib/ui/features/container/views/browser_menu_sheet.dart` (new) | `BrowserMenuSheet` — §6.4 |
| `lib/ui/features/container/views/container_top_bar.dart` | Rewritten: pill with shield and stop, panic — §6.1 |
| `lib/ui/features/container/views/container_screen.dart` | Rewritten: layout C, chrome modes, `PopScope`, both sheets |
| `lib/ui/features/container/views/container_route.dart` | `initialUrl`, `throwaway`, destinations, save flow, menu, find, navigation |
| `lib/ui/features/container/views/container_toolbar.dart` | Deleted (`2b`'s floating toolbar) |

---

### Task 1: Address input, search engines, destinations and throwaways (pure Dart)

**Files:**
- Create: `lib/domain/models/address_input.dart`, `lib/domain/models/search_engine.dart`, `lib/domain/models/destination.dart`, `lib/domain/models/throwaway.dart`
- Test: `test/domain/address_input_test.dart`, `test/domain/search_engine_test.dart`, `test/domain/destination_test.dart`, `test/domain/throwaway_test.dart`

**Interfaces:**
- Consumes: `Site`, `ProxyMode`, `CookiePolicy` (`lib/domain/models/site.dart`); `suggestMonogram(String)` (`monogram_suggestion.dart`); `selectUserScripts` and `UserScript` (tests only).
- Produces:
  - `sealed class AddressInput`; `AddressEmpty()`; `AddressUrl(Uri url)`; `AddressSearch(String query)`; `AddressInput parseAddressInput(String raw)`
  - `enum SearchEngine { duckDuckGo, startpage, braveSearch }` with `String label`, `String template`, `Uri resultsFor(String query)`, `String get host`, `static SearchEngine fromStored(String? name)`
  - `sealed class Destination { Uri get url; }`; `ThisContainer(Uri url)`; `SavedSiteContainer(Site site, Uri url)`; `Throwaway(Uri url, ProxyMode mode, String? proxyHost, int? proxyPort)`
  - `String normalizeHost(String host)`
  - `Destination resolveDestination({required AddressInput input, required Site current, required List<Site> saved, required SearchEngine engine})` — throws `ArgumentError` for `AddressEmpty`
  - `Destination destinationFor(Uri url, {required Site current, required List<Site> saved})`
  - `Site buildThrowaway({required Throwaway destination, required Site current, required String Function() newId})`

- [ ] **Step 1: Write the failing tests**

```dart
// test/domain/address_input_test.dart
import 'package:container/domain/models/address_input.dart';
import 'package:flutter_test/flutter_test.dart';

String? _url(String raw) {
  final input = parseAddressInput(raw);
  return input is AddressUrl ? input.url.toString() : null;
}

String? _search(String raw) {
  final input = parseAddressInput(raw);
  return input is AddressSearch ? input.query : null;
}

void main() {
  test('nothing but whitespace is empty', () {
    expect(parseAddressInput(''), isA<AddressEmpty>());
    expect(parseAddressInput('   \t'), isA<AddressEmpty>());
  });

  test('anything containing whitespace is a search, trimmed', () {
    expect(_search('  privacy tools  '), 'privacy tools');
    expect(_search('example.com/a b'), 'example.com/a b');
  });

  test('an explicit http or https address is kept as typed, never upgraded', () {
    expect(_url('https://forum.example.com/t/1?page=2#top'),
        'https://forum.example.com/t/1?page=2#top');
    expect(_url('http://forum.example.com'), 'http://forum.example.com');
  });

  test('an explicit http or https scheme with no host is a search', () {
    expect(_search('https://'), 'https://');
    expect(_search('http:///path'), 'http:///path');
  });

  test('every other scheme is a search, never an address', () {
    for (final raw in [
      'javascript:alert(1)',
      'file:///etc/hosts',
      'about:blank',
      'intent://scan/#Intent;scheme=zxing;end',
      'content://media/external/images/1',
      'data:text/html,hi',
      'mailto:a@example.com',
      'ftp://example.com',
    ]) {
      expect(parseAddressInput(raw), isA<AddressSearch>(), reason: raw);
    }
  });

  // Review Focus 3.
  test('case and surrounding whitespace do not smuggle a scheme through', () {
    for (final raw in [
      '  JavaScript:alert(1)',
      'JAVASCRIPT:alert(document.cookie)',
      'FILE:///etc/hosts',
      'http://javascript:alert(1)',
    ]) {
      expect(parseAddressInput(raw), isA<AddressSearch>(), reason: raw);
    }
  });

  test('a bare host is tried over https', () {
    expect(_url('forum.example.com'), 'https://forum.example.com');
    expect(_url('  Forum.Example.COM  '), 'https://forum.example.com');
  });

  test('ports, paths, queries and fragments come along', () {
    expect(_url('example.com:8080/a/b?c=1#d'), 'https://example.com:8080/a/b?c=1#d');
    expect(_url('example.com?q=1'), 'https://example.com?q=1');
  });

  test('localhost and IPv4 literals are addresses', () {
    expect(_url('localhost'), 'https://localhost');
    expect(_url('localhost:3000/api'), 'https://localhost:3000/api');
    expect(_url('192.168.1.10'), 'https://192.168.1.10');
    expect(_url('10.0.2.2:8888/x'), 'https://10.0.2.2:8888/x');
  });

  test('what only looks like a host is a search', () {
    for (final raw in [
      'example',
      'example.c',
      'example.123',
      '999.1.1.1',
      'example.com:99999',
      'user@example.com',
      '-bad.example.com',
    ]) {
      expect(parseAddressInput(raw), isA<AddressSearch>(), reason: raw);
    }
  });
}
```

```dart
// test/domain/search_engine_test.dart
import 'package:container/domain/models/search_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('each engine builds its results address with the query encoded', () {
    expect(SearchEngine.duckDuckGo.resultsFor('privacy tools').toString(),
        'https://duckduckgo.com/?q=privacy+tools');
    expect(SearchEngine.startpage.resultsFor('a&b').toString(),
        'https://www.startpage.com/sp/search?query=a%26b');
    expect(SearchEngine.braveSearch.resultsFor('café #1').toString(),
        'https://search.brave.com/search?q=caf%C3%A9+%231');
  });

  test('the picker lists the three engines by their spec names; Mullvad Leta is gone', () {
    expect(SearchEngine.values.map((e) => e.label),
        ['DuckDuckGo', 'Startpage', 'Brave Search']);
    expect(SearchEngine.values.map((e) => e.name), isNot(contains('mullvadLeta')));
  });

  test('each engine names its own host, shown under the search row', () {
    expect(SearchEngine.values.map((e) => e.host),
        ['duckduckgo.com', 'www.startpage.com', 'search.brave.com']);
  });

  test('a stored engine reads back; anything else is DuckDuckGo', () {
    expect(SearchEngine.fromStored('braveSearch'), SearchEngine.braveSearch);
    expect(SearchEngine.fromStored('startpage'), SearchEngine.startpage);
    expect(SearchEngine.fromStored(null), SearchEngine.duckDuckGo);
    expect(SearchEngine.fromStored(''), SearchEngine.duckDuckGo);
    expect(SearchEngine.fromStored('mullvadLeta'), SearchEngine.duckDuckGo);
  });
}
```

```dart
// test/domain/destination_test.dart
import 'package:container/domain/models/address_input.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(
  String id,
  String url, {
  String workspaceId = 'w1',
  DateTime? visited,
  ProxyMode mode = ProxyMode.direct,
  String? proxyHost,
  int? proxyPort,
}) =>
    Site(
      id: id, workspaceId: workspaceId, name: id, monogram: 'Xx', url: url,
      profileId: 'p-$id', proxyMode: mode, proxyHost: proxyHost,
      proxyPort: proxyPort, lastVisitedAt: visited,
    );

final _forum = _site('forum', 'https://forum.example.com',
    mode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050);

Destination _resolve(String raw, {Site? current, List<Site> saved = const []}) =>
    resolveDestination(
      input: parseAddressInput(raw),
      current: current ?? _forum,
      saved: saved,
      engine: SearchEngine.duckDuckGo,
    );

void main() {
  test("this container's own host stays in this container", () {
    final destination = _resolve('forum.example.com/latest');
    expect(destination, isA<ThisContainer>());
    expect(destination.url.toString(), 'https://forum.example.com/latest');
  });

  test('a leading www. and letter case do not change the host', () {
    expect(_resolve('WWW.Forum.Example.com/x'), isA<ThisContainer>());
    final market = _site('market', 'https://www.market.example.com');
    expect(_resolve('market.example.com', saved: [market]), isA<SavedSiteContainer>());
  });

  test('a subdomain is a different host', () {
    expect(_resolve('mail.forum.example.com'), isA<Throwaway>());
  });

  test("a saved site's host opens its own container at the typed address", () {
    final market = _site('market', 'https://market.example.com');
    final destination = _resolve('market.example.com/deals', saved: [market]);
    expect((destination as SavedSiteContainer).site.id, 'market');
    expect(destination.url.toString(), 'https://market.example.com/deals');
  });

  test('ties go to this workspace first, then the most recent visit', () {
    final older = _site('a', 'https://news.example.org',
        workspaceId: 'w2', visited: DateTime(2026, 9, 1));
    final newer = _site('b', 'https://news.example.org',
        workspaceId: 'w2', visited: DateTime(2026, 9, 20));
    final here = _site('c', 'https://news.example.org',
        workspaceId: 'w1', visited: DateTime(2026, 8, 1));
    final never = _site('d', 'https://news.example.org', workspaceId: 'w2');

    SavedSiteContainer pick(List<Site> saved) =>
        _resolve('news.example.org', saved: saved) as SavedSiteContainer;

    expect(pick([older, newer]).site.id, 'b');
    expect(pick([older, newer, here]).site.id, 'c');
    expect(pick([never, older]).site.id, 'a');
  });

  test("a search opens the engine's results, in the engine's own container if saved", () {
    final search = _resolve('privacy tools');
    expect(search, isA<Throwaway>());
    expect(search.url.toString(), 'https://duckduckgo.com/?q=privacy+tools');

    final duck = _site('ddg', 'https://duckduckgo.com');
    expect(_resolve('privacy tools', saved: [duck]), isA<SavedSiteContainer>());
  });

  test('a throwaway inherits the route exactly: direct, SOCKS5 or http', () {
    final direct = _site('d', 'https://d.example.com');
    final http = _site('h', 'https://h.example.com',
        mode: ProxyMode.http, proxyHost: '10.0.2.2', proxyPort: 8888);
    for (final current in [direct, _forum, http]) {
      final destination =
          _resolve('elsewhere.example.net', current: current) as Throwaway;
      expect(destination.mode, current.proxyMode, reason: current.id);
      expect(destination.proxyHost, current.proxyHost, reason: current.id);
      expect(destination.proxyPort, current.proxyPort, reason: current.id);
    }
  });

  test('nothing typed has no destination', () {
    expect(
      () => resolveDestination(
        input: const AddressEmpty(),
        current: _forum,
        saved: const [],
        engine: SearchEngine.duckDuckGo,
      ),
      throwsArgumentError,
    );
  });
}
```

```dart
// test/domain/throwaway_test.dart
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/throwaway.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:flutter_test/flutter_test.dart';

/// A site with every setting moved off its default, so inheritance shows.
final _current = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p-forum',
  blockWebRtc: false, blockTrackers: false, antiFingerprinting: false,
  allowCamera: true, allowMicrophone: true, allowLocation: true,
  allowClipboard: true, userAgentMode: UserAgentMode.desktop,
  forceDark: false, openInReader: true, pageZoom: 150,
  customCss: 'a{}', customJs: 'x()', cookiePolicy: CookiePolicy.keep,
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
  requirePin: true, showInDecoy: true,
  lastVisitedAt: DateTime(2026, 9, 1), sortIndex: 4,
);

Site _build() {
  final destination = destinationFor(
    Uri.parse('https://news.example.org/today'),
    current: _current,
    saved: const [],
  ) as Throwaway;
  var next = 0;
  return buildThrowaway(
    destination: destination,
    current: _current,
    newId: () => 'id${next++}',
  );
}

void main() {
  test('only the route is inherited; everything else is the safe default', () {
    final throwaway = _build();
    const defaults = Site(
        id: '', workspaceId: '', name: '', monogram: '', url: '', profileId: '');

    expect(throwaway.id, 'id0');
    expect(throwaway.profileId, 'id1');
    expect(throwaway.workspaceId, 'w1');
    expect(throwaway.name, 'news.example.org');
    expect(throwaway.monogram, 'Nw');
    expect(throwaway.url, 'https://news.example.org/today');
    expect(throwaway.cookiePolicy, CookiePolicy.wipeOnExit);
    expect(throwaway.proxyMode, ProxyMode.socks5);
    expect(throwaway.proxyHost, '127.0.0.1');
    expect(throwaway.proxyPort, 9050);

    expect(throwaway.blockWebRtc, defaults.blockWebRtc);
    expect(throwaway.blockTrackers, defaults.blockTrackers);
    expect(throwaway.antiFingerprinting, defaults.antiFingerprinting);
    expect(throwaway.allowCamera, defaults.allowCamera);
    expect(throwaway.allowMicrophone, defaults.allowMicrophone);
    expect(throwaway.allowLocation, defaults.allowLocation);
    expect(throwaway.allowClipboard, defaults.allowClipboard);
    expect(throwaway.userAgentMode, defaults.userAgentMode);
    expect(throwaway.forceDark, defaults.forceDark);
    expect(throwaway.openInReader, defaults.openInReader);
    expect(throwaway.pageZoom, defaults.pageZoom);
    expect(throwaway.customCss, defaults.customCss);
    expect(throwaway.customJs, defaults.customJs);
    expect(throwaway.requirePin, defaults.requirePin);
    expect(throwaway.showInDecoy, defaults.showInDecoy);
    expect(throwaway.lastVisitedAt, isNull);
    expect(throwaway.sortIndex, 0);
  });

  test('it never takes a library script applied to the site it was typed in', () {
    const script = UserScript(
      id: 'sc', name: 'Hide', kind: ScriptKind.css, code: 'a{}',
      runAtDocumentStart: false, enabled: true, appliedSiteIds: ['forum'],
    );
    expect(selectUserScripts(_build(), const [script]), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/domain/address_input_test.dart test/domain/search_engine_test.dart test/domain/destination_test.dart test/domain/throwaway_test.dart`
Expected: FAIL — compile errors, the four `lib/domain/models/…` files do not exist.

- [ ] **Step 3: Write `address_input.dart`**

```dart
// lib/domain/models/address_input.dart

/// What the address field's text means (spec
/// `2026-09-28-browser-chrome-design.md` §4.1). Pure Dart.
sealed class AddressInput {
  const AddressInput();
}

/// Nothing but whitespace.
class AddressEmpty extends AddressInput {
  const AddressEmpty();
}

/// An `http` or `https` address, ready to load.
class AddressUrl extends AddressInput {
  const AddressUrl(this.url);

  final Uri url;
}

/// Words for the search engine. [query] is the input, trimmed.
class AddressSearch extends AddressInput {
  const AddressSearch(this.query);

  final String query;
}

final _whitespace = RegExp(r'\s');
final _explicitWeb = RegExp(r'^https?://', caseSensitive: false);

/// `host.tld` (last label two or more letters), `localhost` or an IPv4
/// literal; then an optional `:port`; then an optional path, query or
/// fragment. Labels are letters, digits and hyphens only, so no scheme,
/// userinfo or Unicode host ever matches.
final _bareAddress = RegExp(
  r'^(localhost|(?:\d{1,3}\.){3}\d{1,3}|(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63})'
  r'(?::(\d{1,5}))?'
  r'([/?#].*)?$',
  caseSensitive: false,
);

final _ipv4 = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');

AddressInput parseAddressInput(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return const AddressEmpty();
  if (_whitespace.hasMatch(text)) return AddressSearch(text);

  if (_explicitWeb.hasMatch(text)) {
    final url = Uri.tryParse(text);
    return url != null && url.host.isNotEmpty ? AddressUrl(url) : AddressSearch(text);
  }

  final match = _bareAddress.firstMatch(text);
  if (match != null && _validHost(match.group(1)!) && _validPort(match.group(2))) {
    // Always https. A failed load is shown as failed; nothing retries over
    // http behind the user's back.
    final url = Uri.tryParse('https://$text');
    if (url != null && url.host.isNotEmpty) return AddressUrl(url);
  }

  // Every other scheme — javascript:, file:, intent:, about:, … — lands here
  // with everything else that is not an address: searched for, never loaded.
  return AddressSearch(text);
}

bool _validHost(String host) {
  final octets = _ipv4.firstMatch(host);
  if (octets == null) return true;
  for (var i = 1; i <= 4; i++) {
    if (int.parse(octets.group(i)!) > 255) return false;
  }
  return true;
}

bool _validPort(String? port) => port == null || int.parse(port) <= 65535;
```

- [ ] **Step 4: Write `search_engine.dart`**

```dart
// lib/domain/models/search_engine.dart

/// The fixed list in Settings (spec §4.2, §6.7). No custom engines, no
/// suggestions.
///
/// Mullvad Leta is not here: it shut down on 2025-11-27, and the spec drops
/// an engine that no longer works rather than ship it broken.
enum SearchEngine {
  duckDuckGo('DuckDuckGo', 'https://duckduckgo.com/?q='),
  startpage('Startpage', 'https://www.startpage.com/sp/search?query='),
  braveSearch('Brave Search', 'https://search.brave.com/search?q=');

  const SearchEngine(this.label, this.template);

  /// The engine's name as the picker and the search row show it (spec §7).
  final String label;

  /// The results address, missing only the encoded query.
  final String template;

  /// The results page for [query]. Nothing is sent until the user opens it.
  Uri resultsFor(String query) =>
      Uri.parse('$template${Uri.encodeQueryComponent(query)}');

  /// Shown under the search row.
  String get host => Uri.parse(template).host;

  /// Reads the stored `search_engine` setting. Anything unknown — including
  /// no setting at all — is the default.
  static SearchEngine fromStored(String? name) {
    for (final engine in values) {
      if (engine.name == name) return engine;
    }
    return duckDuckGo;
  }
}
```

- [ ] **Step 5: Write `destination.dart`**

```dart
// lib/domain/models/destination.dart
import 'address_input.dart';
import 'search_engine.dart';
import 'site.dart';

/// Where a typed address or search opens (spec §4.3).
sealed class Destination {
  const Destination();

  Uri get url;
}

/// Loads in place, in the container it was typed in.
class ThisContainer extends Destination {
  const ThisContainer(this.url);

  @override
  final Uri url;
}

/// Opens [site]'s own container — pushed over this one — at [url].
class SavedSiteContainer extends Destination {
  const SavedSiteContainer(this.site, this.url);

  final Site site;

  @override
  final Uri url;
}

/// Opens a new throwaway container at [url], on the route of the container
/// it was typed in: [mode], [proxyHost] and [proxyPort] exactly as they are.
class Throwaway extends Destination {
  const Throwaway(this.url, this.mode, this.proxyHost, this.proxyPort);

  @override
  final Uri url;
  final ProxyMode mode;
  final String? proxyHost;
  final int? proxyPort;
}

/// Hosts compare lowercase with one leading `www.` removed. Subdomains stay
/// distinct: `mail.example.com` is not `example.com`.
String normalizeHost(String host) {
  final lower = host.toLowerCase();
  return lower.startsWith('www.') ? lower.substring(4) : lower;
}

/// [current] is the site this container was opened for, not the page it is
/// showing now; [saved] is every site in the open vault. A search becomes
/// [engine]'s results address first, then follows the same rules, so a
/// suggestion's tag is always where it really opens.
Destination resolveDestination({
  required AddressInput input,
  required Site current,
  required List<Site> saved,
  required SearchEngine engine,
}) {
  final url = switch (input) {
    AddressUrl(:final url) => url,
    AddressSearch(:final query) => engine.resultsFor(query),
    AddressEmpty() => throw ArgumentError.value(input, 'input', 'Nothing to open'),
  };
  return destinationFor(url, current: current, saved: saved);
}

/// §4.3's rules for an address already decided.
Destination destinationFor(
  Uri url, {
  required Site current,
  required List<Site> saved,
}) {
  final host = normalizeHost(url.host);
  if (host == normalizeHost(current.host)) return ThisContainer(url);

  final matches = [
    for (final site in saved)
      if (normalizeHost(site.host) == host) site,
  ];
  if (matches.isNotEmpty) {
    matches.sort((a, b) => _preference(a, b, current.workspaceId));
    return SavedSiteContainer(matches.first, url);
  }

  return Throwaway(url, current.proxyMode, current.proxyHost, current.proxyPort);
}

/// Sites in [workspaceId] first, then the most recently visited; never
/// visited last.
int _preference(Site a, Site b, String workspaceId) {
  final aHere = a.workspaceId == workspaceId;
  final bHere = b.workspaceId == workspaceId;
  if (aHere != bHere) return aHere ? -1 : 1;
  final at = a.lastVisitedAt;
  final bt = b.lastVisitedAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}
```

- [ ] **Step 6: Write `throwaway.dart`**

```dart
// lib/domain/models/throwaway.dart
import 'destination.dart';
import 'monogram_suggestion.dart';
import 'site.dart';

/// The in-memory [Site] a throwaway container runs as (spec §5.1). Nothing
/// writes it to the vault until the user saves it.
///
/// Only the route is inherited, carried by [destination] from the container
/// it was typed in. Every other field is `Site()`'s default — trackers,
/// WebRTC and fingerprinting blocked, no hardware or clipboard access, no
/// custom CSS or JS, the Android user agent, force-dark on — so a throwaway
/// never inherits another site's grants. Its id is fresh, so no library
/// script applied to another site selects it either. [current] supplies only
/// the workspace the save form defaults to. [newId] makes the id and the
/// profile id (`newProfileId` in the app).
Site buildThrowaway({
  required Throwaway destination,
  required Site current,
  required String Function() newId,
}) {
  final host = destination.url.host;
  return Site(
    id: newId(),
    profileId: newId(),
    workspaceId: current.workspaceId,
    name: host,
    monogram: suggestMonogram(host),
    url: destination.url.toString(),
    cookiePolicy: CookiePolicy.wipeOnExit,
    proxyMode: destination.mode,
    proxyHost: destination.proxyHost,
    proxyPort: destination.proxyPort,
  );
}
```

- [ ] **Step 7: Run the tests and the gate**

Run: `flutter test test/domain/address_input_test.dart test/domain/search_engine_test.dart test/domain/destination_test.dart test/domain/throwaway_test.dart`
Expected: PASS — 24 tests (10 + 4 + 8 + 2).
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 24.

- [ ] **Step 8: Commit**

```bash
git add lib/domain/models/address_input.dart lib/domain/models/search_engine.dart lib/domain/models/destination.dart lib/domain/models/throwaway.dart test/domain/address_input_test.dart test/domain/search_engine_test.dart test/domain/destination_test.dart test/domain/throwaway_test.dart
git commit -m "feat: parse typed addresses and decide where they open"
```

---

### Task 2: Vault-local address suggestions

**Files:**
- Create: `lib/domain/site_search.dart`, `lib/domain/models/address_suggestion.dart`
- Modify: `lib/ui/features/search/view_models/search_view.dart` (`searchResults`)
- Test: `test/domain/site_search_test.dart`, `test/domain/address_suggestion_test.dart`

**Interfaces:**
- Consumes: Task 1's `parseAddressInput`, `AddressUrl`, `AddressEmpty`, `destinationFor`, `Destination` and subclasses, `SearchEngine`; `Workspace`.
- Produces:
  - `List<Site> sitesMatching(List<Site> sites, String query)`
  - `enum SuggestionKind { savedSite, address, search }`
  - `class AddressSuggestion { SuggestionKind kind; String primary; String secondary; String tag; Destination destination; String? monogram; }`
  - `const maxSavedSuggestions = 5`
  - `String destinationTag(Destination destination)`
  - `List<AddressSuggestion> suggestionsFor({required String text, required Site current, required List<Site> saved, required List<Workspace> workspaces, required SearchEngine engine})`

- [ ] **Step 1: Write the failing tests**

```dart
// test/domain/site_search_test.dart
import 'package:container/domain/models/site.dart';
import 'package:container/domain/site_search.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(String id, String name, String url, {DateTime? visited}) => Site(
      id: id, workspaceId: 'w', name: name, monogram: 'Xx', url: url,
      profileId: 'p-$id', lastVisitedAt: visited,
    );

void main() {
  test('matches name or host, case-insensitively, most recent first', () {
    final forum = _site('f', 'Forum', 'https://forum.example.com',
        visited: DateTime(2026, 9, 1));
    final mail = _site('m', 'Webmail', 'https://mail.example.org',
        visited: DateTime(2026, 9, 20));
    final notes = _site('n', 'Notes', 'https://notes.example.net');

    expect(sitesMatching([forum, mail, notes], 'EXAMPLE').map((s) => s.id),
        ['m', 'f', 'n']);
    expect(sitesMatching([forum, mail, notes], 'mail').map((s) => s.id), ['m']);
  });

  test('an empty query matches every site', () {
    final a = _site('a', 'A', 'https://a.example.com');
    final b = _site('b', 'B', 'https://b.example.com');
    expect(sitesMatching([a, b], '  '), hasLength(2));
  });
}
```

```dart
// test/domain/address_suggestion_test.dart
import 'package:container/domain/models/address_suggestion.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const _personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);
const _work = Workspace(
    id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep);

final _forum = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
  lastVisitedAt: DateTime(2026, 9, 20),
);
final _market = Site(
  id: 'market', workspaceId: 'w1', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'p2',
  lastVisitedAt: DateTime(2026, 9, 10),
);

List<AddressSuggestion> _for(
  String text, {
  Site? current,
  List<Site>? saved,
  SearchEngine engine = SearchEngine.duckDuckGo,
}) =>
    suggestionsFor(
      text: text,
      current: current ?? _forum,
      saved: saved ?? [_forum, _market],
      workspaces: const [_personal, _work],
      engine: engine,
    );

void main() {
  test('a word lists the saved sites it matches, then the search row', () {
    final rows = _for('market');
    expect(rows.map((r) => r.kind), [SuggestionKind.savedSite, SuggestionKind.search]);

    final saved = rows.first;
    expect(saved.primary, 'Marketplace');
    expect(saved.secondary, 'market.example.com · Personal');
    expect(saved.monogram, 'Mk');
    expect(saved.tag, 'ITS OWN CONTAINER');

    final search = rows.last;
    expect(search.primary, 'Search DuckDuckGo for “market”');
    expect(search.secondary, 'duckduckgo.com');
    expect(search.tag, 'THROWAWAY · SOCKS5');
    expect(search.monogram, isNull);
  });

  test('an address lists the address row before the search row', () {
    final rows = _for('news.example.org/today');
    expect(rows.map((r) => r.kind), [SuggestionKind.address, SuggestionKind.search]);
    expect(rows.first.primary, 'news.example.org/today');
    expect(rows.first.secondary, 'not saved');
    expect(rows.first.tag, 'THROWAWAY · SOCKS5');
    expect(rows.first.destination.url.toString(), 'https://news.example.org/today');
  });

  test('this container\'s own site is tagged THIS CONTAINER, at its saved address', () {
    final row = _for('forum').first;
    expect(row.tag, 'THIS CONTAINER');
    expect(row.destination, isA<ThisContainer>());
    expect(row.destination.url.toString(), 'https://forum.example.com');
  });

  test("a saved row opens that site's own saved address, not the typed text", () {
    final row = _for('mark').first;
    expect((row.destination as SavedSiteContainer).site.id, 'market');
    expect(row.destination.url.toString(), 'https://market.example.com');
  });

  test('at most five saved sites, most recently visited first', () {
    final shops = [
      for (var i = 0; i < 7; i++)
        Site(
          id: 's$i', workspaceId: 'w1', name: 'Shop $i', monogram: 'Sh',
          url: 'https://shop$i.example.com', profileId: 'p$i',
          lastVisitedAt: DateTime(2026, 9, 1 + i),
        ),
    ];
    final rows = _for('shop', saved: shops)
        .where((r) => r.kind == SuggestionKind.savedSite);
    expect(rows.map((r) => r.primary),
        ['Shop 6', 'Shop 5', 'Shop 4', 'Shop 3', 'Shop 2']);
  });

  test('a direct throwaway is tagged THROWAWAY alone; an http one is named', () {
    expect(_for('x.example.net', current: _market).first.tag, 'THROWAWAY');
    final http = _forum.copyWith(
        proxyMode: ProxyMode.http, proxyHost: '10.0.2.2', proxyPort: 8888);
    expect(_for('x.example.net', current: http).first.tag, 'THROWAWAY · HTTP');
  });

  test("a search whose engine is a saved site is tagged for that site's container", () {
    const duck = Site(
      id: 'ddg', workspaceId: 'w2', name: 'Duck', monogram: 'Dk',
      url: 'https://duckduckgo.com', profileId: 'p9',
    );
    expect(_for('market', saved: [_forum, _market, duck]).last.tag,
        'ITS OWN CONTAINER');
  });

  test('the chosen engine names the search row', () {
    expect(_for('x y', engine: SearchEngine.braveSearch).single.primary,
        'Search Brave Search for “x y”');
  });

  test('nothing typed suggests nothing', () {
    expect(_for('   '), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/domain/site_search_test.dart test/domain/address_suggestion_test.dart`
Expected: FAIL — `site_search.dart` and `address_suggestion.dart` do not exist.

- [ ] **Step 3: Write `site_search.dart`**

```dart
// lib/domain/site_search.dart
import 'models/site.dart';

/// Plan 7's search: [query], trimmed and case-insensitive, found in a site's
/// name or host. An empty query matches every site. Most recently visited
/// first, never-visited last. Shared by the search screen and the address
/// bar's suggestions so the two never disagree about what matches.
List<Site> sitesMatching(List<Site> sites, String query) {
  final q = query.trim().toLowerCase();
  return sites.where((site) {
    if (q.isEmpty) return true;
    return site.name.toLowerCase().contains(q) ||
        site.host.toLowerCase().contains(q);
  }).toList()
    ..sort((a, b) {
      final at = a.lastVisitedAt;
      final bt = b.lastVisitedAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
}
```

- [ ] **Step 4: Make `searchResults` use it**

In `lib/ui/features/search/view_models/search_view.dart`, add the import below the two existing ones:

```dart
import '../../../../domain/site_search.dart';
```

and replace the whole body of `searchResults` with:

```dart
  final workspacesById = {for (final w in workspaces) w.id: w};

  final entries = <SearchResultEntry>[];
  for (final site in sitesMatching(sites, query)) {
    final workspace = workspacesById[site.workspaceId];
    if (workspace == null) continue;
    entries.add(SearchResultEntry(
      siteId: site.id,
      workspaceId: site.workspaceId,
      name: site.name,
      monogram: site.monogram,
      host: site.host,
      live: openSiteIds.contains(site.id),
      workspaceName: workspace.name,
      markerIndex: workspace.markerIndex,
    ));
  }
  return entries;
```

- [ ] **Step 5: Write `address_suggestion.dart`**

```dart
// lib/domain/models/address_suggestion.dart
import '../site_search.dart';
import 'address_input.dart';
import 'destination.dart';
import 'search_engine.dart';
import 'site.dart';
import 'workspace.dart';

enum SuggestionKind { savedSite, address, search }

/// One row under the address field (spec §4.4, §6.2), already reduced to
/// strings. [tag] says where the row opens before it is tapped.
class AddressSuggestion {
  const AddressSuggestion({
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.tag,
    required this.destination,
    this.monogram,
  });

  final SuggestionKind kind;
  final String primary;

  /// Shown in mono under [primary].
  final String secondary;
  final String tag;
  final Destination destination;

  /// Set for a saved site only; the other rows draw an icon.
  final String? monogram;
}

const maxSavedSuggestions = 5;

/// Spec §7's destination tags. The route part follows the existing rule
/// that there is no DIRECT label.
String destinationTag(Destination destination) => switch (destination) {
      ThisContainer() => 'THIS CONTAINER',
      SavedSiteContainer() => 'ITS OWN CONTAINER',
      Throwaway(mode: ProxyMode.direct) => 'THROWAWAY',
      Throwaway(:final mode) => 'THROWAWAY · ${mode.name.toUpperCase()}',
    };

/// In order: up to [maxSavedSuggestions] saved sites matching [text] (each
/// opening at its own saved address), the address row when [text] parses as
/// an address, and the search row whenever [text] is not empty. Reads only
/// what it is given — the open vault's sites — and fetches nothing.
List<AddressSuggestion> suggestionsFor({
  required String text,
  required Site current,
  required List<Site> saved,
  required List<Workspace> workspaces,
  required SearchEngine engine,
}) {
  final input = parseAddressInput(text);
  if (input is AddressEmpty) return const [];
  final typed = text.trim();
  final workspaceNames = {for (final w in workspaces) w.id: w.name};
  final rows = <AddressSuggestion>[];

  for (final site in sitesMatching(saved, typed).take(maxSavedSuggestions)) {
    final url = Uri.tryParse(site.url);
    if (url == null) continue;
    final destination =
        site.id == current.id ? ThisContainer(url) : SavedSiteContainer(site, url);
    final workspace = workspaceNames[site.workspaceId];
    rows.add(AddressSuggestion(
      kind: SuggestionKind.savedSite,
      primary: site.name,
      secondary: workspace == null ? site.host : '${site.host} · $workspace',
      tag: destinationTag(destination),
      destination: destination,
      monogram: site.monogram,
    ));
  }

  if (input is AddressUrl) {
    final destination = destinationFor(input.url, current: current, saved: saved);
    rows.add(AddressSuggestion(
      kind: SuggestionKind.address,
      primary: typed,
      secondary: 'not saved',
      tag: destinationTag(destination),
      destination: destination,
    ));
  }

  final search =
      destinationFor(engine.resultsFor(typed), current: current, saved: saved);
  rows.add(AddressSuggestion(
    kind: SuggestionKind.search,
    primary: 'Search ${engine.label} for “$typed”',
    secondary: engine.host,
    tag: destinationTag(search),
    destination: search,
  ));
  return rows;
}
```

- [ ] **Step 6: Run the tests and the gate**

Run: `flutter test test/domain/site_search_test.dart test/domain/address_suggestion_test.dart test/ui/features/search/`
Expected: PASS — 11 new tests, and every existing search test unchanged.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 35.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/site_search.dart lib/domain/models/address_suggestion.dart lib/ui/features/search/view_models/search_view.dart test/domain/site_search_test.dart test/domain/address_suggestion_test.dart
git commit -m "feat: suggest vault-local destinations for typed addresses"
```

---

### Task 3: The search-engine setting in `2d`

**Files:**
- Modify: `lib/domain/repositories/repositories.dart` (`SettingsRepository`), `lib/data/repositories/settings_repository_sqlite.dart`
- Modify: `lib/ui/features/settings/view_models/providers.dart`
- Modify: `lib/ui/features/settings/views/settings_screen.dart`
- Create: `lib/ui/features/settings/views/search_engine_picker.dart`, `lib/ui/features/settings/views/settings_route.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart` (remove `_SettingsRoute` and `settingsDestination`)
- Test: `test/data/settings_repository_strings_test.dart`, `test/ui/features/settings/search_engine_picker_test.dart`, `test/ui/features/settings/search_engine_setting_test.dart`
- Modify tests: `test/ui/features/settings_test.dart`, `test/ui/features/dashboard/settings_destination_test.dart`

**Interfaces:**
- Consumes: Task 1's `SearchEngine`; `databaseProvider`; `BottomSheetSurface` (`lib/ui/core/widgets/sheet.dart`).
- Produces:
  - `SettingsRepository.getString(String key, {String? fallback}) → Future<String?>`, `setString(String key, String value) → Future<void>`
  - `final searchEngineProvider = FutureProvider<SearchEngine>(…)` (key `search_engine`)
  - `SettingsController.setSearchEngine(SearchEngine engine) → Future<void>`
  - `SettingsScreen` gains `required String searchEngineName`; `onTap('searchEngine')` for its row
  - `class SearchEnginePicker extends StatelessWidget { SearchEnginePicker({required SearchEngine current, required ValueChanged<SearchEngine> onPick}) }`
  - `class SettingsRoute extends ConsumerWidget { const SettingsRoute() }`; `Widget? settingsDestination(String key)` (moved, same behaviour)

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/settings_repository_strings_test.dart
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<SqliteSettingsRepository> repository() async => SqliteSettingsRepository(
      await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi));

  test('an unset string reads as the fallback', () async {
    final settings = await repository();
    expect(await settings.getString('search_engine'), isNull);
    expect(await settings.getString('search_engine', fallback: 'duckDuckGo'), 'duckDuckGo');
  });

  test('setString persists, and a second set replaces the first', () async {
    final settings = await repository();
    await settings.setString('search_engine', 'startpage');
    await settings.setString('search_engine', 'braveSearch');
    expect(await settings.getString('search_engine'), 'braveSearch');
  });

  test('string and bool settings live side by side', () async {
    final settings = await repository();
    await settings.setBool('biometrics_enabled', true);
    await settings.setString('search_engine', 'startpage');
    expect(await settings.getBool('biometrics_enabled'), isTrue);
    expect(await settings.getString('search_engine'), 'startpage');
  });
}
```

```dart
// test/ui/features/settings/search_engine_picker_test.dart
import 'package:container/domain/models/search_engine.dart';
import 'package:container/ui/features/settings/views/search_engine_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('lists the three engines under its title, the current one checked', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchEnginePicker(current: SearchEngine.startpage, onPick: (_) {}),
      ),
    ));

    expect(find.text('Search engine'), findsOneWidget);
    for (final name in ['DuckDuckGo', 'Startpage', 'Brave Search']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.byIcon(Icons.check), findsOneWidget);
    final startpageRow = find.ancestor(of: find.text('Startpage'), matching: find.byType(Row));
    expect(find.descendant(of: startpageRow.first, matching: find.byIcon(Icons.check)),
        findsOneWidget);
  });

  testWidgets('tapping an engine picks it', (tester) async {
    SearchEngine? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchEnginePicker(
          current: SearchEngine.duckDuckGo,
          onPick: (engine) => picked = engine,
        ),
      ),
    ));

    await tester.tap(find.text('Brave Search'));
    expect(picked, SearchEngine.braveSearch);
  });
}
```

```dart
// test/ui/features/settings/search_engine_setting_test.dart
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart' show databaseProvider;
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/settings/views/settings_route.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show biometricServiceProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../shell/session_controller_test.dart' show FakeBiometricService;

/// Lets the in-memory database's real IO finish, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('the setting reads DuckDuckGo until another engine is stored', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(database),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(searchEngineProvider.future), SearchEngine.duckDuckGo);

    await SqliteSettingsRepository(database).setString('search_engine', 'startpage');
    container.invalidate(searchEngineProvider);
    expect(await container.read(searchEngineProvider.future), SearchEngine.startpage);
  });

  testWidgets('picking an engine in 2d stores it in the open vault and shows it', (tester) async {
    final database = (await tester.runAsync(
        () => AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)))!;
    addTearDown(() => tester.runAsync(database.close));
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      ],
      child: const MaterialApp(home: SettingsRoute()),
    ));
    await _settle(tester);
    expect(find.text('DuckDuckGo'), findsOneWidget);

    await tester.tap(find.text('Search engine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brave Search'));
    await tester.pumpAndSettle();
    await _settle(tester);

    final stored = await tester.runAsync(
        () => SqliteSettingsRepository(database).getString('search_engine'));
    expect(stored, 'braveSearch');
    expect(find.text('Brave Search'), findsOneWidget);
  });
}
```

Add to `test/ui/features/settings_test.dart`, inside `main()` after the last test:

```dart
  testWidgets('the browsing section follows manage and names the engine', (tester) async {
    var tapped = '';
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        biometricsAvailable: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: true,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        searchEngineName: 'Startpage',
        onChanged: (_, __) {},
        onTap: (key) => tapped = key,
      ),
    ));

    final manage = tester.getTopLeft(find.text('MANAGE')).dy;
    final browsing = tester.getTopLeft(find.text('BROWSING')).dy;
    final vault = tester.getTopLeft(find.text('VAULT')).dy;
    expect(browsing, greaterThan(manage));
    expect(browsing, lessThan(vault));
    expect(find.text('Startpage'), findsOneWidget);

    await tester.tap(find.text('Search engine'));
    expect(tapped, 'searchEngine');
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data/settings_repository_strings_test.dart test/ui/features/settings/ test/ui/features/settings_test.dart`
Expected: FAIL — `getString`, `SearchEnginePicker`, `settings_route.dart`, `searchEngineProvider` and `searchEngineName` do not exist.

- [ ] **Step 3: Strings in the settings repository**

In `lib/domain/repositories/repositories.dart`, replace the `SettingsRepository` interface with:

```dart
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool fallback = false});
  Future<void> setBool(String key, bool value);

  /// `app_settings.value` is text already; this reads it as stored.
  Future<String?> getString(String key, {String? fallback});
  Future<void> setString(String key, String value);
}
```

In `lib/data/repositories/settings_repository_sqlite.dart`, add after `setBool`:

```dart
  @override
  Future<String?> getString(String key, {String? fallback}) async {
    final rows = await _database.db
        .query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return fallback;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setString(String key, String value) async {
    await _database.db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
```

- [ ] **Step 4: The provider and the controller method**

In `lib/ui/features/settings/view_models/providers.dart`, add the import:

```dart
import '../../../../domain/models/search_engine.dart';
```

add after `decoySiteCountProvider`:

```dart
/// Spec §6.7: the open vault's `search_engine` setting, stored as the enum
/// name. Per vault like every other setting; the row looks the same in both.
final searchEngineProvider = FutureProvider<SearchEngine>((ref) async {
  final stored = await ref.watch(settingsRepositoryProvider).getString('search_engine');
  return SearchEngine.fromStored(stored);
});
```

and add to `SettingsController`, after `setBiometricsEnabled`:

```dart
  Future<void> setSearchEngine(SearchEngine engine) async {
    await _ref.read(settingsRepositoryProvider).setString('search_engine', engine.name);
    _ref.invalidate(searchEngineProvider);
  }
```

- [ ] **Step 5: The `BROWSING` section**

In `lib/ui/features/settings/views/settings_screen.dart`:
1. Add `required this.searchEngineName,` to the constructor after `required this.onPanicLabel,`, and the field after `final String onPanicLabel;`:

```dart
  /// The current engine's name (spec §6.7); empty while it loads.
  final String searchEngineName;
```

2. Replace

```dart
                  SettingRow(
                      title: 'Scripts and filters', onTap: () => onTap('scripts')),
                  if (decoyEnabled) ...[
```

with

```dart
                  SettingRow(
                      title: 'Scripts and filters', onTap: () => onTap('scripts')),
                  const SizedBox(height: 24),
                  Text('BROWSING', style: T.sectionLabel),
                  SettingRow(
                    title: 'Search engine',
                    value: searchEngineName,
                    onTap: () => onTap('searchEngine'),
                  ),
                  if (decoyEnabled) ...[
```

3. In `test/ui/features/settings_test.dart`, add `searchEngineName: 'DuckDuckGo',` after `onPanicLabel: 'Wipe + lock',` in both existing `SettingsScreen(` constructors (the `pump` helper and the re-sync test).

- [ ] **Step 6: The picker**

```dart
// lib/ui/features/settings/views/search_engine_picker.dart
import 'package:flutter/material.dart';

import '../../../../domain/models/search_engine.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/sheet.dart';

/// Spec §6.7: the sheet the `Search engine` row opens. The current engine is
/// checked the way the workspace menu checks its selected row.
class SearchEnginePicker extends StatelessWidget {
  const SearchEnginePicker({super.key, required this.current, required this.onPick});

  final SearchEngine current;
  final ValueChanged<SearchEngine> onPick;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Text('Search engine', style: T.sheetTitle),
        ),
        for (final engine in SearchEngine.values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(engine),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: C.line05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(engine.label, style: ui(size: 14.5, color: C.textPrimary)),
                  ),
                  if (engine == current) const Icon(Icons.check, size: 15, color: C.jade),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 7: `SettingsRoute`, moved out of the dashboard**

```dart
// lib/ui/features/settings/views/settings_route.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/search_engine.dart';
import '../../scripts/views/scripts_route.dart';
import '../../workspaces/views/workspaces_route.dart';
import '../view_models/providers.dart';
import 'decoy_resync_route.dart';
import 'search_engine_picker.dart';
import 'settings_screen.dart';

/// The screen a Settings row opens, by the key `SettingsScreen.onTap`
/// reports. Null for a row with nothing built behind it yet, and for
/// `searchEngine`, which opens a sheet rather than a screen.
Widget? settingsDestination(String key) => switch (key) {
      'resyncDecoy' => const DecoyResyncRoute(),
      'workspaces' => const WorkspacesRoute(),
      'scripts' => const ScriptsRoute(),
      _ => null,
    };

/// Spec `2d` against the open vault. Pushed from the dashboard's `⋯` and
/// from a container's ☰ menu.
class SettingsRoute extends ConsumerWidget {
  const SettingsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometrics = ref.watch(biometricsEnabledProvider);
    final biometricsAvailable = ref.watch(biometricsAvailableProvider);
    final decoyEnabled = ref.watch(decoyEnabledProvider);
    final decoySiteCount = ref.watch(decoySiteCountProvider);
    final searchEngine = ref.watch(searchEngineProvider).valueOrNull;
    return SettingsScreen(
      biometrics: biometrics.value ?? false,
      biometricsAvailable: biometricsAvailable.value ?? false,
      autoLockLabel: 'After 1 min',
      decoyEnabled: decoyEnabled.value ?? false,
      decoySiteCount: decoySiteCount.value ?? 0,
      hideFromSwitcher: true,
      panicOnFlip: false,
      onPanicLabel: 'Wipe + lock',
      searchEngineName: searchEngine?.label ?? '',
      onChanged: (key, value) {
        if (key == 'biometrics') {
          ref.read(settingsControllerProvider).setBiometricsEnabled(value);
        }
      },
      onTap: (key) {
        if (key == 'searchEngine') {
          _pickSearchEngine(context, ref, searchEngine ?? SearchEngine.duckDuckGo);
          return;
        }
        final destination = settingsDestination(key);
        if (destination != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
        }
      },
    );
  }

  void _pickSearchEngine(BuildContext context, WidgetRef ref, SearchEngine current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SearchEnginePicker(
        current: current,
        onPick: (engine) {
          Navigator.pop(sheetContext);
          ref.read(settingsControllerProvider).setSearchEngine(engine);
        },
      ),
    );
  }
}
```

- [ ] **Step 8: The dashboard pushes it**

In `lib/ui/features/dashboard/views/dashboard_screen.dart`:
1. Delete `settingsDestination` and the whole `_SettingsRoute` class (from the `/// The screen a Settings row opens` comment to the end of the file).
2. Replace `const _SettingsRoute()` in `onOverflow` with `const SettingsRoute()`.
3. Delete these now-unused imports: `'../../scripts/views/scripts_route.dart'`, the `'../../settings/view_models/providers.dart' show …` import (all five names), `'../../settings/views/decoy_resync_route.dart'`, `'../../settings/views/settings_screen.dart'`, `'../../workspaces/views/workspaces_route.dart'`; and add:

```dart
import '../../settings/views/settings_route.dart';
```

In `test/ui/features/dashboard/settings_destination_test.dart`, replace the first import with:

```dart
import 'package:container/ui/features/settings/views/settings_route.dart';
```

- [ ] **Step 9: Run the tests and the gate**

Run: `flutter test test/data/settings_repository_strings_test.dart test/ui/features/settings/ test/ui/features/settings_test.dart test/ui/features/dashboard/`
Expected: PASS — 8 new tests; `settings_destination_test.dart`'s two still pass.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 43.

- [ ] **Step 10: Commit**

```bash
git add lib/domain/repositories/repositories.dart lib/data/repositories/settings_repository_sqlite.dart lib/ui/features/settings lib/ui/features/dashboard/views/dashboard_screen.dart test/data/settings_repository_strings_test.dart test/ui/features/settings test/ui/features/settings_test.dart test/ui/features/dashboard/settings_destination_test.dart
git commit -m "feat: choose the search engine in settings"
```

---

### Task 4: Line icons and the icon button

**Files:**
- Create: `lib/ui/core/icons.dart`, `lib/ui/core/widgets/icon_tap.dart`
- Test: `test/ui/core/icons_test.dart`

**Interfaces:**
- Consumes: `C` tokens.
- Produces:
  - `enum AppGlyph { back, forward, reload, stop, shield, panic, menu, find, reader, link, search, globe, chevronUp, chevronDown, close }`
  - `class AppIcon extends StatelessWidget { const AppIcon(AppGlyph glyph, {double size = 20, Color color = C.icon}) }`
  - `class AppIconPainter extends CustomPainter { const AppIconPainter(AppGlyph glyph, Color color) }`
  - `class IconTap extends StatelessWidget { const IconTap({required AppGlyph glyph, required String? label, required VoidCallback? onTap, double size = 40, double iconSize = 20, Color color = C.icon, Color? background, double? radius}) }` — a null `onTap` draws the icon in `C.textDisabled` and ignores taps; a null `radius` is a circle; a non-null `label` wraps it in `Semantics(label:, button: true)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/core/icons_test.dart
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test("the set is spec §6.6's fifteen glyphs", () {
    expect(AppGlyph.values.map((g) => g.name), [
      'back', 'forward', 'reload', 'stop', 'shield', 'panic', 'menu', 'find',
      'reader', 'link', 'search', 'globe', 'chevronUp', 'chevronDown', 'close',
    ]);
  });

  testWidgets('every glyph paints, at the size it is given', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Wrap(children: [
          for (final glyph in AppGlyph.values) AppIcon(glyph, size: 24),
          const AppIcon(AppGlyph.back, size: 13, color: C.danger),
        ]),
      ),
    ));

    expect(tester.takeException(), isNull);
    for (final glyph in AppGlyph.values) {
      final icon = find.byWidgetPredicate(
          (w) => w is AppIcon && w.glyph == glyph && w.size == 24);
      expect(tester.getSize(icon), const Size(24, 24), reason: glyph.name);
    }
    expect(tester.getSize(find.byWidgetPredicate((w) => w is AppIcon && w.size == 13)),
        const Size(13, 13));
  });

  test('the painter repaints only for a new glyph or colour', () {
    const painter = AppIconPainter(AppGlyph.back, C.icon);
    expect(painter.shouldRepaint(const AppIconPainter(AppGlyph.back, C.icon)), isFalse);
    expect(painter.shouldRepaint(const AppIconPainter(AppGlyph.forward, C.icon)), isTrue);
    expect(painter.shouldRepaint(const AppIconPainter(AppGlyph.back, C.textDisabled)), isTrue);
  });

  testWidgets('an icon button with no tap is dimmed and inert', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          const IconTap(glyph: AppGlyph.back, label: 'Back', onTap: null),
          IconTap(glyph: AppGlyph.forward, label: 'Forward', onTap: () => taps++),
        ]),
      ),
    ));

    AppIcon icon(AppGlyph glyph) => tester.widget<AppIcon>(
        find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph));
    expect(icon(AppGlyph.back).color, C.textDisabled);
    expect(icon(AppGlyph.forward).color, C.icon);

    await tester.tap(find.byWidgetPredicate((w) => w is IconTap && w.label == 'Back'),
        warnIfMissed: false);
    await tester.tap(find.byWidgetPredicate((w) => w is IconTap && w.label == 'Forward'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(IconTap).first), const Size(40, 40));
  });

  testWidgets('an icon button names itself for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: () {}),
      ),
    ));

    expect(find.bySemanticsLabel('Menu'), findsOneWidget);
    semantics.dispose();
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ui/core/icons_test.dart`
Expected: FAIL — `icons.dart` and `icon_tap.dart` do not exist.

- [ ] **Step 3: Write `icons.dart`**

```dart
// lib/ui/core/icons.dart
import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Spec §6.6's set, drawn in-repo: no icon font, no dependency.
enum AppGlyph {
  back,
  forward,
  reload,
  stop,
  shield,
  panic,
  menu,
  find,
  reader,
  link,
  search,
  globe,
  chevronUp,
  chevronDown,
  close,
}

/// One line icon at the size the caller passes. Replaces `2b`'s Unicode
/// glyphs on the container screen; other screens keep theirs until project 4.
class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {super.key, this.size = 20, this.color = C.icon});

  final AppGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: AppIconPainter(glyph, color));
}

/// Draws [glyph] with 2-unit round strokes on a 24-unit grid, scaled to the
/// canvas. The paths follow the brainstorm mockups
/// (`.superpowers/brainstorm/…/typing-and-menu.html`).
class AppIconPainter extends CustomPainter {
  const AppIconPainter(this.glyph, this.color);

  final AppGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      case AppGlyph.back:
        _lines(canvas, stroke, const [Offset(15, 18), Offset(9, 12), Offset(15, 6)]);
      case AppGlyph.forward:
        _lines(canvas, stroke, const [Offset(9, 18), Offset(15, 12), Offset(9, 6)]);
      case AppGlyph.chevronUp:
        _lines(canvas, stroke, const [Offset(6, 15), Offset(12, 9), Offset(18, 15)]);
      case AppGlyph.chevronDown:
        _lines(canvas, stroke, const [Offset(6, 9), Offset(12, 15), Offset(18, 9)]);
      case AppGlyph.close:
        _lines(canvas, stroke, const [Offset(6, 6), Offset(18, 18)]);
        _lines(canvas, stroke, const [Offset(18, 6), Offset(6, 18)]);
      case AppGlyph.stop:
        _lines(canvas, stroke, const [Offset(7, 7), Offset(17, 17)]);
        _lines(canvas, stroke, const [Offset(17, 7), Offset(7, 17)]);
      case AppGlyph.reload:
        canvas.drawPath(
          Path()
            ..moveTo(20, 12)
            ..arcToPoint(const Offset(17.6, 6.3),
                radius: const Radius.circular(8), largeArc: true)
            ..lineTo(20, 8.5),
          stroke,
        );
        _lines(canvas, stroke, const [Offset(20, 3.5), Offset(20, 8.5), Offset(15, 8.5)]);
      case AppGlyph.shield:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(19, 6)
            ..lineTo(19, 12)
            ..cubicTo(19, 16.5, 16, 19.5, 12, 21)
            ..cubicTo(8, 19.5, 5, 16.5, 5, 12)
            ..lineTo(5, 6)
            ..close(),
          stroke,
        );
      case AppGlyph.panic:
        canvas.drawCircle(const Offset(12, 12), 8, stroke);
        canvas.drawCircle(const Offset(12, 12), 3.2, Paint()..color = color);
      case AppGlyph.menu:
        _lines(canvas, stroke, const [Offset(4, 7), Offset(20, 7)]);
        _lines(canvas, stroke, const [Offset(4, 12), Offset(20, 12)]);
        _lines(canvas, stroke, const [Offset(4, 17), Offset(20, 17)]);
      case AppGlyph.find:
        canvas.drawCircle(const Offset(11, 11), 6.5, stroke);
        _lines(canvas, stroke, const [Offset(20, 20), Offset(15.8, 15.8)]);
        _lines(canvas, stroke, const [Offset(8.5, 11), Offset(13.5, 11)]);
      case AppGlyph.search:
        canvas.drawCircle(const Offset(11, 11), 6.5, stroke);
        _lines(canvas, stroke, const [Offset(20, 20), Offset(15.8, 15.8)]);
      case AppGlyph.reader:
        _lines(canvas, stroke, const [Offset(5, 5), Offset(19, 5)]);
        _lines(canvas, stroke, const [Offset(5, 10), Offset(19, 10)]);
        _lines(canvas, stroke, const [Offset(5, 15), Offset(14, 15)]);
        _lines(canvas, stroke, const [Offset(5, 20), Offset(11, 20)]);
      case AppGlyph.link:
        canvas.drawPath(
          Path()
            ..moveTo(10, 14)
            ..arcToPoint(const Offset(15.7, 14),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(18.7, 11)
            ..arcToPoint(const Offset(13, 5.3),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(12, 6.3),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(14, 10)
            ..arcToPoint(const Offset(8.3, 10),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(5.3, 13)
            ..arcToPoint(const Offset(11, 18.7),
                radius: const Radius.circular(4), clockwise: false)
            ..lineTo(12, 17.7),
          stroke,
        );
      case AppGlyph.globe:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        _lines(canvas, stroke, const [Offset(3.5, 12), Offset(20.5, 12)]);
        canvas.drawPath(
          Path()
            ..moveTo(12, 3.5)
            ..cubicTo(14.5, 6.1, 15.5, 8.9, 15.5, 12)
            ..cubicTo(15.5, 15.1, 14.5, 17.9, 12, 20.5)
            ..cubicTo(9.5, 17.9, 8.5, 15.1, 8.5, 12)
            ..cubicTo(8.5, 8.9, 9.5, 6.1, 12, 3.5)
            ..close(),
          stroke,
        );
    }
    canvas.restore();
  }

  static void _lines(Canvas canvas, Paint paint, List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(AppIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
```

- [ ] **Step 4: Write `icon_tap.dart`**

```dart
// lib/ui/core/widgets/icon_tap.dart
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';

/// A tap target drawn as one [AppIcon] — every button in the container's
/// chrome. [label] names it for screen readers, from spec §7's list; it is
/// null only where the spec gives none. A null [onTap] dims the icon and
/// makes it inert: back and forward with no history that way (§3.3).
class IconTap extends StatelessWidget {
  const IconTap({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.size = 40,
    this.iconSize = 20,
    this.color = C.icon,
    this.background,
    this.radius,
  });

  final AppGlyph glyph;
  final String? label;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color color;
  final Color? background;

  /// Corner radius; null draws a circle, like `2b`'s 40px round targets.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final corner = radius;
    final target = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: corner == null
            ? BoxDecoration(color: background, shape: BoxShape.circle)
            : BoxDecoration(color: background, borderRadius: BorderRadius.circular(corner)),
        child: AppIcon(glyph, size: iconSize, color: onTap == null ? C.textDisabled : color),
      ),
    );
    final name = label;
    if (name == null) return target;
    return Semantics(label: name, button: true, enabled: onTap != null, child: target);
  }
}
```

- [ ] **Step 5: Run the tests and the gate**

Run: `flutter test test/ui/core/icons_test.dart` — Expected: PASS, 5 tests.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 48.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/core/icons.dart lib/ui/core/widgets/icon_tap.dart test/ui/core/icons_test.dart
git commit -m "feat: draw the container's line icons in-repo"
```

---

### Task 5: The engine's navigation, find and throwaway API (Dart)

**Files:**
- Create: `lib/domain/models/navigation_state.dart`, `lib/domain/models/find_result.dart`, `lib/ui/features/container/view_models/subscribe_then_snapshot.dart`
- Modify (whole file): `lib/data/services/container_engine.dart`, `lib/data/services/container_engine_channel.dart`, `lib/data/services/fake_container_engine.dart`
- Modify: `lib/ui/features/container/view_models/providers.dart`
- Test: `test/data/container_engine_channel_test.dart` (5 added), `test/ui/features/navigation_for_site_provider_test.dart` (new)
- Modify test: `test/ui/features/container_route_test.dart` (`_GatedEngine.open`'s signature only)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `class NavigationState { const NavigationState({required String siteId, required String url, String title = '', bool canGoBack = false, bool canGoForward = false, bool loading = false, int progress = 0}); String get host; }`
  - `class FindResult { const FindResult({required String siteId, required int activeMatch, required int matchCount}); }` — `activeMatch` is zero-based, as WebView reports it.
  - `ContainerEngine`: `open(Site, {EngineExtras extras, bool throwaway = false})`, `Stream<NavigationState> navigation()`, `Future<NavigationState?> navigationState(String siteId)`, `Stream<FindResult> findResults()`, `goBack`, `goForward`, `stop`, `loadUrl(String siteId, String url)`, `find(String siteId, String query)`, `findNext(String siteId, {required bool forward})`, `clearFind`, `keep` (each `Future<void>`, each taking `siteId` first).
  - Channel method names: `goBack`, `goForward`, `stop`, `loadUrl` (`url`), `find` (`query`), `findNext` (`forward`), `clearFind`, `navigationState`, `keep`; `open` gains `throwaway`. Events: `type: "navigation"` (`siteId, url, title, canGoBack, canGoForward, loading, progress`) and `type: "find_result"` (`siteId, activeMatch, matchCount`).
  - `NavigationState navigationFromEvent(Map)`, `FindResult findResultFromEvent(Map)` (exposed for tests).
  - `FakeContainerEngine` records `openedSites` (`Map<String, Site>`), `openedAsThrowaway` (`Set<String>`), `wentBack`, `wentForward`, `stopped`, `clearedFind`, `kept` (`List<String>`), `loaded` (`List<({String siteId, String url})>`), `findQueries` (`List<({String siteId, String query})>`), `findSteps` (`List<({String siteId, bool forward})>`); test helpers `emitNavigation(NavigationState)` (also sets the snapshot), `seedNavigation(NavigationState)` (snapshot only), `emitFindResult(FindResult)`.
  - `Stream<T> subscribeThenSnapshot<T>(Ref ref, {required Stream<T> events, required Future<T> Function() snapshot})`
  - `final navigationForSiteProvider = StreamProvider.autoDispose.family<NavigationState?, String>(…)`; `sessionForSiteProvider` becomes `StreamProvider.autoDispose.family` too (only `ContainerRoute` watches either)

- [ ] **Step 1: Write the failing tests**

Add to `test/data/container_engine_channel_test.dart` two imports:

```dart
import 'package:container/domain/models/site.dart';
import 'package:flutter/services.dart';
```

make `TestWidgetsFlutterBinding.ensureInitialized();` the first statement of `main()`, and add at the end of `main()`:

```dart
  test('a navigation event decodes every field the chrome reads', () {
    final state = navigationFromEvent(<Object?, Object?>{
      'type': 'navigation', 'siteId': 's1', 'url': 'https://forum.example.com/t/9',
      'title': 'Thread', 'canGoBack': true, 'canGoForward': false,
      'loading': true, 'progress': 40,
    });
    expect(state.siteId, 's1');
    expect(state.url, 'https://forum.example.com/t/9');
    expect(state.host, 'forum.example.com');
    expect(state.title, 'Thread');
    expect(state.canGoBack, isTrue);
    expect(state.canGoForward, isFalse);
    expect(state.loading, isTrue);
    expect(state.progress, 40);
  });

  test('a find_result event decodes its counts', () {
    final result = findResultFromEvent(<Object?, Object?>{
      'type': 'find_result', 'siteId': 's1', 'activeMatch': 2, 'matchCount': 7,
    });
    expect((result.siteId, result.activeMatch, result.matchCount), ('s1', 2, 7));
  });

  group('over the channels', () {
    const methods = MethodChannel('com.mono.container/engine');
    const events = EventChannel('com.mono.container/sessions');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    tearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(events, null);
    });

    // Every event type the listener did not know fell through to the
    // sessions decoder, which throws on a map with no `sessions` key.
    test('navigation and find events reach their own streams', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, sink) {
        sink.success(<String, Object?>{
          'type': 'navigation', 'siteId': 's1', 'url': 'https://a.example/x',
          'title': '', 'canGoBack': true, 'canGoForward': false,
          'loading': false, 'progress': 100,
        });
        sink.success(<String, Object?>{
          'type': 'find_result', 'siteId': 's1', 'activeMatch': 0, 'matchCount': 3,
        });
      }));
      final engine = ChannelContainerEngine();
      final navigation = engine.navigation().first;
      final find = engine.findResults().first;

      expect((await navigation).canGoBack, isTrue);
      expect((await find).matchCount, 3);
    });

    test('the page controls reach the platform under the names Kotlin handles', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return null;
      });
      final engine = ChannelContainerEngine();

      await engine.goBack('s1');
      await engine.goForward('s1');
      await engine.stop('s1');
      await engine.loadUrl('s1', 'https://a.example/x');
      await engine.find('s1', 'fox');
      await engine.findNext('s1', forward: false);
      await engine.clearFind('s1');
      await engine.keep('s1');
      expect(await engine.navigationState('s1'), isNull);

      expect(calls.map((c) => c.method), [
        'goBack', 'goForward', 'stop', 'loadUrl', 'find', 'findNext',
        'clearFind', 'keep', 'navigationState',
      ]);
      expect(calls[3].arguments, {'siteId': 's1', 'url': 'https://a.example/x'});
      expect(calls[4].arguments, {'siteId': 's1', 'query': 'fox'});
      expect(calls[5].arguments, {'siteId': 's1', 'forward': false});
    });

    test('open says whether the site is a throwaway', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return <String, Object?>{
          'siteId': 't1', 'phase': 'opening', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
        };
      });
      const site = Site(
        id: 't1', workspaceId: 'w', name: 'news.example.org', monogram: 'Nw',
        url: 'https://news.example.org', profileId: 'p',
      );

      await ChannelContainerEngine().open(site, throwaway: true);
      await ChannelContainerEngine().open(site);

      expect(calls.map((c) => (c.arguments as Map<Object?, Object?>)['throwaway']),
          [true, false]);
    });
  });
```

```dart
// test/ui/features/navigation_for_site_provider_test.dart
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/navigation_state.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Emits a page change *while* the snapshot is being read, and hands back
/// the snapshot as it stood before — the same race `sessionForSiteProvider`
/// lost on a device, now for navigation.
class _EventLandsDuringSnapshot extends FakeContainerEngine {
  @override
  Future<NavigationState?> navigationState(String siteId) async {
    final stale = await super.navigationState(siteId);
    emitNavigation(const NavigationState(
        siteId: 's1', url: 'https://forum.example.com/new', loading: true));
    return stale;
  }
}

List<NavigationState?> _watch(ProviderContainer container) {
  final seen = <NavigationState?>[];
  container.listen(
    navigationForSiteProvider('s1'),
    (_, next) => next.whenData(seen.add),
    fireImmediately: true,
  );
  return seen;
}

void main() {
  test('a page change during the snapshot read is not lost', () async {
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(_EventLandsDuringSnapshot()),
    ]);
    addTearDown(container.dispose);

    final seen = _watch(container);
    await pumpEventQueue();

    expect(seen.last?.url, 'https://forum.example.com/new');
  });

  test('the snapshot stands in until the first event, which replaces it', () async {
    final engine = FakeContainerEngine()
      ..seedNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/a'));
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(container.dispose);

    final seen = _watch(container);
    await pumpEventQueue();
    expect(seen.last?.url, 'https://forum.example.com/a');

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/b'));
    await pumpEventQueue();
    expect(seen.last?.url, 'https://forum.example.com/b');
  });

  test("another site's page changes are not this site's", () async {
    final engine = FakeContainerEngine();
    final container = ProviderContainer(overrides: [
      containerEngineProvider.overrideWithValue(engine),
    ]);
    addTearDown(container.dispose);

    final seen = _watch(container);
    await pumpEventQueue();
    engine.emitNavigation(const NavigationState(siteId: 's2', url: 'https://elsewhere.example.com'));
    await pumpEventQueue();

    expect(seen, [null]);
  });
}
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/data/container_engine_channel_test.dart test/ui/features/navigation_for_site_provider_test.dart`
Expected: FAIL — `navigationFromEvent`, `NavigationState`, `navigationForSiteProvider` and the new engine methods do not exist.

- [ ] **Step 3: The two models**

```dart
// lib/domain/models/navigation_state.dart

/// What a container's page is doing, as the chrome shows it (spec §3.1–3.3).
/// Runtime only, like every session value.
class NavigationState {
  const NavigationState({
    required this.siteId,
    required this.url,
    this.title = '',
    this.canGoBack = false,
    this.canGoForward = false,
    this.loading = false,
    this.progress = 0,
  });

  final String siteId;
  final String url;
  final String title;
  final bool canGoBack;
  final bool canGoForward;
  final bool loading;

  /// 0–100; the load line's fill while [loading].
  final int progress;

  /// The pill's text. Empty when [url] has none (`about:blank`); the chrome
  /// then falls back to the saved site's host.
  String get host => Uri.tryParse(url)?.host ?? '';
}
```

```dart
// lib/domain/models/find_result.dart

/// The page's finished count for a find in page (spec §6.5).
class FindResult {
  const FindResult({
    required this.siteId,
    required this.activeMatch,
    required this.matchCount,
  });

  final String siteId;

  /// Zero-based, as WebView reports it; the find bar shows it plus one.
  final int activeMatch;
  final int matchCount;
}
```

- [ ] **Step 4: The engine interface**

Replace `lib/data/services/container_engine.dart` with:

```dart
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/engine_extras.dart';
import '../../domain/models/find_result.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
import '../../domain/models/navigation_state.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/site.dart';

/// Everything Dart is allowed to know about the platform. No WebView type
/// crosses this line.
abstract interface class ContainerEngine {
  /// False when the device cannot isolate. The app refuses to open containers
  /// rather than sharing a profile — see Global Constraints.
  Future<bool> isolationAvailable();

  /// Creates the profile if absent and begins loading. Emits progress on
  /// [sessions]. Completes when the page is live or the route was refused.
  /// [extras] is the open vault's filter rules and scripts for this site.
  /// [throwaway] marks an in-memory site (browser-chrome spec §5.4): the
  /// platform journals its profile before creating it, so a crash cannot
  /// leak it, and always wipes it on exit.
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
  });

  /// Destroys the profile's cookies, cache and storage. Called for
  /// `CookiePolicy.wipeOnExit` and by "Close all and wipe" in `2c`.
  Future<void> wipe(String profileId);

  /// Destroys every profile the platform holds, including ones this process
  /// cannot name.
  ///
  /// Panic calls this, and it exists because [wipe] cannot do that job. A
  /// profile id lives in a `Site` row inside an encrypted vault, so the ids
  /// belonging to the vault that is *not* open are unreadable to this
  /// process — before panic starts, not merely after it finishes. A loop over
  /// [wipe] would clear the open vault's containers and silently leave the
  /// other vault's storage sitting on disk. Asking the platform which
  /// profiles exist is the only enumeration that can see both. See Task 9.
  Future<void> wipeAll();

  Future<void> close(String siteId);

  /// Every live session. Spec `2c`'s drawer renders exactly this.
  Stream<List<ContainerSession>> sessions();

  /// The same list [sessions] emits, read once.
  ///
  /// [sessions] is a broadcast stream that fires only on change, so awaiting
  /// its `.first` on a cold app blocks forever instead of yielding an empty
  /// list. Anything needing a snapshot rather than a subscription — panic
  /// counting what it is about to destroy, for one — uses this.
  Future<List<ContainerSession>> liveSessions();

  Future<void> reload(String siteId);

  /// Hardware asks the platform is holding, waiting on the user's decision.
  /// Filtered to the foreground site by whoever listens — see Task 4.
  Stream<PendingPermissionRequest> permissionRequests();

  /// Tells the platform what the user picked for [requestId]. A decision for
  /// a request that already timed out or whose site closed is a silent
  /// no-op on the platform side, not an error here.
  Future<void> resolvePermission(String requestId, PermissionDecision decision);

  Stream<HeldDownloadEvent> downloads();
  Future<void> resolveDownload(String requestId, DownloadDecision decision);
  Stream<DownloadResult> downloadResults();

  /// A *live* session's tunnel failing mid-browse. Distinct from
  /// [SessionPhase.refused], which only ever happens before a session goes
  /// live — see Plan 6's design spec §3.
  Stream<TunnelDroppedEvent> tunnelDropped();

  /// Runs the reader-mode heuristic against the page currently loaded for
  /// [siteId]. Returns `null` when extraction finds nothing article-shaped.
  Future<ReaderArticle?> extractArticle(String siteId);

  /// Every page change in every open container (browser-chrome spec §3.1).
  /// Broadcast with no replay: a change made before anyone listened is only
  /// in [navigationState].
  Stream<NavigationState> navigation();

  /// The last [navigation] event for [siteId], or null before its first.
  Future<NavigationState?> navigationState(String siteId);

  /// The finished count of each find in page (spec §6.5).
  Stream<FindResult> findResults();

  // The in-page controls below are each a silent no-op on a closed or
  // unknown session, like [reload].

  Future<void> goBack(String siteId);
  Future<void> goForward(String siteId);
  Future<void> stop(String siteId);

  /// Loads [url] in [siteId]'s own container, on its own route. The platform
  /// refuses every scheme but `http` and `https`.
  Future<void> loadUrl(String siteId, String url);

  /// Highlights [query] in the page. An empty query is [clearFind]'s job.
  Future<void> find(String siteId, String query);
  Future<void> findNext(String siteId, {required bool forward});
  Future<void> clearFind(String siteId);

  /// A throwaway saved as a site (spec §5.3–5.4): its profile stops being
  /// wiped on exit and leaves the crash journal, so the login just saved
  /// survives closing the page.
  Future<void> keep(String siteId);
}
```

- [ ] **Step 5: The channel implementation**

Replace `lib/data/services/container_engine_channel.dart` with:

```dart
import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/engine_extras.dart';
import '../../domain/models/find_result.dart';
import '../../domain/models/held_download.dart';
import '../../domain/models/navigation_state.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/route_decision.dart';
import '../../domain/models/site.dart';
import 'container_engine.dart';

const _method = MethodChannel('com.mono.container/engine');
const _events = EventChannel('com.mono.container/sessions');

SessionPhase _phase(String name) => switch (name) {
      'opening' => SessionPhase.opening,
      'background' => SessionPhase.background,
      'refused' => SessionPhase.refused,
      _ => SessionPhase.live,
    };

RouteFailure? _failure(String? name) => switch (name) {
      'proxyUnreachable' => RouteFailure.proxyUnreachable,
      'proxyRefused' => RouteFailure.proxyRefused,
      'upstreamTimeout' => RouteFailure.upstreamTimeout,
      'tlsFailure' => RouteFailure.tlsFailure,
      'misconfigured' => RouteFailure.misconfigured,
      _ => null,
    };

BlockedCategory? _category(String name) => switch (name) {
      'trackers' => BlockedCategory.trackers,
      'ads' => BlockedCategory.ads,
      'fingerprinting' => BlockedCategory.fingerprinting,
      'permissionAsks' => BlockedCategory.permissionAsks,
      _ => null,
    };

PermissionKind _kind(String name) => switch (name) {
      'microphone' => PermissionKind.microphone,
      'location' => PermissionKind.location,
      'clipboard' => PermissionKind.clipboard,
      _ => PermissionKind.camera,
};

DownloadOutcome _downloadOutcome(String name) => switch (name) {
      'saved' => DownloadOutcome.saved,
      'kept' => DownloadOutcome.kept,
      _ => DownloadOutcome.failed,
    };

Map<BlockedCategory, int> _categoryCountsFrom(Object? raw) {
  final map = (raw as Map<Object?, Object?>?) ?? const {};
  final result = <BlockedCategory, int>{};
  for (final entry in map.entries) {
    final category = _category(entry.key! as String);
    if (category != null) result[category] = entry.value as int;
  }
  return result;
}

ContainerSession _sessionFrom(Map<Object?, Object?> map) => ContainerSession(
      siteId: map['siteId']! as String,
      phase: _phase(map['phase']! as String),
      lastActiveAt: map['lastActiveAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt']! as int),
      blockedCount: (map['blockedCount'] as int?) ?? 0,
      categoryCounts: _categoryCountsFrom(map['categoryCounts']),
      failure: _failure(map['failure'] as String?),
    );

/// Exposed for testing — decodes a `type: "sessions"` event's payload.
List<ContainerSession> sessionsFromEvent(Map<Object?, Object?> event) =>
    (event['sessions']! as List<Object?>)
        .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
        .toList();

/// Exposed for testing — decodes a `type: "permission_request"` event.
PendingPermissionRequest permissionRequestFromEvent(Map<Object?, Object?> event) =>
    PendingPermissionRequest(
      siteId: event['siteId']! as String,
      host: event['host']! as String,
      kind: _kind(event['kind']! as String),
      requestId: event['requestId']! as String,
    );

/// Exposed for testing — decodes a `type: "download"` event.
HeldDownloadEvent downloadFromEvent(Map<Object?, Object?> event) => HeldDownloadEvent(
      siteId: event['siteId']! as String,
      requestId: event['requestId']! as String,
      download: HeldDownload(
        fileName: event['fileName']! as String,
        sizeBytes: event['sizeBytes'] as int?,
        sourceHost: event['sourceHost']! as String,
        kindLabel: event['kindLabel']! as String,
      ),
    );

DownloadResult downloadResultFromEvent(Map<Object?, Object?> event) => DownloadResult(
      requestId: event['requestId']! as String,
      outcome: _downloadOutcome(event['outcome']! as String),
      reason: _failure(event['reason'] as String?),
    );

/// Exposed for testing — decodes a `type: "tunnel_dropped"` event.
TunnelDroppedEvent tunnelDroppedFromEvent(Map<Object?, Object?> event) => TunnelDroppedEvent(
      siteId: event['siteId']! as String,
      host: event['host']! as String,
      droppedAt: DateTime.fromMillisecondsSinceEpoch(event['droppedAtMs']! as int),
    );

/// Exposed for testing — decodes a `type: "navigation"` event, and the map
/// `navigationState` returns, which is the same event.
NavigationState navigationFromEvent(Map<Object?, Object?> event) => NavigationState(
      siteId: event['siteId']! as String,
      url: event['url']! as String,
      title: (event['title'] as String?) ?? '',
      canGoBack: (event['canGoBack'] as bool?) ?? false,
      canGoForward: (event['canGoForward'] as bool?) ?? false,
      loading: (event['loading'] as bool?) ?? false,
      progress: (event['progress'] as int?) ?? 0,
    );

/// Exposed for testing — decodes a `type: "find_result"` event.
FindResult findResultFromEvent(Map<Object?, Object?> event) => FindResult(
      siteId: event['siteId']! as String,
      activeMatch: event['activeMatch']! as int,
      matchCount: event['matchCount']! as int,
    );

class ChannelContainerEngine implements ContainerEngine {
  ChannelContainerEngine() {
    _events.receiveBroadcastStream().listen((event) {
      final map = event as Map<Object?, Object?>;
      switch (map['type']) {
        case 'permission_request':
          _permissionController.add(permissionRequestFromEvent(map));
        case 'download':
          _downloadController.add(downloadFromEvent(map));
        case 'download_result':
          _downloadResultController.add(downloadResultFromEvent(map));
        case 'tunnel_dropped':
          _tunnelDroppedController.add(tunnelDroppedFromEvent(map));
        case 'navigation':
          _navigationController.add(navigationFromEvent(map));
        case 'find_result':
          _findController.add(findResultFromEvent(map));
        default:
          _sessionsController.add(sessionsFromEvent(map));
      }
    });
  }

  final _sessionsController = StreamController<List<ContainerSession>>.broadcast();
  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _downloadResultController = StreamController<DownloadResult>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();
  final _navigationController = StreamController<NavigationState>.broadcast();
  final _findController = StreamController<FindResult>.broadcast();

  @override
  Future<bool> isolationAvailable() async =>
      await _method.invokeMethod<bool>('isolationAvailable') ?? false;

  @override
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
  }) async {
    final result = await _method.invokeMapMethod<Object?, Object?>('open', {
      'siteId': site.id,
      'profileId': site.profileId,
      'url': site.url,
      'proxyMode': site.proxyMode.name,
      'proxyHost': site.proxyHost,
      'proxyPort': site.proxyPort,
      'blockWebRtc': site.blockWebRtc,
      'blockTrackers': site.blockTrackers,
      'antiFingerprinting': site.antiFingerprinting,
      'allowCamera': site.allowCamera,
      'allowMicrophone': site.allowMicrophone,
      'allowLocation': site.allowLocation,
      'allowClipboard': site.allowClipboard,
      'userAgentMode': site.userAgentMode.name,
      'forceDark': site.forceDark,
      'pageZoom': site.pageZoom,
      'customCss': site.customCss,
      'customJs': site.customJs,
      'wipeOnExit': site.cookiePolicy == CookiePolicy.wipeOnExit,
      'filterRules': extras.filterRules,
      'userScripts': [for (final script in extras.userScripts) script.toMap()],
      'throwaway': throwaway,
    });
    return _sessionFrom(result!);
  }

  @override
  Future<void> wipe(String profileId) =>
      _method.invokeMethod('wipe', {'profileId': profileId});

  @override
  Future<void> wipeAll() => _method.invokeMethod('wipeAll');

  @override
  Future<void> close(String siteId) =>
      _method.invokeMethod('close', {'siteId': siteId});

  @override
  Future<void> reload(String siteId) =>
      _method.invokeMethod('reload', {'siteId': siteId});

  @override
  Stream<List<ContainerSession>> sessions() => _sessionsController.stream;

  @override
  Future<List<ContainerSession>> liveSessions() async {
    final result = await _method.invokeListMethod<Object?>('liveSessions');
    return (result ?? const <Object?>[])
        .map((e) => _sessionFrom(e! as Map<Object?, Object?>))
        .toList();
  }

  @override
  Stream<PendingPermissionRequest> permissionRequests() => _permissionController.stream;

  @override
  Future<void> resolvePermission(String requestId, PermissionDecision decision) =>
      _method.invokeMethod('resolvePermission', {
        'requestId': requestId,
        'decision': decision.name,
      });

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;

  @override
  Future<void> resolveDownload(String requestId, DownloadDecision decision) =>
      _method.invokeMethod('resolveDownload', {'requestId': requestId, 'decision': decision.name});

  @override
  Stream<DownloadResult> downloadResults() => _downloadResultController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  @override
  Future<ReaderArticle?> extractArticle(String siteId) async {
    final result = await _method
        .invokeMapMethod<Object?, Object?>('extractArticle', {'siteId': siteId});
    if (result == null) return null;
    return ReaderArticle(
      host: result['host']! as String,
      title: result['title']! as String,
      paragraphs: (result['paragraphs']! as List<Object?>).cast<String>(),
      minutesToRead: result['minutesToRead']! as int,
    );
  }

  @override
  Stream<NavigationState> navigation() => _navigationController.stream;

  @override
  Future<NavigationState?> navigationState(String siteId) async {
    final result = await _method
        .invokeMapMethod<Object?, Object?>('navigationState', {'siteId': siteId});
    return result == null ? null : navigationFromEvent(result);
  }

  @override
  Stream<FindResult> findResults() => _findController.stream;

  @override
  Future<void> goBack(String siteId) =>
      _method.invokeMethod('goBack', {'siteId': siteId});

  @override
  Future<void> goForward(String siteId) =>
      _method.invokeMethod('goForward', {'siteId': siteId});

  @override
  Future<void> stop(String siteId) =>
      _method.invokeMethod('stop', {'siteId': siteId});

  @override
  Future<void> loadUrl(String siteId, String url) =>
      _method.invokeMethod('loadUrl', {'siteId': siteId, 'url': url});

  @override
  Future<void> find(String siteId, String query) =>
      _method.invokeMethod('find', {'siteId': siteId, 'query': query});

  @override
  Future<void> findNext(String siteId, {required bool forward}) =>
      _method.invokeMethod('findNext', {'siteId': siteId, 'forward': forward});

  @override
  Future<void> clearFind(String siteId) =>
      _method.invokeMethod('clearFind', {'siteId': siteId});

  @override
  Future<void> keep(String siteId) =>
      _method.invokeMethod('keep', {'siteId': siteId});
}
```

- [ ] **Step 6: The fake**

Replace `lib/data/services/fake_container_engine.dart` with:

```dart
import 'dart:async';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/engine_extras.dart';
import '../../domain/models/find_result.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
import '../../domain/models/navigation_state.dart';
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/route_decision.dart';
import '../../domain/models/site.dart';
import 'container_engine.dart';

/// Drives every widget test in this plan. Deterministic: no timers, no delays.
class FakeContainerEngine implements ContainerEngine {
  FakeContainerEngine({
    this.isolation = true,
    this.proxyReachable = true,
    this.opensLive = true,
  });

  bool isolation;
  bool proxyReachable;

  /// Whether [open] reports a routable session as already `live`. The real
  /// engine never does: it reports `opening`, and only the native view's
  /// first finished load moves it to `live` (see [markLive]). Pass `false` to
  /// test anything that depends on that handoff.
  bool opensLive;

  final _sessions = <String, ContainerSession>{};
  final _controller = StreamController<List<ContainerSession>>.broadcast();
  final wiped = <String>[];
  final closed = <String>[];

  /// The extras each site was last opened with, by site id.
  final openedExtras = <String, EngineExtras>{};

  /// Every site passed to [open], by id; the latest open wins.
  final openedSites = <String, Site>{};

  /// The ids of the sites opened as throwaways.
  final openedAsThrowaway = <String>{};

  final wentBack = <String>[];
  final wentForward = <String>[];
  final stopped = <String>[];
  final loaded = <({String siteId, String url})>[];
  final findQueries = <({String siteId, String query})>[];
  final findSteps = <({String siteId, bool forward})>[];
  final clearedFind = <String>[];
  final kept = <String>[];

  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _downloadResultController = StreamController<DownloadResult>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();
  final _navigationController = StreamController<NavigationState>.broadcast();
  final _findController = StreamController<FindResult>.broadcast();
  final _navigation = <String, NavigationState>{};
  final resolvedPermissions = <String, PermissionDecision>{};
  final resolvedDownloads = <({String requestId, DownloadDecision decision})>[];
  ReaderArticle? articleToReturn;

  void _emit() => _controller.add(_sessions.values.toList());

  @override
  Future<bool> isolationAvailable() async => isolation;

  @override
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
  }) async {
    openedExtras[site.id] = extras;
    openedSites[site.id] = site;
    if (throwaway) openedAsThrowaway.add(site.id);
    final decision = resolveRoute(site, proxyReachable: proxyReachable);
    final session = ContainerSession(
      siteId: site.id,
      phase: decision is RouteRefused
          ? SessionPhase.refused
          : (opensLive ? SessionPhase.live : SessionPhase.opening),
      lastActiveAt: DateTime(2026, 8, 30, 12),
    );
    _sessions[site.id] = session;
    _emit();
    return session;
  }

  @override
  Future<void> wipe(String profileId) async => wiped.add(profileId);

  bool wipedAll = false;

  @override
  Future<void> wipeAll() async {
    wipedAll = true;
    _sessions.clear();
    _emit();
  }

  @override
  Future<void> close(String siteId) async {
    closed.add(siteId);
    _sessions.remove(siteId);
    _emit();
  }

  @override
  Stream<List<ContainerSession>> sessions() => _controller.stream;

  @override
  Future<List<ContainerSession>> liveSessions() async =>
      _sessions.values.toList();

  @override
  Future<void> reload(String siteId) async {}

  @override
  Stream<PendingPermissionRequest> permissionRequests() => _permissionController.stream;

  @override
  Future<void> resolvePermission(String requestId, PermissionDecision decision) async {
    resolvedPermissions[requestId] = decision;
  }

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;
  @override
  Future<void> resolveDownload(String requestId, DownloadDecision decision) async {
    resolvedDownloads.add((requestId: requestId, decision: decision));
  }
  @override
  Stream<DownloadResult> downloadResults() => _downloadResultController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  @override
  Future<ReaderArticle?> extractArticle(String siteId) async => articleToReturn;

  @override
  Stream<NavigationState> navigation() => _navigationController.stream;

  @override
  Future<NavigationState?> navigationState(String siteId) async => _navigation[siteId];

  @override
  Stream<FindResult> findResults() => _findController.stream;

  @override
  Future<void> goBack(String siteId) async => wentBack.add(siteId);

  @override
  Future<void> goForward(String siteId) async => wentForward.add(siteId);

  @override
  Future<void> stop(String siteId) async => stopped.add(siteId);

  @override
  Future<void> loadUrl(String siteId, String url) async =>
      loaded.add((siteId: siteId, url: url));

  @override
  Future<void> find(String siteId, String query) async =>
      findQueries.add((siteId: siteId, query: query));

  @override
  Future<void> findNext(String siteId, {required bool forward}) async =>
      findSteps.add((siteId: siteId, forward: forward));

  @override
  Future<void> clearFind(String siteId) async => clearedFind.add(siteId);

  @override
  Future<void> keep(String siteId) async => kept.add(siteId);

  /// Test helpers: push one event of each new kind.
  void emitPermissionRequest(PendingPermissionRequest request) =>
      _permissionController.add(request);
  void emitDownload(HeldDownloadEvent event) => _downloadController.add(event);
  void emitDownloadResult(DownloadResult result) => _downloadResultController.add(result);
  void emitTunnelDropped(TunnelDroppedEvent event) => _tunnelDroppedController.add(event);

  /// Test helper: what a native view does on every page change — the event,
  /// and the per-session snapshot `navigationState` returns.
  void emitNavigation(NavigationState state) {
    _navigation[state.siteId] = state;
    _navigationController.add(state);
  }

  /// Test helper: the snapshot only — a change reported before anyone
  /// listened.
  void seedNavigation(NavigationState state) => _navigation[state.siteId] = state;

  void emitFindResult(FindResult result) => _findController.add(result);

  /// Test helper: advance a live session's category counts by [delta] and
  /// re-emit — mirrors what a real category-tagged `FilterEngine` does over
  /// time.
  void addBlocked(String siteId, BlockedCategory category, int delta) {
    final current = _sessions[siteId];
    if (current == null) return;
    final counts = Map<BlockedCategory, int>.from(current.categoryCounts);
    counts[category] = (counts[category] ?? 0) + delta;
    _sessions[siteId] = current.copyWith(
      categoryCounts: counts,
      blockedCount: counts.values.fold<int>(0, (a, b) => a + b),
    );
    _emit();
  }

  /// Test helper: what the native `ContainerView` does when its first load
  /// finishes — `EngineChannel.markLive` moves an `opening` session to `live`.
  void markLive(String siteId) {
    final current = _sessions[siteId];
    if (current == null || current.phase == SessionPhase.refused) return;
    _sessions[siteId] = current.copyWith(phase: SessionPhase.live);
    _emit();
  }

  /// Test helper: put a session into the background without opening a page.
  void seedBackground(String siteId, {int blockedCount = 0}) {
    _sessions[siteId] = ContainerSession(
      siteId: siteId,
      phase: SessionPhase.background,
      lastActiveAt: DateTime(2026, 8, 30, 11, 58),
      blockedCount: blockedCount,
    );
    _emit();
  }

  void dispose() {
    _controller.close();
    _permissionController.close();
    _downloadController.close();
    _downloadResultController.close();
    _tunnelDroppedController.close();
    _navigationController.close();
    _findController.close();
  }
}
```

In `test/ui/features/container_route_test.dart`, `_GatedEngine.open` must match the new signature. Replace it with:

```dart
  @override
  Future<ContainerSession> open(
    Site site, {
    EngineExtras extras = EngineExtras.none,
    bool throwaway = false,
  }) async {
    final gate = _gate;
    _gate = null;
    if (gate != null) await gate.future;
    return super.open(site, extras: extras, throwaway: throwaway);
  }
```

- [ ] **Step 7: The shared race fix, and the navigation provider**

Create `lib/ui/features/container/view_models/subscribe_then_snapshot.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [events], preceded by [snapshot]'s value when no event has arrived first.
///
/// For an engine stream that is broadcast with no replay. `ContainerRoute`
/// calls `open` from `initState`, ahead of the first `build()` that creates a
/// provider using this, so an engine that emits before anyone listens needs
/// the snapshot to be seen at all.
///
/// **Subscribe first, then read the snapshot.** The other order drops any
/// change emitted while the snapshot is in flight, and on a device that is
/// the common case, not an edge: `open` decides its route on a worker thread
/// and registers the session moments later, typically mid-snapshot. The lost
/// event left the route on the opening checklist forever (`7996a17`). And
/// once an event has arrived, the snapshot is older than it and is discarded
/// rather than allowed to overwrite it.
///
/// Shared by `sessionForSiteProvider` and `navigationForSiteProvider` rather
/// than written twice: the race is subtle enough to get wrong again.
Stream<T> subscribeThenSnapshot<T>(
  Ref ref, {
  required Stream<T> events,
  required Future<T> Function() snapshot,
}) {
  final out = StreamController<T>();
  var sawEvent = false;
  final sub = events.listen(
    (value) {
      sawEvent = true;
      out.add(value);
    },
    onError: out.addError,
  );
  snapshot().then(
    (value) {
      if (!sawEvent && !out.isClosed) out.add(value);
    },
    onError: (Object e, StackTrace s) {
      if (!out.isClosed) out.addError(e, s);
    },
  );
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  return out.stream;
}
```

In `lib/ui/features/container/view_models/providers.dart`:
1. Delete `import 'dart:async';` (its only use moves into the helper; leaving it is an `unused_import`).
2. Add imports:

```dart
import '../../../../domain/models/navigation_state.dart';
import 'subscribe_then_snapshot.dart';
```

3. Replace the whole `sessionForSiteProvider` declaration and its doc comment with:

```dart
/// The live session for one site, or `null` when that site has none. Feeds
/// [ContainerRoute]'s `opening -> live -> refused` state machine. Filters
/// [ContainerEngine.sessions] rather than adding a per-site-keyed stream to
/// the engine itself, since the engine already emits its full list on every
/// change and every existing caller ([sessions]) wants that shape. Any
/// sessions event supersedes the snapshot — see [subscribeThenSnapshot].
///
/// Auto-disposed with the route that watches it, like
/// [navigationForSiteProvider]: a throwaway's id is never seen again once its
/// route is gone, and a family kept for the life of the app would hold one
/// engine subscription per throwaway ever opened.
final sessionForSiteProvider =
    StreamProvider.autoDispose.family<ContainerSession?, String>((ref, siteId) {
  final engine = ref.watch(containerEngineProvider);
  return subscribeThenSnapshot<ContainerSession?>(
    ref,
    events: engine.sessions().map((sessions) => _findSite(sessions, siteId)),
    snapshot: () => engine.liveSessions().then((sessions) => _findSite(sessions, siteId)),
  );
});

/// The page one site's container is showing (browser-chrome spec §3.2): its
/// address, history and load progress, or `null` before its view has
/// reported anything. Has `sessionForSiteProvider`'s race exactly — the first
/// load can report before anyone listens — hence the shared helper.
///
/// Auto-disposed with its route, so a site opened again starts from its new
/// page rather than showing the last visit's address and history until the
/// first report.
final navigationForSiteProvider =
    StreamProvider.autoDispose.family<NavigationState?, String>((ref, siteId) {
  final engine = ref.watch(containerEngineProvider);
  return subscribeThenSnapshot<NavigationState?>(
    ref,
    events: engine.navigation().where((state) => state.siteId == siteId),
    snapshot: () => engine.navigationState(siteId),
  );
});
```

- [ ] **Step 8: Run the tests and the gate**

Run: `flutter test test/data/container_engine_channel_test.dart test/ui/features/navigation_for_site_provider_test.dart test/ui/features/session_for_site_provider_test.dart test/ui/features/container_route_test.dart`
Expected: PASS — 8 new tests; `session_for_site_provider_test.dart`'s two still pass through the extracted helper.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 56.

- [ ] **Step 9: Commit**

```bash
git add lib/domain/models/navigation_state.dart lib/domain/models/find_result.dart lib/data/services lib/ui/features/container/view_models test/data/container_engine_channel_test.dart test/ui/features/navigation_for_site_provider_test.dart test/ui/features/container_route_test.dart
git commit -m "feat: carry page navigation and find results across the engine channel"
```

---

### Task 6: Kotlin reports navigation and find, and takes in-page controls

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/Navigation.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt`, `Shields.kt`, `ContainerViewFactory.kt`, `EngineChannel.kt`
- Modify (whole file): `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/NavigationTest.kt`

**Interfaces:**
- Consumes: Task 5's channel names and event shapes (Dart already routes both event types to their own streams, so emitting them is safe).
- Produces:
  - `data class NavigationSnapshot(url, title, canGoBack, canGoForward, loading, progress)` with `fun toEvent(siteId: String): Map<String, Any?>`
  - `class NavigationTracker(initialUrl: String)`: `started(url)`, `finished(url)`, `stopped()`, `visited(url)`, `progressed(percent)`, `titled(title: String?)`, `snapshot(canGoBack, canGoForward)`
  - `fun findResultEvent(siteId: String, activeMatch: Int, matchCount: Int): Map<String, Any?>`
  - `fun isLoadableUrl(url: String): Boolean`
  - `interface PageCallbacks { started(url); finished(url); visited(url) }` with `PageCallbacks.NONE`; `RequestInterceptor.clientFor(config, onLoaded, lengths, page)`
  - `Shields.chromeClientFor(config, session, onAsk, onProgress, onTitle)`
  - `ContainerView`: `goBack()`, `goForward()`, `stop()`, `load(url)`, `find(query)`, `findNext(forward)`, `clearFind()`; constructor callbacks `onNavigation`, `onFindResult`
  - `Session.navigation: NavigationSnapshot?`; `EngineChannel.onNavigation(session, snapshot)`, `onFindResult(session, activeMatch, matchCount)`; channel methods `goBack`, `goForward`, `stop`, `loadUrl`, `find`, `findNext`, `clearFind`, `navigationState`

- [ ] **Step 1: Write the failing JVM test**

```kotlin
// android/app/src/test/kotlin/com/mono/container/engine/NavigationTest.kt
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The chrome (browser-chrome spec §3) is built from these: what the page is
 * doing, folded from WebView's callbacks, and the one guard on what
 * `loadUrl` may load.
 */
class NavigationTest {

    @Test fun `a new container starts loading its own address`() {
        assertEquals(
            NavigationSnapshot("https://forum.example.com", "", false, false, true, 0),
            NavigationTracker("https://forum.example.com").snapshot(canGoBack = false, canGoForward = false),
        )
    }

    @Test fun `a page starts, reports progress and a title, then finishes`() {
        val tracker = NavigationTracker("https://forum.example.com")
        tracker.started("https://forum.example.com/")
        tracker.progressed(40)
        tracker.titled("Forum")
        assertEquals(
            NavigationSnapshot("https://forum.example.com/", "Forum", false, false, true, 40),
            tracker.snapshot(canGoBack = false, canGoForward = false),
        )

        tracker.finished("https://forum.example.com/")
        val done = tracker.snapshot(canGoBack = true, canGoForward = false)
        assertFalse(done.loading)
        assertEquals(100, done.progress)
        assertTrue(done.canGoBack)
    }

    @Test fun `the next load starts the line from zero`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.finished("https://a.example/")
        tracker.started("https://a.example/next")
        val snapshot = tracker.snapshot(false, false)
        assertTrue(snapshot.loading)
        assertEquals(0, snapshot.progress)
    }

    @Test fun `progress reported before the start is kept`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.finished("https://a.example/")
        tracker.progressed(10)
        tracker.started("https://a.example/next")
        assertEquals(10, tracker.snapshot(false, false).progress)
    }

    @Test fun `stopping ends the load where it stood`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.progressed(60)
        tracker.stopped()
        val snapshot = tracker.snapshot(false, false)
        assertFalse(snapshot.loading)
        assertEquals(60, snapshot.progress)
    }

    @Test fun `a history update moves the address without ending the load`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.started("https://a.example/")
        tracker.visited("https://a.example/#section")
        val snapshot = tracker.snapshot(false, false)
        assertEquals("https://a.example/#section", snapshot.url)
        assertTrue(snapshot.loading)
    }

    @Test fun `progress outside 0 to 100 is clamped`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.progressed(140)
        assertEquals(100, tracker.snapshot(false, false).progress)
        tracker.progressed(-5)
        assertEquals(0, tracker.snapshot(false, false).progress)
    }

    @Test fun `a missing title reads as empty`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.titled("Before")
        tracker.titled(null)
        assertEquals("", tracker.snapshot(false, false).title)
    }

    @Test fun `the navigation event carries every key Dart reads`() {
        assertEquals(
            mapOf(
                "type" to "navigation", "siteId" to "s1", "url" to "https://a.example/x",
                "title" to "X", "canGoBack" to true, "canGoForward" to false,
                "loading" to false, "progress" to 100,
            ),
            NavigationSnapshot("https://a.example/x", "X", true, false, false, 100).toEvent("s1"),
        )
    }

    @Test fun `the find result event carries every key Dart reads`() {
        assertEquals(
            mapOf("type" to "find_result", "siteId" to "s1", "activeMatch" to 2, "matchCount" to 7),
            findResultEvent("s1", 2, 7),
        )
    }

    @Test fun `loadUrl accepts http and https addresses`() {
        for (url in listOf(
            "https://example.com",
            "http://example.com:8080/a?b=1#c",
            "HTTPS://Example.com/",
            "https://10.0.2.2:8888/x",
        )) {
            assertTrue(url, isLoadableUrl(url))
        }
    }

    // Review Focus 3: Dart never sends these; the platform refuses them anyway.
    @Test fun `loadUrl refuses every other scheme`() {
        for (url in listOf(
            "javascript:alert(1)",
            "JAVASCRIPT:alert(1)",
            " https://example.com",
            "file:///sdcard/a.html",
            "intent://scan/#Intent;end",
            "content://media/external/images/1",
            "data:text/html,hi",
            "about:blank",
            "ftp://example.com",
            "httpx://example.com",
            "https:///no-host",
            "https://",
            "",
        )) {
            assertFalse(url, isLoadableUrl(url))
        }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run (from `android/`): `./gradlew :app:testDebugUnitTest`
Expected: FAIL — compilation errors: `NavigationSnapshot`, `NavigationTracker`, `findResultEvent`, `isLoadableUrl` unresolved. (If `android/gradlew` is missing, run `flutter build apk --debug` from the repo root first.)

- [ ] **Step 3: Write `Navigation.kt`**

```kotlin
package com.mono.container.engine

/** One `navigation` event (browser-chrome spec §3.1): what the chrome shows about a page. */
data class NavigationSnapshot(
    val url: String,
    val title: String,
    val canGoBack: Boolean,
    val canGoForward: Boolean,
    val loading: Boolean,
    /** 0–100. */
    val progress: Int,
) {
    /** Also what `navigationState` returns; Dart decodes both the same way. */
    fun toEvent(siteId: String): Map<String, Any?> = mapOf(
        "type" to "navigation",
        "siteId" to siteId,
        "url" to url,
        "title" to title,
        "canGoBack" to canGoBack,
        "canGoForward" to canGoForward,
        "loading" to loading,
        "progress" to progress,
    )
}

/**
 * Folds WebView's page callbacks — `onPageStarted`, `onPageFinished`,
 * `doUpdateVisitedHistory`, `onProgressChanged`, `onReceivedTitle` — into one
 * state. History (`canGoBack`/`canGoForward`) is read from the WebView at
 * [snapshot] time. Main thread only, like the WebView that feeds it.
 */
class NavigationTracker(initialUrl: String) {
    private var url = initialUrl
    private var title = ""

    /** The view starts loading its site's address as soon as it exists. */
    private var loading = true
    private var progress = 0

    fun started(url: String) {
        this.url = url
        loading = true
        // A new load after a finished one restarts the line. WebView may
        // report its first progress before this callback, so a lower value
        // already reported for this load is kept.
        if (progress >= 100) progress = 0
    }

    fun finished(url: String) {
        this.url = url
        loading = false
        progress = 100
    }

    fun stopped() {
        loading = false
    }

    fun visited(url: String) {
        this.url = url
    }

    fun progressed(percent: Int) {
        progress = percent.coerceIn(0, 100)
    }

    fun titled(title: String?) {
        this.title = title.orEmpty()
    }

    fun snapshot(canGoBack: Boolean, canGoForward: Boolean) =
        NavigationSnapshot(url, title, canGoBack, canGoForward, loading, progress)
}

/** The `find_result` event (spec §6.5). [activeMatch] is WebView's zero-based ordinal. */
fun findResultEvent(siteId: String, activeMatch: Int, matchCount: Int): Map<String, Any?> = mapOf(
    "type" to "find_result",
    "siteId" to siteId,
    "activeMatch" to activeMatch,
    "matchCount" to matchCount,
)

private val loadableUrl = Regex("^https?://[^/?#\\s]+", RegexOption.IGNORE_CASE)

/**
 * Whether `loadUrl` may load [url]: `http` or `https`, with a host, from the
 * very first character. Nothing else — `javascript:` would run in the page,
 * `file:` and `content:` read the device, `intent:` leaves the container.
 * Dart's parser never sends any of them; this refuses them anyway.
 */
fun isLoadableUrl(url: String): Boolean = loadableUrl.find(url) != null
```

- [ ] **Step 4: Run the JVM tests**

Run (from `android/`): `./gradlew :app:testDebugUnitTest`
Expected: PASS. Read `build/app/test-results/testDebugUnitTest/TEST-com.mono.container.engine.NavigationTest.xml`: `tests="12" failures="0" errors="0"`. Kotlin counts (the `grep | sed | awk` line): K0 + 12, 0 failures, 0 errors.

- [ ] **Step 5: Page callbacks in `RequestInterceptor`**

In `RequestInterceptor.kt`, replace

```kotlin
class RequestInterceptor(private val filters: FilterEngine, private val onRefused: (RouteFailure) -> Unit = {}) {
    /** [lengths] records each proxied response's declared length, for the
     *  view's held-download sheet. */
    fun clientFor(config: SiteConfig, onLoaded: () -> Unit = {}, lengths: DeclaredLengths? = null): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? = intercept(config, request, lengths)
        override fun onPageFinished(view: WebView, url: String) = onLoaded()
    }
```

with

```kotlin
/** The page events [ContainerView] builds its navigation state from. */
interface PageCallbacks {
    fun started(url: String) {}
    fun finished(url: String) {}
    fun visited(url: String) {}

    companion object {
        val NONE = object : PageCallbacks {}
    }
}

class RequestInterceptor(private val filters: FilterEngine, private val onRefused: (RouteFailure) -> Unit = {}) {
    /** [lengths] records each proxied response's declared length, for the
     *  view's held-download sheet. [page] hears the page starting, finishing
     *  and moving through history (browser-chrome spec §3.1). */
    fun clientFor(
        config: SiteConfig,
        onLoaded: () -> Unit = {},
        lengths: DeclaredLengths? = null,
        page: PageCallbacks = PageCallbacks.NONE,
    ): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? = intercept(config, request, lengths)

        override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
            if (url != null) page.started(url)
        }

        override fun onPageFinished(view: WebView, url: String?) {
            onLoaded()
            if (url != null) page.finished(url)
        }

        override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
            if (url != null) page.visited(url)
        }
    }
```

- [ ] **Step 6: Progress and title in `Shields`**

In `Shields.kt`, replace

```kotlin
    fun chromeClientFor(
        config: SiteConfig,
        session: Session,
        onAsk: (PendingPermission) -> String,
    ) = object : android.webkit.WebChromeClient() {
```

with

```kotlin
    fun chromeClientFor(
        config: SiteConfig,
        session: Session,
        onAsk: (PendingPermission) -> String,
        onProgress: (Int) -> Unit = {},
        onTitle: (String?) -> Unit = {},
    ) = object : android.webkit.WebChromeClient() {
        override fun onProgressChanged(view: android.webkit.WebView, newProgress: Int) = onProgress(newProgress)

        override fun onReceivedTitle(view: android.webkit.WebView, title: String?) = onTitle(title)

```

- [ ] **Step 7: `ContainerView` tracks, reports and takes controls**

Replace `ContainerView.kt` with:

```kotlin
package com.mono.container.engine

import android.content.Context
import android.view.View
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.webkit.WebSettings
import androidx.webkit.ServiceWorkerControllerCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.platform.PlatformView

class ContainerView(
    private val context: Context,
    private val config: SiteConfig,
    private val profiles: ProfileManager,
    private val interceptor: RequestInterceptor,
    private val session: Session,
    private val onLive: () -> Unit = {},
    private val onAsk: (PendingPermission) -> String = { "" },
    /** [sizeBytes] is null when the size is unknown — see [heldDownloadSize]. */
    private val onDownload: (url: String, mimeType: String, fileName: String, sizeBytes: Long?, kindLabel: String) -> String = { _, _, _, _, _ -> "" },
    /** Every change to what the page is doing: browser-chrome spec §3.1's `navigation` event. */
    private val onNavigation: (NavigationSnapshot) -> Unit = {},
    /** A finished count for the current find: spec §6.5's `find_result` event. */
    private val onFindResult: (activeMatch: Int, matchCount: Int) -> Unit = { _, _ -> },
) : PlatformView {

    private var disposed = false

    private val declaredLengths = DeclaredLengths()

    /** Declared before `init`, which hands the clients that feed it to the WebView. */
    private val navigation = NavigationTracker(config.url)

    private val webView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.userAgentString = userAgentFor(config.userAgentMode, context)
        settings.setSupportMultipleWindows(false)
        settings.mediaPlaybackRequiresUserGesture = true
        settings.setSafeBrowsingEnabled(false)   // pings Google directly; see Constraints

        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, config.forceDark)
        }
        setInitialScale(config.pageZoom)
    }

    init {
        // Must precede the first load, or the request goes to the default store.
        androidx.webkit.WebViewCompat.setProfile(webView, config.profileId)
        webView.webViewClient = interceptor.clientFor(config, onLive, declaredLengths, object : PageCallbacks {
            override fun started(url: String) = report { navigation.started(url) }
            override fun finished(url: String) = report { navigation.finished(url) }
            override fun visited(url: String) = report { navigation.visited(url) }
        })
        webView.webChromeClient = Shields.chromeClientFor(
            config, session, onAsk,
            onProgress = { percent -> report { navigation.progressed(percent) } },
            onTitle = { title -> report { navigation.titled(title) } },
        )
        // Reported once counting is done, so the find bar never shows a
        // count that is still climbing.
        webView.setFindListener { activeMatch, matchCount, isDoneCounting ->
            if (isDoneCounting && !disposed) onFindResult(activeMatch, matchCount)
        }
        Shields.apply(webView, config) { session.counters.fingerprinting.incrementAndGet() }

        webView.setDownloadListener { url, _, contentDisposition, mimeType, contentLength ->
            val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val extension = MimeTypeMap.getFileExtensionFromUrl(url).ifEmpty {
                mimeType?.substringAfter('/') ?: ""
            }
            val resolvedMimeType = mimeType?.ifEmpty { null } ?: "application/octet-stream"
            // Not currentRoute(): that probes the proxy, and this is the main
            // thread. Any mode but direct means RequestInterceptor supplied
            // this response, so contentLength is not the server's number.
            val size = heldDownloadSize(config.proxyMode != "direct", contentLength, declaredLengths.take(url))
            onDownload(url, resolvedMimeType, fileName, size, extension.uppercase().ifEmpty { "FILE" })
        }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
            ServiceWorkerControllerCompat.getInstance()
                .setServiceWorkerClient(interceptor.serviceWorkerClient(config))
        }

        webView.loadUrl(config.url)
    }

    override fun getView(): View = webView

    /** Applies [change] to the navigation state and reports the result,
     *  unless this view is already gone. */
    private fun report(change: () -> Unit) {
        if (disposed) return
        change()
        onNavigation(navigation.snapshot(webView.canGoBack(), webView.canGoForward()))
    }

    fun reload() {
        if (!disposed) webView.reload()
    }

    fun goBack() {
        if (!disposed && webView.canGoBack()) webView.goBack()
    }

    fun goForward() {
        if (!disposed && webView.canGoForward()) webView.goForward()
    }

    fun stop() {
        if (disposed) return
        webView.stopLoading()
        report { navigation.stopped() }
    }

    /** Loads [url] in this container, on its own route. Refuses every scheme
     *  but http and https — see [isLoadableUrl]. */
    fun load(url: String) {
        if (!disposed && isLoadableUrl(url)) webView.loadUrl(url)
    }

    fun find(query: String) {
        if (!disposed) webView.findAllAsync(query)
    }

    fun findNext(forward: Boolean) {
        if (!disposed) webView.findNext(forward)
    }

    fun clearFind() {
        if (!disposed) webView.clearMatches()
    }

    /** Runs the reader-mode JS heuristic and hands the parsed article back
     * on the platform thread. `null` when nothing article-shaped was found. */
    fun extractArticle(onResult: (Map<String, Any?>?) -> Unit) {
        if (disposed) {
            onResult(null)
            return
        }
        webView.evaluateJavascript(READER_JS) { rawJson ->
            val json = rawJson?.takeIf { it != "null" }
            if (json == null) {
                onResult(null)
                return@evaluateJavascript
            }
            onResult(parseReaderJson(json))
        }
    }

    /**
     * Idempotent: `close` on the engine channel and Flutter tearing the
     * platform view down both land here, in either order, and destroying a
     * WebView twice is not safe.
     */
    override fun dispose() {
        if (disposed) return
        disposed = true
        webView.stopLoading()
        // The profile this view used cannot be deleted until the next start
        // (see ProfileManager.wipe), and its HTTP cache has no profile-level
        // clear — the view is the only handle on it, so empty it now.
        if (config.wipeOnExit) webView.clearCache(true)
        webView.destroy()
        if (config.wipeOnExit) {
            deleteDownloadsDir(context, config.profileId)
            profiles.wipe(config.profileId)
        }
    }

}
```

- [ ] **Step 8: The factory wires the reports**

In `ContainerViewFactory.kt`, replace

```kotlin
            onDownload = { url, mimeType, fileName, sizeBytes, kindLabel ->
                val requestId = engine.nextRequestId()
                engine.onDownload(siteId, requestId, url, mimeType, fileName, sizeBytes, kindLabel)
                requestId
            },
        )
```

with

```kotlin
            onDownload = { url, mimeType, fileName, sizeBytes, kindLabel ->
                val requestId = engine.nextRequestId()
                engine.onDownload(siteId, requestId, url, mimeType, fileName, sizeBytes, kindLabel)
                requestId
            },
            // Reported against the session this view was made for, not
            // whatever the site's session is by then: a reopened site's older
            // view must not speak for the newer session.
            onNavigation = { snapshot -> engine.onNavigation(session, snapshot) },
            onFindResult = { activeMatch, matchCount -> engine.onFindResult(session, activeMatch, matchCount) },
        )
```

- [ ] **Step 9: The channel's events and methods**

In `EngineChannel.kt`:

1. In `class Session`, replace

```kotlin
    var failure: String? = null
    var view: ContainerView? = null
```

with

```kotlin
    var failure: String? = null
    var view: ContainerView? = null

    /** The last `navigation` event this session's view reported, for
     *  `navigationState`: Dart may start listening after the first load has
     *  already reported (browser-chrome spec §3.2). */
    var navigation: NavigationSnapshot? = null
```

2. After the closing brace of `fun onDownload(…)` (the one ending `"sourceHost" to host, "kindLabel" to kindLabel, "requestId" to requestId,` / `))` / `}`), add:

```kotlin

    /**
     * Called by [ContainerView] on every page change. [session] is the one the
     * view was made for: only the site's current session reaches Dart, since
     * a reopened site's older view still reports. Kept per session for
     * `navigationState`.
     */
    fun onNavigation(session: Session, snapshot: NavigationSnapshot) {
        session.navigation = snapshot
        val siteId = session.config.siteId
        if (sessions[siteId] !== session) return
        sink?.success(snapshot.toEvent(siteId))
    }

    /** Called by [ContainerView] once a find has finished counting. */
    fun onFindResult(session: Session, activeMatch: Int, matchCount: Int) {
        val siteId = session.config.siteId
        if (sessions[siteId] !== session) return
        sink?.success(findResultEvent(siteId, activeMatch, matchCount))
    }

    /** The open view for the call's `siteId`. Every in-page control is a
     *  silent no-op on a closed or unknown session, like `reload`. */
    private fun viewFor(call: MethodCall): ContainerView? =
        sessions[call.argument<String>("siteId")]?.view
```

3. In `onMethodCall`, replace

```kotlin
                "reload" -> {
                    sessions[call.argument<String>("siteId")]?.view?.reload()
                    result.success(null)
                }
```

with

```kotlin
                "reload" -> {
                    sessions[call.argument<String>("siteId")]?.view?.reload()
                    result.success(null)
                }
                "goBack" -> {
                    viewFor(call)?.goBack()
                    result.success(null)
                }
                "goForward" -> {
                    viewFor(call)?.goForward()
                    result.success(null)
                }
                "stop" -> {
                    viewFor(call)?.stop()
                    result.success(null)
                }
                "loadUrl" -> {
                    // ContainerView.load refuses every scheme but http(s).
                    viewFor(call)?.load(call.argument<String>("url")!!)
                    result.success(null)
                }
                "find" -> {
                    viewFor(call)?.find(call.argument<String>("query")!!)
                    result.success(null)
                }
                "findNext" -> {
                    viewFor(call)?.findNext(call.argument<Boolean>("forward") ?: true)
                    result.success(null)
                }
                "clearFind" -> {
                    viewFor(call)?.clearFind()
                    result.success(null)
                }
                "navigationState" -> {
                    val siteId = call.argument<String>("siteId")!!
                    result.success(sessions[siteId]?.navigation?.toEvent(siteId))
                }
```

- [ ] **Step 10: Verify the Kotlin compiles and every check passes**

Run (from `android/`): `./gradlew :app:testDebugUnitTest` — Expected: PASS; Kotlin counts K0 + 12, 0 failures, 0 errors.
Run (from the repo root): `flutter build apk --debug 2>&1 | tee build/apk-build.log` then `grep -c '^e:' build/apk-build.log` — Expected: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`, and `0`.
Run: `flutter analyze` and `flutter test` — Expected: clean; all pass, D0 + 56.

- [ ] **Step 11: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine android/app/src/test/kotlin/com/mono/container/engine/NavigationTest.kt
git commit -m "feat: report page navigation and find results from each container"
```

---

### Task 7: Kotlin throwaway journal, `open(throwaway)`, `keep` and the start sweep

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/ThrowawayJournal.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`, `ContainerView.kt`, `ContainerViewFactory.kt`, `ProfileManager.kt`, `android/app/src/main/kotlin/com/mono/container/MainActivity.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/ThrowawayJournalTest.kt`

**Interfaces:**
- Consumes: `PendingDeletions` (storage format and atomic rewrite); `ProfileManager.wipe`; `deleteDownloadsDir`; Task 5's `open` argument `throwaway` and method `keep`.
- Produces:
  - `class ThrowawayJournal(file: File)`: `names()`, `add(profileId)`, `remove(profileId)`, `clear()`, `sweep(wipe: (String) -> Unit)`
  - `internal fun wipeThenForget(profileId: String, journal: ThrowawayJournal, wipe: () -> Unit)`
  - `internal fun keepThrowaway(profileId: String, journal: ThrowawayJournal, stopWiping: () -> Unit)`
  - `ProfileManager.sweepThrowaways(journal: ThrowawayJournal, deleteDownloads: (String) -> Unit)`
  - `EngineChannel(context, profiles, throwaways: ThrowawayJournal)` with `val throwaways`; `Session.wipeOnExit: Boolean` (var)
  - `ContainerView(…, throwaways: ThrowawayJournal, …)`

- [ ] **Step 1: Write the failing JVM test**

```kotlin
// android/app/src/test/kotlin/com/mono/container/engine/ThrowawayJournalTest.kt
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * A throwaway's profile is on disk while its page is open (browser-chrome
 * spec §5.4). If the app dies before `ContainerView.dispose`, nothing else
 * would ever wipe it, so it is listed from before it exists until it is
 * wiped or kept, and every start wipes whatever is still listed.
 */
class ThrowawayJournalTest {

    @get:Rule val folder = TemporaryFolder()

    private val file get() = java.io.File(folder.root, "throwaway-profiles")

    private fun journal() = ThrowawayJournal(file)

    @Test fun `a throwaway stays listed across a restart`() {
        journal().add("t1")
        assertEquals(listOf("t1"), journal().names())
    }

    @Test fun `the file holds profile ids and nothing else`() {
        val journal = journal()
        journal.add("t1")
        journal.add("t2")
        assertEquals("t1\nt2\n", file.readText())
    }

    @Test fun `a wipe on dispose forgets the throwaway, after wiping`() {
        val journal = journal()
        journal.add("t1")
        val calls = mutableListOf<String>()

        wipeThenForget("t1", journal) { calls += "wipe while listed: ${journal.names()}" }

        assertEquals(listOf("wipe while listed: [t1]"), calls)
        assertTrue(journal().names().isEmpty())
    }

    @Test fun `a wipe that throws leaves it listed for the next start`() {
        val journal = journal()
        journal.add("t1")

        runCatching { wipeThenForget("t1", journal) { throw IllegalStateException("store gone") } }

        assertEquals(listOf("t1"), journal().names())
    }

    @Test fun `a wipe-on-exit site that was never a throwaway leaves the journal alone`() {
        val journal = journal()
        journal.add("t1")

        wipeThenForget("s1", journal) {}

        assertEquals(listOf("t1"), journal().names())
    }

    @Test fun `keeping a throwaway stops its wipe and forgets it`() {
        val journal = journal()
        journal.add("t1")
        var wipesOnExit = true

        keepThrowaway("t1", journal) { wipesOnExit = false }

        assertFalse(wipesOnExit)
        assertTrue(journal().names().isEmpty())
    }

    @Test fun `the start sweep wipes every listed profile and removes the file`() {
        val journal = journal()
        journal.add("t1")
        journal.add("t2")
        val wiped = mutableListOf<String>()

        journal.sweep { wiped += it }

        assertEquals(listOf("t1", "t2"), wiped)
        assertTrue(journal().names().isEmpty())
        assertFalse(file.exists())
    }

    @Test fun `a profile whose start wipe throws is tried again next start`() {
        val journal = journal()
        journal.add("gone")
        journal.add("stuck")

        journal.sweep { if (it == "stuck") throw IllegalStateException("store unavailable") }

        assertEquals(listOf("stuck"), journal().names())
    }

    @Test fun `panic clears the journal`() {
        val journal = journal()
        journal.add("t1")
        journal.add("t2")

        journal.clear()

        assertTrue(journal().names().isEmpty())
        assertFalse(file.exists())
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run (from `android/`): `./gradlew :app:testDebugUnitTest`
Expected: FAIL — `ThrowawayJournal`, `wipeThenForget`, `keepThrowaway` unresolved.

- [ ] **Step 3: Write `ThrowawayJournal.kt`**

```kotlin
package com.mono.container.engine

import java.io.File

/**
 * Throwaway containers whose profile may still be on disk (browser-chrome
 * spec §5.4), one opaque profile id per line in `filesDir/throwaway-profiles`.
 *
 * `open(throwaway = true)` lists the id before the profile is created, and it
 * leaves the list once `ContainerView.dispose` has wiped the profile or `keep`
 * has saved the site. Anything still listed when the engine starts belonged
 * to a page the app died with, and is wiped then. Panic's `wipeAll` destroys
 * every profile and clears the list.
 *
 * A separate file from [PendingDeletions], which it stores through (the same
 * one-id-per-line format and atomic rewrite): that file lists profiles to
 * *delete* at the next start because a wipe could only clear them in place;
 * this one lists profiles to *wipe*. A throwaway wiped while in use goes
 * through [ProfileManager.wipe] like any other profile, so it lands in both
 * until the next start deals with each.
 *
 * Holds random ids only, never a host, name or URL. It sits in plaintext in
 * `filesDir`, which is within the threat model: coerced unlock, not disk
 * imaging.
 */
class ThrowawayJournal(file: File) {
    private val ids = PendingDeletions(file)

    fun names(): List<String> = ids.names()

    fun add(profileId: String) = ids.add(profileId)

    fun remove(profileId: String) = ids.remove(profileId)

    /** Panic: every profile is gone already. */
    fun clear() = ids.sweep {}

    /** Engine start: [wipe] each listed profile. One whose wipe throws stays
     *  listed for the start after. */
    fun sweep(wipe: (String) -> Unit) = ids.sweep(wipe)
}

/**
 * How a view's wipe-on-exit ends: [wipe], then — only if it did not throw —
 * off the journal. For a wipe-on-exit site that was never a throwaway, the
 * removal is a no-op.
 */
internal fun wipeThenForget(profileId: String, journal: ThrowawayJournal, wipe: () -> Unit) {
    wipe()
    journal.remove(profileId)
}

/**
 * `keep` (spec §5.3): a throwaway saved as a site stops being wiped on exit —
 * [stopWiping] — and stops being a leftover for the start sweep.
 */
internal fun keepThrowaway(profileId: String, journal: ThrowawayJournal, stopWiping: () -> Unit) {
    stopWiping()
    journal.remove(profileId)
}
```

- [ ] **Step 4: Run the JVM tests**

Run (from `android/`): `./gradlew :app:testDebugUnitTest`
Expected: PASS. `TEST-com.mono.container.engine.ThrowawayJournalTest.xml`: `tests="9" failures="0" errors="0"`; `PendingDeletionsTest.xml` unchanged and passing. Kotlin counts: K0 + 21.

- [ ] **Step 5: The channel journals, keeps and clears**

In `EngineChannel.kt`:

1. Replace

```kotlin
class EngineChannel(
    private val context: Context,
    private val profiles: ProfileManager,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
```

with

```kotlin
class EngineChannel(
    private val context: Context,
    private val profiles: ProfileManager,
    /** Throwaways whose profile may still be on disk; see [ThrowawayJournal]. */
    val throwaways: ThrowawayJournal,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
```

2. In `class Session`, replace

```kotlin
    var navigation: NavigationSnapshot? = null
```

with

```kotlin
    var navigation: NavigationSnapshot? = null

    /** Starts as the config's; `keep` turns it off for a throwaway saved as a
     *  site while its page is still open (spec §5.3). [ContainerView.dispose]
     *  reads this, not the config. */
    var wipeOnExit: Boolean = config.wipeOnExit
```

3. In `open`, replace

```kotlin
    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val config = configFrom(call)
        if (!profiles.isAvailable()) {
```

with

```kotlin
    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val throwaway = call.argument<Boolean>("throwaway") ?: false
        // A throwaway always wipes on exit, whatever else the call says.
        val config = configFrom(call).let { if (throwaway) it.copy(wipeOnExit = true) else it }
        // Listed before its profile can exist (register() creates it), so a
        // crash from here on still leaves it for the next start's sweep.
        if (throwaway) throwaways.add(config.profileId)
        if (!profiles.isAvailable()) {
```

4. In `onMethodCall`, replace

```kotlin
                "wipeAll" -> {
                    wipeAll()
                    result.success(null)
                }
```

with

```kotlin
                "wipeAll" -> {
                    wipeAll()
                    result.success(null)
                }
                "keep" -> {
                    keep(call.argument<String>("siteId")!!)
                    result.success(null)
                }
```

5. Replace

```kotlin
        java.io.File(context.filesDir, "downloads").deleteRecursively()
        profiles.wipeAll()
    }
```

with

```kotlin
        java.io.File(context.filesDir, "downloads").deleteRecursively()
        profiles.wipeAll()
        // Every profile is gone, throwaways included: nothing left to sweep.
        throwaways.clear()
    }

    /** `keep` (spec §5.3–5.4): a throwaway saved as a site. A no-op on an
     *  unknown session, like every in-page control. */
    private fun keep(siteId: String) {
        val session = sessions[siteId] ?: return
        keepThrowaway(session.config.profileId, throwaways) { session.wipeOnExit = false }
    }
```

- [ ] **Step 6: The view wipes through the journal, by the session's flag**

In `ContainerView.kt`:

1. Replace

```kotlin
    private val session: Session,
    private val onLive: () -> Unit = {},
```

with

```kotlin
    private val session: Session,
    /** Throwaways still on disk (spec §5.4); a wipe here takes this one off. */
    private val throwaways: ThrowawayJournal,
    private val onLive: () -> Unit = {},
```

2. Replace the body of `dispose()` from `webView.stopLoading()` to the end of the method with:

```kotlin
        webView.stopLoading()
        // The session's flag, not the config's: `keep` turns it off for a
        // throwaway saved as a site while its page is still open.
        val wipe = session.wipeOnExit
        // The profile this view used cannot be deleted until the next start
        // (see ProfileManager.wipe), and its HTTP cache has no profile-level
        // clear — the view is the only handle on it, so empty it now.
        if (wipe) webView.clearCache(true)
        webView.destroy()
        if (wipe) {
            // Off the throwaway journal only once the wipe has run: a wipe
            // that throws leaves it for the next start's sweep.
            wipeThenForget(config.profileId, throwaways) {
                deleteDownloadsDir(context, config.profileId)
                profiles.wipe(config.profileId)
            }
        }
    }
```

In `ContainerViewFactory.kt`, replace

```kotlin
            session = session,
```

with

```kotlin
            session = session,
            throwaways = engine.throwaways,
```

- [ ] **Step 7: The start sweep**

In `ProfileManager.kt`, add after `sweepPendingDeletions()`:

```kotlin
    /**
     * Wipes every throwaway that outlived its page — the app died with it
     * open, so `ContainerView.dispose` never ran (browser-chrome spec §5.4).
     * Like [sweepPendingDeletions] this runs before anything loads a profile,
     * so each [wipe] deletes outright. One whose wipe throws stays listed for
     * the next start. With nothing listed, WebView is not started at all.
     */
    fun sweepThrowaways(journal: ThrowawayJournal, deleteDownloads: (String) -> Unit) {
        if (journal.names().isEmpty()) return
        // A device that cannot isolate never created a profile to leak.
        if (!isAvailable()) {
            journal.clear()
            return
        }
        journal.sweep { profileId ->
            deleteDownloads(profileId)
            wipe(profileId)
        }
    }
```

In `MainActivity.kt`, add two imports beside the other `engine` imports:

```kotlin
import com.mono.container.engine.ThrowawayJournal
import com.mono.container.engine.deleteDownloadsDir
```

and replace

```kotlin
        // Before anything can load a profile: a loaded one cannot be deleted.
        profiles.sweepPendingDeletions()
        val engine = EngineChannel(applicationContext, profiles)
```

with

```kotlin
        val throwaways = ThrowawayJournal(java.io.File(applicationContext.filesDir, "throwaway-profiles"))
        // Before anything can load a profile: a loaded one cannot be deleted.
        profiles.sweepPendingDeletions()
        profiles.sweepThrowaways(throwaways) { deleteDownloadsDir(applicationContext, it) }
        val engine = EngineChannel(applicationContext, profiles, throwaways)
```

- [ ] **Step 8: Verify the Kotlin compiles and every check passes**

Run (from `android/`): `./gradlew :app:testDebugUnitTest` — Expected: PASS; Kotlin counts K0 + 21, 0 failures, 0 errors.
Run (from the repo root): `flutter build apk --debug 2>&1 | tee build/apk-build.log` then `grep -c '^e:' build/apk-build.log` — Expected: the APK builds, and `0`.
Run: `grep -rn "EngineChannel(applicationContext, profiles)" android/app/src/main` — Expected: no output.
Run: `flutter analyze` and `flutter test` — Expected: clean; all pass, D0 + 56.

- [ ] **Step 9: Commit**

```bash
git add android/app/src/main/kotlin android/app/src/test/kotlin/com/mono/container/engine/ThrowawayJournalTest.kt
git commit -m "feat: journal throwaway profiles so a crash cannot leak one"
```

---

### Task 8: Throwaway containers in the route stack

**Files:**
- Create: `lib/ui/features/container/view_models/throwaway_sites.dart`
- Modify: `lib/ui/features/container/views/container_route.dart` (constructor, `_engine`, `_open`, `dispose`)
- Test: `test/ui/features/container/throwaway_sites_test.dart` (new), `test/ui/features/container_route_test.dart` (5 added; `_pump` gains `throwaway` and `initialUrl`)

**Interfaces:**
- Consumes: Task 5's `open(site, throwaway:)` and `close`; `sessionProvider`, `SessionOpen`.
- Produces:
  - `class ThrowawaySites extends Notifier<List<Site>>` with `add(Site)`, `remove(String siteId)`; `final throwawaySitesProvider = NotifierProvider<ThrowawaySites, List<Site>>(…)` — emptied whenever the open database changes, which includes every transition out of `SessionOpen`.
  - `ContainerRoute({required Site site, String? initialUrl, bool throwaway = false})`: opens `site.copyWith(url: initialUrl)` when `initialUrl` is set (the stored site is never written), passes `throwaway` to `open`, and closes a throwaway's native session in `dispose`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/features/container/throwaway_sites_test.dart
import 'dart:typed_data';

import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/features/container/view_models/throwaway_sites.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../shell/session_controller_test.dart' show FakeBiometricService;

const _throwaway = Site(
  id: 't1', workspaceId: 'w', name: 'news.example.org', monogram: 'Nw',
  url: 'https://news.example.org', profileId: 'p-t1',
  cookiePolicy: CookiePolicy.wipeOnExit,
);

void main() {
  // SessionController.build starts a LifecycleController, which reaches for
  // WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  /// An open vault with one throwaway in it.
  Future<ProviderContainer> openVault() async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = ProviderContainer(overrides: [
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.a, database: database, dataKey: Uint8List(32))),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
    ]);
    addTearDown(container.dispose);
    container.read(throwawaySitesProvider.notifier).add(_throwaway);
    expect(container.read(throwawaySitesProvider), [_throwaway]);
    return container;
  }

  test('a 9b lock empties the list', () async {
    final container = await openVault();
    container.read(sessionProvider.notifier).debugHandleReturn(ReturnDestination.board);
    expect(container.read(throwawaySitesProvider), isEmpty);
  });

  test('a 9c lock empties the list', () async {
    final container = await openVault();
    container.read(sessionProvider.notifier).debugHandleReturn(ReturnDestination.pin);
    expect(container.read(throwawaySitesProvider), isEmpty);
  });

  test('panic empties the list', () async {
    final container = await openVault();
    container.read(sessionProvider.notifier).panicked(const PanicReport(sessionsDestroyed: 1));
    expect(container.read(throwawaySitesProvider), isEmpty);
  });

  test('the vault staying open keeps the list; removing one drops only it', () async {
    final container = await openVault();
    // A new SessionOpen on the same database, as turning biometrics on makes.
    container.read(sessionProvider.notifier).setBiometricWrapped(Uint8List.fromList([1, 2, 3]));
    expect(container.read(throwawaySitesProvider), [_throwaway]);

    const other = Site(
      id: 't2', workspaceId: 'w', name: 'elsewhere.example.net', monogram: 'Es',
      url: 'https://elsewhere.example.net', profileId: 'p-t2',
    );
    container.read(throwawaySitesProvider.notifier).add(other);
    container.read(throwawaySitesProvider.notifier).remove('t1');
    expect(container.read(throwawaySitesProvider), [other]);
  });
}
```

In `test/ui/features/container_route_test.dart`, replace the whole `_pump` function with:

```dart
Future<void> _pump(
  WidgetTester tester,
  FakeContainerEngine engine,
  Site site, {
  SiteRepository? sites,
  bool realExtras = false,
  List<Override> overrides = const [],
  bool overHome = false,
  bool throwaway = false,
  String? initialUrl,
}) async {
  // A modal bottom sheet is capped at 9/16 of the surface height, so the
  // default 800x600 canvas leaves HeldDownloadSheet ~294px where its fixed
  // column needs ~357px. Only the height is raised here: the container
  // screen's own rows need the default 800 width, and narrowing to a phone
  // width overflows all five of the older tests in this file.
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  final navigator = GlobalKey<NavigatorState>();
  Widget route() => ContainerRoute(site: site, initialUrl: initialUrl, throwaway: throwaway);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      if (sites != null) siteRepositoryProvider.overrideWithValue(sites),
      workspacesProvider.overrideWith((ref) async => const [_workspace]),
      if (!realExtras)
        engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
      ...overrides,
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      home: overHome ? const Scaffold(body: Text(_homeMarker)) : route(),
    ),
  ));
  // Pushed the way the dashboard pushes it, so a test can see whether leaving
  // the container lands back on what was underneath.
  if (overHome) {
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => route()));
  }
}
```

add below `_site()`:

```dart
Site _throwaway() => Site(
      id: 't1', workspaceId: 'w', name: 'news.example.org', monogram: 'Nw',
      url: 'https://news.example.org', profileId: 'c' * 32,
      cookiePolicy: CookiePolicy.wipeOnExit,
    );
```

and add at the end of `main()` (before `_drainSnackBar`, which sits outside `main`):

```dart
  testWidgets('a throwaway is opened as one', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true);
    await tester.pumpAndSettle();

    expect(engine.openedAsThrowaway, {'t1'});
  });

  testWidgets('a saved site opened at a typed address loads it, and saves nothing', (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _site(), sites: sites,
        initialUrl: 'https://forum.example.com/t/9');
    await tester.pumpAndSettle();

    expect(engine.openedSites['s1']!.url, 'https://forum.example.com/t/9');
    expect(engine.openedAsThrowaway, isEmpty);
    expect(sites.upserts, isEmpty);
  });

  testWidgets('leaving a throwaway closes its session', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true, overHome: true);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(ContainerRoute))).pop();
    await tester.pumpAndSettle();

    expect(engine.closed, ['t1']);
  });

  testWidgets('leaving a saved site leaves its session open', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true);
    await tester.pumpAndSettle();

    Navigator.of(tester.element(find.byType(ContainerRoute))).pop();
    await tester.pumpAndSettle();

    expect(engine.closed, isEmpty);
  });

  // Review Focus 4: a lock or panic disposes the open vault's navigator, and
  // every route in it, without popping anything.
  testWidgets('a throwaway torn down with its navigator is closed too', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());

    expect(engine.closed, ['t1']);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/ui/features/container/throwaway_sites_test.dart test/ui/features/container_route_test.dart`
Expected: FAIL — `throwaway_sites.dart` does not exist; `ContainerRoute` has no `initialUrl` or `throwaway`.

- [ ] **Step 3: Write `throwaway_sites.dart`**

```dart
// lib/ui/features/container/view_models/throwaway_sites.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/site.dart';
import '../../shell/view_models/session_controller.dart' show SessionOpen, sessionProvider;

/// The throwaway containers open in this vault (browser-chrome spec §5.1):
/// in memory only, never written to the vault until the user saves one.
///
/// [build] watches which database is open, so the list is rebuilt empty on
/// every transition out of `SessionOpen` — a `9b` or `9c` lock, panic — and
/// again on the next unlock. A throwaway from one vault can never be seen
/// from the other. A new `SessionOpen` on the same database (re-wrapping the
/// biometric key) keeps it.
class ThrowawaySites extends Notifier<List<Site>> {
  @override
  List<Site> build() {
    ref.watch(sessionProvider
        .select((session) => session is SessionOpen ? session.database : null));
    return const [];
  }

  void add(Site site) => state = [...state, site];

  void remove(String siteId) => state = [
        for (final site in state)
          if (site.id != siteId) site,
      ];
}

final throwawaySitesProvider =
    NotifierProvider<ThrowawaySites, List<Site>>(ThrowawaySites.new);
```

- [ ] **Step 4: `ContainerRoute` opens a typed address or a throwaway**

In `lib/ui/features/container/views/container_route.dart`:

1. Add the import:

```dart
import '../../../../data/services/container_engine.dart';
```

2. Replace

```dart
class ContainerRoute extends ConsumerStatefulWidget {
  const ContainerRoute({super.key, required this.site});

  final Site site;
```

with

```dart
class ContainerRoute extends ConsumerStatefulWidget {
  const ContainerRoute({
    super.key,
    required this.site,
    this.initialUrl,
    this.throwaway = false,
  });

  final Site site;

  /// Loaded instead of [site]'s stored address, for this session only — a
  /// saved site opened from the address bar (browser-chrome spec §5.2). The
  /// stored address never changes.
  final String? initialUrl;

  /// Opens [site] as a throwaway (spec §5): journaled natively so a crash
  /// cannot leak its profile, always wiped on exit, and closed when this
  /// route goes. Whoever pushes one adds it to `throwawaySitesProvider` first.
  final bool throwaway;
```

3. Replace

```dart
class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  bool _opened = false;
```

with

```dart
class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  /// Captured in [initState]: [dispose] may not read providers.
  late final ContainerEngine _engine;
  bool _opened = false;
```

4. Replace

```dart
    super.initState();
    final engine = ref.read(containerEngineProvider);
```

with

```dart
    super.initState();
    _engine = ref.read(containerEngineProvider);
    final engine = _engine;
```

5. In `_open`, replace

```dart
    final extras = await ref.read(engineExtrasBuilderProvider)(widget.site);
    if (!mounted) return;
    try {
      await ref.read(containerEngineProvider).open(widget.site, extras: extras);
    } finally {
```

with

```dart
    final initialUrl = widget.initialUrl;
    final site = initialUrl == null ? widget.site : widget.site.copyWith(url: initialUrl);
    final extras = await ref.read(engineExtrasBuilderProvider)(site);
    if (!mounted) return;
    try {
      await _engine.open(site, extras: extras, throwaway: widget.throwaway);
    } finally {
```

6. In `dispose`, replace

```dart
    _tunnelSub?.cancel();
    super.dispose();
```

with

```dart
    _tunnelSub?.cancel();
    // A throwaway never reopens. Closing its session disposes its page view
    // if Flutter has not already, and ContainerView.dispose wipes a
    // wipe-on-exit profile — popped, or torn down by a lock or panic.
    if (widget.throwaway) unawaited(_engine.close(widget.site.id));
    super.dispose();
```

- [ ] **Step 5: Run the tests and the gate**

Run: `flutter test test/ui/features/container/throwaway_sites_test.dart test/ui/features/container_route_test.dart`
Expected: PASS — 9 new tests (4 + 5) and every existing route test.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 65.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/container/view_models/throwaway_sites.dart lib/ui/features/container/views/container_route.dart test/ui/features/container/throwaway_sites_test.dart test/ui/features/container_route_test.dart
git commit -m "feat: open throwaway containers and typed addresses in their own route"
```

---

### Task 9: Saving a throwaway as a site

This task builds the save flow and reaches it through `6c`'s `Edit` — `2b`'s `☰` still opens `6c` until Task 12. Task 12 adds the save bar in front of the same `_saveAsSite`.

**Files:**
- Modify: `lib/ui/features/container/views/container_route.dart` (`_closeOnDispose`, `_isThrowaway`, `_openedUrl`, `_showSiteSheet`, new `_saveAsSite`)
- Test: `test/ui/features/container_route_test.dart` (4 added; `_pump` gains `throwaways`)

**Interfaces:**
- Consumes: Task 8's `throwawaySitesProvider` and `ContainerRoute(throwaway:)`; Task 5's `keep` and `navigationForSiteProvider`; `AddSiteScreen(initial:, workspaces:, onSave:)` (keeps `initial`'s `id` and `profileId`); `allSitesProvider`, `dashboardProvider`.
- Produces: `_ContainerRouteState._saveAsSite()` — used by Task 12's save bar. On save: `siteRepository.upsert(site)`, then `engine.keep(site.id)` unless the form picked `CookiePolicy.wipeOnExit`, then off `throwawaySitesProvider`; the route stops closing the session on dispose. `6c` on a throwaway: switches change only the running page's record; `Edit` runs the save flow; the subtitle shows the host alone.

- [ ] **Step 1: Write the failing tests**

In `test/ui/features/container_route_test.dart`:

1. Add the import:

```dart
import 'package:container/ui/features/container/view_models/throwaway_sites.dart';
```

2. Replace `_RecordingSiteRepository`'s first lines

```dart
class _RecordingSiteRepository implements SiteRepository {
  final upserts = <Site>[];

  @override
  Future<void> upsert(Site site) async => upserts.add(site);
```

with

```dart
class _RecordingSiteRepository implements SiteRepository {
  _RecordingSiteRepository({this.events});

  final upserts = <Site>[];

  /// Shared with [_LoggingEngine], so a test can pin the order of a save.
  final List<String>? events;

  @override
  Future<void> upsert(Site site) async {
    upserts.add(site);
    events?.add('upsert ${site.id}');
  }
```

3. Add below `_RecordingSiteRepository`:

```dart
/// Logs `keep` into the same list the repository logs its upserts to.
class _LoggingEngine extends FakeContainerEngine {
  _LoggingEngine(this.events);

  final List<String> events;

  @override
  Future<void> keep(String siteId) async {
    events.add('keep $siteId');
    await super.keep(siteId);
  }
}

/// The real registry empties itself on leaving `SessionOpen`, which needs a
/// session this file does not build.
class _Throwaways extends ThrowawaySites {
  _Throwaways(this.initial);

  final List<Site> initial;

  @override
  List<Site> build() => initial;
}

List<Site> _registry(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(throwawaySitesProvider);
```

4. In `_pump`, add the parameter `List<Site> throwaways = const [],` after `String? initialUrl,`, and the override `throwawaySitesProvider.overrideWith(() => _Throwaways(throwaways)),` after the `workspacesProvider` override.

5. Add at the end of `main()`:

```dart
  testWidgets("a throwaway's site sheet changes nothing in the vault", (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();
    // No workspace until it is saved.
    expect(find.text('news.example.org · Personal'), findsNothing);
    await tester.tap(find.byType(AppToggle).at(0)); // Force dark mode
    await tester.pumpAndSettle();

    expect(sites.upserts, isEmpty);
    expect(tester.widget<AppToggle>(find.byType(AppToggle).at(0)).value, isFalse);
  });

  testWidgets('Edit on a throwaway saves it: the row first, then its profile kept', (tester) async {
    final events = <String>[];
    final engine = _LoggingEngine(events);
    final sites = _RecordingSiteRepository(events: events);
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final form = tester.widget<AddSiteScreen>(find.byType(AddSiteScreen));
    expect(form.initial!.id, 't1');
    expect(form.initial!.profileId, 'c' * 32);
    expect(form.initial!.url, 'https://news.example.org');
    expect(form.initial!.cookiePolicy, CookiePolicy.keep);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(events, ['upsert t1', 'keep t1']);
    expect(_registry(tester), isEmpty);
  });

  // Saved, it is a site like any other: leaving it must not close — and so
  // wipe — the login just kept.
  testWidgets('a saved throwaway is not closed when left', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), sites: _RecordingSiteRepository(),
        throwaway: true, throwaways: [_throwaway()], overHome: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(ContainerRoute))).pop();
    await tester.pumpAndSettle();

    expect(engine.kept, ['t1']);
    expect(engine.closed, isEmpty);
  });

  testWidgets('saving with Wipe on exit picked keeps nothing', (tester) async {
    final events = <String>[];
    final engine = _LoggingEngine(events);
    final sites = _RecordingSiteRepository(events: events);
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('☰'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wipe on exit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(events, ['upsert t1']);
    expect(sites.upserts.single.cookiePolicy, CookiePolicy.wipeOnExit);
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/ui/features/container_route_test.dart`
Expected: FAIL — the first two new tests see an upsert and the ordinary edit form (no `keep`); the others follow.

- [ ] **Step 3: Track whether the site is still a throwaway**

In `container_route.dart`:

1. Add the imports:

```dart
import '../../search/view_models/providers.dart' show allSitesProvider;
import '../view_models/throwaway_sites.dart';
```

and replace the dashboard import's `show closeSite, siteRepositoryProvider, workspacesProvider;` with:

```dart
    show closeSite, dashboardProvider, siteRepositoryProvider, workspacesProvider;
```

2. Replace

```dart
  /// Captured in [initState]: [dispose] may not read providers.
  late final ContainerEngine _engine;
```

with

```dart
  /// Captured in [initState]: [dispose] may not read providers.
  late final ContainerEngine _engine;

  /// Whether leaving this route closes its native session: a throwaway's,
  /// until it is saved as a site. Kept here rather than read from
  /// `throwawaySitesProvider`, which whoever pushed this route empties while
  /// this route is still animating out.
  late bool _closeOnDispose = widget.throwaway;

  /// Whether this site is a throwaway right now: on `throwawaySitesProvider`,
  /// read at every build.
  bool _isThrowaway = false;
```

3. Below `String get _host => …;` add:

```dart
  /// What this container opened: the typed address, or the stored one.
  String get _openedUrl => widget.initialUrl ?? widget.site.url;
```

4. In `dispose`, replace `if (widget.throwaway) unawaited(_engine.close(widget.site.id));` with:

```dart
    if (_closeOnDispose) unawaited(_engine.close(widget.site.id));
```

5. In `build`, replace

```dart
    final sessionAsync = ref.watch(sessionForSiteProvider(widget.site.id));
```

with

```dart
    final sessionAsync = ref.watch(sessionForSiteProvider(widget.site.id));
    _isThrowaway = ref.watch(throwawaySitesProvider).any((site) => site.id == widget.site.id);
```

- [ ] **Step 4: `6c` on a throwaway, and the save flow**

Replace the whole `_showSiteSheet` method with:

```dart
  Future<void> _showSiteSheet(int blockedCount) async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    String? workspaceName;
    for (final workspace in workspaces) {
      if (workspace.id == _site.workspaceId) workspaceName = workspace.name;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // A throwaway is not written to the vault until it is saved (spec
          // §5.1). Its switches change only this page's record, which nothing
          // reads again: a throwaway never reopens.
          Future<void> save(Site updated) async {
            setState(() => _site = updated);
            setSheetState(() {});
            if (_isThrowaway) return;
            await ref.read(siteRepositoryProvider).upsert(updated);
          }

          final host = _site.host;
          return SiteSheet(
            monogram: _site.monogram,
            name: _site.name,
            // A throwaway belongs to no workspace until it is saved.
            subtitle: _isThrowaway || workspaceName == null ? host : '$host · $workspaceName',
            proxyDescriptor: _proxyDescriptor(_site),
            cookiesDescriptor: switch (_site.cookiePolicy) {
              CookiePolicy.keep => 'Keep for this site',
              CookiePolicy.wipeOnExit => 'Wipe on exit',
            },
            blockedCount: blockedCount,
            forceDark: _site.forceDark,
            desktopView: _site.userAgentMode == UserAgentMode.desktop,
            // Editing a throwaway means saving it.
            onEdit: () {
              Navigator.pop(sheetContext);
              if (_isThrowaway) {
                _saveAsSite();
              } else {
                _editSite();
              }
            },
            onForceDarkChanged: (value) => save(_site.copyWith(forceDark: value)),
            // The switch is binary, so turning it off lands on `android` — a
            // site that was `minimal` loses that once desktop view is flipped.
            onDesktopViewChanged: (value) => save(_site.copyWith(
              userAgentMode: value ? UserAgentMode.desktop : UserAgentMode.android,
            )),
            onCloseAndWipe: () async {
              Navigator.pop(sheetContext);
              closeSite(ref, widget.site.id);
              await _engine.close(widget.site.id);
              await _engine.wipe(widget.site.profileId);
              if (!mounted) return;
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
```

and add after `_editSite`:

```dart
  /// Spec §5.3. The form opens on the throwaway as it is now — the page it is
  /// showing, cookies kept — and keeps its id and profile id, so the saved
  /// site is this same container. The row is written first, then the native
  /// profile is kept: without `keep`, closing the page would wipe the login
  /// just saved. Picking "Wipe on exit" in the form skips `keep`. Anything
  /// else changed in the form applies the next time the site opens.
  Future<void> _saveAsSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final navigation = ref.read(navigationForSiteProvider(widget.site.id)).valueOrNull;
    final initial = _site.copyWith(
      url: navigation?.url ?? _openedUrl,
      cookiePolicy: CookiePolicy.keep,
    );
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => AddSiteScreen(
        initial: initial,
        workspaces: workspaces,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          if (site.cookiePolicy != CookiePolicy.wipeOnExit) await _engine.keep(site.id);
          if (!mounted) return;
          _closeOnDispose = false;
          ref.read(throwawaySitesProvider.notifier).remove(site.id);
          ref.invalidate(allSitesProvider);
          ref.invalidate(dashboardProvider);
          setState(() => _site = site);
          Navigator.pop(context);
        },
      ),
    ));
  }
```

- [ ] **Step 5: Run the tests and the gate**

Run: `flutter test test/ui/features/container_route_test.dart` — Expected: PASS, 4 new tests.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 69.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/container/views/container_route.dart test/ui/features/container_route_test.dart
git commit -m "feat: save a throwaway as a site, keeping its login"
```

---

### Task 10: The chrome's bars

Pure widgets, nothing wired yet: the load line, the panic square every bar shares, the bottom bar, the save bar and the find bar. Task 12 assembles them.

**Files:**
- Modify: `lib/ui/core/widgets/pill_button.dart` (optional `padding`)
- Create: `lib/ui/features/container/views/panic_square.dart`, `load_line.dart`, `container_bottom_bar.dart`, `throwaway_save_bar.dart`, `find_bar.dart`
- Test: `test/ui/features/container/chrome_bars_test.dart`

**Interfaces:**
- Consumes: Task 4's `AppIcon`, `AppGlyph`, `IconTap`; Task 5's `FindResult`; `PillButton`.
- Produces:
  - `PillButton` gains `EdgeInsetsGeometry? padding` (null — every existing call site — changes nothing)
  - `class PanicSquare extends StatelessWidget { const PanicSquare({required VoidCallback onTap}) }` — 32px, radius 9, label `Panic`
  - `class LoadLine extends StatelessWidget { const LoadLine({required bool loading, required int progress}) }` — always 2px tall; the fill (`Key('load-line')`, `C.textMuted`) only while `loading`
  - `class ContainerBottomBar extends StatelessWidget { const ContainerBottomBar({required int openCount, required VoidCallback? onBack, required VoidCallback? onForward, required VoidCallback onOpenSwitcher, required VoidCallback onMenu}) }` — a null `onBack`/`onForward` is dimmed and inert
  - `class ThrowawaySaveBar extends StatelessWidget { const ThrowawaySaveBar({required VoidCallback onSave, required VoidCallback onDismiss}) }` — the × is `Key('save-bar-dismiss')`, unlabelled (Design question 1)
  - `class FindBar extends StatelessWidget { const FindBar({required TextEditingController controller, required FindResult? result, required ValueChanged<String> onChanged, required VoidCallback onPrevious, required VoidCallback onNext, required VoidCallback onClose, required VoidCallback onPanic}) }` — shows `result` only while the field has text; the arrows are inert until a match is reported

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/features/container/chrome_bars_test.dart
import 'package:container/domain/models/find_result.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/features/container/views/container_bottom_bar.dart';
import 'package:container/ui/features/container/views/find_bar.dart';
import 'package:container/ui/features/container/views/load_line.dart';
import 'package:container/ui/features/container/views/panic_square.dart';
import 'package:container/ui/features/container/views/throwaway_save_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

AppIcon _glyph(WidgetTester tester, AppGlyph glyph) => tester.widget<AppIcon>(
    find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph));

Future<void> _pump(WidgetTester tester, Widget bar) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Column(children: [bar]))));

FindBar _findBar(
  TextEditingController controller,
  FindResult? result, {
  List<String>? calls,
}) =>
    FindBar(
      controller: controller,
      result: result,
      onChanged: (query) => calls?.add('find $query'),
      onPrevious: () => calls?.add('previous'),
      onNext: () => calls?.add('next'),
      onClose: () => calls?.add('close'),
      onPanic: () => calls?.add('panic'),
    );

void main() {
  testWidgets('the panic square is 32px of danger, labelled, and reports a tap', (tester) async {
    var taps = 0;
    await _pump(tester, PanicSquare(onTap: () => taps++));

    await tester.tap(_icon('Panic'));
    expect(taps, 1);
    expect(tester.getSize(_icon('Panic')), const Size(32, 32));
    expect(_glyph(tester, AppGlyph.panic).color, C.danger);
  });

  testWidgets('the load line fills to the progress while loading, and is empty otherwise', (tester) async {
    Widget line({required bool loading, required int progress}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: LoadLine(loading: loading, progress: progress),
            ),
          ),
        );

    await tester.pumpWidget(line(loading: true, progress: 40));
    expect(tester.getSize(find.byKey(const Key('load-line'))), const Size(120, 2));
    // Muted, not jade: jade means live state or the one affirmative action.
    expect(tester.widget<ColoredBox>(find.byKey(const Key('load-line'))).color, C.textMuted);

    await tester.pumpWidget(line(loading: false, progress: 100));
    expect(find.byKey(const Key('load-line')), findsNothing);
    // Still 2px tall, so a load starting or ending never moves the page.
    expect(tester.getSize(find.byType(LoadLine)), const Size(300, 2));
  });

  testWidgets('back and forward are dimmed and inert with no history that way', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      ContainerBottomBar(
        openCount: 3,
        onBack: null,
        onForward: () => calls.add('forward'),
        onOpenSwitcher: () => calls.add('switcher'),
        onMenu: () => calls.add('menu'),
      ),
    );

    await tester.tap(_icon('Back'), warnIfMissed: false);
    await tester.tap(_icon('Forward'));
    await tester.tap(find.text('3 OPEN'));
    await tester.tap(_icon('Menu'));

    expect(calls, ['forward', 'switcher', 'menu']);
    expect(_glyph(tester, AppGlyph.back).color, C.textDisabled);
    expect(_glyph(tester, AppGlyph.forward).color, C.icon);
    expect(tester.getSize(_icon('Back')), const Size(40, 40));
  });

  testWidgets('the bottom bar is flat footer with a hairline above, its pill named for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      ContainerBottomBar(
        openCount: 1,
        onBack: () {},
        onForward: () {},
        onOpenSwitcher: () {},
        onMenu: () {},
      ),
    );

    final bar = tester.widget<Container>(find
        .descendant(of: find.byType(ContainerBottomBar), matching: find.byType(Container))
        .first);
    final decoration = bar.decoration! as BoxDecoration;
    expect(decoration.color, C.footer);
    expect((decoration.border! as Border).top.color, C.line07);
    expect(find.text('▲'), findsOneWidget);
    expect(find.bySemanticsLabel('Open sessions'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the save bar offers saving and dismissing, and is neutral throughout', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      ThrowawaySaveBar(onSave: () => calls.add('save'), onDismiss: () => calls.add('dismiss')),
    );

    expect(find.text('Not saved · wiped when you close it'), findsOneWidget);
    await tester.tap(find.text('Save as a site'));
    await tester.tap(find.byKey(const Key('save-bar-dismiss')));

    expect(calls, ['save', 'dismiss']);
    expect(tester.widget<PillButton>(find.byType(PillButton)).tone, PillTone.neutral);
    final colours = tester
        .widgetList<Text>(find.descendant(of: find.byType(ThrowawaySaveBar), matching: find.byType(Text)))
        .map((text) => text.style?.color);
    expect(colours, isNot(contains(C.jade)));
  });

  testWidgets('the find count reads from one, says No matches, and waits for the page', (tester) async {
    final controller = TextEditingController(text: 'fox');
    addTearDown(controller.dispose);

    await _pump(tester, _findBar(controller, const FindResult(siteId: 's1', activeMatch: 1, matchCount: 7)));
    expect(find.text('2/7'), findsOneWidget);

    await _pump(tester, _findBar(controller, const FindResult(siteId: 's1', activeMatch: 0, matchCount: 0)));
    expect(find.text('No matches'), findsOneWidget);

    // No count yet for what is typed: nothing, rather than a stale one.
    await _pump(tester, _findBar(controller, null));
    expect(find.text('No matches'), findsNothing);

    // Nothing typed: nothing to count.
    controller.clear();
    await _pump(tester, _findBar(controller, const FindResult(siteId: 's1', activeMatch: 0, matchCount: 0)));
    await tester.pump();
    expect(find.text('No matches'), findsNothing);
    expect(find.text('Find in page'), findsOneWidget);
  });

  testWidgets('typing, stepping, closing and panic each report from the find bar', (tester) async {
    final calls = <String>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      _findBar(controller, const FindResult(siteId: 's1', activeMatch: 0, matchCount: 3), calls: calls),
    );

    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pump();
    await tester.tap(_icon('Previous match'));
    await tester.tap(_icon('Next match'));
    await tester.tap(_icon('Close find'));
    await tester.tap(_icon('Panic'));

    expect(calls, ['find fox', 'previous', 'next', 'close', 'panic']);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('with no match to step to, the arrows are dimmed and inert', (tester) async {
    final calls = <String>[];
    final controller = TextEditingController(text: 'zebra');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      _findBar(controller, const FindResult(siteId: 's1', activeMatch: 0, matchCount: 0), calls: calls),
    );

    await tester.tap(_icon('Previous match'), warnIfMissed: false);
    await tester.tap(_icon('Next match'), warnIfMissed: false);

    expect(calls, isEmpty);
    expect(_glyph(tester, AppGlyph.chevronUp).color, C.textDisabled);
    expect(_glyph(tester, AppGlyph.chevronDown).color, C.textDisabled);
  });

  testWidgets('the find field asks the keyboard not to learn what is typed', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, _findBar(controller, null));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.cursorColor, C.textPrimary);
  });

  // Review Focus 5.
  testWidgets('every bar fits a 360-wide phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'a query longer than the field');
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            _findBar(controller, const FindResult(siteId: 's1', activeMatch: 0, matchCount: 0)),
            const Spacer(),
            ThrowawaySaveBar(onSave: () {}, onDismiss: () {}),
            ContainerBottomBar(
              openCount: 12,
              onBack: () {},
              onForward: () {},
              onOpenSwitcher: () {},
              onMenu: () {},
            ),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ui/features/container/chrome_bars_test.dart`
Expected: FAIL — the five `container/views/…` files do not exist.

- [ ] **Step 3: `PillButton` can pad its label**

A pill in a row, as the save bar's is, sizes to its label with nothing around it. In `lib/ui/core/widgets/pill_button.dart`:

1. Replace

```dart
    this.height = 48,
    this.radius,
  });
```

with

```dart
    this.height = 48,
    this.radius,
    this.padding,
  });
```

2. Replace

```dart
  final double height;
  final double? radius;
```

with

```dart
  final double height;
  final double? radius;

  /// Around the label, inside the pill. Null, the default, changes nothing:
  /// a full-width pill is as wide as its parent makes it. A pill in a row
  /// sizes to its label and needs this to breathe.
  final EdgeInsetsGeometry? padding;
```

3. Replace

```dart
        child: Container(
          height: height,
          decoration: BoxDecoration(borderRadius: r, border: border),
```

with

```dart
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(borderRadius: r, border: border),
```

- [ ] **Step 4: Write `panic_square.dart` and `load_line.dart`**

```dart
// lib/ui/features/container/views/panic_square.dart
import 'package:flutter/widgets.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/widgets/icon_tap.dart';

/// `2b`'s 32px panic square, drawn with the `panic` line icon. On every bar
/// the container shows — the top bar, the address field, the find bar — so
/// panic is never more than one tap away and never behind a menu.
class PanicSquare extends StatelessWidget {
  const PanicSquare({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconTap(
      glyph: AppGlyph.panic,
      label: 'Panic',
      onTap: onTap,
      size: 32,
      iconSize: 16,
      color: C.danger,
      background: C.danger.withValues(alpha: 0.14),
      radius: 9,
    );
  }
}
```

```dart
// lib/ui/features/container/views/load_line.dart
import 'package:flutter/widgets.dart';

import '../../../core/tokens.dart';

/// Browser-chrome spec §6.1: 2px under the top bar's hairline, drawn only
/// while the page loads, filled to its progress. `C.textMuted`, not jade:
/// jade is for live state and the one affirmative action.
///
/// Always 2px tall, drawn or not, and laid over the top edge of the page by
/// `ContainerScreen` rather than above it, so a load starting or ending
/// never moves or resizes the page.
class LoadLine extends StatelessWidget {
  const LoadLine({super.key, required this.loading, required this.progress});

  final bool loading;

  /// 0–100.
  final int progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: loading
          ? FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0, 100) / 100,
              child: const ColoredBox(key: Key('load-line'), color: C.textMuted),
            )
          : null,
    );
  }
}
```

- [ ] **Step 5: Write `container_bottom_bar.dart`**

```dart
// lib/ui/features/container/views/container_bottom_bar.dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';

/// Browser-chrome spec §6.1's bottom bar, replacing `2b`'s floating pill: a
/// flat `C.footer` bar with a hairline above. Back and forward are 40px
/// round targets, dimmed and inert with no history that way (§3.3). The
/// centre `N OPEN ▲` pill keeps `2b`'s style and opens the `2c` switcher;
/// ☰ opens the menu (§6.4).
class ContainerBottomBar extends StatelessWidget {
  const ContainerBottomBar({
    super.key,
    required this.openCount,
    required this.onBack,
    required this.onForward,
    required this.onOpenSwitcher,
    required this.onMenu,
  });

  final int openCount;

  /// Null when the page cannot go back.
  final VoidCallback? onBack;

  /// Null when the page cannot go forward.
  final VoidCallback? onForward;
  final VoidCallback onOpenSwitcher;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: const BoxDecoration(
        color: C.footer,
        border: Border(top: BorderSide(color: C.line07)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconTap(glyph: AppGlyph.back, label: 'Back', onTap: onBack),
          IconTap(glyph: AppGlyph.forward, label: 'Forward', onTap: onForward),
          Semantics(
            label: 'Open sessions',
            button: true,
            excludeSemantics: true,
            onTap: onOpenSwitcher,
            child: GestureDetector(
              onTap: onOpenSwitcher,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: C.selected,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$openCount OPEN',
                        style: ui(size: 11, weight: 500, color: C.textSecondary)),
                    const SizedBox(width: 7),
                    Text('▲', style: ui(size: 9, color: C.jade)),
                  ],
                ),
              ),
            ),
          ),
          IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: onMenu),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Write `throwaway_save_bar.dart`**

```dart
// lib/ui/features/container/views/throwaway_save_bar.dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../../core/widgets/pill_button.dart';

/// Browser-chrome spec §5.3/§6.3: offered in a throwaway once its first load
/// has finished, directly above the bottom bar. Neutral throughout — jade
/// stays on the live dot; saving is not this screen's affirmative action.
///
/// The hairline below it is the bottom bar's own, not a second one.
class ThrowawaySaveBar extends StatelessWidget {
  const ThrowawaySaveBar({super.key, required this.onSave, required this.onDismiss});

  final VoidCallback onSave;

  /// Hides the bar for this throwaway.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        color: C.raised,
        border: Border(top: BorderSide(color: C.line07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Not saved · wiped when you close it',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ui(size: 12, color: C.textMuted),
            ),
          ),
          const SizedBox(width: 10),
          PillButton(
            label: 'Save as a site',
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onTap: onSave,
          ),
          const SizedBox(width: 2),
          // Unlabelled: spec §7's screen-reader list has no name for this ×
          // (see the plan's Design questions).
          IconTap(
            key: const Key('save-bar-dismiss'),
            glyph: AppGlyph.close,
            label: null,
            onTap: onDismiss,
            size: 36,
            iconSize: 16,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Write `find_bar.dart`**

```dart
// lib/ui/features/container/views/find_bar.dart
import 'package:flutter/material.dart';

import '../../../../domain/models/find_result.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.5: stands in for the top bar while finding in the
/// page. Panic keeps its place on the right, as on every bar.
class FindBar extends StatelessWidget {
  const FindBar({
    super.key,
    required this.controller,
    required this.result,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    required this.onPanic,
  });

  final TextEditingController controller;

  /// The page's count for what is typed, or null until it arrives.
  final FindResult? result;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onPanic;

  /// `<active>/<total>`, counting from one (WebView counts from zero), or
  /// `No matches`.
  static String? _count(FindResult? found) {
    if (found == null) return null;
    if (found.matchCount == 0) return 'No matches';
    return '${found.activeMatch + 1}/${found.matchCount}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line07)),
      ),
      // Follows the field itself, so the count and the arrows are right on
      // the keystroke, before anything above rebuilds.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final found = value.text.isEmpty ? null : result;
          final count = _count(found);
          final canStep = (found?.matchCount ?? 0) > 0;
          return Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.raised,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: C.line16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          onChanged: onChanged,
                          cursorColor: C.textPrimary,
                          style: ui(size: 13, color: C.textPrimary),
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          enableIMEPersonalizedLearning: false,
                          decoration: InputDecoration.collapsed(
                            hintText: 'Find in page',
                            hintStyle: ui(size: 13, color: C.textFaint),
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 8),
                        Text(count, style: mono(size: 10.5, color: C.textMuted)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconTap(
                glyph: AppGlyph.chevronUp,
                label: 'Previous match',
                onTap: canStep ? onPrevious : null,
                size: 32,
                iconSize: 18,
              ),
              IconTap(
                glyph: AppGlyph.chevronDown,
                label: 'Next match',
                onTap: canStep ? onNext : null,
                size: 32,
                iconSize: 18,
              ),
              IconTap(
                glyph: AppGlyph.close,
                label: 'Close find',
                onTap: onClose,
                size: 32,
                iconSize: 16,
              ),
              const SizedBox(width: 4),
              PanicSquare(onTap: onPanic),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 8: Run the tests and the gate**

Run: `flutter test test/ui/features/container/chrome_bars_test.dart` — Expected: PASS, 10 tests.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 79.

- [ ] **Step 9: Commit**

```bash
git add lib/ui/core/widgets/pill_button.dart lib/ui/features/container/views/panic_square.dart lib/ui/features/container/views/load_line.dart lib/ui/features/container/views/container_bottom_bar.dart lib/ui/features/container/views/throwaway_save_bar.dart lib/ui/features/container/views/find_bar.dart test/ui/features/container/chrome_bars_test.dart
git commit -m "feat: build the container's load line, bottom bar, save bar and find bar"
```

---

### Task 11: The address field, its suggestions, and the ☰ menu

Three more pure widgets. Task 12 shows the menu; Task 13 shows the address field and its suggestions.

**Files:**
- Create: `lib/ui/features/container/views/address_edit_bar.dart`, `address_suggestions.dart`, `browser_menu_sheet.dart`
- Test: `test/ui/features/container/address_and_menu_test.dart`

**Interfaces:**
- Consumes: Task 2's `AddressSuggestion`, `SuggestionKind`, `suggestionsFor` (tests); Task 10's `PanicSquare`; Task 4's `AppIcon`, `IconTap`; `Monogram`, `BottomSheetSurface`.
- Produces:
  - `class AddressEditBar extends StatelessWidget { const AddressEditBar({required TextEditingController controller, required ValueChanged<String> onChanged, required ValueChanged<String> onSubmitted, required VoidCallback onPanic}) }` — its × clears the field and reports `onChanged('')`
  - `class AddressSuggestions extends StatelessWidget { const AddressSuggestions({required List<AddressSuggestion> suggestions, required ValueChanged<AddressSuggestion> onPick, required VoidCallback onDismiss}) }` — a tap anywhere but a row is `onDismiss`
  - `class BrowserMenuSheet extends StatelessWidget { const BrowserMenuSheet({required String monogram, required String name, required String subtitle, required int blockedToday, required VoidCallback onReload, onFind, onReader, onCopyLink, onToday, onScripts, onWorkspaces, onSettings, onAllSites}) }` — pure; whoever shows it closes it before acting

- [ ] **Step 1: Write the failing tests**

```dart
// test/ui/features/container/address_and_menu_test.dart
import 'package:container/domain/models/address_suggestion.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/container/views/address_edit_bar.dart';
import 'package:container/ui/features/container/views/address_suggestions.dart';
import 'package:container/ui/features/container/views/browser_menu_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

const _personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

const _forum = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
  proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
);
const _market = Site(
  id: 'market', workspaceId: 'w1', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'p2',
);

/// What Task 2 suggests for [text], typed in the SOCKS5 forum's container.
List<AddressSuggestion> _rows(String text) => suggestionsFor(
      text: text,
      current: _forum,
      saved: const [_forum, _market],
      workspaces: const [_personal],
      engine: SearchEngine.duckDuckGo,
    );

Widget _bar(
  TextEditingController controller, {
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  VoidCallback? onPanic,
}) =>
    AddressEditBar(
      controller: controller,
      onChanged: onChanged ?? (_) {},
      onSubmitted: onSubmitted ?? (_) {},
      onPanic: onPanic ?? () {},
    );

Widget _menu(List<String> calls, {String subtitle = 'forum.example.com · Personal'}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: BrowserMenuSheet(
            monogram: 'Fr',
            name: 'Forum',
            subtitle: subtitle,
            blockedToday: 312,
            onReload: () => calls.add('reload'),
            onFind: () => calls.add('find'),
            onReader: () => calls.add('reader'),
            onCopyLink: () => calls.add('copy link'),
            onToday: () => calls.add('today'),
            onScripts: () => calls.add('scripts'),
            onWorkspaces: () => calls.add('workspaces'),
            onSettings: () => calls.add('settings'),
            onAllSites: () => calls.add('all sites'),
          ),
        ),
      ),
    );

const _menuLabels = [
  'Reload', 'Find', 'Reader', 'Copy link',
  'Today', 'Scripts and filters', 'Workspaces', 'Settings', 'All sites',
];

void main() {
  testWidgets('the address field is raised, hinted, and asks the keyboard to learn nothing', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [_bar(controller)]))));

    expect(find.text('Search or type an address'), findsOneWidget);
    final pill = tester.widget<Container>(
        find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);
    final decoration = pill.decoration! as BoxDecoration;
    expect(decoration.color, C.raised);
    expect((decoration.border! as Border).top.color, C.line16);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.cursorColor, C.textPrimary);
    expect(field.keyboardType, TextInputType.url);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(_icon('Panic'), findsOneWidget);
  });

  testWidgets('typing, the keyboard action, clearing and panic each report', (tester) async {
    final calls = <String>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          _bar(
            controller,
            onChanged: (text) => calls.add('changed $text'),
            onSubmitted: (text) => calls.add('submitted $text'),
            onPanic: () => calls.add('panic'),
          ),
        ]),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'news.example.org');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    await tester.tap(_icon('Clear'));
    await tester.pump();
    await tester.tap(_icon('Panic'));

    expect(calls, [
      'changed news.example.org',
      'submitted news.example.org',
      'changed ',
      'panic',
    ]);
    expect(controller.text, isEmpty);
  });

  testWidgets('rows sit under their sections, each with where it opens, above the footer', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressSuggestions(
          suggestions: _rows('market.example.com'),
          onPick: (_) {},
          onDismiss: () {},
        ),
      ),
    ));

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('SAVED SITES'), lessThan(top('Marketplace')));
    expect(top('Marketplace'), lessThan(top('ADDRESS')));
    expect(top('ADDRESS'), lessThan(top('SEARCH')));
    expect(top('SEARCH'), lessThan(top('Nothing is fetched while you type.')));

    expect(find.text('Mk'), findsOneWidget);
    expect(find.text('market.example.com · Personal'), findsOneWidget);
    expect(find.text('not saved'), findsOneWidget);
    expect(find.text('Search DuckDuckGo for “market.example.com”'), findsOneWidget);
    // The saved row and the address row both open the market's container;
    // the search opens a throwaway on the forum's SOCKS5 route.
    expect(find.text('ITS OWN CONTAINER'), findsNWidgets(2));
    expect(find.text('THROWAWAY · SOCKS5'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.glyph == AppGlyph.globe), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.glyph == AppGlyph.search), findsOneWidget);
  });

  testWidgets('tapping a row picks it; tapping anywhere else dismisses', (tester) async {
    final picked = <AddressSuggestion>[];
    var dismissed = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressSuggestions(
          suggestions: _rows('mark'),
          onPick: picked.add,
          onDismiss: () => dismissed++,
        ),
      ),
    ));

    await tester.tap(find.text('Marketplace'));
    expect(picked.single.destination, isA<SavedSiteContainer>());
    expect(dismissed, 0);

    await tester.tapAt(
        tester.getBottomLeft(find.byType(AddressSuggestions)) + const Offset(40, -40));
    expect(dismissed, 1);
    expect(picked, hasLength(1));
  });

  testWidgets('with nothing typed, only the footer shows, in dim mono', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AddressSuggestions(suggestions: _rows('   '), onPick: (_) {}, onDismiss: () {}),
      ),
    ));

    expect(find.text('SEARCH'), findsNothing);
    final footer = tester.widget<Text>(find.text('Nothing is fetched while you type.'));
    expect(footer.style!.fontFamily, 'IBMPlexMono');
    expect(footer.style!.color, C.textDim);
  });

  testWidgets('the menu shows this site, four quick actions in a row, then five rows', (tester) async {
    await tester.pumpWidget(_menu([]));

    expect(find.text('Fr'), findsOneWidget);
    expect(find.text('Forum'), findsOneWidget);
    final subtitle = tester.widget<Text>(find.text('forum.example.com · Personal'));
    expect(subtitle.style!.fontFamily, 'IBMPlexMono');
    for (final label in _menuLabels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('312 BLOCKED'), findsOneWidget);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Reload'), top('Copy link'));
    expect(top('Copy link'), lessThan(top('Today')));
    expect(top('Today'), lessThan(top('Scripts and filters')));
    expect(top('Settings'), lessThan(top('All sites')));
  });

  testWidgets('every quick action and row reports its own tap', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_menu(calls));

    for (final label in _menuLabels) {
      await tester.tap(find.text(label));
    }

    expect(calls, [
      'reload', 'find', 'reader', 'copy link',
      'today', 'scripts', 'workspaces', 'settings', 'all sites',
    ]);
  });

  // Review Focus 5.
  testWidgets('at 360 wide the address bar, its suggestions and the menu all fit', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(
        text: 'market.example.com/a/rather/long/path?with=a&query=string');
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          _bar(controller),
          Expanded(
            child: AddressSuggestions(
              suggestions: _rows(controller.text),
              onPick: (_) {},
              onDismiss: () {},
            ),
          ),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_menu(
      [],
      subtitle: 'a-rather-long-subdomain.forum.example.com · A long workspace name',
    ));
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/ui/features/container/address_and_menu_test.dart`
Expected: FAIL — the three `container/views/…` files do not exist.

- [ ] **Step 3: Write `address_edit_bar.dart`**

```dart
// lib/ui/features/container/views/address_edit_bar.dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.2: the top bar's pill as a text field while an
/// address is typed. The same bar — 12/8 padding, a 34px pill, panic on the
/// right — with the pill raised (`C.raised`, a `C.line16` border) and a ×
/// that clears it. The cursor is `C.textPrimary`, not jade.
///
/// Whoever shows it fills and selects [controller] first: the field takes
/// focus as it is built.
class AddressEditBar extends StatelessWidget {
  const AddressEditBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onPanic,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// The keyboard's action.
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPanic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.only(left: 12, right: 3),
              decoration: BoxDecoration(
                color: C.raised,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: C.line16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      cursorColor: C.textPrimary,
                      style: ui(size: 13, color: C.textPrimary),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      // Typed addresses stay out of the keyboard app's
                      // dictionary and suggestion strip.
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search or type an address',
                        hintStyle: ui(size: 13, color: C.textFaint),
                      ),
                    ),
                  ),
                  IconTap(
                    glyph: AppGlyph.close,
                    label: 'Clear',
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    size: 28,
                    iconSize: 14,
                    color: C.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PanicSquare(onTap: onPanic),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write `address_suggestions.dart`**

```dart
// lib/ui/features/container/views/address_suggestions.dart
import 'package:flutter/material.dart';

import '../../../../domain/models/address_suggestion.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';

/// Browser-chrome spec §6.2: under the address field while typing, over the
/// page and the bottom bar. Only what the open vault already holds — nothing
/// is fetched while typing — and every row's tag says where it opens before
/// it is tapped. A tap anywhere but a row leaves editing.
class AddressSuggestions extends StatelessWidget {
  const AddressSuggestions({
    super.key,
    required this.suggestions,
    required this.onPick,
    required this.onDismiss,
  });

  /// In `suggestionsFor`'s order, which is the order the sections show in.
  final List<AddressSuggestion> suggestions;
  final ValueChanged<AddressSuggestion> onPick;
  final VoidCallback onDismiss;

  static String _section(SuggestionKind kind) => switch (kind) {
        SuggestionKind.savedSite => 'SAVED SITES',
        SuggestionKind.address => 'ADDRESS',
        SuggestionKind.search => 'SEARCH',
      };

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    SuggestionKind? section;
    for (final suggestion in suggestions) {
      if (suggestion.kind != section) {
        section = suggestion.kind;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(_section(suggestion.kind), style: T.sectionLabel),
        ));
      }
      children.add(_SuggestionRow(suggestion, onTap: () => onPick(suggestion)));
    }
    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Text('Nothing is fetched while you type.',
          style: mono(size: 10, color: C.textDim)),
    ));

    return ColoredBox(
      color: C.bg,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: ListView(padding: EdgeInsets.zero, children: children),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow(this.suggestion, {required this.onTap});

  final AddressSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final monogram = suggestion.monogram;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line06)),
        ),
        child: Row(
          children: [
            if (monogram != null)
              Monogram(monogram, size: 32, radius: 9, fontSize: 12)
            else
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.button,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: AppIcon(
                  suggestion.kind == SuggestionKind.address ? AppGlyph.globe : AppGlyph.search,
                  size: 15,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    suggestion.primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui(size: 13.5, color: C.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    suggestion.secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(size: 10, color: C.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Narrow, so a long tag wraps onto a second line (`THROWAWAY` /
            // `· SOCKS5`) instead of squeezing the row.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                suggestion.tag,
                textAlign: TextAlign.right,
                style: mono(size: 9.5, color: C.textMuted, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write `browser_menu_sheet.dart`**

```dart
// lib/ui/features/container/views/browser_menu_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/sheet.dart';

/// Browser-chrome spec §6.4: the ☰ sheet, in `2c`/`6c`'s sheet style. Four
/// quick actions on this page, then screens that are also reachable from the
/// dashboard, here as shortcuts. Project 3 adds security level and New
/// identity to it.
///
/// Pure: whoever shows it closes it before acting on a tap, so a screen it
/// opens lands above the container rather than above the sheet.
class BrowserMenuSheet extends StatelessWidget {
  const BrowserMenuSheet({
    super.key,
    required this.monogram,
    required this.name,
    required this.subtitle,
    required this.blockedToday,
    required this.onReload,
    required this.onFind,
    required this.onReader,
    required this.onCopyLink,
    required this.onToday,
    required this.onScripts,
    required this.onWorkspaces,
    required this.onSettings,
    required this.onAllSites,
  });

  final String monogram;
  final String name;

  /// `host · Workspace` in mono; a throwaway's host alone.
  final String subtitle;

  /// Today's total, shown as `<n> BLOCKED` on the `Today` row.
  final int blockedToday;

  final VoidCallback onReload;
  final VoidCallback onFind;
  final VoidCallback onReader;
  final VoidCallback onCopyLink;
  final VoidCallback onToday;
  final VoidCallback onScripts;
  final VoidCallback onWorkspaces;
  final VoidCallback onSettings;
  final VoidCallback onAllSites;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.line06)),
          ),
          child: Row(
            children: [
              Monogram(monogram),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ui(size: 15, weight: 600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mono(size: 10.5, color: C.textFaint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.line06)),
          ),
          child: Row(
            children: [
              Expanded(child: _Tile(glyph: AppGlyph.reload, label: 'Reload', onTap: onReload)),
              Expanded(child: _Tile(glyph: AppGlyph.find, label: 'Find', onTap: onFind)),
              Expanded(child: _Tile(glyph: AppGlyph.reader, label: 'Reader', onTap: onReader)),
              Expanded(child: _Tile(glyph: AppGlyph.link, label: 'Copy link', onTap: onCopyLink)),
            ],
          ),
        ),
        _MenuRow(label: 'Today', meta: '$blockedToday BLOCKED', onTap: onToday),
        _MenuRow(label: 'Scripts and filters', onTap: onScripts),
        _MenuRow(label: 'Workspaces', onTap: onWorkspaces),
        _MenuRow(label: 'Settings', onTap: onSettings),
        _MenuRow(label: 'All sites', onTap: onAllSites, divider: false),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.glyph, required this.label, required this.onTap});

  final AppGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.button,
              borderRadius: BorderRadius.circular(13),
            ),
            child: AppIcon(glyph),
          ),
          const SizedBox(height: 7),
          Text(label,
              textAlign: TextAlign.center,
              style: ui(size: 11, color: C.textTertiary)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap, this.meta, this.divider = true});

  final String label;
  final VoidCallback onTap;

  /// Mono text in place of the chevron: `Today`'s blocked count.
  final String? meta;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final meta = this.meta;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: divider
            ? const BoxDecoration(border: Border(bottom: BorderSide(color: C.line05)))
            : null,
        child: Row(
          children: [
            Expanded(child: Text(label, style: ui(size: 14, color: C.textPrimary))),
            if (meta != null)
              Text(meta, style: mono(size: 10.5, color: C.textFaint))
            else
              const AppIcon(AppGlyph.forward, size: 14, color: C.textFaint),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the tests and the gate**

Run: `flutter test test/ui/features/container/address_and_menu_test.dart` — Expected: PASS, 8 tests.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 87.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/features/container/views/address_edit_bar.dart lib/ui/features/container/views/address_suggestions.dart lib/ui/features/container/views/browser_menu_sheet.dart test/ui/features/container/address_and_menu_test.dart
git commit -m "feat: build the address field, its suggestions and the browser menu"
```

---

### Task 12: Layout C

`2b` becomes layout C: the new top bar, the load line, the bottom bar, the ☰ menu, the find bar, the save bar, and system back, all driven by the page's navigation. Typing an address is Task 13; the pill does not react to a tap until then.

**Files:**
- Modify (whole file): `lib/ui/features/container/views/container_top_bar.dart`, `lib/ui/features/container/views/container_screen.dart`, `lib/ui/features/container/views/container_route.dart`
- Delete: `lib/ui/features/container/views/container_toolbar.dart`
- Modify (whole file): `test/ui/features/container_screen_test.dart` — its five `2b` tests are replaced by 14. Two of the five pinned removed chrome: `the back button reports a tap` tapped the top bar's `‹`, which spec §6.1 removes (back is on the bottom bar, and system back); `the panic square reports a tap` found panic by its `◉` text, which is now a drawn icon. Both behaviours are still tested, the new way. The other three carry over.
- Modify: `test/ui/features/container_route_test.dart` — `_pump` gains `size` and a `siteLookupProvider` override; the nine `find.text('☰')` taps become the shield (`2b`'s ☰ opened `6c`; the shield does now, spec §6.1) and the two `find.text('◑')` taps go through ☰ → `Reader` (`2b`'s ◑ is gone, spec §7); 11 tests added.

**Interfaces:**
- Consumes: Tasks 10–11's widgets; Task 5's `navigationForSiteProvider`, `findResults`, in-page controls; Task 9's `_saveAsSite` and `_isThrowaway`; Task 3's `SettingsRoute`; `leakCountProvider`, `TodayRoute`, `ScriptsRoute`, `WorkspacesRoute`.
- Produces:
  - `ContainerTopBar({required String host, required String routeLabel, required bool live, required bool loading, required VoidCallback onStop, required VoidCallback onSiteDetails, required VoidCallback onPanic})`
  - `ContainerScreen` (now stateful): `host`, `routeLabel`, `live`, `NavigationState? navigation`, `openCount`, `body`, `entries`, `workspaceName`, `siteMonogram`, `siteName`, `siteSubtitle`, `int blockedToday`, `FindResult? findResult`, `bool showSaveBar`; callbacks `onBack`, `onForward`, `onStop`, `onReload`, `onPanic`, `onSiteDetails`, `onReader`, `onCopyLink`, `onToday`, `onScripts`, `onWorkspaces`, `onSettings`, `onAllSites`, `ValueChanged<String> onFind`, `ValueChanged<bool> onFindNext` (true is forward), `onClearFind`, `onSaveAsSite`, `onDismissSaveBar`, `onCloseSession`, `onCloseAllAndWipe`. Owns which bar shows and the find text; `PopScope` leaves find, then goes back in the page, then lets the route pop.
  - `ContainerRoute`: the save bar shows for a throwaway after its first finished load until saved or dismissed; ☰ rows push `TodayRoute`, `ScriptsRoute`, `WorkspacesRoute`, `SettingsRoute` on the vault's navigator; `All sites` pops to the first route; Copy link writes the page's URL to the clipboard and shows `Link copied`.

- [ ] **Step 1: Rewrite the screen test**

Replace `test/ui/features/container_screen_test.dart` with:

```dart
import 'package:container/domain/models/find_result.dart';
import 'package:container/domain/models/navigation_state.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/container/views/browser_menu_sheet.dart';
import 'package:container/ui/features/container/views/container_bottom_bar.dart';
import 'package:container/ui/features/container/views/container_screen.dart';
import 'package:container/ui/features/container/views/container_top_bar.dart';
import 'package:container/ui/features/container/views/find_bar.dart';
import 'package:container/ui/features/container/views/switcher_sheet.dart';
import 'package:container/ui/features/container/views/throwaway_save_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every callback [ContainerScreen] made, by name, in order.
final _calls = <String>[];

Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

/// Stands in for the native page view: a State that must outlive every change
/// of chrome, as the WebView must — rebuilding it disposes the WebView.
class _Page extends StatefulWidget {
  const _Page();

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  Widget build(BuildContext context) => const ColoredBox(color: Color(0xFFF4F2EC));
}

NavigationState _nav({
  String url = 'https://forum.example.com/t/9',
  bool canGoBack = false,
  bool canGoForward = false,
  bool loading = false,
  int progress = 0,
}) =>
    NavigationState(
      siteId: 's1',
      url: url,
      canGoBack: canGoBack,
      canGoForward: canGoForward,
      loading: loading,
      progress: progress,
    );

ContainerScreen _screen({
  String host = 'forum.example.com',
  String routeLabel = 'SOCKS5',
  NavigationState? navigation,
  FindResult? findResult,
  bool showSaveBar = false,
}) =>
    ContainerScreen(
      host: host,
      routeLabel: routeLabel,
      live: true,
      navigation: navigation,
      openCount: 3,
      body: const _Page(),
      entries: const [
        SwitcherEntry(
          siteId: 's1',
          name: 'Forum',
          monogram: 'Fr',
          meta: 'viewing now · socks5',
          live: true,
        ),
      ],
      workspaceName: 'Personal',
      siteMonogram: 'Fr',
      siteName: 'Forum',
      siteSubtitle: 'forum.example.com · Personal',
      blockedToday: 312,
      findResult: findResult,
      showSaveBar: showSaveBar,
      onBack: () => _calls.add('back'),
      onForward: () => _calls.add('forward'),
      onStop: () => _calls.add('stop'),
      onReload: () => _calls.add('reload'),
      onPanic: () => _calls.add('panic'),
      onSiteDetails: () => _calls.add('site details'),
      onReader: () => _calls.add('reader'),
      onCopyLink: () => _calls.add('copy link'),
      onToday: () => _calls.add('today'),
      onScripts: () => _calls.add('scripts'),
      onWorkspaces: () => _calls.add('workspaces'),
      onSettings: () => _calls.add('settings'),
      onAllSites: () => _calls.add('all sites'),
      onFind: (query) => _calls.add('find $query'),
      onFindNext: (forward) => _calls.add(forward ? 'next' : 'previous'),
      onClearFind: () => _calls.add('clear find'),
      onSaveAsSite: () => _calls.add('save as a site'),
      onDismissSaveBar: () => _calls.add('dismiss save bar'),
      onCloseSession: (siteId) => _calls.add('close $siteId'),
      onCloseAllAndWipe: () => _calls.add('close all and wipe'),
    );

Widget _app(Widget screen) => MaterialApp(home: screen);

/// What the platform sends for a system back gesture.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

Future<void> _openFind(WidgetTester tester) async {
  await tester.tap(_icon('Menu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Find'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(_calls.clear);

  testWidgets('shows the host, the route label and the open count', (tester) async {
    await tester.pumpWidget(_app(_screen()));

    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(find.text('3 OPEN'), findsOneWidget);
  });

  testWidgets('a direct site shows no route label', (tester) async {
    await tester.pumpWidget(_app(_screen(routeLabel: '')));

    expect(find.text('SOCKS5'), findsNothing);
  });

  testWidgets("the pill ends in the shield, which opens the site's details; panic sits beside it", (tester) async {
    await tester.pumpWidget(_app(_screen()));

    expect(tester.getCenter(_icon('Site details')).dx,
        greaterThan(tester.getCenter(find.text('SOCKS5')).dx));
    expect(tester.getCenter(_icon('Panic')).dx,
        greaterThan(tester.getCenter(_icon('Site details')).dx));
    await tester.tap(_icon('Site details'));
    await tester.tap(_icon('Panic'));

    expect(_calls, ['site details', 'panic']);
    // 2b's ‹ and ⟳ have left the top bar.
    expect(find.text('‹'), findsNothing);
    expect(find.text('⟳'), findsNothing);
  });

  testWidgets('stop sits before the shield only while the page loads', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav())));
    expect(_icon('Stop'), findsNothing);

    await tester.pumpWidget(_app(_screen(navigation: _nav(loading: true, progress: 30))));
    expect(tester.getCenter(_icon('Stop')).dx,
        lessThan(tester.getCenter(_icon('Site details')).dx));
    await tester.tap(_icon('Stop'));

    expect(_calls, ['stop']);
  });

  testWidgets('the load line lies over the top of the page, only while it loads', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav(loading: true, progress: 50))));

    final line = tester.getRect(find.byKey(const Key('load-line')));
    final page = tester.getRect(find.byType(_Page));
    expect(line.top, page.top);
    expect(line.width, page.width / 2);

    await tester.pumpWidget(_app(_screen(navigation: _nav(progress: 100))));
    expect(find.byKey(const Key('load-line')), findsNothing);
  });

  testWidgets('back and forward follow the page history', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await tester.tap(_icon('Back'), warnIfMissed: false);
    await tester.tap(_icon('Forward'), warnIfMissed: false);
    expect(_calls, isEmpty);

    await tester.pumpWidget(_app(_screen(navigation: _nav(canGoBack: true, canGoForward: true))));
    await tester.tap(_icon('Back'));
    await tester.tap(_icon('Forward'));

    expect(_calls, ['back', 'forward']);
  });

  testWidgets('tapping the open-count pill opens the switcher sheet', (tester) async {
    await tester.pumpWidget(_app(_screen()));

    await tester.tap(find.text('3 OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('1 OPEN SESSIONS'), findsOneWidget);
    expect(find.text('viewing now · socks5'), findsOneWidget);
  });

  testWidgets('the ☰ menu names this site, and closes itself before each action it reports', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('312 BLOCKED'), findsOneWidget);
    Navigator.of(tester.element(find.byType(BrowserMenuSheet))).pop();
    await tester.pumpAndSettle();

    const actions = [
      ('Reload', 'reload'),
      ('Reader', 'reader'),
      ('Copy link', 'copy link'),
      ('Today', 'today'),
      ('Scripts and filters', 'scripts'),
      ('Workspaces', 'workspaces'),
      ('Settings', 'settings'),
      ('All sites', 'all sites'),
    ];
    for (final (label, call) in actions) {
      await tester.tap(_icon('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(BrowserMenuSheet), findsNothing, reason: label);
      expect(_calls.last, call);
    }
    expect(_calls, hasLength(actions.length));
  });

  testWidgets('Find puts the find bar in place of the top bar; typing, stepping and closing report', (tester) async {
    await tester.pumpWidget(_app(_screen(
      findResult: const FindResult(siteId: 's1', activeMatch: 2, matchCount: 5),
    )));
    await _openFind(tester);

    expect(find.byType(ContainerTopBar), findsNothing);
    expect(find.text('Find in page'), findsOneWidget);
    expect(_icon('Panic'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pump();
    expect(find.text('3/5'), findsOneWidget);
    await tester.tap(_icon('Previous match'));
    await tester.tap(_icon('Next match'));
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();

    expect(_calls, ['find fox', 'previous', 'next', 'clear find']);
    expect(find.byType(FindBar), findsNothing);
    expect(find.byType(ContainerTopBar), findsOneWidget);
  });

  testWidgets('system back goes back in the page while it can, then leaves', (tester) async {
    final navigation = ValueNotifier<NavigationState?>(_nav(canGoBack: true));
    addTearDown(navigation.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Text('home')));
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => ValueListenableBuilder<NavigationState?>(
        valueListenable: navigation,
        builder: (_, value, __) => _screen(navigation: value),
      ),
    ));
    await tester.pumpAndSettle();

    await _systemBack(tester);
    expect(_calls, ['back']);
    expect(find.byType(ContainerScreen), findsOneWidget);

    navigation.value = _nav();
    await tester.pumpAndSettle();
    await _systemBack(tester);

    expect(_calls, ['back']);
    expect(find.byType(ContainerScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  // Review Focus 2.
  testWidgets('system back while finding closes find, and goes nowhere', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav(canGoBack: true))));
    await _openFind(tester);

    await _systemBack(tester);

    expect(find.byType(FindBar), findsNothing);
    expect(find.byType(ContainerTopBar), findsOneWidget);
    expect(_calls, ['clear find']);
  });

  testWidgets('the save bar shows only when asked, directly above the bottom bar', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    expect(find.byType(ThrowawaySaveBar), findsNothing);

    await tester.pumpWidget(_app(_screen(showSaveBar: true)));
    expect(tester.getRect(find.byType(ThrowawaySaveBar)).bottom,
        tester.getRect(find.byType(ContainerBottomBar)).top);
    await tester.tap(find.text('Save as a site'));
    await tester.tap(find.byKey(const Key('save-bar-dismiss')));

    expect(_calls, ['save as a site', 'dismiss save bar']);
  });

  // Review Focus 1.
  testWidgets('the page view is never rebuilt as the chrome changes', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    final page = tester.state(find.byType(_Page));

    await tester.pumpWidget(_app(_screen(
      navigation: _nav(loading: true, progress: 30, canGoBack: true),
    )));
    await tester.pumpWidget(_app(_screen(
      navigation: _nav(loading: true, progress: 30, canGoBack: true),
      showSaveBar: true,
    )));
    await _openFind(tester);
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(_screen()));

    expect(tester.state(find.byType(_Page)), same(page));
  });

  // Review Focus 5.
  testWidgets('at 360 wide a long host, a route, a load and the save bar all fit', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_screen(
      host: 'a-rather-long-subdomain.forum.example.com',
      navigation: _nav(loading: true, progress: 40, canGoBack: true, canGoForward: true),
      showSaveBar: true,
    )));
    expect(tester.takeException(), isNull);

    await _openFind(tester);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Update the route test**

In `test/ui/features/container_route_test.dart`:

1. Add these imports, keeping the list sorted:

```dart
import 'package:container/domain/models/find_result.dart';
import 'package:container/domain/models/navigation_state.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/container/views/find_bar.dart';
import 'package:container/ui/features/container/views/throwaway_save_bar.dart';
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart'
    show siteLookupProvider;
import 'package:container/ui/features/report/views/today_route.dart';
import 'package:container/ui/features/scripts/views/scripts_route.dart';
import 'package:container/ui/features/settings/views/settings_route.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show biometricServiceProvider;
import 'package:container/ui/features/workspaces/views/workspaces_route.dart';
```

and, beside the existing `bundled_filter_lists_test.dart` import:

```dart
import 'shell/session_controller_test.dart' show FakeBiometricService;
```

2. Add below `_registry` (Task 9):

```dart
Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

/// What the platform sends for a system back gesture.
Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Lets real database IO finish, then rebuilds.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

/// Answers `flutter/platform_views` for a test that lets real async work run;
/// the first test in this file explains why an unanswered create is fatal.
void _standInForPlatformViews(WidgetTester tester) {
  const platformViews = MethodChannel('flutter/platform_views');
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(platformViews, (call) async => null);
  addTearDown(() =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(platformViews, null));
}
```

3. Replace the whole `_pump` function with:

```dart
Future<void> _pump(
  WidgetTester tester,
  FakeContainerEngine engine,
  Site site, {
  SiteRepository? sites,
  bool realExtras = false,
  List<Override> overrides = const [],
  bool overHome = false,
  bool throwaway = false,
  String? initialUrl,
  List<Site> throwaways = const [],
  Size size = const Size(800, 1600),
}) async {
  // A modal bottom sheet is capped at 9/16 of the surface height, so the
  // default 800x600 canvas leaves HeldDownloadSheet ~294px where its fixed
  // column needs ~357px: hence the tall default. A test about a phone
  // passes [size].
  addTearDown(tester.view.reset);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final navigator = GlobalKey<NavigatorState>();
  Widget route() => ContainerRoute(site: site, initialUrl: initialUrl, throwaway: throwaway);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      if (sites != null) siteRepositoryProvider.overrideWithValue(sites),
      workspacesProvider.overrideWith((ref) async => const [_workspace]),
      throwawaySitesProvider.overrideWith(() => _Throwaways(throwaways)),
      // Today's tally, which the ☰ menu shows, looks each session's site up
      // in the vault. These tests have no vault.
      siteLookupProvider.overrideWithValue((_) async => null),
      if (!realExtras)
        engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
      ...overrides,
    ],
    child: MaterialApp(
      navigatorKey: navigator,
      home: overHome ? const Scaffold(body: Text(_homeMarker)) : route(),
    ),
  ));
  // Pushed the way the dashboard pushes it, so a test can see whether leaving
  // the container lands back on what was underneath.
  if (overHome) {
    navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => route()));
  }
}
```

4. Replace every `await tester.tap(find.text('☰'));` — five in the existing tests, four in Task 9's — with:

```dart
    await tester.tap(_icon('Site details'));
```

5. In both reader-mode tests, replace

```dart
    await tester.tap(find.text('◑'));
```

with

```dart
    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reader'));
```

6. Add at the end of `main()`:

```dart
  testWidgets('the pill follows the page, falling back to the site when the page has no host', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    expect(find.text('forum.example.com'), findsOneWidget);
    // There is no DIRECT label; the route used to pass one.
    expect(find.text('DIRECT'), findsNothing);

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://elsewhere.example.net/a'));
    await tester.pumpAndSettle();
    expect(find.text('elsewhere.example.net'), findsOneWidget);

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'about:blank'));
    await tester.pumpAndSettle();
    expect(find.text('forum.example.com'), findsOneWidget);
  });

  testWidgets("back, forward and stop act on this container's page", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    await tester.tap(_icon('Back'), warnIfMissed: false);
    expect(engine.wentBack, isEmpty);
    expect(_icon('Stop'), findsNothing);

    engine.emitNavigation(const NavigationState(
      siteId: 's1', url: 'https://forum.example.com/t/9',
      canGoBack: true, canGoForward: true, loading: true, progress: 50,
    ));
    await tester.pumpAndSettle();
    await tester.tap(_icon('Back'));
    await tester.tap(_icon('Forward'));
    await tester.tap(_icon('Stop'));

    expect(engine.wentBack, ['s1']);
    expect(engine.wentForward, ['s1']);
    expect(engine.stopped, ['s1']);
  });

  testWidgets('system back goes back in the page first, then leaves the container', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true);
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 's1', url: 'https://forum.example.com/t/9', canGoBack: true));
    await tester.pumpAndSettle();

    await _systemBack(tester);
    expect(engine.wentBack, ['s1']);
    expect(find.byType(ContainerRoute), findsOneWidget);

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/'));
    await tester.pumpAndSettle();
    await _systemBack(tester);

    expect(find.byType(ContainerRoute), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
    // A saved site's session stays open in the background, as before.
    expect(engine.closed, isEmpty);
  });

  testWidgets("the menu's rows open their screens over this container, and All sites leaves it", (tester) async {
    sqfliteFfiInit();
    final database = (await tester.runAsync(
        () => AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)))!;
    addTearDown(() => tester.runAsync(database.close));
    _standInForPlatformViews(tester);
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true, overrides: [
      databaseProvider.overrideWithValue(database),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
    ]);
    await tester.pumpAndSettle();

    for (final (row, screen) in [
      ('Today', TodayRoute),
      ('Scripts and filters', ScriptsRoute),
      ('Workspaces', WorkspacesRoute),
      ('Settings', SettingsRoute),
    ]) {
      await tester.tap(_icon('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(row));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byType(screen), findsOneWidget, reason: row);

      Navigator.of(tester.element(find.byType(screen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ContainerRoute), findsOneWidget, reason: row);
    }

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All sites'));
    await tester.pumpAndSettle();

    expect(find.byType(ContainerRoute), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
  });

  testWidgets('Copy link copies the page address, and says so', (tester) async {
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map<Object?, Object?>)['text']);
      }
      return null;
    });
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/t/9'));
    await tester.pumpAndSettle();

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();

    expect(copied, ['https://forum.example.com/t/9']);
    expect(find.text('Link copied'), findsOneWidget);
  });

  testWidgets("find in page searches this page, shows this page's count, and clears on close", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();
    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pump();
    expect(engine.findQueries, [(siteId: 's1', query: 'fox')]);

    engine.emitFindResult(const FindResult(siteId: 's1', activeMatch: 0, matchCount: 4));
    engine.emitFindResult(const FindResult(siteId: 'other', activeMatch: 0, matchCount: 9));
    await tester.pumpAndSettle();
    expect(find.text('1/4'), findsOneWidget);

    await tester.tap(_icon('Next match'));
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();

    expect(engine.findSteps, [(siteId: 's1', forward: true)]);
    expect(engine.clearedFind, ['s1']);
    expect(find.byType(FindBar), findsNothing);
  });

  testWidgets('a throwaway offers the save bar after its first finished load; saving writes the row, then keeps it', (tester) async {
    final events = <String>[];
    final engine = _LoggingEngine(events);
    final sites = _RecordingSiteRepository(events: events);
    await _pump(tester, engine, _throwaway(), sites: sites,
        throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();

    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: 'https://news.example.org/', loading: true, progress: 30));
    await tester.pumpAndSettle();
    expect(find.byType(ThrowawaySaveBar), findsNothing);

    engine.emitNavigation(const NavigationState(siteId: 't1', url: 'https://news.example.org/today'));
    await tester.pumpAndSettle();
    expect(find.text('Not saved · wiped when you close it'), findsOneWidget);

    await tester.tap(find.text('Save as a site'));
    await tester.pumpAndSettle();
    expect(tester.widget<AddSiteScreen>(find.byType(AddSiteScreen)).initial!.url,
        'https://news.example.org/today');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(events, ['upsert t1', 'keep t1']);
    expect(find.byType(ThrowawaySaveBar), findsNothing);
  });

  testWidgets('a saved site never shows the save bar', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitNavigation(const NavigationState(siteId: 's1', url: 'https://forum.example.com/'));
    await tester.pumpAndSettle();

    expect(find.byType(ThrowawaySaveBar), findsNothing);
  });

  testWidgets('dismissing the save bar hides it for this throwaway', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(siteId: 't1', url: 'https://news.example.org/'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-bar-dismiss')));
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(siteId: 't1', url: 'https://news.example.org/next'));
    await tester.pumpAndSettle();

    expect(find.byType(ThrowawaySaveBar), findsNothing);
  });

  // Review Focus 5.
  testWidgets('at 360 wide a throwaway with a long host, a route, a load and the save bar fits, and so do its menu and find bar', (tester) async {
    const url = 'https://a-rather-long-subdomain-for-a-phone.news.example.org';
    final engine = FakeContainerEngine();
    final site = _throwaway().copyWith(
      url: url, proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
    );
    await _pump(tester, engine, site, throwaway: true, throwaways: [site]);
    await tester.pumpAndSettle();
    // Phone width once live: this is about the container's chrome. `8a`'s
    // checklist, shown for the first frames, is outside this plan.
    tester.view.physicalSize = const Size(360, 740);
    await tester.pump();
    engine.emitNavigation(const NavigationState(siteId: 't1', url: '$url/'));
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: '$url/today', loading: true, progress: 40));
    await tester.pumpAndSettle();

    expect(find.byType(ThrowawaySaveBar), findsOneWidget);
    expect(_icon('Stop'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    expect(find.byType(FindBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Review Focus 1: rebuilding the page view disposes the native WebView,
  // which wipes a throwaway.
  testWidgets('the page view outlives every change of chrome', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _throwaway(), throwaway: true, throwaways: [_throwaway()]);
    await tester.pumpAndSettle();
    final page = tester.state(find.byType(PlatformViewLink));

    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: 'https://news.example.org/', loading: true, progress: 20));
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 't1', url: 'https://news.example.org/', canGoBack: true));
    await tester.pumpAndSettle();
    expect(find.byType(ThrowawaySaveBar), findsOneWidget);
    await tester.tap(_icon('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find'));
    await tester.pumpAndSettle();
    await tester.tap(_icon('Close find'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-bar-dismiss')));
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(PlatformViewLink)), same(page));
    expect(engine.closed, isEmpty);
  });
```

- [ ] **Step 3: Run to verify they fail**

Run: `flutter test test/ui/features/container_screen_test.dart test/ui/features/container_route_test.dart`
Expected: FAIL — compile errors: `ContainerScreen` has none of the new parameters, and the route shows no shield or menu icon.

- [ ] **Step 4: Rewrite `container_top_bar.dart`**

Replace `lib/ui/features/container/views/container_top_bar.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.1's top bar (layout C). Keeps `2b`'s 12/8 padding,
/// 34px pill, 6px dot and 32px panic square; `2b`'s ‹ and ⟳ are gone — back
/// is on the bottom bar, reload in the ☰ menu. The pill ends in the shield,
/// which opens `6c`, and while the page loads a stop × sits just before it.
/// Panic is always here, never behind a menu.
class ContainerTopBar extends StatelessWidget {
  const ContainerTopBar({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.loading,
    required this.onStop,
    required this.onSiteDetails,
    required this.onPanic,
  });

  /// The page's host: after following a link, the other site's.
  final String host;

  /// `site.proxyMode.name.toUpperCase()` for a proxied site, empty for a
  /// direct one. The caller computes this — there is no "DIRECT" label; the
  /// spec never shows one.
  final String routeLabel;

  /// Jade while the tunnel is up; amber while the container is still opening.
  final bool live;

  /// Shows the stop ×.
  final bool loading;

  final VoidCallback onStop;

  /// The shield: `6c`.
  final VoidCallback onSiteDetails;
  final VoidCallback onPanic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.only(left: 12, right: 3),
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: C.line08),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: live ? C.jade : C.warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ui(size: 11.5, color: const Color(0xFFA9B0AE)),
                    ),
                  ),
                  if (routeLabel.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(routeLabel,
                        style: ui(size: 9.5, weight: 500, color: C.textFaint)),
                    const SizedBox(width: 2),
                  ],
                  if (loading)
                    IconTap(
                      glyph: AppGlyph.stop,
                      label: 'Stop',
                      onTap: onStop,
                      size: 28,
                      iconSize: 14,
                    ),
                  IconTap(
                    glyph: AppGlyph.shield,
                    label: 'Site details',
                    onTap: onSiteDetails,
                    size: 28,
                    iconSize: 15,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PanicSquare(onTap: onPanic),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite `container_screen.dart`**

Replace `lib/ui/features/container/views/container_screen.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/find_result.dart';
import '../../../../domain/models/navigation_state.dart';
import '../../../core/tokens.dart';
import 'browser_menu_sheet.dart';
import 'container_bottom_bar.dart';
import 'container_top_bar.dart';
import 'find_bar.dart';
import 'load_line.dart';
import 'switcher_sheet.dart';
import 'throwaway_save_bar.dart';

/// Which bar sits above the page.
enum _Chrome { page, find }

/// The container (browser-chrome spec §6, layout C, which supersedes `2b`):
/// the top bar or the find bar, the page, a throwaway's save bar, and the
/// bottom bar, with the `2c` switcher and the ☰ menu as sheets.
///
/// Owns only which chrome shows. What the page does, and every screen the
/// chrome opens, belongs to the route, through the callbacks.
///
/// **[body] never moves in the tree.** Rebuilding the page view disposes the
/// native WebView, which wipes a throwaway and reloads anything else. So the
/// bar above the page is swapped within one slot, and everything that comes
/// and goes around the page is laid out after it.
class ContainerScreen extends StatefulWidget {
  const ContainerScreen({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.navigation,
    required this.openCount,
    required this.body,
    required this.entries,
    required this.workspaceName,
    required this.siteMonogram,
    required this.siteName,
    required this.siteSubtitle,
    required this.blockedToday,
    required this.findResult,
    required this.showSaveBar,
    required this.onBack,
    required this.onForward,
    required this.onStop,
    required this.onReload,
    required this.onPanic,
    required this.onSiteDetails,
    required this.onReader,
    required this.onCopyLink,
    required this.onToday,
    required this.onScripts,
    required this.onWorkspaces,
    required this.onSettings,
    required this.onAllSites,
    required this.onFind,
    required this.onFindNext,
    required this.onClearFind,
    required this.onSaveAsSite,
    required this.onDismissSaveBar,
    required this.onCloseSession,
    required this.onCloseAllAndWipe,
  });

  /// The page's host, for the pill.
  final String host;

  /// `SOCKS5`, `HTTP`, or empty for a direct site — see [ContainerTopBar].
  final String routeLabel;
  final bool live;

  /// What the page is doing, or null before its first report.
  final NavigationState? navigation;
  final int openCount;

  /// The page itself: the native WebView platform view on a device.
  final Widget body;

  final List<SwitcherEntry> entries;
  final String workspaceName;

  /// The ☰ menu's header (spec §6.4).
  final String siteMonogram;
  final String siteName;
  final String siteSubtitle;

  /// Today's blocked total, for the menu's `Today` row.
  final int blockedToday;

  /// The page's count for what the find bar holds; null until it reports.
  final FindResult? findResult;

  /// A throwaway's save bar (spec §5.3), directly above the bottom bar.
  final bool showSaveBar;

  /// Back in the page: the bottom bar's back, and system back while the page
  /// can go back.
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onStop;
  final VoidCallback onReload;
  final VoidCallback onPanic;

  /// The shield: `6c`.
  final VoidCallback onSiteDetails;
  final VoidCallback onReader;
  final VoidCallback onCopyLink;
  final VoidCallback onToday;
  final VoidCallback onScripts;
  final VoidCallback onWorkspaces;
  final VoidCallback onSettings;
  final VoidCallback onAllSites;

  /// The find bar's text on every change — empty once it is cleared.
  final ValueChanged<String> onFind;

  /// True steps forward.
  final ValueChanged<bool> onFindNext;

  /// Find closed.
  final VoidCallback onClearFind;
  final VoidCallback onSaveAsSite;
  final VoidCallback onDismissSaveBar;
  final void Function(String siteId) onCloseSession;
  final VoidCallback onCloseAllAndWipe;

  @override
  State<ContainerScreen> createState() => _ContainerScreenState();
}

class _ContainerScreenState extends State<ContainerScreen> {
  _Chrome _chrome = _Chrome.page;
  final _findText = TextEditingController();

  @override
  void dispose() {
    _findText.dispose();
    super.dispose();
  }

  void _startFind() {
    _findText.clear();
    setState(() => _chrome = _Chrome.find);
  }

  void _closeFind() {
    widget.onClearFind();
    setState(() => _chrome = _Chrome.page);
  }

  /// System back that [PopScope] kept from popping the route: out of find
  /// first, then back in the page (spec §3.3). The route pops only once
  /// neither applies.
  void _handleBack() {
    switch (_chrome) {
      case _Chrome.find:
        _closeFind();
      case _Chrome.page:
        if (widget.navigation?.canGoBack ?? false) widget.onBack();
    }
  }

  /// The two close actions dismiss the sheet by its own context before
  /// reporting, so a caller that then pops its route pops the route and not
  /// this sheet on top of it. Panic is passed through untouched: it replaces
  /// the whole open vault, sheet included.
  void _openSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (sheetContext) => SwitcherSheet(
        entries: widget.entries,
        workspaceName: widget.workspaceName,
        onCloseSession: (siteId) {
          Navigator.pop(sheetContext);
          widget.onCloseSession(siteId);
        },
        onCloseAllAndWipe: () {
          Navigator.pop(sheetContext);
          widget.onCloseAllAndWipe();
        },
        onPanic: widget.onPanic,
      ),
    );
  }

  /// Spec §6.4. Every entry closes the sheet by its own context before it
  /// acts, so a screen it opens lands above this container, not the sheet.
  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      // Taller than a modal sheet's default cap of 9/16 of a small phone.
      isScrollControlled: true,
      builder: (sheetContext) {
        VoidCallback closing(VoidCallback action) => () {
              Navigator.pop(sheetContext);
              action();
            };
        return BrowserMenuSheet(
          monogram: widget.siteMonogram,
          name: widget.siteName,
          subtitle: widget.siteSubtitle,
          blockedToday: widget.blockedToday,
          onReload: closing(widget.onReload),
          onFind: closing(_startFind),
          onReader: closing(widget.onReader),
          onCopyLink: closing(widget.onCopyLink),
          onToday: closing(widget.onToday),
          onScripts: closing(widget.onScripts),
          onWorkspaces: closing(widget.onWorkspaces),
          onSettings: closing(widget.onSettings),
          onAllSites: closing(widget.onAllSites),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navigation = widget.navigation;
    final canGoBack = navigation?.canGoBack ?? false;
    final canGoForward = navigation?.canGoForward ?? false;
    final loading = navigation?.loading ?? false;

    return PopScope(
      canPop: _chrome == _Chrome.page && !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              switch (_chrome) {
                _Chrome.page => ContainerTopBar(
                    host: widget.host,
                    routeLabel: widget.routeLabel,
                    live: widget.live,
                    loading: loading,
                    onStop: widget.onStop,
                    onSiteDetails: widget.onSiteDetails,
                    onPanic: widget.onPanic,
                  ),
                _Chrome.find => FindBar(
                    controller: _findText,
                    result: widget.findResult,
                    onChanged: widget.onFind,
                    onPrevious: () => widget.onFindNext(false),
                    onNext: () => widget.onFindNext(true),
                    onClose: _closeFind,
                    onPanic: widget.onPanic,
                  ),
              },
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: widget.body),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: LoadLine(
                          loading: loading,
                          progress: navigation?.progress ?? 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.showSaveBar)
                ThrowawaySaveBar(
                  onSave: widget.onSaveAsSite,
                  onDismiss: widget.onDismissSaveBar,
                ),
              ContainerBottomBar(
                openCount: widget.openCount,
                onBack: canGoBack ? widget.onBack : null,
                onForward: canGoForward ? widget.onForward : null,
                onOpenSwitcher: _openSwitcher,
                onMenu: _openMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Delete `2b`'s floating toolbar**

Run: `git rm lib/ui/features/container/views/container_toolbar.dart`

- [ ] **Step 7: Rewrite `container_route.dart`**

Replace `lib/ui/features/container/views/container_route.dart` with the version below. Against Task 9's file it: imports `flutter/services.dart`, `find_result.dart`, `workspace.dart`, `leakCountProvider` and the four ☰ destinations; adds `_loadedOnce`, `_saveBarDismissed`, `_findResult` and `_findSub`; adds `_find`, `_clearFind`, `_copyLink`, `_push` and `_menuSubtitle`; uses `_engine` everywhere it read `containerEngineProvider` before; and passes the new `ContainerScreen` parameters. Everything else — Task 8's open and dispose, Task 9's site sheet and save flow, the permission, download, reader, refusal and tunnel handling — is unchanged.

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/container_engine.dart';
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/find_result.dart';
import '../../../../domain/models/open_step.dart';
import '../../../../domain/models/route_failure_copy.dart';
import '../../../../domain/models/route_decision.dart' show refusalMessage;
import '../../../../domain/models/site.dart';
import '../../../../domain/models/workspace.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../dashboard/view_models/providers.dart'
    show
        closeSite,
        dashboardProvider,
        leakCountProvider,
        siteRepositoryProvider,
        workspacesProvider;
import '../../in_page/views/held_download_sheet.dart';
import '../../in_page/views/permission_request_sheet.dart';
import '../../in_page/views/proxy_unreachable_screen.dart';
import '../../in_page/views/reader_screen.dart';
import '../../in_page/views/site_sheet.dart';
import '../../in_page/views/tunnel_dropped_screen.dart';
import '../../report/views/today_route.dart';
import '../../scripts/views/scripts_route.dart';
import '../../search/view_models/providers.dart' show allSitesProvider;
import '../../settings/views/settings_route.dart';
import '../../workspaces/views/workspaces_route.dart';
import '../view_models/providers.dart';
import '../view_models/throwaway_sites.dart';
import 'container_screen.dart';
import 'container_web_view.dart';
import 'opening_screen.dart';
import 'switcher_sheet.dart';

/// One push per site tap — and, since browser-chrome spec §5.2, one per
/// saved site or throwaway opened from the address bar, pushed over the
/// container it was typed in, on the open vault's navigator. Owns the
/// `opening -> live -> refused` lifecycle against [ContainerEngine]
/// internally, rather than issuing a second navigation event when the
/// session finishes connecting — see Plan 6's design spec §2 for why a
/// `pushReplacement` was rejected.
class ContainerRoute extends ConsumerStatefulWidget {
  const ContainerRoute({
    super.key,
    required this.site,
    this.initialUrl,
    this.throwaway = false,
  });

  final Site site;

  /// Loaded instead of [site]'s stored address, for this session only — a
  /// saved site opened from the address bar (browser-chrome spec §5.2). The
  /// stored address never changes.
  final String? initialUrl;

  /// Opens [site] as a throwaway (spec §5): journaled natively so a crash
  /// cannot leak its profile, always wiped on exit, and closed when this
  /// route goes. Whoever pushes one adds it to `throwawaySitesProvider` first.
  final bool throwaway;

  @override
  ConsumerState<ContainerRoute> createState() => _ContainerRouteState();
}

class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  /// Captured in [initState]: [dispose] may not read providers.
  late final ContainerEngine _engine;

  /// Whether leaving this route closes its native session: a throwaway's,
  /// until it is saved as a site. Kept here rather than read from
  /// `throwawaySitesProvider`, which whoever pushed this route empties while
  /// this route is still animating out.
  late bool _closeOnDispose = widget.throwaway;

  /// Whether this site is a throwaway right now: on `throwawaySitesProvider`,
  /// read at every build.
  bool _isThrowaway = false;
  bool _opened = false;

  /// Whether this route's own `open` has returned. Until then, any session
  /// the site has is the one a previous visit left open, registered with the
  /// settings it had then — and the native view factory binds to whatever
  /// session exists when the view is created. Building the page view early
  /// would load it under those old settings (a site switched to a proxy went
  /// out direct) and leave this route waiting on a new session that the view
  /// never reports `live` to.
  bool _openReturned = false;
  bool _refusalHandled = false;
  bool _tunnelDropped = false;

  /// Whether the page has finished a load since this route opened. A
  /// throwaway's save bar waits for it (spec §5.3).
  bool _loadedOnce = false;
  bool _saveBarDismissed = false;

  /// The page's count for what the find bar holds; null until it reports.
  FindResult? _findResult;
  StreamSubscription<PendingPermissionRequest>? _permissionSub;
  StreamSubscription<HeldDownloadEvent>? _downloadSub;
  StreamSubscription<DownloadResult>? _downloadResultSub;
  StreamSubscription<TunnelDroppedEvent>? _tunnelSub;
  StreamSubscription<FindResult>? _findSub;
  final _myDownloadRequestIds = <String>{};

  /// The site as last saved from this route. Starts as [ContainerRoute.site]
  /// and moves on with every change made from the site sheet, so a second
  /// change is saved on top of the first rather than over it. The open
  /// session itself keeps running under the settings it was opened with —
  /// the engine has no call to re-apply them to a live view, so a change
  /// takes effect the next time this site is opened.
  late Site _site = widget.site;

  String get _host => Uri.tryParse(widget.site.url)?.host ?? widget.site.url;

  /// What this container opened: the typed address, or the stored one.
  String get _openedUrl => widget.initialUrl ?? widget.site.url;

  @override
  void initState() {
    super.initState();
    _engine = ref.read(containerEngineProvider);
    final engine = _engine;
    _permissionSub = engine
        .permissionRequests()
        .where((r) => r.siteId == widget.site.id)
        .listen(_showPermissionSheet);
    _downloadSub = engine
        .downloads()
        .where((d) => d.siteId == widget.site.id)
        .listen(_showDownloadSheet);
    _downloadResultSub = engine
        .downloadResults()
        .where((r) => _myDownloadRequestIds.contains(r.requestId))
        .listen(_showDownloadResult);
    _tunnelSub = engine
        .tunnelDropped()
        .where((t) => t.siteId == widget.site.id)
        .listen((_) => setState(() => _tunnelDropped = true));
    _findSub = engine
        .findResults()
        .where((r) => r.siteId == widget.site.id)
        .listen((result) => setState(() => _findResult = result));
    _open();
  }

  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    // Read before opening, and a failure here stops the open: a site is
    // never opened without the lists and scripts its vault says it gets.
    final initialUrl = widget.initialUrl;
    final site = initialUrl == null ? widget.site : widget.site.copyWith(url: initialUrl);
    final extras = await ref.read(engineExtrasBuilderProvider)(site);
    if (!mounted) return;
    try {
      await _engine.open(site, extras: extras, throwaway: widget.throwaway);
    } finally {
      if (mounted) setState(() => _openReturned = true);
    }
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    _downloadSub?.cancel();
    _downloadResultSub?.cancel();
    _tunnelSub?.cancel();
    _findSub?.cancel();
    // A throwaway never reopens. Closing its session disposes its page view
    // if Flutter has not already, and ContainerView.dispose wipes a
    // wipe-on-exit profile — popped, or torn down by a lock or panic.
    if (_closeOnDispose) unawaited(_engine.close(widget.site.id));
    super.dispose();
  }

  void _showPermissionSheet(PendingPermissionRequest request) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => PermissionRequestSheet(
        host: request.host,
        kind: request.kind,
        onDecision: (decision) {
          Navigator.pop(context);
          _engine.resolvePermission(request.requestId, decision);
        },
      ),
    );
  }

  void _showDownloadSheet(HeldDownloadEvent event) {
    _myDownloadRequestIds.add(event.requestId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HeldDownloadSheet(
        download: event.download,
        onDecision: (decision) {
          Navigator.pop(context);
          _engine.resolveDownload(event.requestId, decision);
        },
      ),
    );
  }

  void _showDownloadResult(DownloadResult result) {
    if (!mounted) return;
    final message = switch (result.outcome) {
      DownloadOutcome.saved => 'Saved to Downloads',
      DownloadOutcome.kept => 'Kept in this container',
      DownloadOutcome.failed => result.reason != null
          ? refusalMessage(result.reason!)
          : 'Download failed',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSiteSheet(int blockedCount) async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    String? workspaceName;
    for (final workspace in workspaces) {
      if (workspace.id == _site.workspaceId) workspaceName = workspace.name;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          // A throwaway is not written to the vault until it is saved (spec
          // §5.1). Its switches change only this page's record, which nothing
          // reads again: a throwaway never reopens.
          Future<void> save(Site updated) async {
            setState(() => _site = updated);
            setSheetState(() {});
            if (_isThrowaway) return;
            await ref.read(siteRepositoryProvider).upsert(updated);
          }

          final host = _site.host;
          return SiteSheet(
            monogram: _site.monogram,
            name: _site.name,
            // A throwaway belongs to no workspace until it is saved.
            subtitle: _isThrowaway || workspaceName == null ? host : '$host · $workspaceName',
            proxyDescriptor: _proxyDescriptor(_site),
            cookiesDescriptor: switch (_site.cookiePolicy) {
              CookiePolicy.keep => 'Keep for this site',
              CookiePolicy.wipeOnExit => 'Wipe on exit',
            },
            blockedCount: blockedCount,
            forceDark: _site.forceDark,
            desktopView: _site.userAgentMode == UserAgentMode.desktop,
            // Editing a throwaway means saving it.
            onEdit: () {
              Navigator.pop(sheetContext);
              if (_isThrowaway) {
                _saveAsSite();
              } else {
                _editSite();
              }
            },
            onForceDarkChanged: (value) => save(_site.copyWith(forceDark: value)),
            // The switch is binary, so turning it off lands on `android` — a
            // site that was `minimal` loses that once desktop view is flipped.
            onDesktopViewChanged: (value) => save(_site.copyWith(
              userAgentMode: value ? UserAgentMode.desktop : UserAgentMode.android,
            )),
            onCloseAndWipe: () async {
              Navigator.pop(sheetContext);
              closeSite(ref, widget.site.id);
              await _engine.close(widget.site.id);
              await _engine.wipe(widget.site.profileId);
              if (!mounted) return;
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Future<void> _editSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddSiteScreen(
        initial: _site,
        workspaces: workspaces,
        onSave: (updated) async {
          await ref.read(siteRepositoryProvider).upsert(updated);
          if (!mounted) return;
          setState(() => _site = updated);
          Navigator.pop(context);
        },
      ),
    ));
  }

  /// Spec §5.3. The form opens on the throwaway as it is now — the page it is
  /// showing, cookies kept — and keeps its id and profile id, so the saved
  /// site is this same container. The row is written first, then the native
  /// profile is kept: without `keep`, closing the page would wipe the login
  /// just saved. Picking "Wipe on exit" in the form skips `keep`. Anything
  /// else changed in the form applies the next time the site opens.
  Future<void> _saveAsSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    final navigation = ref.read(navigationForSiteProvider(widget.site.id)).valueOrNull;
    final initial = _site.copyWith(
      url: navigation?.url ?? _openedUrl,
      cookiePolicy: CookiePolicy.keep,
    );
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (_) => AddSiteScreen(
        initial: initial,
        workspaces: workspaces,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          if (site.cookiePolicy != CookiePolicy.wipeOnExit) await _engine.keep(site.id);
          if (!mounted) return;
          _closeOnDispose = false;
          ref.read(throwawaySitesProvider.notifier).remove(site.id);
          ref.invalidate(allSitesProvider);
          ref.invalidate(dashboardProvider);
          setState(() => _site = site);
          Navigator.pop(context);
        },
      ),
    ));
  }

  Future<void> _openReader() async {
    final article = await _engine.extractArticle(widget.site.id);
    if (article == null || !mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReaderScreen(
        article: article,
        onClose: () => Navigator.pop(context),
        onTextSize: () {},
        onTheme: () {},
      ),
    ));
  }

  /// Find in page (spec §6.5). The count shown is dropped until the page
  /// reports the new text's, so it is never the old text's.
  void _find(String query) {
    setState(() => _findResult = null);
    if (query.isEmpty) {
      _engine.clearFind(widget.site.id);
    } else {
      _engine.find(widget.site.id, query);
    }
  }

  void _clearFind() {
    setState(() => _findResult = null);
    _engine.clearFind(widget.site.id);
  }

  /// Spec §3.3: the page's own address, through Flutter's clipboard. The
  /// site's `allowClipboard` governs page scripts, not this user action.
  Future<void> _copyLink() async {
    final url =
        ref.read(navigationForSiteProvider(widget.site.id)).valueOrNull?.url ?? _openedUrl;
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
  }

  /// A ☰ shortcut (spec §6.4), pushed on the open vault's navigator above
  /// this container.
  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// The ☰ header's mono line (spec §6.4): `host · Workspace`, or the host
  /// alone for a throwaway, which belongs to no workspace until saved.
  String _menuSubtitle(List<Workspace> workspaces) {
    final host = _site.host;
    if (_isThrowaway) return host;
    for (final workspace in workspaces) {
      if (workspace.id == _site.workspaceId) return '$host · ${workspace.name}';
    }
    return host;
  }

  void _handleRefusal(ContainerSession session) {
    if (_refusalHandled) return;
    _refusalHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => ProxyUnreachableScreen(
          host: _host,
          siteName: widget.site.name,
          failure: session.failure ?? RouteFailure.misconfigured,
          tunnelDescriptor: widget.site.proxyHost == null
              ? 'no proxy'
              : '${widget.site.proxyMode.name} · ${widget.site.proxyHost}:${widget.site.proxyPort}',
          lastWorkedLabel: 'never on this device',
          onTryAgain: () => Navigator.pop(context),
          onChangeProxySettings: () => Navigator.pop(context),
          onOpenWithoutTunnel: () => Navigator.pop(context),
        ),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionForSiteProvider(widget.site.id));
    _isThrowaway = ref.watch(throwawaySitesProvider).any((site) => site.id == widget.site.id);
    final navigation = ref.watch(navigationForSiteProvider(widget.site.id)).valueOrNull;
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];
    final blockedToday = ref.watch(leakCountProvider);
    // Spec §5.3: a throwaway offers the save bar once its first load has
    // finished.
    ref.listen(navigationForSiteProvider(widget.site.id), (_, next) {
      if (!_loadedOnce && next.valueOrNull?.loading == false) {
        setState(() => _loadedOnce = true);
      }
    });

    return sessionAsync.when(
      loading: () => OpeningBody(
        host: _host, steps: openStepsFor(widget.site), progress: 0.2,
        onCancel: () => Navigator.pop(context),
      ),
      error: (_, __) => OpeningBody(
        host: _host, steps: openStepsFor(widget.site), progress: 0,
        onCancel: () => Navigator.pop(context),
      ),
      data: (session) {
        // No session yet means `open` has not registered this site natively,
        // and the platform refuses a view for an unregistered site — so only
        // the checklist here. Once it exists, the page view is built even
        // while `opening` (see the overlay below). A session seen before this
        // route's own `open` returns is a previous visit's; see
        // [_openReturned].
        if (session == null || !_openReturned) {
          return OpeningBody(
            host: _host, steps: openStepsFor(widget.site), progress: 0.6,
            onCancel: () => Navigator.pop(context),
          );
        }
        if (session.phase == SessionPhase.refused) {
          _handleRefusal(session);
          return const SizedBox.shrink();
        }

        final pageHost = navigation?.host ?? '';
        return Stack(children: [
          ContainerScreen(
            // The page's host once it reports one; the site's before that,
            // and whenever the page has none (`about:blank`, a failed load).
            host: pageHost.isEmpty ? _host : pageHost,
            // There is no DIRECT label (spec §4.4).
            routeLabel: widget.site.proxyMode == ProxyMode.direct
                ? ''
                : widget.site.proxyMode.name.toUpperCase(),
            live: session.phase == SessionPhase.live,
            navigation: navigation,
            openCount: 1,
            body: ContainerWebView(siteId: widget.site.id),
            entries: [
              SwitcherEntry(
                siteId: widget.site.id, name: widget.site.name,
                monogram: widget.site.monogram,
                meta: 'viewing now · ${widget.site.proxyMode.name}',
                live: true,
              ),
            ],
            workspaceName: '',
            siteMonogram: _site.monogram,
            siteName: _site.name,
            siteSubtitle: _menuSubtitle(workspaces),
            blockedToday: blockedToday,
            findResult: _findResult,
            showSaveBar: _isThrowaway && _loadedOnce && !_saveBarDismissed,
            onBack: () => _engine.goBack(widget.site.id),
            onForward: () => _engine.goForward(widget.site.id),
            onStop: () => _engine.stop(widget.site.id),
            onReload: () => _engine.reload(widget.site.id),
            onPanic: () => panic(ref),
            onSiteDetails: () => _showSiteSheet(session.blockedCount),
            onReader: _openReader,
            onCopyLink: _copyLink,
            onToday: () => _push(const TodayRoute()),
            onScripts: () => _push(const ScriptsRoute()),
            onWorkspaces: () => _push(const WorkspacesRoute()),
            onSettings: () => _push(const SettingsRoute()),
            // Spec §5.2: to the dashboard, the first route, closing every
            // container pushed on the way.
            onAllSites: () => Navigator.popUntil(context, (route) => route.isFirst),
            onFind: _find,
            onFindNext: (forward) => _engine.findNext(widget.site.id, forward: forward),
            onClearFind: _clearFind,
            onSaveAsSite: _saveAsSite,
            onDismissSaveBar: () => setState(() => _saveBarDismissed = true),
            // The switcher has already closed itself by now. Only closing
            // this route's own site leaves it with nothing to show.
            onCloseSession: (siteId) async {
              closeSite(ref, siteId);
              await _engine.close(siteId);
              if (siteId != widget.site.id || !context.mounted) return;
              Navigator.pop(context);
            },
            onCloseAllAndWipe: () async {
              closeSite(ref, widget.site.id);
              await _engine.close(widget.site.id);
              await _engine.wipe(widget.site.profileId);
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          if (_tunnelDropped)
            TunnelDroppedScreen(
              host: _host,
              droppedAgoLabel: 'just now',
              onReconnect: () => setState(() => _tunnelDropped = false),
              onCloseAndWipe: () async {
                closeSite(ref, widget.site.id);
                await _engine.close(widget.site.id);
                await _engine.wipe(widget.site.profileId);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
            ),
          // The checklist covers the page rather than replacing it. The
          // native view only reports `live` once its first load finishes, and
          // it only exists once ContainerWebView above is built — so the page
          // must be building underneath while this shows, or it never
          // arrives. Keeping ContainerScreen at the same position in this
          // Stack is what lets going live remove the overlay without
          // rebuilding the view (a rebuild disposes the native WebView).
          if (session.phase == SessionPhase.opening)
            Positioned.fill(
              child: OpeningBody(
                host: _host, steps: openStepsFor(widget.site), progress: 0.6,
                onCancel: () => Navigator.pop(context),
              ),
            ),
        ]);
      },
    );
  }
}

/// Spec `6c`'s proxy row: `SOCKS5 · 127.0.0.1:9050`.
String _proxyDescriptor(Site site) => switch (site.proxyMode) {
      ProxyMode.direct => 'Direct',
      ProxyMode.socks5 => 'SOCKS5 · ${site.proxyHost}:${site.proxyPort}',
      ProxyMode.http => 'HTTP · ${site.proxyHost}:${site.proxyPort}',
    };
```

- [ ] **Step 8: Run the tests and the gate**

Run: `flutter test test/ui/features/container_screen_test.dart test/ui/features/container_route_test.dart`
Expected: PASS — the screen test's 14; the route test's 11 new tests and every older one, now reaching `6c` through the shield and reader mode through ☰.
Run: `grep -rn "ContainerToolbar\|container_toolbar" lib test` — Expected: no output.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 107.

- [ ] **Step 9: Commit**

```bash
git add lib/ui/features/container/views test/ui/features/container_screen_test.dart test/ui/features/container_route_test.dart
git commit -m "feat: rebuild the container as layout C with navigation, find and the browser menu"
```

---

### Task 13: Typing an address

Tapping the pill turns it into the address field (§6.2); what is typed opens this container, a saved site's own container, or a throwaway on this container's route (§4.3, §5.2).

**Files:**
- Modify (whole file): `lib/ui/features/container/views/container_top_bar.dart`
- Modify: `lib/ui/features/container/views/container_screen.dart` (editing), `lib/ui/features/container/views/container_route.dart` (suggestions, `_openDestination`)
- Test: `test/ui/features/container_screen_test.dart` (6 added), `test/ui/features/container_route_test.dart` (5 added; `_pump` gains `saved` and `searchEngine`; `_RecordingSiteRepository` records `touch`)

**Interfaces:**
- Consumes: Tasks 1–2's `Destination`s, `suggestionsFor`, `buildThrowaway`, `SearchEngine`; Task 3's `searchEngineProvider`; Task 8's `ContainerRoute(initialUrl:, throwaway:)` and `throwawaySitesProvider`; Task 11's `AddressEditBar`, `AddressSuggestions`; `openSite`, `allSitesProvider`, `newProfileId`.
- Produces:
  - `ContainerTopBar` gains `required VoidCallback onEditAddress` — a tap anywhere on the pill but its stop and shield
  - `ContainerScreen` gains `required String address`, `required List<AddressSuggestion> Function(String text) suggest`, `required ValueChanged<Destination> onOpen`; system back and a tap outside the list leave editing
  - `_ContainerRouteState._openDestination(Destination)`: `ThisContainer` → `engine.loadUrl`; `SavedSiteContainer` → `openSite`, then push `ContainerRoute(site:, initialUrl:)`; `Throwaway` → `buildThrowaway`, add to `throwawaySitesProvider`, push `ContainerRoute(site:, throwaway: true)`, and remove it from the list once popped

- [ ] **Step 1: Write the failing screen tests**

In `test/ui/features/container_screen_test.dart`:

1. Add these imports, keeping the list sorted:

```dart
import 'package:container/domain/models/address_suggestion.dart';
import 'package:container/domain/models/destination.dart';
import 'package:container/domain/models/search_engine.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/container/views/address_edit_bar.dart';
import 'package:container/ui/features/container/views/address_suggestions.dart';
```

2. Add below `final _calls = <String>[];`:

```dart
/// Every destination [ContainerScreen] asked to open, in order.
final _opened = <Destination>[];

const _personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);
const _forum = Site(
  id: 's1', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p1',
);
const _market = Site(
  id: 'm1', workspaceId: 'w1', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'p2',
);

/// Task 2's suggestions, as the route hands them over.
List<AddressSuggestion> _suggest(String text) => suggestionsFor(
      text: text,
      current: _forum,
      saved: const [_forum, _market],
      workspaces: const [_personal],
      engine: SearchEngine.duckDuckGo,
    );
```

3. In `_screen`, add the parameter `String address = 'https://forum.example.com/t/9',` after `bool showSaveBar = false,`, and the arguments

```dart
      address: address,
      suggest: _suggest,
      onOpen: _opened.add,
```

after `showSaveBar: showSaveBar,`.

4. Add below `_openFind`:

```dart
/// Taps the pill, which starts editing the address.
Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.text('forum.example.com'));
  await tester.pumpAndSettle();
}
```

5. Replace `setUp(_calls.clear);` with:

```dart
  setUp(() {
    _calls.clear();
    _opened.clear();
  });
```

6. Add at the end of `main()`:

```dart
  testWidgets('tapping the pill starts editing on the page address, selected, with panic beside it', (tester) async {
    const address = 'https://forum.example.com/t/9';
    await tester.pumpWidget(_app(_screen(address: address)));

    await _edit(tester);

    expect(find.byType(ContainerTopBar), findsNothing);
    expect(find.byType(AddressEditBar), findsOneWidget);
    expect(_icon('Panic'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, address);
    expect(field.controller!.selection,
        const TextSelection(baseOffset: 0, extentOffset: address.length));
    // The list covers the page and the bottom bar.
    final list = tester.getRect(find.byType(AddressSuggestions));
    expect(list.top, tester.getRect(find.byType(_Page)).top);
    expect(list.bottom, tester.getRect(find.byType(ContainerBottomBar)).bottom);
    expect(_calls, isEmpty);
  });

  testWidgets('typing lists what the text would open; tapping a row leaves editing and opens it', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    await _edit(tester);

    await tester.enterText(find.byType(TextField), 'mark');
    await tester.pump();
    expect(find.text('SAVED SITES'), findsOneWidget);
    expect(find.text('Search DuckDuckGo for “mark”'), findsOneWidget);
    await tester.tap(find.text('Marketplace'));
    await tester.pumpAndSettle();

    expect(find.byType(AddressEditBar), findsNothing);
    expect(_opened.single, isA<SavedSiteContainer>());
    expect(_opened.single.url.toString(), 'https://market.example.com');
  });

  testWidgets('the keyboard opens the address row, or the search row when there is none', (tester) async {
    await tester.pumpWidget(_app(_screen()));

    await _edit(tester);
    await tester.enterText(find.byType(TextField), 'news.example.org');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    await _edit(tester);
    await tester.enterText(find.byType(TextField), 'privacy tools');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();
    // Nothing typed: nothing to open, and editing ends.
    await _edit(tester);
    await tester.tap(_icon('Clear'));
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(_opened.map((destination) => destination.url.toString()),
        ['https://news.example.org', 'https://duckduckgo.com/?q=privacy+tools']);
    expect(find.byType(AddressEditBar), findsNothing);
  });

  // Review Focus 2.
  testWidgets('back, or a tap outside the list, leaves editing without going anywhere', (tester) async {
    await tester.pumpWidget(_app(_screen(navigation: _nav(canGoBack: true))));

    await _edit(tester);
    await _systemBack(tester);
    expect(find.byType(AddressEditBar), findsNothing);
    expect(find.byType(ContainerTopBar), findsOneWidget);

    await _edit(tester);
    await tester.tapAt(
        tester.getBottomLeft(find.byType(AddressSuggestions)) + const Offset(40, -20));
    await tester.pumpAndSettle();
    expect(find.byType(AddressEditBar), findsNothing);

    expect(_calls, isEmpty);
    expect(_opened, isEmpty);
  });

  // Review Focus 1.
  testWidgets('the page view survives editing', (tester) async {
    await tester.pumpWidget(_app(_screen()));
    final page = tester.state(find.byType(_Page));

    await _edit(tester);
    await tester.enterText(find.byType(TextField), 'news');
    await tester.pump();
    await _systemBack(tester);

    expect(tester.state(find.byType(_Page)), same(page));
  });

  // Review Focus 5.
  testWidgets('at 360 wide, editing a long address fits', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(_screen(
      address: 'https://a-rather-long-subdomain.forum.example.com/threads/12345?page=2',
    )));

    await _edit(tester);
    await tester.enterText(
        find.byType(TextField), 'market.example.com/a/very/long/path/that/keeps/going');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 2: Write the failing route tests**

In `test/ui/features/container_route_test.dart`:

1. Add these imports, keeping the list sorted:

```dart
import 'package:container/domain/models/search_engine.dart';
import 'package:container/ui/features/container/views/address_suggestions.dart';
import 'package:container/ui/features/search/view_models/providers.dart' show allSitesProvider;
import 'package:container/ui/features/settings/view_models/providers.dart'
    show searchEngineProvider;
```

2. In `_RecordingSiteRepository`, replace

```dart
  @override
  Future<void> touch(String id, DateTime at) => throw UnimplementedError();
```

with

```dart
  /// Sites marked visited: what `openSite` records.
  final touched = <String>[];

  @override
  Future<void> touch(String id, DateTime at) async => touched.add(id);
```

3. In `_pump`, add the parameters

```dart
  List<Site> saved = const [],
  SearchEngine searchEngine = SearchEngine.duckDuckGo,
```

after `Size size = const Size(800, 1600),`, and the overrides

```dart
      // What the address bar suggests from: this vault's sites and engine.
      allSitesProvider.overrideWith((ref) async => saved),
      searchEngineProvider.overrideWith((ref) async => searchEngine),
```

after the `siteLookupProvider` override.

4. Add below `_standInForPlatformViews`:

```dart
/// A SOCKS5 forum: a throwaway typed in it goes out on the same proxy.
Site _socksSite() => _site().copyWith(
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050);

const _market = Site(
  id: 'm1', workspaceId: 'w', name: 'Marketplace', monogram: 'Mk',
  url: 'https://market.example.com', profileId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
);

/// Taps the forum's pill and types [text] into the address field.
Future<void> _typeAddress(WidgetTester tester, String text) async {
  await tester.tap(find.text('forum.example.com'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}
```

5. Add at the end of `main()`:

```dart
  testWidgets("an address on this container's own host loads here, in place", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'forum.example.com/latest');
    expect(find.text('THIS CONTAINER'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(engine.loaded, [(siteId: 's1', url: 'https://forum.example.com/latest')]);
    expect(engine.openedSites.keys, ['s1']);
    expect(find.byType(AddressSuggestions), findsNothing);
  });

  testWidgets("a saved site's address opens its own container over this one, at that address", (tester) async {
    final engine = FakeContainerEngine();
    final sites = _RecordingSiteRepository();
    await _pump(tester, engine, _site(), sites: sites, saved: [_site(), _market], overHome: true);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'market.example.com/deals');
    expect(find.text('ITS OWN CONTAINER'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    expect(engine.openedSites['m1']!.url, 'https://market.example.com/deals');
    expect(engine.openedAsThrowaway, isEmpty);
    // Marked open and visited, as the dashboard opens a site; its stored
    // address is untouched.
    expect(sites.touched, ['m1']);
    expect(sites.upserts, isEmpty);
    expect(ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(openSiteIdsProvider), contains('m1'));

    await _systemBack(tester);
    expect(find.text('forum.example.com'), findsOneWidget);
    // Left, a saved site's session stays open in the background.
    expect(engine.closed, isEmpty);
  });

  testWidgets("anything else opens a throwaway on this container's route; leaving it closes and forgets it", (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _socksSite(), overHome: true);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'news.example.org/today');
    // The address row and the search row both open a throwaway on SOCKS5.
    expect(find.text('THROWAWAY · SOCKS5'), findsNWidgets(2));
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pumpAndSettle();

    final id = engine.openedAsThrowaway.single;
    final opened = engine.openedSites[id]!;
    expect(opened.url, 'https://news.example.org/today');
    expect((opened.proxyMode, opened.proxyHost, opened.proxyPort),
        (ProxyMode.socks5, '127.0.0.1', 9050));
    expect(opened.cookiePolicy, CookiePolicy.wipeOnExit);
    expect(_registry(tester).map((site) => site.id), [id]);

    await _systemBack(tester);

    // Its route closed its session, which wipes it natively.
    expect(engine.closed, [id]);
    expect(_registry(tester), isEmpty);
    expect(find.byType(ContainerRoute), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
  });

  testWidgets('suggestions come from this vault only, and name the chosen engine', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(),
        saved: [_site(), _market], searchEngine: SearchEngine.startpage);
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'market');

    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.text('market.example.com · Personal'), findsOneWidget);
    expect(find.text('Search Startpage for “market”'), findsOneWidget);
    expect(find.text('Nothing is fetched while you type.'), findsOneWidget);
  });

  // Review Focus 2.
  testWidgets('back while typing leaves editing, and neither goes back nor leaves', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site(), overHome: true);
    await tester.pumpAndSettle();
    engine.emitNavigation(const NavigationState(
        siteId: 's1', url: 'https://forum.example.com/t/9', canGoBack: true));
    await tester.pumpAndSettle();

    await _typeAddress(tester, 'news');
    await _systemBack(tester);

    expect(find.byType(AddressSuggestions), findsNothing);
    expect(engine.wentBack, isEmpty);
    expect(engine.loaded, isEmpty);
    expect(find.byType(ContainerRoute), findsOneWidget);
  });
```

- [ ] **Step 3: Run to verify they fail**

Run: `flutter test test/ui/features/container_screen_test.dart test/ui/features/container_route_test.dart`
Expected: FAIL — compile errors: `ContainerScreen` has no `address`, `suggest` or `onOpen`.

- [ ] **Step 4: The pill starts editing**

Replace `lib/ui/features/container/views/container_top_bar.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.1's top bar (layout C). Keeps `2b`'s 12/8 padding,
/// 34px pill, 6px dot and 32px panic square; `2b`'s ‹ and ⟳ are gone — back
/// is on the bottom bar, reload in the ☰ menu. The pill ends in the shield,
/// which opens `6c`, and while the page loads a stop × sits just before it.
/// A tap anywhere else on the pill starts typing an address (§6.2). Panic is
/// always here, never behind a menu.
class ContainerTopBar extends StatelessWidget {
  const ContainerTopBar({
    super.key,
    required this.host,
    required this.routeLabel,
    required this.live,
    required this.loading,
    required this.onEditAddress,
    required this.onStop,
    required this.onSiteDetails,
    required this.onPanic,
  });

  /// The page's host: after following a link, the other site's.
  final String host;

  /// `site.proxyMode.name.toUpperCase()` for a proxied site, empty for a
  /// direct one. The caller computes this — there is no "DIRECT" label; the
  /// spec never shows one.
  final String routeLabel;

  /// Jade while the tunnel is up; amber while the container is still opening.
  final bool live;

  /// Shows the stop ×.
  final bool loading;

  /// The pill, outside its stop and shield: typing an address.
  final VoidCallback onEditAddress;
  final VoidCallback onStop;

  /// The shield: `6c`.
  final VoidCallback onSiteDetails;
  final VoidCallback onPanic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEditAddress,
              child: Container(
                height: 34,
                padding: const EdgeInsets.only(left: 12, right: 3),
                decoration: BoxDecoration(
                  color: C.surface,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: C.line08),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: live ? C.jade : C.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ui(size: 11.5, color: const Color(0xFFA9B0AE)),
                      ),
                    ),
                    if (routeLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(routeLabel,
                          style: ui(size: 9.5, weight: 500, color: C.textFaint)),
                      const SizedBox(width: 2),
                    ],
                    if (loading)
                      IconTap(
                        glyph: AppGlyph.stop,
                        label: 'Stop',
                        onTap: onStop,
                        size: 28,
                        iconSize: 14,
                      ),
                    IconTap(
                      glyph: AppGlyph.shield,
                      label: 'Site details',
                      onTap: onSiteDetails,
                      size: 28,
                      iconSize: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PanicSquare(onTap: onPanic),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: `ContainerScreen` edits the address**

In `lib/ui/features/container/views/container_screen.dart`:

1. Replace the imports with:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/models/address_suggestion.dart';
import '../../../../domain/models/destination.dart';
import '../../../../domain/models/find_result.dart';
import '../../../../domain/models/navigation_state.dart';
import '../../../core/tokens.dart';
import 'address_edit_bar.dart';
import 'address_suggestions.dart';
import 'browser_menu_sheet.dart';
import 'container_bottom_bar.dart';
import 'container_top_bar.dart';
import 'find_bar.dart';
import 'load_line.dart';
import 'switcher_sheet.dart';
import 'throwaway_save_bar.dart';
```

2. Replace `enum _Chrome { page, find }` with:

```dart
enum _Chrome { page, editing, find }
```

3. Replace

```dart
    required this.showSaveBar,
    required this.onBack,
```

with

```dart
    required this.showSaveBar,
    required this.address,
    required this.suggest,
    required this.onOpen,
    required this.onBack,
```

4. Replace

```dart
  /// A throwaway's save bar (spec §5.3), directly above the bottom bar.
  final bool showSaveBar;
```

with

```dart
  /// A throwaway's save bar (spec §5.3), directly above the bottom bar.
  final bool showSaveBar;

  /// What the address field starts from, selected: the page's address.
  final String address;

  /// What typed text would open (spec §4.4), from the open vault only.
  final List<AddressSuggestion> Function(String text) suggest;

  /// A suggestion picked, or the keyboard's action on the field (§6.2).
  final ValueChanged<Destination> onOpen;
```

5. Replace

```dart
  _Chrome _chrome = _Chrome.page;
  final _findText = TextEditingController();

  @override
  void dispose() {
    _findText.dispose();
    super.dispose();
  }
```

with

```dart
  _Chrome _chrome = _Chrome.page;
  final _addressText = TextEditingController();
  final _findText = TextEditingController();

  @override
  void dispose() {
    _addressText.dispose();
    _findText.dispose();
    super.dispose();
  }

  /// Spec §6.2: the field starts from the page's address, selected, so
  /// typing replaces it.
  void _startEditing() {
    final address = widget.address;
    _addressText.value = TextEditingValue(
      text: address,
      selection: TextSelection(baseOffset: 0, extentOffset: address.length),
    );
    setState(() => _chrome = _Chrome.editing);
  }

  void _stopEditing() => setState(() => _chrome = _Chrome.page);

  void _open(AddressSuggestion suggestion) {
    _stopEditing();
    widget.onOpen(suggestion.destination);
  }

  /// The keyboard's action opens the address row if there is one, otherwise
  /// the search row. With nothing typed there is neither, and editing ends.
  void _submitAddress(String text) {
    AddressSuggestion? address;
    AddressSuggestion? search;
    for (final row in widget.suggest(text)) {
      if (row.kind == SuggestionKind.address) address ??= row;
      if (row.kind == SuggestionKind.search) search ??= row;
    }
    final pick = address ?? search;
    if (pick == null) {
      _stopEditing();
    } else {
      _open(pick);
    }
  }
```

6. Replace the whole `_handleBack` method and its doc comment with:

```dart
  /// System back that [PopScope] kept from popping the route: out of editing
  /// or find first, then back in the page (spec §3.3, §6.2). The route pops
  /// only once none of these applies.
  void _handleBack() {
    switch (_chrome) {
      case _Chrome.editing:
        _stopEditing();
      case _Chrome.find:
        _closeFind();
      case _Chrome.page:
        if (widget.navigation?.canGoBack ?? false) widget.onBack();
    }
  }
```

7. Replace the whole `build` method with:

```dart
  @override
  Widget build(BuildContext context) {
    final navigation = widget.navigation;
    final canGoBack = navigation?.canGoBack ?? false;
    final canGoForward = navigation?.canGoForward ?? false;
    final loading = navigation?.loading ?? false;

    return PopScope(
      canPop: _chrome == _Chrome.page && !canGoBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              switch (_chrome) {
                _Chrome.page => ContainerTopBar(
                    host: widget.host,
                    routeLabel: widget.routeLabel,
                    live: widget.live,
                    loading: loading,
                    onEditAddress: _startEditing,
                    onStop: widget.onStop,
                    onSiteDetails: widget.onSiteDetails,
                    onPanic: widget.onPanic,
                  ),
                _Chrome.editing => AddressEditBar(
                    controller: _addressText,
                    // The suggestions below are worked out from the field
                    // at every build.
                    onChanged: (_) => setState(() {}),
                    onSubmitted: _submitAddress,
                    onPanic: widget.onPanic,
                  ),
                _Chrome.find => FindBar(
                    controller: _findText,
                    result: widget.findResult,
                    onChanged: widget.onFind,
                    onPrevious: () => widget.onFindNext(false),
                    onNext: () => widget.onFindNext(true),
                    onClose: _closeFind,
                    onPanic: widget.onPanic,
                  ),
              },
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(child: widget.body),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: LoadLine(
                                      loading: loading,
                                      progress: navigation?.progress ?? 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.showSaveBar)
                            ThrowawaySaveBar(
                              onSave: widget.onSaveAsSite,
                              onDismiss: widget.onDismissSaveBar,
                            ),
                          ContainerBottomBar(
                            openCount: widget.openCount,
                            onBack: canGoBack ? widget.onBack : null,
                            onForward: canGoForward ? widget.onForward : null,
                            onOpenSwitcher: _openSwitcher,
                            onMenu: _openMenu,
                          ),
                        ],
                      ),
                    ),
                    // Spec §6.2: while typing, the suggestions cover the page
                    // and the bottom bar. Laid over them, after the page, so
                    // the page view keeps its place.
                    if (_chrome == _Chrome.editing)
                      Positioned.fill(
                        child: AddressSuggestions(
                          suggestions: widget.suggest(_addressText.text),
                          onPick: _open,
                          onDismiss: _stopEditing,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 6: The route opens what is typed**

In `lib/ui/features/container/views/container_route.dart`:

1. Add these imports, keeping the list sorted:

```dart
import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../domain/models/address_suggestion.dart';
import '../../../../domain/models/destination.dart';
import '../../../../domain/models/search_engine.dart';
import '../../../../domain/models/throwaway.dart';
import '../../settings/view_models/providers.dart' show searchEngineProvider;
```

and add `openSite,` to the dashboard import's `show` list, after `leakCountProvider,`.

2. Add after `_menuSubtitle`:

```dart
  /// Spec §5.2: where a typed address or search opens. A saved site's
  /// container and a throwaway are pushed over this one, on the open vault's
  /// navigator, so system back comes back here with this page still live.
  Future<void> _openDestination(Destination destination) async {
    switch (destination) {
      case ThisContainer(:final url):
        await _engine.loadUrl(widget.site.id, url.toString());
      case SavedSiteContainer(:final site, :final url):
        // As the dashboard and search open a site: marked open, the visit
        // recorded. Its stored address is not touched.
        openSite(ref, site.id);
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => ContainerRoute(site: site, initialUrl: url.toString()),
        ));
      case final Throwaway target:
        final throwaway = buildThrowaway(
          destination: target,
          current: widget.site,
          newId: newProfileId,
        );
        ref.read(throwawaySitesProvider.notifier).add(throwaway);
        await Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => ContainerRoute(site: throwaway, throwaway: true),
        ));
        // Popped: its route closed its session, which wiped it. A lock or
        // panic empties the list by itself.
        if (mounted) ref.read(throwawaySitesProvider.notifier).remove(throwaway.id);
    }
  }
```

3. In `build`, replace

```dart
    final blockedToday = ref.watch(leakCountProvider);
```

with

```dart
    final blockedToday = ref.watch(leakCountProvider);
    // What typed text is matched against (spec §4.4): this vault's sites and
    // search engine, watched from the start so the first keystroke has them.
    final saved = ref.watch(allSitesProvider).valueOrNull ?? const <Site>[];
    final searchEngine =
        ref.watch(searchEngineProvider).valueOrNull ?? SearchEngine.duckDuckGo;
```

4. In the `ContainerScreen(` call, replace

```dart
            showSaveBar: _isThrowaway && _loadedOnce && !_saveBarDismissed,
```

with

```dart
            showSaveBar: _isThrowaway && _loadedOnce && !_saveBarDismissed,
            address: navigation?.url ?? _openedUrl,
            // `current` is the site this container was opened for: its host
            // is "this container", its route the one a throwaway inherits.
            suggest: (text) => suggestionsFor(
              text: text,
              current: widget.site,
              saved: saved,
              workspaces: workspaces,
              engine: searchEngine,
            ),
            onOpen: _openDestination,
```

- [ ] **Step 7: Run the tests and the gate**

Run: `flutter test test/ui/features/container_screen_test.dart test/ui/features/container_route_test.dart`
Expected: PASS — 6 new screen tests and 5 new route tests, and every earlier one.
Run: `flutter analyze` — Expected: `No issues found!`
Run: `flutter test` — Expected: all pass, D0 + 118.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/features/container/views test/ui/features/container_screen_test.dart test/ui/features/container_route_test.dart
git commit -m "feat: type an address to open this container, a saved site's, or a throwaway"
```

---

### Task 14: Verify the whole plan, and record it

The executor runs Steps 1–6. Step 7 is on an emulator and is **the orchestrator's, not the executor's**: the executor lists it as not done and stops.

**Files:**
- Modify: `CLAUDE.md` (a Plan 12 row in the plan table)
- Modify: `docs/superpowers/plans/2026-09-29-browser-chrome.md` (a `## Verification` section at the end)

- [ ] **Step 1: The full gate, on a clean tree**

```bash
git status --short                   # expect no output
flutter analyze                      # expect "No issues found!"
flutter test                         # expect "+<D0 + 118>: All tests passed!"
(cd android && ./gradlew :app:testDebugUnitTest)
grep -ho '<testsuite [^>]*' build/app/test-results/testDebugUnitTest/TEST-*.xml \
  | sed -E 's/.* tests="([0-9]+)".* failures="([0-9]+)" errors="([0-9]+)".*/\1 \2 \3/' \
  | awk '{t+=$1; f+=$2; e+=$3} END {print t" tests, "f" failures, "e" errors"}'
                                     # expect K0 + 21 tests, 0 failures, 0 errors
flutter build apk --debug 2>&1 | tee build/apk-build.log
grep -c '^e:' build/apk-build.log    # expect 0
```

If a count differs from D0 + 118 or K0 + 21, find out why before going on — a test that did not run is not a pass.

- [ ] **Step 2: The constraints, checked in the tree**

```bash
# 2b's floating toolbar is gone.
grep -rn "ContainerToolbar\|container_toolbar" lib test                  # expect no output
# Nothing in the container reaches past the open vault's navigator (6a5f013).
grep -rn "rootNavigator\|useRootNavigator" lib/ui/features/container      # expect no output
# Jade only on the live dot and 2b's ▲, among the files this plan wrote.
grep -n "C.jade" lib/ui/core/icons.dart lib/ui/core/widgets/icon_tap.dart \
  lib/ui/features/container/views/{panic_square,load_line,container_bottom_bar,throwaway_save_bar,find_bar,address_edit_bar,address_suggestions,browser_menu_sheet,container_top_bar,container_screen}.dart
                                     # expect two lines: container_bottom_bar.dart (▲), container_top_bar.dart (the dot)
# loadUrl's scheme guard holds on the platform side too.
grep -n "isLoadableUrl" android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt
                                     # expect one line, in load()
# The app makes no network request of its own.
grep -rn "HttpClient\|package:http/" lib                                  # expect no output
# Mullvad Leta is gone (spec §4.2's own rule; see Deviations).
grep -rn "mullvadLeta\|'Mullvad Leta'" lib                                # expect no output
```

- [ ] **Step 3: Every string spec §7 approved is in the tree, word for word**

```bash
for s in 'Search or type an address' 'SAVED SITES' 'ADDRESS' 'SEARCH' 'not saved' \
  'THIS CONTAINER' 'ITS OWN CONTAINER' 'THROWAWAY' 'Nothing is fetched while you type.' \
  'Not saved · wiped when you close it' 'Save as a site' 'Reload' 'Find' 'Reader' \
  'Copy link' 'Today' 'Scripts and filters' 'Workspaces' 'Settings' 'All sites' \
  'Link copied' 'Find in page' 'No matches' 'BROWSING' 'Search engine' 'DuckDuckGo' \
  'Startpage' 'Brave Search' 'Back' 'Forward' 'Stop' 'Site details' 'Panic' \
  'Open sessions' 'Menu' 'Clear' 'Previous match' 'Next match' 'Close find'; do
  grep -rqF -- "'$s'" lib || echo "MISSING: $s"
done                                                                    # expect no output
grep -rnF -- "'Search \${engine.label} for “\$typed”'" lib/domain        # expect one line: the search row
grep -rnF -- "'THROWAWAY · \${" lib/domain                              # expect one line: THROWAWAY · <ROUTE>
grep -rnF -- " BLOCKED'" lib/ui/features/container                      # expect one line: <n> BLOCKED
```

- [ ] **Step 4: Record the plan in `CLAUDE.md`**

Add this row to the plan table, after Plan 11's, with the date and the counts from Step 1 in place of the angle brackets:

```markdown
| 12 — Browser chrome and navigation | `2026-09-29-browser-chrome.md` | **Done** (<date>) | Rebuilds `2b` as layout C, implementing `docs/superpowers/specs/2026-09-28-browser-chrome-design.md` (project 1 of 4; supersedes `2b` and its toolbar copy): a top bar whose address pill ends in a shield (`6c`) and, while loading, a stop ×, beside panic; a 2px muted load line; a bottom bar with back / forward / `N OPEN` / ☰; drawn line icons (`lib/ui/core/icons.dart`); find in page; the ☰ menu (`BrowserMenuSheet`: Reload, Find, Reader, Copy link; Today, Scripts and filters, Workspaces, Settings, All sites); and a `Search engine` setting in `2d`. **Mullvad Leta is not offered** — it shut down on 2025-11-27, and the spec drops an engine that no longer works — so the picker lists DuckDuckGo, Startpage and Brave Search. Typing in the pill opens this container (`loadUrl`, which refuses every scheme but http/https in Dart and in Kotlin), a saved site's own container pushed over this one, or a **throwaway** container on this container's exact route, held in memory (`throwawaySitesProvider`, emptied on leaving `SessionOpen`) until `Save as a site`, which writes the row and then `keep`s the profile. A throwaway's profile id is journaled in `filesDir/throwaway-profiles` (`ThrowawayJournal`, beside `PendingDeletions`) from before the profile exists, so a crash cannot leak it; every start sweeps the journal and panic clears it. Verified <date>: `flutter analyze` clean, `flutter test` <N>/<N>, Kotlin JVM tests <K>/<K> (read from the JUnit XML), `flutter build apk --debug` with zero `e:` lines. **Not verified on a device** — the plan's Task 14 Step 7 lists the checks still owed, including whether Startpage's search URL works. See the plan's Known gaps and Design questions. |
```

- [ ] **Step 5: Record the verification in this plan**

Append to the end of this file:

```markdown
## Verification

<date>, on branch `plan-12-browser-chrome` at <commit>, clean tree:

- `flutter analyze`: No issues found!
- `flutter test`: <N> passed (baseline D0 = <D0>; this plan adds 118).
- Kotlin JVM tests: <K> tests, 0 failures, 0 errors, read from `build/app/test-results/testDebugUnitTest/TEST-*.xml` (baseline K0 = <K0>; this plan adds 21).
- `flutter build apk --debug`: built, zero `e:` lines.
- Task 14 Steps 2–3: every check as expected.
- **Not done: Task 14 Step 7** (on-device checks), which the orchestrator owns.
```

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md docs/superpowers/plans/2026-09-29-browser-chrome.md
git commit -m "docs: record plan 12, browser chrome and navigation"
```

- [ ] **Step 7 (orchestrator, on the emulator): Device checks**

Spec §8's device checks, plus what only a device can show. Drive it through `adb` and `uiautomator`; the app is `FLAG_SECURE`, so read the UI tree (labels are in `content-desc`), not screenshots. Record each result — seen, not seen, or not possible and why — in `CLAUDE.md`'s "Device verification" section.

1. **A search from a SOCKS5 site opens a throwaway on SOCKS5.** With a SOCKS5 proxy the emulator reaches at `10.0.2.2`, open a site set to it, tap the pill, type a search: the search row reads `THROWAWAY · SOCKS5`. Submit: a throwaway container opens, and the proxy's log shows its requests for the engine's host and none go direct. (With no SOCKS5 proxy to hand, do the same from an http-mode site through the local CONNECT proxy used for Plan 10, expect `THROWAWAY · HTTP`, and record which mode was used.)
2. **Back returns to the original container**, still live and not reloaded: no new request for the original page in the proxy log when you land back on it.
3. **Save as a site keeps the login.** In a throwaway, load a page that sets a cookie (`https://httpbin.org/cookies/set?plan12=1`). Tap `Save as a site`, save, go back to the dashboard, open the saved site again at `https://httpbin.org/cookies`: `plan12` is still there.
4. **A crash leaves no throwaway behind.** Open a throwaway and note its profile id: `adb shell run-as com.mono.container cat files/throwaway-profiles`. `adb shell am force-stop com.mono.container`, relaunch, unlock: `files/throwaway-profiles` is gone, and `adb shell run-as com.mono.container ls -R app_webview | grep <id>` prints nothing.
5. **Startpage works** (it could not be reached while planning). Settings → `Search engine` → `Startpage`; type a search in a container: the throwaway shows Startpage's results for it at `https://www.startpage.com/sp/search?query=…`. If it does not, stop: under spec §4.2 an engine that no longer works is dropped, and that is the user's call to confirm. Do the same for `Brave Search`.
6. **Find, Copy link, and the menu.** Find in page shows `<active>/<total>` and `No matches`; the arrows move through matches. Copy link, pasted into the address field, is the page's address. Each ☰ row opens its screen over the container, and `All sites` lands on the dashboard.
7. **A lock wipes an open throwaway.** Open a throwaway, background the app past the grace period and return (`9c`), unlock: `files/throwaway-profiles` no longer lists it.

---

## Known gaps

Deliberate, from the spec's §9 and from this plan. None is a bug to fix in passing.

- **No cap on stacked containers** (spec §9). Every container pushed from the address bar keeps its WebView alive until popped. Project 2 (tabs) replaces the stack.
- **The switcher stays a one-entry stub** (`openCount: 1`); a throwaway lists itself as that entry.
- **No address entry from the dashboard.** A route to inherit only exists inside a container.
- **Links still leave the site inside the same container**, on its route. Only typed addresses get the throwaway rule.
- **`ProxyProbe` still probes the proxy, not the destination**, so a throwaway on a proxy that refuses its destination fails on load, as a saved site does.
- **Throwaway settings are fixed** at the safe defaults plus the inherited route. `6c`'s switches on a throwaway change only the running page's record, which nothing reads again.
- **A saved site typed while its own container is open lower in the stack gets a second container** (Design question 2). The engine keys sessions by site id, so the newer open replaces the native session; after popping back, the lower container's back, forward, reload and find act on nothing until it is opened again.
- **Throwaways are not counted in Today's tally** or the menu's `<n> BLOCKED`. `BlockedTallyController` counts only sessions whose site is in the open vault, and a throwaway is not until it is saved.
- **A find count carries no query.** The shown count is dropped on every change, but a count WebView reports late for earlier text can show against the current text until the next report.
- **The search engine reads as DuckDuckGo until its setting has loaded**, which is only the instant after a container opens; the route watches it from then on.
- **Every lock closes every container**, `9b` included (the §1 fix's accepted cost). Unlocking lands on the dashboard, and every throwaway is wiped.
- **The save bar follows the first finished load**, and a load that failed also finishes.
- **A bare Unicode host is searched for, not loaded** (Design question 4).
- **With the keyboard up, the first system back goes to the keyboard**: Android closes the IME, and a second back leaves editing or find.
- **`8a`'s opening checklist does not shorten a long host.** Its pill's host text is not flexible, so a host too long for a phone overflows it for the moment the checklist shows. Found by Task 12's phone-width test and left alone: `8a` is not a screen this plan changes.
- **Line icons are on the container screen and its new widgets only.** Every other screen keeps its Unicode glyphs until project 4.
- **WebView's callback order on a device is untested.** `NavigationTracker` is JVM-tested against callback sequences written by hand; what a real WebView sends, and in what order, is Task 14 Step 7's to see.
- **Not verified on a device** until the orchestrator runs Task 14 Step 7.

## Handoff

- **Project 2 (tabs)** takes over the pushed-`ContainerRoute` stack, `N OPEN` and the `2c` switcher. `throwawaySitesProvider` already lists the vault's live throwaways, navigation state is per site id (`navigationForSiteProvider`), and `ContainerRoute(site:, initialUrl:, throwaway:)` opens any of them.
- **Project 3 (privacy controls)** adds rows to `BrowserMenuSheet` — a constructor callback each, wired through `ContainerScreen._openMenu`'s `closing` like the rest — and extends `6c` (`SiteSheet`), which the pill's shield opens (`ContainerScreen.onSiteDetails`).
- **Project 4 (restyle)** extends `AppGlyph`/`AppIcon` and `IconTap` (`lib/ui/core/`) and replaces the glyphs left elsewhere: `‹` on Today, Search, Scripts, Workspaces, the reader, `8b` and `8c`; `⋯` on the dashboard; `◉` in the switcher; `›` in `SettingRow`.
- **The engine** now carries `navigation()`/`navigationState`, `findResults()`, `goBack`/`goForward`/`stop`/`loadUrl`/`find`/`findNext`/`clearFind`/`keep` and `open(…, throwaway:)`. Kotlin's `ContainerView.load` refuses every scheme but http/https (`isLoadableUrl`), and `ThrowawayJournal` sits beside `PendingDeletions`, which it stores through and does not replace.
- **Settings** can store text (`SettingsRepository.getString`/`setString`); `searchEngineProvider` is the open vault's engine; `SettingsRoute` and `settingsDestination` are public in `lib/ui/features/settings/views/settings_route.dart`.
- **`sitesMatching`** (`lib/domain/site_search.dart`) is the one name-or-host matcher, shared by search and the address bar's suggestions.

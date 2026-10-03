# Dashboard redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dashboard quick to use: a bottom tab bar (Sites · Today · Settings), workspace chips, one list with open sites first, a search field in place of `+ Add site`, a per-vault default route, add-site defaults, and a sideways swipe between open containers.

**Architecture:** A new domain type, `ProxyRoute`, holds a route apart from any site. It is stored per vault in `app_settings` and used in two places: by the dashboard's search field, through `destinationFor`/`suggestionsFor` with no opener site, and as the add-site form's starting route. `DashboardScreen` becomes a shell holding three tabs. The old dashboard body moves into `SitesTab`, which gets chips, the reordered list and the search field. The container's bottom bar gains a horizontal drag. A pure `swipeNeighbours` picks which container a drag leads to.

**Tech Stack:** Flutter stable (3.47) / Dart 3, `flutter_riverpod` 2.6, `sqflite_sqlcipher` (host tests: `sqflite_common_ffi`). No new dependency. No Kotlin change.

**Spec:** `docs/superpowers/specs/2026-10-03-dashboard-redesign-design.md` (commit `4a3d480`, branch `dashboard-redesign`). Read it first. This plan argues from it.

## Global Constraints

- Android only, dark theme only.
- No network request of the app's own. Nothing is fetched while typing (spec §3: "No new network request of any kind").
- Jade `#7FC8A9` (`C.jade`) is live state or the single affirmative action on a screen, never decoration. The tabs and chips use no jade. The footer's `+` is jade only on an empty workspace (spec §4.4).
- Hairline dividers, not cards. IBM Plex Mono (`mono(...)`) for anything technical, Figtree (`ui(...)`) for everything else.
- Copy is verbatim. New strings, approved 2026-10-03: `Sites`, `Default route`, and `<MODE> · <host>:<port>` (e.g. `SOCKS5 · 127.0.0.1:9050`). Reused: `Search or type an address`, `Today`, `Settings`, `Direct`, `Add site`, `New workspace`, `WIPES ON EXIT`, the suggestion rows and tags. **Add no other user-facing string.**
- Two-vault decoy model: the default route is a per-vault setting (`app_settings`). Decoy re-sync does not copy it. No code asks which vault is open.
- **Nothing falls back to direct.** A proxy that cannot be reached refuses the page (`8b`). A default route that cannot be read is refused too, never direct.
- No leak count anywhere. `N SESSIONS` is removed from the dashboard (user's ruling 5), and nothing replaces it.
- `test/no_glyphs_test.dart` must keep passing: every icon is an `AppIcon`. No Unicode glyph and no Material `Icons.*`.
- `flutter analyze` and `flutter test` never compile Kotlin. This plan changes no Kotlin, but Task 9 still runs `flutter build apk --debug`.
- Flutter and Gradle commands need the Bash sandbox disabled (`dangerouslyDisableSandbox: true`).

## Review Focus

These are the inputs most likely to hurt someone that the spec implies but does not spell out. Each line names its pinning test and the task that owns it.

1. **A stored default route that cannot be read** (corrupt JSON, an unknown mode). Expected: it is treated as a proxy with no address, so every open is refused. It never becomes Direct. Test: `proxy_route_test.dart`, "a stored route that cannot be read is refused, never direct" (Task 1).
2. **Typing or pressing Enter before the default route has loaded.** Expected: no suggestion rows are offered, and Enter opens nothing. Nothing goes out on a guessed route. Test: `dashboard_search_test.dart`, "nothing is offered or opened before the default route is read" (Task 7).
3. **System back while the search field holds text.** Expected: the text clears and the list comes back. The app does not go to the background. Test: `dashboard_search_test.dart`, "back while searching clears the field and stays" (Task 7).
4. **Typing the host of a saved site whose container is already open.** Expected: that container is shown and loads the address. No second container opens. Test: `dashboard_search_test.dart`, "a saved site that is already open is shown, not opened twice" (Task 7).
5. **A swipe on the bottom bar with only one container, or a tap that moves a little.** Expected: nothing switches, and the tapped button still acts. Tests: `chrome_bars_test.dart`, "a short drag does not switch and a tap still taps" and "with no neighbour a fling does nothing" (Task 8).

## Decisions this plan makes (for the user's review)

Each one is a place where the spec is silent, or where taking it literally does not work.

- **D1. The swipe follows the order containers were opened in, not `2c`'s order. This deviates from spec §9.** `2c` lists the viewed container first, then the most recently viewed. Every swipe changes which container is viewed, so `2c`'s order is rebuilt after each one. A swipe left from X reaches the next container, A. `2c` then reads `[A, X, …]`, where A is first and has nothing before it, so a swipe right does nothing and another swipe left goes back to X. In that order, left would toggle between two containers forever and right would never work. Opening order does not move: left goes to the container opened after this one, right to the one before. Both ends do nothing, as the spec says. **Asked in the plan review.**
- **D2.** The Default route screen's proxy switch has **no subtitle**, because the add-site form's `This site only` would be wrong there. "Separate login per site" keeps `Tor gives this site its own circuit`, since every throwaway is a site of its own. No new string.
- **D3.** The `WIPES ON EXIT` badge stays, fixed at the right end of the chip row, for a wipe-on-exit workspace. Spec §4.1 removes the dropdown, `⋯` and `N SESSIONS`, not this badge.
- **D4.** The tab bar is hidden while the keyboard is up. Otherwise the search field would sit a tab bar's height above the keyboard.
- **D5.** The default route is saved on every change, and again when you leave its screen, by its back icon or by system back. It has no Save button, which matches how the other Settings choices save without one.
- **D6.** A blank NAME (empty or only spaces) also takes the host's monogram, as `buildThrowaway` does. This applies to an edited site too, since `buildSite` is shared.
- **D7.** System back while the search field holds text clears it (Review Focus 3).

## File structure

| File | Task | Responsibility |
|---|---|---|
| `lib/domain/models/proxy_route.dart` (new) | 1 | `ProxyRoute`: a route apart from any site; ruling 8; stored form; row label |
| `lib/ui/features/settings/view_models/providers.dart` | 1, 3 | `defaultRouteProvider`, `SettingsController.setDefaultRoute` |
| `lib/domain/models/destination.dart` | 2 | `destinationFor`/`resolveDestination` with optional `current` and a `route` |
| `lib/domain/models/address_suggestion.dart` | 2 | `suggestionsFor` with optional `current`; `submittedSuggestion` |
| `lib/domain/models/throwaway.dart` | 2 | `buildThrowaway` takes `workspaceId` |
| `lib/domain/tabs.dart` | 2, 8 | back from a throwaway with no opener; `swipeNeighbours` |
| `lib/ui/features/add_site/views/form_toggle_row.dart` (new) | 3 | the form's switch row, shared |
| `lib/ui/features/add_site/views/route_fields.dart` (new) | 3 | the proxy switch through the login fields, shared by `2a` and Default route |
| `lib/ui/features/add_site/views/network_tab.dart` | 3 | uses `RouteFields` |
| `lib/ui/features/settings/views/default_route_screen.dart` (new) | 3 | `DefaultRouteScreen` (pure) and `DefaultRouteRoute` |
| `lib/ui/core/widgets/setting_row.dart` | 3 | `monoValue` |
| `lib/ui/features/settings/views/settings_screen.dart`, `settings_route.dart` | 3, 5 | Default route row; optional back |
| `lib/ui/features/add_site/view_models/add_site_view.dart` | 4 | blank-name rule; ruling 8 through `ProxyRoute.fromForm` |
| `lib/ui/features/add_site/views/add_site_screen.dart`, `basics_tab.dart` | 4 | autofocus, starting workspace, starting route |
| `lib/ui/core/icons.dart` | 5 | `sites`, `today`, `settings` glyphs |
| `lib/ui/features/report/views/today_screen.dart`, `today_route.dart` | 5 | optional back |
| `lib/ui/features/dashboard/views/dashboard_tab_bar.dart` (new) | 5 | `DashboardTab`, `DashboardTabBar` |
| `lib/ui/features/dashboard/views/dashboard_screen.dart` | 5 | the shell: tabs, back to Sites |
| `lib/ui/features/dashboard/views/sites_tab.dart` (new) | 5, 6, 7 | the Sites tab's wiring |
| `lib/ui/features/dashboard/view_models/dashboard_view.dart`, `providers.dart` | 6 | one ordered list, the viewed workspace id |
| `lib/ui/features/dashboard/views/workspace_chips.dart` (new) | 6 | the chip row |
| `lib/ui/features/dashboard/views/dashboard_body.dart` | 5, 6, 7 | chips, list or suggestions, footer |
| `lib/ui/features/workspaces/views/workspaces_route.dart` | 6 | `createWorkspace`/`editWorkspace`, shared with the chips |
| `lib/ui/features/dashboard/views/dashboard_footer.dart` | 7 | the search field and `+` |
| `lib/ui/features/container/views/container_bottom_bar.dart`, `container_screen.dart`, `container_route.dart` | 2, 7, 8 | the swipe; `submittedSuggestion` |
| Deleted | 6, 7 | `workspace_bar.dart`, `workspace_menu.dart`, `search_screen.dart`, `search_view.dart`, and their tests |
| `test/support/dashboard_harness.dart` (new) | 5 | `pumpDashboard`: `DashboardScreen` over fakes |

---

### Task 1: `ProxyRoute` and the stored default route

**Files:**
- Create: `lib/domain/models/proxy_route.dart`
- Modify: `lib/ui/features/settings/view_models/providers.dart`
- Test: `test/domain/proxy_route_test.dart` (new), `test/ui/features/settings/default_route_storage_test.dart` (new)

**Interfaces:**
- Consumes: `ProxyMode`, `Site` (`lib/domain/models/site.dart`); `SettingsRepository.getString/setString`; `settingsRepositoryProvider`; `resyncDecoy({required AppDatabase from, required AppDatabase into})`.
- Produces:
  - `class ProxyRoute { const ProxyRoute({ProxyMode mode = ProxyMode.direct, String? host, int? port, String? user, String? password, bool loginPerSite = false}); static const direct; static const unreadable; factory ProxyRoute.fromForm({required ProxyMode mode, String? host, int? port, String user = '', String password = '', bool loginPerSite = false}); factory ProxyRoute.of(Site site); String get label; String toStored(); static ProxyRoute fromStored(String? stored); }`, with `==`/`hashCode` over every field
  - `const defaultRouteSettingKey = 'default_route'`
  - `final defaultRouteProvider = FutureProvider<ProxyRoute>`
  - `Future<void> SettingsController.setDefaultRoute(ProxyRoute route)`

- [ ] **Step 1: Write the failing domain test**

`test/domain/proxy_route_test.dart`:

```dart
import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fromForm applies ruling 8', () {
    test('a typed login is kept on a proxy, the password exactly as typed', () {
      final route = ProxyRoute.fromForm(
          mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: ' s3cret ');
      expect(route, const ProxyRoute(
          mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: ' s3cret '));
    });

    test('per-site login drops a typed one', () {
      final route = ProxyRoute.fromForm(
          mode: ProxyMode.http, host: 'h', port: 1, user: 'alice', password: 'x', loginPerSite: true);
      expect(route.user, isNull);
      expect(route.password, isNull);
      expect(route.loginPerSite, isTrue);
    });

    test('a password without a user is not kept', () {
      final route = ProxyRoute.fromForm(mode: ProxyMode.socks5, host: 'h', port: 1, password: 'x');
      expect(route.password, isNull);
    });

    test('direct keeps no address, no login and no per-site choice', () {
      final route = ProxyRoute.fromForm(
          mode: ProxyMode.direct, host: 'h', port: 1, user: 'a', password: 'b', loginPerSite: true);
      expect(route, ProxyRoute.direct);
    });
  });

  test("of(site) is the site's own route", () {
    const site = Site(
      id: 's', workspaceId: 'w', name: 'S', monogram: 'S', url: 'https://s.example', profileId: 'p',
      proxyMode: ProxyMode.http, proxyHost: '10.0.0.1', proxyPort: 8080,
      proxyUser: 'u', proxyPassword: 'pw',
    );
    expect(ProxyRoute.of(site), const ProxyRoute(
        mode: ProxyMode.http, host: '10.0.0.1', port: 8080, user: 'u', password: 'pw'));
  });

  test("the row value: Direct, or the mode and address (spec §8)", () {
    expect(ProxyRoute.direct.label, 'Direct');
    expect(const ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050).label,
        'SOCKS5 · 127.0.0.1:9050');
    expect(const ProxyRoute(mode: ProxyMode.http, host: 'proxy.lan', port: 3128).label,
        'HTTP · proxy.lan:3128');
    expect(ProxyRoute.unreadable.label, 'SOCKS5');
  });

  test('a route survives being stored and read back', () {
    const route = ProxyRoute(
        mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw');
    expect(ProxyRoute.fromStored(route.toStored()), route);
    const perSite = ProxyRoute(mode: ProxyMode.http, host: 'h', port: 1, loginPerSite: true);
    expect(ProxyRoute.fromStored(perSite.toStored()), perSite);
  });

  test('nothing stored is Direct', () {
    expect(ProxyRoute.fromStored(null), ProxyRoute.direct);
  });

  test('a stored route that cannot be read is refused, never direct', () {
    for (final stored in ['{not json', '[]', '{"mode":"tor","host":"h","port":1}', '{"mode":7}']) {
      final route = ProxyRoute.fromStored(stored);
      expect(route, ProxyRoute.unreadable, reason: stored);
      expect(route.mode, isNot(ProxyMode.direct), reason: stored);
      expect(route.host, isNull, reason: 'no address: every open refuses it (8b)');
    }
  });
}
```

- [ ] **Step 2: Run it and see it fail**

Run: `flutter test test/domain/proxy_route_test.dart`
Expected: FAIL, because `proxy_route.dart` does not exist.

- [ ] **Step 3: Write `ProxyRoute`**

`lib/domain/models/proxy_route.dart`:

```dart
import 'dart:convert';

import 'site.dart';

/// A route as a site holds it (mode, host, port and Plan 14's login), kept
/// apart from any site: the vault's default route (dashboard spec §7), which a
/// throwaway opened from the dashboard runs on and a new site's form starts
/// from.
class ProxyRoute {
  const ProxyRoute({
    this.mode = ProxyMode.direct,
    this.host,
    this.port,
    this.user,
    this.password,
    this.loginPerSite = false,
  });

  /// The default route until one is chosen.
  static const direct = ProxyRoute();

  /// What a stored route that cannot be read becomes: a proxy with no
  /// address, which every open refuses (`8b`). Never [direct]: it may have
  /// been a proxy, and nothing falls back to direct.
  static const unreadable = ProxyRoute(mode: ProxyMode.socks5);

  /// The route a form describes, with ruling 8 applied: a typed login is kept
  /// only while the proxy is on, per-site login is off and a user was typed.
  /// A direct route keeps no address and no login. Nothing is trimmed.
  factory ProxyRoute.fromForm({
    required ProxyMode mode,
    String? host,
    int? port,
    String user = '',
    String password = '',
    bool loginPerSite = false,
  }) {
    if (mode == ProxyMode.direct) return direct;
    final typed = !loginPerSite && user.isNotEmpty;
    return ProxyRoute(
      mode: mode,
      host: host,
      port: port,
      user: typed ? user : null,
      password: typed ? password : null,
      loginPerSite: loginPerSite,
    );
  }

  /// [site]'s own route, as saved.
  factory ProxyRoute.of(Site site) => ProxyRoute(
        mode: site.proxyMode,
        host: site.proxyHost,
        port: site.proxyPort,
        user: site.proxyUser,
        password: site.proxyPassword,
        loginPerSite: site.proxyLoginPerSite,
      );

  final ProxyMode mode;
  final String? host;
  final int? port;
  final String? user;
  final String? password;
  final bool loginPerSite;

  /// Settings' row value (spec §8): `Direct`, or `SOCKS5 · 127.0.0.1:9050`.
  /// A proxy with no address reads as its mode alone.
  String get label {
    if (mode == ProxyMode.direct) return 'Direct';
    final name = mode.name.toUpperCase();
    return host == null || port == null ? name : '$name · $host:$port';
  }

  /// `app_settings.default_route`'s value, in the encrypted vault.
  String toStored() => jsonEncode({
        'mode': mode.name,
        'host': host,
        'port': port,
        'user': user,
        'password': password,
        'loginPerSite': loginPerSite,
      });

  /// Reads [toStored]'s value. Nothing stored is [direct]. Anything that
  /// cannot be read is [unreadable].
  static ProxyRoute fromStored(String? stored) {
    if (stored == null) return direct;
    try {
      final data = jsonDecode(stored) as Map<String, Object?>;
      final mode = ProxyMode.values.firstWhere((m) => m.name == data['mode']);
      return ProxyRoute(
        mode: mode,
        host: data['host'] as String?,
        port: data['port'] as int?,
        user: data['user'] as String?,
        password: data['password'] as String?,
        loginPerSite: data['loginPerSite'] as bool? ?? false,
      );
    } on Object {
      return unreadable;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ProxyRoute &&
      other.mode == mode &&
      other.host == host &&
      other.port == port &&
      other.user == user &&
      other.password == password &&
      other.loginPerSite == loginPerSite;

  @override
  int get hashCode => Object.hash(mode, host, port, user, password, loginPerSite);
}
```

- [ ] **Step 4: Run it and see it pass**

Run: `flutter test test/domain/proxy_route_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Write the failing storage test**

`test/ui/features/settings/default_route_storage_test.dart`:

```dart
import 'package:container/data/repositories/decoy_provisioner.dart' show resyncDecoy;
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart' show databaseProvider;
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> _vault() =>
    AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);

ProviderContainer _over(AppDatabase database) {
  final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(database)]);
  addTearDown(container.dispose);
  return container;
}

const _socks = ProxyRoute(
    mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw');

void main() {
  setUpAll(sqfliteFfiInit);

  test('the default route is Direct until one is chosen', () async {
    final database = await _vault();
    addTearDown(database.close);
    expect(await _over(database).read(defaultRouteProvider.future), ProxyRoute.direct);
  });

  test('a chosen route is stored in the open vault and read back', () async {
    final database = await _vault();
    addTearDown(database.close);
    final container = _over(database);

    await container.read(settingsControllerProvider).setDefaultRoute(_socks);

    expect(await container.read(defaultRouteProvider.future), _socks);
    expect(await SqliteSettingsRepository(database).getString(defaultRouteSettingKey),
        _socks.toStored());
  });

  test('each vault has its own', () async {
    final real = await _vault();
    final decoy = await _vault();
    addTearDown(real.close);
    addTearDown(decoy.close);

    await _over(real).read(settingsControllerProvider).setDefaultRoute(_socks);

    expect(await _over(decoy).read(defaultRouteProvider.future), ProxyRoute.direct);
  });

  test('decoy re-sync does not copy it: it is a setting, not a site', () async {
    final real = await _vault();
    final decoy = await _vault();
    addTearDown(real.close);
    addTearDown(decoy.close);
    await _over(real).read(settingsControllerProvider).setDefaultRoute(_socks);

    await resyncDecoy(from: real, into: decoy);

    expect(await SqliteSettingsRepository(decoy).getString(defaultRouteSettingKey), isNull);
  });
}
```

- [ ] **Step 6: Run it and see it fail**

Run: `flutter test test/ui/features/settings/default_route_storage_test.dart`
Expected: FAIL to compile, because `defaultRouteProvider`, `defaultRouteSettingKey` and `setDefaultRoute` do not exist yet.

- [ ] **Step 7: Add the provider and the controller method**

In `lib/ui/features/settings/view_models/providers.dart`, add the import beside the other domain imports:

```dart
import '../../../../domain/models/proxy_route.dart';
```

After `vaultSecurityLevelProvider`, add:

```dart
/// `app_settings`' key for the default route (dashboard spec §7).
const defaultRouteSettingKey = 'default_route';

/// The open vault's default route (dashboard spec §7): what the dashboard's
/// search field opens a throwaway on, and where a new site's Network tab
/// starts. Per vault, like the search engine; Direct until chosen. A stored
/// value that cannot be read is refused, never direct (`ProxyRoute.fromStored`).
final defaultRouteProvider = FutureProvider<ProxyRoute>((ref) async {
  final stored = await ref.watch(settingsRepositoryProvider).getString(defaultRouteSettingKey);
  return ProxyRoute.fromStored(stored);
});
```

In `SettingsController`, after `setSecurityLevel`, add:

```dart
  /// The default route (dashboard spec §7). No saved site and no open
  /// container changes: it applies to what is opened next.
  Future<void> setDefaultRoute(ProxyRoute route) async {
    await _ref.read(settingsRepositoryProvider).setString(defaultRouteSettingKey, route.toStored());
    _ref.invalidate(defaultRouteProvider);
  }
```

- [ ] **Step 8: Run both tests and see them pass**

Run: `flutter test test/domain/proxy_route_test.dart test/ui/features/settings/default_route_storage_test.dart`
Expected: PASS (13 tests).

- [ ] **Step 9: Commit**

```bash
git add lib/domain/models/proxy_route.dart lib/ui/features/settings/view_models/providers.dart test/domain/proxy_route_test.dart test/ui/features/settings/default_route_storage_test.dart
git commit -m "feat(settings): a per-vault default route"
```

---

### Task 2: Destinations with no opener

**Files:**
- Modify: `lib/domain/models/destination.dart`, `lib/domain/models/address_suggestion.dart`, `lib/domain/models/throwaway.dart`, `lib/domain/tabs.dart`, `lib/ui/features/container/views/container_route.dart:651-657`, `lib/ui/features/container/views/container_screen.dart:207-221`
- Test: `test/domain/destination_test.dart`, `test/domain/address_suggestion_test.dart`, `test/domain/throwaway_test.dart`, `test/domain/tabs_test.dart`, `test/data/security_level_storage_test.dart:131-135`

**Interfaces:**
- Consumes: `ProxyRoute` (Task 1).
- Produces:
  - `Destination destinationFor(Uri url, {Site? current, ProxyRoute? route, required List<Site> saved})`. It throws `ArgumentError` when both `current` and `route` are null. A throwaway's route is `route ?? ProxyRoute.of(current!)`.
  - `Destination resolveDestination({required AddressInput input, Site? current, ProxyRoute? route, required List<Site> saved, required SearchEngine engine})`
  - `List<AddressSuggestion> suggestionsFor({required String text, Site? current, ProxyRoute? route, required List<Site> saved, required List<Workspace> workspaces, required SearchEngine engine})`
  - `AddressSuggestion? submittedSuggestion(List<AddressSuggestion> rows)`: the address row if there is one, else the search row, else null
  - `Site buildThrowaway({required Throwaway destination, required String workspaceId, required String Function() newId})`
  - `backTarget(...)` returns `CloseThrowawayToDashboard` for a throwaway's first page whose `openerSiteId` is null

- [ ] **Step 1: Write the failing tests**

Append to `test/domain/destination_test.dart`. Add the import `package:container/domain/models/proxy_route.dart`, and put this group inside `main()`:

```dart
  group('with no opener (the dashboard, spec §5)', () {
    const socks = ProxyRoute(
        mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw');

    Destination open(String url, {List<Site> saved = const []}) =>
        destinationFor(Uri.parse(url), route: socks, saved: saved);

    test('a host no site has opens a throwaway on the route given, login and all', () {
      final destination = open('https://news.example.org/today') as Throwaway;
      expect(destination.url.toString(), 'https://news.example.org/today');
      expect((destination.mode, destination.proxyHost, destination.proxyPort),
          (ProxyMode.socks5, '127.0.0.1', 9050));
      expect((destination.proxyUser, destination.proxyPassword), ('alice', 'pw'));
      expect(destination.proxyLoginPerSite, isFalse);
    });

    test("a saved site's host opens its own container, never this one", () {
      final destination = open('https://www.forum.example.com/x', saved: [_forum]);
      expect(destination, isA<SavedSiteContainer>());
      expect((destination as SavedSiteContainer).site.id, 'forum');
    });

    test('a per-site route gives a per-site throwaway', () {
      final destination = destinationFor(Uri.parse('https://a.example'),
          route: const ProxyRoute(mode: ProxyMode.http, host: 'h', port: 1, loginPerSite: true),
          saved: const []) as Throwaway;
      expect(destination.proxyLoginPerSite, isTrue);
      expect(destination.proxyUser, isNull);
    });

    test('a search resolves the same way', () {
      final destination = resolveDestination(
        input: parseAddressInput('two words'),
        route: ProxyRoute.direct,
        saved: const [],
        engine: SearchEngine.duckDuckGo,
      );
      expect(destination, isA<Throwaway>());
      expect((destination as Throwaway).mode, ProxyMode.direct);
      expect(destination.url.host, 'duckduckgo.com');
    });

    test('neither an opener nor a route is a mistake', () {
      expect(() => destinationFor(Uri.parse('https://a.example'), saved: const []),
          throwsArgumentError);
    });
  });
```

Append to `test/domain/address_suggestion_test.dart`. Add the import `package:container/domain/models/proxy_route.dart`, and put these inside `main()`:

```dart
  group('with no opener (the dashboard, spec §5)', () {
    List<AddressSuggestion> dashboard(String text, {ProxyRoute route = ProxyRoute.direct}) =>
        suggestionsFor(
          text: text,
          route: route,
          saved: [_forum, _market],
          workspaces: const [_personal, _work],
          engine: SearchEngine.duckDuckGo,
        );

    test('every saved site opens its own container; nothing is THIS CONTAINER', () {
      final rows = dashboard('example');
      final saved = rows.where((r) => r.kind == SuggestionKind.savedSite).toList();
      expect(saved.map((r) => r.primary), ['Forum', 'Marketplace']);
      expect(saved.map((r) => r.tag).toSet(), {'ITS OWN CONTAINER'});
      expect(rows.map((r) => r.tag), isNot(contains('THIS CONTAINER')));
    });

    test('an unsaved address is a throwaway on the route given', () {
      expect(dashboard('news.example.org').map((r) => r.tag),
          ['THROWAWAY', 'THROWAWAY']);
      const socks = ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050);
      expect(dashboard('news.example.org', route: socks).map((r) => r.tag),
          ['THROWAWAY · SOCKS5', 'THROWAWAY · SOCKS5']);
    });

    test("a saved site's host typed is its own container", () {
      final address = dashboard('market.example.com')
          .firstWhere((r) => r.kind == SuggestionKind.address);
      expect(address.tag, 'ITS OWN CONTAINER');
    });
  });

  group('submittedSuggestion: what the keyboard action opens', () {
    final rows = _for('market.example.com');

    test('the address row when there is one', () {
      expect(submittedSuggestion(rows)!.kind, SuggestionKind.address);
    });

    test('otherwise the search row', () {
      expect(submittedSuggestion(_for('two words'))!.kind, SuggestionKind.search);
    });

    test('nothing for nothing typed', () {
      expect(submittedSuggestion(_for('   ')), isNull);
    });
  });
```

In `test/domain/throwaway_test.dart`, change both `buildThrowaway(` calls. In `_build`:

```dart
  return buildThrowaway(
    destination: destination,
    workspaceId: _current.workspaceId,
    newId: () => 'id${next++}',
  );
```

and in "a throwaway from a per-site container is per-site, on its own profile":

```dart
    final throwaway = buildThrowaway(
        destination: destination, workspaceId: _current.workspaceId, newId: () => 'id${next++}');
```

Then add a test inside `main()`:

```dart
  test('its workspace is the one it is given: the viewed chip from the dashboard', () {
    final throwaway = buildThrowaway(
      destination: Throwaway(Uri.parse('https://news.example.org'), ProxyMode.direct, null, null),
      workspaceId: 'w-work',
      newId: () => 'fresh',
    );
    expect(throwaway.workspaceId, 'w-work');
    expect(throwaway.name, 'news.example.org');
  });
```

In `test/data/security_level_storage_test.dart`'s "a throwaway follows the vault default", the `current:` argument becomes `workspaceId:`:

```dart
    final throwaway = buildThrowaway(
      destination: Throwaway(Uri.parse('https://news.example.org'), ProxyMode.direct, null, null),
      workspaceId: _site.workspaceId,
      newId: () => 'fresh',
    );
```

In `test/domain/tabs_test.dart`, inside the back-target group after "a throwaway with nothing else open is closed to the dashboard", add:

```dart
    test('a throwaway opened from the dashboard is closed to it, even with others open', () {
      final c = _container('t', throwaway: true, pages: const [first]);
      expect(
        backTarget(canGoBack: false, container: c, pageId: 'p1', others: {'b': late}),
        isA<CloseThrowawayToDashboard>(),
      );
    });
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/domain/destination_test.dart test/domain/address_suggestion_test.dart test/domain/throwaway_test.dart test/domain/tabs_test.dart test/data/security_level_storage_test.dart`
Expected: compile errors (`route`, `submittedSuggestion` and `workspaceId` are unknown). Once those compile, the tabs test still fails, returning `ViewContainer('b')`.

- [ ] **Step 3: Change `destination.dart`**

Add `import 'proxy_route.dart';`. Replace `resolveDestination`, `destinationFor` and `_preference` with:

```dart
/// [current] is the site this container was opened for, not the page it is
/// showing now. The dashboard has none (dashboard spec §5). [route] is what a
/// throwaway runs on: [current]'s own route when it is not given. [saved] is
/// every site in the open vault. A search becomes [engine]'s results address
/// first, then follows the same rules, so a suggestion's tag is always where
/// it really opens.
Destination resolveDestination({
  required AddressInput input,
  Site? current,
  ProxyRoute? route,
  required List<Site> saved,
  required SearchEngine engine,
}) {
  final url = switch (input) {
    AddressUrl(:final url) => url,
    AddressSearch(:final query) => engine.resultsFor(query),
    AddressEmpty() => throw ArgumentError.value(input, 'input', 'Nothing to open'),
  };
  return destinationFor(url, current: current, route: route, saved: saved);
}

/// §4.3's rules for an address already decided. With no [current] there is
/// no "this container": a saved site's host opens its own, anything else a
/// throwaway on [route].
Destination destinationFor(
  Uri url, {
  Site? current,
  ProxyRoute? route,
  required List<Site> saved,
}) {
  final via = route ?? (current == null ? null : ProxyRoute.of(current));
  if (via == null) {
    throw ArgumentError('A throwaway needs a route: give current or route');
  }
  final host = normalizeHost(url.host);
  if (current != null && host == normalizeHost(current.host)) return ThisContainer(url);

  final matches = [
    for (final site in saved)
      if (normalizeHost(site.host) == host) site,
  ];
  if (matches.isNotEmpty) {
    matches.sort((a, b) => _preference(a, b, current?.workspaceId));
    return SavedSiteContainer(matches.first, url);
  }

  return Throwaway(url, via.mode, via.host, via.port,
      proxyUser: via.user,
      proxyPassword: via.password,
      proxyLoginPerSite: via.loginPerSite);
}

/// Sites in [workspaceId] first, when there is one, then the most recently
/// visited; never visited last.
int _preference(Site a, Site b, String? workspaceId) {
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

Replace the `Throwaway` class's doc comment with:

```dart
/// Opens a new throwaway container at [url], on the route it is given: the
/// route of the container it was typed in, or the vault's default route from
/// the dashboard. [mode], [proxyHost], [proxyPort] and its proxy login exactly
/// as they are (proxy-auth spec §4).
```

- [ ] **Step 4: Change `address_suggestion.dart`**

Add `import 'proxy_route.dart';`. Replace `suggestionsFor` with the version below, and add `submittedSuggestion` after it:

```dart
/// In order: up to [maxSavedSuggestions] saved sites matching [text] (each
/// opening at its own saved address), the address row when [text] parses as
/// an address, and the search row whenever [text] is not empty. Reads only
/// what it is given (the open vault's sites) and fetches nothing. [current]
/// and [route] are `destinationFor`'s: the dashboard gives a route and no
/// opener.
List<AddressSuggestion> suggestionsFor({
  required String text,
  Site? current,
  ProxyRoute? route,
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
        site.id == current?.id ? ThisContainer(url) : SavedSiteContainer(site, url);
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
    final destination =
        destinationFor(input.url, current: current, route: route, saved: saved);
    rows.add(AddressSuggestion(
      kind: SuggestionKind.address,
      primary: typed,
      secondary: 'not saved',
      tag: destinationTag(destination),
      destination: destination,
    ));
  }

  final search = destinationFor(engine.resultsFor(typed),
      current: current, route: route, saved: saved);
  rows.add(AddressSuggestion(
    kind: SuggestionKind.search,
    primary: 'Search ${engine.label} for “$typed”',
    secondary: engine.host,
    tag: destinationTag(search),
    destination: search,
  ));
  return rows;
}

/// What the keyboard's action opens (browser-chrome spec §6.2): the address
/// row if there is one, otherwise the search row. Null with nothing typed.
/// The container's address bar and the dashboard's field both use it.
AddressSuggestion? submittedSuggestion(List<AddressSuggestion> rows) {
  AddressSuggestion? search;
  for (final row in rows) {
    if (row.kind == SuggestionKind.address) return row;
    if (row.kind == SuggestionKind.search) search ??= row;
  }
  return search;
}
```

- [ ] **Step 5: Change `throwaway.dart`**

Replace `buildThrowaway` and its doc comment's last three sentences:

```dart
/// The in-memory [Site] a throwaway container runs as (spec §5.1). Nothing
/// writes it to the vault until the user saves it.
///
/// Only the route, its proxy login included, is inherited, carried by
/// [destination]. Every other field is `Site()`'s default (trackers,
/// WebRTC and fingerprinting blocked, no hardware or clipboard access, no
/// custom CSS or JS, the Android user agent, force-dark on), so a throwaway
/// never inherits another site's grants. Its id is fresh, so no library
/// script applied to another site selects it either. [workspaceId] is the
/// workspace it counts under and its save form defaults to: its opener's, or
/// the dashboard's viewed chip (dashboard spec §5). [newId] makes the id and
/// the profile id (`newProfileId` in the app). With per-site login on, the
/// fresh profile id gives the throwaway its own login.
Site buildThrowaway({
  required Throwaway destination,
  required String workspaceId,
  required String Function() newId,
}) {
  final host = destination.url.host;
  return Site(
    id: newId(),
    profileId: newId(),
    workspaceId: workspaceId,
    name: host,
    monogram: suggestMonogram(host),
    url: destination.url.toString(),
    cookiePolicy: CookiePolicy.wipeOnExit,
    proxyMode: destination.mode,
    proxyHost: destination.proxyHost,
    proxyPort: destination.proxyPort,
    proxyUser: destination.proxyUser,
    proxyPassword: destination.proxyPassword,
    proxyLoginPerSite: destination.proxyLoginPerSite,
  );
}
```

- [ ] **Step 6: Change `tabs.dart`**

Change the `CloseThrowawayToDashboard` doc to:

```dart
/// A throwaway opened from the dashboard (dashboard spec §5), or one with
/// nothing else open: closed, wiped, dashboard.
```

In `backTarget`, after `if (!container.throwaway) return const LeaveToDashboard();`, insert:

```dart
  // Opened from the dashboard: back goes there, even with others open.
  if (container.openerSiteId == null) return const CloseThrowawayToDashboard();
```

- [ ] **Step 7: Update the two app call sites**

In `lib/ui/features/container/views/container_route.dart` `_openDestination`, change the throwaway case to:

```dart
      case final Throwaway target:
        final throwaway = buildThrowaway(
          destination: target,
          workspaceId: _routeSite(viewed).workspaceId,
          newId: newProfileId,
        );
        showContainer(context, ref, throwaway, throwaway: true, openerSiteId: viewed.siteId);
```

In `lib/ui/features/container/views/container_screen.dart`, replace `_submitAddress` with:

```dart
  /// The keyboard's action opens the address row if there is one, otherwise
  /// the search row. With nothing typed there is neither, and editing ends.
  void _submitAddress(String text) {
    final pick = submittedSuggestion(widget.suggest(text));
    if (pick == null) {
      _stopEditing();
    } else {
      _open(pick);
    }
  }
```

- [ ] **Step 8: Run the tests and see them pass**

Run: `flutter test test/domain test/data/security_level_storage_test.dart test/ui/features/container_screen_test.dart test/ui/features/container/address_and_menu_test.dart test/ui/features/container_route_test.dart`
Expected: PASS. The existing address-bar tests pass unchanged, because their `current:` calls still compile and behave as before.

- [ ] **Step 9: Analyze and commit**

Run: `flutter analyze`. Expected: `No issues found!`

```bash
git add lib/domain lib/ui/features/container/views/container_route.dart lib/ui/features/container/views/container_screen.dart test/domain test/data/security_level_storage_test.dart
git commit -m "feat(domain): destinations with no opener, on a given route"
```

---

### Task 3: Route fields shared, and the Default route screen

**Files:**
- Create: `lib/ui/features/add_site/views/form_toggle_row.dart`, `lib/ui/features/add_site/views/route_fields.dart`, `lib/ui/features/settings/views/default_route_screen.dart`
- Modify: `lib/ui/features/add_site/views/network_tab.dart`, `lib/ui/core/widgets/setting_row.dart`, `lib/ui/features/settings/views/settings_screen.dart`, `lib/ui/features/settings/views/settings_route.dart`
- Test: `test/ui/features/settings/default_route_screen_test.dart` (new), `test/ui/features/settings_test.dart`, `test/ui/features/dashboard/settings_destination_test.dart`

**Interfaces:**
- Consumes: `ProxyRoute`, `defaultRouteProvider`, `SettingsController.setDefaultRoute` (Task 1).
- Produces:
  - `class FormToggleRow extends StatelessWidget { const FormToggleRow({Key? key, required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged, Key? switchKey}); }`
  - `class RouteFields extends StatelessWidget { const RouteFields({Key? key, required bool proxyEnabled, required ValueChanged<bool> onProxyEnabledChanged, String? proxySubtitle, required ProxyMode proxyMode, required ValueChanged<ProxyMode> onProxyModeChanged, required TextEditingController hostController, required TextEditingController portController, required bool loginPerSite, required ValueChanged<bool> onLoginPerSiteChanged, required TextEditingController userController, required TextEditingController passwordController}); }`. It keeps the keys `proxy-enabled`, `proxy-login-per-site`, `proxy-user` and `proxy-password`.
  - `class DefaultRouteScreen extends StatefulWidget { const DefaultRouteScreen({Key? key, required ProxyRoute initial, required ValueChanged<ProxyRoute> onDone}); }`
  - `class DefaultRouteRoute extends ConsumerWidget`
  - `SettingRow(..., bool monoValue = false)`
  - `SettingsScreen(..., String defaultRouteLabel = '', bool defaultRouteMono = false)`. Its row reports `onTap('defaultRoute')`.
  - `settingsDestination('defaultRoute')` returns a `DefaultRouteRoute`.

- [ ] **Step 1: Write the failing tests**

`test/ui/features/settings/default_route_screen_test.dart`:

```dart
import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/settings/views/default_route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

/// [DefaultRouteScreen] pushed over a home route, so leaving it is a real pop.
Future<List<ProxyRoute>> _pump(WidgetTester tester, ProxyRoute initial) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1000);
  tester.view.devicePixelRatio = 1;
  final done = <ProxyRoute>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (_) => DefaultRouteScreen(initial: initial, onDone: done.add),
        )),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return done;
}

Future<void> _systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("it is titled Default route and holds the route fields only", (tester) async {
    await _pump(tester, ProxyRoute.direct);

    expect(find.text('Default route'), findsOneWidget);
    expect(findIconTap('Back'), findsOneWidget);
    expect(find.text('Route through proxy'), findsOneWidget);
    expect(find.text('SOCKS5'), findsOneWidget);
    expect(find.text('HTTP'), findsOneWidget);
    expect(find.text('HOST'), findsOneWidget);
    expect(find.text('PORT'), findsOneWidget);
    // Per site, not route (spec §7), and no "This site only" (plan D2).
    expect(find.text('Block WebRTC'), findsNothing);
    expect(find.text('Block trackers and ads'), findsNothing);
    expect(find.text('This site only'), findsNothing);
  });

  testWidgets('it starts from the stored route', (tester) async {
    await _pump(tester, const ProxyRoute(
        mode: ProxyMode.http, host: 'proxy.lan', port: 3128, user: 'alice', password: 'pw'));

    expect(find.text('proxy.lan'), findsOneWidget);
    expect(find.text('3128'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('Separate login per site'), findsOneWidget);
  });

  testWidgets('the back icon leaves with the route as set, ruling 8 applied', (tester) async {
    final done = await _pump(tester, ProxyRoute.direct);

    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pump();
    await tester.enterText(
        find.descendant(of: find.byKey(const Key('proxy-user')), matching: find.byType(TextField)),
        'alice');
    await tester.enterText(
        find.descendant(of: find.byKey(const Key('proxy-password')), matching: find.byType(TextField)),
        'pw');
    await tester.tap(findIconTap('Back'));
    await tester.pumpAndSettle();

    expect(done, [
      const ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw'),
    ]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('system back saves too; turning the proxy off is Direct', (tester) async {
    final done = await _pump(tester,
        const ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050));

    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pump();
    await _systemBack(tester);

    expect(done, [ProxyRoute.direct]);
  });
}
```

`Key('proxy-user')` and `Key('proxy-password')` name the `Container` around each field, as in `add_site_login_test.dart`, so `enterText` finds the `TextField` under it.

In `test/ui/features/settings_test.dart`, add `defaultRouteLabel: 'SOCKS5 · 127.0.0.1:9050', defaultRouteMono: true,` to the shared `pump`'s `SettingsScreen(` call, after `securityLevelName: 'Standard',`. Then add:

```dart
  testWidgets('BROWSING has Default route, its proxy value in mono, and it reports a tap',
      (tester) async {
    final taps = <String>[];
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: false, biometricsAvailable: true, autoLockLabel: 'After 1 min',
        decoyEnabled: false, decoySiteCount: 0, hideFromSwitcher: true, panicOnFlip: false,
        onPanicLabel: 'Wipe + lock', searchEngineName: 'DuckDuckGo', securityLevelName: 'Standard',
        defaultRouteLabel: 'SOCKS5 · 127.0.0.1:9050', defaultRouteMono: true,
        onChanged: (_, __) {}, onTap: taps.add, onBack: () {},
      ),
    ));

    expect(find.text('Default route'), findsOneWidget);
    final value = tester.widget<Text>(find.text('SOCKS5 · 127.0.0.1:9050'));
    expect(value.style!.fontFamily, mono(size: 12).fontFamily);
    await tester.tap(find.text('Default route'));
    expect(taps, ['defaultRoute']);
  });
```

Add `import 'package:container/ui/core/typography.dart';` to `settings_test.dart` for `mono`.

In `test/ui/features/dashboard/settings_destination_test.dart`, add `import 'package:container/ui/features/settings/views/default_route_screen.dart';` and, in "Settings rows lead to their screens":

```dart
    expect(settingsDestination('defaultRoute'), isA<DefaultRouteRoute>());
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/ui/features/settings/default_route_screen_test.dart test/ui/features/settings_test.dart test/ui/features/dashboard/settings_destination_test.dart`
Expected: compile errors (`default_route_screen.dart`, `defaultRouteLabel` and `DefaultRouteRoute` are missing).

- [ ] **Step 3: Extract `FormToggleRow`**

`lib/ui/features/add_site/views/form_toggle_row.dart`. This is `NetworkTab`'s `_toggleRow` and `_switch`, moved with no visual change. The subtitle is optional (D2):

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// A form line with a title, an optional subtitle and the add-site form's own
/// switch: `2a`'s Network tab and the Default route screen.
class FormToggleRow extends StatelessWidget {
  const FormToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.switchKey,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// On the switch itself, for tests: `proxy-enabled`, `proxy-login-per-site`.
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ui(size: 14, color: C.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: ui(size: 11, color: C.textFaint)),
              ],
            ],
          ),
        ),
        GestureDetector(
          key: switchKey,
          onTap: () => onChanged(!value),
          child: Container(
            width: 44,
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: value ? C.jade : C.trackOff,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? C.bg : C.knobOff,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Extract `RouteFields`**

`lib/ui/features/add_site/views/route_fields.dart`. This is `NetworkTab`'s lines from "Route through proxy" through the login fields, moved:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../domain/models/site.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import 'form_toggle_row.dart';

/// A route's fields (dashboard spec §7): the proxy switch, SOCKS5/HTTP, HOST,
/// PORT, and Plan 14's login. `2a`'s Network tab and the Default route screen
/// both use it, so the two never differ. [proxySubtitle] is the switch's
/// subtitle: `2a`'s "This site only", none on Default route (plan D2).
class RouteFields extends StatelessWidget {
  const RouteFields({
    super.key,
    required this.proxyEnabled,
    required this.onProxyEnabledChanged,
    this.proxySubtitle,
    required this.proxyMode,
    required this.onProxyModeChanged,
    required this.hostController,
    required this.portController,
    required this.loginPerSite,
    required this.onLoginPerSiteChanged,
    required this.userController,
    required this.passwordController,
  });

  final bool proxyEnabled;
  final ValueChanged<bool> onProxyEnabledChanged;
  final String? proxySubtitle;
  final ProxyMode proxyMode;
  final ValueChanged<ProxyMode> onProxyModeChanged;
  final TextEditingController hostController;
  final TextEditingController portController;
  final bool loginPerSite;
  final ValueChanged<bool> onLoginPerSiteChanged;
  final TextEditingController userController;
  final TextEditingController passwordController;

  static final _label = T.sectionLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormToggleRow(
          title: 'Route through proxy',
          subtitle: proxySubtitle,
          value: proxyEnabled,
          onChanged: onProxyEnabledChanged,
          switchKey: const Key('proxy-enabled'),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _modeChip('SOCKS5', ProxyMode.socks5)),
            const SizedBox(width: 8),
            Expanded(child: _modeChip('HTTP', ProxyMode.http)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HOST', style: _label),
                  const SizedBox(height: 7),
                  _field(hostController),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PORT', style: _label),
                  const SizedBox(height: 7),
                  _field(portController),
                ],
              ),
            ),
          ],
        ),
        // Proxy-auth spec §1: only while the proxy is on.
        if (proxyEnabled) ...[
          const SizedBox(height: 18),
          FormToggleRow(
            title: 'Separate login per site',
            subtitle: 'Tor gives this site its own circuit',
            value: loginPerSite,
            onChanged: onLoginPerSiteChanged,
            switchKey: const Key('proxy-login-per-site'),
          ),
          if (!loginPerSite) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('USERNAME', style: _label),
                      const SizedBox(height: 7),
                      _field(userController, key: const Key('proxy-user'), loginField: true),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PASSWORD', style: _label),
                      const SizedBox(height: 7),
                      _field(passwordController,
                          key: const Key('proxy-password'), loginField: true, obscure: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ],
    );
  }

  /// [loginField]: at most 255 characters (ruling 9), no autocorrect or
  /// suggestions. [obscure] masks it, with no reveal control (spec §1).
  Widget _field(TextEditingController controller,
          {Key? key, bool loginField = false, bool obscure = false}) =>
      Container(
        key: key,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line09),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: !loginField,
          enableSuggestions: !loginField,
          inputFormatters: loginField ? [LengthLimitingTextInputFormatter(255)] : null,
          style: mono(size: 13, color: C.textSecondary),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      );

  Widget _modeChip(String label, ProxyMode mode) {
    final selected = proxyMode == mode;
    return GestureDetector(
      onTap: () => onProxyModeChanged(mode),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? C.selected : null,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? C.line10 : C.line07),
        ),
        child: Text(label,
            style: ui(size: 12, weight: 500, color: selected ? C.textPrimary : C.tabInactive)),
      ),
    );
  }
}
```

- [ ] **Step 5: Make `NetworkTab` use them**

Replace `NetworkTab.build` and delete its `_label`, `_field`, `_modeChip`, `_toggleRow` and `_switch`. Its constructor and fields are unchanged. Imports become `flutter/material.dart`, `site.dart`, `form_toggle_row.dart` and `route_fields.dart`:

```dart
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RouteFields(
          proxyEnabled: proxyEnabled,
          onProxyEnabledChanged: onProxyEnabledChanged,
          proxySubtitle: 'This site only',
          proxyMode: proxyMode,
          onProxyModeChanged: onProxyModeChanged,
          hostController: hostController,
          portController: portController,
          loginPerSite: loginPerSite,
          onLoginPerSiteChanged: onLoginPerSiteChanged,
          userController: userController,
          passwordController: passwordController,
        ),
        const SizedBox(height: 18),
        FormToggleRow(
          title: 'Block WebRTC',
          subtitle: 'Prevents real IP leaking past the proxy',
          value: blockWebRtc,
          onChanged: onBlockWebRtcChanged,
        ),
        const SizedBox(height: 14),
        FormToggleRow(
          title: 'Block trackers and ads',
          subtitle: 'Local filter lists · 42 rules matched today',
          value: blockTrackers,
          onChanged: onBlockTrackersChanged,
        ),
      ],
    );
  }
```

- [ ] **Step 6: Write the Default route screen**

`lib/ui/features/settings/views/default_route_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/proxy_route.dart';
import '../../../../domain/models/site.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../add_site/views/route_fields.dart';
import '../view_models/providers.dart';

/// Dashboard spec §7: the vault's default route, edited with `2a`'s own route
/// fields. Leaving the screen, by its back icon or system back, reports the
/// route as set ([onDone]), with ruling 8 applied (plan D5: no Save button).
/// It is reported on every change as well as on leaving: a lock tears the
/// screen down without popping it, which would otherwise drop the edits.
class DefaultRouteScreen extends StatefulWidget {
  const DefaultRouteScreen({super.key, required this.initial, required this.onDone});

  final ProxyRoute initial;
  final ValueChanged<ProxyRoute> onDone;

  @override
  State<DefaultRouteScreen> createState() => _DefaultRouteScreenState();
}

class _DefaultRouteScreenState extends State<DefaultRouteScreen> {
  // A new site's form starts from 127.0.0.1:9050 when it has no address;
  // this screen does the same, so the two read alike.
  late final _host = TextEditingController(text: widget.initial.host ?? '127.0.0.1');
  late final _port = TextEditingController(text: (widget.initial.port ?? 9050).toString());
  late final _user = TextEditingController(text: widget.initial.user ?? '');
  late final _password = TextEditingController(text: widget.initial.password ?? '');
  late bool _enabled = widget.initial.mode != ProxyMode.direct;
  late ProxyMode _mode =
      widget.initial.mode == ProxyMode.http ? ProxyMode.http : ProxyMode.socks5;
  late bool _perSite = widget.initial.loginPerSite;

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  ProxyRoute _route() => ProxyRoute.fromForm(
        mode: _enabled ? _mode : ProxyMode.direct,
        host: _host.text,
        port: int.tryParse(_port.text),
        user: _user.text,
        password: _password.text,
        loginPerSite: _perSite,
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) widget.onDone(_route());
      },
      child: Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    IconTap(
                      glyph: AppGlyph.back,
                      label: 'Back',
                      onTap: () => Navigator.maybePop(context),
                      size: 20,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 10),
                    Text('Default route', style: T.screenTitle),
                  ],
                ),
              ),
              const Divider(height: 1, color: C.line06),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    RouteFields(
                      proxyEnabled: _enabled,
                      onProxyEnabledChanged: (v) => setState(() => _enabled = v),
                      proxyMode: _mode,
                      onProxyModeChanged: (v) => setState(() => _mode = v),
                      hostController: _host,
                      portController: _port,
                      loginPerSite: _perSite,
                      onLoginPerSiteChanged: (v) => setState(() => _perSite = v),
                      userController: _user,
                      passwordController: _password,
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
}

/// [DefaultRouteScreen] against the open vault: Settings ▸ BROWSING's
/// `Default route` row. Changing it touches no saved site and no open
/// container (spec §7).
class DefaultRouteRoute extends ConsumerWidget {
  const DefaultRouteRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = ref.watch(defaultRouteProvider).valueOrNull;
    if (initial == null) return const Scaffold(backgroundColor: C.bg);
    final settings = ref.read(settingsControllerProvider);
    return DefaultRouteScreen(initial: initial, onDone: settings.setDefaultRoute);
  }
}
```

The `when`-free `valueOrNull` is deliberate. While the save is in flight, `invalidate` keeps the previous value (Riverpod's refresh), so the screen is not rebuilt from scratch during its own pop.

- [ ] **Step 7: `SettingRow.monoValue`, the row, the destination**

In `lib/ui/core/widgets/setting_row.dart`, add the field `this.monoValue = false,` to the constructor, with the doc `/// [value] in mono: an address, as everything technical (spec §8).` and `final bool monoValue;`. Change the value line to:

```dart
              if (value != null)
                Text(value!,
                    style: monoValue
                        ? mono(size: 12, color: C.textMuted)
                        : ui(size: 12.5, color: C.textMuted)),
```

In `SettingsScreen`, add the constructor parameters `this.defaultRouteLabel = '',` and `this.defaultRouteMono = false,`, with these fields:

```dart
  /// The default route's row value (dashboard spec §8); empty while it loads.
  final String defaultRouteLabel;

  /// True when [defaultRouteLabel] is a proxy's address, shown in mono.
  final bool defaultRouteMono;
```

and, in BROWSING, between "Search engine" and "Security level":

```dart
                  SettingRow(
                    title: 'Default route',
                    value: defaultRouteLabel,
                    monoValue: defaultRouteMono,
                    onTap: () => onTap('defaultRoute'),
                  ),
```

In `settings_route.dart`, add `import '../../../../domain/models/site.dart';` and `import 'default_route_screen.dart';`. Add `'defaultRoute' => const DefaultRouteRoute(),` to `settingsDestination`. In `SettingsRoute.build`, add `final defaultRoute = ref.watch(defaultRouteProvider).valueOrNull;` and pass:

```dart
      defaultRouteLabel: defaultRoute?.label ?? '',
      defaultRouteMono: defaultRoute != null && defaultRoute.mode != ProxyMode.direct,
```

`settingsDestination`'s doc comment needs no change: `defaultRoute` opens a screen, like `changePin`.

- [ ] **Step 8: Run the tests and see them pass**

Run: `flutter test test/ui/features/settings test/ui/features/settings_test.dart test/ui/features/dashboard/settings_destination_test.dart test/ui/features/add_site_test.dart test/ui/features/add_site_login_test.dart test/ui/features/dashboard/dashboard_site_actions_test.dart`
Expected: PASS. The add-site tests pass unchanged, which shows the extraction moved the fields without changing them.

- [ ] **Step 9: Analyze and commit**

Run: `flutter analyze`. Expected: no issues.

```bash
git add lib/ui/features/add_site/views lib/ui/core/widgets/setting_row.dart lib/ui/features/settings test/ui/features/settings test/ui/features/settings_test.dart test/ui/features/dashboard/settings_destination_test.dart
git commit -m "feat(settings): Default route row and screen, sharing 2a's route fields"
```

---

### Task 4: The add-site form's defaults

**Files:**
- Modify: `lib/ui/features/add_site/view_models/add_site_view.dart`, `lib/ui/features/add_site/views/add_site_screen.dart`, `lib/ui/features/add_site/views/basics_tab.dart`
- Test: `test/ui/features/add_site_test.dart`, `test/ui/features/add_site_login_test.dart`

**Interfaces:**
- Consumes: `ProxyRoute`, `ProxyRoute.fromForm`, `ProxyRoute.of` (Task 1); `suggestMonogram` (`lib/domain/models/monogram_suggestion.dart`).
- Produces:
  - `AddSiteScreen({Key? key, Site? initial, required List<Workspace> workspaces, required ValueChanged<Site> onSave, int initialTab = 0, String? initialWorkspaceId, ProxyRoute defaultRoute = ProxyRoute.direct})`
  - `BasicsTab(..., FocusNode? addressFocus)`
  - `buildSite` saves a blank name as the address's host, with that host's monogram (D6)

- [ ] **Step 1: Write the failing tests**

Append to `test/ui/features/add_site_login_test.dart`'s `main()`:

```dart
  group('a blank name (dashboard spec §6)', () {
    Site withName(String name, {String monogram = ''}) => buildSite(
          initial: null, url: 'https://www.example.com/x', name: name, monogram: monogram,
          workspaceId: 'ws-personal', cookiePolicy: CookiePolicy.keep, proxyMode: ProxyMode.direct,
          blockWebRtc: true, blockTrackers: true, antiFingerprinting: true,
          allowCamera: false, allowMicrophone: false, allowLocation: false, allowClipboard: false,
          requirePin: false, showInDecoy: false, userAgentMode: UserAgentMode.android,
          forceDark: true, openInReader: false, pageZoom: 100, customCss: '', customJs: '',
        );

    test("saves as the address's host, as typed, with its monogram", () {
      final site = withName('');
      expect(site.name, 'www.example.com');
      expect(site.monogram, suggestMonogram('www.example.com'));
    });

    test('only spaces is blank too', () {
      expect(withName('   ').name, 'www.example.com');
    });

    test('a name typed is kept as typed', () {
      final site = withName('My Example', monogram: 'Me');
      expect((site.name, site.monogram), ('My Example', 'Me'));
    });
  });
```

and add `import 'package:container/domain/models/monogram_suggestion.dart';` and `import 'package:container/domain/models/proxy_route.dart';` to it.

In `test/ui/features/add_site_test.dart`, change `_pump` to take the new parameters:

```dart
Future<void> _pump(WidgetTester tester,
    {ValueChanged<Site>? onSave, String? initialWorkspaceId,
    ProxyRoute defaultRoute = ProxyRoute.direct, Site? initial}) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  return tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(
      initial: initial,
      workspaces: _workspaces,
      initialWorkspaceId: initialWorkspaceId,
      defaultRoute: defaultRoute,
      onSave: onSave ?? (_) {},
    ),
  ));
}

/// Whether the field under [key] holds focus: the keyboard is up on it.
bool _focused(WidgetTester tester, String key) => tester
    .widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)))
    .focusNode
    .hasFocus;
```

Add the import `package:container/domain/models/proxy_route.dart`, then append these tests:

```dart
  group('defaults (dashboard spec §6)', () {
    const forum = Site(
      id: 's1', workspaceId: 'ws-personal', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
    );
    const socks = ProxyRoute(
        mode: ProxyMode.socks5, host: '10.0.2.2', port: 1080, user: 'alice', password: 'pw');

    testWidgets('a new site opens with the keyboard up on ADDRESS', (tester) async {
      await _pump(tester);
      await tester.pump();
      expect(_focused(tester, 'add-site-address'), isTrue);
    });

    testWidgets('an edited site does not', (tester) async {
      await _pump(tester, initial: forum);
      await tester.pump();
      expect(_focused(tester, 'add-site-address'), isFalse);
    });

    testWidgets('WORKSPACE starts on the one given', (tester) async {
      Site? saved;
      await _pump(tester, initialWorkspaceId: 'ws-work', onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.workspaceId, 'ws-work');
    });

    testWidgets('a workspace that is not there falls back to the first', (tester) async {
      Site? saved;
      await _pump(tester, initialWorkspaceId: 'gone', onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.workspaceId, 'ws-personal');
    });

    testWidgets('an empty NAME saves as the host', (tester) async {
      Site? saved;
      await _pump(tester, onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'example.com');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.name, 'example.com');
    });

    testWidgets("a new site's Network tab starts from the default route", (tester) async {
      Site? saved;
      await _pump(tester, defaultRoute: socks, onSave: (s) => saved = s);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('10.0.2.2'), findsOneWidget);
      expect(find.text('1080'), findsOneWidget);
      expect(find.text('alice'), findsOneWidget);

      await tester.tap(find.text('Basics'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('add-site-address')), 'forum.example.com');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect((saved!.proxyMode, saved!.proxyHost, saved!.proxyPort, saved!.proxyUser),
          (ProxyMode.socks5, '10.0.2.2', 1080, 'alice'));
    });

    testWidgets('an edited site shows its own route, not the default', (tester) async {
      await _pump(tester, initial: forum, defaultRoute: socks);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('10.0.2.2'), findsNothing);
      expect(find.text('Separate login per site'), findsNothing, reason: 'the proxy is off');
    });
  });
```

The existing tests that call `_pump(tester, onSave: ...)` keep working because the new parameters have defaults.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/ui/features/add_site_test.dart test/ui/features/add_site_login_test.dart`
Expected: compile errors (`initialWorkspaceId` and `defaultRoute` do not exist). Once those compile, the blank-name tests fail with name `''`.

- [ ] **Step 3: `buildSite` rules**

In `add_site_view.dart`, add `import '../../../../domain/models/monogram_suggestion.dart';` and `import '../../../../domain/models/proxy_route.dart';`. In `buildSite`, replace the three ruling-8 lines and the proxy, name and monogram arguments:

```dart
  // Ruling 8, in one place (ProxyRoute.fromForm): a typed login is kept only
  // while the proxy is on, per-site login is off and a user was typed.
  final route = ProxyRoute.fromForm(
    mode: proxyMode,
    host: proxyHost,
    port: proxyPort,
    user: proxyUser,
    password: proxyPassword,
    loginPerSite: proxyLoginPerSite,
  );
  // Dashboard spec §6: a blank name saves as the address's host, as typed,
  // and takes that host's monogram, as a throwaway saved as a site does
  // (`buildThrowaway`).
  final blank = name.trim().isEmpty;
  final host = Uri.parse(url).host;
  return Site(
    id: initial?.id ?? newProfileId(),
    workspaceId: workspaceId,
    name: blank ? host : name,
    monogram: blank ? suggestMonogram(host) : monogram,
    url: url,
    profileId: initial?.profileId ?? newProfileId(),
    cookiePolicy: cookiePolicy,
    proxyMode: route.mode,
    proxyHost: route.host,
    proxyPort: route.port,
    proxyUser: route.user,
    proxyPassword: route.password,
    proxyLoginPerSite: route.loginPerSite,
```

The rest of the `Site(...)` arguments (`blockWebRtc` onward) are unchanged.

- [ ] **Step 4: The form's starting values**

In `add_site_screen.dart`, add `import '../../../../domain/models/proxy_route.dart';`. Add the constructor parameters `this.initialWorkspaceId,` and `this.defaultRoute = ProxyRoute.direct,`, with:

```dart
  /// The workspace a new site starts in: the dashboard's viewed chip (spec
  /// §6). Ignored when editing, or when it is not among [workspaces].
  final String? initialWorkspaceId;

  /// Where a new site's Network tab starts (spec §6): the vault's default
  /// route. An edited site shows its own.
  final ProxyRoute defaultRoute;
```

In the state, replace the host, port, user and password controllers, and the `_workspaceId`, `_proxyEnabled`, `_proxyMode` and `_loginPerSite` fields, with:

```dart
  /// The route the Network tab starts from.
  late final ProxyRoute _startRoute =
      widget.initial == null ? widget.defaultRoute : ProxyRoute.of(widget.initial!);
  late final _hostController = TextEditingController(text: _startRoute.host ?? '127.0.0.1');
  late final _portController =
      TextEditingController(text: (_startRoute.port ?? 9050).toString());
  late final _userController = TextEditingController(text: _startRoute.user ?? '');
  late final _passwordController = TextEditingController(text: _startRoute.password ?? '');
  late String _workspaceId = widget.initial?.workspaceId ?? _startWorkspace();
  late bool _proxyEnabled = _startRoute.mode != ProxyMode.direct;
  late ProxyMode _proxyMode =
      _startRoute.mode == ProxyMode.http ? ProxyMode.http : ProxyMode.socks5;
  late bool _loginPerSite = _startRoute.loginPerSite;

  /// The keyboard is up on ADDRESS when a new site's form opens (spec §6).
  final _addressFocus = FocusNode();

  String _startWorkspace() {
    for (final workspace in widget.workspaces) {
      if (workspace.id == widget.initialWorkspaceId) return workspace.id;
    }
    return widget.workspaces.first.id;
  }
```

Keep `_urlController`, `_nameController`, `_cssController` and `_jsController` as they are. In `dispose`, add `_addressFocus.dispose();`. At the end of `initState`, add:

```dart
    if (widget.initial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addressFocus.requestFocus();
      });
    }
```

Pass `addressFocus: _addressFocus,` to `BasicsTab(` in `_body`.

In `basics_tab.dart`, add the constructor parameter `this.addressFocus,` and the field `final FocusNode? addressFocus;`. Change the address field call to `_field(key: const Key('add-site-address'), controller: urlController, focusNode: addressFocus),` and `_field` to:

```dart
  Widget _field({required Key key, required TextEditingController controller, FocusNode? focusNode}) =>
      Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line09),
        ),
        child: TextField(
          key: key,
          controller: controller,
          focusNode: focusNode,
          style: ui(size: 13, color: C.textSecondary),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      );
```

`_focused` in the test finds the `TextField` by its key and the `EditableText` under it. That key is on the `TextField` itself here, so the descendant finder works.

- [ ] **Step 5: Run the tests and see them pass**

Run: `flutter test test/ui/features/add_site_test.dart test/ui/features/add_site_login_test.dart test/ui/features/container_route_test.dart test/ui/features/dashboard/dashboard_site_actions_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze and commit**

Run: `flutter analyze`. Expected: no issues.

```bash
git add lib/ui/features/add_site test/ui/features/add_site_test.dart test/ui/features/add_site_login_test.dart
git commit -m "feat(2a): autofocus, starting workspace and route, a blank name is the host"
```

### Task 5: The tab bar

**Files:**
- Modify: `lib/ui/core/icons.dart`, `lib/ui/features/report/views/today_screen.dart`, `lib/ui/features/report/views/today_route.dart`, `lib/ui/features/settings/views/settings_screen.dart`, `lib/ui/features/settings/views/settings_route.dart`, `lib/ui/features/dashboard/views/dashboard_screen.dart` (rewritten), `lib/ui/features/dashboard/views/dashboard_body.dart`, `lib/ui/features/dashboard/views/workspace_bar.dart`
- Create: `lib/ui/features/dashboard/views/dashboard_tab_bar.dart`, `lib/ui/features/dashboard/views/sites_tab.dart`, `lib/ui/features/dashboard/views/site_row_actions.dart`, `test/support/dashboard_harness.dart`
- Test: `test/ui/core/icons_test.dart`, `test/ui/features/report/today_screen_test.dart`, `test/ui/features/settings_test.dart`, `test/ui/features/dashboard/workspace_bar_test.dart`, `test/ui/features/dashboard_body_test.dart`, `test/ui/features/dashboard/dashboard_tab_bar_test.dart` (new), `test/ui/features/dashboard/dashboard_tabs_test.dart` (new)

**Interfaces:**
- Consumes: `DefaultRouteScreen` (Task 3), for the "a pushed screen covers the bar" test.
- Produces:
  - `AppGlyph.sites`, `AppGlyph.today`, `AppGlyph.settings`
  - `TodayScreen({required BlockedTally tally, VoidCallback? onBack})` and `SettingsScreen(..., VoidCallback? onBack)`. A null `onBack` draws no back icon.
  - `TodayRoute({bool showBack = true})` and `SettingsRoute({bool showBack = true})`
  - `enum DashboardTab { sites, today, settings }`
  - `DashboardTabBar({required DashboardTab current, required ValueChanged<DashboardTab> onSelect})`
  - `SitesTab`, a `ConsumerStatefulWidget`: the dashboard's old content, minus `⋯` and the menu's Today row
  - `Future<void> showSiteRowMenu(BuildContext context, WidgetRef ref, String siteId)`
  - `test/support/dashboard_harness.dart`: `personal`, `work`, `FakeSites`, `FakeSettings`, `DashboardHarness`, `pumpDashboard(tester, {workspaces, sites, settings, overrides})`, `tapTab(tester, label)`, `systemBack(tester)`

- [ ] **Step 1: Write the failing tests**

In `test/ui/core/icons_test.dart`, change the first test to:

```dart
  test("the set is spec §6.6's fifteen glyphs, the restyle's eight, then the dashboard's three", () {
    expect(AppGlyph.values.map((g) => g.name), [
      'back', 'forward', 'reload', 'stop', 'shield', 'panic', 'menu', 'find',
      'reader', 'link', 'search', 'globe', 'chevronUp', 'chevronDown', 'close',
      'check', 'plus', 'more', 'vault', 'fingerprint', 'backspace', 'refused',
      'contrast', 'sites', 'today', 'settings',
    ]);
  });
```

"every glyph paints, at the size it is given" already covers the new three.

In `test/ui/features/report/today_screen_test.dart`, add inside `main()`:

```dart
  testWidgets('with no onBack it draws no back icon: the dashboard tab (spec §4.1)', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const MaterialApp(home: TodayScreen(tally: tally)));

    expect(find.text('Today'), findsOneWidget);
    expect(findIconTap('Back'), findsNothing);
  });
```

In `test/ui/features/settings_test.dart`, add:

```dart
  testWidgets('with no onBack it draws no back icon: the dashboard tab (spec §4.1)', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: false, biometricsAvailable: true, autoLockLabel: 'After 1 min',
        decoyEnabled: false, decoySiteCount: 0, hideFromSwitcher: true, panicOnFlip: false,
        onPanicLabel: 'Wipe + lock', searchEngineName: 'DuckDuckGo', securityLevelName: 'Standard',
        onChanged: (_, __) {}, onTap: (_) {},
      ),
    ));

    expect(find.text('Settings'), findsOneWidget);
    expect(findIconTap('Back'), findsNothing);
  });
```

`test/ui/features/dashboard/dashboard_tab_bar_test.dart`:

```dart
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/dashboard_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

Future<List<DashboardTab>> _pump(WidgetTester tester, DashboardTab current) async {
  final picked = <DashboardTab>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DashboardTabBar(current: current, onSelect: picked.add),
      ),
    ),
  ));
  return picked;
}

void main() {
  testWidgets('three tabs, each a line icon over its label, in order', (tester) async {
    await _pump(tester, DashboardTab.sites);

    final xs = [
      for (final label in ['Sites', 'Today', 'Settings']) tester.getCenter(find.text(label)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()));
    for (final glyph in [AppGlyph.sites, AppGlyph.today, AppGlyph.settings]) {
      expect(tester.getSize(findGlyph(glyph)), const Size(20, 20));
    }
  });

  testWidgets('the viewed tab is primary, the others muted, and nothing is jade', (tester) async {
    await _pump(tester, DashboardTab.today);

    expect(tester.widget<Text>(find.text('Today')).style!.color, C.textPrimary);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.today)).color, C.textPrimary);
    expect(tester.widget<Text>(find.text('Sites')).style!.color, C.textMuted);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.settings)).color, C.textMuted);
    expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        isNot(contains(C.jade)));
  });

  testWidgets('a tap anywhere on a tab reports it', (tester) async {
    final picked = await _pump(tester, DashboardTab.sites);

    await tester.tap(find.text('Settings'));
    await tester.tap(findGlyph(AppGlyph.today));
    expect(picked, [DashboardTab.settings, DashboardTab.today]);
  });
}
```

`test/support/dashboard_harness.dart`:

```dart
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/engine_extras.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/domain/repositories/repositories.dart';
import 'package:container/ui/features/container/view_models/open_containers.dart';
import 'package:container/ui/features/container/view_models/providers.dart'
    show containerEngineProvider, engineExtrasBuilderProvider;
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart'
    show siteLookupProvider;
import 'package:container/ui/features/dashboard/view_models/providers.dart';
import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:container/ui/features/dashboard/views/dashboard_tab_bar.dart';
import 'package:container/ui/features/settings/view_models/providers.dart'
    show autoLockProvider, settingsRepositoryProvider;
import 'package:container/ui/features/shell/view_models/session_controller.dart'
    show Session, SessionController, SessionUnconfigured, biometricServiceProvider, sessionProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../ui/features/shell/session_controller_test.dart' show FakeBiometricService;

const personal = Workspace(
    id: 'w1', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep, sortIndex: 0);
const work =
    Workspace(id: 'w2', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep, sortIndex: 1);

/// The registry watches the session only to empty itself on leaving
/// `SessionOpen`, which these tests never do.
class _Session extends SessionController {
  @override
  Session build() => const SessionUnconfigured();
}

/// The open vault's sites, in memory. A write changes what the next read
/// returns, as the vault would.
class FakeSites implements SiteRepository {
  FakeSites(List<Site> rows) : rows = [...rows];

  final List<Site> rows;
  final upserts = <Site>[];

  @override
  Future<List<Site>> all() async => [...rows];
  @override
  Future<List<Site>> inWorkspace(String workspaceId) async =>
      rows.where((s) => s.workspaceId == workspaceId).toList();
  @override
  Future<Site?> byId(String id) async => rows.where((s) => s.id == id).firstOrNull;
  @override
  Future<void> upsert(Site site) async {
    upserts.add(site);
    rows.removeWhere((s) => s.id == site.id);
    rows.add(site);
  }

  @override
  Future<void> delete(String id) async => rows.removeWhere((s) => s.id == id);
  @override
  Future<void> touch(String id, DateTime at) async {
    final i = rows.indexWhere((s) => s.id == id);
    if (i >= 0) rows[i] = rows[i].copyWith(lastVisitedAt: at);
  }

  @override
  Future<DateTime?> lastWorked(String id) async => null;
  @override
  Future<void> setLastWorked(String id, DateTime? at) async {}
}

/// The open vault's `app_settings`, in memory.
class FakeSettings implements SettingsRepository {
  FakeSettings(Map<String, String> values) : values = {...values};

  final Map<String, String> values;

  @override
  Future<bool> getBool(String key, {bool fallback = false}) async =>
      values.containsKey(key) ? values[key] == 'true' : fallback;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = '$value';
  @override
  Future<String?> getString(String key, {String? fallback}) async => values[key] ?? fallback;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

class DashboardHarness {
  DashboardHarness(this.container, this.engine, this.sites, this.settings);

  final ProviderContainer container;
  final FakeContainerEngine engine;
  final FakeSites sites;
  final FakeSettings settings;

  OpenContainersState get tabs => container.read(openContainersProvider);
  OpenContainers get registry => container.read(openContainersProvider.notifier);
}

/// The real [DashboardScreen], every tab included, over in-memory fakes: no
/// database, no platform. A container shown from it creates a platform view,
/// which is answered here.
Future<DashboardHarness> pumpDashboard(
  WidgetTester tester, {
  List<Workspace> workspaces = const [personal, work],
  List<Site> sites = const [],
  Map<String, String> settings = const {},
  List<Override> overrides = const [],
}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  const platformViews = MethodChannel('flutter/platform_views');
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(platformViews, (call) async => null);
  addTearDown(() =>
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(platformViews, null));

  final engine = FakeContainerEngine();
  final fakeSites = FakeSites(sites);
  final fakeSettings = FakeSettings(settings);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      containerEngineProvider.overrideWithValue(engine),
      engineExtrasBuilderProvider.overrideWithValue((site) async => EngineExtras.none),
      sessionProvider.overrideWith(_Session.new),
      siteRepositoryProvider.overrideWithValue(fakeSites),
      workspacesProvider.overrideWith((ref) async => workspaces),
      settingsRepositoryProvider.overrideWithValue(fakeSettings),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      autoLockProvider.overrideWith((ref) async => AutoLockPolicy.oneMinute),
      siteLookupProvider.overrideWithValue((_) async => null),
      ...overrides,
    ],
    child: const MaterialApp(home: DashboardScreen()),
  ));
  await tester.pumpAndSettle();
  return DashboardHarness(
    ProviderScope.containerOf(tester.element(find.byType(DashboardScreen))),
    engine,
    fakeSites,
    fakeSettings,
  );
}

/// Taps the tab labelled [label] in the dashboard's tab bar.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(DashboardTabBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// What the platform sends for a system back gesture.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}
```

`test/ui/features/dashboard/dashboard_tabs_test.dart`:

```dart
import 'package:container/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:container/ui/features/dashboard/views/dashboard_tab_bar.dart';
import 'package:container/ui/features/dashboard/views/sites_tab.dart';
import 'package:container/ui/features/report/views/today_screen.dart';
import 'package:container/ui/features/settings/views/default_route_screen.dart';
import 'package:container/ui/features/settings/views/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/glyph_finders.dart';

/// The dashboard shell's own back handler: the first `PopScope` under it.
PopScope _dashboardScope(WidgetTester tester) => tester.widget<PopScope>(find
    .descendant(
        of: find.byType(DashboardScreen), matching: find.byWidgetPredicate((w) => w is PopScope))
    .first);

void main() {
  testWidgets('the dashboard opens on Sites, under the three tabs', (tester) async {
    await pumpDashboard(tester);

    expect(find.byType(SitesTab), findsOneWidget);
    for (final label in ['Sites', 'Today', 'Settings']) {
      expect(find.descendant(of: find.byType(DashboardTabBar), matching: find.text(label)),
          findsOneWidget);
    }
  });

  testWidgets('each tab shows its screen, with no back icon', (tester) async {
    await pumpDashboard(tester);

    await tapTab(tester, 'Today');
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(findIconTap('Back'), findsNothing);

    await tapTab(tester, 'Settings');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(findIconTap('Back'), findsNothing);
    expect(find.text('Default route'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);

    await tapTab(tester, 'Sites');
    expect(find.byType(SitesTab), findsOneWidget);
  });

  testWidgets('system back on Today or Settings shows Sites', (tester) async {
    await pumpDashboard(tester);

    await tapTab(tester, 'Today');
    await systemBack(tester);
    expect(find.byType(SitesTab), findsOneWidget);

    await tapTab(tester, 'Settings');
    await systemBack(tester);
    expect(find.byType(SitesTab), findsOneWidget);
  });

  testWidgets('on Sites, back is left to the system, as before', (tester) async {
    await pumpDashboard(tester);
    expect(_dashboardScope(tester).canPop, isTrue);

    await tapTab(tester, 'Today');
    expect(_dashboardScope(tester).canPop, isFalse);
  });

  testWidgets('a screen pushed from a tab covers the tab bar', (tester) async {
    await pumpDashboard(tester);
    await tapTab(tester, 'Settings');

    await tester.tap(find.text('Default route'));
    await tester.pumpAndSettle();

    expect(find.byType(DefaultRouteScreen), findsOneWidget);
    expect(find.byType(DashboardTabBar), findsNothing);
  });

  testWidgets('the bar steps aside while the keyboard is up (plan D4)', (tester) async {
    await pumpDashboard(tester);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.byType(DashboardTabBar), findsNothing);
    expect(find.byType(SitesTab), findsOneWidget);

    tester.view.resetViewInsets();
    await tester.pump();
    expect(find.byType(DashboardTabBar), findsOneWidget);
  });
}
```

Replace the whole of `test/ui/features/dashboard/workspace_bar_test.dart`. The bar loses `⋯` in this task and is deleted in Task 6:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/workspace_bar.dart';

import '../../../support/glyph_finders.dart';

void main() {
  Widget harness() => MaterialApp(
        home: Scaffold(
          body: WorkspaceBar(
            name: 'Personal',
            trailing: '2 SESSIONS',
            trailingIsBadge: false,
            onTap: () {},
          ),
        ),
      );

  testWidgets('the workspace name and trailing text still render', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 SESSIONS'), findsOneWidget);
  });

  testWidgets('Settings is a tab now: the bar has no overflow icon', (tester) async {
    await tester.pumpWidget(harness());

    expect(findIconTap('Settings'), findsNothing);
    expect(findGlyph(AppGlyph.more), findsNothing);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.chevronDown)).color, C.chevron);
  });
}
```

In `test/ui/features/dashboard_body_test.dart`, delete the line `onOverflow: () {},` from `_pump`.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/ui/core/icons_test.dart test/ui/features/report/today_screen_test.dart test/ui/features/settings_test.dart test/ui/features/dashboard test/ui/features/dashboard_body_test.dart`
Expected: compile errors (the new glyphs, `onBack` optional, `dashboard_tab_bar.dart`, `sites_tab.dart`, `WorkspaceBar` without `onOverflow`).

- [ ] **Step 3: The three glyphs**

In `lib/ui/core/icons.dart`, add `sites`, `today` and `settings` after `contrast` in `AppGlyph`. Change the enum's doc comment's last sentence to: `The restyle added eight (`2026-10-02-restyle-design.md` §2), and the dashboard redesign the last three.` Then add these cases to `paint`'s switch, after `contrast`:

```dart
      case AppGlyph.sites:
        for (final corner in const [Offset(4, 4), Offset(14, 4), Offset(4, 14), Offset(14, 14)]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(corner & const Size(6, 6), const Radius.circular(1.5)),
            stroke,
          );
        }
      case AppGlyph.today:
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTRB(4, 6, 20, 20), const Radius.circular(2)),
          stroke,
        );
        _lines(canvas, stroke, const [Offset(4, 10.5), Offset(20, 10.5)]);
        _lines(canvas, stroke, const [Offset(8.5, 3.5), Offset(8.5, 7.5)]);
        _lines(canvas, stroke, const [Offset(15.5, 3.5), Offset(15.5, 7.5)]);
      case AppGlyph.settings:
        // Three sliders: each line stops at its knob, a ring.
        for (final (y, knob) in const [(7.0, 15.0), (12.0, 9.0), (17.0, 13.0)]) {
          _lines(canvas, stroke, [Offset(4, y), Offset(knob - 2, y)]);
          canvas.drawCircle(Offset(knob, y), 2, stroke);
          _lines(canvas, stroke, [Offset(knob + 2, y), Offset(20, y)]);
        }
```

- [ ] **Step 4: Optional back icons**

In `today_screen.dart`, make the constructor `const TodayScreen({super.key, required this.tally, this.onBack});` and the field:

```dart
  /// The header's back icon. Null draws none: the dashboard's Today tab
  /// (dashboard spec §4.1).
  final VoidCallback? onBack;
```

In the header `Row`, replace the `IconTap(...)` and the `SizedBox(width: 10)` after it with:

```dart
                  if (onBack != null) ...[
                    IconTap(
                      glyph: AppGlyph.back,
                      label: 'Back',
                      onTap: onBack,
                      size: 20,
                      iconSize: 18,
                    ),
                    const SizedBox(width: 10),
                  ],
```

Replace `today_route.dart`'s class with:

```dart
/// [TodayScreen] fed from the live tally, so it keeps counting while open.
/// Pushed from ☰ with a back icon. The dashboard's tab has none ([showBack]
/// false, dashboard spec §4.1).
class TodayRoute extends ConsumerWidget {
  const TodayRoute({super.key, this.showBack = true});

  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TodayScreen(
      tally: ref.watch(blockedTallyProvider),
      onBack: showBack ? () => Navigator.pop(context) : null,
    );
  }
}
```

In `settings_screen.dart`, change `required this.onBack,` to `this.onBack,` and the field to:

```dart
  /// The header's back icon. Pops Settings, like every other screen's `‹`
  /// (restyle spec §4). Null draws none: the dashboard's Settings tab
  /// (dashboard spec §4.1).
  final VoidCallback? onBack;
```

Wrap its header `IconTap` and the `SizedBox(width: 10)` after it in `if (onBack != null) ...[ ... ],`, exactly as in `TodayScreen`. In the class doc comment, replace "`DashboardScreen`'s `⋯` icon (which pushes this screen)" with "the dashboard's Settings tab".

In `settings_route.dart`, give `SettingsRoute` the same switch:

```dart
  const SettingsRoute({super.key, this.showBack = true});

  /// False as the dashboard's tab, which has no back icon (dashboard spec §4.1).
  final bool showBack;
```

Change `onBack: () => Navigator.pop(context),` to `onBack: showBack ? () => Navigator.pop(context) : null,`. In its doc comment, change "Pushed from the dashboard's `⋯` and from a container's ☰ menu." to "The dashboard's Settings tab, and pushed from a container's ☰ menu."

- [ ] **Step 5: The tab bar**

`lib/ui/features/dashboard/views/dashboard_tab_bar.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// The dashboard's tabs (dashboard spec §4.1), in bar order.
enum DashboardTab { sites, today, settings }

/// Spec §4.1's bottom tab bar: each tab a line icon over its label. The
/// viewed tab is in the primary text colour, the others muted. No jade,
/// which stays for open sessions.
class DashboardTabBar extends StatelessWidget {
  const DashboardTabBar({super.key, required this.current, required this.onSelect});

  final DashboardTab current;
  final ValueChanged<DashboardTab> onSelect;

  static const _tabs = [
    (DashboardTab.sites, AppGlyph.sites, 'Sites'),
    (DashboardTab.today, AppGlyph.today, 'Today'),
    (DashboardTab.settings, AppGlyph.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: C.footer,
        border: Border(top: BorderSide(color: C.line07)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (tab, glyph, label) in _tabs) Expanded(child: _item(tab, glyph, label)),
          ],
        ),
      ),
    );
  }

  Widget _item(DashboardTab tab, AppGlyph glyph, String label) {
    final viewed = tab == current;
    final color = viewed ? C.textPrimary : C.textMuted;
    return Semantics(
      button: true,
      selected: viewed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(glyph, size: 20, color: color),
              const SizedBox(height: 4),
              Text(label, style: ui(size: 10.5, weight: 500, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Move the row menu out, unchanged**

`lib/ui/features/dashboard/views/site_row_actions.dart`. This is `DashboardScreen`'s `onSiteMenu` body, moved, with `mounted` replaced by `context.mounted`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/site_wipe.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/view_models/open_containers.dart' show openContainersProvider;
import '../../container/view_models/providers.dart' show containerEngineProvider;
import '../../search/view_models/providers.dart' show sitesChanged;
import '../view_models/providers.dart';
import 'site_row_menu.dart';
import 'wipe_site_sheet.dart';

/// A dashboard row's long-press: the row menu (`7b`) for [siteId], and what
/// its actions do.
Future<void> showSiteRowMenu(BuildContext context, WidgetRef ref, String siteId) async {
  final site = await ref.read(siteRepositoryProvider).byId(siteId);
  if (site == null || !context.mounted) return;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SiteRowMenu(
      monogram: site.monogram,
      name: site.name,
      subtitle: site.url,
      ephemeralWorkspaceName: 'Ephemeral',
      duplicateTargetName: 'Work',
      onCancel: () => Navigator.pop(context),
      onAction: (action) async {
        Navigator.pop(context);
        if (action == SiteRowAction.editSettings) {
          final workspaces = await ref.read(workspacesProvider.future);
          if (!context.mounted) return;
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => AddSiteScreen(
              initial: site,
              workspaces: workspaces,
              // A change of route or cookie policy closes the site's open
              // container (tabs spec §5.7). From here it is in the
              // background, so it stays closed until it is next opened.
              onSave: (updated) async {
                await ref.read(siteRepositoryProvider).upsert(updated);
                await ref.read(openContainersProvider.notifier).siteSaved(updated);
                sitesChanged(ref);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
            ),
          ));
        } else if (action == SiteRowAction.removeSite) {
          // Closed and wiped first: deleting the row alone left the site's
          // profile and downloads on disk. The close reaches the registry
          // through the sessions event.
          await removeSavedSite(
            engine: ref.read(containerEngineProvider),
            sites: ref.read(siteRepositoryProvider),
            site: site,
          );
          sitesChanged(ref);
        } else if (action == SiteRowAction.wipeData) {
          // Asked first (user's ruling, 2026-09-30). The site stays, under a
          // fresh profile (wipeSavedSite).
          if (!await confirmWipeSite(context) || !context.mounted) return;
          await wipeSavedSite(
            engine: ref.read(containerEngineProvider),
            sites: ref.read(siteRepositoryProvider),
            site: site,
          );
          sitesChanged(ref);
        }
        // openEphemeral, duplicate, requirePin: Known Gap, see Plan 6's
        // Known gaps. None has a target workspace or PIN flow built yet.
      },
    ),
  );
}
```

- [ ] **Step 7: `SitesTab`, the old dashboard minus `⋯` and the Today row**

`lib/ui/features/dashboard/views/sites_tab.dart`. This is `DashboardScreen`'s state moved, without `onOverflow` and without the menu's `managementOptions`. Tasks 6 and 7 rewrite it:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tokens.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/views/container_route.dart';
import '../../search/view_models/providers.dart'
    show allSitesProvider, searchQueryProvider, searchResultsProvider, sitesChanged;
import '../../search/view_models/search_view.dart' show SearchResultEntry;
import '../../search/views/search_screen.dart';
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import 'site_row_actions.dart';
import 'workspace_menu.dart';

/// The dashboard's Sites tab (dashboard spec §4).
class SitesTab extends ConsumerStatefulWidget {
  const SitesTab({super.key});

  @override
  ConsumerState<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<SitesTab> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => Stack(
        children: [
          DashboardBody(
            view: view,
            onWorkspaceTap: () => setState(() => _menuOpen = !_menuOpen),
            onAddSite: _addSite,
            onSearch: () {
              ref.invalidate(searchQueryProvider);
              ref.invalidate(allSitesProvider);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const _SearchRoute()));
            },
            onOpenSite: _openSite,
            onSiteMenu: (siteId) => showSiteRowMenu(context, ref, siteId),
          ),
          if (_menuOpen) _menu(),
        ],
      ),
    );
  }

  Future<void> _addSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddSiteScreen(
        workspaces: workspaces,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          sitesChanged(ref);
          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    ));
  }

  // Tabs spec §4.2: an open container is shown as it is, with no second open;
  // otherwise it opens. Either way through the one host route.
  Future<void> _openSite(String siteId) async {
    openSite(ref, siteId);
    final site = await ref.read(siteRepositoryProvider).byId(siteId);
    if (site == null || !mounted) return;
    showContainer(context, ref, site);
  }

  Widget _menu() {
    final options = ref.watch(workspaceOptionsProvider);
    return SafeArea(
      child: Padding(
        // Sits directly under the 47px-tall workspace bar.
        padding: const EdgeInsets.only(top: 47),
        child: Align(
          alignment: Alignment.topCenter,
          child: options.maybeWhen(
            data: (options) => WorkspaceMenu(
              options: options,
              onPick: (id) {
                ref.read(activeWorkspaceIdProvider.notifier).state = id;
                setState(() => _menuOpen = false);
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _SearchRoute extends ConsumerStatefulWidget {
  const _SearchRoute();

  @override
  ConsumerState<_SearchRoute> createState() => _SearchRouteState();
}

class _SearchRouteState extends ConsumerState<_SearchRoute> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);

    return SearchScreen(
      controller: _controller,
      results: results.value ?? const [],
      onQueryChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
      onOpen: (siteId) async {
        final entries = results.value ?? const [];
        SearchResultEntry? entry;
        for (final candidate in entries) {
          if (candidate.siteId == siteId) {
            entry = candidate;
            break;
          }
        }
        if (entry == null) return;
        ref.read(activeWorkspaceIdProvider.notifier).state = entry.workspaceId;
        openSite(ref, siteId);
        final site = await ref.read(siteRepositoryProvider).byId(siteId);
        if (site == null || !context.mounted) return;
        // Pops this search route itself, down to the dashboard.
        showContainer(context, ref, site);
      },
      onBack: () => Navigator.pop(context),
    );
  }
}
```

- [ ] **Step 8: `DashboardScreen` becomes the shell**

Replace `lib/ui/features/dashboard/views/dashboard_screen.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../report/views/today_route.dart';
import '../../settings/views/settings_route.dart';
import 'dashboard_tab_bar.dart';
import 'sites_tab.dart';

/// The open vault's first screen (dashboard spec §4): Sites, Today and
/// Settings under a bottom tab bar. The bar belongs to the dashboard only:
/// anything pushed (a container, a form, a screen opened from a tab) covers
/// it.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Not remembered: every unlock builds this screen anew, on Sites (§4.1).
  DashboardTab _tab = DashboardTab.sites;

  @override
  Widget build(BuildContext context) {
    // Plan D4: while the keyboard is up the bar steps aside, so the search
    // field sits on the keyboard.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      // §4.1: back on Today or Settings shows Sites. On Sites it does what it
      // always did.
      canPop: _tab == DashboardTab.sites,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != DashboardTab.sites) setState(() => _tab = DashboardTab.sites);
      },
      child: ColoredBox(
        color: C.bg,
        child: Column(
          children: [
            Expanded(
              // The same widget whether or not the keyboard is up, so a tab
              // keeps its state (the search field's text) as it comes and goes.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: !keyboardUp,
                child: switch (_tab) {
                  DashboardTab.sites => const SitesTab(),
                  DashboardTab.today => const TodayRoute(showBack: false),
                  DashboardTab.settings => const SettingsRoute(showBack: false),
                },
              ),
            ),
            if (!keyboardUp)
              DashboardTabBar(current: _tab, onSelect: (tab) => setState(() => _tab = tab)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: `⋯` leaves the workspace bar**

In `workspace_bar.dart`, delete the `onOverflow` parameter and field, the `IconTap`, the `SizedBox(width: 10)` before it, and the `icon_tap.dart` import. The trailing `Row` becomes just `Text(trailing, style: trailingIsBadge ? T.barBadge : T.barSummary)`. In `dashboard_body.dart`, delete `onOverflow` from the constructor, the field and the `WorkspaceBar(` call.

- [ ] **Step 10: Run the tests and see them pass**

Run: `flutter test test/ui/core test/ui/features/report test/ui/features/settings_test.dart test/ui/features/settings test/ui/features/dashboard test/ui/features/dashboard_body_test.dart test/ui/features/workspace_menu_test.dart test/no_glyphs_test.dart`
Expected: PASS. `dashboard_site_actions_test.dart` passes unchanged, because the shell opens on Sites.

- [ ] **Step 11: Analyze and commit**

Run: `flutter analyze`. Expected: no issues.

```bash
git add lib/ui/core/icons.dart lib/ui/features/report lib/ui/features/settings lib/ui/features/dashboard test/support/dashboard_harness.dart test/ui/core/icons_test.dart test/ui/features/report test/ui/features/settings_test.dart test/ui/features/dashboard test/ui/features/dashboard_body_test.dart
git commit -m "feat(dashboard): Sites, Today and Settings tabs"
```

---

### Task 6: Workspace chips and one list

**Files:**
- Modify: `lib/ui/features/dashboard/view_models/dashboard_view.dart` (rewritten), `lib/ui/features/dashboard/view_models/providers.dart`, `lib/ui/features/dashboard/views/dashboard_body.dart` (rewritten), `lib/ui/features/dashboard/views/sites_tab.dart` (rewritten), `lib/ui/features/workspaces/views/workspaces_route.dart`
- Create: `lib/ui/features/dashboard/views/workspace_chips.dart`
- Delete: `lib/ui/features/dashboard/views/workspace_bar.dart`, `lib/ui/features/dashboard/views/workspace_menu.dart`, `test/ui/features/dashboard/workspace_bar_test.dart`, `test/ui/features/workspace_menu_test.dart`
- Rename: `test/ui/features/dashboard/dashboard_counts_test.dart` to `test/ui/features/dashboard/dashboard_provider_test.dart` (rewritten)
- Test: `test/ui/features/dashboard/dashboard_view_test.dart` (new), `test/ui/features/dashboard/workspace_chips_test.dart` (new), `test/ui/features/dashboard/dashboard_chips_test.dart` (new), `test/ui/features/dashboard_body_test.dart` (rewritten), `test/ui/features/dashboard/dashboard_site_actions_test.dart`

**Interfaces:**
- Consumes: `pumpDashboard`, `personal`, `work`, `tapTab` (Task 5); `showSiteRowMenu` (Task 5).
- Produces:
  - `DashboardView({required String? workspaceId, required bool wipesOnExit, required List<SessionEntry> rows})`, with `isEmpty`, `static const empty`, and `static DashboardView from({required Workspace workspace, required List<Site> sites, required Set<String> openSiteIds, required DateTime now})`
  - `class WorkspaceChip { const WorkspaceChip({required String id, required String name, required bool selected}); }`
  - `WorkspaceChips({required List<WorkspaceChip> chips, required ValueChanged<String> onPick, required ValueChanged<String> onEdit, required VoidCallback onNew, String? badge})`
  - `DashboardBody({required DashboardView view, required List<WorkspaceChip> chips, required ValueChanged<String> onPickWorkspace, required ValueChanged<String> onEditWorkspace, required VoidCallback onNewWorkspace, required void Function(String) onOpenSite, required void Function(String) onSiteMenu, required Widget footer})`
  - `void createWorkspace(BuildContext context, WidgetRef ref)` and `Future<void> editWorkspace(BuildContext context, WidgetRef ref, String id)` in `workspaces_route.dart`
  - Removed: `workspaceOptionsProvider`, `WorkspaceOption`, `workspaceMeta`, `ManagementOption`, `WorkspaceMenu`, `WorkspaceBar`, `DashboardView.open/idle/sessionCount/workspaceName`

- [ ] **Step 1: Write the failing tests**

`test/ui/features/dashboard/dashboard_view_test.dart`:

```dart
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 3, 12);

Site _site(String id, {Duration? ago}) => Site(
      id: id, workspaceId: 'w', name: id, monogram: 'Xx', url: 'https://$id.example',
      profileId: 'p-$id', lastVisitedAt: ago == null ? null : _now.subtract(ago),
    );

const _personal =
    Workspace(id: 'w', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep);

void main() {
  test('open sites first, then the rest; each most recent first, never-visited last (§4.3)', () {
    final view = DashboardView.from(
      workspace: _personal,
      sites: [
        _site('idle-old', ago: const Duration(days: 3)),
        _site('never'),
        _site('open-old', ago: const Duration(hours: 2)),
        _site('idle-new', ago: const Duration(minutes: 5)),
        _site('open-new', ago: const Duration(minutes: 1)),
        _site('open-never'),
      ],
      openSiteIds: const {'open-old', 'open-new', 'open-never'},
      now: _now,
    );

    expect(view.rows.map((r) => r.siteId),
        ['open-new', 'open-old', 'open-never', 'idle-new', 'idle-old', 'never']);
    expect(view.rows.map((r) => r.live), [true, true, true, false, false, false]);
  });

  test('ties keep the order the vault gave', () {
    final view = DashboardView.from(
      workspace: _personal,
      sites: [_site('c'), _site('a'), _site('b')],
      openSiteIds: const {},
      now: _now,
    );
    expect(view.rows.map((r) => r.siteId), ['c', 'a', 'b']);
  });

  test('it names the viewed workspace and its storage rule', () {
    final keep = DashboardView.from(
        workspace: _personal, sites: const [], openSiteIds: const {}, now: _now);
    expect(keep.workspaceId, 'w');
    expect(keep.wipesOnExit, isFalse);
    expect(keep.isEmpty, isTrue);

    final wipe = DashboardView.from(
      workspace: const Workspace(
          id: 'e', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
      sites: const [],
      openSiteIds: const {},
      now: _now,
    );
    expect(wipe.wipesOnExit, isTrue);
  });

  test('a vault with no workspaces has none viewed', () {
    expect(DashboardView.empty.workspaceId, isNull);
    expect(DashboardView.empty.isEmpty, isTrue);
  });
}
```

`git mv test/ui/features/dashboard/dashboard_counts_test.dart test/ui/features/dashboard/dashboard_provider_test.dart`. Keep its imports, `_Session`, `_Sites`, `_personal`, `_work`, `_site` and `_openThree`, and replace its `main()` with:

```dart
void main() {
  test('throwaways are never listed, and the viewed workspace follows the chip', () async {
    final container = await _openThree();

    final personal = await container.read(dashboardProvider.future);
    expect(personal.workspaceId, 'w1');
    expect(personal.rows.map((e) => (e.siteId, e.live)), [('s1', true), ('s2', false)]);

    container.read(activeWorkspaceIdProvider.notifier).state = 'w2';
    final work = await container.read(dashboardProvider.future);
    expect(work.workspaceId, 'w2');
    expect(work.rows, isEmpty);
  });

  test('the green dot follows the registry: a closed site is no longer marked', () async {
    final container = await _openThree();

    await container.read(openContainersProvider.notifier).close('s1');

    final view = await container.read(dashboardProvider.future);
    expect(view.rows.map((e) => e.live), [false, false]);
  });
}
```

Change its file doc above `_openThree` to: `/// A saved site and a throwaway open under Personal, and a throwaway open under Work. A throwaway is never a row (it is not a site): `N OPEN`, `2c` and the swipe reach it.`

`test/ui/features/dashboard/workspace_chips_test.dart`:

```dart
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/dashboard/views/workspace_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

const _chips = [
  WorkspaceChip(id: 'w1', name: 'Personal', selected: true),
  WorkspaceChip(id: 'w2', name: 'Work', selected: false),
];

Future<List<String>> _pump(WidgetTester tester, {String? badge}) async {
  final calls = <String>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: WorkspaceChips(
        chips: _chips,
        onPick: (id) => calls.add('pick $id'),
        onEdit: (id) => calls.add('edit $id'),
        onNew: () => calls.add('new'),
        badge: badge,
      ),
    ),
  ));
  return calls;
}

void main() {
  testWidgets('one chip per workspace, in order, then the + chip', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    final personal = tester.getCenter(find.text('Personal')).dx;
    final work = tester.getCenter(find.text('Work')).dx;
    final plus = tester.getCenter(findIconTap('New workspace')).dx;
    expect(personal < work && work < plus, isTrue);
    expect(find.bySemanticsLabel('New workspace'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a tap picks, a long-press edits, + makes a new one', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.text('Work'));
    await tester.longPress(find.text('Personal'));
    await tester.tap(findIconTap('New workspace'));

    expect(calls, ['pick w2', 'edit w1', 'new']);
  });

  testWidgets('the viewed chip is drawn selected, and nothing is jade', (tester) async {
    await _pump(tester);

    expect(tester.widget<Text>(find.text('Personal')).style!.color, C.textPrimary);
    expect(tester.widget<Text>(find.text('Work')).style!.color, C.tabInactive);
    expect(tester.widgetList<Text>(find.byType(Text)).map((t) => t.style?.color),
        isNot(contains(C.jade)));
  });

  testWidgets("a wipe-on-exit workspace's badge sits at the row's end (plan D3)", (tester) async {
    await _pump(tester, badge: 'WIPES ON EXIT');

    expect(find.text('WIPES ON EXIT'), findsOneWidget);
    expect(tester.getCenter(find.text('WIPES ON EXIT')).dx,
        greaterThan(tester.getCenter(findIconTap('New workspace')).dx));
  });
}
```

Replace the whole of `test/ui/features/dashboard_body_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/dashboard/views/dashboard_body.dart';
import 'package:container/ui/features/dashboard/views/workspace_chips.dart';
import 'package:container/ui/features/dashboard/view_models/dashboard_view.dart';

final _now = DateTime(2026, 8, 30, 9, 10);

Site _site(String id, String name, String mono, String url, Duration ago,
        {CookiePolicy cookies = CookiePolicy.keep,
        ProxyMode proxy = ProxyMode.direct,
        bool pin = false}) =>
    Site(
      id: id, workspaceId: 'ws', name: name, monogram: mono, url: url,
      profileId: 'p-$id',
      cookiePolicy: cookies, proxyMode: proxy, requirePin: pin,
      lastVisitedAt: _now.subtract(ago),
    );

DashboardView _personal({Set<String> open = const {'st-notes', 'st-bank'}}) {
  return DashboardView.from(
    workspace: const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
    sites: [
      _site('st-notes', 'Notes', 'Nt', 'https://notes.example.org',
          const Duration(seconds: 10), proxy: ProxyMode.socks5),
      _site('st-webmail', 'Webmail', 'Wm', 'https://mail.example.net',
          const Duration(minutes: 14)),
      _site('st-forum', 'Forum', 'Fr', 'https://forum.example.com',
          const Duration(hours: 2), cookies: CookiePolicy.wipeOnExit),
      _site('st-bank', 'Bank', 'Bk', 'https://bank.example.com',
          const Duration(days: 3), pin: true),
    ],
    openSiteIds: open,
    now: _now,
  );
}

DashboardView _empty() => DashboardView.from(
      workspace: const Workspace(
          id: 'ws', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
      sites: const [],
      openSiteIds: const {},
      now: _now,
    );

Future<void> _pump(WidgetTester tester, DashboardView view,
    {void Function(String)? onOpenSite, void Function(String)? onSiteMenu}) {
  return tester.pumpWidget(MaterialApp(
    home: DashboardBody(
      view: view,
      chips: const [WorkspaceChip(id: 'ws', name: 'Personal', selected: true)],
      onPickWorkspace: (_) {},
      onEditWorkspace: (_) {},
      onNewWorkspace: () {},
      onOpenSite: onOpenSite ?? (_) {},
      onSiteMenu: onSiteMenu ?? (_) {},
      footer: const Text('the footer'),
    ),
  ));
}

void main() {
  testWidgets('no section titles and no count: the green dot alone (rulings 5)', (tester) async {
    await _pump(tester, _personal());

    expect(find.text('OPEN NOW'), findsNothing);
    expect(find.text('IDLE'), findsNothing);
    expect(find.textContaining('SESSIONS'), findsNothing);
    // User's ruling 2026-10-02: the dashboard shows no leak count.
    expect(find.textContaining('LEAK'), findsNothing);
  });

  testWidgets('open sites come first, then the rest, most recent first (ruling 6)',
      (tester) async {
    await _pump(tester, _personal());

    final ys = [
      for (final name in ['Notes', 'Bank', 'Webmail', 'Forum'])
        tester.getTopLeft(find.text(name)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
  });

  testWidgets('each row shows host and descriptor, and its age', (tester) async {
    await _pump(tester, _personal());

    expect(find.text('notes.example.org · socks5'), findsOneWidget);
    expect(find.text('mail.example.net · direct'), findsOneWidget);
    expect(find.text('forum.example.com · ephemeral'), findsOneWidget);
    expect(find.text('bank.example.com · pin required'), findsOneWidget);

    expect(find.text('now'), findsOneWidget);
    expect(find.text('14m'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('3d'), findsOneWidget);
  });

  testWidgets('an open row is brighter than an idle one', (tester) async {
    await _pump(tester, _personal());

    expect(tester.widget<Text>(find.text('Notes')).style!.color, C.textPrimary);
    expect(tester.widget<Text>(find.text('Forum')).style!.color, C.textTertiary);
  });

  testWidgets('a tap opens a site, a long-press its menu', (tester) async {
    final opened = <String>[];
    final menus = <String>[];
    await _pump(tester, _personal(), onOpenSite: opened.add, onSiteMenu: menus.add);

    await tester.tap(find.text('Forum'));
    await tester.longPress(find.text('Webmail'));
    expect(opened, ['st-forum']);
    expect(menus, ['st-webmail']);
  });

  testWidgets('the chips sit on top and the footer at the bottom', (tester) async {
    await _pump(tester, _personal());

    expect(tester.getTopLeft(find.text('Personal')).dy,
        lessThan(tester.getTopLeft(find.text('Notes')).dy));
    expect(tester.getTopLeft(find.text('the footer')).dy,
        greaterThan(tester.getTopLeft(find.text('Forum')).dy));
  });

  testWidgets('a wipe-on-exit workspace shows its rule (plan D3)', (tester) async {
    await _pump(tester, _empty());
    expect(find.text('WIPES ON EXIT'), findsOneWidget);
  });

  testWidgets('an empty workspace says so in one sentence', (tester) async {
    await _pump(tester, _empty());

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(
      find.text('Sites you open in this workspace leave nothing behind when '
          'you close the app.'),
      findsOneWidget,
    );
  });
}
```

`test/ui/features/dashboard/dashboard_chips_test.dart`:

```dart
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/widgets/status_rail.dart';
import 'package:container/ui/features/workspaces/views/workspace_form_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/glyph_finders.dart';

const _notes = Site(
  id: 's-notes', workspaceId: 'w1', name: 'Notes', monogram: 'Nt',
  url: 'https://notes.example.org', profileId: 'p-notes',
);
const _ledger = Site(
  id: 's-ledger', workspaceId: 'w2', name: 'Ledger', monogram: 'Lg',
  url: 'https://ledger.example.org', profileId: 'p-ledger',
);

void main() {
  testWidgets('a chip per workspace, then +; the first is viewed', (tester) async {
    await pumpDashboard(tester, sites: const [_notes, _ledger]);

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(findIconTap('New workspace'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Ledger'), findsNothing);
  });

  testWidgets('a tap on a chip shows that workspace', (tester) async {
    await pumpDashboard(tester, sites: const [_notes, _ledger]);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.text('Ledger'), findsOneWidget);
    expect(find.text('Notes'), findsNothing);
  });

  testWidgets("a long-press opens that workspace's form (10b), and changes nothing else",
      (tester) async {
    await pumpDashboard(tester, sites: const [_notes, _ledger]);

    await tester.longPress(find.text('Work'));
    await tester.pumpAndSettle();

    final form = tester.widget<WorkspaceFormScreen>(find.byType(WorkspaceFormScreen));
    expect(form.title, 'Work');
    expect(form.initialName, 'Work');

    form.onClose();
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsOneWidget, reason: 'Personal is still the one viewed');
  });

  testWidgets('+ opens a new workspace form', (tester) async {
    await pumpDashboard(tester);

    await tester.tap(findIconTap('New workspace'));
    await tester.pumpAndSettle();

    expect(tester.widget<WorkspaceFormScreen>(find.byType(WorkspaceFormScreen)).title,
        'New workspace');
  });

  testWidgets('an open site is marked by its green rail alone', (tester) async {
    final h = await pumpDashboard(tester, sites: const [_notes]);

    await tester.runAsync(() => h.registry.view(_notes));
    h.registry.showDashboard();
    await tester.pumpAndSettle();

    expect(tester.widget<StatusRail>(find.byType(StatusRail)).live, isTrue);
    expect(find.text('OPEN NOW'), findsNothing);
    expect(find.textContaining('SESSIONS'), findsNothing);
  });

  testWidgets('a wipe-on-exit workspace shows WIPES ON EXIT', (tester) async {
    await pumpDashboard(tester, workspaces: const [
      Workspace(id: 'e', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
    ]);
    expect(find.text('WIPES ON EXIT'), findsOneWidget);
  });
}
```

In `test/ui/features/dashboard/dashboard_site_actions_test.dart`:
- Delete the line `workspaceOptionsProvider.overrideWith((ref) async => const []),`.
- Add `import 'package:container/ui/core/widgets/status_rail.dart';`.
- Rename the edit test to `'a row edit that changes the route of an open site closes it, and its green rail goes'`.
- In that test, replace `expect(find.text('OPEN NOW'), findsOneWidget);` and `expect(find.text('1 SESSIONS'), findsOneWidget);` with `expect(tester.widget<StatusRail>(find.byType(StatusRail)).live, isTrue);`.
- Replace its last two lines (`OPEN NOW` and `0 SESSIONS`) with `expect(tester.widget<StatusRail>(find.byType(StatusRail)).live, isFalse);`.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/ui/features/dashboard test/ui/features/dashboard_body_test.dart`
Expected: compile errors (`workspace_chips.dart`, `DashboardView.rows/workspaceId/empty`, `DashboardBody`'s new parameters).

- [ ] **Step 3: `DashboardView`, one ordered list**

Replace `lib/ui/features/dashboard/view_models/dashboard_view.dart` below `SessionEntry` (which is unchanged) with:

```dart
class DashboardView {
  const DashboardView({
    required this.workspaceId,
    required this.wipesOnExit,
    required this.rows,
  });

  /// A vault with no workspaces: no chip is viewed.
  static const empty = DashboardView(workspaceId: null, wipesOnExit: false, rows: []);

  /// The viewed workspace (dashboard spec §4.2): its chip is drawn selected,
  /// and a new site or a typed address's throwaway goes into it. Null only
  /// for a vault with no workspaces.
  final String? workspaceId;

  /// True for a workspace whose storage rule is wipe-on-exit: the chip row
  /// shows `WIPES ON EXIT` (spec `5b`, plan D3).
  final bool wipesOnExit;

  /// Spec §4.3, rulings 5 and 6: one list, no titles. Open sites first, then
  /// the rest, each most recently visited first and never-visited last.
  final List<SessionEntry> rows;

  bool get isEmpty => rows.isEmpty;

  /// Which sites are live is runtime state, not stored state: containers do
  /// not survive the app closing, so [openSiteIds] comes from the registry
  /// rather than from the database. A throwaway is never a row (it is not a
  /// site). `N OPEN`, `2c` and the swipe reach it (spec §11).
  static DashboardView from({
    required Workspace workspace,
    required List<Site> sites,
    required Set<String> openSiteIds,
    required DateTime now,
  }) {
    // Ties keep the vault's order: `List.sort` is not stable.
    final position = {for (var i = 0; i < sites.length; i++) sites[i].id: i};
    final ordered = [...sites]
      ..sort((a, b) {
        final aOpen = openSiteIds.contains(a.id);
        final bOpen = openSiteIds.contains(b.id);
        if (aOpen != bOpen) return aOpen ? -1 : 1;
        final byRecency = _byRecency(a, b);
        return byRecency != 0 ? byRecency : position[a.id]!.compareTo(position[b.id]!);
      });

    return DashboardView(
      workspaceId: workspace.id,
      wipesOnExit: workspace.storageRule == StorageRule.wipeOnExit,
      rows: [
        for (final site in ordered)
          SessionEntry(
            siteId: site.id,
            name: site.name,
            monogram: site.monogram,
            meta: '${site.host} · ${siteDescriptor(site)}',
            age: relativeAge(now, site.lastVisitedAt),
            live: openSiteIds.contains(site.id),
          ),
      ],
    );
  }
}

/// Most recently visited first; never visited last.
int _byRecency(Site a, Site b) {
  final at = a.lastVisitedAt;
  final bt = b.lastVisitedAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}
```

- [ ] **Step 4: The providers**

In `lib/ui/features/dashboard/view_models/providers.dart`:
- Delete the `import '../views/workspace_menu.dart';` line, `_throwawaysIn`, and `workspaceOptionsProvider` with its doc comment.
- Replace `dashboardProvider` with:

```dart
final dashboardProvider = FutureProvider<DashboardView>((ref) async {
  final workspaces = await ref.watch(workspacesProvider.future);
  if (workspaces.isEmpty) return DashboardView.empty;

  final activeId = ref.watch(activeWorkspaceIdProvider);
  final workspace = workspaces.firstWhere(
    (w) => w.id == activeId,
    orElse: () => workspaces.first,
  );

  final sites = await ref.watch(siteRepositoryProvider).inWorkspace(workspace.id);

  return DashboardView.from(
    workspace: workspace,
    sites: sites,
    openSiteIds: ref.watch(openSiteIdsProvider),
    now: DateTime.now(),
  );
});
```

- Change `activeWorkspaceIdProvider`'s doc to `/// The viewed chip (dashboard spec §4.2). Null means the first workspace.`

`OpenContainersState.throwawaysIn` stays. Its test in `open_containers_test.dart` still pins it, and it is how a throwaway counts under a workspace.

- [ ] **Step 5: The chip row**

`lib/ui/features/dashboard/views/workspace_chips.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';

/// One workspace's chip, already reduced to what it shows.
class WorkspaceChip {
  const WorkspaceChip({required this.id, required this.name, required this.selected});

  final String id;
  final String name;

  /// The viewed workspace.
  final bool selected;
}

/// Dashboard spec §4.2: the top of Sites. One chip per workspace, in the
/// vault's order, then `+`, scrolling sideways. A tap views a workspace, a
/// long-press opens its form (`10b`), and `+` makes a new one. Deleting stays
/// in Settings ▸ Workspaces. No jade: the selected chip is drawn like `2a`'s
/// selected mode chip. [badge] is the viewed workspace's `WIPES ON EXIT`,
/// fixed at the row's end (plan D3).
class WorkspaceChips extends StatelessWidget {
  const WorkspaceChips({
    super.key,
    required this.chips,
    required this.onPick,
    required this.onEdit,
    required this.onNew,
    this.badge,
  });

  final List<WorkspaceChip> chips;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onEdit;
  final VoidCallback onNew;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 18, 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 18, right: 8),
                  child: Row(
                    children: [
                      for (final chip in chips) ...[_chip(chip), const SizedBox(width: 8)],
                      IconTap(
                        glyph: AppGlyph.plus,
                        label: 'New workspace',
                        onTap: onNew,
                        size: 32,
                        iconSize: 14,
                        color: C.textMuted,
                        background: C.button,
                        radius: 16,
                      ),
                    ],
                  ),
                ),
              ),
              if (badge != null) Text(badge!, style: T.barBadge),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }

  Widget _chip(WorkspaceChip chip) {
    return Semantics(
      button: true,
      selected: chip.selected,
      child: GestureDetector(
        onTap: () => onPick(chip.id),
        onLongPress: () => onEdit(chip.id),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: chip.selected ? C.selected : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: chip.selected ? C.line10 : C.line07),
          ),
          child: Text(
            chip.name,
            style: ui(
              size: 12.5,
              weight: 500,
              color: chip.selected ? C.textPrimary : C.tabInactive,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: The body**

Replace `lib/ui/features/dashboard/views/dashboard_body.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../view_models/dashboard_view.dart';
import 'empty_workspace.dart';
import 'session_row.dart';
import 'workspace_chips.dart';

/// The Sites tab (dashboard spec §4.2–§4.4, replacing `1b`'s layout): the
/// workspace chips, then the viewed workspace's sites as one list with no
/// titles and no count, then [footer]. It takes a finished view model and
/// callbacks, so it can be pumped in a widget test with no providers and no
/// database.
class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.view,
    required this.chips,
    required this.onPickWorkspace,
    required this.onEditWorkspace,
    required this.onNewWorkspace,
    required this.onOpenSite,
    required this.onSiteMenu,
    required this.footer,
  });

  final DashboardView view;
  final List<WorkspaceChip> chips;
  final ValueChanged<String> onPickWorkspace;
  final ValueChanged<String> onEditWorkspace;
  final VoidCallback onNewWorkspace;
  final void Function(String siteId) onOpenSite;
  final void Function(String siteId) onSiteMenu;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            WorkspaceChips(
              chips: chips,
              onPick: onPickWorkspace,
              onEdit: onEditWorkspace,
              onNew: onNewWorkspace,
              badge: view.wipesOnExit ? 'WIPES ON EXIT' : null,
            ),
            Expanded(child: _list()),
            footer,
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (view.isEmpty) return const EmptyWorkspace();
    return ListView(
      padding: const EdgeInsets.only(top: 6),
      children: [
        for (final entry in view.rows)
          SessionRow(
            key: ValueKey(entry.siteId),
            entry: entry,
            onTap: () => onOpenSite(entry.siteId),
            onLongPress: () => onSiteMenu(entry.siteId),
          ),
      ],
    );
  }
}
```

- [ ] **Step 7: The workspace forms, shared**

In `lib/ui/features/workspaces/views/workspaces_route.dart`, turn `_create`, `_edit` and `_byId` into top-level functions. `WorkspacesRoute` calls them, and `_delete` uses `_workspaceById`. Replace everything from `class WorkspacesRoute` to the end of `_edit` with:

```dart
class WorkspacesRoute extends ConsumerWidget {
  const WorkspacesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(workspaceListItemsProvider);
    return WorkspacesScreen(
      items: items.value ?? const [],
      onOpen: (id) => editWorkspace(context, ref, id),
      onDelete: (id) => _delete(context, ref, id),
      onNewWorkspace: () => createWorkspace(context, ref),
      onBack: () => Navigator.pop(context),
    );
  }
```

keep `_delete` inside the class with `final workspace = await _workspaceById(ref, id);` in place of `_byId`, close the class, and add after it:

```dart
Future<Workspace?> _workspaceById(WidgetRef ref, String id) async {
  for (final workspace in await ref.read(workspacesProvider.future)) {
    if (workspace.id == id) return workspace;
  }
  return null;
}

/// `10b` for a new workspace: Settings ▸ Workspaces' "+ New workspace", and
/// the dashboard's `+` chip (dashboard spec §4.2).
void createWorkspace(BuildContext context, WidgetRef ref) {
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => WorkspaceFormScreen(
      title: 'New workspace',
      initialName: '',
      initialMarkerIndex: 0,
      initialStorageRule: StorageRule.keep,
      initialRequirePin: false,
      initialShowInDecoy: false,
      onSave: (result) async {
        await ref.read(workspaceActionsProvider).create(result);
        workspacesChanged(ref);
        if (context.mounted) Navigator.pop(context);
      },
      onClose: () => Navigator.pop(context),
    ),
  ));
}

/// `10b` for workspace [id]: a tap on its row in Settings ▸ Workspaces, or a
/// long-press on its dashboard chip (dashboard spec §4.2). The spec draws only
/// the create form. Editing reuses it, titled with the workspace's own name
/// rather than copy the spec never wrote.
Future<void> editWorkspace(BuildContext context, WidgetRef ref, String id) async {
  final workspace = await _workspaceById(ref, id);
  if (workspace == null || !context.mounted) return;
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => WorkspaceFormScreen(
      title: workspace.name,
      initialName: workspace.name,
      initialMarkerIndex: workspace.markerIndex,
      initialStorageRule: workspace.storageRule,
      initialRequirePin: workspace.requirePin,
      initialShowInDecoy: workspace.showInDecoy,
      onSave: (result) async {
        await ref.read(workspaceActionsProvider).update(workspace, result);
        workspacesChanged(ref);
        if (context.mounted) Navigator.pop(context);
      },
      onClose: () => Navigator.pop(context),
    ),
  ));
}
```

- [ ] **Step 8: `SitesTab` with chips**

In `lib/ui/features/dashboard/views/sites_tab.dart`, replace everything above `class _SearchRoute` with the code below, and leave `_SearchRoute` and `_SearchRouteState` as they are. The dropdown menu goes and the chips come in. The search screen and `+ Add site` stay until Task 7:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/views/container_route.dart';
import '../../search/view_models/providers.dart'
    show allSitesProvider, searchQueryProvider, searchResultsProvider, sitesChanged;
import '../../search/view_models/search_view.dart' show SearchResultEntry;
import '../../search/views/search_screen.dart';
import '../../workspaces/views/workspaces_route.dart' show createWorkspace, editWorkspace;
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import 'dashboard_footer.dart';
import 'site_row_actions.dart';
import 'workspace_chips.dart';

/// The dashboard's Sites tab (dashboard spec §4.2–§4.4): workspace chips and
/// the viewed workspace's sites.
class SitesTab extends ConsumerStatefulWidget {
  const SitesTab({super.key});

  @override
  ConsumerState<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<SitesTab> {
  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => DashboardBody(
        view: view,
        chips: [
          for (final workspace in workspaces)
            WorkspaceChip(
              id: workspace.id,
              name: workspace.name,
              selected: workspace.id == view.workspaceId,
            ),
        ],
        onPickWorkspace: (id) => ref.read(activeWorkspaceIdProvider.notifier).state = id,
        onEditWorkspace: (id) => editWorkspace(context, ref, id),
        onNewWorkspace: () => createWorkspace(context, ref),
        onOpenSite: _openSite,
        onSiteMenu: (siteId) => showSiteRowMenu(context, ref, siteId),
        footer: DashboardFooter(
          onAddSite: _addSite,
          onSearch: () {
            ref.invalidate(searchQueryProvider);
            ref.invalidate(allSitesProvider);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const _SearchRoute()));
          },
          emphasise: view.isEmpty,
        ),
      ),
    );
  }

  Future<void> _addSite() async {
    final workspaces = await ref.read(workspacesProvider.future);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddSiteScreen(
        workspaces: workspaces,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          sitesChanged(ref);
          if (!mounted) return;
          Navigator.pop(context);
        },
      ),
    ));
  }

  // Tabs spec §4.2: an open container is shown as it is, with no second open;
  // otherwise it opens. Either way through the one host route.
  Future<void> _openSite(String siteId) async {
    openSite(ref, siteId);
    final site = await ref.read(siteRepositoryProvider).byId(siteId);
    if (site == null || !mounted) return;
    showContainer(context, ref, site);
  }
}
```

- [ ] **Step 9: Delete the bar and the menu**

```bash
git rm lib/ui/features/dashboard/views/workspace_bar.dart lib/ui/features/dashboard/views/workspace_menu.dart test/ui/features/dashboard/workspace_bar_test.dart test/ui/features/workspace_menu_test.dart
```

Run `grep -rn "WorkspaceMenu\|WorkspaceBar\|workspaceOptionsProvider\|workspaceMeta\|sessionCount" lib test`. Expected: no output.

- [ ] **Step 10: Run the tests and see them pass**

Run: `flutter test test/ui/features/dashboard test/ui/features/dashboard_body_test.dart test/ui/features/workspaces test/ui/features/workspaces_screen_test.dart test/ui/features/container`
Expected: PASS.

- [ ] **Step 11: Analyze and commit**

Run: `flutter analyze`. Expected: no issues.

```bash
git add -A lib/ui/features/dashboard lib/ui/features/workspaces test/ui/features/dashboard test/ui/features/dashboard_body_test.dart
git commit -m "feat(dashboard): workspace chips and one list, open sites first"
```

---

### Task 7: The search field

**Files:**
- Modify: `lib/ui/features/dashboard/views/dashboard_footer.dart` (rewritten), `lib/ui/features/dashboard/views/dashboard_body.dart`, `lib/ui/features/dashboard/views/sites_tab.dart` (rewritten), `lib/ui/features/search/view_models/providers.dart`, `lib/ui/features/dashboard/view_models/providers.dart` (a doc comment), `lib/domain/site_search.dart` (a doc comment)
- Delete: `lib/ui/features/search/views/search_screen.dart`, `lib/ui/features/search/view_models/search_view.dart`, `test/ui/features/search/search_screen_test.dart`, `test/ui/features/search/search_view_test.dart`, `test/ui/features/search/search_providers_test.dart`
- Test: `test/ui/features/dashboard/dashboard_footer_test.dart` (rewritten), `test/ui/features/dashboard_body_test.dart`, `test/ui/features/dashboard/dashboard_search_test.dart` (new)

**Interfaces:**
- Consumes:
  - `suggestionsFor(text:, route:, saved:, workspaces:, engine:)`, `submittedSuggestion`, `destinationFor(url, route:, saved:)` and `buildThrowaway(destination:, workspaceId:, newId:)` (Task 2)
  - `defaultRouteProvider` (Task 1); `AddSiteScreen(initialWorkspaceId:, defaultRoute:)` (Task 4)
  - `DashboardView.workspaceId`, `WorkspaceChip`, `createWorkspace`, `editWorkspace` (Task 6)
  - `showContainer(context, ref, site, {initialUrl, throwaway, openerSiteId})` and `AddressSuggestions` (existing)
- Produces:
  - `DashboardFooter({required TextEditingController controller, required FocusNode focusNode, required ValueChanged<String> onChanged, required ValueChanged<String> onSubmitted, required VoidCallback onAddSite, bool emphasise = false})`. Its `TextField` has the key `dashboard-search`.
  - `DashboardBody(..., Widget? cover)`: shown in place of the list while non-null.
  - Removed: `SearchScreen`, `SearchResultEntry`, `searchResults`, `searchQueryProvider`, `searchResultsProvider`. Kept: `allSitesProvider`, `sitesChanged`, `sitesChangedIn`, `sitesMatching`.

- [ ] **Step 1: Write the failing tests**

Replace the whole of `test/ui/features/dashboard/dashboard_footer_test.dart` with:

```dart
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/dashboard/views/dashboard_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

Future<List<String>> _pump(WidgetTester tester, {bool emphasise = false}) async {
  final calls = <String>[];
  final controller = TextEditingController();
  final focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DashboardFooter(
          controller: controller,
          focusNode: focus,
          onChanged: (text) => calls.add('changed $text'),
          onSubmitted: (text) => calls.add('submitted $text'),
          onAddSite: () => calls.add('add'),
          emphasise: emphasise,
        ),
      ),
    ),
  ));
  return calls;
}

void main() {
  testWidgets("a search field with the address bar's placeholder, then + (spec §5)",
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.text('Search or type an address'), findsOneWidget);
    expect(find.text('+ Add site'), findsNothing);
    expect(tester.getSize(findIconTap('Add site')), const Size(46, 46));
    expect(find.bySemanticsLabel('Add site'), findsOneWidget);
    expect(tester.getCenter(findIconTap('Add site')).dx,
        greaterThan(tester.getCenter(find.byType(TextField)).dx));
    semantics.dispose();
  });

  testWidgets('typing, the keyboard action and + are reported', (tester) async {
    final calls = await _pump(tester);

    await tester.enterText(find.byKey(const Key('dashboard-search')), 'forum');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.tap(findIconTap('Add site'));

    expect(calls, ['changed forum', 'submitted forum', 'add']);
  });

  testWidgets('typed addresses stay out of the keyboard dictionary', (tester) async {
    await _pump(tester);
    final field = tester.widget<TextField>(find.byKey(const Key('dashboard-search')));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.keyboardType, TextInputType.url);
  });

  testWidgets('+ is jade only on an empty workspace; the field never is (§4.4)', (tester) async {
    await _pump(tester);
    var plus = tester.widget<IconTap>(findIconTap('Add site'));
    expect(plus.background, C.button);
    expect(plus.color, C.icon);

    await _pump(tester, emphasise: true);
    plus = tester.widget<IconTap>(findIconTap('Add site'));
    expect(plus.background, C.jade);
    expect(plus.color, C.bg);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.plus)).color, C.bg);
  });
}
```

In `test/ui/features/dashboard_body_test.dart`, give `_pump` a `Widget? cover` parameter, pass `cover: cover,` to `DashboardBody`, and add:

```dart
  testWidgets("a cover takes the list's place: the search field's suggestions", (tester) async {
    await _pump(tester, _personal(), cover: const Text('suggestions'));

    expect(find.text('suggestions'), findsOneWidget);
    expect(find.text('Notes'), findsNothing);
    expect(find.text('Personal'), findsOneWidget, reason: 'the chips stay');
    expect(find.text('the footer'), findsOneWidget);
  });
```

`test/ui/features/dashboard/dashboard_search_test.dart`:

```dart
import 'dart:async';

import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/container/views/container_route.dart';
import 'package:container/ui/features/dashboard/views/sites_tab.dart';
import 'package:container/ui/features/settings/view_models/providers.dart'
    show defaultRouteProvider, defaultRouteSettingKey;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/dashboard_harness.dart';
import '../../../support/glyph_finders.dart';

const _forum = Site(
  id: 'forum', workspaceId: 'w1', name: 'Forum', monogram: 'Fr',
  url: 'https://forum.example.com', profileId: 'p-forum',
);
const _ledger = Site(
  id: 'ledger', workspaceId: 'w2', name: 'Ledger', monogram: 'Lg',
  url: 'https://ledger.example.org', profileId: 'p-ledger',
);

const _socks = ProxyRoute(
    mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw');

Map<String, String> _route(ProxyRoute route) => {defaultRouteSettingKey: route.toStored()};

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('dashboard-search')), text);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.go);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a word lists saved sites from every workspace, then the search row', (tester) async {
    await pumpDashboard(tester, sites: const [_forum, _ledger]);

    await _type(tester, 'example');

    expect(find.text('SAVED SITES'), findsOneWidget);
    expect(find.text('ledger.example.org · Work'), findsOneWidget);
    expect(find.text('forum.example.com · Personal'), findsOneWidget);
    expect(find.text('ITS OWN CONTAINER'), findsNWidgets(2));
    expect(find.text('Search DuckDuckGo for “example”'), findsOneWidget);
    expect(find.text('THIS CONTAINER'), findsNothing);
  });

  testWidgets('an unsaved address on a direct default opens a throwaway with no opener',
      (tester) async {
    final h = await pumpDashboard(tester);

    await _type(tester, 'news.example.org/today');
    expect(find.text('THROWAWAY'), findsNWidgets(2));
    await _enter(tester);

    final id = h.engine.openedAsThrowaway.single;
    final opened = h.engine.openedSites[id]!;
    expect(opened.url, 'https://news.example.org/today');
    expect(opened.proxyMode, ProxyMode.direct);
    expect(opened.workspaceId, 'w1', reason: 'the viewed chip');
    expect(h.tabs.byId(id)!.openerSiteId, isNull);
    expect(h.tabs.viewedSiteId, id);
    expect(find.byType(ContainerRoute), findsOneWidget);
  });

  testWidgets('on a SOCKS5 default the throwaway goes out on it, login and all', (tester) async {
    final h = await pumpDashboard(tester, settings: _route(_socks));

    await _type(tester, 'news.example.org');
    expect(find.text('THROWAWAY · SOCKS5'), findsNWidgets(2));
    await _enter(tester);

    final opened = h.engine.openedSites[h.engine.openedAsThrowaway.single]!;
    expect((opened.proxyMode, opened.proxyHost, opened.proxyPort),
        (ProxyMode.socks5, '127.0.0.1', 9050));
    expect((opened.proxyUser, opened.proxyPassword), ('alice', 'pw'));
  });

  testWidgets('with per-site login each throwaway gets its own', (tester) async {
    final h = await pumpDashboard(tester,
        settings: _route(const ProxyRoute(
            mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, loginPerSite: true)));

    await _type(tester, 'news.example.org');
    await _enter(tester);

    final opened = h.engine.openedSites[h.engine.openedAsThrowaway.single]!;
    expect(opened.proxyLoginPerSite, isTrue);
    expect(opened.proxyUser, isNull);
  });

  testWidgets("a saved site's host opens its own container, not a throwaway", (tester) async {
    final h = await pumpDashboard(tester, sites: const [_forum]);

    await _type(tester, 'forum.example.com/latest');
    await _enter(tester);

    expect(h.engine.openedAsThrowaway, isEmpty);
    expect(h.tabs.viewedSiteId, 'forum');
    expect(h.engine.openedInitialUrls['forum'], 'https://forum.example.com/latest');
  });

  testWidgets('a saved site that is already open is shown, not opened twice', (tester) async {
    final h = await pumpDashboard(tester, sites: const [_forum]);
    await tester.runAsync(() => h.registry.view(_forum));
    h.registry.showDashboard();
    await tester.pumpAndSettle();

    await _type(tester, 'forum.example.com/latest');
    await _enter(tester);

    expect(h.tabs.containers.map((c) => c.siteId), ['forum']);
    expect(h.tabs.viewedSiteId, 'forum');
    expect(h.engine.loaded.single.url, 'https://forum.example.com/latest');
  });

  testWidgets('words open the search engine on the default route', (tester) async {
    final h = await pumpDashboard(tester);

    await _type(tester, 'two words');
    await _enter(tester);

    final opened = h.engine.openedSites[h.engine.openedAsThrowaway.single]!;
    expect(opened.url, startsWith('https://duckduckgo.com/?q=two'));
  });

  testWidgets("a throwaway counts under the viewed chip's workspace", (tester) async {
    final h = await pumpDashboard(tester);
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await _type(tester, 'news.example.org');
    await _enter(tester);

    expect(h.engine.openedSites[h.engine.openedAsThrowaway.single]!.workspaceId, 'w2');
  });

  testWidgets('back from its first page closes and wipes it, to the dashboard, '
      'even with another container open', (tester) async {
    final h = await pumpDashboard(tester, sites: const [_forum]);
    await tester.runAsync(() => h.registry.view(_forum));
    h.registry.showDashboard();
    await tester.pumpAndSettle();
    await _type(tester, 'news.example.org');
    await _enter(tester);
    final id = h.engine.openedAsThrowaway.single;

    await systemBack(tester);

    expect(h.engine.closedWith[id], isTrue, reason: 'closed and wiped');
    expect(h.tabs.byId(id), isNull);
    expect(h.tabs.byId('forum'), isNotNull, reason: 'the other stays open');
    expect(find.byType(SitesTab), findsOneWidget);
    expect(find.byType(ContainerRoute), findsNothing);
  });

  testWidgets('back while searching clears the field and stays', (tester) async {
    await pumpDashboard(tester, sites: const [_forum]);
    await _type(tester, 'forum');
    expect(find.text('SAVED SITES'), findsOneWidget);

    await systemBack(tester);

    expect(find.text('SAVED SITES'), findsNothing);
    expect(find.text('Forum'), findsOneWidget, reason: 'the list is back');
    expect(tester.widget<TextField>(find.byKey(const Key('dashboard-search'))).controller!.text,
        isEmpty);
  });

  testWidgets('a tap outside the rows ends the search', (tester) async {
    await pumpDashboard(tester, sites: const [_forum]);
    await _type(tester, 'forum');

    await tester.tap(find.text('Nothing is fetched while you type.'));
    await tester.pumpAndSettle();

    expect(find.text('SAVED SITES'), findsNothing);
  });

  testWidgets('nothing is offered or opened before the default route is read', (tester) async {
    final h = await pumpDashboard(tester, overrides: [
      defaultRouteProvider.overrideWith((ref) => Completer<ProxyRoute>().future),
    ]);

    await _type(tester, 'news.example.org');
    expect(find.text('ADDRESS'), findsNothing);
    expect(find.textContaining('THROWAWAY'), findsNothing);
    await _enter(tester);

    expect(h.tabs.containers, isEmpty);
  });

  testWidgets("+ opens a new site's form on the viewed workspace and the default route",
      (tester) async {
    await pumpDashboard(tester, settings: _route(_socks));
    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    await tester.tap(findIconTap('Add site'));
    await tester.pumpAndSettle();

    final form = tester.widget<AddSiteScreen>(find.byType(AddSiteScreen));
    expect(form.initial, isNull);
    expect(form.initialWorkspaceId, 'w2');
    expect(form.defaultRoute, _socks);
  });

  testWidgets('saving that form adds the site to the vault', (tester) async {
    final h = await pumpDashboard(tester);
    await tester.tap(findIconTap('Add site'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('add-site-address')), 'example.com');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(h.sites.upserts.single.name, 'example.com');
    expect(h.sites.upserts.single.workspaceId, 'w1');
    expect(find.byType(AddSiteScreen), findsNothing);
  });
}
```

`find.text('Work')` is the chip here: the list is not covered, and no site is named Work.

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/ui/features/dashboard test/ui/features/dashboard_body_test.dart`
Expected: compile errors (`DashboardFooter`'s new parameters, `cover`).

- [ ] **Step 3: The footer**

Replace `lib/ui/features/dashboard/views/dashboard_footer.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';

/// Dashboard spec §5: the Sites tab's footer, within thumb reach. A search
/// field with the container address bar's own placeholder, then a 46px `+`
/// that opens the add-site form.
///
/// [emphasise] turns the `+` jade: on an empty workspace it is the one
/// affirmative action left (spec `5b`, §4.4). The field is never jade.
class DashboardFooter extends StatelessWidget {
  const DashboardFooter({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onAddSite,
    this.emphasise = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// The keyboard's action.
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAddSite;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Hairline(),
        ColoredBox(
          color: C.footer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: C.button,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      key: const Key('dashboard-search'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      cursorColor: C.textPrimary,
                      style: ui(size: 13.5, color: C.textPrimary),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      // Typed addresses stay out of the keyboard app's
                      // dictionary and suggestion strip, as in the address bar.
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search or type an address',
                        hintStyle: ui(size: 13.5, color: C.textFaint),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconTap(
                  glyph: AppGlyph.plus,
                  label: 'Add site',
                  onTap: onAddSite,
                  size: 46,
                  iconSize: 20,
                  radius: 14,
                  background: emphasise ? C.jade : C.button,
                  color: emphasise ? C.bg : C.icon,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: The body's cover**

In `dashboard_body.dart`, add the constructor parameter `this.cover,` with:

```dart
  /// Shown in the list's place while non-null: the search field's
  /// suggestions (dashboard spec §5). The chips and the footer stay.
  final Widget? cover;
```

and change `Expanded(child: _list()),` to `Expanded(child: cover ?? _list()),`.

- [ ] **Step 5: `SitesTab`, final**

Replace `lib/ui/features/dashboard/views/sites_tab.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../domain/models/address_suggestion.dart';
import '../../../../domain/models/destination.dart';
import '../../../../domain/models/search_engine.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/throwaway.dart';
import '../../../../domain/models/workspace.dart';
import '../../../core/tokens.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/views/address_suggestions.dart';
import '../../container/views/container_route.dart';
import '../../search/view_models/providers.dart' show allSitesProvider, sitesChanged;
import '../../settings/view_models/providers.dart' show defaultRouteProvider, searchEngineProvider;
import '../../workspaces/views/workspaces_route.dart' show createWorkspace, editWorkspace;
import '../view_models/providers.dart';
import 'dashboard_body.dart';
import 'dashboard_footer.dart';
import 'site_row_actions.dart';
import 'workspace_chips.dart';

/// The dashboard's Sites tab (dashboard spec §4.2–§6): workspace chips, the
/// viewed workspace's sites, and the search field, whose suggestions cover
/// the list while it holds text.
class SitesTab extends ConsumerStatefulWidget {
  const SitesTab({super.key});

  @override
  ConsumerState<SitesTab> createState() => _SitesTabState();
}

class _SitesTabState extends ConsumerState<SitesTab> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  /// The field holds more than whitespace: its suggestions cover the list.
  bool get _searching => _search.text.trim().isNotEmpty;

  void _endSearch() {
    _search.clear();
    _searchFocus.unfocus();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const <Workspace>[];
    // What typed text is matched against (spec §5), watched from the start so
    // the first keystroke has them. Until the default route is read nothing
    // is offered: a throwaway's tag, and so its route, would be a guess.
    final saved = ref.watch(allSitesProvider).valueOrNull ?? const <Site>[];
    final engine = ref.watch(searchEngineProvider).valueOrNull ?? SearchEngine.duckDuckGo;
    final route = ref.watch(defaultRouteProvider).valueOrNull;
    List<AddressSuggestion> suggest(String text) => route == null
        ? const []
        : suggestionsFor(
            text: text, route: route, saved: saved, workspaces: workspaces, engine: engine);

    return dashboard.when(
      loading: () => const Scaffold(backgroundColor: C.bg),
      error: (error, _) => Scaffold(
        backgroundColor: C.bg,
        body: Center(child: Text('$error')),
      ),
      data: (view) => PopScope(
        // Plan D7: back while searching clears the field and stays.
        canPop: !_searching,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _searching) _endSearch();
        },
        child: DashboardBody(
          view: view,
          chips: [
            for (final workspace in workspaces)
              WorkspaceChip(
                id: workspace.id,
                name: workspace.name,
                selected: workspace.id == view.workspaceId,
              ),
          ],
          onPickWorkspace: (id) => ref.read(activeWorkspaceIdProvider.notifier).state = id,
          onEditWorkspace: (id) => editWorkspace(context, ref, id),
          onNewWorkspace: () => createWorkspace(context, ref),
          onOpenSite: _openSite,
          onSiteMenu: (siteId) => showSiteRowMenu(context, ref, siteId),
          cover: _searching
              ? AddressSuggestions(
                  suggestions: suggest(_search.text),
                  onPick: (row) => _open(row.destination, view.workspaceId),
                  onDismiss: _endSearch,
                )
              : null,
          footer: DashboardFooter(
            controller: _search,
            focusNode: _searchFocus,
            onChanged: (_) => setState(() {}),
            // The address row if there is one, else the search row: the
            // container's address bar makes the same choice.
            onSubmitted: (text) {
              final pick = submittedSuggestion(suggest(text));
              if (pick == null) {
                _endSearch();
              } else {
                _open(pick.destination, view.workspaceId);
              }
            },
            onAddSite: () => _addSite(view.workspaceId),
            emphasise: view.isEmpty,
          ),
        ),
      ),
    );
  }

  /// A suggestion picked, or the keyboard's action (spec §5).
  void _open(Destination destination, String? workspaceId) {
    _endSearch();
    unawaited(_openDestination(destination, workspaceId));
  }

  /// As the container's address bar opens one, with no opener. The
  /// suggestion was worked out from copies of the vault's sites and of the
  /// default route, which can be out of date, so it is decided again here
  /// against both as they are now: a saved site opens with its current route
  /// and profile, never one removed since.
  Future<void> _openDestination(Destination suggested, String? workspaceId) async {
    final saved = await ref.read(siteRepositoryProvider).all();
    final route = await ref.read(defaultRouteProvider.future);
    if (!mounted) return;
    switch (destinationFor(suggested.url, route: route, saved: saved)) {
      case ThisContainer():
        // Only a container's own address bar has one.
        return;
      case SavedSiteContainer(:final site, :final url):
        // As a row opens a site: the visit recorded. Its stored address is
        // not touched.
        openSite(ref, site.id);
        showContainer(context, ref, site, initialUrl: url.toString());
      case final Throwaway target:
        if (workspaceId == null) return;
        // No opener: back from its first page closes it to here (spec §5).
        showContainer(
          context,
          ref,
          buildThrowaway(destination: target, workspaceId: workspaceId, newId: newProfileId),
          throwaway: true,
        );
    }
  }

  /// The `+` (spec §5, §6): a new site's form, on the viewed workspace and
  /// the default route.
  Future<void> _addSite(String? workspaceId) async {
    final workspaces = await ref.read(workspacesProvider.future);
    final route = await ref.read(defaultRouteProvider.future);
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (formContext) => AddSiteScreen(
        workspaces: workspaces,
        initialWorkspaceId: workspaceId,
        defaultRoute: route,
        onSave: (site) async {
          await ref.read(siteRepositoryProvider).upsert(site);
          sitesChanged(ref);
          if (formContext.mounted) Navigator.pop(formContext);
        },
      ),
    ));
  }

  // Tabs spec §4.2: an open container is shown as it is, with no second open;
  // otherwise it opens. Either way through the one host route.
  Future<void> _openSite(String siteId) async {
    openSite(ref, siteId);
    final site = await ref.read(siteRepositoryProvider).byId(siteId);
    if (site == null || !mounted) return;
    showContainer(context, ref, site);
  }
}
```

- [ ] **Step 6: Delete the search screen**

```bash
git rm lib/ui/features/search/views/search_screen.dart lib/ui/features/search/view_models/search_view.dart test/ui/features/search/search_screen_test.dart test/ui/features/search/search_view_test.dart test/ui/features/search/search_providers_test.dart
```

In `lib/ui/features/search/view_models/providers.dart`, delete `searchQueryProvider`, `searchResultsProvider`, the `search_view.dart` import, and `workspacesProvider, openSiteIdsProvider` from the dashboard import's `show`. Change `allSitesProvider`'s doc to: `/// Every site in the open vault: what the container's address bar and the dashboard's search field match against.` and keep the rest of it unchanged.

In `lib/domain/site_search.dart`, change the doc's first sentence to `/// What a typed text matches: [query], trimmed and case-insensitive, found in a site's name or host.` and its last sentence to `Shared by the container's address bar and the dashboard's search field (`suggestionsFor`), so the two never disagree about what matches.`

In `lib/ui/features/dashboard/view_models/providers.dart`, change `openSite`'s doc to: `/// Records a visit to [siteId]. Shared by a dashboard row's tap and the saved-site destinations of the address bar and the dashboard's search field, so all three agree on what "opening a site" records. The registry, not this, decides what is open (tabs spec §5.4): `showContainer` tells it.`

Run `grep -rn "SearchScreen\|searchQueryProvider\|searchResultsProvider\|SearchResultEntry\|search_view\|search_screen" lib test`. Expected: no output.

- [ ] **Step 7: Run the tests and see them pass**

Run: `flutter test test/ui/features/dashboard test/ui/features/dashboard_body_test.dart test/domain test/no_glyphs_test.dart test/ui/features/container_route_test.dart`
Expected: PASS. If `no_glyphs_test.dart` names the deleted `+ Add site` label line, as its comment at line 10 and the scan at line 183 do, leave both. They assert the old label does not appear, which is still true.

- [ ] **Step 8: Analyze and commit**

Run: `flutter analyze`. Expected: no issues.

```bash
git add -A lib/ui/features/dashboard lib/ui/features/search lib/domain/site_search.dart test/ui/features/dashboard test/ui/features/dashboard_body_test.dart test/ui/features/search
git commit -m "feat(dashboard): a search field in place of + Add site; the search screen goes"
```

---

### Task 8: Swipe between open containers

**Files:**
- Modify: `lib/domain/tabs.dart`, `lib/ui/features/container/views/container_bottom_bar.dart`, `lib/ui/features/container/views/container_screen.dart`, `lib/ui/features/container/views/container_route.dart`
- Test: `test/domain/tabs_test.dart`, `test/ui/features/container/chrome_bars_test.dart`, `test/ui/features/container_route_test.dart`

**Interfaces:**
- Consumes: `OpenContainer.listed`, `OpenContainersState.containers`, `_viewContainer(siteId)` in `ContainerRoute` (existing).
- Produces:
  - `({String? previous, String? next}) swipeNeighbours(List<OpenContainer> containers, String viewedSiteId)`
  - `ContainerBottomBar(..., VoidCallback? onNextContainer, VoidCallback? onPreviousContainer)`
  - `ContainerScreen(..., VoidCallback? onNextContainer, VoidCallback? onPreviousContainer)`

- [ ] **Step 1: Write the failing tests**

In `test/domain/tabs_test.dart`, add inside `main()`:

```dart
  group('swipeNeighbours (dashboard spec §9, plan D1)', () {
    final containers = [_container('a'), _container('b'), _container('c')];

    test('the containers opened just before and just after the viewed one', () {
      expect(swipeNeighbours(containers, 'b'), (previous: 'a', next: 'c'));
    });

    test('nothing past either end', () {
      expect(swipeNeighbours(containers, 'a'), (previous: null, next: 'b'));
      expect(swipeNeighbours(containers, 'c'), (previous: 'b', next: null));
    });

    test('only listed containers: a refused saved site is skipped, a refused throwaway is not', () {
      final mixed = [
        _container('a'),
        _container('r', refusal: _refused),
        _container('t', throwaway: true, refusal: _refused),
        _container('c'),
      ];
      expect(swipeNeighbours(mixed, 'a'), (previous: null, next: 't'));
      expect(swipeNeighbours(mixed, 'c'), (previous: 't', next: null));
    });

    test('one container, or one not listed, has none', () {
      expect(swipeNeighbours([_container('a')], 'a'), (previous: null, next: null));
      expect(swipeNeighbours(containers, 'gone'), (previous: null, next: null));
    });
  });
```

In `test/ui/features/container/chrome_bars_test.dart`, add inside `main()`. Add `import '../../../support/glyph_finders.dart';` if the file does not import it yet:

```dart
  group('the swipe between open containers (dashboard spec §9)', () {
    Future<List<String>> pumpBar(WidgetTester tester,
        {bool next = true, bool previous = true}) async {
      final calls = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ContainerBottomBar(
              openCount: 3,
              onBack: () => calls.add('back'),
              onForward: null,
              onOpenSwitcher: () => calls.add('switcher'),
              onMenu: () => calls.add('menu'),
              onNextContainer: next ? () => calls.add('next') : null,
              onPreviousContainer: previous ? () => calls.add('previous') : null,
            ),
          ),
        ),
      ));
      return calls;
    }

    testWidgets('a fling to the left views the next, to the right the previous', (tester) async {
      final calls = await pumpBar(tester);

      await tester.fling(find.byType(ContainerBottomBar), const Offset(-200, 0), 800);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ContainerBottomBar), const Offset(200, 0), 800);
      await tester.pumpAndSettle();

      expect(calls, ['next', 'previous']);
    });

    testWidgets('with no neighbour a fling does nothing', (tester) async {
      final calls = await pumpBar(tester, next: false, previous: false);

      await tester.fling(find.byType(ContainerBottomBar), const Offset(-200, 0), 800);
      await tester.fling(find.byType(ContainerBottomBar), const Offset(200, 0), 800);
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('at the last container only a fling to the right works', (tester) async {
      final calls = await pumpBar(tester, next: false);

      await tester.fling(find.byType(ContainerBottomBar), const Offset(-200, 0), 800);
      await tester.fling(find.byType(ContainerBottomBar), const Offset(200, 0), 800);
      await tester.pumpAndSettle();

      expect(calls, ['previous']);
    });

    testWidgets('a short drag does not switch and a tap still taps', (tester) async {
      final calls = await pumpBar(tester);
      final height = tester.getSize(find.byType(ContainerBottomBar)).height;

      await tester.drag(find.byType(ContainerBottomBar), Offset(-(height - 10), 0));
      await tester.pumpAndSettle();
      expect(calls, isEmpty, reason: 'shorter than the bar is tall');

      // A tap that moves a little, under the touch slop, is still a tap.
      await tester.dragFrom(tester.getCenter(findIconTap('Menu')), const Offset(6, 0));
      await tester.pumpAndSettle();
      await tester.tap(findIconTap('Back'));
      expect(calls, ['menu', 'back']);
    });
  });
```

In `test/ui/features/container_route_test.dart`, add `import 'package:container/ui/features/container/views/container_bottom_bar.dart';` and, inside `main()`:

```dart
  testWidgets('a fling on the bottom bar moves between open containers, in opening order',
      (tester) async {
    final engine = FakeContainerEngine();
    _standInForPlatformViews(tester);
    await _pump(tester, engine, _site());
    await _settle(tester);
    final registry = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(openContainersProvider.notifier);
    await tester.runAsync(() => registry.view(_market));
    await _settle(tester);
    expect(_tabs(tester).viewedSiteId, 'm1');

    await tester.fling(find.byType(ContainerBottomBar), const Offset(200, 0), 800);
    await tester.pumpAndSettle();
    expect(_tabs(tester).viewedSiteId, 's1', reason: 'right: the one opened before');

    await tester.fling(find.byType(ContainerBottomBar), const Offset(-200, 0), 800);
    await tester.pumpAndSettle();
    expect(_tabs(tester).viewedSiteId, 'm1', reason: 'left: the one opened after');
    expect(engine.openedSites.keys.toSet(), {'s1', 'm1'}, reason: 'switched, not reopened');
  });
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/domain/tabs_test.dart test/ui/features/container/chrome_bars_test.dart test/ui/features/container_route_test.dart`
Expected: compile errors (`swipeNeighbours`, `onNextContainer`).

- [ ] **Step 3: `swipeNeighbours`**

Append to `lib/domain/tabs.dart`:

```dart
/// Where a fling on the bottom bar goes (dashboard spec §9): the listed
/// container opened just before [viewedSiteId], and the one just after.
/// Null past either end, where nothing happens.
///
/// Opening order, not `2c`'s (plan D1): `2c` puts the viewed container first,
/// so its order changes with every swipe, and a swipe right would never find
/// anything before the one it had just moved to.
({String? previous, String? next}) swipeNeighbours(
  List<OpenContainer> containers,
  String viewedSiteId,
) {
  final listed = [for (final c in containers) if (c.listed) c.siteId];
  final at = listed.indexOf(viewedSiteId);
  if (at < 0) return (previous: null, next: null);
  return (
    previous: at > 0 ? listed[at - 1] : null,
    next: at < listed.length - 1 ? listed[at + 1] : null,
  );
}
```

- [ ] **Step 4: The bar takes a horizontal drag**

Replace `lib/ui/features/container/views/container_bottom_bar.dart`'s class with a stateful one. The bar's `Container` and its children are unchanged, with every `onX` read through `widget.`:

```dart
/// Browser-chrome spec §6.1's bottom bar, replacing `2b`'s floating pill: a
/// flat `C.footer` bar with a hairline above. Back and forward are 40px
/// round targets, dimmed and inert with no history that way (§3.3). The
/// centre `N OPEN ▲` pill keeps `2b`'s style and opens the `2c` switcher;
/// ☰ opens the menu (§6.4).
///
/// Dashboard spec §9: a fling sideways across the bar views the next open
/// container (left) or the previous one (right). It must travel at least the
/// bar's own height, so a tap that moves a little is still a tap.
class ContainerBottomBar extends StatefulWidget {
  const ContainerBottomBar({
    super.key,
    required this.openCount,
    required this.onBack,
    required this.onForward,
    required this.onOpenSwitcher,
    required this.onMenu,
    this.onNextContainer,
    this.onPreviousContainer,
  });

  final int openCount;

  /// Null when the page cannot go back.
  final VoidCallback? onBack;

  /// Null when the page cannot go forward.
  final VoidCallback? onForward;
  final VoidCallback onOpenSwitcher;
  final VoidCallback onMenu;

  /// Null at that end: a fling that way does nothing.
  final VoidCallback? onNextContainer;
  final VoidCallback? onPreviousContainer;

  @override
  State<ContainerBottomBar> createState() => _ContainerBottomBarState();
}

class _ContainerBottomBarState extends State<ContainerBottomBar> {
  /// How far the current horizontal drag has gone; left is negative.
  double _travel = 0;

  void _dragEnded() {
    final threshold = context.size?.height ?? double.infinity;
    if (_travel <= -threshold) {
      widget.onNextContainer?.call();
    } else if (_travel >= threshold) {
      widget.onPreviousContainer?.call();
    }
    _travel = 0;
  }

  @override
  Widget build(BuildContext context) {
    // With nowhere to go there is no drag recogniser at all, so the buttons'
    // taps are exactly as they were.
    final swipes = widget.onNextContainer != null || widget.onPreviousContainer != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: swipes ? (_) => _travel = 0 : null,
      onHorizontalDragUpdate: swipes ? (details) => _travel += details.delta.dx : null,
      onHorizontalDragEnd: swipes ? (_) => _dragEnded() : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: const BoxDecoration(
          color: C.footer,
          border: Border(top: BorderSide(color: C.line07)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconTap(glyph: AppGlyph.back, label: 'Back', onTap: widget.onBack),
            IconTap(glyph: AppGlyph.forward, label: 'Forward', onTap: widget.onForward),
            Semantics(
              label: 'Open sessions',
              button: true,
              excludeSemantics: true,
              onTap: widget.onOpenSwitcher,
              child: GestureDetector(
                onTap: widget.onOpenSwitcher,
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
                      Text('${widget.openCount} OPEN',
                          style: ui(size: 11, weight: 500, color: C.textSecondary)),
                      const SizedBox(width: 7),
                      const AppIcon(AppGlyph.chevronUp, size: 12, color: C.jade),
                    ],
                  ),
                ),
              ),
            ),
            IconTap(glyph: AppGlyph.menu, label: 'Menu', onTap: widget.onMenu),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Through the screen to the route**

In `container_screen.dart`, add the constructor parameters `this.onNextContainer,` and `this.onPreviousContainer,`, with:

```dart
  /// Dashboard spec §9's swipe on the bottom bar. Null at that end.
  final VoidCallback? onNextContainer;
  final VoidCallback? onPreviousContainer;
```

and pass `onNextContainer: widget.onNextContainer,` and `onPreviousContainer: widget.onPreviousContainer,` to `ContainerBottomBar(`.

In `container_route.dart`'s `build`, after `final openedUrl = _openedUrl(viewed);`, add:

```dart
    final neighbours = swipeNeighbours(state.containers, siteId);
    final previous = neighbours.previous;
    final next = neighbours.next;
```

and pass to `ContainerScreen(`:

```dart
        // Dashboard spec §9: switched in place, as a tap on a `2c` row is.
        onPreviousContainer: previous == null ? null : () => _viewContainer(previous),
        onNextContainer: next == null ? null : () => _viewContainer(next),
```

- [ ] **Step 6: Run the tests and see them pass**

Run: `flutter test test/domain/tabs_test.dart test/ui/features/container test/ui/features/container_route_test.dart test/ui/features/container_screen_test.dart test/ui/features/switcher_sheet_test.dart`
Expected: PASS.

- [ ] **Step 7: Analyze and commit**

Run: `flutter analyze`. Expected: no issues.

```bash
git add lib/domain/tabs.dart lib/ui/features/container test/domain/tabs_test.dart test/ui/features/container/chrome_bars_test.dart test/ui/features/container_route_test.dart
git commit -m "feat(2b): a fling on the bottom bar moves between open containers"
```

---

### Task 9: Gates, documentation and the device checks

**Files:**
- Modify: `CLAUDE.md`, this plan (its Verification section)

- [ ] **Step 1: The whole suite and the build**

Run each, with the Bash sandbox disabled:

```bash
flutter analyze
flutter test
flutter build apk --debug
```

Expected: `No issues found!`; all tests pass. Record the count: the baseline on `main` at `98d8205` plus this plan's, minus the deleted search, bar and menu tests. The build shows zero `e:` lines. No Kotlin changed, but the build is the only check that compiles the app as a whole. If anything fails, fix it in the task that owns the code, then rerun all three.

- [ ] **Step 2: Record the plan in `CLAUDE.md`**

Add a row to the plans table after Plan 17's:

```markdown
| 18 — Dashboard redesign | `2026-10-03-dashboard-redesign.md` | **Done** (<date>) | Implements `docs/superpowers/specs/2026-10-03-dashboard-redesign-design.md` (the user's nine rulings of 2026-10-03, approved section by section). The dashboard is a shell with three tabs (Sites · Today · Settings; `AppGlyph.sites/today/settings`; back on Today or Settings shows Sites; the bar hides while the keyboard is up). Sites has workspace chips (tap views, long-press opens `10b`, `+` makes one; delete stays in Settings ▸ Workspaces), one list with open sites first and no `OPEN NOW`/`IDLE`/`N SESSIONS`, and a search field in place of `+ Add site`. The field suggests as the container's address bar does, with no opener (`destinationFor`/`suggestionsFor` take an optional `current` and a `route`). A throwaway opened from it has no opener, counts under the viewed chip, and its first page's back closes and wipes it to the dashboard. The `+` opens `2a` on the viewed workspace with the keyboard up. A **default route** (`ProxyRoute`, `app_settings.default_route`, per vault, Direct until set, not copied by decoy re-sync; one that cannot be read is refused, never direct) is set in Settings ▸ BROWSING and is where a new site's Network tab starts. `2a` and the Default route screen share `RouteFields`. A blank NAME saves as the host. A fling on the container's bottom bar moves to the next or previous open container, **in opening order (plan D1, not `2c`'s order)**. The Plan 7 search screen is deleted (`sitesMatching` stays). Decisions D1–D7 are in the plan's header. Verified <date>: `flutter analyze` clean, `flutter test` <n>/<n>, `flutter build apk --debug` with zero `e:` lines. See the plan's "Device checks". |
```

In Plan 7's row, append: `**Superseded 2026-10-03 by Plan 18:** the search screen is gone; the dashboard's search field took its place.`

Under "Global constraints", the no-leak-count bullet says "The dashboard bar reads `N SESSIONS`". Change it to: "The dashboard shows no count at all since Plan 18 (`N SESSIONS` was removed by the user's ruling of 2026-10-03)." Keep the rest of the bullet.

- [ ] **Step 3: Device checks, on the physical phone**

The phone is a Redmi 2209116AG (`adb -s 967764a80013`, Android 13, WebView 153). It is a physical phone, not the emulator. `FLAG_SECURE` blanks screenshots, so read the UI with `uiautomator dump` (labels are in `content-desc`). Ask the user before tapping: they use this phone. Install the debug APK with data kept (`adb install -r`).

1. **Tabs.** Each tab shows its screen with no back icon. Back on Today and on Settings shows Sites. Back on Sites backgrounds the app. Settings ▸ Workspaces covers the tab bar.
2. **Chips.** A tap switches the list. A long-press opens the workspace's form. `+` opens New workspace.
3. **List.** An open site has its green rail and sits first. There are no titles and no count.
4. **Search, direct.** With Default route Direct, type an unsaved address. Its rows read `THROWAWAY`, and Enter loads the page. Back closes it to the dashboard with another site still open, and `2c` no longer lists it.
5. **Search, proxied.** Set Default route to SOCKS5 on the user's proxy. Ask the user for host and port first: on 2026-10-03 the phone had no proxy app and nothing on 9050. The rows read `THROWAWAY · SOCKS5`, and the page loads through it. Also try a proxy that is down: `8b` shows, with nothing direct.
6. **Add site.** `+` opens the form with the keyboard up, on the viewed chip's workspace, with the Network tab on the default route. An empty name saves as the host.
7. **Swipe.** With three containers open, a fling left and right on the bottom bar moves between them in opening order. Nothing happens at either end, and the buttons still tap.

Record what was seen in a "Device checks" section of this plan, check by check, including anything not seen and why.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/superpowers/plans/2026-10-03-dashboard-redesign.md
git commit -m "docs: Plan 18, the dashboard redesign, verified"
```

---

## Verification

Run 2026-10-03 on branch `dashboard-redesign`, after the fix below:

- `flutter analyze`: `No issues found!`
- `flutter test`: `+923: All tests passed!`
- `flutter build apk --debug`: built `app-debug.apk`, zero `e:` lines. No Kotlin changed.

The first full run had 5 failures, all in `test/ui/features/shell/app_gate_test.dart` ("A Timer is still pending even after the widget tree was disposed"): the Sites tab now reads `workspacesProvider`, `allSitesProvider`, `searchEngineProvider` and `defaultRouteProvider`, which over the test's real in-memory database left a timer pending. The test now overrides them with immediate values (`23297d7`).

## Device checks

Not yet run (2026-10-03): they need the user's physical phone, and the user is asked before it is used. Nothing below has been seen on a device. The checks:

1. **Tabs.** Each tab shows its screen with no back icon. Back on Today and on Settings shows Sites. Back on Sites backgrounds the app. Settings ▸ Workspaces covers the tab bar.
2. **Chips.** A tap switches the list. A long-press opens the workspace's form. `+` opens New workspace.
3. **List.** An open site has its green rail and sits first. There are no titles and no count.
4. **Search, direct.** With Default route Direct, type an unsaved address. Its rows read `THROWAWAY`, and Enter loads the page. Back closes it to the dashboard with another site still open, and `2c` no longer lists it.
5. **Search, proxied.** Set Default route to SOCKS5 on the user's proxy (ask for host and port first). The rows read `THROWAWAY · SOCKS5`, and the page loads through it. Also try a proxy that is down: `8b` shows, with nothing direct.
6. **Add site.** `+` opens the form with the keyboard up, on the viewed chip's workspace, with the Network tab on the default route. An empty name saves as the host.
7. **Swipe.** With three containers open, a fling left and right on the bottom bar moves between them in opening order. Nothing happens at either end, and the buttons still tap.

## Known gaps

- **Long-press on a chip is not discoverable** (spec §11). Settings ▸ Workspaces stays the visible way in.
- **A throwaway opened from the dashboard is never on the dashboard's list** (spec §11), because it is not a site. `N OPEN`, `2c` and the swipe reach it.
- **Changing the default route does not move open throwaways** (spec §11) or any open container.
- **The default route is saved on every change and on leaving its screen** (D5). A lock while the screen is open keeps what was typed, since a lock tears the screen down without a pop.
- **The swipe order is opening order** (D1). If the user wants `2c`'s order instead, that needs a rule for how the order stays put between swipes, which the spec does not give.
- **A workspace made with the `+` chip is not viewed afterwards.** The list stays on the chip that was viewed. The spec does not say otherwise.
- **`activeWorkspaceIdProvider` survives a lock** (unchanged from before this plan). The viewed tab resets to Sites on every unlock, but the viewed chip does not, unless the workspace is gone.

## Handoff

- `ProxyRoute` (`lib/domain/models/proxy_route.dart`) is the one place ruling 8 lives: `buildSite` and the Default route screen both go through `ProxyRoute.fromForm`. Use it for any new route form.
- `destinationFor`/`suggestionsFor` work with no opener. Give them a `route`. They throw if they get neither an opener nor a route.
- `test/support/dashboard_harness.dart`'s `pumpDashboard` builds the real dashboard, every tab, over fakes. Extend it rather than write another.
- `AppGlyph` now has 26 glyphs. `icons_test.dart` lists them in order, so add any new glyph there.
- Nothing here changed Kotlin.

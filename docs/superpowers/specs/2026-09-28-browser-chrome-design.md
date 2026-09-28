# Browser chrome and navigation — design

**Date:** 2026-09-28
**Status:** Design approved section by section in conversation with the user
(2026-09-28); this written spec awaits the user's review.
**Supersedes:** canvas screen `2b` (layout, toolbar, and the copy listed in
§7). Every other canvas screen is unchanged and still authoritative. This
follows the precedent of `2026-09-04-search-screen-design.md`, which stands in
for a screen the canvas never designed.

## 0. Context

The user asked for the app's UI and UX to be improved "like Firefox and Mullvad
Browser", and chose all four of: real browsing, finishing the half-built chrome,
Mullvad-style privacy controls, and a new look and feel. That was split into
four projects, each with its own spec, plan and implementation, in this order:

1. **Browser chrome and navigation** — this spec.
2. Tabs — several pages per container and a real `2c` switcher.
3. Privacy controls — security level (Standard/Safer/Safest), New identity,
   a per-site shield panel.
4. Restyle the remaining screens in the direction chosen here.

Mullvad Browser has no Android version. "Like Mullvad" means borrowing its
ideas, not copying an Android app.

### Decisions the user made

| Question | Decision |
|---|---|
| Where does a typed address or search open? | This container for this container's own site; the saved site's own container for a saved site; otherwise a new **throwaway** container. |
| Which route does a throwaway use? | **Inherits the route of the container it was typed in.** |
| Search | A small fixed list in Settings: DuckDuckGo (default), Startpage, Brave Search, Mullvad Leta. No custom engines, no suggestions. |
| Chrome layout | **C** — address pill + panic on top, back / forward / `N OPEN` / ☰ at the bottom. |
| Visual direction | **Keep the Container look** (graphite, jade, hairlines, Figtree + IBM Plex Mono). Unicode glyphs become line icons. |
| Typing state and ☰ menu | As mocked up: vault-local suggestions with destination tags; menu with four quick actions and five rows. |
| Address entry from the dashboard | **Not in this project.** |
| How a throwaway exists | **In memory only**, written to the vault only if the user saves it (approach A). |
| Icons | **Drawn in-repo** with `CustomPainter`, no new dependency. |
| New copy | Approved as listed in §7. |

The mockups used during brainstorming live under `.superpowers/brainstorm/`
(gitignored, local only): `chrome-layout.html`, `visual-style.html`,
`typing-and-menu.html`.

## 1. Prerequisite: the lock screen must cover pushed routes

**Confirmed and fixed on branch `fix-lock-covers-routes` (commit `6a5f013`),
which must be merged before this plan executes.** `AppGate` was
`MaterialApp.home`, and every container, Settings, Search and Today screen was
pushed onto the root navigator above it. Leaving `SessionOpen` only swapped the
bottom route, so a pushed container stayed on top of `LockScreen` and
`PanicScreen`, live and with no PIN asked. Queued snackbars carried over onto
the lock screen the same way (`Decoy vault synced`). The fix, option A as the
user chose it on 2026-09-28: the open vault gets its own `Navigator` and
`ScaffoldMessenger` inside `AppGate` (`_OpenVault`, keyed by the database
connection), so leaving `SessionOpen` for any reason tears everything down.
`test/ui/features/shell/app_gate_test.dart` covers `9b`, `9c`, panic,
snackbars and Android back.

**What this spec builds on:** every `ContainerRoute` push in §5.2 lands on that
nested navigator, and **every lock — `9b` included — closes every open
container**. Unlocking lands on the dashboard.

## 2. Scope

**In:**

- `2b` rebuilt as layout C in the Container look (§6).
- Line icons for the container screen only (§6.6).
- The editable address field with vault-local suggestions and destination
  tags (§4, §6.2).
- Throwaway containers, including the save bar (§5).
- In-page back / forward, system back, stop, load progress (§3, §6).
- The ☰ menu sheet (§6.4); the shield opens `6c`.
- Find in page (§6.5).
- A search-engine setting in `2d` (§6.7).

**Out:**

- Typing an address from the dashboard.
- More than one page per container; a real `2c` switcher. The switcher stays
  the one-entry stub it is today (`openCount: 1`); a throwaway lists itself as
  that one entry.
- Security level, New identity (project 3).
- Restyling any other screen (project 4).
- Search or address suggestions fetched over the network — never, in any
  project.
- Any change to link following. A link to another site still loads in the
  same container, on the same route, as it does today.

## 3. Engine plumbing

### 3.1 Kotlin (`android/app/src/main/kotlin/com/mono/container/engine/`)

`ContainerView` gains a navigation reporter. It is fed from the two clients
`ContainerView` already installs:

- the `WebViewClient` built by `RequestInterceptor.clientFor` —
  `doUpdateVisitedHistory`, `onPageStarted`, `onPageFinished`;
- the `WebChromeClient` built by `Shields.chromeClientFor` —
  `onProgressChanged`, `onReceivedTitle`.

Each report is one `navigation` event on the engine's event channel:

```
{ type: "navigation", siteId, url, title, canGoBack, canGoForward, loading, progress }
```

`progress` is 0–100. `EngineChannel` keeps the latest event per session so Dart
can read a snapshot.

Find uses `WebView.findAllAsync` with `setFindListener`, reporting:

```
{ type: "find_result", siteId, activeMatch, matchCount }
```

New channel methods, each taking `siteId`:

| Method | Behaviour |
|---|---|
| `goBack` | `webView.goBack()` if it can go back |
| `goForward` | `webView.goForward()` if it can go forward |
| `stop` | `webView.stopLoading()` |
| `loadUrl(url)` | Loads `url` in this container. **Refuses any scheme other than `http`/`https`** — `javascript:`, `file:`, `intent:`, `content:`, `data:` and everything else — even though the Dart parser never produces them. |
| `find(query)` | `findAllAsync(query)` |
| `findNext(forward)` | `findNext(forward)` |
| `clearFind` | `clearMatches()` |
| `navigationState` | Returns the last `navigation` event for the site, or null |
| `keep` | Turns off wipe-on-exit for a live throwaway and removes it from the journal (§5.4) |

Every method is a silent no-op on a closed or unknown session, matching
`reload` today.

`open` gains a `throwaway: Boolean` argument (§5.4).

### 3.2 Dart

`ContainerEngine` (`lib/data/services/container_engine.dart`) gains:

- `Stream<NavigationState> navigation()` and
  `Future<NavigationState?> navigationState(String siteId)`;
- `Stream<FindResult> findResults()`;
- `goBack`, `goForward`, `stop`, `loadUrl`, `find`, `findNext`, `clearFind`,
  `keep`;
- `open(Site site, {bool throwaway = false})`.

`NavigationState` and `FindResult` are plain domain models in
`lib/domain/models/`. `ChannelContainerEngine` maps the events;
`FakeContainerEngine` implements all of it so widget tests can drive
navigation.

`navigationForSiteProvider` (a `StreamProvider.family` keyed by site id) has
the same race as `sessionForSiteProvider`: the stream is broadcast with no
replay, and the first load can report before anyone listens. The
subscribe-first-then-snapshot logic fixed in `7996a17` is extracted from
`sessionForSiteProvider` into one shared helper, and both providers use it,
rather than duplicating a subtle race fix.

### 3.3 Chrome behaviour built on it

- The pill shows the host of `navigation.url`, falling back to the saved
  site's `host` until the first event arrives. After following a link to
  another site, the pill shows that site's host.
- Back and forward are dimmed and inert when `canGoBack` / `canGoForward` is
  false.
- System back (`PopScope`): `goBack` when `canGoBack`, otherwise pop the route.
- The × stop button appears in the pill only while `loading`.
- Copy link writes `navigation.url` with Flutter's `Clipboard`. The site's
  `allowClipboard` flag governs page script access, not this user action.

## 4. Address input and destinations

Pure Dart in `lib/domain/`, no Flutter imports.

### 4.1 `parseAddressInput(String raw) → AddressInput`

`sealed class AddressInput` with `AddressUrl(Uri url)`,
`AddressSearch(String query)` and `AddressEmpty`. The input is trimmed first.

| Input | Result |
|---|---|
| Empty after trimming | `AddressEmpty` |
| Contains whitespace | `AddressSearch` |
| Explicit `http://` or `https://` with a non-empty host | `AddressUrl`, exactly as typed. No automatic upgrade or downgrade. |
| Any other explicit scheme (`javascript:`, `file:`, `about:`, `intent:`, …) | `AddressSearch` — never a URL |
| Bare `host.tld` (the last label is at least two letters), `localhost`, or an IPv4 literal, each with an optional `:port` and `/path?query#fragment` | `AddressUrl` with `https://` prepended |
| Anything else | `AddressSearch` |

A bare host is always tried over `https`. If that load fails, the failure is
shown. There is no silent fallback to `http`.

### 4.2 `SearchEngine`

```dart
enum SearchEngine { duckDuckGo, startpage, braveSearch, mullvadLeta }
```

| Engine | Name (copy) | Template, followed by `Uri.encodeQueryComponent(query)` |
|---|---|---|
| `duckDuckGo` (default) | `DuckDuckGo` | `https://duckduckgo.com/?q=` |
| `startpage` | `Startpage` | `https://www.startpage.com/sp/search?query=` |
| `braveSearch` | `Brave Search` | `https://search.brave.com/search?q=` |
| `mullvadLeta` | `Mullvad Leta` | `https://leta.mullvad.net/search?q=` |

**To verify during planning:** the Startpage and Leta templates, and whether
Leta is still in service. Any engine that no longer works is dropped from the
enum rather than shipped broken.

### 4.3 `resolveDestination → Destination`

```dart
Destination resolveDestination({
  required AddressInput input,        // not AddressEmpty
  required Site current,              // the site this container was opened for
  required List<Site> saved,          // every site in the open vault
  required SearchEngine engine,
});

sealed class Destination
  ThisContainer(Uri url)
  SavedSiteContainer(Site site, Uri url)
  Throwaway(Uri url, ProxyMode mode, String? proxyHost, int? proxyPort)
```

- A search becomes its results URL first, then goes through the same rules. If
  the engine's host is itself a saved site, the search opens that container,
  so a row's tag is always the truth.
- **Host comparison:** lowercase, with one leading `www.` removed. Subdomains
  do not match (`mail.example.com` ≠ `example.com`).
- The URL's host equals `current`'s host → `ThisContainer`. "Current" is the
  site the container was opened for, not the page it is showing now.
- Otherwise, one or more saved sites have the host → `SavedSiteContainer`.
  Ties go to a site in `current.workspaceId` first, then to the most recent
  `lastVisitedAt`.
- Otherwise → `Throwaway` with `current`'s `proxyMode`, `proxyHost` and
  `proxyPort`.

### 4.4 `suggestionsFor → List<AddressSuggestion>`

In order:

1. Up to five saved-site matches, using Plan 7's `searchResults` name/host
   matching over the open vault. Tapping one opens that site at its **own
   saved URL**, not the typed text. Tag: `ITS OWN CONTAINER`, or
   `THIS CONTAINER` when it is `current`.
2. The address row, only when the input parses as `AddressUrl`. Tag from
   `resolveDestination`.
3. The search row, whenever the input is not empty. Tag from
   `resolveDestination`.

The route part of a tag follows the existing rule "there is no DIRECT label":
a throwaway on a direct route is tagged `THROWAWAY` alone. Otherwise the tag is
`THROWAWAY · ` + `proxyMode.name.toUpperCase()`.

## 5. Throwaway containers

### 5.1 What one is

A throwaway is an ordinary `Site` value, never written to the vault until saved:

- `id` and `profileId`: fresh values from `newProfileId()`.
- `workspaceId`: `current.workspaceId`. It is only used as the save form's
  default.
- `name`: the destination host. `monogram`: `suggestMonogram(host)`.
- `url`: the destination URL.
- `cookiePolicy`: `CookiePolicy.wipeOnExit`.
- `proxyMode` / `proxyHost` / `proxyPort`: copied from `current` — the only
  inherited setting.
- **Everything else is `Site()`'s default**: trackers, WebRTC and
  fingerprinting blocked; no camera, microphone, location or clipboard access;
  no custom CSS or JS; the Android user agent; force-dark on. A throwaway
  never inherits another site's permission grants or scripts.

`throwawaySitesProvider` holds the list in memory. It is cleared on every
transition out of `SessionOpen`, so a throwaway from one vault can never be
seen from the other.

### 5.2 Opening and the route stack

`ThisContainer` calls `engine.loadUrl` in place.

`SavedSiteContainer` and `Throwaway` **push** a new `ContainerRoute` on top of
the current one:

- `ContainerRoute` gains an optional `initialUrl`. A saved site opened from
  the address bar loads the typed URL for this session only; its stored `url`
  is never changed.
- System back on a pushed container's first page pops it and returns you to
  the container underneath, still live and not reloaded.
- A popped throwaway is wiped through the existing `wipeOnExit` path in
  `ContainerView.dispose`, and removed from `throwawaySitesProvider`.
- ☰ → `All sites` pops to the first route (the dashboard).

Every container in the stack keeps its WebView alive. No cap in this project
(see Known gaps).

### 5.3 The save bar

- Appears in a throwaway after its first completed load (`navigation.loading`
  becomes false). It sits directly above the bottom bar.
- Neutral styling. Jade stays on the live dot.
- Copy: `Not saved · wiped when you close it`, the button `Save as a site`,
  and a × that dismisses the bar for that throwaway.
- `Save as a site` opens `AddSiteScreen(initial: …)` (`2a`), prefilled with
  the throwaway `Site`, its `url` set to the current `navigation.url`, and
  `cookiePolicy` set to `CookiePolicy.keep`. `AddSiteScreen` already keeps
  `initial`'s `id` and `profileId`.
- On save: `siteRepository.upsert(site)`, then `engine.keep(site.id)`, then
  remove it from `throwawaySitesProvider`. The live page, cookies and login
  carry over. Without `keep`, closing the page would wipe the login just
  saved.
- If the user picked "wipe on exit" in the form, `keep` is skipped.
- Other settings changed in the form take effect the next time the site opens.
  That is how editing through `6c` already behaves.

### 5.4 Crash cleanup (Kotlin)

A throwaway's WebView profile is on disk. If the app dies before
`ContainerView.dispose`, nothing would ever wipe it, and one leaks on every
crash. So:

- `open` with `throwaway = true` appends the profile id to
  `filesDir/throwaway-profiles` **before** the profile is created.
- The id is removed after `ContainerView.dispose` wipes the profile, and by
  `keep`.
- When the engine starts, every id still listed is wiped with
  `profiles.wipe` and `deleteDownloadsDir`, and then the file is cleared.
- `wipeAll` (panic) clears the file too.
- The file holds random ids only — no hosts, names or URLs. It sits on disk
  in plaintext, which is within the threat model (a forced unlock, not disk
  imaging).

### 5.5 Lock, panic, decoy

- **Every lock wipes every throwaway**, `9b` included. Since the §1 fix, any
  transition out of `SessionOpen` disposes the open vault's navigator, and with
  it every `ContainerRoute`, so each throwaway's WebView goes through
  `ContainerView.dispose` → `wipeOnExit`. The registry is cleared on the same
  transition (§5.1). That matches `9c`'s "Ephemeral sessions were closed and
  wiped", and is stricter than `9b`'s "sessions kept" — the §1 fix's accepted
  cost, not something this spec adds.
- Nothing further is needed on `ReturnDestination.pin` / `graceExpired`.
- Panic needs no change: `wipeAll` already destroys every profile.
- The address bar, throwaways and the save bar look and behave identically
  in both vaults.

## 6. The screen

Where an element survives from `2b`, its existing dimensions and tokens are
kept. New elements use existing tokens only (`lib/ui/core/tokens.dart`); no new
colours.

### 6.1 Layout C

```
┌──────────────────────────────────────┐
│ ( ● forum.example.com   SOCKS5 🛡 ) ◉ │  top bar, hairline below (C.line07)
│ ▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔                  │  2px load line, only while loading
│                                      │
│               page                   │
│                                      │
│ [Not saved · wiped when you… Save ×] │  throwaway only (§5.3)
│   ‹        ›     [3 OPEN ▲]     ☰    │  bottom bar, C.footer, hairline above
└──────────────────────────────────────┘
```

- **Top bar:** keeps `ContainerTopBar`'s 12/8 padding, the 34px pill (radius
  17, `C.surface`, `C.line08` border), the 6px dot (`C.jade` live /
  `C.warning` opening) and the 32px panic square. The pill gains the shield
  icon on its right, and the × stop icon just before the shield while
  loading. `2b`'s back `‹` and reload `⟳` squares leave the top bar. Tapping
  the pill enters editing (§6.2). Tapping the shield opens `6c`: the existing
  `_showSiteSheet`, moved there from today's `☰`.
- **Load line:** 2px, full width, under the top bar's hairline, drawn only
  while `loading`, filled to `progress`. Colour `C.textMuted`, **not jade**,
  because the global rule keeps jade for live state and the single
  affirmative action. (The brainstorming mockup drew it jade; this spec
  corrects that.)
- **Bottom bar:** a flat bar in `C.footer` with a `C.line07` hairline above.
  It replaces `2b`'s floating pill with the `-70px` overlap and its `◑ ≡ ⋯`
  buttons. Back and forward icons are 40px round targets. The centre `N OPEN
  ▲` pill keeps its existing style and still opens the `2c` switcher. ☰
  opens the menu (§6.4).

### 6.2 Editing the address

- The pill becomes a `TextField`: `C.raised` fill, a `C.line16` border, and
  the hint `Search or type an address`. The current URL is pre-selected when
  editing begins. A × clears the field. The cursor is `C.textPrimary`, not
  jade.
- Panic stays beside the field. The bottom bar and page are covered by the
  suggestion list, and the keyboard sits below.
- The suggestion list (`AddressSuggestions`) has `C.bg` behind it. Section
  labels `SAVED SITES`, `ADDRESS` and `SEARCH` use `T.sectionLabel`. Rows are
  separated by hairlines: a monogram (a saved site) or an icon (globe for an
  address, magnifier for a search), a primary line, a mono secondary line,
  and the right-aligned mono destination tag. The footer line
  `Nothing is fetched while you type.` is in mono, `C.textDim`.
- Submitting the keyboard picks the address row if there is one, otherwise
  the search row.
- Back or tapping outside the list leaves editing without navigating.

### 6.3 Save bar

`ThrowawaySaveBar` is a single row: `C.raised`, with hairlines above and
below. The text is `Not saved · wiped when you close it` in `C.textMuted`. The
button `Save as a site` uses `PillButton` in its neutral tone, followed by a ×.

### 6.4 ☰ menu

`BrowserMenuSheet` uses the existing `Sheet` style (`2c`/`6c`):

- **Header:** the site's monogram, name, and `host · Workspace` in mono. A
  throwaway shows its host as the name, and no workspace.
- **Quick actions,** a row of four icon tiles:
  - `Reload` — `engine.reload`
  - `Find` — opens the find bar
  - `Reader` — the existing `_openReader`
  - `Copy link` — the clipboard, then the snackbar `Link copied`
- **Rows,** separated by hairlines:
  - `Today`, with the mono meta `<n> BLOCKED` from
    `blockedTallyProvider.total` → `TodayRoute`
  - `Scripts and filters` → the scripts route
  - `Workspaces` → the workspaces route
  - `Settings` → settings
  - `All sites` → pop to the dashboard

  These screens are also reachable from elsewhere since Plan 6 Tasks 6–7, so
  here they are shortcuts.
- Project 3 will add security level and New identity to this sheet.

### 6.5 Find bar

`FindBar` temporarily replaces the top bar:

- A field with the hint `Find in page`.
- A mono count `<active>/<total>`, or `No matches` when the query is not
  empty and has none.
- Previous and next icons, and a close ×.

Typing calls `engine.find`, the arrows call `findNext`, and close calls
`clearFind` and restores the top bar. Panic stays reachable: the find bar
keeps the 32px panic square on its right.

### 6.6 Icons

`lib/ui/core/icons.dart` holds `AppIcon`, a `CustomPainter` with 2px round
strokes on a 24-unit grid, drawn at the size the caller passes. The set:

- `back`, `forward`, `reload`, `stop`
- `shield`, `panic`
- `menu`, `find`, `reader`, `link`
- `search`, `globe`
- `chevronUp`, `chevronDown`, `close`

Only the container screen and the new widgets use them in this project. The
dashboard's `Icons.search` and other screens' glyphs are left for project 4.

### 6.7 Settings: search engine

- `SettingsScreen` (`2d`) gains a section `BROWSING`, placed after `MANAGE`,
  with one row `Search engine` whose value is the current engine's name.
- Tapping it opens `SearchEnginePicker`, a sheet titled `Search engine` that
  lists the four names; the current one is marked with a check.
- Storage is the open vault's `app_settings` table under the key
  `search_engine`, holding the enum name, with the fallback `duckDuckGo`.
- `SettingsRepository` is bool-only today. It gains
  `getString(String key, {String? fallback})` and
  `setString(String key, String value)`. `app_settings.value` is already
  text.
- The setting is per vault, like every other setting, and the row looks the
  same in both vaults.

## 7. New copy (approved 2026-09-28)

Every string below is new. The user approved all of it word for word. Anything
not in this list or the canvas is still a design question.

| Where | String |
|---|---|
| Address field hint | `Search or type an address` |
| Suggestion section labels | `SAVED SITES` · `ADDRESS` · `SEARCH` |
| Search row | `Search <engine name> for “<query>”` (curly quotes) |
| Address row, second line | `not saved` |
| Destination tags | `THIS CONTAINER` · `ITS OWN CONTAINER` · `THROWAWAY` · `THROWAWAY · <ROUTE>` |
| Suggestions footer | `Nothing is fetched while you type.` |
| Save bar | `Not saved · wiped when you close it` · button `Save as a site` |
| Menu quick actions | `Reload` · `Find` · `Reader` · `Copy link` |
| Menu rows | `Today` · `Scripts and filters` · `Workspaces` · `Settings` (canvas titles, reused) · `All sites` (new) |
| Today row meta | `<n> BLOCKED` |
| Copy-link snackbar | `Link copied` |
| Find bar | hint `Find in page` · count `<active>/<total>` · `No matches` |
| Settings | section `BROWSING` · row `Search engine` · picker title `Search engine` |
| Engine names | `DuckDuckGo` · `Startpage` · `Brave Search` · `Mullvad Leta` |
| Screen-reader labels | `Back` · `Forward` · `Stop` · `Site details` · `Panic` · `Open sessions` · `Menu` · `Clear` · `Previous match` · `Next match` · `Close find` |

**Removed from `2b`:** the `◑`, `≡` and `⋯` toolbar buttons, and the top bar's
`‹` and `⟳` squares.

## 8. Testing and verification

- **Unit tests (pure Dart):**
  - `parseAddressInput`: every row of §4.1's table, including `javascript:`
    and `file:` becoming searches, bare hosts getting `https://`, ports,
    paths, IPv4 and `localhost`.
  - Search URL building, including query encoding.
  - `resolveDestination`: same host, `www.` normalisation, subdomain
    non-match, saved-site tie-breaking, a search whose engine host is saved,
    and route inheritance for direct, SOCKS5 and http.
  - `suggestionsFor`: ordering, the cap of five, and tags.
  - Building a throwaway: **no permission, script or cookie-policy
    inheritance**, route inherited.
- **Widget tests** with `FakeContainerEngine` driving `navigation` events:
  - the pill shows the current host;
  - back/forward dimmed and enabled;
  - system back going back in history, then popping;
  - stop shown only while loading;
  - editing and submitting for each destination kind;
  - a pushed throwaway, popped and wiped;
  - the save bar appearing, and saving calling `upsert` then `keep`;
  - every menu row's destination; the shield opening `6c`;
  - find bar counts and `No matches`;
  - the search-engine picker persisting;
  - the throwaway registry cleared on lock and on panic.
- **Kotlin JVM tests:**
  - `loadUrl` scheme refusal;
  - the throwaway journal (append, remove on wipe, remove on `keep`, the
    sweep on start, cleared by `wipeAll`).
- **Gate:** `flutter analyze` clean; `flutter test` all passing;
  `flutter build apk --debug` succeeding with zero `e:` lines (the only check
  that compiles `engine/`); Kotlin test counts read from the JUnit XML.
- **Device:** on the emulator, driven through `adb` and `uiautomator`. The
  screen is `FLAG_SECURE`, so read the UI tree, not screenshots. Check:
  - typing a search from a SOCKS5 site opens a throwaway tagged
    `THROWAWAY · SOCKS5`, and its traffic goes through the proxy;
  - back returns to the original container;
  - save-as-site keeps the login;
  - killing the app with a throwaway open, then relaunching, leaves no
    throwaway profile behind.

## 9. Known gaps (deliberate)

- **No cap on stacked containers.** Each pushed container keeps a WebView
  alive. Project 2 (tabs) replaces the stack.
- **The switcher stays a one-entry stub** until project 2.
- **No address entry from the dashboard.** A route to inherit only exists
  inside a container.
- **Links still leave the site inside the same container.** Only typed
  addresses get the throwaway rule.
- **`ProxyProbe` still probes the proxy, not the destination.** Unchanged, so
  a throwaway on a proxy that refuses a given destination fails on load, as
  saved sites already do.
- **Throwaway settings are fixed** at the safe defaults plus the inherited
  route. There is no per-throwaway toggle before saving.

## 10. Coordination

A peer session (flutter-app-67) is, as of 2026-09-28, changing
`EngineChannel.kt`, `ContainerView.kt`, `Shields.kt`, `FilterEngine.kt`,
`container_engine*.dart` and `fake_container_engine.dart`, so that filter-list
switches and user scripts affect page loads. The implementation plan for this
spec is written against `main` **after** that work merges, not against the
tree as of this spec.

## 11. Handoff to later projects

- **Project 2 (tabs):** takes over the pushed-route stack (§5.2), the
  `N OPEN` count and the `2c` switcher. Navigation state is already per site
  id.
- **Project 3 (privacy controls):** adds rows to `BrowserMenuSheet` (§6.4)
  and extends the `6c` sheet the shield opens.
- **Project 4 (restyle):** extends `AppIcon` (§6.6) to every screen and
  removes the remaining Unicode glyphs.

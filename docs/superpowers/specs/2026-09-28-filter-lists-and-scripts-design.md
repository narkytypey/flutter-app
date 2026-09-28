# Filter lists and user scripts reach the engine — design

**Status:** approved in conversation 2026-09-28, section by section.
**Closes:** Plan 5's Known gaps "`FilterList.enabled` is not read by Plan 3's
`FilterEngine`" and "`UserScript.code`/`runAtDocumentStart` are not injected
into any WebView", plus the fabricated rule counts `seedFilterListsIfEmpty`
would show.
**Owner boundary:** engine and data layers only. Another session owns the
container UI; the only UI file this touches is `container_route.dart`, and
only the one line that opens a site.

## Problem

Three things, found by reading the tree at `4676bed`:

1. **Switches are ignored.** Every `Session` builds its `FilterEngine` from two
   bundled Kotlin assets (`default_trackers.txt`, 20 domains;
   `default_ads.txt`, 2 domains) no matter which lists are enabled.
2. **The lists are not real.** The three rows spec `10d` draws — "Trackers and
   ads", "Cookie notices", "Social embeds" — exist only as
   `seedFilterListsIfEmpty`'s mock rows with the spec's mock counts
   (84,102 / 11,430 / 2,908). No rules exist for the latter two, and nothing
   calls the seeder, so a real vault has no filter lists. Obeying the switches
   as things stand would make a fresh vault block nothing.
3. **Library scripts never reach a page.** Kotlin already injects a site's own
   `customCss`/`customJs` (`Shields.apply`). Library scripts are simply never
   sent.

## Decisions

- **Real bundled lists (option A).** One rules file per spec-named list, built
  from well-known domains, shipped with the app. Rule counts and dates shown
  on `10d` are those of the shipped file — not the spec's mock numbers.
- **Dart decides, Kotlin applies (option 1).** At open, Dart reads the open
  vault's enabled lists and applicable scripts and sends their content to the
  engine. Kotlin keeps no filter state of its own and reads no rule assets.
- **Next open, not live.** A change takes effect the next time a site opens —
  the same rule the site sheet follows. No engine-wide state is added, so
  there is nothing that could carry one vault's settings into the other.
- **No network.** "Update now" still fetches nothing; lists change only with
  an app update.

## Filter lists

### Rule files

Three Flutter assets, declared in `pubspec.yaml`:

| File | List id | Spec name | Default | Category |
|---|---|---|---|---|
| `assets/filters/trackers_and_ads.txt` | `fl-trackers` | Trackers and ads | on | split, see below |
| `assets/filters/cookie_notices.txt` | `fl-cookies` | Cookie notices | on | trackers |
| `assets/filters/social_embeds.txt` | `fl-social` | Social embeds | off | ads |

Format is what `FilterEngine` already parses: one `||host^` rule per line,
`!` comments. One addition: a comment line `! category: <name>` switches the
category of the rules that follow, so `trackers_and_ads.txt` keeps today's
tracker/ad split for the Today log (`5c`). A file with no directive uses its
list's category.

Content:
- **Trackers and ads** — today's `default_trackers.txt` (trackers) and
  `default_ads.txt` (ads), merged.
- **Cookie notices** — consent-management platforms whose scripts render the
  banners: OneTrust/cookielaw, Cookiebot, Quantcast Choice, TrustArc,
  Usercentrics, Didomi, Iubenda, Osano, CookieYes, Termly, Consentmanager and
  similar. Blocking the loader removes the banner.
- **Social embeds** — widget/SDK domains: `connect.facebook.net`,
  `platform.twitter.com`, `platform.linkedin.com`, `assets.pinterest.com`,
  `widgets.tiktok.com`, `platform.instagram.com`, `embed.reddit.com` and
  similar. Whole social sites are *not* listed — this blocks embeds on other
  pages, not the networks themselves.

Kotlin's `android/app/src/main/assets/filters/` is deleted with `readAsset`.

### One definition in Dart

`bundledFilterLists` (new, data layer): for each list its id, spec name,
default `enabled`, category, asset path, and release date — the date the file
last changed, written by hand next to it. This replaces the Kotlin asset
pair, `seedFilterListsIfEmpty`, and the mock counts.

`BundledFilterRules` loads and parses each file once through an injectable
`AssetBundle` and caches the result: `rulesFor(listId) → Map<category,
List<rule>>` and `ruleCount(listId)`. `parseRules(text, defaultCategory)` is
the pure parser both use; it counts only lines that are `||host^` rules.

### Keeping each vault in step

`syncBundledFilterLists(database, bundled)` runs whenever a vault is opened —
from `openEncrypted`, the one production entry point for opening a vault
(session unlock, setup, decoy re-sync). For every bundled list it:

- inserts the row with its default `enabled` if the vault lacks it;
- updates `name`, `rule_count`, `updated_at`, `category` from the bundle;
- never changes an existing row's `enabled`.

Rows whose id is not bundled are left alone (none exist today). The decoy is
a separate store and gets its own rows the same way.
`seedFilterListsIfEmpty` is deleted.

### What reaches the engine

`filterRules: Map<String, List<String>>` — the union of every enabled list's
rules, by category. `Session` builds its `FilterEngine` from
`config.filterRules`. Everything disabled means an empty map and nothing is
blocked. The site's own "Block trackers" flag (`blockTrackers`) still gates
all list blocking, as today.

## Library scripts

### Selection

`selectUserScripts(site, scripts)` (pure): scripts that are `enabled` and
whose `appliedSiteIds` contains `site.id`, in library order
(`ScriptRepository.all()`'s `rowid` order). Sent as
`userScripts: [{kind: 'css'|'js', code, atDocumentStart}]`. A site's own
`customCss`/`customJs` are unchanged and independent.

### Timing — `runAtDocumentStart`

| Kind | `true` | `false` |
|---|---|---|
| CSS | `<style>` inserted at document start, before first paint (`10e`: "Prevents a flash of the hidden elements") | inserted at `DOMContentLoaded` |
| JS | code runs at document start, before the page's own scripts | code runs at `DOMContentLoaded` (`10d`: "runs at load") |

### Injection

- **One `addDocumentStartJavaScript` call per script**, built by the pure
  `UserScriptJs.wrap(kind, code, atDocumentStart)`. A syntax error or throw in
  one script cannot stop another, or Shields.
- **No `eval`.** JS code is placed in the injected source as written (wrapped
  in a function for the `DOMContentLoaded` case); CSS text is embedded with
  the existing `asJsString`. `eval`/`new Function` would be blocked by a
  page's Content-Security-Policy.
- **Scoped to the site's origin.** Shields keeps `setOf("*")`. Library scripts
  get `originRuleFor(site.url)` — `scheme://host[:port]` — so a script
  applied to Forum does not run on another domain navigated to inside that
  container. An unparseable URL yields no rule and the script is not injected.

## Wiring

- `ContainerEngine.open(Site site, {EngineExtras extras = EngineExtras.none})`,
  `EngineExtras(filterRules, userScripts)`. The channel adds `filterRules` and
  `userScripts` to the `open` map; `SiteConfig` gains both; `configFrom`
  reads them (absent → empty, which blocks nothing — the Dart side always
  sends them).
- `openContainer(ref, site)` (new, container view-models): reads the open
  vault's filter lists and scripts, builds `EngineExtras`, calls
  `engine.open`. `ContainerRoute._open` calls it instead of `engine.open`.
- `FakeContainerEngine` records the extras of each `open`.

## Failures

- Reading the vault's lists or scripts, or a bundled file, fails → `open`
  fails. The site is never opened quietly unfiltered.
- A missing or empty bundled file is a packaging defect: a test asserts every
  `bundledFilterLists` entry loads with at least one rule.
- A script's runtime error stays inside that script (separate injection).

## Testing

Dart (`flutter test`):
- `parseRules`: rules, comments, blank lines, `! category:` switching, count.
- every bundled file loads and has ≥ 1 rule.
- `syncBundledFilterLists`: inserts missing with defaults, refreshes count/
  date/name, preserves `enabled`, idempotent, leaves unknown ids.
- extras: only enabled lists' rules, merged by category; `selectUserScripts`
  filters by enabled and site, keeps order.
- `ContainerRoute` → `openContainer` → fake engine receives those extras.

Kotlin (JVM unit tests):
- `UserScriptJs.wrap` for all four kind × timing cases.
- `originRuleFor`: default and explicit ports, http/https, unparseable.
- `FilterEngine` blocks from a supplied map; empty map blocks nothing.

Build: `flutter build apk --debug`, zero `e:` lines.

Emulator: with Social embeds off then on, load a page embedding
`platform.twitter.com` and observe it allowed then blocked (Today count);
apply a CSS library script to a site and confirm its effect in the page.

## Out of scope

"Update now" and any list download; applying changes to already-open
sessions; the script editor's "+ Add site" picker (UI); new copy of any kind.

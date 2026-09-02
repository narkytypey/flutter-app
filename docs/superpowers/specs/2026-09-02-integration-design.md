# Integration — wiring the five plans into one navigable app

**Status:** Approved by user, 2026-09-02. Ready for `superpowers:writing-plans`.

## Problem

Plans 1–5 each shipped their own screens, fully tested in isolation, but
almost none of them are reachable from a running app. `AppGate` routes
between Setup / Lock / Dashboard / Panic, and the dashboard itself renders
correctly — but tapping a site, tapping "+ Add site", long-pressing a site
row, and opening workspaces/settings/scripts all do nothing (`onAddSite`,
`onSearch`, `onSiteMenu` are empty callbacks; `onOpenSite` only marks a
provider-set entry and never navigates). Plan 3's native container engine is
real and compiles, but nothing on the Dart side ever selects it or talks to
it outside its own tests. Plan 4's failure-state screens (permission ask,
held download, proxy-unreachable, tunnel-dropped, reader) have no event
source. This is the single largest remaining gap in the project, named but
not built by CLAUDE.md's own "Unassigned work" section.

This is not a sixth plan number in the existing five — it is a new
plan, `docs/superpowers/plans/2026-09-0X-isolated-web-container-06-integration.md`,
written and executed the same way the other five were (subagent-driven
development, task-by-task, spec-verbatim copy where the spec has copy).

## Explicitly out of scope

- **Search.** The dashboard's search button has no design-spec screen
  anywhere in the canvas HTML at all. Left as a documented no-op; this is a
  design question for later, not a gap this plan guesses at.
- **Biometric unlock.** Self-contained security feature (Keystore-wrapped
  data key, unlocked by `local_auth`) that doesn't block navigation or
  anything else in this plan. Settings toggle stays a documented no-op.
  Deferred to its own future plan.

## Architecture

### 1. Navigation shell

No router package. Plain `Navigator.push(MaterialPageRoute(...))` from each
call site — matches the project's "no code generation, hand-written
everything" convention (CLAUDE.md tech stack) and the app's single-activity,
no-deep-linking target. Exact entry-point placement (where a
workspaces-management affordance sits, where the settings gear lives) is
resolved against the canvas spec at plan-write time, the same way every
other plan resolved its own screen wiring — not speculated here.

Routes this plan adds, each a thin `MaterialPageRoute` wrapper around an
existing pure-UI screen plus a Riverpod-aware call site:
- Dashboard `onAddSite` → push `AddSiteScreen`.
- Dashboard `onSiteMenu(siteId)` → push (as a modal sheet, matching the
  existing `SwitcherSheet`/`WorkspaceMenu` pattern) `SiteRowMenu`, which can
  itself open `SiteSheet`.
- Dashboard `onOpenSite(siteId)` → push `ContainerRoute(siteId: siteId)`
  (see §2) instead of only mutating `openSiteIdsProvider`.
- A workspaces-management entry point → push `WorkspacesScreen`.
- A settings entry point → push `SettingsScreen`.
- A Today/report entry point → push `TodayScreen`.
- A scripts/filters entry point → push `ScriptsAndFiltersScreen`.

### 2. `ContainerRoute` — the site session widget

New file: `lib/ui/features/container/views/container_route.dart`, a
`ConsumerStatefulWidget`. One push per site-tap; internally swaps between
`OpeningBody` and `ContainerScreen` as the session's phase changes, rather
than issuing a second navigation event (rejected alternative: push
`OpeningScreen`, then `Navigator.pushReplacement` to `ContainerScreen` —
doubles navigation events for one logical session and muddies what "back"
means mid-connect).

- Watches a new `sessionForSite(siteId)` provider (family, in
  `lib/ui/features/container/view_models/providers.dart`) built from
  `containerEngineProvider.sessions()`, filtered to `siteId`.
- On first build, calls `containerEngineProvider.open(site)` if no session
  exists yet for this site.
- Renders `OpeningBody` while `phase == SessionPhase.opening`.
- Renders `ContainerScreen` (with `ContainerWebView(siteId: siteId)` as
  `body`) once `phase == SessionPhase.live`.
- On `phase == SessionPhase.refused`, pops back to the dashboard after
  first pushing `ProxyUnreachableScreen` — it already handles all 5
  `RouteFailure` kinds internally via `proxyFailureHeadline`/
  `proxyFailureDetail` (confirmed: not per-failure-type screens, one
  screen with copy that switches on `failure`). `TunnelDroppedScreen` is a
  *different* trigger — see §3, `tunnel_dropped` event — for a session that
  was already live and lost its tunnel mid-browse, not an initial-connect
  refusal.
- Owns the event-stream subscriptions from §3 for the lifetime of the
  route; cancels them in `dispose()`.

### 3. Native event bridge

`EngineChannel.kt`'s existing `EventChannel` carries only the session list
today. Its payload gains a discriminated `type` field
(`sessions | permission_request | download | tunnel_dropped`) instead of new
channels being opened per event kind — one channel, one wire format,
extended. `ContainerEngineChannel` (Dart) fans the discriminated stream
into four separate broadcast streams on the `ContainerEngine` interface:
`sessions()` (existing, unchanged shape), plus new `permissionRequests()`,
`downloads()`, and `tunnelDropped()`. `FakeContainerEngine` gets trivial
`StreamController`-backed equivalents so every consumer stays testable with
no platform channel.

`tunnel_dropped` is emitted by `Router.kt`/`RequestInterceptor.kt` when a
*live* session's proxy connection is lost mid-browse (distinct from
`RouteRefused`, which only ever happens on the initial `open()` call, before
a session goes live — see §2 above). It does not change `SessionPhase`; the
`ContainerView`/`WebView` stays mounted underneath ("the page freezes...
instead of a dialog stealing focus", spec `8c`'s own framing), and
`ContainerRoute` shows `TunnelDroppedScreen` as an overlay on top of the
still-live `ContainerScreen`, not a route pop/replace.

`ContainerRoute` subscribes to all three new streams filtered to its own
`siteId` and shows `PermissionRequestSheet` / `HeldDownloadSheet` /
`TunnelDroppedScreen` when an event arrives for the currently-open site.
Events for a site that isn't the foreground route are dropped for now (no
queuing/notification-center — out of scope; note this as a Known Gap in the
plan).

### 4. Filter category tagging

No per-rule category metadata exists (`android/app/src/main/assets/filters/default.txt`
is one flat `||host^` list). `BlockedCategory` has four values —
`trackers`, `ads`, `fingerprinting`, `permissionAsks` — of which only the
first two are `FilterEngine`'s job; the other two already belong to
`Shields.kt` (fingerprint countermeasures) and the permission-deny path
respectively.

- `FilterList` (Plan 5's domain model) gains a `category` field
  (`trackers` default, `ads` selectable) — reuses the existing filter-list
  management screen rather than inventing per-rule tagging, which no
  adblock-list format here carries.
- `FilterEngine.kt` is constructed per-category-tagged rule set (or one
  `FilterEngine` per category) and reports `(category, count)` pairs
  instead of one flat counter.
- `Shields.kt` gets a fingerprint-block counter; the permission-deny path
  gets a permission-ask counter.
- All three feed one in-memory `BlockedTally` aggregator, per Plan 1's
  "sessions and their counts are runtime-only" rule (`blocked_tally.dart`'s
  existing doc comment already promises this — no new persistence).

### 5. Download interception

`ContainerView.kt` registers a `DownloadListener` on its `WebView`. On a
hit, it emits a `type: download` event (§3) carrying filename, sizeBytes,
sourceHost (the container's own host — `DownloadListener` doesn't hand this
directly, use the site the session already knows), and a short `kindLabel`
derived from the file extension/MIME type (e.g. `application/pdf` → `"PDF"`)
on the Kotlin side before it crosses the channel — `HeldDownload`
(`lib/domain/models/held_download.dart`) takes `kindLabel` as a pre-computed
badge string, not a raw MIME type, so the mapping belongs in the event
producer, not the Dart consumer. No Android `DownloadManager` integration in this
plan — the download is *held* (per spec), not fetched; actually starting
a held download is a Known Gap this plan can leave, same as Plan 4 did.

### 6. `SiteSheet` persistence + decoy auto-sync

Both are direct repository calls, no new plumbing:
- `SiteSheet`'s force-dark/desktop-view toggles call
  `siteRepository.update(...)` on change instead of only setting local
  widget state.
- A shared `syncToDecoy(Site)` function (factored out of
  `decoy_provisioner.dart`'s existing copy-with-fresh-`profileId` logic, not
  duplicated) gets called from `SiteRepository.create`/`update` whenever
  `showInDecoy` is true and a decoy vault exists — covers both "created with
  showInDecoy on" and "existing site flipped to showInDecoy on" without two
  code paths.

### 7. Reader mode extraction

`ContainerView.kt` gets a request/response pair on the existing
`EngineChannel` (`extractArticle(siteId)` → JSON matching `ReaderArticle`'s
four fields: `host`, `title`, `paragraphs` — a `List<String>`, one entry per
extracted block-level element, not one text blob — and `minutesToRead`).
The Kotlin side runs an injected JS heuristic: strip
`<script>/<style>/<nav>/<aside>/<footer>`, find the element with the
highest text-to-tag-node ratio, split its child block elements
(`<p>`, headings, list items) into the `paragraphs` array, take
`document.title`, and estimate `minutesToRead` from total word count
(~200wpm). Not spec-exact copy-matching (there's no spec for what any given
page's extracted article looks like) — functionally real for typical
article-shaped pages, honestly approximate for anything else.
`ReaderArticle`'s own doc comment already anticipates this: "producing an
`ReaderArticle` from a live page... is not [Plan 4's] job" — confirming this
plan is the intended owner, not a scope overreach. `ReaderScreen`'s entry
point is `ContainerToolbar`'s existing `◑` reader icon → `ContainerRoute`
calls `extractArticle`, then pushes `ReaderScreen(article: ...)`.

## Data flow summary

```
Dashboard (site tap)
  → Navigator.push(ContainerRoute(siteId))
    → sessionForSite(siteId) provider
      → containerEngineProvider.open(site)  [ChannelContainerEngine, real engine]
        → EngineChannel.kt: ProfileManager creates/reuses profile,
          RequestInterceptor+Router+FilterEngine+Shields attach,
          ContainerView (WebView) attaches, DownloadListener registers
        → EventChannel: sessions | permission_request | download | tunnel_dropped, discriminated
    → phase opening → OpeningBody
    → phase live → ContainerScreen(body: ContainerWebView(siteId))
      → permission_request event → PermissionRequestSheet
      → download event → HeldDownloadSheet
      → tunnel_dropped event → TunnelDroppedScreen (overlay, session stays live)
      → reader icon → extractArticle() → ReaderScreen
      → panic (top bar / switcher) → panicServiceProvider.trigger()
        [already built, Plan 3 Task 9 — this plan gives it its first real
        call site via ContainerRoute/ContainerScreen]
    → phase refused → ProxyUnreachableScreen (all 5 RouteFailure kinds) → pop
```

## Error handling

- `containerEngineProvider.open` failing (native exception, e.g. isolation
  unsupported) surfaces as `phase == refused` with a `RouteFailure` the
  existing `RouteFailureCopy` already has copy for — no new error UI needed.
- Event-stream disconnection (platform channel dies) is treated as an
  implicit session end: `ContainerRoute` pops to dashboard rather than
  hanging on a dead stream. Add a test for this — it's the one failure mode
  none of Plan 3's existing tests exercise (they're all against
  `FakeContainerEngine`, which never disconnects).
- `extractArticle` timing out or returning empty content: `ReaderScreen`
  shows nothing rather than a broken layout — exact fallback copy is a
  plan-write-time detail against the spec (`6a`'s permission and `6b`-style
  patterns as precedent for "graceful nothing").

## Testing

Every new pure-Dart piece (`sessionForSite` provider logic, `ContainerRoute`'s
phase-switching, category-tagged `BlockedTally` aggregation, `syncToDecoy`)
gets widget/unit tests against `FakeContainerEngine` and fake repositories,
matching every other plan's convention — no plan in this project has ever
required a device for its Dart-level tests. The Kotlin additions
(`DownloadListener`, `extractArticle`, per-category `FilterEngine`,
`Shields.kt` counters) get Kotlin unit tests where the existing engine
package already has them (`ProxyProbe`, `SiteConfig` have precedent), plus a
manual `flutter build apk --debug` compile check per Plan 3's own established
practice — full device instrumentation testing stays out of scope, matching
every other plan in this project.

## Known gaps this plan will declare

- Events for a backgrounded (non-foreground) session are dropped, not
  queued — no notification-center concept exists yet.
- Held downloads are held, not actioned — no `DownloadManager` integration.
- `extractArticle`'s heuristic is honestly approximate outside typical
  article pages — no spec exists to be exact against.
- Search screen and biometric unlock remain unbuilt (explicitly out of
  scope above).

# Privacy controls — design

**Date:** 2026-10-02
**Status:** Designed with the user on 2026-10-02, question by question. §1–§4
were approved section by section and §5's copy word for word. Decisions the
planning session made without asking are listed under "Rulings" so the user
can overturn them. This written spec is waiting for the user's review.
**Project:** 3 of the four in `2026-09-28-browser-chrome-design.md` §0. It adds
rows to `BrowserMenuSheet` (that spec §6.4) and extends the `6c` sheet the
address pill's shield opens (§11).
**Depends on:** Project 2, Tabs (Plan 15). Its spec and plan were being
written in a parallel session when this was designed, and neither existed in
the tree. This spec is written against `main` at `e4e2a62`. The
implementation plan (Plan 16) is written **after Plan 15 is on `main`**, against
that tree (user's ruling). See §8.

## 0. Context

"Like Mullvad Browser" means borrowing its ideas. Mullvad Browser has no
Android version, and it is built on Firefox, whose switches Android WebView
does not have. The three level names and their intent come from Mullvad (and
Tor Browser, which Mullvad inherits them from); what each level switches off
is what WebView can actually switch off.

### What WebView can and cannot do (checked while designing)

- **Settings** (`WebSettings`, per view, reliable): `javaScriptEnabled`,
  `blockNetworkImage`, `mediaPlaybackRequiresUserGesture` (already `true` for
  every site).
- **Injected** (`WebViewCompat.addDocumentStartJavaScript`, which the tree
  already uses for every shield): a script that runs in each document and
  frame before the page's own scripts. It does not reach workers. It does not
  run when JavaScript is off.
- **Not available:** a JIT switch. V8's JIT-less mode is a process-wide
  command-line flag that release WebView does not expose. Also unavailable:
  a request's destination type (`Sec-Fetch-Dest`), so the interceptor can only
  tell a font or a video from its URL.

### Decisions the user made (2026-10-02)

| Question | Decision |
|---|---|
| Relation to Tabs | Design now; write Plan 16 once Plan 15 is on `main`. |
| Where the level lives | **A vault default, and a per-site override.** |
| When a change applies to an open site | **At once: the page reloads.** |
| How it applies | **A: reopen in place** at the current page (not a live re-apply). |
| New identity acts on | **This site only.** |
| Safer switches off | JavaScript on `http://` pages, WebAssembly, WebGL. |
| Safest switches off | JavaScript everywhere, and images. (Fonts and media were dropped: with JavaScript off they could only be blocked by URL extension.) |
| Default level | **Standard.** |
| A throwaway's level | **The vault default.** |
| The ☰ row and Settings | ☰ sets **this site's** level; Settings sets the **vault default**. `6c` shows the site's level and opens the ☰ picker. |
| Picker for a site | **A fourth row** that follows the vault default. |
| Vault default changed while sites are open | Applies **at their next open**. |
| New identity reopens at | **The site's saved address.** |
| New identity confirmation | **A confirm sheet.** |
| New identity appears in | **The ☰ menu only.** |
| New identity on a throwaway | **The same as on a saved site.** |
| Decoy re-sync and the `2a` form | Re-sync **copies** the override. **No** level control in `2a`. |
| `6c` gains | Security level row, shield switches, blocked-by-category rows, permissions in use. |
| `6c`'s older switches (Force dark mode, Desktop view) | **Apply at once too**, like the new ones. |
| Category rows | **Only categories with a count above 0.** |
| Revoking a permission | **Session grants only.** Stored grants are shown and changed through Edit. |
| The pill's shield icon | **Unchanged.** |
| Copy | §5, approved word for word. |

## 1. Security levels (approved)

```dart
enum SecurityLevel { standard, safer, safest }
```

| | Standard | Safer | Safest |
|---|---|---|---|
| JavaScript | on | off in every `http:` document, frames included | off everywhere (setting) |
| WebAssembly | on | removed (injected) | — (no JavaScript) |
| WebGL | on | refused (injected) | — |
| Images | on | on | off (setting `blockNetworkImage`) |
| Media | needs a tap before it plays, as today | same | same |
| The site's own shields | as today | as today | only those that need no JavaScript |

### 1.1 Standard

Exactly today's behaviour. Every existing site is Standard after the upgrade,
because every site follows the vault default and the default is Standard.

### 1.2 Safer

Two document-start scripts, added with origin rule `*` so they run in every
document and frame:

- **WebAssembly and WebGL.** Deletes `WebAssembly`. Wraps
  `HTMLCanvasElement.prototype.getContext` and
  `OffscreenCanvas.prototype.getContext` so `webgl`, `webgl2` and
  `experimental-webgl` return `null`. `2d` and `bitmaprenderer` are untouched.
- **JavaScript on `http:` pages.** When `location.protocol === 'http:'`, it
  inserts `<meta http-equiv="Content-Security-Policy" content="script-src
  'none'">` before the parser reaches any page script. That stops inline and
  external scripts, inline event handlers and `javascript:` URLs. The script
  checks the scheme itself. It does not rely on an `http://*` origin rule,
  whose acceptance by WebView is not documented.

The app's own document-start scripts are injected by the browser, not as
`<script>` elements, so the CSP does not stop them.

### 1.3 Safest

- `javaScriptEnabled = false` and `blockNetworkImage = true`.
- `Shields.apply` adds no document-start scripts, since none can run. With no
  JavaScript there is no WebRTC, WebSocket or fingerprinting API for the
  shields to remove.
- `data:` images still show; only network images are blocked.

### 1.4 Gaps (approved with the section)

- **No JIT switch.** Safer's WebAssembly removal is a partial stand-in.
- **Workers** are not reached by Safer's scripts: a worker keeps WebAssembly
  and `OffscreenCanvas` WebGL.
- **The `http:` CSP has never been seen on a device.** Whether a meta CSP
  inserted at document start stops the parser's later scripts in WebView 154
  must be checked first (§7). If it does not, the fallback is to switch
  `javaScriptEnabled` per main-frame navigation, and the plan says so.
- **At Safest, Reader probably extracts nothing:** `extractArticle` runs
  JavaScript. It already does nothing when extraction fails. To be seen on a
  device.
- **At Safest, custom CSS and CSS library scripts do not apply:** they are
  injected through JavaScript. Custom JS and JS library scripts do not run,
  as expected.
- **Fonts and media are not blocked at any level** (user's ruling: no
  URL-extension heuristic).

### 1.5 Unknown values fail closed

- Kotlin: a `securityLevel` it does not recognise, or none, is **Safest**.
- Dart: a stored `security_level` it does not recognise reads as `safest`.
  Only a downgrade or a damaged row can produce one.

## 2. Storage, where it is set, how it applies (approved)

### 2.1 Storage

- **Per site:** `Site.securityLevel` (`SecurityLevel?`). Null means "follow
  the vault default". Column `security_level TEXT`, nullable, holding the
  enum name. **Schema 9**, and existing rows upgrade to null.
  - `copyWith` cannot set a nullable field back to null, so the site gets an
    explicit way to clear it (the plan picks the shape).
  - Decoy re-sync copies it.
  - New identity and every wipe keep it: it is a setting, not data.
  - The `2a` form has no control for it. Saving the form keeps whatever the
    site had.
- **Vault default:** the open vault's `app_settings` under `security_level`,
  holding the enum name, falling back to `standard`. It is per vault, like
  `search_engine`, and it is never read before an unlock.
- **Throwaway:** starts with null. An override set on it lives in its
  in-memory `Site` and is kept if it is saved.

### 2.2 Resolution

When a site opens, Dart resolves the effective level, `site.securityLevel ??
vault default`. It sends that level over the channel as `securityLevel`, so
Kotlin never sees "follow the default". `SiteConfig` gains `securityLevel`.

### 2.3 Where it is set

- **☰ menu row** → the **site picker**. Its first row follows the vault
  default; then come Standard, Safer and Safest, with the current choice
  checked.
- **`6c` row** → the same site picker.
- **Settings, BROWSING**, a row after `Search engine` → the **vault picker**,
  with Standard, Safer and Safest only.

### 2.4 How a change applies

- **A site change** (level, or any `6c` switch, §3) saves the row (a
  throwaway: its in-memory `Site`), then **reopens the site in place** at the
  page it is showing (`navigation.url`, or the address it was opened with
  before any navigation event). The route stays; only the session and its
  view are replaced, as `8b`'s buttons already do.
- **Reopening in place never wipes.** Today, closing a wipe-on-exit site or a
  throwaway wipes its profile (`ContainerView.dispose`). The swap hands the
  profile from the old view to the new one without that wipe, so a
  throwaway, or a wipe-on-exit site, keeps its login across a switch. (Ruling
  1.)
- **Lost by a reopen:** back/forward history, "allow while this site is open"
  grants, find state.
- **A vault default change** applies to each site at its next open. Open
  sites keep the level they opened with.
- A reopen onto a refused route shows `8b`, as any open does.

## 3. The `6c` shield panel (approved)

`SiteSheet` becomes scrollable: it is now taller than a phone screen. Rows in
order, ★ marking what is new:

1. Header (monogram, name, subtitle, `Edit`), `Proxy`, `Cookies`: unchanged.
2. ★ **`Security level`**: the effective level (§5), and a tap opens the site
   picker.
3. `Blocked here`, `N requests`: unchanged.
   ★ Under it, one indented, muted row per category whose count this session
   is above 0. Rows appear in `5c`'s order and use `5c`'s labels, `Trackers`,
   `Ads`, `Fingerprinting` and `Permission asks`, with the count in mono and
   no dividers. The counts already exist natively (`EngineChannel`'s session
   map); the Dart session snapshot gains them.
4. ★ **`Block WebRTC`**, **`Block trackers and ads`**, **`Anti-fingerprinting`**:
   switches, with `2a`'s canvas titles and no subtitles.
5. `Force dark mode`, `Desktop view`: unchanged switches.
6. ★ **Permissions in use:** a row for each of `Camera`, `Microphone`,
   `Location` and `Clipboard` that is granted, using `2a`'s labels. No row
   when nothing is granted.
   - A **stored** grant (`allow*` set in `2a`) reads `Allowed`. It is not
     tappable; it changes through `Edit`.
   - An **"allow while this site is open"** grant shows a `Revoke` text button,
     in a neutral colour, not jade.
   - "Allow once" grants are not tracked natively, so they never appear.
     Clipboard is only ever a stored grant.
7. `Close and wipe this session`: unchanged.

**Every switch in `6c`, old and new, applies at once** (§2.4). This removes
Plan 6's known gap that `6c`'s switches applied only at the next open.

**Revoke** calls a new native `revokeGrant(siteId, kind)`. It removes that one
kind from the session's grants and reloads the page. The reload ends a live
camera or microphone stream, and the next ask shows `6a` again. History and
the other grants stay. The session snapshot gains its grant kinds (`camera`,
`microphone`, `location`) so Dart can draw the rows.

## 4. New identity (approved)

### 4.1 Where

A ☰ row. `BrowserMenuSheet`'s rows become:

1. `Security level`, with the effective level as mono meta (§5)
2. `New identity`
3. `Today`, `Scripts and filters`, `Workspaces`, `Settings`, `All sites`, as
   today.

### 4.2 The confirm sheet

`NewIdentitySheet` is styled like `WipeSiteSheet`, with no jade, and opens on
the open vault's own navigator. Cancel, a tap outside and back do nothing.
Nothing is shown afterwards.

### 4.3 What it does

- **A saved site:** `wipeSavedSite` (close, wipe the profile and kept
  downloads, write the row back with a fresh `profileId`, clear "Last
  worked"), then reopen in place at the site's **saved address** (`site.url`).
  This reopen follows a real wipe; it is not §2.4's swap.
- **A throwaway:** close and wipe it, give its in-memory `Site` a fresh
  `profileId`, and reopen it in place, as a throwaway (journaled before the
  profile exists, browser-chrome spec §5.4), at the address it was opened
  with.

| Changes | Stays |
|---|---|
| Cookies, storage, cache (deleted whole at the next start, as every wipe), history, kept downloads | The site's row, id, settings and level override |
| "Allow while open" grants, back/forward history | Its library scripts |
| The loopback proxy credential (it is per profile) | A **typed** proxy login |
| The per-site proxy login (`Separate login per site`), so on Tor a new circuit | |

**Gap:** with a typed login, or no login, the upstream proxy sees nothing
change. On Tor, only `Separate login per site` gives the site a new circuit.

### 4.4 Tabs

New identity closes **every page** in the site's container. How Plan 15 holds
those pages decides how; see §8.

## 5. New copy (approved 2026-10-02)

Every string below is new. The user approved all of it word for word.

| Where | String |
|---|---|
| Level names | `Standard` · `Safer` · `Safest` |
| Row title in ☰, `6c` and Settings (BROWSING); title of both pickers | `Security level` |
| Picker, second line under each level | Standard `Every site feature is on` · Safer `JavaScript off on http pages · no WebGL or WebAssembly` · Safest `JavaScript and images off on every page` |
| Site picker's first row | title `Default`, second line `<Level> · set in Settings` (e.g. `Standard · set in Settings`) |
| `6c` Security level value | `<Level>` for an override; `<Level> · default` when following the default |
| ☰ Security level meta (mono) | `STANDARD` · `SAFER` · `SAFEST` |
| ☰ row | `New identity` |
| Confirm sheet | title `New identity for this site?` · body `Its logins, storage and downloads are destroyed, and it starts over at its first page.` · button `New identity` · `Cancel` |
| `6c` permission values | stored grant `Allowed` · while-open grant button `Revoke` |
| Settings row value | the level name |

**Reused, not new:** `Block WebRTC`, `Block trackers and ads`,
`Anti-fingerprinting`, `Camera`, `Microphone`, `Location`, `Clipboard` (canvas
`2a`); `Trackers`, `Ads`, `Fingerprinting`, `Permission asks` (canvas `5c`);
`N requests` (canvas `6c`); `Cancel`.

**Screen-reader labels:** none new. Every new control has visible text.

## 6. Global constraints, as they apply here

- **Two vaults.** Every control here looks and behaves the same in both
  vaults. The vault default is per vault, like the search engine, and is
  never read before an unlock, so the lock screen cannot be compared with
  either vault's Settings (the `shared-auto-lock` lesson). No code asks which
  vault is open, and nothing counts across vaults.
- **No requests of the app's own.** Nothing here fetches anything. New
  identity makes no request; the reopened page is the site's own traffic.
- **Never direct.** A reopen goes through the same open path, route resolution
  and loopback proxy as any open. New identity and reopen never change a
  route.
- **Jade:** each picker marks its current row with a jade check, as
  `SearchEnginePicker` and the workspace menu already do: the one selected
  state on that sheet. `Revoke` and the confirm sheet use none. In `6c`, `Edit`
  stays the only jade.
- **Copy:** only §5's strings are new.

## 7. Testing and verification

- **Dart unit:**
  - level resolution (override, default, fallback `standard`, an unknown
    stored value reading as `safest`);
  - schema 8→9 upgrade and round trip;
  - decoy re-sync copying the override;
  - a throwaway starting at null;
  - clearing an override.
- **Widget** (with `FakeContainerEngine`):
  - the ☰ rows, their meta and their destinations;
  - both pickers, with the current row checked;
  - the vault picker persisting;
  - `6c`'s new rows: the level value with and without `· default`; category
    rows only above 0; permission rows `Allowed` and `Revoke`;
  - every `6c` switch saving, then reopening in place at the current page;
  - Revoke calling `revokeGrant`;
  - the New identity sheet (Cancel, outside and back do nothing);
  - New identity on a saved site (close, wipe, rotate, reopen at `site.url`)
    and on a throwaway (fresh profile, reopened as a throwaway).
- **Kotlin JVM** (pure functions, as `dispositionFor` and `Teardown` are):
  - the level parsed from the channel, unknown or missing → Safest;
  - the settings and injected scripts chosen for each level;
  - a swap not wiping, and a close still wiping;
  - `revokeGrant` removing one kind;
  - the session map's grant kinds and category counts.
- **Gates:** `flutter analyze` clean; `flutter test` all passing; Kotlin JVM
  tests with counts read from the JUnit XML; `flutter build apk --debug` with
  zero `e:` lines.
- **Device: not available to the planning session.** The work is marked
  **Not verified on a device**, and `tool/device-check/` gains a run sheet and
  local test pages (an `http:` page with inline and external scripts and an
  `onclick`, a WebAssembly probe, a WebGL probe, an image page), served by the
  harness. **First check: the `http:` CSP (§1.4).** Then:
  - each level's effects;
  - Reader at Safest;
  - a switch reopening a throwaway without losing its cookie;
  - New identity giving a new `--any-login` user at `proxy.py` and journaling
    the old profile;
  - Revoke ending a microphone stream, and the next ask showing `6a`.

## 8. Coordination

- **Plan 15 (Tabs)** takes over the pushed-route stack, `N OPEN` and `2c`
  (browser-chrome spec §11). Plan 16 is written against its result. Points of
  contact:
  - **Reopen in place** (§2.4) and **New identity** (§4) replace a site's
    session. With several pages per container, they must act on every page
    (reopening each at its own page, or as Plan 15's model dictates), and the
    swap's no-wipe rule must hold for each.
  - **Revoke** reloads the page that holds the grant; grants are per session.
  - **`BrowserMenuSheet`** and **`6c`** may change shape under Plan 15.
- **Project 4 (restyle)** is also running. It may restyle `6c`, the pickers
  and Settings; Plan 16 rebases onto whichever lands first.

## 9. Known gaps (deliberate)

All of §1.4, plus:

- **A vault default change does not reach open sites** until they reopen.
- **A reopen loses back/forward history** and "allow while open" grants (the
  cost of approach A).
- **New identity does not change a typed proxy login** (§4.3).
- **New identity cannot rotate what Chromium caches for the process:** the
  old profile's HTTP auth cache entry for the loopback proxy stays in memory
  until the process ends, as with every wipe (P2 spec §2). It names a profile
  no site uses any more.
- **The level is not shown in the address pill** (user's ruling).
- **Not verified on a device**, any of it (§7).

## Rulings (decided without asking)

1. **A reopen in place hands the profile over without wiping it**, whatever the
   cookie policy (§2.4). Without this, flipping a switch on a throwaway or a
   wipe-on-exit site would log it out.
2. An unknown or missing level is **Safest** in Kotlin and `safest` in Dart
   (§1.5).
3. Safer's scripts run on every origin (`*`) and check the scheme themselves
   (§1.2).
4. At Safest, `Shields.apply` adds no scripts (§1.3).
5. The reopen loads the page being shown, or the opened address before any
   navigation event.
6. Blocked images and CSP-blocked scripts are **not counted** in the blocked
   tally. It counts filter-list blocks, fingerprinting reads and permission
   asks, as today.
7. Counts already in the Today tally stay after a reopen or New identity.
8. New identity keeps the level override and every switch (§4.3).
9. `6c`'s switches on a throwaway change only its in-memory `Site`, then
   reopen it in place.
10. The ☰ meta and the `6c` value show the **effective** level.
11. The Settings row sits in BROWSING, after `Search engine`.
12. The pickers check their current row with `SearchEnginePicker`'s jade
    check.
13. Revoke reloads rather than reopens, so history and the other grants stay.

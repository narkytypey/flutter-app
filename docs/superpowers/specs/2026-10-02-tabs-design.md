# Tabs — design

**Date:** 2026-10-02
**Status:** Every design question below was answered by the user in
conversation on 2026-10-02. This written spec awaits the user's review.
**Project 2 of 4** in the browser-chrome series
(`2026-09-28-browser-chrome-design.md` §0). It takes over that spec's
pushed-route stack (§5.2), the bottom bar's `N OPEN` count (§6.1) and the
`2c` switcher, which is a one-entry stub today (`openCount: 1`; §11
"Handoff to later projects").

## 0. Context

Today a container is exactly one page. Natively, `EngineChannel` holds one
`Session` per site id, and that session has one `ContainerView`, which owns
one WebView. In Dart, each open container is a `ContainerRoute` pushed on the
open vault's navigator: the dashboard, search and the address bar each push
one. The WebView lives and dies with its Flutter platform view, so **backing
out to the dashboard destroys the page**: the session record stays (the site
reads as OPEN NOW), but going back in runs `open` again and loads the stored
address fresh.

The canvas has no tab design. `2c` ("Quick switcher drawer") is a switcher
across *containers*: "3 OPEN SESSIONS", "PERSONAL", rows "Forum · viewing now ·
socks5", "Notes · background · 2 min", "Webmail · background · 14 min",
"Close all and wipe", and panic.

### Terms

- **Container:** one open site, saved or throwaway, with one profile, one
  route and one proxy login. Unchanged from today.
- **Page:** one WebView inside a container. Every page in a container shares
  its profile (cookies, storage), its route and its loopback credential.
- **Viewed page:** the page on screen. Each container also remembers its
  *last viewed* page.
- **Opener page:** the page whose link opened this one, in the same
  container.
- **Opener container:** for a throwaway, the container it was typed in.

### Decisions the user made (2026-10-02)

| Question | Decision |
|---|---|
| What `2c` lists | **Containers, with their pages nested.** One row per open container, in the canvas's copy. A container with two or more pages lists them under its row, indented. × on a page closes that page; × on a container closes the whole container. |
| How a new page opens | **Only from links that ask for a new window** (`target=_blank`, `window.open`), and only on a user tap. No "new page" button, no link menu, no address-bar option, so no new copy. |
| New page focus | **It comes to the front**, as in Chrome on Android. |
| Moving between containers | **Switch in place.** One container host route sits over the dashboard and shows whichever container and page is viewed. Picking a `2c` row swaps it, with no push or pop. |
| Do pages survive the dashboard? | **Yes.** A page's WebView lives as long as its container is open and is reattached when you come back, from the dashboard, `2c` or search. |
| System back on a page with no history | **Close the page and return to its opener page.** With no opener page: a saved container goes to the dashboard and stays open; a throwaway goes to its opener container. |
| Throwaway whose opener container is closed | Back goes to the **most recently viewed open container**. If no other container is open, the throwaway would be unreachable, so it **closes, is wiped, and you land on the dashboard**. |
| `N OPEN` | **Open containers**, vault-wide, throwaways included. The same number as `2c`'s "N OPEN SESSIONS". |
| Which containers `2c` lists | **All open containers in the vault**, from any workspace. The right-hand label is the viewed container's workspace, empty for a throwaway. |
| "Close all and wipe" | **Every open container** is closed and wiped. You land on the dashboard. |
| Closing the viewed container from `2c`'s × | **The dashboard**, as today. Closing a *page* row shows that container's most recently viewed remaining page. |
| Background pages | **Paused** (`WebView.onPause`). A camera, microphone or location ask, or a held download, from a background page **waits and is shown when that page is next viewed.** |
| Cap on live pages | **None.** Recorded as a known gap. |
| A site's settings saved while its container is open | A change to its **route or cookie policy closes the container**, under the new cookie policy. The **viewed** container then **reopens in place** under the new settings, fresh at its stored address (as `8b`'s "Change proxy settings" already does). A background container just closes. Every other change waits until the container is next opened after closing. |
| Dashboard `N SESSIONS` | **Stays per workspace**, and now also counts throwaways whose workspace (their opener's) is the one shown. `9b`'s count, `2c` and `N OPEN` are vault-wide, throwaways included. |
| Typing the address of a saved site whose container is open | **Switch to that container and load the address in its last viewed page.** This carries Plan 12's 2026-10-02 ruling over to pages. |
| Page row look | **The page title, falling back to the host, with the host in mono below.** The viewed page is in primary text, the others muted. No jade, no rail. |
| Background age in `2c` | **`now` / `N min` / `N h`**: "background · now", "background · 14 min", "background · 2 h". These are `1a`'s units ("Open · now", "Idle · 2 h"). |

## 1. Scope

**In:**

- Several pages per container, opened by links that ask for a new window.
- Pages that outlive their Flutter view: the native page is no longer
  destroyed when you leave for the dashboard (§3).
- One container host route that replaces the pushed `ContainerRoute` stack
  (§4).
- A real `2c` (§5.1) and a real `N OPEN` (§5.4).
- Back, closing, and where you land (§5.2, §5.3).
- Background pausing, and asks held until a page is viewed (§5.6).
- A route or cookie-policy change closing an open container (§5.7).
- Every lock closing every container natively (§5.8).

**Out:**

- A "new page" button, a link context menu, and "open in new page" from the
  address bar. The user chose links only, and each of these would need new
  copy.
- Restoring pages after a lock or a restart. Every lock still closes
  everything (browser-chrome §1's accepted cost), and pages are runtime only.
- Listing throwaways on the dashboard. They are reached through `2c` and
  through back.
- Live page previews (`1c`).
- Security level and New identity (project 3), and restyling other screens
  (project 4).
- A cap on live pages.

## 2. What stays true

These carry over unchanged, and every task's requirements include them:

- **Dark only.** **One jade per screen**, meaning live state or the single
  affirmative action. `2c` keeps the canvas's jade header, jade rail on the
  viewed container and 45%-jade rails on the others, exactly as drawn. Page
  rows add no jade.
- **Hairlines, not cards.**
- **No network requests of the app's own.** A page opened by a link is the
  page's own request, on its container's route.
- **The route never falls back to direct.** Every page of a container is on
  that container's route and profile and holds its credential. A new page
  never gets a route of its own.
- **Throwaways and their journal** (`ThrowawayJournal`) are unchanged. The
  journal is per profile, and a container still has exactly one profile. A
  throwaway's pages are all wiped together when the container closes.
- **Everything goes through the open vault's own `Navigator`**: no
  `rootNavigator`, no `useRootNavigator: true`.
- **`open` decides the session; the view never does.** A page view binds to
  an exact page id that its own container's `open` (or a link) created, never
  to "whatever session the site has now". Plan 12's `_openReturned` problem
  cannot recur, because page ids are never reused.
- **`ProfileManager.wipe` journals an in-use profile**
  (`PendingDeletions`). `ProfileStore` is UI-thread only. Proxy probing never
  runs on the main thread.
- **Two-vault model.** The open-containers registry is in memory, emptied on
  every transition out of `SessionOpen`, and never asks which vault is open.

## 3. Engine: pages that outlive their view

### 3.1 Kotlin

`android/app/src/main/kotlin/com/mono/container/engine/`:

- **`Page`** (new) takes over what `ContainerView` does today. It owns one
  WebView and everything attached to it:
  - settings, `Shields.apply`, and the site's user scripts;
  - the `RequestInterceptor` client, the chrome client, the find listener and
    the download listener;
  - its `NavigationTracker` and its `Teardown`.

  It is created with a `MutableContextWrapper`, so a WebView made before any
  view exists can later be shown in the activity.
- **`Session`** holds `pages: LinkedHashMap<String, Page>` (page id → page)
  instead of `view`. Its filters, counters, interceptor, pending asks,
  binding and wipe-on-exit flag stay per session, so per container.
- **`open`** registers the session as today. On a route that is not refused,
  it also creates the container's first page (a fresh page id) and loads
  `firstLoadUrl(config.url, initialUrl)`. The returned session map carries
  `pages`, the list of page ids.
- **New windows.** `setSupportMultipleWindows(true)`. `onCreateWindow`
  answers `false` unless `isUserGesture` is true. Otherwise it creates a new
  `Page` in the same session: `setProfile` comes before the transport hands
  the new WebView its first navigation. It then emits
  `page_opened {siteId, pageId, openerPageId}`.
  `javaScriptCanOpenWindowsAutomatically` stays `false`. `onCloseWindow` (a
  page's own `window.close()`) closes that page and emits
  `page_closed {siteId, pageId}`.
- **`PageHost`** (new; replaces `ContainerView` as the `PlatformView`). Its
  creation params carry a `pageId`. `getView()` is a `FrameLayout`, and the
  host attaches the page's WebView into it and calls `onResume`.
  `dispose()` only detaches the WebView and calls `onPause`. It never
  destroys the WebView. A `pageId` that `open` or `page_opened` never
  produced is an error, as an unopened site id is today.
- **Closing.**
  - `closePage(pageId)` runs that page's `Teardown`: the page refuses
    everything, loads `about:blank`, and is destroyed.
  - `close(siteId, wipe?)` tears down every page, and then, if the session
    is to be wiped, runs the wipe once, after the last page is destroyed. The
    wipe is today's `destroyAndWipe` (cache cleared through a WebView before
    it goes, profile wiped or journaled, kept downloads deleted, taken off
    the throwaway journal). `wipe` overrides the session's flag for this
    close only; omitted, the session's own flag decides (§5.7).
  - `closeAll()` (new) closes every session. Lock calls it (§5.8).
  - `wipeAll` calls it before deleting every profile, as it closes every
    session today.
- **Events now carry the page.** `navigation`, `find_result`,
  `permission_request` and `download` each gain `pageId`. `navigationState`
  takes a `pageId`. `tunnel_dropped` and refusals stay per site (a route is
  per container).
- **In-page methods take a page id** instead of a site id: `reload`,
  `goBack`, `goForward`, `stop`, `loadUrl`, `find`, `findNext`, `clearFind`
  and `extractArticle`. Each stays a silent no-op on an unknown page.
  `loadUrl` still refuses every scheme but http and https (`isLoadableUrl`).

### 3.2 Dart

`ContainerEngine` (`lib/data/services/container_engine.dart`):

- In-page methods take `pageId`.
- `navigation()` and `navigationState(pageId)` are keyed by page.
- `close(siteId, {bool? wipe})`, `closePage(pageId)` and `closeAll()`.
- `pageEvents()` emits `PageOpened(siteId, pageId, openerPageId)` and
  `PageClosed(siteId, pageId)`.
- `ContainerSession.pages`.
- `NavigationState`, `FindResult`, `PendingPermissionRequest` and
  `HeldDownloadEvent` gain `pageId`.

`ChannelContainerEngine` maps all of it. `FakeContainerEngine` implements all
of it, including opening a page "from a link", so widget tests can drive
tabs.

`ContainerWebView` becomes `PageView(pageId)`, keyed by its page id. Swapping
pages disposes one platform view and creates another, which now only
detaches one WebView and attaches the other. The chrome around it still keeps
the page view's slot fixed, to avoid a needless detach and reattach.

## 4. Dart: one host, a registry of open containers

### 4.1 `OpenContainers` (new registry)

A `Notifier` in `lib/ui/features/container/view_models/open_containers.dart`.
It holds, in memory:

- the open containers in opening order. For each:
  - the site as opened, and whether it is a throwaway;
  - for a throwaway, its opener container's site id;
  - its pages in opening order, each with its opener page id;
  - its last viewed page;
  - when it was last viewed;
  - its lifecycle: opening, live, or refused with `8b`'s failure; whether a
    tunnel drop is pending; and a throwaway's save-bar state (first load
    done, dismissed);
  - its asks and held downloads waiting for a page to be viewed;
- the viewed container's site id, or none while the dashboard shows.

Like `ThrowawaySites` today, it watches the open database. On every
transition out of `SessionOpen` it is rebuilt empty, and its `onDispose` calls
`engine.closeAll()` (§5.8). It absorbs `throwawaySitesProvider`. A throwaway
is an entry with `throwaway: true`.

The `opening → live → refused` logic, `8b`'s reopen, the tunnel-drop flag and
the save-bar state move out of `_ContainerRouteState` into this registry and
a small per-container controller. They have to survive the host route going
away while the container stays open.

`openSiteIdsProvider` becomes a view of the registry: the ids of every open
container, saved and throwaway. Its callers (`openSite`/`closeSite`, the
dashboard, search, `9b`, the workspace menu) keep their meaning.

### 4.2 `ContainerHostRoute` (replaces pushed `ContainerRoute`s)

There is at most one host route on the open vault's navigator, directly
above the dashboard. It renders the viewed container's viewed page with
Plan 12's `ContainerScreen`, unchanged except for `2c`'s content and
`N OPEN`. It also shows the opening checklist (`8a`), `8b` and `8c` for the
viewed container, as `ContainerRoute` does today.

- **Opening a site** from the dashboard row, a search result or the address
  bar calls `OpenContainers.view(site, …)`:
  - If the site is open, it becomes the viewed container, showing its last
    viewed page. Nothing reloads, and `open` is not called again.
  - Otherwise it is opened (`engine.open`), registered, and viewed.
  - Then the host route is shown: pushed if it is absent, left in place if
    it is on top. Anything above it (Settings, Today and so on) is popped
    first.
- **Leaving for the dashboard** pops the host route. Every page stays
  alive, paused (§5.6).
- `☰ → All sites` pops to the dashboard, as today. It no longer closes
  anything on the way, since there is no stack of containers to pop.
- Screens the chrome opens (Today, Scripts, Workspaces, Settings, Reader,
  the add-site form) are still pushed above the host route.

## 5. Behaviour

### 5.1 `2c`

```
3 OPEN SESSIONS                      PERSONAL
▌ Fr  Forum                                 ×
      viewing now · socks5
         Thread: rules                      ×
         forum.example.com
         Members                            ×
         forum.example.com
──────────────────────────────────────────────
▌ Nt  Notes                                 ×
      background · 2 min
──────────────────────────────────────────────
[ Close all and wipe ]                    [◉]
```

- **Header:** `N OPEN SESSIONS`, where N is every open container in the
  vault. On the right is the viewed container's workspace name in capitals,
  empty for a throwaway.
- **Container rows**, in the canvas's style (`_SwitcherRow`, unchanged):
  - the viewed container first, then the rest, most recently viewed first;
  - meta `viewing now · <mode>` for the viewed container and
    `background · <age>` for the rest. `<mode>` is the route mode as today
    (`socks5`, `http`, `direct`). `<age>` is the time since the container
    was last viewed: `now` under a minute, `N min` under an hour, then `N h`;
  - a throwaway's name is its host, as elsewhere.
- **Page rows**, only under a container with two or more pages, in opening
  order:
  - indented to the container row's text column;
  - a 13px title line (the page's title, or its host when it has none) and a
    mono host line;
  - `C.textPrimary` for the page on screen or the container's last viewed
    page, `C.textMuted` for the rest;
  - a × at the right; a hairline only between container groups.
- **Tapping:**
  - a container row views it, on its last viewed page;
  - a page row views that page;
  - a row already viewed just closes the sheet.
- **Each ×:**
  - on a page closes that page (`closePage`). Its container's last viewed
    page becomes its most recently viewed remaining page. If it was on
    screen, that page is shown;
  - on a container closes it: a saved site's session closes, and is wiped
    if its policy is wipe on exit; a throwaway is closed and wiped. If it was
    the viewed container, you land on the dashboard.
- **`Close all and wipe`** closes and wipes every open container. A saved
  site goes through `wipeSavedSite`, which rotates its `profileId`. A
  throwaway is closed and wiped. You land on the dashboard.
- **Panic** is unchanged.

### 5.2 New pages

A link that asks for a new window, on a user tap, opens a new page in the
same container and brings it to the front: the container's viewed page
becomes the new one. Its opener page is recorded. Without a user gesture,
nothing opens and nothing is shown, as today with multiple windows off.

### 5.3 System back

In order:

1. Address editing or find is open: leave it. Unchanged from Plan 12.
2. The page has history: `goBack`.
3. The page has an opener page that is still open: close this page and view
   the opener.
4. A saved container: go to the dashboard. The container stays open.
5. A throwaway:
   - its opener container is still open: view that container;
   - otherwise another container is open: view the most recently viewed one;
   - otherwise: close and wipe the throwaway, and land on the dashboard.

The in-page Back button (bottom bar) still only goes back in history. It is
dimmed when `canGoBack` is false.

### 5.4 Counts

- **Bottom bar `N OPEN`** and **`2c`'s header:** every open container in the
  vault, throwaways included.
- **`9b`'s session count:** the same vault-wide number.
- **Dashboard `N SESSIONS`** and the **workspace menu's `M OPEN`:** open
  containers whose workspace is that workspace. A throwaway counts under its
  opener's workspace (`Site.workspaceId`, already set by `buildThrowaway`).
- **OPEN NOW** still lists only saved sites. Throwaways are not listed on
  the dashboard.

### 5.5 Address bar destinations

`resolveDestination` is unchanged. What each result does:

- **`ThisContainer`:** `loadUrl` in the viewed page.
- **`SavedSiteContainer`:**
  - its container is open: view it and `loadUrl` in its last viewed page;
  - otherwise: open it with `initialUrl` and view it. Its stored address is
    never changed.
- **`Throwaway`:** open a new throwaway container whose opener container is
  the current one, and view it.

### 5.6 Background pages, and asks that wait

- **Pausing.** Every page that is not attached to the screen is paused
  (`WebView.onPause`, per view; never the process-wide `pauseTimers`). The
  attached page is resumed. Leaving for the dashboard pauses every page.
- **Asks wait.** A permission ask or a held download whose page is not on
  screen is queued on its container in the registry. The platform already
  holds the request with no timeout. When its page is next viewed, its asks
  are shown one at a time, oldest first, through the existing `6a` and `7c`
  sheets. Plan 6's "a backgrounded site's events are dropped" gap is closed
  for pages.
- **`8c` waits.** A tunnel drop on a background container sets its flag, and
  `8c` shows when that container is next viewed.
- **`8b` waits.** A refusal on a background container is shown when it is
  viewed. A saved site's refused session is closed and taken off OPEN NOW,
  as today.

### 5.7 Settings saved while a container is open

The **route** is `proxyMode`, `proxyHost`, `proxyPort`, `proxyUser`,
`proxyPassword` and `proxyLoginPerSite`. When a save from any form changes
the route or `cookiePolicy` of a site whose container is open, the container
is closed with `close(siteId, wipe: newPolicy == wipeOnExit)`. A site moved to
wipe on exit is wiped now, and one moved to keep is not. Then:

- **Viewed container:** it reopens in place under the new settings, fresh at
  its stored address, like `8b`'s reopen.
- **Background container:** it stays closed until it is next opened.

The forms are `6c`'s Edit, the dashboard row's edit form, `8b`'s "Change
proxy settings" (which already reopens) and `Save as a site` on a throwaway.
Any other change (force dark, desktop view, user agent, scripts, zoom and so
on) applies the next time the container opens after closing. The
`6c` switches change neither the route nor the cookie policy, so they never
close anything.

### 5.8 Lock and panic

Pages no longer die with the widget tree, so the tree can no longer close
them. **Every transition out of `SessionOpen` calls `engine.closeAll()`** from
the registry's own reset (§4.1), whatever path leaves `SessionOpen`. Every
page is torn down, every wipe-on-exit profile is wiped, and every throwaway
is wiped and leaves the journal. This also closes something that has been
true since Plan 6: today a lock leaves every saved site's native session and
loopback binding registered.

Panic is unchanged. `wipeAll` closes everything first.

### 5.9 Everything else acts on the viewed page

Reload, find, Reader, Copy link and the ☰ menu act on the viewed page. The
shield's `6c`, `Save as a site` and the save bar act on the viewed
container. The save bar shows for a throwaway once its first page has
finished a load, and it is dismissed per throwaway, as today.

## 6. Copy

**No new strings.** Everything shown is canvas copy or page data:

| Where | String | Source |
|---|---|---|
| `2c` header | `N OPEN SESSIONS` | `2c` |
| `2c` meta | `viewing now · <mode>`, `background · <age>` | `2c` |
| `2c` ages | `now`, `N min`, `N h` | `1a`'s "Open · now", "Open · 14 min", "Idle · 2 h" (user's ruling, 2026-10-02) |
| `2c` page rows | page title, or host; host | page data |
| `2c` buttons | `Close all and wipe`, `◉` | `2c` |
| Bottom bar | `N OPEN` | `2b` / browser-chrome §6.1 |

## 7. Testing and verification

- **Pure Dart:**
  - the background-age formatter;
  - `2c`'s entry list: ordering, pages only for 2+, workspace label, empty
    for a throwaway;
  - the back decision (§5.3), every branch;
  - the route-change detector (§5.7): each route field and the cookie policy
    count, while force dark, desktop view, user agent and name do not;
  - the counts (§5.4), including a throwaway counted under its opener's
    workspace.
- **Registry:**
  - open, view, close page, close container and close all;
  - emptied, with `closeAll` called, on a `9b` lock, a `9c` lock and panic;
  - a throwaway's opener container recorded;
  - asks queued for a background page and released when it is viewed.
- **Widget tests** with `FakeContainerEngine`:
  - a link opening a page that comes to the front;
  - back closing it to its opener;
  - back on a saved container's first page landing on the dashboard with the
    container still open, and coming back without `open` called again;
  - a throwaway's back to its opener container, to the most recently viewed
    container, or wiped;
  - `2c`'s rows and × actions;
  - "Close all and wipe" closing every container;
  - `N OPEN`;
  - the dashboard's count with a throwaway;
  - a route edit reopening the viewed container in place;
  - a 360-wide phone with a long title in `2c`, with no overflow.
- **Kotlin JVM:**
  - the page registry (open's first page, a link's page, `closePage`,
    `close` wiping once after the last page, `closeAll`);
  - `onCreateWindow` refusing a call without a user gesture;
  - `PageHost` detaching without destroying;
  - the per-page event maps.
- **Gates:** `flutter analyze` clean, `flutter test` all passing, Kotlin JVM
  tests with counts read from the JUnit XML, and `flutter build apk --debug`
  with zero `e:` lines.
- **Not verified on a device.** No emulator is available where this is
  built. The plan carries a "Device checks" run sheet for the user, using
  `tool/device-check/`.

## 8. Known gaps (deliberate)

- **No cap on live pages.** Each is a WebView. Android may kill the process
  under memory pressure, and the throwaway journal survives that, but every
  page is lost.
- **Pages do not survive a lock or a restart.** Every lock closes
  everything, `9b` included (browser-chrome §1's accepted cost).
- **No way to open a new page except a link that asks for one.**
- **Pausing is WebView's.** `onPause` stops media, animations and
  geolocation. It does not stop every script, and a background page's
  network activity continues on its route.
- **A popup without a user gesture is dropped silently.** There is no
  "popup blocked" notice, since that would need copy.
- **Cosmetic setting changes wait for a close.** Force dark, desktop view
  and similar changes apply only once an open container is closed and
  reopened.
- **The dashboard does not list throwaways.** They are reached through `2c`
  and through back.
- **Device-unverified:** reattaching a WebView to a new platform view, the
  `onCreateWindow` transport with a profile set, and `onPause` behaviour are
  all from the WebView contract, not observed.

## 9. Handoff to later projects

- **Project 3 (privacy controls):**
  - adds rows to `BrowserMenuSheet` and extends `6c`, both unchanged in
    shape here;
  - New identity acts on a container, so on all of its pages at once:
    `close(siteId, wipe: true)` plus `wipeSavedSite`'s rotation, then a
    reopen in place (§5.7's path);
  - a security level that changes WebView settings applies per container,
    because every page of a container is built from the one `SiteConfig`.
- **Project 4 (restyle):** `2c`'s `◉` and `×` glyphs and the page rows are
  left for it.

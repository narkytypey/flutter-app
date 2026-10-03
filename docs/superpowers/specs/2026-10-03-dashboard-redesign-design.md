# Dashboard redesign: tabs, search field, default route

**Status:** design approved section by section by the user on 2026-10-03, in
conversation (session flutter-app-be); this document is for their review.
Supersedes `1b`'s layout and `5b`'s footer where they conflict (the user's
rulings below). Every new string in §8 was approved word for word.

## 1. Why

On the first run on a physical phone (2026-10-03), the user found the dashboard
tiring to use: workspaces behind a dropdown, Today behind that dropdown,
Settings behind `⋯`, Scripts and filters and Workspaces two or three taps deep,
a four-tab form to add a site, and no way to type an address on the dashboard.
Asked who the dashboard is for, the user chose **everyday and power users
equally**: every control stays; the frequent ones move to one tap.

## 2. The user's rulings (2026-10-03)

1. The dashboard footer's `+ Add site` button becomes a **search field**; a `+`
   icon beside it opens the add-site form. The separate saved-sites search
   screen (Plan 7) goes.
2. Pages opened from that field use a **default route set in Settings**.
3. The default route is also **where the add-site form's Network tab starts**.
4. Layout **B**: a bottom tab bar.
5. **No `OPEN NOW`, `IDLE` or `N SESSIONS`** on the dashboard; the green dot
   alone marks an open site. (`N SESSIONS` replaced the leak count; the
   no-leak-count rule in `CLAUDE.md` still stands.)
6. The list is sorted **open sites first, then by last used**.
7. Three tabs: **Sites · Today · Settings**. Scripts and filters stays in
   Settings.
8. Adding a site: the form keeps its four tabs, with the small changes in §6.
9. Inside a container, a **sideways swipe on the bottom bar** moves to the
   previous or next open container.

## 3. Scope

In: the dashboard shell and Sites tab (§4), the search field (§5), the add-site
form's defaults (§6), the default route (§7), the swipe (§9).

Out, unchanged: the container's chrome other than the swipe; `2c`; the ☰ menu
(its Today, Scripts and filters, Workspaces, Settings and All sites rows keep
pushing the screens they push today); the lock, setup and panic screens; the
decoy model. No new network request of any kind.

## 4. The dashboard shell

### 4.1 Tabs

A bottom tab bar under the footer with three tabs, each an `AppIcon` line icon
over its label: **Sites** (the dashboard list), **Today** (`5c`, the existing
`TodayScreen`) and **Settings** (`2d`, the existing `SettingsScreen`). The
viewed tab's icon and label use the primary text colour, the others the muted
one; no jade (jade stays for open sessions).

- As tabs, Today and Settings draw **no back icon** (their `onBack` becomes
  optional; a `null` draws none). Pushed from elsewhere (the ☰ menu) they keep
  it.
- System back on Today or Settings shows Sites. On Sites it does what the
  dashboard's back does today.
- The tab bar belongs to the dashboard only: a container, the add-site form,
  and every screen pushed from a tab cover it.
- The viewed tab is not remembered: unlocking shows Sites.
- Three new glyphs are drawn in Plan 17's style: `sites`, `today`, `settings`.
  `test/no_glyphs_test.dart` must keep passing.

Removed from the dashboard: the workspace bar's dropdown (`▼`) and its menu
(`WorkspaceMenu`, including its Today row), the `⋯` icon (Settings is a tab),
and the `N SESSIONS` label.

### 4.2 Workspace chips

At the top of Sites, a horizontally scrolling row of chips, one per workspace,
in the order the dropdown lists them today, then a `+` chip.

- **Tap** a chip: show that workspace (what picking it in the dropdown did).
  The viewed one is drawn selected.
- **Long-press** a chip: the workspace form (`10b`) for that workspace, as a
  tap on its row in Settings ▸ Workspaces opens today.
- **`+` chip** (screen-reader label `New workspace`): the new-workspace form.
- **Deleting** a workspace stays where it is: Settings ▸ Workspaces,
  long-press a row (`10c`). Not on a chip, so a destructive action is never one
  stray long-press away on the dashboard.

### 4.3 The site list

One list per workspace, no section titles. Rows are `SessionRow`s as today
(monogram, name, mono meta, time), with the green dot on an open site and
nothing on an idle one. Order: **open sites first, most recently visited first;
then the rest, most recently visited first; never-visited last.** Tap and
long-press do what they do today (open; the row menu).

### 4.4 Empty workspace (`5b`)

The footer's `+` icon turns jade, as `+ Add site` did: still the one
affirmative action on the screen. The search field is not jade.

## 5. The search field

The footer: a text field with the placeholder `Search or type an address`
(the container address bar's own placeholder), then a 46px `+` icon
(screen-reader label `Add site`) that opens the add-site form.

Typing shows the container's suggestion rows (`AddressSuggestions`) above the
footer, built by the same `suggestionsFor`, with no opener site:

- up to five saved sites matching the text, from every workspace, each tagged
  `ITS OWN CONTAINER` and opening its own container at its saved address;
- the address row, when the text parses as an address: a saved site's host
  opens that site's container (`ITS OWN CONTAINER`), any other host a
  throwaway;
- the search row, `Search <engine> for “…”`, always.

A throwaway is tagged as today: `THROWAWAY` on a direct default route,
`THROWAWAY · SOCKS5` / `THROWAWAY · HTTP` otherwise. Enter opens the address
row when there is one, else the search row: the same choice the container's
address bar makes.

**Domain change.** `destinationFor`/`suggestionsFor` take the opener as an
optional `current` site plus a route to give a throwaway. With no `current`
there is no `THIS CONTAINER` destination and the throwaway's route is the
default route (§7). With one, behaviour is unchanged. `buildThrowaway` takes
the workspace id explicitly; from the dashboard it is the viewed chip's.

**A throwaway opened from the dashboard** has no opener. It is counted under
the viewed workspace in `2c`, and it is reachable through `N OPEN` and the swipe
(§9). Its first page's back closes and wipes it and shows the dashboard
(`CloseThrowawayToDashboard`), even when other containers are open; a
throwaway opened inside a container keeps today's rule. "Save as a site" opens
the form with the viewed workspace selected.

The saved-sites search screen (`SearchScreen`, `_SearchRoute`,
`searchQueryProvider`, `searchResultsProvider`) is deleted with its tests;
`sitesMatching` stays, since suggestions use it.

## 6. Adding a site

The form keeps its four tabs. Changes:

- It opens with the keyboard up on ADDRESS (autofocus), for a new site only.
- WORKSPACE defaults to the viewed chip's workspace.
- An empty NAME saves as the address's host, as typed (`example.com`): the
  name a throwaway saved as a site already gets (`buildThrowaway`). Today an
  empty name saves a site with no name.
- The Network tab starts from the default route (§7) for a new site only; an
  edited site shows its own route.

## 7. The default route

A **vault setting** (`app_settings`, per vault like the other settings; the
decoy has its own), **Direct** until changed:
mode (direct, SOCKS5, HTTP), host, port, and the login (typed user and
password, or "Separate login per site"), with the same rules as a site's
(Plan 14, ruling 8: a typed login is kept only with the proxy on, per-site
login off and a user typed).

- **Settings ▸ BROWSING** gets a `Default route` row beside Search engine and
  Security level. Its value: `Direct`, or mode and `host:port` in mono
  (`SOCKS5 · 127.0.0.1:9050`).
- Its screen, titled `Default route`, holds the add-site Network tab's route
  fields only: the proxy switch, SOCKS5/HTTP, HOST, PORT, USERNAME/PASSWORD,
  "Separate login per site". Not WebRTC or trackers, which are per site. Those
  fields move out of `NetworkTab` into one widget both screens use.
- It is used by the dashboard's search field (§5) and as the new-site form's
  starting route (§6). Changing it touches no saved site and no open
  container.
- A proxy that cannot be reached refuses the page (`8b`), as for any site;
  nothing falls back to direct.
- With "Separate login per site", each throwaway gets its own login, as a
  throwaway opened inside a site does today.
- Decoy re-sync does not copy it: it is a setting, not a site.

## 8. Copy

New (approved 2026-10-03):

| Where | Text |
|---|---|
| First tab | `Sites` |
| Settings ▸ BROWSING row, and its screen's title | `Default route` |
| That row's value with a proxy | `<MODE> · <host>:<port>`, mono, e.g. `SOCKS5 · 127.0.0.1:9050` |

Reused: `Search or type an address` (field), `Today` and `Settings` (tabs),
`Direct` (row value), `Add site` (`+` label), `New workspace` (chip `+` label),
the suggestion rows and tags unchanged. Removed from the dashboard:
`OPEN NOW`, `IDLE`, `N SESSIONS`.

## 9. Swipe between open containers

A horizontal fling on the container's bottom bar (back / forward / `N OPEN` /
☰) views the next or previous open container, in `2c`'s order (most recently
viewed first): a fling to the left the next one in that list, to the right the
previous. At either end nothing happens. Taps on the bar's buttons are
unchanged; a fling must travel at least the bar's height sideways, so a slightly
moving tap still taps. It switches in place, as a tap on a `2c` row does.

## 10. Testing

Widget tests: the tab bar (each tab shows its screen, back from Today/Settings
shows Sites, no back icon on a tab); chips (tap switches, long-press opens the
form, `+` opens a new one); list order; no titles or count; the jade `+` on an
empty workspace; the search field's rows and destinations with and without
proxies, saved hosts, Enter; the dashboard throwaway's back; the add-site
autofocus, workspace, name and route defaults; the default-route screen and
row value; the swipe (both directions, both ends, a tap still a tap). Unit
tests: `destinationFor`/`suggestionsFor` with no opener; the name rule; the
default route's storage and login rule. Device checks on the physical phone:
every tab, a dashboard search on direct and on a proxy, a refused proxy, the
swipe.

## 11. Known gaps

- Long-press on a chip is not discoverable; Settings ▸ Workspaces stays the
  visible way in.
- A throwaway opened from the dashboard does not appear on the dashboard's
  list (it is not a site); `N OPEN`, `2c` and the swipe reach it.
- Changing the default route does not move open throwaways.

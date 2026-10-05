# Inventory: blocks 1a–5c as the app builds them now

Read from `lib/ui/` on 2026-10-05. For each canvas block this file gives
where the code builds it, its layout and dimensions, every string it shows,
how it differs from the canvas, and sample data. When code and canvas differ,
**the code wins**, along with the later spec that changed it (Plans 12, 15,
16 and 18 in `docs/superpowers/specs/`). Strings are copied exactly. `<x>`
marks data put into a string; the rest of the string is literal. Middle dots
are `·` (U+00B7). The search row's quotes are curly (`“ ”`).

## Shared vocabulary

**Colour tokens (`lib/ui/core/tokens.dart`, `C.*`)**
- Surfaces: `bg #0F1113`, `bgPanic #0C0E10`, `surface #15181B`,
  `sheet #141719`, `raised #181B1E`, `button #1C2124`, `selected #20262A`,
  `monogramOpen #20252A`, `footer #111417`, `trackOff #232729`,
  `knobOff #4A5150`, `barTrack #1A1E21`, `handle #2C3134`.
- Hairlines (white at the given alpha): `line05` through `line16`, so
  `line06` = 6%, `line07` = 7%, and so on.
- Text: `textPrimary #E8E9E7`, `textSecondary #D7DCDA`,
  `textTertiary #B9BFBD`, `textMuted #8A918F`, `textFaint #6E7573`,
  `textDim #5F6664`, `textDisabled #4A5150`, `monogramText #C7CECC`,
  `icon #9AA1A0`, `tabInactive #767D7B`, `pillText #A9B0AE`.
- State: `jade #7FC8A9`, `jadeCode #9FD8C0`, `idleDot #3E4644`,
  `pinEmpty #3A403E`, `pinError #4A3634`, `danger #D66A5A`,
  `dangerMuted #8A6A62`, `warning #D6A45B` (amber).

**Type (`lib/ui/core/typography.dart`)**
- `ui()` is Figtree and `mono()` is IBM Plex Mono.
- Named styles:
  - `T.screenTitle` 16/600
  - `T.sheetTitle` 17/600, −0.17 tracking
  - `T.stepTitle` 22/600, −0.22 tracking
  - `T.appBarTitle` 15/600
  - `T.rowTitle` 14.5/500 primary, and `T.rowTitleIdle` 14.5/500 tertiary
  - `T.body` 14
  - `T.bodyMuted` 13 muted, 1.65 line height
  - `T.meta` 10.5 faint, and `T.metaIdle` 10.5 dim
  - `T.sectionLabel` 10/500, 1.0 letter-spacing, faint (uppercase strings)
  - `T.barBadge` 10.5/500, 0.63 spacing, faint
  - `T.code` mono 11.5, 1.9 line height, jadeCode

**Shared widgets**
- `Monogram`: 36×36, radius 10, 14/600 letters.
  - Open: `monogramOpen` fill with `monogramText`.
  - Idle: `raised` fill with `textMuted`.
- `StatusRail`: 3px wide, radius 2; jade when live, `line09` otherwise.
- `IconTap`: a line icon (`AppIcon`). Circular by default, or with a radius;
  the label goes to screen readers. With no tap handler it is dimmed to
  `textDisabled`.
- `AppToggle` and the form switches: 44×26 track, 20px knob.
  - On: jade track with a `bg` knob.
  - Off: `trackOff` track with a `knobOff` knob.
  - Inert: 40% opacity.
- `PillButton`: the label is 14.5.
  - `primary`: jade fill, `bg` text, weight 600.
  - `neutral`: `button` fill, `textSecondary` text, weight 500.
  - The radius defaults to height/2.
- `BottomSheetSurface`: `sheet` fill, top radius 22, 9% white top border,
  black 55% shadow (blur 40, y −20), optional 36×4 `handle`.
- `Hairline`: 1px `line06`.
- Line icons (`AppGlyph`): back, forward, reload, stop, shield, panic, menu,
  find, reader, link, search, globe, chevronUp, chevronDown, close, check,
  plus, more, vault, fingerprint, backspace, refused, contrast, sites, today,
  settings. Since Plan 17, no Unicode glyph (`‹ › × ⟳ ◑ ◉ ◇ ☉ ✓ ⋯ ▲ ⌫`) is
  drawn anywhere.

**Canvas sample data (the canvas's script)**

| Workspace | Mono | Name | Host · descriptor | Status (1a) | Age (1b) |
|---|---|---|---|---|---|
| Personal | Nt | Notes | notes.example.org · socks5 | Open · now | now |
| Personal | Wm | Webmail | mail.example.net · direct | Open · 14 min | 14m |
| Personal | Fr | Forum | forum.example.com · ephemeral | Idle · 2 h | 2h |
| Personal | Rd | Reader | read.example.io · direct | Idle · yesterday | 1d |
| Personal | Bk | Bank | bank.example.com · pin required | Idle · 3 d | 3d |
| Personal | Mk | Marketplace | shop.example.com · direct | Idle · 5 d | 5d |
| Work | Wk | Wiki | wiki.internal · socks5 | Open · 3 min | 3m |
| Work | Tk | Tickets | tickets.internal · direct | Idle · 1 h | 1h |
| Ephemeral | Sc | Scratch tab | wipes on exit | Open · now | now |

Workspace meta in the canvas menu reads "6 SITES · 2 OPEN", "2 SITES · 1
OPEN" and "WIPES ON EXIT". The app's own seed data (`app_database.dart`)
uses the same eight Personal and Work sites. The decoy sample (3b) is News
`news.example.com` 2d, Weather `weather.example.com` 4d, Recipes
`cook.example.org` 1w, and Timetable `transit.example.com` 2w.

---

## 1a — "Quiet grid — monogram tiles, one status line, badges only when they mean something"

- **Built by:** nothing. The design was never built. Plan 1 built 1b instead.
  The dashboard is now Plan 18's shell; see 1b.
- **Canvas (for reference only):** a top bar with `{wsName}` ▼, ⌕ and ⋯, a
  workspace menu (name, `meta`, ✓), monogram tiles with
  `PROXY`/`TEMP`/`LOCK` badges and an `Open · now` status line, and a
  `+ Add site` tile.
- **Which wins:** the code (Plan 18). No tile grid, badges or ⋯ exist.

## 1b — "Session list — grouped by what is running, technical meta in mono, one-handed reach"

**Superseded by Plan 18** (`docs/superpowers/specs/2026-10-03-dashboard-redesign-design.md`).
The canvas had a `Personal ▼` dropdown, `2 SESSIONS`, `OPEN NOW`/`IDLE`
headings and a `+ Add site` / ⌕ footer. The app replaces them with a shell of
three tabs (Sites · Today · Settings), workspace chips, one list with no
headings or counts, and a search field with a `+` button. The code wins.

**Files**
- `lib/ui/features/dashboard/views/dashboard_screen.dart` (the shell)
- `dashboard_tab_bar.dart`
- `sites_tab.dart`
- `dashboard_body.dart`
- `workspace_chips.dart`
- `session_row.dart`
- `dashboard_footer.dart`
- `empty_workspace.dart`
- `lib/ui/features/container/views/address_suggestions.dart` (the search
  overlay)
- View model: `dashboard/view_models/dashboard_view.dart`
- Meta descriptor: `lib/domain/models/site_descriptor.dart`
- Age: `lib/domain/models/relative_age.dart`

**Layout, top to bottom (Sites tab)**

Everything sits in a `Material` (`C.bg`), inside a `SafeArea`.

1. **Workspace chip row** (`WorkspaceChips`):
   - Padding is 10 top and bottom and 18 right. The chips scroll sideways
     inside, with 18 on the left and 8 on the right.
   - **Chip**: 32 high, 14px side padding, radius 16, text 12.5/500.
     - Selected: `C.selected` fill, `line10` border, `textPrimary` text.
     - Unselected: no fill, `line07` border, `tabInactive` text.
     - Chips are 8 apart. There is no jade.
   - **`+` IconTap** at the end: 32px, radius 16, `button` fill, 14px plus
     icon in `textMuted`.
   - **Badge**: on a wipe-on-exit workspace, `WIPES ON EXIT` (`T.barBadge`)
     is fixed at the right end.
   - A `Hairline` runs below the row.
   - Gestures: tap a chip to view that workspace, long-press to open `10b`,
     tap `+` to open the new-workspace form.
2. **Site list** (`ListView`, 6 top padding): one `SessionRow` per site.
   Open sites come first, then the rest, each group ordered by most recent
   visit. Each row:
   - `InkWell`, with a bottom border of `line05`. Padding is 18 on the sides
     and 12 top and bottom. It is a row of these pieces, in order:
   - `StatusRail` (3px wide, full row height; jade when the site is open).
   - A 12 gap, then a `Monogram` 36/r10 (the open or idle treatment).
   - A 12 gap, then a column:
     - The name, ellipsized: `T.rowTitle` when open, `T.rowTitleIdle` when
       idle.
     - A 3 gap, then the meta line: `T.meta` when open, `T.metaIdle` when
       idle. The meta is Figtree 10.5, not mono.
   - A 12 gap, then the age: 10.5 `textMuted` when open, `T.metaIdle` when
     idle.
   - Tap opens the site's container. Long-press opens the `7b` row menu.
   - Row height is about 60.
   - If the workspace is empty, the list's place shows `EmptyWorkspace`
     (see 5b).
   - **While the search field holds text**, `AddressSuggestions` covers the
     list (the chips and footer stay):
     - `C.bg` background.
     - Section labels (`T.sectionLabel`) with 16/14/16/6 padding.
     - Rows with 16 side padding, 10 top and bottom, and a `line06` bottom
       border. Each row has:
       - A 32/r9 monogram (12pt letters). An address or search row shows a
         32px `button` square, radius 9, holding a globe or search icon at
         15 instead.
       - The primary line: 13.5 `textPrimary`.
       - The secondary line: mono 10 `textFaint`.
       - A right-aligned tag: mono 9.5 `textMuted`, 1.35 line height, at
         most 96 wide, so it wraps.
     - The footer line is mono 10 `textDim`.
3. **Footer** (`DashboardFooter`):
   - A `Hairline`, then a `C.footer` band with padding 18/12/18/16.
   - **Search field**: 46 high, `button` fill, radius 14, 14 horizontal
     padding. Text is 13.5 `textPrimary`, the hint 13.5 `textFaint`, and the
     URL keyboard's action is "go".
   - A 10 gap.
   - **`+` IconTap**: 46×46, radius 14, 20 icon. It is `button` fill with an
     `icon`-coloured glyph. On an empty workspace it becomes a **jade fill
     with a `bg` glyph** (the screen's one affirmative action).
4. **Bottom tab bar** (`DashboardTabBar`):
   - `C.footer` fill, `line07` top border, `SafeArea` at the bottom.
   - Three equal items. Each has 8 top and bottom padding and a 20px icon,
     then a 4 gap, then the label at 10.5/500.
   - The viewed tab is `textPrimary`; the others are `textMuted`. No jade.
   - The bar is hidden while the keyboard is up.
   - Back on Today or Settings returns to Sites.

The loading state is a bare `C.bg` Scaffold. The error state is the raw
error text, centred.

**Strings, in order**
- Chips: `<workspace name>` (for example `Personal`, `Work`, `Ephemeral`)
- `WIPES ON EXIT` (only when the viewed workspace wipes on exit)
- Row name: `<site name>`
- Row meta: `<host> · <descriptor>`. The descriptor is one of `pin required`,
  `ephemeral`, `socks5`, `http`, `direct` or `tor`, checked in that order.
  Example: `forum.example.com · ephemeral`.
- Row age: `now`, `<n>m`, `<n>h`, `<n>d` or `<n>w`, or empty if the site was
  never visited.
- Search hint: `Search or type an address`
- Suggestions overlay:
  - Section labels: `SAVED SITES`, `ADDRESS`, `SEARCH`
  - Saved-site row: primary `<site name>`; secondary `<host> · <workspace
    name>` (or `<host>` alone); tag `ITS OWN CONTAINER`
  - Address row: primary `<typed text>`; secondary `not saved`; tag
    `THROWAWAY` or `THROWAWAY · <MODE>`, where the mode is `SOCKS5`, `HTTP`
    or `TOR` (from the default route). If the address matches a saved site,
    the tag is `ITS OWN CONTAINER`.
  - Search row: primary `Search <engine> for “<typed>”`, where the engine is
    `DuckDuckGo`, `Startpage` or `Brave Search`; secondary is the engine's
    host (`duckduckgo.com`, `www.startpage.com` or `search.brave.com`); the
    tag follows the same rule as the address row.
  - Footer: `Nothing is fetched while you type.`
- Tab bar: `Sites`, `Today`, `Settings`
- Screen-reader labels:
  - `New workspace` (the chip-row `+`)
  - `Add site` (the footer `+`)
  - Tab items read their visible label and are marked selected.
  - Rows have no extra label.

**Canvas differences**
- No `Personal ▼` dropdown, `2 SESSIONS` count, or `OPEN NOW`/`IDLE`
  headings.
- The canvas footer's `+ Add site` text pill and ⌕ button became a search
  field plus a `+` button.
- The canvas meta line is in mono; the code uses Figtree 10.5.
- A Plan 18 ruling forbids any session or leak count.

**Sample:** the Personal rows from the table above. Open first: Notes `now`
and Webmail `14m`. Then idle: Forum `2h`, Reader `1d`, Bank `3d` (meta
`bank.example.com · pin required`), Marketplace `5d`.

## 1c — "Live tiles — full-width rows for open sessions with a page preview, small tiles below"

- **Built by:** nothing. It is unbuilt and superseded by the Plan 18 Sites
  tab (see 1b).
- **Canvas (reference):**
  - `WORKSPACE` / `Personal ▼` / ⌕
  - A `LIVE` section of full-width "page preview" cards: monogram, name,
    meta, ×
  - A `SAVED` section of small tiles: monogram, name, time, and a `+` tile
- **Which wins:** the code. There are no page previews or tiles. Plan 15's
  `2c` lists open containers instead.

---

## 2a — "Add site — four tabs, all visible from the start"

**Files**
- `lib/ui/features/add_site/views/add_site_screen.dart`
- `basics_tab.dart`
- `network_tab.dart`
- `route_fields.dart` (shared with Settings ▸ Default route)
- `privacy_tab.dart`
- `appearance_tab.dart`
- `form_toggle_row.dart`

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`.

1. **Header row**, padding 18 on the sides and 12 top and bottom, laid out
   space-between:
   - A `close` IconTap (24px box, 20 icon).
   - The title at 15/600 `textPrimary`, ellipsized, with 12 side padding.
   - `Save` at 14/500 **jade**. It is at 40% opacity and inert while the
     address field is not a loadable web address.
2. **Tab strip**:
   - A `line07` bottom border, with 18 side padding.
   - Four equal tabs, each padded 4/11/4/10, with a 2px bottom border:
     jade on the active tab, transparent otherwise.
   - Labels are 12.5/500: `textPrimary` when active, `tabInactive` otherwise.
     They scale down rather than wrap.
3. **Body**: a `SingleChildScrollView` with 18 padding all round.
   - **Basics:**
     - Each section label is `T.sectionLabel`, followed by a 7 gap. Sections
       are 18 apart.
     - **Text fields**: 46 high, `surface` fill, radius 12, `line09` border,
       13 horizontal padding.
       - Address text: 13 `textSecondary`.
       - Name text: 14 `textSecondary`.
     - The name field ends with a 28×28 `monogramOpen` chip, radius 8, letters
       12/600 `monogramText`.
     - **Workspace chips**: 40 high, radius 11.
       - Selected: `selected` fill, `line10` border.
       - Unselected: `line07` border.
       - Text is 13, in `textPrimary` or `tabInactive`.
       - Up to three chips share the row equally. With four or more, the row
         scrolls sideways (each chip 72–220 wide).
     - **Cookies group**: radius 12, `line08` border. Two rows, each with
       `surface` fill and 13 padding:
       - The title is 13.5: `textPrimary` when selected, `textTertiary`
         otherwise.
       - The subtitle is 11 `textFaint`.
       - A 16px radio sits on the right. Selected: a 5px jade ring. Otherwise
         a 1.5px `pinEmpty` ring.
   - **Network** (`RouteFields`, then two toggles):
     - Every `FormToggleRow` has a 14 `textPrimary` title, a 3 gap, an 11
       `textFaint` subtitle, and a 44×26 switch.
     - Mode chips: three of them (SOCKS5, HTTP, Tor), 40 high, radius 11,
       12/500 text, 8 apart.
     - HOST and PORT sit side by side, split 2:1 with a 10 gap. Their fields
       are 46 high and use mono 13 `textSecondary`.
     - Tor replaces HOST and PORT with one line of 12.5 `textMuted` (1.5 line
       height).
     - USERNAME and PASSWORD (mono, password masked) show only while the
       proxy is on and "Separate login per site" is off.
     - Spacing is 18 between blocks, and 14 between the last two toggles.
   - **Privacy:**
     - Section labels have 12 below them. `SHIELDS` has 22 above it.
     - Bare rows have 14 top and bottom padding and a `line06` top border.
       The title is 14 `textPrimary` with a switch.
     - Detailed rows add an 11 `textFaint` subtitle.
   - **Appearance:**
     - User-agent chips: three equal chips, 40 high, radius 11, all with a
       `line08` border. The selected chip has `selected` fill. Text is 13.
     - The `Page zoom` value is 12/500 jade.
     - The slider (50–200) has a 3px track: jade active, `trackOff` inactive,
       with a `textPrimary` thumb.
     - Code boxes: `surface` fill, radius 12, `line09` border, 12 padding, at
       least 3 lines.
       - CSS: mono 11.5 at 1.6 line height, `jadeCode`.
       - JS: Figtree 11.5, `textFaint`.

**Strings, in order**
- Header:
  - Title: `Add site` for a new site or a throwaway being saved. When editing
    a saved site, its `<site name>` (its host if the name is blank).
  - `Save`
- Tabs: `Basics`, `Network`, `Privacy`, `Appearance`
- Basics:
  - `ADDRESS`, then the field's `<url>`. A new site's field starts empty with
    no hint, and the keyboard is up.
  - `NAME`, then the field's `<name>`, then the chip's `<monogram>`. The
    monogram is suggested as the first letter plus the next consonant
    (Forum → `Fr`).
  - `WORKSPACE`, then the chips' `<workspace names>`
  - `COOKIES`:
    - `Keep for this site` / `Stays signed in, isolated from other sites`
    - `Wipe on exit` / `Cookies, cache and form history destroyed`
- Network:
  - `Route through proxy` / `This site only`
  - `SOCKS5`, `HTTP`, `Tor`
  - `HOST` (default `127.0.0.1`) and `PORT` (default `9050`)
  - Tor only: `Through the Tor network. Each site gets its own circuit.`
  - While the proxy is on: `Separate login per site` / `Tor gives this site
    its own circuit`
  - When per-site login is off: `USERNAME` and `PASSWORD`
  - `Block WebRTC` / `Prevents real IP leaking past the proxy`. On Tor it is
    locked on and drawn inert.
  - `Block trackers and ads`. The subtitle is `Local filter lists` for a new
    site or a throwaway, `Local filter lists · 1 rule matched today`, or
    `Local filter lists · <n> rules matched today`.
- Privacy:
  - `HARDWARE · ALL OFF BY DEFAULT`
  - `Camera`, `Microphone`, `Location`, `Clipboard`
  - `SHIELDS`:
    - `Anti-fingerprinting` / `Noise for canvas, WebGL and audio readouts`
    - `Ask for PIN before opening` / `Biometric accepted`
    - `Show in decoy vault` / `Visible when the second PIN is used`
- Appearance:
  - `USER AGENT`: `Android`, `Desktop`, `Minimal`
  - `Force dark mode` / `For sites with no dark theme`
  - `Open in reader mode`
  - `Page zoom`, with the value `<n>%` (default `100%`)
  - `CUSTOM CSS` (the box is empty, no hint)
  - `CUSTOM JS` (empty-box hint: `Runs at document start`)
- Screen-reader labels: `Close` (the ×).

**Canvas differences**
- The canvas's user-agent choices are `Mobile` / `Desktop` / `Custom`; the
  code has `Android` / `Desktop` / `Minimal`.
- The canvas has no Tor chip, Tor line, login fields or "Separate login"
  (Plans 14 and 19 added them).
- The canvas's "42 rules matched today" was example data; the user ruled the
  real count is shown.
- The canvas's `Page zoom 110%` is example data; the code defaults to 100%.
- The canvas's CSS example is `header, .ads-banner {` / `display: none
  !important;` / `}`. The code shows no example.
- The edit form's title (the site's name) is a 2026-10-05 ruling.
- The code wins.

**Sample:** address `https://forum.example.com`, name `Forum`, monogram
`Fr`, workspaces `Personal` / `Work` / `Ephemeral`, proxy SOCKS5
`127.0.0.1` : `9050`.

## 2b — "Isolated container — minimal top bar, panic button always reachable"

**Superseded by Plan 12, "layout C"**
(`docs/superpowers/specs/2026-09-28-browser-chrome-design.md`), with later
changes from Plans 15, 16 and 18 and a 2026-10-05 ruling that put reload in
the pill. The canvas had a ‹ / pill / ⟳ / ◉ top bar and a floating bottom pill
holding ◑ ≡ `3 OPEN ▲` ☰ ⋯. The code wins.

**Files** (all in `lib/ui/features/container/views/`)
- `container_screen.dart`
- `container_top_bar.dart`
- `panic_square.dart`
- `load_line.dart`
- `container_bottom_bar.dart`
- `address_edit_bar.dart`
- `address_suggestions.dart`
- `find_bar.dart`
- `throwaway_save_bar.dart`
- `browser_menu_sheet.dart` (☰)
- `new_identity_sheet.dart`
- The wiring is in `container_route.dart`.
- Route labels come from `lib/domain/models/route_display.dart`.

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`.

1. **Top bar** (`ContainerTopBar`): padding 12 on the sides and 8 top and
   bottom, with a `line07` bottom border.
   - **Pill**: fills the width, 34 high, `surface` fill, radius 17, `line08`
     border, padding 12 left and 3 right. Inside it, in order:
     - A 6px dot: jade when the site is live, `warning` (amber) while it is
       opening.
     - A 7 gap, then the host at 11.5 `pillText`, ellipsized.
     - If the route isn't direct: an 8 gap, then the route label at
       9.5/500 `textFaint`.
     - A `reload` IconTap (28 box, 14 icon). While the page loads it is a
       `stop` IconTap instead.
     - A `shield` IconTap (28 box, 15 icon), which opens `6c`.
     - A tap anywhere else on the pill switches to the address edit bar.
   - An 8 gap.
   - **Panic square**: 32×32, radius 9, `danger` at 14% fill, 16px
     `danger` panic icon.
2. **Page area** (the WebView):
   - A **load line** is overlaid on its top edge: 2px high, `textMuted`, its
     width the load fraction, drawn only while the page loads. Not jade.
3. **Throwaway save bar**: only for a throwaway, after its first load.
   - `raised` fill, `line07` top border, padding 16/8/8/8.
   - The text is 12 `textMuted`, at most 2 lines.
   - A neutral `PillButton` 32 high with 14 side padding.
   - A `close` IconTap (36 box, 16 icon).
4. **Bottom bar** (`ContainerBottomBar`):
   - `footer` fill, `line07` top border, padding 16 on the sides and 4 top
     and bottom. Items are spread space-between:
     - `back` and `forward` IconTaps: 40px round, 20 icon, dimmed when there
       is no history that way.
     - A centre pill: 34 high, 14 side padding, `selected` fill, radius 17.
       The text is 11/500 `textSecondary`, followed by a 7 gap and a 12px
       **jade** chevronUp. Tapping it opens `2c`.
     - A `menu` IconTap that opens ☰.
   - A horizontal fling at least as long as the bar is high switches to the
     next or previous open container.
5. **Address edit mode** replaces the top bar.
   - Same padding as the top bar, but the pill is `raised` with a `line16`
     border.
   - The text field is 13 `textPrimary`; the hint is 13 `textFaint`.
   - A clear × (28 box, 14 icon, `textMuted`).
   - Panic stays on the right.
   - `AddressSuggestions` covers the page and the bottom bar; it is the same
     overlay as on the dashboard (see 1b).
6. **Find mode** replaces the top bar.
   - The pill is `raised` with a `line16` border. A count sits at its right
     (mono 10.5 `textMuted`).
   - Next to it, at 32 boxes: chevronUp and chevronDown (18 icons) and a
     close × (16 icon).
   - Then panic.
7. **☰ sheet** (`BrowserMenuSheet`):
   - `BottomSheetSurface` with a handle, padding 0/10/0/12. Scroll-controlled
     and inside the safe area.
   - **Header**: padding 18/0/18/14, a `line06` bottom border. A `Monogram`
     36, a 12 gap, then the name at 15/600 and the subtitle in mono 10.5
     `textFaint`.
   - **Four tiles**: padding 8 on the sides and 14 top and bottom, with a
     `line06` bottom border. Each tile is a 44×44 `button` square (radius
     13) holding an icon, then a 7 gap and an 11 `textTertiary` label.
   - **Rows**: padding 18 on the sides and 14 top and bottom, with a `line05`
     divider. The label is 14 `textPrimary`. The right side shows mono 10.5
     `textFaint` meta, or else a 14px `forward` chevron. The last row has no
     divider.
8. **New identity sheet** (from ☰):
   - `BottomSheetSurface`, padding 20/22/20/20.
   - The title is 17/600.
   - The body is `T.bodyMuted`.
   - A `SheetGroup` (radius 16, 8% border) holding one row with a `danger`
     label.
   - A `Cancel` pill, 50 high.

**Strings, in order**
- Pill: `<page host>`, then the route label: `SOCKS5`, `HTTP` or `Tor`, or
  nothing at all for a direct site (there is never a `DIRECT` label).
- Throwaway save bar: `Not saved · wiped when you close it`, `Save as a site`
- Bottom pill: `<n> OPEN`. `<n>` counts every open container in the vault,
  throwaways included.
- Address edit hint: `Search or type an address`. The overlay's strings are
  the same as on the dashboard. Inside a container, a saved-site row can also
  be tagged `THIS CONTAINER`.
- Find bar: hint `Find in page`; count `<active>/<total>` (for example
  `2/14`) or `No matches`
- ☰ sheet:
  - Header: `<site name>`; subtitle `<host> · <workspace name>` (a
    throwaway's subtitle is `<host>` alone, and its name is also its host)
  - Tiles: `Reload`, `Find`, `Reader`, `Copy link`
  - Rows:
    - `Security level`, with meta `STANDARD`, `SAFER` or `SAFEST`
    - `New identity`
    - `Today`, with meta `<n> BLOCKED`
    - `Scripts and filters`
    - `Workspaces`
    - `Settings`
    - `All sites`
- New identity sheet: `New identity for this site?` / `Its logins, storage
  and downloads are destroyed, and it starts over at its first page.` / `New
  identity` / `Cancel`
- Screen-reader labels:
  - `Stop` or `Reload`
  - `Site details` (the shield)
  - `Panic`
  - `Clear` (the edit bar's ×)
  - `Back`, `Forward`
  - `Open sessions` (the `N OPEN` pill)
  - `Menu`
  - `Previous match`, `Next match`, `Close find`
  - `Dismiss` (the save bar's ×)

**Canvas differences**
- The ‹ in the top bar was removed; back is on the bottom bar.
- ⟳ moved inside the pill and became reload or stop.
- The shield opens `6c`.
- The canvas's floating bottom pill (◑ ≡ ▲ ☰ ⋯) is now a flat bar: back /
  forward / `N OPEN ▲` / ☰.
- ◑ (reader) and ≡ (find) moved into the ☰ sheet.

**Sample:** `forum.example.com`, `SOCKS5`, `3 OPEN`. ☰ header: `Fr`, `Forum`,
`forum.example.com · Personal`. Today meta, for example `312 BLOCKED`.

## 2c — "Quick switcher drawer — thumb height, wipe and panic in the same sheet"

**Files**
- `lib/ui/features/container/views/switcher_sheet.dart`
- Entries come from `lib/domain/tabs.dart` (`switcherEntries`,
  `backgroundAge`).
- Rewritten by Plan 15 (tabs) and restyled by Plan 17.

**Layout**

The sheet is a modal bottom sheet with a 32% black barrier.

- **Container**: `sheet` fill, `line09` top border, top radius 22, padding
  0/10/0/16.
- **Handle**: 36×4 `handle`, radius 2, with 12 below it. The handle stays
  fixed; the rest scrolls.
- **Header row**: padding 18/0/18/10.
  - Left: the count, 10/500, 1.0 letter-spacing, **jade**.
  - Right: the workspace name in capitals, 10/500, 0.6 spacing, `textFaint`,
    ellipsized.
- **Container rows**: padding 18 on the sides, 14 above (0 for the first
  row) and 14 below. In order:
  - A rail, 3×38, radius 2: jade for the viewed container, jade at 45% for
    the others.
  - A 12 gap, then a `Monogram` 36 (open treatment).
  - A 12 gap, then the name at 14.5/500 `textPrimary` and the meta at 10.5
    `textFaint` (Figtree).
  - A `close` IconTap: 24 box, 16 icon, `textFaint`.
- **Page rows**: only when a container has two or more pages.
  - Indented to the text column (left padding 81), with 12 below.
  - The title is 13/500: `textPrimary` for the current page, `textMuted`
    otherwise.
  - The host is mono 10.5 `textFaint`.
  - A × on the right. No rail, no jade.
- A `Hairline` sits only between container groups.
- **Action row**: padding 18/16/18/0.
  - A **`Close all and wipe`** button: fills the width, 46 high, `button`
    fill, radius 14, text 13.5/500 `textSecondary`.
  - A 10 gap.
  - A **panic button**: 46×46, radius 14, `danger` at 14% fill, `danger`
    border at 30%, an 18px `danger` panic icon.
- There is no confirmation for either action.

**Strings**
- `<n> OPEN SESSIONS`. It is always plural (`1 OPEN SESSIONS`), and `<n>`
  counts every listed container.
- `<WORKSPACE NAME>`: the viewed container's workspace in capitals. It is
  empty when the viewed container is a throwaway.
- Container row: `<site name>` (a throwaway shows its host), then
  `viewing now · <route>` or `background · <age>`:
  - `<route>` is `socks5`, `http`, `direct` or `Tor`.
  - `<age>` is `now`, `<n> min` or `<n> h`.
- Page row: `<page title>` (its host if it has no title), then `<page host>`.
- `Close all and wipe`
- Screen-reader labels: `Close` (every row ×) and `Panic`.

**Canvas differences**
- Plan 15 changed this:
  - It lists **every** open container in the vault: the viewed one first,
    then the rest by most recent view.
  - Pages are nested under their container.
  - Each row taps to switch.
- The canvas's rail for background rows is the same jade at 45%.
- The code wins.

**Sample (the canvas):** `3 OPEN SESSIONS` / `PERSONAL`:
- Fr Forum `viewing now · socks5`
- Nt Notes `background · 2 min`
- Wm Webmail `background · 14 min`

## 2d — "Settings — lock, vault and panic behaviour"

**Files**
- `lib/ui/features/settings/views/settings_screen.dart`
- Wiring: `settings_route.dart`
- Pickers: `auto_lock_picker.dart`, `search_engine_picker.dart`,
  `security_level_picker.dart`, `default_route_screen.dart`
- Row widget: `lib/ui/core/widgets/setting_row.dart`

It appears in two places: as the dashboard's **Settings tab** (no back icon),
and pushed from ☰ (with a back icon).

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`.

1. **Header**: padding 18/14/18/12.
   - An optional `back` IconTap (20 box, 18 icon), then a 10 gap.
   - `Settings` in `T.screenTitle`.
   - A 1px `line06` divider below.
2. **List**: a `ListView` with 18 padding.
   - Section labels are `T.sectionLabel`; 24 separates sections.
   - **`SettingRow`**: an `InkWell` with a `line06` bottom border and 15 top
     and bottom padding.
     - The title is `T.body` (14). The subtitle, if any, is 11 `textFaint`.
     - The right side holds one of:
       - an `AppToggle`
       - a value, 12.5 `textMuted`, end-aligned (mono 12 for a proxy
         address)
       - a 16px `forward` chevron in `textFaint` when the row only navigates
   - The **footer note** is 11 `textDim` at 1.6 line height, with 22 above.
3. **Picker sheets** (Auto-lock, Search engine, Security level):
   - `BottomSheetSurface` with a handle, padding 0/10/0/18.
   - The title is `T.sheetTitle`, padded 18/0/18/12.
   - Rows: padding 18 on the sides and 15 top and bottom (13 for security
     level), with a `line05` top border. The text is 14.5 `textPrimary`.
     Security level adds a 12 `textFaint` second line.
   - The chosen row shows a 15px **jade** check.
4. **Default route screen**:
   - The same header as Settings, with `Default route`.
   - Below it, `RouteFields` (see 2a's Network tab), but the
     "Route through proxy" switch has no subtitle.

**Strings, in order**
- `Settings`
- `LOCK`:
  - `Unlock with biometrics` / `PIN always available as fallback` (a toggle,
    inert at 40% when biometrics are unavailable)
  - `Auto-lock`, with the value `After 1 min`, `After 5 min` or `After 15 min`
  - `Change main PIN` (›)
- `MANAGE`:
  - `Workspaces` (›)
  - `Scripts and filters` (›)
- `BROWSING`:
  - `Search engine`, with the value `DuckDuckGo`, `Startpage` or `Brave
    Search`
  - `Default route`, with the value `Direct`, `Tor`, `SOCKS5 · <host>:<port>`
    (mono) or `HTTP · <host>:<port>` (mono)
  - `Security level`, with the value `Standard`, `Safer` or `Safest`
- `VAULT` (shown only when a decoy is configured):
  - `Decoy vault` / `A second PIN opens a harmless board` (toggle on, inert)
  - `Sites shown in decoy`, with the value `<n> selected` (it opens
    Workspaces)
  - `Re-sync decoy now` (›)
  - `Hide from app switcher` / `Blurs previews, blocks screenshots` (toggle
    on, inert)
- `PANIC`:
  - `Trigger by flipping face down` / `Uses the accelerometer` (toggle, off by
    default)
  - `On panic`, with the value `Wipe + lock` (no chevron, inert)
- `Nothing leaves this device. There is no account and no sync.`
- Auto-lock sheet: `Auto-lock` / `After 1 min`, `After 5 min`, `After 15 min`
- Search engine sheet: `Search engine` / `DuckDuckGo`, `Startpage`, `Brave
  Search`
- Security level sheet (vault):
  - `Security level`
  - `Standard` / `Every site feature is on`
  - `Safer` / `JavaScript off on http pages · no WebGL or WebAssembly`
  - `Safest` / `JavaScript and images off on every page`
  - The per-site version (from ☰ / `6c`) first adds `Default` / `<Level> ·
    set in Settings`.
- Default route screen: `Default route`, then the RouteFields strings from 2a
  without `This site only`.
- Screen-reader labels: `Back`.

**Canvas differences**
- `MANAGE` and `BROWSING`, and the `Re-sync decoy now` row, are additions
  from Plans 6, 9, 12, 16 and 18.
- The canvas shows the VAULT section unconditionally; the code shows it only
  when a decoy exists.
- As a tab, the header has no ‹.
- The code wins.

**Sample:** biometrics on, `After 1 min`, `DuckDuckGo`, `Direct` (or `SOCKS5 ·
127.0.0.1:9050`), `Standard`, `4 selected`, `Wipe + lock`.

---

## 3a — "Lock — one PIN field, no mention of vaults"

**Files**
- `lib/ui/features/lock/views/lock_body.dart` (mood `normal`); the same file
  also builds 4c, 9b and 9c.
- `lock_screen.dart`
- `lib/ui/core/widgets/pin_dots.dart`, `pin_keypad.dart`, `pin_layout.dart`

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`, with 28 horizontal
padding. `PinLayout` arranges it:
- **Portrait**: a scrolling message column, centred, with the keypad below.
- **Landscape**: the message on the left, a 28 gap, then the keypad column
  (280 wide) on the right.

The pieces:
- **Mark**: 44×44, radius 13, `line12` border, a 20px **jade** `vault` icon.
- 26 gap, then the headline: 14 `textMuted`, centred.
- 26 gap, then **PIN dots**: six of them, each 11px, 14 apart, with a 1.5
  border.
  - Filled: `textPrimary` fill and border.
  - Empty: `pinEmpty` border.
- **Keypad**: at most 280 wide, a 3×4 grid with 14 gaps (8 vertical below
  640 high). The cells are circles, 64 high (52 when compact), with `surface`
  fill and an ink splash.
  - Digits are 22 `textSecondary`.
  - The bottom-left cell is blank.
  - Bottom right is a 24px `backspace` icon.
- No fingerprint prompt on a cold lock. It shows only in `9b`, beneath the
  keypad: a 28px jade fingerprint icon, then `Use fingerprint` at 12
  `textFaint`, with 26/30 padding.

**Strings**
- `Enter your PIN`
- Keypad: `1`–`9` and `0`
- Screen-reader label: `Delete` (backspace)
- `Use fingerprint` appears only in 9b, never here.

**Canvas differences**
- The canvas 3a shows `☉ Use fingerprint` under the keypad. The code never
  shows it on a cold lock (biometric unlock is resume-only, by design).
- ◇ was replaced by the `vault` line icon.
- The code wins.

## 3b — "Decoy vault — same shell, ordinary content, no privacy language"

- **Built by:** the same dashboard as 1b (`DashboardScreen` / `SitesTab`).
  There is no decoy-specific code anywhere. The decoy vault is just a second
  vault, rendered by identical widgets.
- **Layout and strings:** exactly 1b's: the workspace chips (an empty decoy
  gets a `Personal` workspace), the rows, `Search or type an address`, `+`,
  and the `Sites` / `Today` / `Settings` tab bar.
- **Canvas differences:**
  - The canvas's `Personal ▼` and `4 SITES` bar is gone, as on 1b.
  - Like every row now, the decoy rows show `<host> · <descriptor>` meta. So
    a decoy site reads, for example, `news.example.com · direct`, where the
    canvas showed the host only.
  - The code wins: identical rendering is a requirement of the threat model.
- **Sample:**
  - News `news.example.com` 2d
  - Weather `weather.example.com` 4d
  - Recipes `cook.example.org` 1w
  - Timetable `transit.example.com` 2w
  - All idle, with monograms `Nw`, `Wt`, `Rc`, `Tt`.

## 3c — "Panic — no confirmation dialog, it just happens and reports after"

**File:** `lib/ui/features/panic/views/panic_screen.dart`

**Layout**

The screen is a `Scaffold` (`C.bgPanic` #0C0E10) inside a `SafeArea`. A
`CenteredScroll` with 34 horizontal padding holds a centred column:
- **Mark**: a 52px circle with a `danger` border at 35%, holding a 20px
  `danger` panic icon.
- 30 gap, then the title at 18/600 `textPrimary`.
- 10 gap, then the body: 13 `textMuted`, centred, 1.6 line height.
- 30 gap, then a **status list**:
  - It has a `line07` border and radius 14, and is clipped.
  - Three rows, each with `sheet` fill and padding 14 on the sides and 12 top
    and bottom. Rows are separated by 1px gaps.
  - The label is 11.5 `textMuted`; the state is 11.5/500 **jade**,
    right-aligned.
- 30 gap, then an `Unlock` pill: neutral tone (`button` fill, `textSecondary`
  text), 48 high, full width.

**Strings**
- `Everything closed`
- `<n> sessions destroyed, temporary storage wiped, app locked.` (`1 session
  destroyed, …` when n = 1)
- `WEBVIEWS` → `DESTROYED`
- `EPHEMERAL DATA` → `WIPED`
- `MEMORY` → `CLEARED`
- `Unlock`

**Canvas differences**
- The canvas has `WEBVIEWS DESTROYED` and the other two lines as single
  strings; the code splits each into a label and a jade state.
- ◉ was replaced by the panic line icon.
- Otherwise it matches. Sample: `3 sessions destroyed, …`.

---

## 4a — "Setup — main PIN, three steps, no account"

**Files**
- `lib/ui/features/setup/views/setup_pin_screen.dart`
- `lib/ui/core/widgets/step_progress.dart`
- Flow: `lib/ui/features/shell/views/setup_flow.dart`
- The same screen is reused for the decoy PIN (step bar still at 1) and for
  Settings ▸ Change main PIN (no step bar).

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`, with 28 horizontal
padding. `PinLayout` arranges it, start-aligned:
- **Step bar**: 18 above it. Three segments, each 3 high, 6 apart, radius 2:
  jade for each segment up to the current step, `trackOff` for the rest.
  Step 1 means one jade segment.
- **Message** (vertically centred, left-aligned):
  - The title in `T.stepTitle` (22/600).
  - 14 gap, then the body: 14 `textMuted`, 1.65 line height.
  - 26 gap, then the PIN dots (left-aligned). When the confirmation doesn't
    match, the dots show the error state.
  - An optional notice: 16 above it, 14 `danger`.
- **Keypad**: as in 3a.
- **Continue**: padding 20 above and 26 below.
  - 50 high, radius 25.
  - Disabled (fewer than 6 digits): `button` fill, `textDim` text at 15/500.
  - Enabled: **jade** fill, `bg` text at 15/600.

**Strings**
- `Choose a PIN`
- `Six digits. It encrypts everything stored on this device. There is no
  account and no way to recover it, so pick something you will remember.`
- `Continue`
- Notice, only on the decoy-PIN step when the decoy PIN equals the main PIN:
  `Choose a different PIN`
- Screen-reader label: `Delete`

**Canvas differences:** the canvas has the same copy. The code adds the
notice line and landscape layout, and reuses this screen for the decoy PIN
because no dedicated canvas screen exists.

## 4b — "Setup — the decoy, explained once and never again"

**File:** `lib/ui/features/setup/views/setup_decoy_screen.dart`

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`, with 28 horizontal
padding.
- `StepProgress(step: 2)`: two jade segments.
- A centred, scrolling column, left-aligned:
  - The title in `T.stepTitle`.
  - 16 gap, then the body: 14 `textMuted`, 1.65 line height.
  - 22 gap, then a **group**: a `line08` border, radius 14, clipped. It holds
    two `surface` rows with 14 padding, separated by a 1px gap:
    - Row 1: `T.body` text with an `AppToggle`. Tapping anywhere on the row
      toggles it.
    - Row 2: `T.body` text, an 11.5 `textFaint` subline, and a 16px
      `forward` chevron in `textFaint`. This row is **inert**: it has no tap
      handler.
- Bottom, with 26 padding below:
  - A **`Continue`** pill: primary (jade), 50 high, full width.
  - 12 gap, then **`Skip for now`**: a 44-high tappable line, 14
    `textMuted`.

**Strings**
- `A second PIN, if you want one`
- `If someone makes you unlock the app, this PIN opens a plain board with
  only the sites you choose. Nothing on it hints that anything else exists.`
- `Set up a decoy PIN`
- `Sites to show` / `Pick after setup`
- `Continue`
- `Skip for now`

**Flow:**
- With the decoy on, Continue goes to the decoy-PIN step (the 4a screen
  again), then to 5a.
- With the decoy off, Continue and Skip both go straight to 5a.

**Canvas differences:** none in the copy. `›` is now the `forward` icon.

## 4c — "Wrong PIN — counts down without naming what is behind it"

**File:** `lib/ui/features/lock/views/lock_body.dart` (mood `wrong`).

**Layout:** the same as 3a, with these changes:
- The mark's border is `danger` at 30%, and its icon is `danger`.
- The headline is 14 **`danger`**.
- The dots are cleared and their borders are `pinError` (#4A3634).
- A footnote follows the dots: 26 above it, at most 250 wide, 12.5
  `textFaint`, 1.6 line height, centred.

**Strings**
- `Wrong PIN · <n> tries left` (`Wrong PIN · 1 try left` when n = 1; `<n>`
  is 0 once the lockout repeats)
- `After 5 wrong tries the app waits 30 seconds before accepting another.`
- Keypad digits, and the `Delete` label

**Canvas differences**
- The canvas shows `☉ Fingerprint unavailable` under the keypad. The code has
  no such string and shows nothing there.
- The code wins; that string is absent from the app.
- Sample: `Wrong PIN · 3 tries left`.

---

## 5a — "Setup step 3 — the defaults, stated plainly"

**File:** `lib/ui/features/setup/views/setup_defaults_screen.dart`

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`, with 28 horizontal
padding.
- `StepProgress(step: 3)`: all three segments jade.
- A scrolling column:
  - 40 gap, then the title in `T.stepTitle`.
  - 18 gap, then the body: 14 `textMuted`, 1.65 line height.
  - 20 gap, then four rows. Each has a `line06` top border and 14 top and
    bottom padding, and is laid out as:
    - A 16px **jade** `check` icon.
    - A 12 gap, then the title in `T.body` and a 3 gap.
    - The detail at 12 `textFaint`, 1.5 line height.
- Bottom, with 26 padding below: a primary (jade) pill, 50 high, full width.
  Tapping it finishes setup and opens the dashboard; it doesn't open the
  add-site form.

**Strings**
- `How sites will behave`
- `These apply to every site you add. You can change any of them per site
  later.`
- `Each site gets its own storage` / `Cookies and logins never cross between
  sites`
- `Camera, mic, location and clipboard blocked` / `A site has to ask you each
  time it wants one`
- `Trackers, ads and WebRTC blocked` / `Some sites may need this relaxed to
  work`
- `Nothing is sent anywhere` / `No account, no sync, no analytics`
- `Add your first site`

**Canvas differences:**
- The copy matches the canvas.
- The ✓ is now the `check` line icon.
- Jade appears in the step bar, the four checks and the button. That is more
  than one jade element; the canvas does the same.

## 5b — "Empty workspace — one sentence and one action"

**Files**
- `lib/ui/features/dashboard/views/empty_workspace.dart`, shown in the list
  area of `DashboardBody`.
- The footer `+` turns jade (`dashboard_footer.dart`, `emphasise`).

**Layout** (within the 1b shell: chips, then this, then the footer, then the
tab bar)
- Centred, with 40 horizontal padding:
  - A dashed rounded square: 40×40, radius 12, 1px `line16`, in 4px dashes
    with 4px gaps.
  - 16 gap, then the title at 15/500 `textTertiary`.
  - For a wipe-on-exit workspace only: a 16 gap, then the sentence at 13
    `textFaint`, centred, 1.65 line height.
- The chip row shows `WIPES ON EXIT` at its right end for a wipe-on-exit
  workspace.
- The footer `+` (46×46, radius 14) has a **jade fill** with a `bg` plus. The
  search field is never jade.

**Strings**
- `<workspace chips>` … `WIPES ON EXIT` (a wipe-on-exit workspace only)
- `Nothing here yet`
- `Sites you open in this workspace leave nothing behind when you close the
  app.` (a wipe-on-exit workspace only; a keep-storage workspace shows the
  title alone, by the 2026-10-05 ruling)
- `Search or type an address`
- Labels: `Add site`, `New workspace`
- Tabs: `Sites`, `Today`, `Settings`

**Canvas differences:**
- The canvas has `Ephemeral ▼` / `WIPES ON EXIT` in a top bar, and a
  `+ Add site` text pill with ⌕.
- The code (Plan 18) uses chips and a jade `+` button instead.

**Sample:** the `Ephemeral` workspace.

## 5c — "Today — a quiet log, not a dashboard of scary numbers"

**Files**
- `lib/ui/features/report/views/today_screen.dart`
- `today_route.dart`
- Data: `lib/domain/models/blocked_tally.dart` and
  `lib/domain/services/blocked_tally_recorder.dart`

It appears in two places: as the dashboard's **Today tab** (no back icon), and
pushed from ☰ ▸ Today (with a back icon).

**Layout**

The screen is a `Scaffold` (`C.bg`) inside a `SafeArea`.
1. **Header**: padding 18/14/18/12, a `line06` bottom border.
   - An optional `back` IconTap (20/18), then a 10 gap.
   - `Today` in `T.screenTitle`.
2. **List**: a `ListView` with padding 18/20/18/20.
   - **Total block**: 22 below it, a `line06` bottom border.
     - The number is 34/600 `textPrimary`, −0.68 tracking.
     - 8 gap, then the caption at 13.5 `textMuted`.
   - **Category bars**: 20 top and bottom padding, a `line06` bottom border.
     Each row has 14 below it:
     - A 110-wide label, 13 `textTertiary`.
     - A bar: 6 high, `barTrack` track, radius 3. Its fill is **jade**, but
       **`warning` (amber)** for Permission asks. The fill's width is the
       count divided by the largest count.
     - A 34-wide count, right-aligned, 12.5/500 `textMuted`.
   - Only categories with a count above 0 appear, in the order they were
     first recorded.
   - **`BY SITE`** label: 10.5/500, 1.05 letter-spacing, `textFaint`, padding
     0/20/0/4.
   - **Site rows**: 14 top and bottom padding, a `line05` bottom border.
     - A `Monogram` 32/r9 at 12.5, in the idle treatment.
     - An 11 gap, then the name at 14 `textSecondary`.
     - The count on the right, 12.5/500 `textMuted`.
     - Sites are listed in the order they were first recorded, not sorted.
   - 20 gap, then the footnote: 12 `textDim`, 1.6 line height.

**Strings**
- `Today`
- `<total>` (for example `312`)
- `<requests|request> blocked across <n> <sites|site>`. Examples: `requests
  blocked across 4 sites`, `request blocked across 1 site`.
- Category labels: `Trackers`, `Ads`, `Fingerprinting`, `Permission asks`,
  each followed by `<count>`
- `BY SITE`
- `<site name>` with `<count>`, plus the monogram
- `Counts are kept in memory only and reset when the app closes.`
- Screen-reader label: `Back` (pushed version only)

**Canvas differences:**
- The canvas has a ‹ in the header; the tab version has none.
- An empty or zero category is omitted. The canvas shows all four.
- Otherwise the copy matches.

**Sample (the canvas):** `312` / `requests blocked across 4 sites`.
- Categories: Trackers 198, Ads 88, Fingerprinting 24, Permission asks 2.
- BY SITE: Fr Forum 164, Mk Marketplace 97, Rd Reader 39, Wm Webmail 12.

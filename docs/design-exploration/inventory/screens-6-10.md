# Screen inventory — canvas blocks 6a to 10e (current app)

What the app builds **now** (Dart under `lib/ui/`, read 2026-10-05) for canvas
blocks `6a 6b 6c 7b 7c 8a 8b 8c 9a 9b 9c 10a 10b 10c 10d 10e`. The canvas file
is `Sandbox Container -canvas-.dc.html`. Later plans and specs (Plan 16's
privacy controls, Plans 14 and 19's failures, Plan 17's icons, and the
2026-09-30 and 2026-10-05 rulings) override it where they say so. Where the code
and the canvas differ and no later ruling covers the difference, this file
says so.

Strings appear in `code font` exactly as the code renders them, curly quotes,
middots (`·`) and apostrophes included. `<x>` marks a data-built part.

## Shared vocabulary

Tokens are in `lib/ui/core/tokens.dart` (`C.*`) and
`lib/ui/core/typography.dart` (`T.*`, `ui()` = Figtree, `mono()` = IBM Plex
Mono).

| Token | Value | | Token | Value |
|---|---|---|---|---|
| `C.bg` | `#0F1113` | | `C.textPrimary` | `#E8E9E7` |
| `C.bgRecents` | `#0A0B0C` | | `C.textSecondary` | `#D7DCDA` |
| `C.bgReader` | `#12100D` | | `C.textTertiary` | `#B9BFBD` |
| `C.surface` | `#15181B` | | `C.textMuted` | `#8A918F` |
| `C.sheet` | `#141719` | | `C.textFaint` | `#6E7573` |
| `C.raised` | `#181B1E` | | `C.textDim` | `#5F6664` |
| `C.button` | `#1C2124` | | `C.textDisabled` | `#4A5150` |
| `C.selected` | `#20262A` | | `C.icon` | `#9AA1A0` |
| `C.monogramOpen` | `#20252A` | | `C.monogramText` | `#C7CECC` |
| `C.trackOff` / `C.knobOff` | `#232729` / `#4A5150` | | `C.pillText` | `#A9B0AE` |
| `C.skeleton` | `#1B1F22` | | `C.tabInactive` | `#767D7B` |
| `C.barTrack` | `#1A1E21` | | `C.jade` | `#7FC8A9` |
| `C.handle` | `#2C3134` | | `C.jadeCode` | `#9FD8C0` |
| `C.lineNN` | white at NN% (05,06,07,08,09,10,12,13,16) | | `C.idleDot` | `#3E4644` |
| `C.danger` | `#D66A5A` | | `C.pinEmpty` | `#3A403E` |
| `C.dangerSurface` | `#241C1D` | | `C.warning` | `#D6A45B` |
| `C.dangerMuted` | `#8A6A62` | | `C.dangerPanel` | `#1A1517` |
| `C.pinError` | `#4A3634` | | `C.markers` | `#7FC8A9 #8FA5C8 #D6A45B #C89BB4 #8A918F` |
| Reader | `readerMuted #8A857C`, `readerTitle #EDE7DC`, `readerBody #CFC8BC`, `readerHost #7C776E` | | | |

Named styles used below: `T.screenTitle` 16/600; `T.sheetTitle` 17/600,
letter-spacing −0.17; `T.rowTitle` 14.5/500; `T.body` 14; `T.bodyMuted`
13/`textMuted`/line-height 1.65.

Shared widgets:

- **`BottomSheetSurface`** (`core/widgets/sheet.dart`): `C.sheet` fill, a 1px
  top border at white 9%, 22 radius on the top corners, shadow black 55% with
  blur 40 and offset (0,−20). Default padding 20/22/20/20 (L/T/R/B). An
  optional handle is 36×4, radius 2, `C.handle`, 16 below it. Children scroll
  when they are too tall. Sheets are shown with `showModalBottomSheet` and a
  transparent background, over the **live page** with Material's default dark
  scrim. The canvas cards draw a dimmed skeleton page instead.
- **`SheetGroup` / `SheetRow`**: a group has radius 16, a 1px border at white
  8%, and white 5% hairlines between rows. A row has 16/15 padding, a
  `C.surface` fill and a 14.5 label (default `C.textPrimary`).
- **`PillButton`**: a minimum height of 48 by default, radius = height/2, label
  14.5. Primary is a `C.jade` fill with a `C.bg` label at weight 600. Neutral
  is a `C.button` fill with a `C.textSecondary` label at weight 500 (`C.textDim`
  when disabled). Danger-outline has no fill, a border of `C.danger` at 28%, a
  `C.danger` label at weight 500 and a 10.5 `C.dangerMuted` sublabel.
- **`AppToggle`**: 44×26, radius 13, 3 padding, 20 knob. On is a `C.jade` track
  with a `C.bg` knob; off is `C.trackOff` with `C.knobOff`. When inert (no
  handler) it is drawn at 40% opacity.
- **`IconTap`**: an `AppIcon` line icon (drawn, never a Unicode glyph:
  `test/no_glyphs_test.dart`) inside a tap target, with a screen-reader label.
- **`Monogram`**: default 36 square, radius 10, 14/600. Open is a
  `C.monogramOpen` fill with `C.monogramText`; idle is `C.raised` with
  `C.textMuted`. The letters scale down to fit.
- **`PageSkeleton`**: placeholder bars in `C.skeleton`/`C.surface`, 20 padding,
  default opacity 0.28.

---

## 6a — Permission request

**Canvas title:** `Permission request — one time by default, never remembered silently`

**Built by:** `lib/ui/features/in_page/views/permission_request_sheet.dart`
(`PermissionRequestSheet`), shown by
`lib/ui/features/container/views/container_route.dart` (`_showPermissionSheet`).
`isDismissible: false` (a tap outside does nothing), `isScrollControlled`,
`useSafeArea`. Back or a drag down answers "Keep blocked". A background page's
ask waits until that page is viewed.

**Layout (top to bottom):** the live page with the modal scrim, then a
`BottomSheetSurface` (padding 20/22/20/20, no handle):

1. Title: `T.sheetTitle` values (17/600, −0.17), `C.textPrimary`.
2. 8 gap. Body in `T.bodyMuted` (13, `C.textMuted`, line-height 1.65).
3. 16 gap. "Allow once": `PillButton` primary (jade), 48.
4. 10 gap. "Allow while this site is open": neutral pill, 48.
5. 10 gap. "Keep blocked": neutral pill, 48.

**Strings, in order:**

- `<host> wants <phrase>`, where `<phrase>` is one of `your camera`,
  `your microphone`, `your location` or `your clipboard`. Example:
  `meet.example.com wants your microphone`.
- `It is blocked right now. Allowing it applies to this site only, inside this container.`
- `Allow once`
- `Allow while this site is open`
- `Keep blocked`

Screen-reader labels: none of its own (the buttons are text).

**Differs from canvas:**

- **Jade button.** The canvas fills **"Keep blocked"** jade, with the two allow
  buttons neutral. The code fills **"Allow once"** jade and leaves "Keep
  blocked" neutral (Plan 4's comment calls this "the design"). No later spec or
  ruling records the change, so it is an unreconciled deviation. Under
  CLAUDE.md the canvas is authoritative here.
- The button gaps are 10 in the code and 9 in the canvas.
- Behind the sheet the code shows the real page and the real container chrome
  under a scrim. The canvas dims the top bar to 50% and the skeleton to 28%.
- The camera and microphone asks also trigger Android's own runtime permission
  dialog after an allow (Plan 15). That dialog is system UI, not this sheet.

**Canvas sample data:** host `meet.example.com`, microphone. The page behind
it shows `meet.example.com` with a jade live dot.

---

## 6b — Reader mode

**Canvas title:** `Reader mode — text only, controls out of the way`

**Built by:** `lib/ui/features/in_page/views/reader_screen.dart`
(`ReaderScreen`), wrapped by `reader_route.dart` (`ReaderRoute`), which keeps
the style per vault in the `reader_text_size` and `reader_contrast` settings.
It is pushed as a full-screen `MaterialPageRoute` from ☰ › Reader. When
extraction returns nothing, nothing opens and no message is shown; this always
happens at the Safest level.

**Layout:** a `Scaffold` with a `C.bgReader` background, inside a `SafeArea`.

1. Header: padding 16 horizontal, 10 vertical, with a `C.line06` bottom
   hairline. A row with space-between:
   - left: an `IconTap` back icon (20 target, 18 icon, `C.readerMuted`);
   - centre: the reading label, 11.5/500, letter-spacing 0.69, `C.readerMuted`,
     centred, one line;
   - right: `Aa` as text (13, `C.readerMuted`), then 14 gap, then an
     `IconTap` contrast icon (20 target, 16 icon, `C.readerMuted`).
2. Article `ListView`, padding 26/26/26/40:
   - host: 12, `C.readerHost`;
   - 18 gap;
   - title: 600, line-height 1.25, letter-spacing −0.375. Size is 25, 28 or 31
     by text size. Colour is `C.readerTitle`, or `C.readerBody` when soft;
   - 18 gap;
   - paragraphs 14 apart, line-height 1.75. Size is 15.5, 17.5 or 19.5. Colour
     is `C.readerBody`, or `C.readerMuted` when soft.

`Aa` cycles three sizes (standard, larger, largest). The contrast icon toggles
a softer, lower-contrast pair. The theme is dark only.

**Strings:**

- `READER · <N> MIN` (`ReaderArticle.readingLabel`), for example
  `READER · 6 MIN`.
- `Aa`
- `<host>`, `<article title>` and `<paragraphs>` all come from the page.

Screen-reader labels: `Back`, `Reader theme`. The `Aa` text has no label of its
own beyond its text.

**Differs from canvas:**

- The `‹` and `◑` glyphs are now drawn icons (`AppGlyph.back`,
  `AppGlyph.contrast`) under Plan 17. The code wins.
- The canvas's `Aa` and `◑` were static. Their behaviour is the user's ruling
  of 2026-09-30.

**Canvas sample data:**

- Label: `READER · 6 MIN`. Host: `forum.example.com`.
- Title: `What a container actually isolates, and what it cannot`.
- Paragraphs:
  - "Separate storage stops one site from reading another's cookies. It does
    not hide the fact that a request came from this device, which is what the
    proxy layer is for."
  - "The two protections are often confused. Keeping them separate in your
    head makes it easier to decide which sites need which."
  - "A site that needs a login and a site you want to read anonymously are
    different problems, and they belong in different workspaces."

---

## 6c — Site sheet (now the per-site shield panel)

**Canvas title:** `Site sheet — what this container is running under, editable in place`

**Built by:** `lib/ui/features/in_page/views/site_sheet.dart` (`SiteSheet`),
shown by `container_route.dart` (`_showSiteSheet`). It opens from the shield at
the end of the address pill, whose screen-reader label is `Site details`. The
sheet is `isScrollControlled` and `useSafeArea`. Its data is live from the
`OpenContainers` registry. The Security level row opens
`lib/ui/features/settings/views/security_level_picker.dart`
(`SecurityLevelPicker.site`), which is described below.

The rebuild follows Plan 16 and
`docs/superpowers/specs/2026-10-02-privacy-controls-design.md` §3 and §5:
security level, counts by category, three privacy switches and the permissions
in use. Every switch, and the level, applies **at once**. The sheet closes and
the container reopens in place at the viewed page.

**Layout:** a `BottomSheetSurface` with a handle, padding 0/10/0/18. The
36×4 `C.handle` handle sits 16 above the content. Everything below the handle
scrolls.

1. Header: outer padding 18/0/18/16, inner 16 bottom padding, a `C.line06`
   bottom hairline. A row of:
   - `Monogram`, size 40, radius 11, font 15;
   - 12 gap;
   - name (15.5/600, one line) over the subtitle (11.5, `C.textFaint`, one
     line), 3 apart;
   - `Edit` (13/500, `C.jade`) at the right.
2. Info rows (`_SheetInfoRow`): padding 18 horizontal, 14 vertical, a
   `C.line05` bottom hairline. Label 14 `C.textPrimary` on the left. Value
   12.5 `C.textMuted`, end-aligned, wrapping when needed. A switch row puts an
   `AppToggle` on the right instead, and the whole row toggles it. Rows in
   order:
   1. **Proxy** (tappable: opens the site's form on its Network tab; on a
      throwaway it saves the throwaway as a site);
   2. **Cookies**;
   3. **Security level** (tappable: opens the picker);
   4. **Blocked here**. When a category count is above 0, the category rows
      come next, without a hairline between them and Blocked here: inset
      32/0/18/12, 6 apart, label 12.5 `C.textMuted`, count in mono 11
      `C.textFaint` at the right, a `C.line05` hairline under the block;
   5. **Block WebRTC** switch. It is on and inert (40% opacity) on a Tor
      site;
   6. **Block trackers and ads** switch;
   7. **Anti-fingerprinting** switch;
   8. **Force dark mode** switch;
   9. **Desktop view** switch;
   10. permissions in use, 0 to 4 rows in the order Camera, Microphone,
       Location, Clipboard. A stored grant shows `Allowed` (12.5,
       `C.textMuted`). An "allow while open" grant shows `Revoke` (13/500,
       `C.textPrimary`), which is tappable and reloads the container.
3. "Close and wipe this session": padding 18/14/18/0, a neutral
   `PillButton` with height 46 and radius 14.

**Strings, in order:**

- `<monogram>`, two letters, for example `Fr`.
- `<site name>`, for example `Forum`.
- Subtitle: `<host> · <workspace name>` (`forum.example.com · Personal`). A
  throwaway, or a site whose workspace is unknown, shows `<host>` alone.
- `Edit`
- `Proxy`. Its value is one of:
  - `Direct`
  - `SOCKS5 · <host>:<port>` (`SOCKS5 · 127.0.0.1:9050`)
  - `HTTP · <host>:<port>`
  - `Tor`
- `Cookies`. Its value is `Keep for this site` or `Wipe on exit`.
- `Security level`. Its value is `<Level>` when the site has its own level,
  or `<Level> · default` when it follows the vault. Levels: `Standard`,
  `Safer`, `Safest`. Example: `Standard · default`.
- `Blocked here`. Its value is `<N> request` when N is 1, otherwise
  `<N> requests` (`164 requests`, `0 requests`).
  - Category rows, only for counts above 0: `Trackers`, `Ads`,
    `Fingerprinting`, `Permission asks`, each with `<N>`.
- `Block WebRTC`
- `Block trackers and ads`
- `Anti-fingerprinting`
- `Force dark mode`
- `Desktop view`
- Permission rows: `Camera`, `Microphone`, `Location`, `Clipboard`, each with
  `Allowed` or `Revoke`.
- `Close and wipe this session`

Screen-reader labels: none of the sheet's own (every control is text). The
entry point is labelled `Site details`.

**Sub-sheet: the site's security level picker**
(`SecurityLevelPicker.site`). A `BottomSheetSurface` with a handle, padding
0/10/0/18.

- Title `Security level` in `T.sheetTitle`, padding 18/0/18/12.
- Rows: 18/13 padding, a `C.line05` top hairline, title 14.5 `C.textPrimary`
  over a 12 `C.textFaint` line, 3 apart. The current row has a jade check
  icon (15).
- Strings, in order:
  - `Security level`
  - `Default`, with `<VaultDefault> · set in Settings` (for example
    `Standard · set in Settings`)
  - `Standard`, with `Every site feature is on`
  - `Safer`, with `JavaScript off on http pages · no WebGL or WebAssembly`
  - `Safest`, with `JavaScript and images off on every page`

**Differs from canvas:**

- **Content (later spec wins).** The canvas has six rows: Proxy, Cookies,
  Blocked here, Force dark mode, Desktop view, then the wipe button. The code
  adds Security level, the category counts, Block WebRTC, Block trackers and
  ads, Anti-fingerprinting and the permission rows, per privacy-controls spec
  §3.
- The Proxy row is tappable (ruling of 2026-10-05).
- The switches apply immediately and reopen the container. The canvas implied
  nothing about timing.
- The Cookies value says `Keep for this site` where the canvas has no keep
  example. Its wipe example, `Wipe on exit`, matches.
- The sheet scrolls, because it is taller than a phone screen.

**Canvas sample data:** `Fr`, `Forum`, `forum.example.com · Personal`, Proxy
`SOCKS5 · 127.0.0.1:9050`, Cookies `Wipe on exit`, Blocked here
`164 requests`, Force dark mode on, Desktop view off.

---

## 7b — Long-press on a row (site row menu)

**Canvas title:** `Long-press on a row — wipe sits apart from the rest`

**Built by:** `lib/ui/features/dashboard/views/site_row_menu.dart`
(`SiteRowMenu`), shown by `site_row_actions.dart` (`showSiteRowMenu`) on a
long-press of a Sites-tab row. The sheet itself is **not** a
`BottomSheetSurface`. It is a bare scrolling column on a transparent sheet
background over the default scrim. The confirmation it leads to is in
`wipe_site_sheet.dart` (`WipeSiteSheet`, `confirmWipeSite`).

**Layout:**

1. Site card: horizontal margin 16, padding 14/12, `C.barTrack` fill, radius
   14, a 1px border at white 9%. It holds a `Monogram` (36, radius 10, 14/600),
   12 gap, then the name (`T.rowTitle` 14.5/500, one line) over the subtitle
   (11, `C.textFaint`, one line), 3 apart.
2. Padding 16/10/16/20, containing:
   - `SheetGroup` 1: `Open`, `Edit settings`;
   - 10 gap;
   - `SheetGroup` 2: `Wipe this site's data` (label `C.textSecondary`), then
     `Remove site` (label `C.danger`);
   - 10 gap;
   - `Cancel`: neutral `PillButton`, height 50.

**Strings, in order:**

- `<monogram>`
- `<site name>`
- `<site.url>`, the stored full address (`https://forum.example.com`).
- `Open`
- `Edit settings`
- `Wipe this site's data`
- `Remove site`
- `Cancel`

What each row does:

- **Open** opens the container.
- **Edit settings** opens `2a` for the site.
- **Remove site** closes, wipes and deletes the site **with no
  confirmation**.
- **Wipe this site's data** first opens the confirmation sheet below.

**Confirmation sheet (`WipeSiteSheet`, approved by the user 2026-09-30, not in
the canvas):** a `BottomSheetSurface` with default padding.

1. Title: 17/600, −0.17.
2. 8 gap. Body in `T.bodyMuted`.
3. 18 gap. A `SheetGroup` with one row, `Wipe`, in `C.danger`.
4. 10 gap. `Cancel`: neutral pill, height 50. The sheet has no jade.

Strings, in order:

- `Wipe this site's data?`
- `Its logins, storage and downloads are destroyed. The site stays in its workspace.`
- `Wipe`
- `Cancel`

Screen-reader labels: none.

**Differs from canvas:**

- **Rows (ruling of 2026-10-05: the code wins).** The canvas's first group is
  Open, Open in Ephemeral, Edit settings, Duplicate into Work, Require PIN to
  open. The three unbuilt rows are hidden until their actions exist.
- **Subtitle.** The canvas shows `forum.example.com · ephemeral`, the host
  plus the storage rule. The code shows `site.url`, the full URL with its
  scheme. No ruling covers this; it looks like a simplification rather than a
  decision.
- The canvas shows the dimmed dashboard skeleton (opacity .3) above the card.
  The code shows the real dashboard under the scrim.
- The wipe confirmation sheet is new (2026-09-30).

**Canvas sample data:** `Fr`, `Forum`, `forum.example.com · ephemeral`.

---

## 7c — Blocked (held) download

**Canvas title:** `Blocked download — says what it is and where it would land`

**Built by:** `lib/ui/features/in_page/views/held_download_sheet.dart`
(`HeldDownloadSheet`), shown by `container_route.dart` (`_showDownloadSheet`).
The sheet is dismissible, and dismissing it means Discard. It is
`isScrollControlled` and `useSafeArea`. Its outcome is reported in a default
Material `SnackBar`.

**Layout:** a `BottomSheetSurface` with default padding.

1. Title `Download held`: 17/600, −0.17.
2. 8 gap. Body in `T.bodyMuted`.
3. 16 gap. File card: padding 14, `C.surface`, radius 14, a `C.line08` border.
   It holds:
   - a `Monogram`-style badge, 38 square, radius 10, 11/600, `C.monogramOpen`
     with `C.monogramText`, showing the extension in capitals;
   - 12 gap;
   - the file name (13.5, `C.textPrimary`, up to 2 lines) over the meta line
     (11.5, `C.textFaint`), 3 apart.
4. 16 gap. `Keep inside this container`: neutral pill, 48.
5. 9 gap. `Save to device storage`: neutral pill, 48.
6. 9 gap. `Discard`: **primary (jade)** pill, 48.

**Strings, in order:**

- `Download held`
- `Files leave the container when they are saved. This one would go to your device storage where other apps can read it.`
- `<KIND>`: the file extension in capitals (`PDF`), or `FILE` when there is
  none.
- `<file name>` (`statement-june.pdf`)
- Meta line, one of:
  - `<size> · from <host>`, where size is `<n> B`, `<n.n> KB` or `<n.n> MB`
    (`1.4 MB · from forum.example.com`);
  - `from <host>`, when the size is unknown (ruling of 2026-09-29).
- `Keep inside this container`
- `Save to device storage`
- `Discard`
- Snackbar afterwards, one of:
  - `Saved to Downloads`
  - `Kept in this container`
  - `Download failed`
  - a route failure's message: `Cannot reach the proxy`,
    `The proxy refused the destination`, `The destination did not respond`,
    `The secure connection failed`, `This site has no proxy configured`,
    `This phone cannot route sites through a proxy`,
    `The proxy rejected the login`, `Tor did not connect`,
    `This site could not be opened`.

Screen-reader labels: none.

**Differs from canvas:**

- The canvas draws the dimmed top bar and skeleton behind the sheet. The code
  shows the live page under a scrim.
- The unknown-size meta line has no canvas example.
- The snackbars are not in the canvas.
- Otherwise the copy, the order and the jade Discard match.

**Canvas sample data:** `statement-june.pdf`, `PDF`,
`1.4 MB · from forum.example.com`.

---

## 8a — Opening checklist

**Canvas title:** `Opening — shows what is being applied before the page appears`

**Built by:** `lib/ui/features/container/views/opening_screen.dart`
(`OpeningBody`). Steps come from `lib/domain/models/open_step.dart`
(`openStepsFor`, `torStepLabel`). `container_route.dart` shows it until the
container's open returns, then lays it over the building page until the first
load reports live. Back and × both cancel: the container is closed, and a
throwaway is wiped.

**Layout:** a `Scaffold` with `C.bg`, inside a `SafeArea`.

1. Top bar: padding 12/8, a `C.line07` bottom hairline. It holds:
   - `IconTap` back (32 target, 18 icon);
   - the pill: height 34, radius 17, `C.surface`, a `C.line08` border, 12
     horizontal padding. Inside, a 6px **`C.warning` (amber)** dot, 7 gap, and
     the host (11.5, `C.pillText`, one line);
   - `IconTap` close (32 target, 16 icon).
2. Progress line: 2 high, `C.barTrack` track, `C.jade` fill fixed at **60%**.
3. Centre block (scrolls), 34 horizontal padding:
   - `Starting a clean container` in `T.screenTitle` (16/600);
   - 20 gap;
   - steps 14 apart. Each has a marker, 11 gap, and a 13.5 label.
4. Footer: padding 34/0/34/30, 12, line-height 1.6, `C.textDim`.

Step markers and label colours:

- **done:** jade check icon 14, label `C.textMuted`;
- **running:** an amber 11px ring with a gap at the top, label
  `C.textSecondary`;
- **pending:** an 11px ring with a 1.5 border in `C.textDim`, label
  `C.textDim`.

`openStepsFor` currently returns **every step as pending**, so the device
always shows grey hollow rings. That was found in the 2026-10-03 device run,
and no done or running state is ever shown.

**Strings, in order:**

- `<host>` (`forum.example.com`)
- `Starting a clean container`
- `Fresh session, no shared cookies` (always shown)
- `Filter lists loaded` (only when Block trackers and ads is on)
- `Fingerprint noise injected` (only when Anti-fingerprinting is on)
- The route step, one of:
  - `Connecting through <proxyHost>:<proxyPort>` on SOCKS5 or HTTP
    (`Connecting through 127.0.0.1:9050`);
  - `Connecting to Tor`, or `Connecting to Tor · <N>%` on Tor
    (`Connecting to Tor · 45%`);
  - nothing on Direct.
- `Nothing loads until the tunnel is up.` (always shown, Direct included)

Screen-reader labels: `Back`, `Close`.

**Differs from canvas:**

- The canvas shows three done steps (jade ✓, muted) and one running amber
  spinner. The code shows all steps pending (grey).
- The canvas progress line is at 58%. The code uses 0.6.
- The steps are conditional on the site's settings.
- The Tor percentage variant comes from Plan 19.
- The icons are drawn (Plan 17).

**Canvas sample data:** host `forum.example.com`, tunnel `127.0.0.1:9050`.

---

## 8b — Proxy unreachable (refused open)

**Canvas title:** `Proxy unreachable — no silent fallback, the risky option is spelled out`

**Built by:** `lib/ui/features/in_page/views/proxy_unreachable_screen.dart`
(`ProxyUnreachableScreen`). The copy comes from
`lib/domain/models/route_failure_copy.dart` (`proxyFailureHeadline`,
`proxyFailureDetail`) and `route_decision.dart` (`refusalMessage`). The values
come from `route_display.dart` (`tunnelDescriptor`, `canOpenWithoutTunnel`)
and `relative_age.dart` (`lastWorkedLabel`). It is shown **in place of the
container** inside the container's route (`container_route.dart`,
`_refusalScreen`).

What the buttons do:

- **Try again** reopens in place.
- **Change proxy settings** opens the site's form on Network. On a throwaway
  it saves the throwaway as a site.
- **Open without the tunnel** goes direct for this visit only, in the site's
  own profile.

**Layout:** a `Scaffold` with `C.bg`, inside a `SafeArea`.

1. Header (`_TunnelHeader`): padding 12/8, a `C.line07` bottom hairline. It
   holds:
   - a back icon in a 32 box (18 icon, **inert**, no tap and no label);
   - the pill: 34 high, radius 17, `C.surface`, with a **border of `C.danger`
     at 25%**. Inside, a 6px `C.danger` dot, 7 gap, and the host (11.5,
     `C.textTertiary`);
   - a reload icon in a 32 box (16, **inert**).
2. Centre block (`CenteredScroll`, 30 horizontal padding, left-aligned):
   1. Mark: 44×44, radius 13, a border of `C.danger` at 30%, with the
      `refused` icon (20, `C.danger`).
   2. 18 gap. Headline: 19/600, letter-spacing −0.19, `C.textPrimary`.
   3. 18 gap. Detail: 13.5, line-height 1.7, `C.textMuted`. Absent for
      `misconfigured`.
   4. 18 gap. Info box: padding 14/13, `C.sheet`, radius 14, a `C.line08`
      border, with two rows 7 apart. Each row has a label (12, `C.textFaint`)
      on the left and a value (12, `C.textSecondary`) on the right.
   5. 22 gap. `Try again`: primary jade pill, 48.
   6. 9 gap. `Change proxy settings`: neutral pill, 48.
   7. 9 gap. `Open without the tunnel` with its sublabel: danger-outline pill,
      48. **Hidden** for a direct site or an onion host.
   8. 20 bottom gap.

**Strings, in order:**

- `<host>` in the pill.
- Headline and detail, one variant per `RouteFailure`. `<Site>` is the site
  name and `<tunnel>` is the tunnel descriptor below.

| Failure | Headline | Detail |
|---|---|---|
| proxyUnreachable | `Proxy did not answer` | `<Site> is set to go through <tunnel> and nothing is listening there. The page was not loaded, so no request left your device.` |
| proxyRefused | `The proxy refused the destination` | `<Site> is set to go through <tunnel>, which did not complete the connection. The page was not loaded, so no request left your device.` |
| upstreamTimeout | `The destination did not respond` | (same as proxyRefused) |
| tlsFailure | `The secure connection failed` | (same as proxyRefused) |
| proxyLoginRejected | `The proxy rejected the login` | (same as proxyRefused) |
| misconfigured | `This site has no proxy configured` | *(none: the headline stands alone)* |
| unsupported | `This phone cannot route sites through a proxy` | `Update Android System WebView to open proxied sites.` |
| torFailed | `Tor did not connect` | `<Site> is set to go through Tor, which could not reach the Tor network. The page was not loaded, so no request left your device.` |
| openFailed | `This site could not be opened` | `Something went wrong before the page loaded. The page was not loaded, so no request left your device.` |

- `Tunnel`. Its value (`tunnelDescriptor`) is one of:
  - `<mode> · <host>:<port>` with the mode in lower case:
    `socks5 · 127.0.0.1:9050` or `http · 10.0.2.2:8888`;
  - `Tor`;
  - `no proxy` when no proxy host is set.
- `Last worked`. Its value is one of:
  - `never on this device`
  - `just now`
  - `<N> minute ago` / `<N> minutes ago`
  - `<N> hour ago` / `<N> hours ago`
  - `<N> day ago` / `<N> days ago`
- `Try again`
- `Change proxy settings`
- `Open without the tunnel`
- `This site will see your real IP` (the sublabel)

Screen-reader labels: none. The header icons are decorative and inert, as the
canvas draws them (Plan 17 ruling).

**Differs from canvas:**

- **Variants (later plans win).** The canvas draws only "Proxy did not
  answer". Plans 4, 13, 14 and 19 and the ruling of 2026-10-05 add the other
  eight variants.
- The canvas's `⛌`, `‹` and `⟳` are drawn icons.
- The canvas always shows "Open without the tunnel". The code hides it for
  Direct (an `openFailed` refusal) and for onion hosts.
- The canvas's "Last worked" is `2 hours ago`. The code reads
  `sites.last_worked_at` and often shows `never on this device`.
- On a direct site the Tunnel row reads `no proxy` (an `openFailed` refusal on
  a direct site).

**Canvas sample data:** host `forum.example.com`, name `Forum`, tunnel
`socks5 · 127.0.0.1:9050`, Last worked `2 hours ago`.

---

## 8c — Tunnel dropped mid-session

**Canvas title:** `Tunnel dropped mid-session — page frozen, decision surfaced at the top`

**Built by:** `lib/ui/features/in_page/views/tunnel_dropped_screen.dart`
(`TunnelDroppedScreen`). `container_route.dart` stacks it over the container
when `viewed.tunnelDropped` is set.

- **Reconnect** clears the overlay **and reloads the page shown** (ruling of
  2026-10-05).
- **Close and wipe** closes the container and rotates a saved site's profile.

**Layout:** a full-screen `Scaffold` with `C.bg` (it covers the real page; the
page underneath is not visible), inside a `SafeArea`.

1. Top row: padding 12/8, **no** bottom hairline. It holds:
   - an inert back icon in a 32 box (18);
   - the danger pill, as in 8b: 34 high, radius 17, `C.surface`, a border of
     `C.danger` at 25%, a 6px `C.danger` dot, and the host in 11.5
     `C.textTertiary`;
   - an inert reload icon in a 32 box (16).
2. Banner: margin 12/4/12/0, padding 14, `C.dangerPanel` fill, radius 16, a
   border of `C.danger` at 28%.
   - A row: the `refused` icon (16, `C.danger`), 11 gap, then a column of the
     title (14.5/600, `C.textPrimary`), 5 gap, and the body (12.5,
     line-height 1.6, **`C.dangerMuted`**).
   - 12 gap. A row of two buttons, 9 apart, each 42 high with radius 21:
     - `Reconnect`: `C.jade` fill, 13.5/600 `C.bg` label;
     - `Close and wipe`: `C.dangerSurface` fill, 13.5/500 `C.textSecondary`
       label.
3. The rest of the screen: `PageSkeleton` at opacity 0.34 behind a greyscale
   colour filter.

**Strings, in order:**

- `<host>`
- `Tunnel dropped`
- `The page is paused. Nothing further has been requested since the connection failed <ago>.`
  `container_route` always passes `just now` for `<ago>`, so the device
  shows:
  `The page is paused. Nothing further has been requested since the connection failed just now.`
- `Reconnect`
- `Close and wipe`

Screen-reader labels: none.

**Differs from canvas:**

- The canvas says `failed 4 seconds ago`. The code always says `just now`.
- The canvas body colour is `#9A9089`, which is not a token. The code uses
  `C.dangerMuted` `#8A6A62`, which is darker and lower contrast. This is an
  unreconciled colour substitution.
- The icons are drawn.
- The canvas shows a frozen greyscale page. The code shows the greyscale
  **skeleton**, not the real page.

**Canvas sample data:** `forum.example.com`, `4 seconds ago`.

---

## 9a — Recents (app switcher)

**Canvas title:** `Recents — neutral name, blank card, no page title`

**Built by:** no Flutter screen. Android draws this.

- `MainActivity.kt` sets `FLAG_SECURE` for the life of the process. It blanks
  the recents preview and blocks screenshots.
- `android/app/src/main/kotlin/com/mono/container/SecureWindowPlugin.kt`,
  called once from `lib/main.dart` (`SecureWindow().neutraliseRecents()`), fixes
  the task label to `Container`.
- The manifest `android:label` and `MaterialApp.title` are also `Container`.

**What the user sees:** the system's recents card with the label `Container`
and the app icon. The preview is blank, black or system-greyed, depending on
the Android version.

**Strings rendered by the app:**

- `Container` (the task label, drawn by the system)

**Differs from canvas:** the canvas mocks up a card containing the ◇ mark and
`Content hidden`, with the caption
`Screenshots blocked while this app is open` underneath. **Neither string
exists in the app.** The OS draws the card, and no part of it can be styled.
Any mockup of 9a is a mockup of system UI.

**Canvas sample data:** a neighbouring app card labelled `Maps`.

---

## 9b — Back within the grace period (welcome back)

**Canvas title:** `Back within the grace period — sessions kept, one tap to resume`

**Built by:** `lib/ui/features/lock/views/lock_body.dart` (`LockBody`,
`LockMood.welcomeBack`), mounted by `lock_screen.dart` (`LockScreen`), which
ticks the countdown every second. The shared pieces are in `core/widgets/`:
`pin_layout.dart` (in landscape the message sits left and the keypad right,
per the 2026-10-05 ruling), `pin_dots.dart` and `pin_keypad.dart`.

**Layout:** a `Scaffold` with `C.bg`, inside a `SafeArea`, 28 horizontal
padding, in portrait:

1. Message block, centred vertically in the space above the keypad:
   - Mark: 44×44, radius 13, a `C.line12` border, holding the `vault` icon
     (20, `C.jade`).
   - 26 gap. `Welcome back`: 15, `C.textSecondary`, centred.
   - 8 gap. The sessions line: 12.5, `C.textFaint`, centred.
   - 26 gap. PIN dots: six 11px circles, 14 apart. Empty dots have a 1.5
     `C.pinEmpty` border; filled dots are `C.textPrimary`.
2. Keypad: at most 280 wide, three columns, 14 gaps, keys about 64 high
   (52 on screens under 640 high), circular `C.surface` keys with digits in
   22 `C.textSecondary`. The keys are 1 to 9, a blank, 0, and a backspace icon
   (24).
3. Fingerprint, **only when biometric unlock is enabled for this vault**:
   padding 26 top and 30 bottom, a `fingerprint` icon (28, `C.jade`), 8 gap,
   and `Use fingerprint` (12, `C.textFaint`). The whole block is tappable.

A wrong PIN here switches the screen to the `4c` mood: a red mark and
`Wrong PIN · <n> tries left`.

**Strings, in order:**

- `Welcome back`
- `<N> session still open · locks in <S>s` when N is 1, otherwise
  `<N> sessions still open · locks in <S>s`. N counts every open container in
  the vault, throwaways included. Example:
  `3 sessions still open · locks in 40s`. With a 5- or 15-minute auto-lock
  this reads, for example, `locks in 897s` (a known gap, left as is by the
  2026-10-01 ruling).
- Digits `1` to `9` and `0`.
- `Use fingerprint` (conditional)

Screen-reader labels: `Delete` on the backspace key.

**Differs from canvas:**

- The canvas mark glyph is ◇. The code draws the `vault` icon.
- The canvas fingerprint glyph ☉ is drawn as the `fingerprint` icon.
- The fingerprint row is only shown when biometrics is enabled. The canvas
  always shows it.
- The gap between the mark, the text and the dots is 26 in the code and 22 in
  the canvas.
- "One tap to resume" is not literal: a full six-digit PIN is required (2026-08-30
  ruling), unless the user resumes by fingerprint.

**Canvas sample data:** `3 sessions still open · locks in 40s`.

---

## 9c — Past the timer (locked after timeout)

**Canvas title:** `Past the timer — ephemeral sessions were already destroyed`

**Built by:** `lib/ui/features/lock/views/lock_body.dart`
(`LockMood.afterTimeout`), with the same shell as 9b.

**Layout:**

1. Mark: 44×44, radius 13, a `C.line12` border, the `vault` icon (20,
   `C.jade`).
2. 26 gap. `Enter your PIN`: 14, `C.textMuted`, centred.
3. 26 gap. PIN dots.
4. 20 gap. Notice box: full width, padding 14/12, `C.sheet` fill, a `C.line07`
   border, radius 14, left-aligned. It holds:
   - the line (12.5, `C.textMuted`);
   - 6 gap;
   - the body (12, line-height 1.55, `C.textDim`).
5. Keypad (as in 9b).
6. **No fingerprint row**: biometric unlock is resume-only and never applies
   to this mood.

**Strings, in order:**

- `Enter your PIN`
- The locked line, depending on the Auto-lock choice:
  - `Locked after 1 minute in the background`
  - `Locked after 5 minutes in the background`
  - `Locked after 15 minutes in the background`
- `Ephemeral sessions were closed and wiped. Saved sites will reopen where you left them.`
- Digits `1` to `9` and `0`.

Screen-reader labels: `Delete` (backspace).

**Differs from canvas:**

- The canvas shows `☉ Use fingerprint` under the keypad. The code shows none,
  per the biometric spec's resume-only rule. The code wins.
- The mark is the `vault` icon, not ◇.
- The gaps are 26/26/20 in the code and 20 throughout in the canvas.
- Since Plan 15 saved sites do not survive a lock (every lock closes every
  container). The body copy is unchanged from the canvas.

**Canvas sample data:** `Locked after 1 minute in the background`.

---

## 10a — Workspaces

**Canvas title:** `Workspaces — what each one keeps`

**Built by:** `lib/ui/features/workspaces/views/workspaces_screen.dart`
(`WorkspacesScreen`), wrapped by `workspaces_route.dart` (`WorkspacesRoute`).
The stats line comes from `lib/domain/workspace_stats.dart`
(`workspaceStatsLine`, `wholeMegabytes`).

The screen is reached from Settings › MANAGE › Workspaces and from ☰ ›
Workspaces. The dashboard's workspace chips open `10b` directly: a long-press
edits, and `+` creates.

- A tap on a row opens `10b` to edit that workspace.
- A long-press on a row opens `10c`.

**Layout:** a `Scaffold` with `C.bg`, inside a `SafeArea`.

1. Header: padding 18/14/18/12, a `C.line06` bottom hairline. It holds a back
   `IconTap` (20 target, 18 icon), 10 gap, and `Workspaces` in
   `T.screenTitle` (16/600).
2. `ListView`, padding 18/8/18/18:
   - **Rows:** 16 vertical padding, a `C.line06` bottom hairline. Each row has
     an 8×8 marker square (radius 2, `C.markers[i]`), 12 gap, then the name
     (15/500, `C.textPrimary`) over the stats line (11.5, `C.textFaint`), 4
     apart. A `forward` chevron icon (16, `C.textFaint`) sits at the right.
   - **"New workspace":** 20 top padding, the whole row tappable. A `plus`
     icon (18, `C.jade`), 11 gap, the label at 14.5/500 `C.jade`.
   - **Footnote:** 22 top padding, 12, line-height 1.6, `C.textDim`.

**Strings, in order:**

- `Workspaces`
- For each workspace: `<name>`, then
  `<N> site · <rule> · <storage>` when N is 1, otherwise
  `<N> sites · <rule> · <storage>`.
  - `<rule>` is `cookies kept` or `wipes on exit`.
  - `<storage>` is `<n> MB` (whole MB) for keep, or `nothing stored` for
    wipe-on-exit.
  - **No real byte count exists yet** (`FakeWorkspaceStorageService`), so on a
    device every keep workspace reads `0 MB`, for example
    `6 sites · cookies kept · 0 MB`.
- `New workspace`
- `The same site can live in more than one workspace. Each copy has its own login and its own history.`

Screen-reader labels: `Back`.

**Differs from canvas:**

- The `‹`, `›` and jade `+` glyphs are drawn icons (Plan 17).
- The storage figure is always `0 MB` in practice. The canvas shows real sizes.
- Long-press to delete is an implementation choice: the canvas does not draw
  the path to `10c`.

**Canvas sample data:**

- Personal (jade marker): `6 sites · cookies kept · 12 MB`
- Work (blue `#8FA5C8`): `2 sites · cookies kept · 3 MB`
- Ephemeral (grey `#8A918F`): `1 site · wipes on exit · nothing stored`

---

## 10b — New workspace (and edit workspace)

**Canvas title:** `New workspace — name, marker, storage rule`

**Built by:** `lib/ui/features/workspaces/views/workspace_form_screen.dart`
(`WorkspaceFormScreen`), opened by `workspaces_route.dart` (`createWorkspace`,
`editWorkspace`). It is used for both creating and editing. Only the title
changes.

**Layout:** a `Scaffold` with `C.bg`, inside a `SafeArea`.

1. Header: padding 18/12, **no hairline**. A row with space-between:
   - a close `IconTap` (24 target, 20 icon);
   - the centred title (15/600, one line);
   - `Save` (14/500, `C.jade`).
2. `ListView`, padding 18/14:
   1. **NAME:** the field label (10.5/600, letter-spacing 1.05, `C.textFaint`),
      8 gap, then a 46-high field: radius 12, `C.surface`, a border of
      `C.jade` at 35% (always, focused or not), 13 horizontal padding, text 14
      `C.textSecondary`, and no hint text.
   2. 20 gap. **MARKER:** label, 9 gap, then five 30×30 squares (radius 8,
      12 apart). The selected square has a 2px `C.textPrimary` border.
   3. 20 gap. **STORAGE:** label, 9 gap, then a group with radius 12, a
      `C.line08` border and a 1px `C.bg` divider. Each option has padding 13
      and a `C.surface` fill, with the title (13.5; `C.textPrimary` when
      selected, otherwise `C.textTertiary`) over the subtitle (11,
      `C.textFaint`), 3 apart. A 16px radio sits at the right: a 5px
      `C.jade` ring when selected, a 1.5px `C.idleDot` ring otherwise.
   4. 4 gap. Two switch rows, each with 16 top padding, the title (14,
      `C.textPrimary`) over the subtitle (11, `C.textFaint`), and an
      `AppToggle`. The whole row toggles.

**Strings, in order:**

- The title, one of:
  - `New workspace` when creating;
  - `<workspace name>` when editing.
- `Save`
- `NAME`
- The name field starts empty when creating, with no placeholder.
- `MARKER`
- `STORAGE`
- `Keep between sessions`, with `Stays signed in`
- `Wipe when the app closes`, with `Nothing survives a restart`
- `Ask for PIN to enter`, with `Applies to the whole workspace`
- `Show in decoy vault`, with `Off keeps it invisible behind the second PIN`

Screen-reader labels: `Close`.

**Defaults for a new workspace:** marker 0 (jade), Keep, PIN off, decoy off.

**Note:** "Ask for PIN to enter" is stored (`requirePin`) but **nothing
enforces it** anywhere in `lib/`. The switch works; the feature does not.

**Differs from canvas:**

- The canvas × is the `close` icon.
- The canvas shows a jade text cursor in the field. That is the native cursor
  now.
- The title is the workspace's name when editing. The canvas draws only the
  create case.

**Canvas sample data:** name `Research`; marker 2 (blue `#8FA5C8`) selected;
Keep selected; both switches off.

---

## 10c — Delete workspace

**Canvas title:** `Deleting — an itemised list of what goes, typed confirmation`

**Built by:** `lib/ui/features/workspaces/views/delete_workspace_sheet.dart`
(`DeleteWorkspaceSheet`), shown by `workspaces_route.dart` (`_delete`) as an
`isScrollControlled`, `useSafeArea` sheet padded above the keyboard. The rule
is in `lib/domain/workspace_deletion.dart` (`confirmsDeletion`): the typed
text, trimmed, must match the name exactly, case included.

Delete closes and wipes every site in the workspace, then deletes the rows.
Deleting the last workspace leaves a fresh `Personal`.

**Layout:** a `BottomSheetSurface` with default padding (20/22/20/20).

1. Title: 17/600, −0.17.
2. 16 gap. Stat table: radius 14, a `C.line08` border. Each row has padding
   14/12, a `C.surface` fill, a label (13, `C.textTertiary`) and a value (13,
   `C.textPrimary`; the last row's value is `C.textMuted`). **There are no
   dividers between rows**; the canvas uses 1px gaps.
3. 16 gap. Warning: 12.5, line-height 1.6, `C.textMuted`.
4. 16 gap. `Type the name to confirm`: 11.5, `C.textFaint`.
5. 8 gap. Field: 46 high, radius 12, `C.surface`, a `C.line10` border, text 14
   `C.textSecondary`. The hint is the workspace name in `C.textDisabled`.
6. 16 gap. A row of two buttons, 9 apart:
   - `Cancel`: neutral pill, 48;
   - `Delete`: 48, radius 24, a `C.dangerSurface` fill. When armed it has a
     border of `C.danger` at 28% and a 14.5/500 `C.dangerMuted` label. When
     disarmed the border drops to 10% and the label is `C.textDisabled`.

**Strings, in order:**

- `Delete “<name>”?` (curly quotes, deliberately), for example
  `Delete “Work”?`
- `Sites removed`, with `<N>`
- `Logins destroyed`, with `<N>` (the same number as sites)
- `Stored data wiped`, with `<n> MB`. This is always `0 MB` in practice, since
  storage is not measured.
- `Custom scripts kept`, with `In the script library`
- `This cannot be undone and there is no backup unless you made one yourself.`
- `Type the name to confirm`
- `<name>` (the field's hint)
- `Cancel`
- `Delete`

Screen-reader labels: none.

**Differs from canvas:**

- The canvas draws a dimmed skeleton behind the sheet. The real screen shows
  `10a` under the scrim.
- The canvas draws only the armed-looking Delete. The code dims it until the
  typed name matches.
- The row separators are absent (see the layout).

**Canvas sample data:** `Delete “Work”?`, 2 sites, 2 logins, `3 MB`, field
hint `Work`.

---

## 10d — Scripts and filters

**Canvas title:** `Scripts and filters — one library, reused across sites`

**Built by:**
`lib/ui/features/scripts/views/scripts_and_filters_screen.dart`
(`ScriptsAndFiltersScreen`, `scriptSubtitle`) and `filter_list_section.dart`
(`FilterListSection`, `formatRuleCount`, `updatedAgoLabel`), wrapped by
`scripts_route.dart` (`ScriptsRoute`). The data is in
`scripts/view_models/providers.dart`, and the bundled lists in
`lib/data/services/bundled_filter_lists.dart` and `assets/filters/*.txt`. The
screen is reached from Settings › MANAGE and from ☰ › Scripts and filters.

**Layout:** a `Scaffold` with `C.bg`, inside a `SafeArea`.

1. Header: padding 18/14/18/12, a `C.line06` bottom hairline. It holds a back
   `IconTap` (20/18), 10 gap, and `Scripts and filters` in `T.screenTitle`.
2. `ListView`, padding 18:
   - **`FILTER LISTS`** label: 10.5/600, letter-spacing 1.05, `C.textFaint`,
     4 bottom padding.
   - Filter rows: 14 vertical padding, a `C.line06` bottom hairline, the name
     (14, `C.textPrimary`) over the meta line (11.5, `C.textFaint`), 3 apart,
     12 gap, then an `AppToggle`. The whole row toggles.
   - **`MY SCRIPTS`** label: padding 0/24/0/4, the same style.
   - Script rows: 14 vertical padding, a hairline. Each has a 34×34 badge
     (radius 9, `C.raised`; text 12, `#9FD8C0` for CSS or `#D6A45B` for JS),
     12 gap, then the name (14) over the subtitle (11.5, `C.textFaint`), and
     an `AppToggle`. A tap on the row opens the editor. The switch toggles
     `enabled`.
   - **"New script":** 18 top padding, a `plus` icon (18, jade), 11 gap, the
     label at 14.5/500 `C.jade`. The whole row is tappable.

**Strings, in order:**

- `Scripts and filters`
- `FILTER LISTS`
- `Trackers and ads`, with the meta line below
- `Cookie notices`, with the meta line below
- `Social embeds`, with the meta line below
  - The meta line is `<N,NNN> rules · updated <D> days ago` when the list is
    on (`<D> day` when D is 1), or `<N,NNN> rules · off` when it is off.
  - Real bundled counts today: Trackers and ads **22**, Cookie notices
    **22**, Social embeds **13**. All are dated 2026-09-28, so on 2026-10-05
    the lines read `22 rules · updated 7 days ago`,
    `22 rules · updated 7 days ago` and `13 rules · off` (Social embeds is off
    by default).
- `MY SCRIPTS`
- For each script:
  - `CSS` or `JS` (the badge);
  - `<script name>`;
  - the subtitle: `Applied to <N> site` or `Applied to <N> sites`, plus
    ` · runs at start` or ` · runs at load` for a **JS** script only.
- `New script`
- A new script opens the editor named `New script` (CSS, empty code, enabled,
  no sites).

Screen-reader labels: `Back`.

**Differs from canvas:**

- **Update block (ruling of 2026-09-30: the code wins).** The canvas's
  "Update over the proxy / Next check in 5 days / Update now" block is
  removed. The lists are bundled, and the app makes no requests of its own.
- **Rule counts.** The canvas shows `84,102`, `11,430` and `2,908`. The real
  bundled lists are tiny (22, 22 and 13). Mockups may keep the canvas's
  numbers as illustrative, but the device shows the small ones.
- No scripts exist until the user makes one.
- The jade `+` and `‹` are drawn icons.

**Canvas sample data:**

- Filter lists:
  - Trackers and ads, on: `84,102 rules · updated 2 days ago`
  - Cookie notices, on: `11,430 rules · updated 2 days ago`
  - Social embeds, off: `2,908 rules · off`
- Scripts:
  - CSS `Hide sticky headers`, on: `Applied to 4 sites`
  - CSS `Wider reading column`, on: `Applied to 1 site`
  - JS `Auto-expand comments`, off: `Applied to 1 site · runs at load`

---

## 10e — Script editor

**Canvas title:** `Script editor — code, then where it runs`

**Built by:** `lib/ui/features/scripts/views/script_editor_screen.dart`
(`ScriptEditorScreen`, `_CodeEditor`), wrapped by `scripts_route.dart`
(`_ScriptEditorRoute`). The site picker is `script_site_picker.dart`
(`ScriptSitePicker`), whose shape is the user's ruling of 2026-09-29. Site
additions and removals take effect on Save.

**Layout:** a `Scaffold` with `C.bg`, inside a `SafeArea`.

1. Header: padding 18/12, a `C.line06` bottom hairline. A row with
   space-between:
   - a back `IconTap` (20/18);
   - the centred title (15/600, the script's name, one line, **not
     editable**);
   - `Save` (14/500, `C.jade`).
2. `ListView`, padding 18:
   1. Kind tabs: two equal tabs, 8 apart, each 38 high with radius 11.
      - Selected: `C.selected` fill, a `C.line10` border, a 13
        `C.textPrimary` label.
      - Unselected: no fill, a `C.line07` border, a 13 `C.tabInactive` label.
   2. 20 gap. Code box: `C.surface`, radius 12, a `C.line09` border. It holds
      a line-number gutter (padding 12/12/8/12, mono 11.5, line-height 1.9,
      `C.textDisabled`, right-aligned) and an editable mono field (padding
      4/12/12/12, 11.5, line-height 1.9, `C.jadeCode`) that grows with its
      content.
   3. 20 gap. `RUNS ON` label: 10.5/600, letter-spacing 1.05, `C.textFaint`.
   4. 10 gap. A wrap of chips, 8 apart:
      - site chips: padding 12/8, `C.button`, radius 20, the name (12.5,
        `C.textSecondary`), 6 gap, a `close` icon (12). A tap removes the
        site;
      - an add chip: padding 12/8, radius 20, a **solid** 1px border at
        white 15%, `+ Add site` (12.5, `C.jade`; `C.textDisabled` and inert
        when every site is already added).
   5. 20 gap. The run-at-start row: 14 top padding, a `C.line06` top hairline,
      the title (14, `C.textPrimary`) over the subtitle (11.5, `C.textFaint`),
      and an `AppToggle`. The whole row toggles.

**Strings, in order:**

- `<script name>`, for example `Hide sticky headers`, or `New script` for a
  new one.
- `Save`
- `CSS`
- `JavaScript`
- `<code>`, the user's text. A new script's code is empty.
- `RUNS ON`
- `<site name>` on each chip.
- `+ Add site`
- `Run before the page paints`
- `Prevents a flash of the hidden elements`

**Picker sheet (`ScriptSitePicker`):** a `BottomSheetSurface` with a handle,
padding 0/10/0/16, and **no title**. Each row has 12 vertical padding, a
`C.line05` hairline between rows, a `Monogram` (36), 12 gap, then the name
(`T.rowTitle`) over the host (mono 10.5, `C.textFaint`), 3 apart. The sheet
adds no copy of its own. Its strings are `<monogram>`, `<site name>` and
`<host>` for each site.

Screen-reader labels: `Back`, and `Remove` on each chip's ×.

**Differs from canvas:**

- The canvas's `+ Add site` chip has a **dashed** border at white 15%. The
  code's border is solid. This is unreconciled; there is no ruling.
- The canvas chip reads `Forum ×` as text. The code draws the name plus an
  icon.
- The `‹` is a drawn icon.
- The picker sheet is not in the canvas.

**Canvas sample data:**

- Title: `Hide sticky headers`. CSS is selected.
- Code (6 lines):

  ```
  header, .sticky, [data-sticky] {
    position: static !important;
  }

  .cookie-banner, .ad-slot {
    display: none !important;
  ```

- Chips: `Forum`, `Reader`, `Marketplace`, `News`.
- "Run before the page paints" is on.

---

## Sample data across these blocks

Names and hosts the canvas and the app's seed data
(`lib/data/services/app_database.dart`) share:

| Name | Monogram | URL | Workspace | Notes |
|---|---|---|---|---|
| Notes | Nt | `https://notes.example.org` | Personal | SOCKS5 `127.0.0.1:9050` |
| Webmail | Wm | `https://mail.example.net` | Personal | |
| Forum | Fr | `https://forum.example.com` | Personal | wipe on exit |
| Reader | Rd | `https://read.example.io` | Personal | |
| Bank | Bk | `https://bank.example.com` | Personal | requires PIN |
| Marketplace | Mk | `https://shop.example.com` | Personal | |
| Wiki | Wk | `https://wiki.internal` | Work | SOCKS5 `127.0.0.1:9050` |
| Tickets | Tk | `https://tickets.internal` | Work | |

The seed workspaces are Personal (marker 0, jade), Work (marker 1, blue) and
Ephemeral (marker 4, grey). Other sample hosts on these cards are
`meet.example.com` (6a) and the file `statement-june.pdf` (7c).

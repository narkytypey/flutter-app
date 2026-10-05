# Audit — the current design, measured

Measured against `main` at `d0edb1c` (2026-10-05). Sources: `lib/ui/core/tokens.dart`,
`typography.dart`, `theme.dart`, `icons.dart`, `lib/ui/core/widgets/*`, the
feature views under `lib/ui/features/*/views/`, and
`Sandbox Container -canvas-.dc.html`. Numbers below were produced by `grep`
and by `tools/contrast.py` in this directory (the pairs it ran are in
`tools/current-pairs.txt`, so every ratio can be re-run).

Per-screen structure and every string, screen by screen, is in
`inventory/screens-1-5.md` and `inventory/screens-6-10.md`.

## 1. Inventory

### 1.1 Colour tokens (`C.*`, 58 values)

References are counts of `C.<name>` across `lib/` (477 references in 71
files). Where a token is used is summarised from those call sites.

| Role group | Token | Hex | Refs | Used for |
|---|---|---|---|---|
| Surface | `bg` | `#0F1113` | 39 | every screen's scaffold; label colour on jade |
| | `bgPanic` | `#0C0E10` | 1 | `3c` |
| | `bgRecents` | `#0A0B0C` | 0 | (unused) |
| | `bgReader` | `#12100D` | 1 | `6b` warm reader |
| | `surface` | `#15181B` | 20 | address pill, keypad keys, sheet rows, skeleton |
| | `sheet` | `#141719` | 5 | bottom sheets |
| | `raised` | `#181B1E` | 7 | idle monogram, inputs |
| | `button` | `#1C2124` | 9 | neutral `PillButton` |
| | `selected` | `#20262A` | 6 | selected chip / tab |
| | `monogramOpen` | `#20252A` | 3 | live monogram |
| | `footer` | `#111417` | 4 | dashboard tab bar |
| | `trackOff` / `knobOff` | `#232729` / `#4A5150` | 6 / 4 | `AppToggle` off, `StepProgress` empty |
| | `skeleton`, `barTrack`, `handle` | `#1B1F22`, `#1A1E21`, `#2C3134` | 1 / 3 / 2 | placeholders, bars, sheet handle |
| Hairline | `line05`…`line16` | white at 5–16 % | 75 total | the structural element of the whole set |
| Text | `textPrimary` | `#E8E9E7` | 46 | titles, row names |
| | `textSecondary` | `#D7DCDA` | 19 | keypad digits, pill labels |
| | `textTertiary` | `#B9BFBD` | 9 | idle row title |
| | `textMuted` | `#8A918F` | 35 | values, body-muted |
| | `textFaint` | `#6E7573` | **52** | meta lines, section labels, subtitles — the most-used text colour |
| | `textDim` | `#5F6664` | 11 | idle meta, disabled labels |
| | `textDisabled` | `#4A5150` | 5 | inert icons |
| | `icon`, `chevron`, `tabInactive`, `pillText`, `monogramText` | `#9AA1A0`, `#7E8583`, `#767D7B`, `#A9B0AE`, `#C7CECC` | 3/0/6/2/3 | |
| Reader | `readerTitle/Body/Muted/Host` | `#EDE7DC` `#CFC8BC` `#8A857C` `#7C776E` | 9 | `6b` |
| State | `jade` | `#7FC8A9` | **43** | live rail, live dot, primary pill, toggles on, step bar, live labels |
| | `jadeCode` | `#9FD8C0` | 3 | code in `10e` |
| | `danger` | `#D66A5A` | 27 | panic, wipe, refusal headlines |
| | `dangerSurface`, `dangerPanel`, `dangerMuted`, `pinError` | `#241C1D` `#1A1517` `#8A6A62` `#4A3634` | 2/1/3/1 | |
| | `warning` | `#D6A45B` | 4 | "opening" dot, JS script kind |
| | `idleDot`, `pinEmpty` | `#3E4644`, `#3A403E` | 1 / 2 | |
| | `markers[5]` | `#7FC8A9 #8FA5C8 #D6A45B #C89BB4 #8A918F` | 4 | workspace colours (`10b`) |

Outside `tokens.dart`, `lib/` holds 4 raw `Color(0x…)` (two transparent
fills, and `user_script.dart`'s CSS/JS kind colours, which duplicate
`jadeCode` and `warning`), 22 `Colors.*` and 20 `withValues(alpha:)`
(mostly white/black alphas in `sheet.dart` and overlays).

Observations: the surface ramp is **eleven near-identical darks** between
`#0F1113` and `#232729` (the furthest apart, `bg` and `trackOff`, are 1.26:1).
They are distinguishable only on a good OLED in a dark room. The hairline
ramp has **nine alphas** from 5 % to 16 % where three would do.

### 1.2 Type

Two families: **Figtree** (variable, one 62.7 KB TTF) for UI and **IBM Plex
Mono** Regular + Medium (135.6 + 136.7 KB) for anything technical. 335 KB
of fonts bundled today.

`T.*` names 14 styles (44 references in 27 files). Most text is not set
through them: there are **175 direct `ui(size: …)` calls in 52 files and 16
`mono(…)` calls**, using **19 distinct sizes** between 9.5 and 34 px.

| `T.*` | Size / weight / tracking | Colour |
|---|---|---|
| `screenTitle` | 16 / 600 | primary |
| `sheetTitle` | 17 / 600 / −0.17 | primary |
| `stepTitle` | 22 / 600 / −0.22 | primary |
| `appBarTitle` | 15 / 600 | primary |
| `rowTitle` / `rowTitleIdle` | 14.5 / 500 | primary / tertiary |
| `body` | 14 / 400 | primary |
| `bodyMuted` | 13 / 400 / lh 1.65 | muted |
| `meta` / `metaIdle` | 10.5 / 400 | faint / dim |
| `sectionLabel` / `…Live` | 10 / 500 / +1.0 (uppercase) | faint / jade |
| `barSummary` | 10 / 400 | faint |
| `barBadge` | 10.5 / 500 / +0.63 | faint |
| `code` | Plex Mono 11.5 / lh 1.9 | jadeCode |

Direct-call size distribution (155 `ui(size:)` calls with a literal):
9.5 ×1, 10 ×3, 10.5 ×9, 11 ×11, 11.5 ×15, 12 ×13, 12.5 ×14, 13 ×17,
13.5 ×9, 14 ×31, 14.5 ×11, 15 ×8, 15.5 ×1, 16 ×1, 17 ×6, 18 ×1, 19 ×1,
22 ×2, 34 ×1. **66 of 155 (43 %) are 12.5 px or smaller.** The canvas file
has the same shape: 327 `font-size` declarations, the mode is 14 px (89),
and 112 are under 13 px.

Body text is 14 px against Material 3's `bodyLarge` 16 sp and iOS's 17 pt
body (see `RESEARCH.md` §Human factors).

### 1.3 Spacing, radii, borders, elevation

- **No spacing scale.** 156 `EdgeInsets` literals in 54 files and 207
  `SizedBox` spacers; the common paddings are 12, 13, 14, 18 and 28.
- **No radius scale.** 81 literal radii, **19 distinct values**: 1.5, 2,
  2.5, 3, 4, 5.5, 8, 9, 11, 12, 13, 14, 16, 17, 20, 21, 22, 24, 25.
- **Borders:** hairlines (white 5–16 %) under rows; `SheetGroup` is the one
  bordered group (16 radius, 8 % border). "Hairlines, not cards" is a global
  constraint in `CLAUDE.md`.
- **Elevation:** one shadow in the whole app, the bottom sheet's (black 55 %,
  blur 40, offset −20). Everything else is flat.

### 1.4 Density and touch targets

| Element | Measured | Reference |
|---|---|---|
| Dashboard site row (`SessionRow`) | 12 + 36 monogram + 12 = **60 dp**, two lines (14.5 / 10.5 px) | M3 two-line list item 72 dp |
| Settings row (`SettingRow`) | 15 + ~18 + 15 ≈ **48 dp** single-line, body 14 px, subtitle 11 px | M3 one-line 56 dp |
| Sheet row (`SheetRow`) | 15 + 18 + 15 ≈ **48 dp** | 48 dp minimum met |
| Container top bar | 8 + **34 dp pill** + 8 = 50 dp; host at **11.5 px**, route label at **9.5 px** | Chrome's omnibox text is ~16 sp |
| Pill's reload / stop / shield (`IconTap`) | **28 dp** targets | 48 dp (M3) |
| `IconTap` targets across the app (29 call sites) | 20 dp ×8, 24 ×4, 28 ×4, 32 ×7, 36 ×1, 40 ×4, 46 ×1 — **28 of 29 under 48 dp** | 48 dp |
| `AppToggle` | 44 × 26 dp visual; tappable only on the switch until 2026-10-05's row fixes | M3 switch 52 × 32 in a 48 dp target |
| Workspace chips | 32 dp tall | M3 chip 32 dp in a 48 dp target |
| PIN keypad keys | 64 dp (52 under 640 px tall), 280 dp max width | fine |
| Primary pill | 48–52 dp | fine |

### 1.5 Icons

`AppGlyph` has **26** line icons drawn by `AppIconPainter` (2-unit round
stroke on a 24-unit grid): back, forward, reload, stop, shield, panic, menu,
find, reader, link, search, globe, chevronUp, chevronDown, close, check,
plus, more, vault, fingerprint, backspace, refused, contrast, sites, today,
settings. No icon font, no dependency; `test/no_glyphs_test.dart` forbids
Unicode glyphs and `Icons.*` in `lib/`. Default colour `C.icon` `#9AA1A0`.

### 1.6 Brand

- **There is no logo.** The launcher icon is Flutter's default template
  icon: `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` has the same
  MD5 (`62703444…`) as Flutter 3.47.2's template. No adaptive icon, no
  monochrome (themed) icon.
- The wordmark exists only as the manifest label `Container`.
- The splash is `Theme.Black` (`#000000`), then `#0F1113`.

## 2. Contrast (WCAG 2.1), real pairings

Text needs 4.5:1 (all of this app's small text is under the 18.66 px bold /
24 px large-text threshold, so 3:1 never applies to text here). Non-text UI
components need 3:1 (1.4.11).

| Pair | FG | BG | Ratio | Needs | Result |
|---|---|---|---|---|---|
| textPrimary on bg | `#E8E9E7` | `#0F1113` | 15.53:1 | 4.5:1 | pass |
| textPrimary on sheet | `#E8E9E7` | `#141719` | 14.78:1 | 4.5:1 | pass |
| textSecondary on bg | `#D7DCDA` | `#0F1113` | 13.64:1 | 4.5:1 | pass |
| textSecondary on button | `#D7DCDA` | `#1C2124` | 11.71:1 | 4.5:1 | pass |
| textTertiary on bg (rowTitleIdle) | `#B9BFBD` | `#0F1113` | 10.14:1 | 4.5:1 | pass |
| textMuted on bg (bodyMuted, values) | `#8A918F` | `#0F1113` | 5.88:1 | 4.5:1 | pass |
| textMuted on sheet | `#8A918F` | `#141719` | 5.60:1 | 4.5:1 | pass |
| textMuted on surface | `#8A918F` | `#15181B` | 5.54:1 | 4.5:1 | pass |
| **textFaint on bg** (meta, section labels, subtitles) | `#6E7573` | `#0F1113` | **4.01:1** | 4.5:1 | **FAIL** |
| **textFaint on sheet** | `#6E7573` | `#141719` | **3.82:1** | 4.5:1 | **FAIL** |
| **textFaint on surface** | `#6E7573` | `#15181B` | **3.78:1** | 4.5:1 | **FAIL** |
| **textFaint on footer** | `#6E7573` | `#111417` | **3.92:1** | 4.5:1 | **FAIL** |
| **textDim on bg** (metaIdle — idle site meta) | `#5F6664` | `#0F1113` | **3.22:1** | 4.5:1 | **FAIL** |
| **textDim on button** (disabled pill label) | `#5F6664` | `#1C2124` | 2.76:1 | (exempt if inactive) | FAIL as text |
| textDisabled on bg | `#4A5150` | `#0F1113` | 2.33:1 | (exempt if inactive) | FAIL as text |
| **tabInactive on footer** (dashboard tab labels) | `#767D7B` | `#111417` | **4.39:1** | 4.5:1 | **FAIL** |
| pillText on button | `#A9B0AE` | `#1C2124` | 7.36:1 | 4.5:1 | pass |
| pillText on surface (address host) | `#A9B0AE` | `#15181B` | 8.07:1 | 4.5:1 | pass |
| monogramText on monogramOpen | `#C7CECC` | `#20252A` | 9.66:1 | 4.5:1 | pass |
| textMuted on raised (idle monogram) | `#8A918F` | `#181B1E` | 5.38:1 | 4.5:1 | pass |
| jade on bg | `#7FC8A9` | `#0F1113` | 9.67:1 | 4.5:1 | pass |
| jadeCode on surface | `#9FD8C0` | `#15181B` | 11.08:1 | 4.5:1 | pass |
| bg on jade (primary label) | `#0F1113` | `#7FC8A9` | 9.67:1 | 4.5:1 | pass |
| danger on bg | `#D66A5A` | `#0F1113` | 5.47:1 | 4.5:1 | pass |
| danger on surface | `#D66A5A` | `#15181B` | 5.15:1 | 4.5:1 | pass |
| danger on dangerSurface | `#D66A5A` | `#241C1D` | 4.82:1 | 4.5:1 | pass |
| **dangerMuted on bg** (pill sublabel, e.g. panic's) | `#8A6A62` | `#0F1113` | **3.89:1** | 4.5:1 | **FAIL** |
| warning on bg | `#D6A45B` | `#0F1113` | 8.40:1 | 4.5:1 | pass |
| readerBody on bgReader | `#CFC8BC` | `#12100D` | 11.43:1 | 4.5:1 | pass |
| readerMuted on bgReader | `#8A857C` | `#12100D` | 5.18:1 | 4.5:1 | pass |
| **readerHost on bgReader** | `#7C776E` | `#12100D` | **4.27:1** | 4.5:1 | **FAIL** |
| icon on bg (non-text) | `#9AA1A0` | `#0F1113` | 7.19:1 | 3:1 | pass |
| chevron on bg (non-text) | `#7E8583` | `#0F1113` | 5.02:1 | 3:1 | pass |
| **AppToggle off track vs bg** | `#232729` | `#0F1113` | **1.26:1** | 3:1 | **FAIL** |
| **AppToggle off knob vs track** | `#4A5150` | `#232729` | **1.85:1** | 3:1 | **FAIL** |
| **PIN dot (empty) vs bg** | `#3A403E` | `#0F1113` | **1.79:1** | 3:1 | **FAIL** |
| **idle dot vs bg** | `#3E4644` | `#0F1113` | **1.95:1** | 3:1 | **FAIL** |
| **StatusRail idle (line09) vs bg** | white 9 % | `#0F1113` | **1.25:1** | 3:1 | **FAIL** |
| keypad key fill vs bg | `#15181B` | `#0F1113` | 1.06:1 | 3:1 | FAIL (the digit carries it; acceptable) |
| jade toggle on vs bg | `#7FC8A9` | `#0F1113` | 9.67:1 | 3:1 | pass |

**Every AA failure, in one list:** `textFaint` on all four surfaces it sits
on (it is the most-used text colour in the app, 52 references — every
meta line, section label and setting subtitle), `textDim` idle meta,
`tabInactive` dashboard tab labels, `dangerMuted` sublabels, `readerHost`;
and as non-text: the off switch (track and knob), empty PIN dots, the idle
dot and the idle status rail. An off `AppToggle` is close to invisible
against the page: its track is 1.26:1. Hairlines (1.14:1 at 6 %) are
decorative and exempt, but they are also the *only* structure on most
screens, so where they disappear, so does the layout.

## 3. What the current design does better than the majors

Said plainly, because the restyle should keep it:

1. **Honest state.** Jade means "live" and nothing else; danger is never a
   fill. Chrome's and Samsung's incognito modes signal state with a
   whole-UI colour swap that tells you nothing about what is protected;
   Container's per-row live rail and per-pill route label (`SOCKS5`, `TOR`)
   tell you something true about each site.
2. **No dark patterns, no counts that brag.** There is no leak count
   (user's ruling), no gamified "trackers blocked" score on the home screen,
   unlike Brave's and DuckDuckGo's counters (see `RESEARCH.md`). The Today
   tally exists but is a ledger, not a trophy.
3. **One accent, used sparingly.** A screen has at most one jade action. The
   majors' toolbars carry three or four coloured affordances.
4. **Technical facts in a technical face.** Hosts, proxy addresses and
   rule counts in Plex Mono read as facts, not marketing. That is a real
   trust signal for the people who check.
5. **Its own drawn icon set**, consistent stroke, no icon-font dependency,
   guarded by a test. That is the foundation a redesign can build on cheaply.
6. **Restraint in motion and decoration** — nothing flashes, which matters
   for an app whose core moments (lock, panic, a refused proxy) are tense.
7. **The responsive work is real**: 320 × 568, text scale 1.3 and 2.0 and
   landscape are under test (`small_screen_layout_test.dart`,
   `responsive_layout_test.dart`).

## 4. Where it fails the bounced user

Each item names the screen and the number.

1. **Too small to read at default scale.** 43 % of literal text sizes are
   12.5 px or under; meta lines are 10.5 px; section labels 10 px uppercase
   with +1.0 tracking; the address pill's host is **11.5 px** and the route
   label **9.5 px** (`2b`). Chrome's omnibox and Material's body are 16 sp.
   The bounced user's first impression of `2b` — the screen they spend the
   most time on — is a URL they cannot read.
2. **Low-contrast secondary text where the explanations live.** The text
   that explains what a setting does (`SettingRow` subtitle, 11 px
   `textFaint`, 4.01:1) fails AA and is also the smallest. The UI hides its
   own explanations.
3. **Targets below 48 dp.** 28 of 29 `IconTap` call sites are under 48 dp;
   the reload/stop and shield in the pill are 28 dp, and the shield is the
   single entry to every privacy control (`6c`).
4. **Surfaces you cannot tell apart.** Eleven background tones within 1.26:1
   of each other; sheets (`#141719`) on the page (`#0F1113`) differ by
   1.05:1, so a sheet reads only through its shadow. Off switches are
   1.26:1 against the page (§2).
5. **Jargon set as the loudest type.** `SOCKS5`, `HTTP`, `TOR`, `N OPEN`,
   section labels in tracked caps — the uppercase machinery labels are the
   most *styled* text on several screens, while the plain-language
   explanation beside them is the faintest. The hierarchy is inverted for
   someone who does not know what SOCKS5 is. (Copy is frozen; its
   *setting* is not.)
6. **No identity.** The launcher icon is Flutter's default. A user arriving
   from the Play Store or a friend's recommendation meets a generic blue
   chevron in the app drawer, which is the opposite of a trust signal for a
   privacy product.
7. **Cold by construction.** Near-black at `#0F1113`, grey-green text,
   hairlines and no surfaces: the instrument-panel look reads as "for
   experts" (see `RESEARCH.md` on intimidating security UI). Dark-only also
   forgoes the positive-polarity legibility advantage for reading long
   setting explanations in daylight (`RESEARCH.md` §dark vs light).
8. **No visual metaphor for the one idea that matters.** "Every site in its
   own container" is invisible: a site row looks like a bookmark row. The
   bounced user cannot see the isolation they are getting.

## 5. Blast radius (for phase 7)

| Measure | Count |
|---|---|
| Dart files in `lib/` | 176 (103 under `lib/ui/`, 69 feature view files) |
| Files reading `C.*` | **71** (477 references) |
| Files reading `T.*` | **27** (44 references) |
| Direct `ui(size: …)` calls | **175 in 52 files**; `mono(…)` 16 |
| Literal `EdgeInsets` | 156 in 54 files; `SizedBox` spacers 207 |
| Literal radii | 81 (19 distinct) |
| `Colors.*` / `withValues(alpha:)` in `lib/` | 22 / 20 |
| Test files | 129 (`*_test.dart`) |
| Tests referencing `C.*` | **24 files, 90 references** — all symbolic (`C.jade`), so a token *value* change does not break them; a token *removal or rename* does |
| Tests asserting literal hex | **2 files**: `test/app_theme_test.dart` (6: `bg`, `jade` via theme, `handle`, `pillText`, `dangerPanel`, `pinError`), `test/ui/core/pin_widgets_test.dart` (1: `#4A3634`) |
| Tests asserting font sizes | 1 file: `reader_screen_test.dart` (reader sizes 25 / 15.5 — reader's own scale) |
| Tests using `findGlyph` / `findIconTap` / `AppGlyph` | 35 files — they find icons by glyph, so redrawing a glyph is free; renaming or removing one is not |
| Tests using `find.text` | 949 calls in 58 files — copy is frozen, so these are the copy guard |
| Guard tests to keep green | `test/no_glyphs_test.dart`, `test/ui/small_screen_layout_test.dart`, `test/ui/responsive_layout_test.dart`, `test/android_theme_test.dart` |

What this means: **the restyle cannot be a token swap.** Because sizes,
paddings and radii are literals at 50-odd call sites, the type scale and
density changes touch every feature view. The cheap part is colour: change
`C.*` values and 71 files follow, and only 7 literal-hex test expectations
move. The tests mostly find widgets by text and glyph, so they guard copy
and structure and will tolerate a visual change — which is what we want.

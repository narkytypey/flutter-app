# Direction B — Instrument: tokens

Dark only. Every value below is also in `tokens.css` (the CSS used by
`screens.html`). Every contrast ratio is **measured** with
`tools/contrast.py`; the pairs are in `contrast-pairs.txt` in this folder
and the table at the end of "Colour" is its output, pasted unedited.

## Colour

### Surfaces — four tones

Each step is at least 1.16:1 from its neighbour (the current set's eleven
darks span 1.26:1 end to end).

| Role | Hex | Purpose | Replaces (`C.*`) |
|---|---|---|---|
| `--ink` | `#121110` | The page: every scaffold, top and bottom bars, panic (`3c`) | `bg`, `bgPanic` (retired: panic is not a different colour), `footer` (retired: bars are the page with a rule), `bgRecents` (unused, retired) |
| `--surface-group` | `#22201D` | One grouped surface for rows that belong together; the address pill; inputs on the page; keypad keys; skeleton; bar tracks; idle monograms | `surface`, `raised` (merged), `skeleton`, `barTrack` |
| `--surface-sheet` | `#302D29` | Bottom sheets (`6a`, `6c`, `7b`, `7c`, `10c`, ☰, pickers) | `sheet` |
| `--surface-raised` | `#403C37` | Selected chip/tab, neutral buttons, open monograms, groups inside a sheet, inputs on a sheet | `selected`, `button`, `monogramOpen` |

Measured steps: group/ink **1.16:1**, sheet/group **1.19:1**, raised/sheet
**1.25:1**, sheet/ink **1.38:1**.

### Text — three tones

| Role | Hex | Purpose | Replaces |
|---|---|---|---|
| `--text-1` | `#EDEAE4` | Titles, row names, the host in the pill, filled PIN dots, an *on* switch's track | `textPrimary`, `textSecondary`, `pillText`, `monogramText` |
| `--text-2` | `#CBC4B9` | Explanations, row subtitles, values, idle row names, icons, inactive tabs | `textTertiary`, `textMuted`, `icon`, `tabInactive`, `dangerMuted` (retired: `8c`'s body is text-2 on the wash) |
| `--text-3` | `#A8A095` | Meta, captions, chevrons, footnotes, inert controls. **Never on `--surface-raised`** (4.23:1 there) | `textFaint`, `textDim`, `textDisabled`, `chevron` |

There is no "dim" or "disabled" text colour. An inert control keeps a
readable tone and *loses its container* (no fill, no outline, no target
ring), so it reads as not-a-button rather than as not-readable. The lowest
text ratio anywhere is **5.30:1** (text-3 on sheet).

### State

| Role | Hex | Purpose | Replaces |
|---|---|---|---|
| `--jade` | `#7FC8A9` | The live light (an open site, the page that is live); the one affirmative action on a screen. Kept from the current app: continuity, and it reads 9.64:1 on ink | `jade` |
| `--on-jade` | `#121110` | Label on a jade fill | — (was `bg`) |
| `--danger` | `#EE8D79` | Danger as text and as a 1.5 dp outline. Warmer and lighter than `#D66A5A` so it passes on every surface (4.54:1 on raised, the worst) | `danger`, `pinError` |
| `--danger-wash` | `#2C201D` | The small tinted panel (`8c` banner, `10c` Delete button) — never a screen | `dangerSurface`, `dangerPanel` |
| `--amber` | `#E0B266` | The *opening* light (amber before live); the `JS` badge | `warning` |
| `--code` | `#D9CFB8` | Code text (`2a` custom CSS/JS, `10e`). Parchment, not jade: code is not live | `jadeCode` |

### Lines — two alphas and one solid edge (was nine alphas)

| Role | Value | Purpose | Replaces |
|---|---|---|---|
| `--line-soft` | `#EDEAE4` at 8 % | Rule between rows *inside* a group | `line05`–`line08` |
| `--line` | `#EDEAE4` at 14 % | A group's outline; the rule under a header or above a bar | `line09`–`line16` |
| `--edge` | `#958D82` | Anything a user must see as a boundary: an off switch's outline, an input's border, an empty PIN dot, the idle light, the sheet handle. ≥ 3.34:1 on every surface | `trackOff`, `knobOff` (→ text-3), `idleDot`, `pinEmpty`, `handle` |
| `--focus` | `#EDEAE4` | 2 dp focus ring, 2 dp offset | — (new) |

Hairlines are kept as structure *inside* a group (rows) and as the one rule
under a header; they are no longer the only thing that holds a screen
together.

### Reader (`6b`)

| Role | Hex | Replaces |
|---|---|---|
| `--reader-bg` | `#15120E` | `bgReader` |
| `--reader-title` | `#EFE8DC` | `readerTitle` |
| `--reader-body` | `#D3CBBE` | `readerBody` |
| `--reader-muted` | `#A39A8C` | `readerMuted`, `readerHost` (was 4.27:1, now 6.72:1) |

The "softer" theme (◑) uses title → `--reader-body`, body →
`--reader-muted`; both measured below.

### Workspace markers (`10a`, `10b`; data, not identity colour)

`#C9B48A` brass, `#8FA5C8` steel, `#E0B266` amber, `#C89BB4` mauve,
`#A8A095` stone. Marker 0 is **no longer jade** (it was `#7FC8A9`), so a
workspace marker can never be mistaken for a live light. All ≥ 7.30:1 on
ink.

### Switches, dots and lights (how state is drawn)

| Element | Off / idle | On / live |
|---|---|---|
| Switch (52 × 32 visual in a 48 dp row target) | Unfilled track, 2 dp `--edge` outline, 16 dp `--text-3` knob | `--text-1` track, 24 dp `--ink` knob with a check. **Not jade** |
| PIN dot (14 dp) | 2 dp `--edge` ring | `--text-1` fill; error: 2 dp `--danger` ring |
| Site light (10 dp) | 2 dp `--edge` ring, hollow | `--jade` fill (live), `--amber` fill (opening) |
| Radio (20 dp) | 2 dp `--edge` ring | 2 dp `--text-1` ring + 10 dp `--text-1` dot |
| Chosen row in a picker | — | `--text-1` check icon (not jade) |

Shape *and* colour carry every state, so none relies on colour alone
(WCAG 1.4.1).

### Measured contrast (`contrast-pairs.txt`)

| Pair | FG | BG | Ratio | Needs | Result |
|---|---|---|---|---|---|
| text-1 on ink | `#EDEAE4` | `#121110` | 15.71:1 | 4.5:1 | pass |
| text-1 on surface-group | `#EDEAE4` | `#22201D` | 13.53:1 | 4.5:1 | pass |
| text-1 on surface-sheet | `#EDEAE4` | `#302D29` | 11.41:1 | 4.5:1 | pass |
| text-1 on surface-raised | `#EDEAE4` | `#403C37` | 9.11:1 | 4.5:1 | pass |
| text-1 on danger-wash | `#EDEAE4` | `#2C201D` | 13.14:1 | 4.5:1 | pass |
| text-2 on ink | `#CBC4B9` | `#121110` | 10.90:1 | 4.5:1 | pass |
| text-2 on surface-group | `#CBC4B9` | `#22201D` | 9.39:1 | 4.5:1 | pass |
| text-2 on surface-sheet | `#CBC4B9` | `#302D29` | 7.92:1 | 4.5:1 | pass |
| text-2 on surface-raised | `#CBC4B9` | `#403C37` | 6.32:1 | 4.5:1 | pass |
| text-2 on danger-wash (8c body) | `#CBC4B9` | `#2C201D` | 9.11:1 | 4.5:1 | pass |
| text-3 on ink | `#A8A095` | `#121110` | 7.30:1 | 4.5:1 | pass |
| text-3 on surface-group | `#A8A095` | `#22201D` | 6.29:1 | 4.5:1 | pass |
| text-3 on surface-sheet | `#A8A095` | `#302D29` | 5.30:1 | 4.5:1 | pass |
| jade text on ink (Save, New workspace) | `#7FC8A9` | `#121110` | 9.64:1 | 4.5:1 | pass |
| jade text on surface-group | `#7FC8A9` | `#22201D` | 8.31:1 | 4.5:1 | pass |
| jade text on surface-sheet (6c Edit) | `#7FC8A9` | `#302D29` | 7.00:1 | 4.5:1 | pass |
| on-jade label on jade fill | `#121110` | `#7FC8A9` | 9.64:1 | 4.5:1 | pass |
| danger text on ink | `#EE8D79` | `#121110` | 7.83:1 | 4.5:1 | pass |
| danger text on surface-group | `#EE8D79` | `#22201D` | 6.75:1 | 4.5:1 | pass |
| danger text on surface-sheet | `#EE8D79` | `#302D29` | 5.69:1 | 4.5:1 | pass |
| danger text on surface-raised (7b Remove site) | `#EE8D79` | `#403C37` | 4.54:1 | 4.5:1 | pass |
| danger text on danger-wash | `#EE8D79` | `#2C201D` | 6.55:1 | 4.5:1 | pass |
| amber on ink | `#E0B266` | `#121110` | 9.64:1 | 4.5:1 | pass |
| amber on surface-group | `#E0B266` | `#22201D` | 8.30:1 | 4.5:1 | pass |
| code on surface-group | `#D9CFB8` | `#22201D` | 10.50:1 | 4.5:1 | pass |
| reader-title on reader-bg | `#EFE8DC` | `#15120E` | 15.33:1 | 4.5:1 | pass |
| reader-body on reader-bg | `#D3CBBE` | `#15120E` | 11.61:1 | 4.5:1 | pass |
| reader-muted on reader-bg (host, label) | `#A39A8C` | `#15120E` | 6.72:1 | 4.5:1 | pass |
| reader-soft-title on reader-bg (soft) | `#D3CBBE` | `#15120E` | 11.61:1 | 4.5:1 | pass |
| reader-soft-body on reader-bg (soft) | `#A39A8C` | `#15120E` | 6.72:1 | 4.5:1 | pass |
| switch on: knob ink on track text-1 | `#121110` | `#EDEAE4` | 15.71:1 | 3.0:1 | pass |
| switch on: track text-1 vs ink | `#EDEAE4` | `#121110` | 15.71:1 | 3.0:1 | pass |
| switch on: track text-1 vs sheet | `#EDEAE4` | `#302D29` | 11.41:1 | 3.0:1 | pass |
| edge (switch-off outline, input border, empty PIN dot, idle light) vs ink | `#958D82` | `#121110` | 5.76:1 | 3.0:1 | pass |
| edge vs surface-group | `#958D82` | `#22201D` | 4.96:1 | 3.0:1 | pass |
| edge vs surface-sheet | `#958D82` | `#302D29` | 4.18:1 | 3.0:1 | pass |
| edge vs surface-raised | `#958D82` | `#403C37` | 3.34:1 | 3.0:1 | pass |
| switch off: knob text-3 vs ink (track is unfilled) | `#A8A095` | `#121110` | 7.30:1 | 3.0:1 | pass |
| switch off: knob text-3 vs sheet | `#A8A095` | `#302D29` | 5.30:1 | 3.0:1 | pass |
| PIN dot filled text-1 vs ink | `#EDEAE4` | `#121110` | 15.71:1 | 3.0:1 | pass |
| PIN dot error ring danger vs ink | `#EE8D79` | `#121110` | 7.83:1 | 3.0:1 | pass |
| live light jade vs ink | `#7FC8A9` | `#121110` | 9.64:1 | 3.0:1 | pass |
| live light jade vs surface-group (in the pill) | `#7FC8A9` | `#22201D` | 8.31:1 | 3.0:1 | pass |
| opening light amber vs surface-group | `#E0B266` | `#22201D` | 8.30:1 | 3.0:1 | pass |
| focus ring text-1 vs ink | `#EDEAE4` | `#121110` | 15.71:1 | 3.0:1 | pass |
| icon text-2 vs ink | `#CBC4B9` | `#121110` | 10.90:1 | 3.0:1 | pass |
| icon text-2 vs surface-sheet | `#CBC4B9` | `#302D29` | 7.92:1 | 3.0:1 | pass |
| panic outline danger vs ink | `#EE8D79` | `#121110` | 7.83:1 | 3.0:1 | pass |
| neutral button fill raised vs ink (container edge) | `#403C37` | `#121110` | 1.72:1 | 1.15:1 | pass |
| surface-group vs ink | `#22201D` | `#121110` | 1.16:1 | 1.15:1 | pass |
| surface-sheet vs surface-group | `#302D29` | `#22201D` | 1.19:1 | 1.15:1 | pass |
| surface-raised vs surface-sheet | `#403C37` | `#302D29` | 1.25:1 | 1.15:1 | pass |
| surface-sheet vs ink | `#302D29` | `#121110` | 1.38:1 | 1.15:1 | pass |
| marker 0 brass vs ink | `#C9B48A` | `#121110` | 9.32:1 | 3.0:1 | pass |
| marker 1 steel vs ink | `#8FA5C8` | `#121110` | 7.53:1 | 3.0:1 | pass |
| marker 2 amber vs ink | `#E0B266` | `#121110` | 9.64:1 | 3.0:1 | pass |
| marker 3 mauve vs ink | `#C89BB4` | `#121110` | 7.91:1 | 3.0:1 | pass |
| marker 4 stone vs ink | `#A8A095` | `#121110` | 7.30:1 | 3.0:1 | pass |

**Nothing is below its threshold.** Lowest text pairing: 4.54:1 (danger on
raised — used only for `7b`'s `Remove site`); lowest text pairing in
common use 5.30:1 (text-3 on sheet). Lowest meaningful mark: 3.34:1 (edge on
raised).

## Jade budget

One jade *role* per screen: either live indicators or the single affirmative
action. Positions (switch on, chosen check, active tab, step bar) are never
jade.

| Screen | Jade | Taken off (was jade in the current app) |
|---|---|---|
| `1b` | the live light on each open site's row (one signal, repeated) | — |
| `5b` | the `+` (Add site) fill — no site is live in an empty workspace | — |
| `2b` | the live light in the pill | the `N OPEN` chevron |
| `2a` | `Save` | active tab underline, radio dot, page-zoom value and slider, code |
| `2c` | the viewed container's light | the header count, background rails at 45 % |
| `2d` | none | every on switch, picker checks |
| `3a`/`4c`/`9b`/`9c` | none (`9b`'s fingerprint is the affirmative action when shown) | the vault mark |
| `4a`/`4b`/`5a` | `Continue` / `Add your first site` | the step bar, `5a`'s four checks, on switches |
| `5c` | none | the category bars |
| `6a` | `Keep blocked` (canvas; see BRIEF) | — |
| `6c` | `Edit` | on switches |
| `7c` | `Discard` | — |
| `8a` | none (steps are drawn in text-1/text-3) | the 60 % progress line, done checks |
| `8b` | `Try again` | — |
| `8c` | `Reconnect` | — |
| `3c` | none | the three status words (`DESTROYED` etc. are now text-1) |
| `10a` | `New workspace` | marker 0 |
| `10b` | `Save` | the name field's border, radio, marker 0 |
| `10d` | `New script` | on switches |
| `10e` | `Save` | code text, `+ Add site` (now text-1) |

## Type

### Families

| Family | Licence | Use | Bundled size (measured 2026-10-05 from Google Fonts' static TTFs, subset with `pyftsubset`) |
|---|---|---|---|
| **IBM Plex Sans** Regular 400, Medium 500, SemiBold 600 (static) | SIL OFL 1.1 | Every word of UI | Full static: 205 KB each, **615 KB**. Latin-1 + punctuation subset: 53 KB each, **159 KB**. Latin + Latin-Ext + Vietnamese: 103 KB each, **309 KB** (recommended). The variable `[wdth,wght]` file is 525 KB and carries a width axis Instrument does not use. |
| **IBM Plex Mono** Regular 400, Medium 500 | SIL OFL 1.1 | Values only: hosts, proxy addresses, ports, counts, PIN digits, code, rule counts | Already bundled: 272 KB (135.6 + 136.7). Not changed. |
| ~~Figtree~~ | — | Retired | −61 KB |

**Net:** today 335 KB → **581 KB** with the recommended subset (+246 KB), or
436 KB with the Latin-1 subset. Static weights avoid the `wght`-variation
workaround `typography.dart` needs for Figtree today. Glyphs outside the
subset (page titles in Greek, Cyrillic, CJK…) fall back to the system font,
as they do with Figtree now.

### Scale

Smallest size anywhere: **12 sp** (badges, the dashboard tab labels).
Body is 16 sp. Line heights are absolute so rows grow predictably.

| Role | `T.*` name | Family | Size sp | Weight | Line height | Tracking | Colour |
|---|---|---|---|---|---|---|---|
| Display number (Today total) | **`display`** (new) | Mono | 40 | 500 | 48 | −0.01 em | text-1 |
| Setup step title | `stepTitle` | Sans | 26 | 600 | 32 | −0.01 em | text-1 |
| Screen title (Settings, Today, Workspaces…) | `screenTitle` | Sans | 22 | 600 | 28 | 0 | text-1 |
| Sheet title | `sheetTitle` | Sans | 20 | 600 | 26 | 0 | text-1 |
| Centred form title (`2a`, `10b`, `10e`) | `appBarTitle` | Sans | 18 | 600 | 24 | 0 | text-1 |
| Keypad digit | **`keypad`** (new) | Mono | 28 | 400 | 32 | 0 | text-1 |
| Row title | `rowTitle` | Sans | 16 | 500 | 22 | 0 | text-1 |
| Row title, idle | `rowTitleIdle` | Sans | 16 | 500 | 22 | 0 | text-2 (idle is said by the hollow light, not by fading the name) |
| Body | `body` | Sans | 16 | 400 | 24 | 0 | text-1 |
| Button label | **`label`** (new) | Sans | 16 | 600 (jade) / 500 (neutral) | 20 | 0 | on-jade / text-1 |
| Address host | **`readout`** (new) | Mono | 15 | 500 | 20 | 0 | text-1 |
| Body, muted (explanations) | `bodyMuted` | Sans | 15 | 400 | 22 | 0 | text-2 |
| Row subtitle | **`sub`** (new) | Sans | 14 | 400 | 20 | 0 | text-2 |
| Value in a row (proxy address, count) | **`value`** (new) | Mono | 14 | 400 | 20 | 0 | text-2 |
| Section label | `sectionLabel` | Sans | 14 | 600 | 20 | 0, **sentence case** via CSS | text-2 |
| Section label, live | `sectionLabelLive` | Sans | 14 | 600 | 20 | 0 | jade (kept for API; no screen uses it) |
| Meta (hosts in rows are Mono 13) | `meta` | Sans | 13 | 400 | 18 | 0 | text-3 |
| Meta, idle | `metaIdle` | Sans | 13 | 400 | 18 | 0 | text-3 (merged with `meta`) |
| Summary beside a bar | `barSummary` | Sans | 13 | 400 | 18 | 0 | text-3 |
| Badge (`SOCKS5`, `WIPES ON EXIT`, `PDF`) | `barBadge` | Sans | 12 | 600 | 16 | +0.02 em; caps kept only when the string names a protocol/format, otherwise sentence case | text-2 on a `--line` outline |
| Code | `code` | Mono | 13 | 400 | 22 | 0 | `--code` |
| Tab label (dashboard bar) | **`tab`** (new) | Sans | 12 | 500 | 16 | 0 | text-1 selected / text-2 |
| Reader title / body | (reader's own) | Sans | 26/30/34 · 17/19/21 | 600 · 400 | 1.25 · 1.7 | 0 | reader tones |

**Rule for mono:** if a string is a *name of a thing* it is Sans (`SOCKS5`
as a mode, `Tunnel`, `Last worked`); if it is a *value you could copy*
it is Mono (`127.0.0.1:9050`, `forum.example.com`, `312`, `2/14`).
In a mixed meta line (`forum.example.com · Personal`) the host is a Mono
span inside a Sans line; the string is unchanged.

## Space, shape, elevation

- **Spacing scale (dp):** 4, 8, 12, 16, 20, 24, 32, 48. Screen gutter 16
  (20 on setup/lock screens). Rows: 16 vertical padding.
- **Row heights (minimum; rows grow with text):** one-line 56, two-line 72,
  settings row with subtitle 72+.
- **Radii:** 6 (badges), 10 (monograms, small chips), 14 (inputs, row
  buttons), 18 (groups, cards), 28 (sheet top corners), full (pill, primary
  buttons, switches). Seven values, down from nineteen.
- **Borders:** a group is `--surface-group` with a 1 dp `--line` outline;
  rows inside it are separated by `--line-soft`. Inputs: 1.5 dp `--edge`,
  2 dp `--text-1` when focused. Danger outline: 1.5 dp `--danger`.
- **Elevation:** one level. Sheets are lighter (`--surface-sheet`, 1.38:1
  over ink), have a 1 dp `--line` top edge and `0 −12 40 black 55 %`.
  Nothing else casts a shadow: tone does the separating.

## Touch targets

**48 × 48 dp minimum for every tappable thing**, 8 dp apart. Specifically:
pill shield and reload 48 dp (visual 24 dp icon); panic 48 dp; bottom-bar
icons 48 dp; `N OPEN` 48 dp tall; chips 48 dp tall (visual 36); form
header × and back 48 dp; switches take their whole row (56–72 dp);
keypad keys 64 dp (56 below 640 dp tall); `2c` row × 48 dp; primary
buttons 52 dp.

## Motion

Two moments move; everything else is an *effect* that never bounces.

| Moment | What moves | Spec |
|---|---|---|
| **Unlock** (`3a`/`9b` → dashboard) | The vault mark's lid seam lifts 2 dp and the case fades into the dashboard | 320 ms, spring damping 0.9 / stiffness 300 (no overshoot visible at 0.9) |
| **A protective change takes effect** (reopen-in-place after `6c`, New identity, route change) | The pill's case outline redraws (stroke-dash sweep, solid ↔ broken) and the light goes amber → jade | 320 ms sweep; the light change is the same 150 ms effect as everywhere |
| Everything else (sheets, pages, toggles) | position/opacity | effects spring damping 1.0 / stiffness 1400 (≈ 150 ms), `cubic-bezier(0.2,0,0,1)` in CSS |

With *Remove animations* on, the two moments become 100 ms cross-fades
and the effects are instant.

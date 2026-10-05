# Direction C — Rooms: tokens

Every ratio below was produced by
`python3 docs/design-exploration/tools/contrast.py --table direction-c-rooms/contrast-pairs.txt`
(202 pairs, 0 below their minimum). The full table is at the end. CSS
custom properties with the same values are in `tokens.css`.

Two themes: **Paper** (light, the default) and **Ink** (dark). The app
follows the system setting. Nothing depends on which vault is open.

## 1. Colour roles

### 1.1 Surfaces (four, plus room tints)

| Role | Paper | Ink | Purpose | Maps to `C.*` |
|---|---|---|---|---|
| `page` | `#F2EBE0` | `#1A1815` | Scaffold of every screen; the panic and lock screens too | `bg`, `bgPanic` (merged), `footer` |
| `box` | `#FFFCF6` | `#37332D` | A site's card ("box"), settings groups, the address pill, inputs on a room | `surface`, `raised`, `monogramOpen` (retired: monograms are wall-filled now) |
| `sheet` | `#FBF7EF` | `#2E2A25` | Bottom sheets | `sheet` |
| `sunken` | `#E4DCCD` | `#0A0908` | Keypad keys, text fields on `page`, the code box, progress tracks | `skeleton`, `barTrack`, `button` (as a fill), `handle` |

Separation (implication 4, target ≥ 1.15 between neighbours that touch):
box on a room tint 1.33–1.35 (Paper) / 1.18–1.19 (Ink); room tint on page
1.15–1.16 (Paper) / 1.19–1.20 (Ink); box on page 1.16 (Paper) / 1.41 (Ink);
sunken on page 1.15 (Paper) / 1.12 (Ink). Sheet vs page is 1.11 (Paper) /
1.24 (Ink) —
a sheet always sits over a scrim and has a 28 dp top radius and a shadow, so
it does not rely on the step.

### 1.2 Ink (text and marks)

| Role | Paper | Ink | Purpose | Maps to `C.*` |
|---|---|---|---|---|
| `ink` | `#1E1B16` | `#F2EDE3` | Titles, row names, body, the primary pill's fill, selected marks (check, radio, switch on, filled door, filled PIN dot) | `textPrimary`, `textSecondary`, `pillText`, `jadeCode` |
| `ink2` | `#4A453C` | `#CEC7B9` | Explanations, section labels, values, icons | `textTertiary`, `textMuted`, `icon`, `tabInactive`, `dangerMuted` (retired) |
| `ink3` | `#635C50` | `#ABA394` | Meta lines, hints, and every **meaningful outline**: off switch track and knob, empty PIN dot, hollow (idle) door, input borders, outlined pills, the throwaway's dashed wall | `textFaint`, `textDim`, `chevron`, `idleDot`, `pinEmpty`, `trackOff`, `knobOff` |
| `onInk` | `#F2EBE0` | `#1A1815` | Label on the primary (ink) pill | (was `bg` on jade) |
| `hairline` | ink at 10 % | ink at 12 % | Decorative only (inside a card between rows) | `line05`–`line09` (merged) |
| `divider` | ink at 18 % | ink at 20 % | Card borders, decorative | `line10`–`line16` (merged) |
| inert | any role at 38 % opacity | same | Disabled controls (exempt from 1.4.3/1.4.11) | `textDisabled` |

`ink3` is the lowest text tone and it is **4.57:1 or better on every surface
and tint it sits on** (lowest: the throwaway hatch stripe, 4.57:1; Fern
tint 4.79:1; on page 5.58:1 Paper / 7.08:1 Ink).

### 1.3 Rooms — the five workspace markers, redrawn as one family

Each marker index keeps its old hue family so existing workspaces keep their
look: 0 jade → **Fern**, 1 blue → **Lake**, 2 amber → **Ochre**, 3 mauve →
**Plum**, 4 grey → **Graphite** (cooled to slate so it never reads as the
neutral ink outline). No room is red: red is danger only.

Each room has four values. `wall` is the frame colour (≥ 3:1 against
everything it borders), `tint` the room's floor, `roomInk` text in the room's
colour, `onWall` the monogram letters on a wall-filled tile.

| Room | Paper wall | Paper tint | Paper roomInk | Ink wall | Ink tint | Ink roomInk |
|---|---|---|---|---|---|---|
| 0 Fern | `#2F7A55` | `#C7E2D1` | `#1E5A3C` | `#6DC59A` | `#192B22` | `#A8E3C5` |
| 1 Lake | `#2C6AA3` | `#CFDDF0` | `#1E4D7A` | `#7FB0E3` | `#1C2938` | `#B5D3F2` |
| 2 Ochre | `#8E6410` | `#EEDAB0` | `#6A4A08` | `#D9AE5C` | `#2F2716` | `#EDD29E` |
| 3 Plum | `#8A4C82` | `#ECD6E8` | `#683862` | `#D79BCC` | `#34222E` | `#EBC6E3` |
| 4 Graphite | `#55595F` | `#DADDDE` | `#3F4247` | `#A9AEB5` | `#25282B` | `#D3D6DB` |

`onWall` is `box` `#FFFCF6` in Paper and `page` `#1A1815` in Ink.

Measured (minimums across the five rooms):

| Pair | Paper min | Ink min | Needs |
|---|---|---|---|
| wall vs page (the chrome frame against the page around it) | 4.39 (Fern) | 7.78 (Lake) | 3:1 |
| wall vs box (pill edge against the pill) | 5.08 (Fern) | 5.51 (Lake) | 3:1 |
| wall vs own tint (frame against the tinted bar) | 3.77 (Fern) | 6.48 (Lake) | 3:1 |
| `onWall` letters on wall (monogram) | 5.08 (Fern) | 7.78 (Lake) | 4.5:1 |
| `roomInk` on own tint | 5.89 (Ochre) | 9.53 (Lake) | 4.5:1 |
| `roomInk` on box | 7.90 (Ochre) | 8.10 (Lake) | 4.5:1 |
| `ink` on tint | 12.45 (Fern) | 12.64 (Lake) | 4.5:1 |
| `ink3` on tint | 4.79 (Fern) | 5.90 (Lake) | 4.5:1 |

(Exact per-room values are in the full table.)

**Where room colour may appear** (the rule that replaces "jade = live"):
chips, the room panel behind a workspace's sites, the monogram tile, the
chrome frame and bars of a site (`2b`, `8a`, `8b`, `8c`), the `2c` card, the
`10a` row's marker, `10b`'s marker picker, `6c`'s header. **Never** on a
button, switch, check, radio, progress bar, count or page content.

### 1.4 State without colour

| State | Mark | Measured |
|---|---|---|
| Open container | **Filled door** (ink) on the site box, row sorted first | ink on box 16.76:1 (Paper) / 10.75:1 (Ink) |
| Idle | **Hollow door** (ink3, 2 dp stroke) | 6.45:1 / 5.02:1 on box |
| Opening | Hollow door + a turning 270° arc (ink) | as above |
| Viewed container (`2c`) | Card lifted onto `box`, full 3 dp wall frame | wall vs box ≥ 5.08 / 5.51 |
| Background container | Flat card on the room tint, 3 dp wall on its leading edge only | wall vs tint ≥ 3.77 / 6.48 |
| **Throwaway** | No room: dashed 2 dp `ink3` wall, diagonal hatch (ink 10 %) instead of a tint, dashed-box glyph instead of a monogram | outline vs hatch 4.57 / 5.42; ink on hatch 11.87 / 11.61 |
| **Tor** route | **Double wall**: the room wall plus a 2 dp inner `ink` line 2 dp inside it, and the onion glyph beside the label `Tor` | inner ink vs Fern tint 12.45 / 12.76 |
| **Wipe on exit** | **Flame** glyph (ink2, 16 dp) on the monogram's corner and before the `WIPES ON EXIT` badge | icon ink2 vs box 9.29 / 7.46 |
| Selected (chip, radio, check) | Ink fill / ink ring / ink check | ink vs box 16.76 / 10.75 |
| Focus | 3 dp Lake wall ring, 2 dp offset | 4.80 / 7.78 on page |

### 1.5 Action and danger

| Role | Paper | Ink | Purpose |
|---|---|---|---|
| `primary` fill | `ink` | `ink` | **The one solid pill per screen.** Label `onInk` 14.49:1 (Paper) / 15.18:1 (Ink). Fill vs page 14.49 / 15.18, vs box 16.76 / 10.75 |
| `secondary` | transparent, 2 dp `ink3` border, `ink` label | same | every other pill |
| `danger` | `#B0362A` | `#F0897A` | Text, outline, panic glyph. On page 5.21:1 / 7.22:1; on box 6.02 / 5.12; on sheet 5.77 / 5.81; on `dangerTint` 4.88 / 6.08 |
| `dangerTint` | `#F7E0DA` | `#3B201C` | The small panel behind `8c`'s banner, the panic square |

`C.jade` is retired as a semantic token. Its value survives only as marker 0's
family (Fern). `C.warning` is retired (opening is shown by shape).

### 1.6 Reader (`6b`)

| Role | Paper | Ink |
|---|---|---|
| `readerBg` | `#F8F2E6` | `#171512` |
| title / body | `#1E1B16` 15.39 / `#2E2A23` 12.80 | `#EFE8DB` 14.96 / `#D8D0C2` 11.91 |
| soft title / soft body (◑) | `#3A352D` 10.91 / `#4F493F` 7.99 | `#CFC7B8` 10.86 / `#B3AB9D` 8.01 |
| host | `#635C50` 5.93 | `#ABA394` 7.29 |

Today the reader is dark only. In Rooms it follows the theme like the rest of
the chrome; the soft pair stays a lower-contrast option that still passes.

## 2. Type

**Figtree** (OFL 1.1; variable, one TTF, **61 KB**, already bundled) is the
UI face, set large, with weights 500–700 for anything that must hold at small
sizes. **IBM Plex Mono** (OFL 1.1; Regular + Medium, **272 KB**, already
bundled) is kept, for values only: hosts, ports, addresses, rule counts, file
names, code. No new font: total stays **333 KB**. Plex Mono is kept rather
than swapped because its slab-ish forms sit well beside Figtree's round ones
and it is already shipped; a new mono would cost ~170 KB for no gain.

All sizes in sp (they scale with the system font scale). Letter-spacing in em.

| Role | `T.*` | Family | Size | Weight | Line height | Tracking | Colour |
|---|---|---|---|---|---|---|---|
| Today total | **new `T.display`** | Figtree | 44 | 700 | 48 | −0.02 | ink |
| Setup step title | `T.stepTitle` | Figtree | 30 | 700 | 36 | −0.01 | ink |
| Tab / screen title | `T.screenTitle` | Figtree | 28 | 700 | 34 | −0.01 | ink |
| Sheet title | `T.sheetTitle` | Figtree | 22 | 700 | 28 | −0.005 | ink |
| Form / pushed-screen title | `T.appBarTitle` | Figtree | 18 | 650 | 24 | 0 | ink |
| Site name (open) | `T.rowTitle` | Figtree | 17 | 650 | 22 | 0 | ink |
| Site name (idle) | `T.rowTitleIdle` | Figtree | 17 | 600 | 22 | 0 | ink (idle is the door, not a fade) |
| Body | `T.body` | Figtree | 16 | 400 | 24 | 0 | ink |
| Explanation | `T.bodyMuted` | Figtree | 15 | 400 | 22 | 0 | ink2 |
| Meta (row second line) | `T.meta` | Figtree | 13 | 500 | 18 | 0.005 | ink3 |
| Meta, idle | `T.metaIdle` | → alias of `T.meta` (retired distinction) | | | | | |
| Section label | `T.sectionLabel` | Figtree | 15 | 700 | 20 | 0 | ink2, **sentence case via CSS** (`LOCK` → "Lock") |
| Section label, live | `T.sectionLabelLive` | **retired** → `T.sectionLabel` | | | | | |
| `N OPEN` pill, counts | `T.barSummary` | Figtree | 15 | 650 | 20 | 0 | ink, sentence case ("3 open") |
| Badges (`SOCKS5`, `WIPES ON EXIT`, `THROWAWAY`) | `T.barBadge` | Figtree | 12 | 700 | 16 | 0.04 | ink / roomInk; acronyms stay caps, phrases sentence case |
| Code | `T.code` | Plex Mono | 14 | 400 | 22 | 0 | ink |
| Host, port, address, count | **new `T.value`** | Plex Mono | 14 | 500 | 20 | 0 | ink2 |
| Address in the pill | **new `T.address`** | Figtree | 16 | 600 | 22 | 0 | ink |
| Button label | **new `T.button`** | Figtree | 16 | 650 | 20 | 0 | onInk / ink |
| Chip label | **new `T.chip`** | Figtree | 15 | 650 | 20 | 0 | onWall / roomInk |
| Keypad digit | **new `T.digit`** | Figtree | 28 | 500 | 32 | 0 | ink |
| Reader title / body | (reader's own) | Figtree | 26/29/32 · 17/19/21 | 700 · 400 | 1.25 · 1.7 | −0.01 | reader roles |

**Smallest text: 12 sp** (`T.barBadge`, always bold 700, always on a ≥ 4.5:1
pairing). Everything else is ≥ 13 sp; body is 16; the address is 16.

Case changes are styling only: the stored string is the inventory's. CSS uses
`.sentence { text-transform: lowercase } .sentence::first-letter {
text-transform: uppercase }` on block or inline-block elements.

## 3. Space, shape, elevation, motion

- **Spacing scale (dp):** 4, 8, 12, 16, 20, 24, 32, 40, 56. Screen side
  gutter 16; inside a room panel 12; between site boxes 8.
- **Radii (dp):** `xs` 8 (badges, door) · `s` 12 (monogram tile, inputs) ·
  `m` 16 (settings group, info box) · `l` 20 (site box) · `xl` 28 (room
  panel, sheet top, `2c` card) · `full` (pills, chips, switches, keys).
- **Borders:** decorative `divider` 1 dp; meaningful `ink3` 2 dp; room wall
  3 dp around the page and on a box's leading edge, 2 dp on the pill.
  Throwaway walls are dashed 6/4.
- **Elevation:** Paper — box on tint: 1 dp `divider` border + `0 1 2` ink 6 %;
  sheet: `0 −8 32` ink 18 % over a 40 % ink scrim. Ink — no shadows; borders
  and the surface step only.
- **Motion:** two moments move.
  1. **Unlock — the door opens.** The lock mark's arched door swings open
     (scaleX 1 → 0.15 about its hinge, 320 ms, spring damping 0.85 /
     stiffness 380) and the room behind it fades to the dashboard (200 ms).
  2. **A protective change takes effect (reopen in place).** The room wall
     around the page redraws itself, stroke-dashoffset 100 % → 0 over
     420 ms, emphasised-decelerate (0.05, 0.7, 0.1, 1). It tells the user the
     room was rebuilt.
  Everything else uses M3 effects springs (damping 1.0, stiffness 1400 /
  700) that never overshoot; sheets 250 ms standard. With reduced motion,
  both moments become a 120 ms cross-fade.
- **Touch targets:** 48 × 48 dp minimum for everything tappable, 8 dp apart.
  The pill's reload and shield are 44 dp visual circles inside 48 dp targets
  (they sit inside a 56 dp pill), the panic square 48, keypad keys 64
  (56 under 640 dp tall), switches 52 × 32 in a 48 dp-tall row, chips 40 tall
  inside a 48 dp hit row, the bottom bar's items 48.

## 4. Mapping summary (`C.*`)

- **Kept, new values:** `bg` (→ page), `surface` (→ box), `sheet`,
  `danger`, `textPrimary` (→ ink), `textMuted` (→ ink2), `textFaint`
  (→ ink3), `markers` (→ `rooms`, five families).
- **Merged:** `bgPanic`, `footer` → page; `raised`, `monogramOpen` → box;
  `skeleton`, `barTrack`, `handle`, `button` fill → sunken;
  `textSecondary`, `pillText`, `jadeCode` → ink; `textTertiary`, `icon`,
  `tabInactive` → ink2; `textDim`, `chevron`, `idleDot`, `pinEmpty`,
  `trackOff`, `knobOff` → ink3; `line05`–`line09` → hairline;
  `line10`–`line16` → divider; `dangerSurface`, `dangerPanel` → dangerTint;
  `pinError` → danger.
- **Retired:** `jade` (as a semantic token), `warning`, `dangerMuted`,
  `bgRecents` (unused), `monogramText` (→ onWall), `selected` (selection is
  ink or wall now).
- **Added:** `ink3` as the outline role, `onInk`, `onWall`, `rooms[i].wall /
  tint / roomInk`, `throwawayHatch`, `focus`, the reader set, `sunken`.

## 5. Full contrast table

| Pair | FG | BG | Ratio | Needs | Result |
|---|---|---|---|---|---|
| light: ink text on paper | `#1E1B16` | `#F2EBE0` | 14.49:1 | 4.5:1 | pass |
| light: ink text on box | `#1E1B16` | `#FFFCF6` | 16.76:1 | 4.5:1 | pass |
| light: ink text on sheet | `#1E1B16` | `#FBF7EF` | 16.06:1 | 4.5:1 | pass |
| light: ink text on sunken | `#1E1B16` | `#E4DCCD` | 12.60:1 | 4.5:1 | pass |
| light: ink2 text on paper | `#4A453C` | `#F2EBE0` | 8.03:1 | 4.5:1 | pass |
| light: ink2 text on box | `#4A453C` | `#FFFCF6` | 9.29:1 | 4.5:1 | pass |
| light: ink2 text on sheet | `#4A453C` | `#FBF7EF` | 8.90:1 | 4.5:1 | pass |
| light: ink2 text on sunken | `#4A453C` | `#E4DCCD` | 6.98:1 | 4.5:1 | pass |
| light: ink3 text on paper | `#635C50` | `#F2EBE0` | 5.58:1 | 4.5:1 | pass |
| light: ink3 text on box | `#635C50` | `#FFFCF6` | 6.45:1 | 4.5:1 | pass |
| light: ink3 text on sheet | `#635C50` | `#FBF7EF` | 6.19:1 | 4.5:1 | pass |
| light: ink3 text on sunken | `#635C50` | `#E4DCCD` | 4.85:1 | 4.5:1 | pass |
| light: ink text on fern tint | `#1E1B16` | `#C7E2D1` | 12.45:1 | 4.5:1 | pass |
| light: ink2 text on fern tint | `#4A453C` | `#C7E2D1` | 6.90:1 | 4.5:1 | pass |
| light: ink3 text on fern tint | `#635C50` | `#C7E2D1` | 4.79:1 | 4.5:1 | pass |
| light: fern ink text on fern tint | `#1E5A3C` | `#C7E2D1` | 5.90:1 | 4.5:1 | pass |
| light: fern ink text on box | `#1E5A3C` | `#FFFCF6` | 7.94:1 | 4.5:1 | pass |
| light: monogram letters on fern wall | `#FFFCF6` | `#2F7A55` | 5.08:1 | 4.5:1 | pass |
| light: fern wall (frame) vs paper | `#2F7A55` | `#F2EBE0` | 4.39:1 | 3.0:1 | pass |
| light: fern wall (frame) vs box | `#2F7A55` | `#FFFCF6` | 5.08:1 | 3.0:1 | pass |
| light: fern wall (frame) vs fern tint | `#2F7A55` | `#C7E2D1` | 3.77:1 | 3.0:1 | pass |
| light: fern wall vs sheet | `#2F7A55` | `#FBF7EF` | 4.87:1 | 3.0:1 | pass |
| light: ink text on lake tint | `#1E1B16` | `#CFDDF0` | 12.47:1 | 4.5:1 | pass |
| light: ink2 text on lake tint | `#4A453C` | `#CFDDF0` | 6.91:1 | 4.5:1 | pass |
| light: ink3 text on lake tint | `#635C50` | `#CFDDF0` | 4.80:1 | 4.5:1 | pass |
| light: lake ink text on lake tint | `#1E4D7A` | `#CFDDF0` | 6.36:1 | 4.5:1 | pass |
| light: lake ink text on box | `#1E4D7A` | `#FFFCF6` | 8.55:1 | 4.5:1 | pass |
| light: monogram letters on lake wall | `#FFFCF6` | `#2C6AA3` | 5.55:1 | 4.5:1 | pass |
| light: lake wall (frame) vs paper | `#2C6AA3` | `#F2EBE0` | 4.80:1 | 3.0:1 | pass |
| light: lake wall (frame) vs box | `#2C6AA3` | `#FFFCF6` | 5.55:1 | 3.0:1 | pass |
| light: lake wall (frame) vs lake tint | `#2C6AA3` | `#CFDDF0` | 4.13:1 | 3.0:1 | pass |
| light: lake wall vs sheet | `#2C6AA3` | `#FBF7EF` | 5.31:1 | 3.0:1 | pass |
| light: ink text on ochre tint | `#1E1B16` | `#EEDAB0` | 12.50:1 | 4.5:1 | pass |
| light: ink2 text on ochre tint | `#4A453C` | `#EEDAB0` | 6.93:1 | 4.5:1 | pass |
| light: ink3 text on ochre tint | `#635C50` | `#EEDAB0` | 4.81:1 | 4.5:1 | pass |
| light: ochre ink text on ochre tint | `#6A4A08` | `#EEDAB0` | 5.89:1 | 4.5:1 | pass |
| light: ochre ink text on box | `#6A4A08` | `#FFFCF6` | 7.90:1 | 4.5:1 | pass |
| light: monogram letters on ochre wall | `#FFFCF6` | `#8E6410` | 5.15:1 | 4.5:1 | pass |
| light: ochre wall (frame) vs paper | `#8E6410` | `#F2EBE0` | 4.46:1 | 3.0:1 | pass |
| light: ochre wall (frame) vs box | `#8E6410` | `#FFFCF6` | 5.15:1 | 3.0:1 | pass |
| light: ochre wall (frame) vs ochre tint | `#8E6410` | `#EEDAB0` | 3.84:1 | 3.0:1 | pass |
| light: ochre wall vs sheet | `#8E6410` | `#FBF7EF` | 4.94:1 | 3.0:1 | pass |
| light: ink text on plum tint | `#1E1B16` | `#ECD6E8` | 12.55:1 | 4.5:1 | pass |
| light: ink2 text on plum tint | `#4A453C` | `#ECD6E8` | 6.95:1 | 4.5:1 | pass |
| light: ink3 text on plum tint | `#635C50` | `#ECD6E8` | 4.83:1 | 4.5:1 | pass |
| light: plum ink text on plum tint | `#683862` | `#ECD6E8` | 6.59:1 | 4.5:1 | pass |
| light: plum ink text on box | `#683862` | `#FFFCF6` | 8.80:1 | 4.5:1 | pass |
| light: monogram letters on plum wall | `#FFFCF6` | `#8A4C82` | 5.97:1 | 4.5:1 | pass |
| light: plum wall (frame) vs paper | `#8A4C82` | `#F2EBE0` | 5.16:1 | 3.0:1 | pass |
| light: plum wall (frame) vs box | `#8A4C82` | `#FFFCF6` | 5.97:1 | 3.0:1 | pass |
| light: plum wall (frame) vs plum tint | `#8A4C82` | `#ECD6E8` | 4.47:1 | 3.0:1 | pass |
| light: plum wall vs sheet | `#8A4C82` | `#FBF7EF` | 5.72:1 | 3.0:1 | pass |
| light: ink text on graphite tint | `#1E1B16` | `#DADDDE` | 12.57:1 | 4.5:1 | pass |
| light: ink2 text on graphite tint | `#4A453C` | `#DADDDE` | 6.97:1 | 4.5:1 | pass |
| light: ink3 text on graphite tint | `#635C50` | `#DADDDE` | 4.84:1 | 4.5:1 | pass |
| light: graphite ink text on graphite tint | `#3F4247` | `#DADDDE` | 7.39:1 | 4.5:1 | pass |
| light: graphite ink text on box | `#3F4247` | `#FFFCF6` | 9.85:1 | 4.5:1 | pass |
| light: monogram letters on graphite wall | `#FFFCF6` | `#55595F` | 6.88:1 | 4.5:1 | pass |
| light: graphite wall (frame) vs paper | `#55595F` | `#F2EBE0` | 5.95:1 | 3.0:1 | pass |
| light: graphite wall (frame) vs box | `#55595F` | `#FFFCF6` | 6.88:1 | 3.0:1 | pass |
| light: graphite wall (frame) vs graphite tint | `#55595F` | `#DADDDE` | 5.16:1 | 3.0:1 | pass |
| light: graphite wall vs sheet | `#55595F` | `#FBF7EF` | 6.59:1 | 3.0:1 | pass |
| light: danger text on paper | `#B0362A` | `#F2EBE0` | 5.21:1 | 4.5:1 | pass |
| light: danger text on box | `#B0362A` | `#FFFCF6` | 6.02:1 | 4.5:1 | pass |
| light: danger text on sheet | `#B0362A` | `#FBF7EF` | 5.77:1 | 4.5:1 | pass |
| light: danger text on dangerTint | `#B0362A` | `#F7E0DA` | 4.88:1 | 4.5:1 | pass |
| light: primary pill label on ink | `#F2EBE0` | `#1E1B16` | 14.49:1 | 4.5:1 | pass |
| light: primary pill fill vs paper | `#1E1B16` | `#F2EBE0` | 14.49:1 | 3.0:1 | pass |
| light: primary pill fill vs box | `#1E1B16` | `#FFFCF6` | 16.76:1 | 3.0:1 | pass |
| light: outline / off switch / empty PIN dot / hollow door (ink3) vs paper | `#635C50` | `#F2EBE0` | 5.58:1 | 3.0:1 | pass |
| light: outline / off switch / empty PIN dot / hollow door (ink3) vs box | `#635C50` | `#FFFCF6` | 6.45:1 | 3.0:1 | pass |
| light: outline / off switch / empty PIN dot / hollow door (ink3) vs sheet | `#635C50` | `#FBF7EF` | 6.19:1 | 3.0:1 | pass |
| light: switch on: knob vs ink track | `#FFFCF6` | `#1E1B16` | 16.76:1 | 3.0:1 | pass |
| light: switch off: ink3 knob vs box track | `#635C50` | `#FFFCF6` | 6.45:1 | 3.0:1 | pass |
| light: filled door / filled PIN dot (ink) vs box | `#1E1B16` | `#FFFCF6` | 16.76:1 | 3.0:1 | pass |
| light: danger outline vs paper | `#B0362A` | `#F2EBE0` | 5.21:1 | 3.0:1 | pass |
| dark: ink text on paper | `#F2EDE3` | `#1A1815` | 15.18:1 | 4.5:1 | pass |
| dark: ink text on box | `#F2EDE3` | `#37332D` | 10.75:1 | 4.5:1 | pass |
| dark: ink text on sheet | `#F2EDE3` | `#2E2A25` | 12.21:1 | 4.5:1 | pass |
| dark: ink text on sunken | `#F2EDE3` | `#0A0908` | 17.05:1 | 4.5:1 | pass |
| dark: ink2 text on paper | `#CEC7B9` | `#1A1815` | 10.54:1 | 4.5:1 | pass |
| dark: ink2 text on box | `#CEC7B9` | `#37332D` | 7.46:1 | 4.5:1 | pass |
| dark: ink2 text on sheet | `#CEC7B9` | `#2E2A25` | 8.48:1 | 4.5:1 | pass |
| dark: ink2 text on sunken | `#CEC7B9` | `#0A0908` | 11.84:1 | 4.5:1 | pass |
| dark: ink3 text on paper | `#ABA394` | `#1A1815` | 7.08:1 | 4.5:1 | pass |
| dark: ink3 text on box | `#ABA394` | `#37332D` | 5.02:1 | 4.5:1 | pass |
| dark: ink3 text on sheet | `#ABA394` | `#2E2A25` | 5.70:1 | 4.5:1 | pass |
| dark: ink3 text on sunken | `#ABA394` | `#0A0908` | 7.96:1 | 4.5:1 | pass |
| dark: ink text on fern tint | `#F2EDE3` | `#192B22` | 12.76:1 | 4.5:1 | pass |
| dark: ink2 text on fern tint | `#CEC7B9` | `#192B22` | 8.86:1 | 4.5:1 | pass |
| dark: ink3 text on fern tint | `#ABA394` | `#192B22` | 5.96:1 | 4.5:1 | pass |
| dark: fern ink text on fern tint | `#A8E3C5` | `#192B22` | 10.25:1 | 4.5:1 | pass |
| dark: fern ink text on box | `#A8E3C5` | `#37332D` | 8.64:1 | 4.5:1 | pass |
| dark: monogram letters on fern wall | `#1A1815` | `#6DC59A` | 8.52:1 | 4.5:1 | pass |
| dark: fern wall (frame) vs paper | `#6DC59A` | `#1A1815` | 8.52:1 | 3.0:1 | pass |
| dark: fern wall (frame) vs box | `#6DC59A` | `#37332D` | 6.04:1 | 3.0:1 | pass |
| dark: fern wall (frame) vs fern tint | `#6DC59A` | `#192B22` | 7.17:1 | 3.0:1 | pass |
| dark: fern wall vs sheet | `#6DC59A` | `#2E2A25` | 6.85:1 | 3.0:1 | pass |
| dark: ink text on lake tint | `#F2EDE3` | `#1C2938` | 12.64:1 | 4.5:1 | pass |
| dark: ink2 text on lake tint | `#CEC7B9` | `#1C2938` | 8.78:1 | 4.5:1 | pass |
| dark: ink3 text on lake tint | `#ABA394` | `#1C2938` | 5.90:1 | 4.5:1 | pass |
| dark: lake ink text on lake tint | `#B5D3F2` | `#1C2938` | 9.53:1 | 4.5:1 | pass |
| dark: lake ink text on box | `#B5D3F2` | `#37332D` | 8.10:1 | 4.5:1 | pass |
| dark: monogram letters on lake wall | `#1A1815` | `#7FB0E3` | 7.78:1 | 4.5:1 | pass |
| dark: lake wall (frame) vs paper | `#7FB0E3` | `#1A1815` | 7.78:1 | 3.0:1 | pass |
| dark: lake wall (frame) vs box | `#7FB0E3` | `#37332D` | 5.51:1 | 3.0:1 | pass |
| dark: lake wall (frame) vs lake tint | `#7FB0E3` | `#1C2938` | 6.48:1 | 3.0:1 | pass |
| dark: lake wall vs sheet | `#7FB0E3` | `#2E2A25` | 6.26:1 | 3.0:1 | pass |
| dark: ink text on ochre tint | `#F2EDE3` | `#2F2716` | 12.65:1 | 4.5:1 | pass |
| dark: ink2 text on ochre tint | `#CEC7B9` | `#2F2716` | 8.78:1 | 4.5:1 | pass |
| dark: ink3 text on ochre tint | `#ABA394` | `#2F2716` | 5.90:1 | 4.5:1 | pass |
| dark: ochre ink text on ochre tint | `#EDD29E` | `#2F2716` | 10.06:1 | 4.5:1 | pass |
| dark: ochre ink text on box | `#EDD29E` | `#37332D` | 8.55:1 | 4.5:1 | pass |
| dark: monogram letters on ochre wall | `#1A1815` | `#D9AE5C` | 8.57:1 | 4.5:1 | pass |
| dark: ochre wall (frame) vs paper | `#D9AE5C` | `#1A1815` | 8.57:1 | 3.0:1 | pass |
| dark: ochre wall (frame) vs box | `#D9AE5C` | `#37332D` | 6.07:1 | 3.0:1 | pass |
| dark: ochre wall (frame) vs ochre tint | `#D9AE5C` | `#2F2716` | 7.14:1 | 3.0:1 | pass |
| dark: ochre wall vs sheet | `#D9AE5C` | `#2E2A25` | 6.89:1 | 3.0:1 | pass |
| dark: ink text on plum tint | `#F2EDE3` | `#34222E` | 12.73:1 | 4.5:1 | pass |
| dark: ink2 text on plum tint | `#CEC7B9` | `#34222E` | 8.83:1 | 4.5:1 | pass |
| dark: ink3 text on plum tint | `#ABA394` | `#34222E` | 5.94:1 | 4.5:1 | pass |
| dark: plum ink text on plum tint | `#EBC6E3` | `#34222E` | 9.70:1 | 4.5:1 | pass |
| dark: plum ink text on box | `#EBC6E3` | `#37332D` | 8.20:1 | 4.5:1 | pass |
| dark: monogram letters on plum wall | `#1A1815` | `#D79BCC` | 7.97:1 | 4.5:1 | pass |
| dark: plum wall (frame) vs paper | `#D79BCC` | `#1A1815` | 7.97:1 | 3.0:1 | pass |
| dark: plum wall (frame) vs box | `#D79BCC` | `#37332D` | 5.65:1 | 3.0:1 | pass |
| dark: plum wall (frame) vs plum tint | `#D79BCC` | `#34222E` | 6.68:1 | 3.0:1 | pass |
| dark: plum wall vs sheet | `#D79BCC` | `#2E2A25` | 6.41:1 | 3.0:1 | pass |
| dark: ink text on graphite tint | `#F2EDE3` | `#25282B` | 12.70:1 | 4.5:1 | pass |
| dark: ink2 text on graphite tint | `#CEC7B9` | `#25282B` | 8.82:1 | 4.5:1 | pass |
| dark: ink3 text on graphite tint | `#ABA394` | `#25282B` | 5.93:1 | 4.5:1 | pass |
| dark: graphite ink text on graphite tint | `#D3D6DB` | `#25282B` | 10.17:1 | 4.5:1 | pass |
| dark: graphite ink text on box | `#D3D6DB` | `#37332D` | 8.61:1 | 4.5:1 | pass |
| dark: monogram letters on graphite wall | `#1A1815` | `#A9AEB5` | 7.94:1 | 4.5:1 | pass |
| dark: graphite wall (frame) vs paper | `#A9AEB5` | `#1A1815` | 7.94:1 | 3.0:1 | pass |
| dark: graphite wall (frame) vs box | `#A9AEB5` | `#37332D` | 5.62:1 | 3.0:1 | pass |
| dark: graphite wall (frame) vs graphite tint | `#A9AEB5` | `#25282B` | 6.64:1 | 3.0:1 | pass |
| dark: graphite wall vs sheet | `#A9AEB5` | `#2E2A25` | 6.38:1 | 3.0:1 | pass |
| dark: danger text on paper | `#F0897A` | `#1A1815` | 7.22:1 | 4.5:1 | pass |
| dark: danger text on box | `#F0897A` | `#37332D` | 5.12:1 | 4.5:1 | pass |
| dark: danger text on sheet | `#F0897A` | `#2E2A25` | 5.81:1 | 4.5:1 | pass |
| dark: danger text on dangerTint | `#F0897A` | `#3B201C` | 6.08:1 | 4.5:1 | pass |
| dark: primary pill label on ink | `#1A1815` | `#F2EDE3` | 15.18:1 | 4.5:1 | pass |
| dark: primary pill fill vs paper | `#F2EDE3` | `#1A1815` | 15.18:1 | 3.0:1 | pass |
| dark: primary pill fill vs box | `#F2EDE3` | `#37332D` | 10.75:1 | 3.0:1 | pass |
| dark: outline / off switch / empty PIN dot / hollow door (ink3) vs paper | `#ABA394` | `#1A1815` | 7.08:1 | 3.0:1 | pass |
| dark: outline / off switch / empty PIN dot / hollow door (ink3) vs box | `#ABA394` | `#37332D` | 5.02:1 | 3.0:1 | pass |
| dark: outline / off switch / empty PIN dot / hollow door (ink3) vs sheet | `#ABA394` | `#2E2A25` | 5.70:1 | 3.0:1 | pass |
| dark: switch on: knob vs ink track | `#37332D` | `#F2EDE3` | 10.75:1 | 3.0:1 | pass |
| dark: switch off: ink3 knob vs box track | `#ABA394` | `#37332D` | 5.02:1 | 3.0:1 | pass |
| dark: filled door / filled PIN dot (ink) vs box | `#F2EDE3` | `#37332D` | 10.75:1 | 3.0:1 | pass |
| dark: danger outline vs paper | `#F0897A` | `#1A1815` | 7.22:1 | 3.0:1 | pass |
| light: box vs paper | `#FFFCF6` | `#F2EBE0` | 1.16:1 | 1.15:1 | pass |
| light: sheet vs scrimmed page (paper under 40% ink) | `#FBF7EF` | `#F2EBE0` | 1.11:1 | 1.0:1 | pass |
| light: sunken vs paper | `#E4DCCD` | `#F2EBE0` | 1.15:1 | 1.1:1 | pass |
| light: fern tint (room) vs paper | `#C7E2D1` | `#F2EBE0` | 1.16:1 | 1.15:1 | pass |
| light: box (site card) vs fern tint | `#FFFCF6` | `#C7E2D1` | 1.35:1 | 1.15:1 | pass |
| light: lake tint (room) vs paper | `#CFDDF0` | `#F2EBE0` | 1.16:1 | 1.15:1 | pass |
| light: box (site card) vs lake tint | `#FFFCF6` | `#CFDDF0` | 1.34:1 | 1.15:1 | pass |
| light: ochre tint (room) vs paper | `#EEDAB0` | `#F2EBE0` | 1.16:1 | 1.15:1 | pass |
| light: box (site card) vs ochre tint | `#FFFCF6` | `#EEDAB0` | 1.34:1 | 1.15:1 | pass |
| light: plum tint (room) vs paper | `#ECD6E8` | `#F2EBE0` | 1.16:1 | 1.15:1 | pass |
| light: box (site card) vs plum tint | `#FFFCF6` | `#ECD6E8` | 1.34:1 | 1.15:1 | pass |
| light: graphite tint (room) vs paper | `#DADDDE` | `#F2EBE0` | 1.15:1 | 1.15:1 | pass |
| light: box (site card) vs graphite tint | `#FFFCF6` | `#DADDDE` | 1.33:1 | 1.15:1 | pass |
| dark: box vs paper | `#37332D` | `#1A1815` | 1.41:1 | 1.15:1 | pass |
| dark: sheet vs scrimmed page (paper under 40% ink) | `#2E2A25` | `#1A1815` | 1.24:1 | 1.0:1 | pass |
| dark: sunken vs paper | `#0A0908` | `#1A1815` | 1.12:1 | 1.1:1 | pass |
| dark: fern tint (room) vs paper | `#192B22` | `#1A1815` | 1.19:1 | 1.15:1 | pass |
| dark: box (site card) vs fern tint | `#37332D` | `#192B22` | 1.19:1 | 1.15:1 | pass |
| dark: lake tint (room) vs paper | `#1C2938` | `#1A1815` | 1.20:1 | 1.15:1 | pass |
| dark: box (site card) vs lake tint | `#37332D` | `#1C2938` | 1.18:1 | 1.15:1 | pass |
| dark: ochre tint (room) vs paper | `#2F2716` | `#1A1815` | 1.20:1 | 1.15:1 | pass |
| dark: box (site card) vs ochre tint | `#37332D` | `#2F2716` | 1.18:1 | 1.15:1 | pass |
| dark: plum tint (room) vs paper | `#34222E` | `#1A1815` | 1.19:1 | 1.15:1 | pass |
| dark: box (site card) vs plum tint | `#37332D` | `#34222E` | 1.18:1 | 1.15:1 | pass |
| dark: graphite tint (room) vs paper | `#25282B` | `#1A1815` | 1.20:1 | 1.15:1 | pass |
| dark: box (site card) vs graphite tint | `#37332D` | `#25282B` | 1.18:1 | 1.15:1 | pass |
| light: reader title on reader bg | `#1E1B16` | `#F8F2E6` | 15.39:1 | 4.5:1 | pass |
| light: reader body on reader bg | `#2E2A23` | `#F8F2E6` | 12.80:1 | 4.5:1 | pass |
| light: reader softTitle on reader bg | `#3A352D` | `#F8F2E6` | 10.91:1 | 4.5:1 | pass |
| light: reader softBody on reader bg | `#4F493F` | `#F8F2E6` | 7.99:1 | 4.5:1 | pass |
| light: reader host on reader bg | `#635C50` | `#F8F2E6` | 5.93:1 | 4.5:1 | pass |
| dark: reader title on reader bg | `#EFE8DB` | `#171512` | 14.96:1 | 4.5:1 | pass |
| dark: reader body on reader bg | `#D8D0C2` | `#171512` | 11.91:1 | 4.5:1 | pass |
| dark: reader softTitle on reader bg | `#CFC7B8` | `#171512` | 10.86:1 | 4.5:1 | pass |
| dark: reader softBody on reader bg | `#B3AB9D` | `#171512` | 8.01:1 | 4.5:1 | pass |
| dark: reader host on reader bg | `#ABA394` | `#171512` | 7.29:1 | 4.5:1 | pass |
| light: ink text on throwaway hatch stripe (ink 10% over paper) | `#1E1B16` | `#DCD6CB` | 11.87:1 | 4.5:1 | pass |
| light: ink3 text on throwaway hatch stripe | `#635C50` | `#DCD6CB` | 4.57:1 | 4.5:1 | pass |
| light: throwaway dashed outline (ink3) vs hatch stripe | `#635C50` | `#DCD6CB` | 4.57:1 | 3.0:1 | pass |
| dark: ink text on throwaway hatch stripe (paper 10% over page) | `#F2EDE3` | `#302E2A` | 11.61:1 | 4.5:1 | pass |
| dark: ink3 text on throwaway hatch stripe | `#ABA394` | `#302E2A` | 5.42:1 | 4.5:1 | pass |
| dark: throwaway dashed outline (ink3) vs hatch stripe | `#ABA394` | `#302E2A` | 5.42:1 | 3.0:1 | pass |
| light: Tor inner wall (ink) vs fern tint | `#1E1B16` | `#C7E2D1` | 12.45:1 | 3.0:1 | pass |
| dark: Tor inner wall (ink) vs fern tint | `#F2EDE3` | `#192B22` | 12.76:1 | 3.0:1 | pass |
| light: danger outline vs box | `#B0362A` | `#FFFCF6` | 6.02:1 | 3.0:1 | pass |
| dark: danger outline vs box | `#F0897A` | `#37332D` | 5.12:1 | 3.0:1 | pass |
| light: danger text on box | `#B0362A` | `#FFFCF6` | 6.02:1 | 4.5:1 | pass |
| dark: danger text on box | `#F0897A` | `#37332D` | 5.12:1 | 4.5:1 | pass |
| light: focus ring (lake wall) vs paper | `#2C6AA3` | `#F2EBE0` | 4.80:1 | 3.0:1 | pass |
| dark: focus ring (lake wall) vs paper | `#7FB0E3` | `#1A1815` | 7.78:1 | 3.0:1 | pass |

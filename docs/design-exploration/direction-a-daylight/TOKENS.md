# Daylight — tokens

Two themes, one set of roles. The app picks the theme from
`MediaQuery.platformBrightness`; there is no setting. Every role has the same
*job* in both themes, so a widget names a role (`C.ink2`), never a hex.
Values live in `tokens.css` as CSS custom properties (light on `:root` /
`.theme-light`, dark on `.theme-dark`), which `screens.html` uses directly.

All ratios below were produced by
`python3 docs/design-exploration/tools/contrast.py --table contrast-pairs.txt`
(the pairs file is in this folder; re-run it to check). Nothing is asserted
without a ratio.

## 1. Colour roles

### Surfaces (three per theme + the accent container — RESEARCH Implication 4)

| Role | Light | Dark | Purpose | Replaces `C.*` |
|---|---|---|---|---|
| `page` | `#EBEEE8` | `#101311` | Scaffold of every screen; the "ground" groups sit on. Light is a faint grey-green so white groups lift off it. | `bg`, `bgPanic`, `footer` (retired: one ground only) |
| `card` | `#FFFFFF` | `#1E2220` | Grouped rows, sheets, bars (top/bottom), keypad keys, dialogs. | `surface`, `sheet`, `raised`, `monogramOpen`, `dangerPanel` (bg role) |
| `tonal` | `#D9DED6` | `#2B302D` | Address pill, neutral buttons, idle monograms, unselected chip on a card, text fields on a card, bar tracks, pressed state. | `button`, `selected` (neutral), `skeleton`, `barTrack`, `trackOff` (fill), `handle` |
| `accentContainer` | `#D3EBE0` | `#1F4A3C` | Selected chip / tab / radio row, the "open" monogram, the `N OPEN` pill — a *state* tint, never decoration. | `selected` (for selected state), new |

Surface steps (measured): light card vs page **1.17:1**, page vs tonal
**1.17:1**; dark card vs page **1.16:1**, tonal vs card **1.20:1**. All ≥ 1.15
(Implication 4). Eleven darks become three.

### Content

| Role | Light | Dark | Purpose | Replaces `C.*` |
|---|---|---|---|---|
| `ink` | `#1A1D1B` | `#E4E8E4` | Titles, row names, body, values, digits. | `textPrimary`, `textSecondary`, `textTertiary`, `monogramText`, `pillText` |
| `ink2` | `#4A514C` | `#B4BBB6` | Secondary text: meta lines, setting subtitles, captions, section labels, icons. Passes 4.5:1 on **every** surface — the explanation text is no longer the faintest. | `textMuted`, `textFaint`, `textDim`, `icon`, `chevron`, `tabInactive` (all six merge) |
| `outline` | `#6E7570` | `#8A928D` | Meaningful non-text marks: text-field border, off-switch track border and knob, empty PIN dot, idle dot, radio ring, focus ring fallback. ≥ 3:1 on every surface. | `pinEmpty`, `idleDot`, `knobOff`, `line16` (focus) |
| `outlineVariant` | `#CDD3CB` | `#3A403C` | Decorative dividers *inside* a group only (exempt from 1.4.11; the group's own surface carries the structure). | `line05`…`line13` (nine alphas → one) |
| `inkDisabled` | `#8D938E` | `#6A716C` | Inert controls only (exempt: inactive UI). Inert switches are drawn at full contrast but with a lock-free *disabled* treatment (see §6), not at 40 % opacity. | `textDisabled` |
| `scrim` | `#1A1D1B` at 40 % | `#000000` at 55 % | Behind sheets. | (Material default) |

### State

| Role | Light | Dark | Purpose | Replaces `C.*` |
|---|---|---|---|---|
| `accent` ("spruce" / jade) | `#1D6B57` | `#7FC8A9` | Live state marks (8 dp dot, switch on, step bar, the shield when protections are on) and the **one** affirmative filled action per screen. | `jade`, `jadeCode` |
| `onAccent` | `#FFFFFF` | `#0B2A20` | Label/knob on an accent fill. | `bg` (as label colour) |
| `onAccentContainer` | `#0D3A2D` | `#BFEBD8` | Text and icons on `accentContainer`. | `monogramText` (open) |
| `danger` | `#B3261E` | `#F2A49A` | Panic, wipe, refused headlines: text, outline, icon. Never a large fill. | `danger` |
| `dangerContainer` | `#FCEBE8` | `#3A201D` | The small tinted panel (`8c` banner, panic button tile, refused mark). | `dangerSurface`, `dangerPanel` |
| `onDangerContainer` | `#8C1D18` | `#F7C9C2` | Text on that panel; replaces the failing `dangerMuted`. | `dangerMuted` (was 3.89:1), `pinError` |
| `warning` (amber) | `#8F5B00` | `#E3B262` | "Opening" dot, Permission-asks bar, JS badge. | `warning` |

Workspace markers (`C.markers`, data not theme): kept as the user's choice,
drawn as a 12 dp dot with a 1 dp `outline` ring so each passes 3:1 by its
ring regardless of hue. Light values deepened to read on white:
`#1D6B57 #3D5F8F #8F5B00 #8A4F72 #5E6661`; dark keep the current
`#7FC8A9 #8FA5C8 #D6A45B #C89BB4 #8A918F`. Both vaults render the same
markers; markers are site data, present in both vaults (Implication 15).

### Reader (`6b`)

| Role | Light | Dark |
|---|---|---|
| `readerPage` | `#F6F1E7` (warm paper) | `#12100D` (current `bgReader`) |
| `readerInk` | `#2B2620` | `#EDE7DC` |
| `readerInk2` | `#5E564B` | `#B3AC9F` (replaces failing `readerHost`) |

### Contrast — every pairing, measured

Text needs 4.5:1 (all app text is below the large-text threshold except the
Today total and step titles, held to 4.5 anyway). Non-text marks need 3:1.
Surface steps need 1.15:1. The "Today bar track vs card" row is a
decorative track (the accent fill and the number carry the meaning), listed
for completeness with a 1.0 bar.

| Pair | FG | BG | Ratio | Needs | Result |
|---|---|---|---|---|---|
| L ink on page | `#1A1D1B` | `#EBEEE8` | 14.51:1 | 4.5:1 | pass |
| L ink on card | `#1A1D1B` | `#FFFFFF` | 17.00:1 | 4.5:1 | pass |
| L ink on tonal | `#1A1D1B` | `#D9DED6` | 12.44:1 | 4.5:1 | pass |
| L ink-2 on page | `#4A514C` | `#EBEEE8` | 6.97:1 | 4.5:1 | pass |
| L ink-2 on card | `#4A514C` | `#FFFFFF` | 8.16:1 | 4.5:1 | pass |
| L ink-2 on tonal | `#4A514C` | `#D9DED6` | 5.97:1 | 4.5:1 | pass |
| L accent text on card | `#1D6B57` | `#FFFFFF` | 6.38:1 | 4.5:1 | pass |
| L accent text on page | `#1D6B57` | `#EBEEE8` | 5.44:1 | 4.5:1 | pass |
| L on-accent on accent (primary button) | `#FFFFFF` | `#1D6B57` | 6.38:1 | 4.5:1 | pass |
| L on-accent-container on accent-container | `#0D3A2D` | `#D3EBE0` | 10.08:1 | 4.5:1 | pass |
| L ink on accent-container (selected chip) | `#1A1D1B` | `#D3EBE0` | 13.54:1 | 4.5:1 | pass |
| L danger text on card | `#B3261E` | `#FFFFFF` | 6.54:1 | 4.5:1 | pass |
| L danger text on page | `#B3261E` | `#EBEEE8` | 5.58:1 | 4.5:1 | pass |
| L on-danger-container on danger-container | `#8C1D18` | `#FCEBE8` | 7.89:1 | 4.5:1 | pass |
| L ink on danger-container | `#1A1D1B` | `#FCEBE8` | 14.72:1 | 4.5:1 | pass |
| L warning text on card | `#8F5B00` | `#FFFFFF` | 5.73:1 | 4.5:1 | pass |
| L code (accent) on code surface | `#1D6B57` | `#EBEEE8` | 5.44:1 | 4.5:1 | pass |
| L reader body on reader page | `#2B2620` | `#F6F1E7` | 13.32:1 | 4.5:1 | pass |
| L reader muted on reader page | `#5E564B` | `#F6F1E7` | 6.41:1 | 4.5:1 | pass |
| L white on danger (panic confirm fill) | `#FFFFFF` | `#B3261E` | 6.54:1 | 4.5:1 | pass |
| L outline (field border, off switch, empty PIN dot) on card | `#6E7570` | `#FFFFFF` | 4.73:1 | 3.0:1 | pass |
| L outline on page | `#6E7570` | `#EBEEE8` | 4.04:1 | 3.0:1 | pass |
| L outline on tonal | `#6E7570` | `#D9DED6` | 3.46:1 | 3.0:1 | pass |
| L icon (ink-2) on page | `#4A514C` | `#EBEEE8` | 6.97:1 | 3.0:1 | pass |
| L accent mark (live dot, on switch) on card | `#1D6B57` | `#FFFFFF` | 6.38:1 | 3.0:1 | pass |
| L accent mark on page | `#1D6B57` | `#EBEEE8` | 5.44:1 | 3.0:1 | pass |
| L on-switch knob vs accent track | `#FFFFFF` | `#1D6B57` | 6.38:1 | 3.0:1 | pass |
| L off-switch knob (outline) vs card | `#6E7570` | `#FFFFFF` | 4.73:1 | 3.0:1 | pass |
| L warning dot (opening) on card | `#8F5B00` | `#FFFFFF` | 5.73:1 | 3.0:1 | pass |
| L warning dot on tonal pill | `#8F5B00` | `#D9DED6` | 4.19:1 | 3.0:1 | pass |
| L danger mark on card | `#B3261E` | `#FFFFFF` | 6.54:1 | 3.0:1 | pass |
| L focus ring (accent) on page | `#1D6B57` | `#EBEEE8` | 5.44:1 | 3.0:1 | pass |
| L filled PIN dot (ink) on page | `#1A1D1B` | `#EBEEE8` | 14.51:1 | 3.0:1 | pass |
| L idle dot (outline) on card | `#6E7570` | `#FFFFFF` | 4.73:1 | 3.0:1 | pass |
| L bar track vs card (Today bars) | `#D9DED6` | `#FFFFFF` | 1.37:1 | 1.0:1 | pass |
| L Today bar fill (ink2) vs track | `#4A514C` | `#D9DED6` | 5.97:1 | 3.0:1 | pass |
| L permission bar fill (warning) vs track | `#8F5B00` | `#D9DED6` | 4.19:1 | 3.0:1 | pass |
| L card vs page | `#FFFFFF` | `#EBEEE8` | 1.17:1 | 1.15:1 | pass |
| L page vs tonal | `#EBEEE8` | `#D9DED6` | 1.17:1 | 1.15:1 | pass |
| D ink on page | `#E4E8E4` | `#101311` | 15.10:1 | 4.5:1 | pass |
| D ink on card | `#E4E8E4` | `#1E2220` | 13.00:1 | 4.5:1 | pass |
| D ink on tonal | `#E4E8E4` | `#2B302D` | 10.85:1 | 4.5:1 | pass |
| D ink-2 on page | `#B4BBB6` | `#101311` | 9.55:1 | 4.5:1 | pass |
| D ink-2 on card | `#B4BBB6` | `#1E2220` | 8.22:1 | 4.5:1 | pass |
| D ink-2 on tonal | `#B4BBB6` | `#2B302D` | 6.86:1 | 4.5:1 | pass |
| D accent text on card | `#7FC8A9` | `#1E2220` | 8.23:1 | 4.5:1 | pass |
| D accent text on page | `#7FC8A9` | `#101311` | 9.56:1 | 4.5:1 | pass |
| D on-accent on accent (primary button) | `#0B2A20` | `#7FC8A9` | 7.86:1 | 4.5:1 | pass |
| D on-accent-container on accent-container | `#BFEBD8` | `#1F4A3C` | 7.65:1 | 4.5:1 | pass |
| D ink on accent-container | `#E4E8E4` | `#1F4A3C` | 8.07:1 | 4.5:1 | pass |
| D danger text on card | `#F2A49A` | `#1E2220` | 8.09:1 | 4.5:1 | pass |
| D danger text on page | `#F2A49A` | `#101311` | 9.39:1 | 4.5:1 | pass |
| D on-danger-container on danger-container | `#F7C9C2` | `#3A201D` | 10.03:1 | 4.5:1 | pass |
| D ink on danger-container | `#E4E8E4` | `#3A201D` | 12.08:1 | 4.5:1 | pass |
| D warning text on card | `#E3B262` | `#1E2220` | 8.28:1 | 4.5:1 | pass |
| D code (accent) on code surface | `#7FC8A9` | `#2B302D` | 6.87:1 | 4.5:1 | pass |
| D on-danger on danger fill | `#3A0B07` | `#F2A49A` | 8.57:1 | 4.5:1 | pass |
| D outline on card | `#8A928D` | `#1E2220` | 5.04:1 | 3.0:1 | pass |
| D outline on page | `#8A928D` | `#101311` | 5.86:1 | 3.0:1 | pass |
| D outline on tonal | `#8A928D` | `#2B302D` | 4.21:1 | 3.0:1 | pass |
| D icon (ink-2) on page | `#B4BBB6` | `#101311` | 9.55:1 | 3.0:1 | pass |
| D accent mark on card | `#7FC8A9` | `#1E2220` | 8.23:1 | 3.0:1 | pass |
| D accent mark on page | `#7FC8A9` | `#101311` | 9.56:1 | 3.0:1 | pass |
| D on-switch knob vs accent track | `#0B2A20` | `#7FC8A9` | 7.86:1 | 3.0:1 | pass |
| D warning dot on card | `#E3B262` | `#1E2220` | 8.28:1 | 3.0:1 | pass |
| D warning dot on tonal | `#E3B262` | `#2B302D` | 6.91:1 | 3.0:1 | pass |
| D danger mark on card | `#F2A49A` | `#1E2220` | 8.09:1 | 3.0:1 | pass |
| D filled PIN dot (ink) on page | `#E4E8E4` | `#101311` | 15.10:1 | 3.0:1 | pass |
| D Today bar fill (ink2) vs track | `#B4BBB6` | `#2B302D` | 6.86:1 | 3.0:1 | pass |
| D card vs page | `#1E2220` | `#101311` | 1.16:1 | 1.15:1 | pass |
| D tonal vs card | `#2B302D` | `#1E2220` | 1.20:1 | 1.15:1 | pass |
| D reader ink on reader page | `#EDE7DC` | `#12100D` | 15.43:1 | 4.5:1 | pass |
| D reader ink-2 on reader page | `#B3AC9F` | `#12100D` | 8.43:1 | 4.5:1 | pass |
| L marker 2 blue on card | `#3D5F8F` | `#FFFFFF` | 6.50:1 | 3.0:1 | pass |
| L marker 4 plum on card | `#8A4F72` | `#FFFFFF` | 6.10:1 | 3.0:1 | pass |
| L marker 5 grey on card | `#5E6661` | `#FFFFFF` | 5.92:1 | 3.0:1 | pass |
| L keypad key vs page | `#FFFFFF` | `#EBEEE8` | 1.17:1 | 1.0:1 | pass |
| D keypad key vs page | `#1E2220` | `#101311` | 1.16:1 | 1.0:1 | pass |

Today's category bars are filled with `ink2`, not the accent: a count is
data, not live state, and an accent bar chart would read as a score.

Notes on pairs that are deliberately *not* held to 3:1:

- **Keypad key fill vs page** (light `#FFFFFF` on `#EBEEE8`, 1.17:1; dark
  `#1E2220` on `#101311`, 1.16:1). The digit (`ink` on `card`, 17.00:1 light / 13.00:1 dark) is the
  identifying mark; the key fill is a press affordance. Same ruling as AUDIT
  §2.
- **Card vs page** is a surface step (1.17:1), not a boundary that must pass
  1.4.11: groups are identified by their content.

## 2. Type

### Families

| Use | Family | Licence | Bundled size |
|---|---|---|---|
| UI, everything that is a word | **Atkinson Hyperlegible Next** (variable, wght 200–800) | SIL OFL 1.1 (Braille Institute, 2025) | **112 KB** full TTF (RESEARCH §4). Google Fonts' Latin-subset variable file measured **46.7 KB** on 2026-10-05. |
| Values: hosts, proxy addresses, ports, rule counts, code, file names | **Atkinson Hyperlegible Mono** (variable, wght 200–800) | SIL OFL 1.1 | Latin-subset variable file measured **32.9 KB** on 2026-10-05; full file estimated **~80 KB** (scaled by Next's full/subset ratio). |

Total ≈ **190 KB**, replacing Figtree (61 KB) + Plex Mono Regular/Medium
(272 KB) = 333 KB today: a net **saving of ~140 KB**. Both are bundled as
assets and never fetched at runtime (the mockup page alone loads them from
Google Fonts). Why Atkinson: its letterforms are deliberately
differentiated (I/l/1, O/0, rn/m) for low vision, which matters most exactly
where this app is technical — a mistyped host or proxy port.

### Scale (sp; all sizes scale with the system font scale)

The smallest text anywhere is **13 sp** (Implication 1: nothing under 12).
Body is 16 sp; the pill's host is 16 sp.

| Role | Family | Size | Weight | Line height | Tracking | Maps to `T.*` |
|---|---|---|---|---|---|---|
| Display (Today total) | Next | 44 | 600 | 52 | −0.5 | **new** `T.display` |
| Step title (setup, `8b` headline) | Next | 26 | 600 | 32 | −0.2 | `T.stepTitle` (22 → 26) |
| Screen title (top app bar) | Next | 22 | 500 | 28 | 0 | `T.screenTitle` (16 → 22), `T.appBarTitle` (15 → 22, merged) |
| Sheet title | Next | 20 | 600 | 26 | 0 | `T.sheetTitle` (17 → 20) |
| Row title | Next | 16 | 600 | 22 | 0 | `T.rowTitle` (14.5 → 16) |
| Row title, idle | Next | 16 | 400 | 22 | 0 | `T.rowTitleIdle` — same `ink`; idle is lighter weight, not lower contrast |
| Body | Next | 16 | 400 | 24 | 0 | `T.body` (14 → 16) |
| Body, secondary | Next | 16 | 400 | 24 | 0 | `T.bodyMuted` (13 → 16, `ink2`) |
| Meta / subtitle | Next | 14 | 400 | 20 | 0.1 | `T.meta` (10.5 → 14), `T.metaIdle` (merged: same colour) |
| Section label | Next | 14 | 700 | 20 | 0.1, **sentence case** via `text-transform` | `T.sectionLabel` (10 caps → 14 sentence) |
| Section label, live | Next | 14 | 700 | 20 | 0.1 | `T.sectionLabelLive` (`accent`) |
| Bar summary (nav labels, `N OPEN`) | Next | 13 | 600 | 16 | 0.2 | `T.barSummary` (10 → 13) |
| Badge (route `SOCKS5` / `Tor`, `WIPES ON EXIT`) | Next | 13 | 700 | 16 | 0.3 | `T.barBadge` (10.5 → 13; in the UI face with an icon, Implication 8) |
| Code | Mono | 14 | 400 | 22 | 0 | `T.code` (11.5 → 14) |
| **new** Address (pill host) | Next | 16 | 500 | 22 | 0 | `T.address` |
| **new** Value (mono facts in rows) | Mono | 14 | 400 | 20 | 0 | `T.value` |
| **new** Button | Next | 16 | 600 | 24 | 0.1 | `T.button` (PillButton label 14.5 → 16) |
| **new** Keypad digit | Next | 28 | 500 | 32 | 0 | `T.keypad` (22 → 28) |
| **new** Caption (footnotes) | Next | 13 | 400 | 18 | 0.1 | `T.caption` — the smallest role |
| **new** Monogram | Next | 16 | 700 | 16 | 0 | `T.monogram` |

Case: every inventory string keeps its stored case; capitals that are
*styling* in the current app (section labels, `N OPEN`, `WIPES ON EXIT`,
`STANDARD`, `<n> BLOCKED`, `READER · 6 MIN`, `WEBVIEWS`…) are displayed in
sentence case with `text-transform: lowercase` + `::first-letter` uppercase.
Acronyms that are words (`SOCKS5`, `HTTP`, `CSS`, `JS`, `PDF`) stay
capitals.

## 3. Spacing

4 dp base. Steps: **4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48**. Screen side
gutter 16 dp; inside a group 16 dp; between groups 16 dp; section label to
group 8 dp; sheet padding 24 dp. Replaces 156 literal `EdgeInsets`.

## 4. Corner radii

| Token | dp | Used for |
|---|---|---|
| `r.xs` | 8 | badges, small tags, marker squares |
| `r.sm` | 12 | monograms, text fields, file badge |
| `r.md` | 16 | inner tiles, menu tiles, code box |
| `r.lg` | 24 | grouped-row containers (Chrome's tab-card radius), banners |
| `r.xl` | 28 | bottom sheets (top corners), M3 large |
| `r.full` | 999 | pills, chips, buttons, switches, PIN keys, dots |

Six values replace nineteen.

## 5. Borders, elevation

- **Borders:** only where they mean something: text fields (1 dp `outline`,
  2 dp `accent` when focused), unselected chips and radios (1 dp `outline`),
  danger outline button (1.5 dp `danger`). Groups have *no* border — their
  surface step carries them.
- **Dividers:** 1 dp `outlineVariant`, inset 16 dp from the left (72 dp when
  the row has a leading monogram), inside a group only.
- **Elevation:** level 0 (page), level 1 (groups: no shadow in light — tone
  only; dark: tone only), level 3 (sheets: light `0 -2 12 rgba(26,29,27,.12)`;
  dark: tone + scrim only), bars: none (they are `card` tone against the
  page).

## 6. Components (the parts screens.html is built from)

- **Top app bar**: 64 dp, `page` tone, title 22 sp; leading back icon in a 48
  dp target.
- **Browser top bar** (`2b`): 56 dp + 8 dp padding = 64 dp, `card` tone.
  Pill 48 dp tall, `tonal`, `r.full`. Inside, left to right: container-type
  icon (24 dp in a 40 dp target-free slot: the box, solid for Keep, dashed
  for wipe-on-exit/throwaway), live dot 8 dp, host 16 sp, route badge
  (`SOCKS5`/`HTTP`/`Tor`, 13 sp on `card`), reload/stop 40 dp target, shield
  40 dp target. Panic: 48 dp round target, `danger` icon on
  `dangerContainer`.
- **Bottom bar**: 64 dp, `card`. Back / forward / `N OPEN` / menu, each a 48
  dp target. `N OPEN` is a 40 dp-tall `accentContainer` pill — live state
  (open containers).
- **List row**: 56 dp one-line, 72 dp two-line (min; grows with text). 40 dp
  monogram, 16 dp gap.
- **Switch**: M3 geometry: 52×32 track, 48 dp target. On: `accent` track,
  `onAccent` 24 dp knob. Off: `tonal` track + 2 dp `outline` border, 16 dp
  `outline` knob. Inert: track and knob `inkDisabled`, no opacity trick.
- **Buttons**: 52 dp tall, `r.full`, 16 sp/600. Filled (accent, one per
  screen), tonal (neutral), outline-danger (1.5 dp `danger`).
- **PIN dots**: 14 dp; empty = 2 dp `outline` ring (3.84:1 on page), filled =
  `ink`. Error = `danger` ring.
- **Keypad keys**: 72 dp circles (64 under 640 dp tall), `card` on `page`,
  28 sp digits.
- **Chips**: 40 dp visible in a 48 dp target, `r.full`. Selected:
  `accentContainer` + check icon; unselected: 1 dp `outline`.

## 7. Touch targets

**48 × 48 dp minimum for every tappable thing**, including the in-pill
reload and shield (40 dp visible circle, 48 dp hit area extends into the bar
padding), chip `×` (48 dp hit), and the dashboard `+`. Adjacent targets ≥ 8
dp apart. The smallest target in screens.html is recorded in A11Y.md.

## 8. Motion

- **Effects** (everything by default): M3 effects spring, damping 1.0,
  stiffness 1400 (fast: switches, chips, ripples), 700 (default: sheets,
  page transitions), 300 (slow: large surfaces). Never bounces. CSS
  stand-in: `cubic-bezier(0.2, 0, 0, 1)` at 150 / 250 / 400 ms.
- **The two moments that move** (Implication 14):
  1. **Unlock** — on the sixth correct digit the box mark's lid lifts 4 dp
     and the PIN screen fades up into the dashboard (400 ms, emphasised
     decelerate `cubic-bezier(0.05, 0.7, 0.1, 1)`).
  2. **A protective change taking effect** (reopen in place after a `6c`
     switch, a route change, New identity) — the pill's container icon
     redraws (stroke draw 300 ms) while the load line runs; then the live
     dot returns. The user sees the box being *re-sealed*.
- **Reduced motion** (`MediaQuery.disableAnimations`): both become a 150 ms
  cross-fade; nothing slides.

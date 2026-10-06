# Restyle v2 ("Instrument") — design

**Date:** 2026-10-05 (written 2026-10-06 by the overnight restyle run, fire
cd6e6b; the run's files carry the date it started).
**Status:** Chosen by the run's adversarial debate
(`docs/design-exploration/debate/VERDICT.md`); **awaits the user's review.**
Six questions are open (§12); the spec assumes an answer to each so the build
could proceed, and says which.
**Source:** Direction B — Instrument (`docs/design-exploration/direction-b-instrument/`),
as revised in its round-2 reply, with seven elements folded in from Directions
A and C (VERDICT "Folded into B").
**Canvas:** `Sandbox Container -canvas-.dc.html` stays authoritative for
**copy, structure and order**. This spec supersedes it, and the 2026-10-02
restyle spec §3, on **colour, type size/weight/family, spacing, radii and
target size** only.

## 0. Context

The current look (graphite `#0F1113`, jade, white-alpha hairlines, Figtree +
IBM Plex Mono at 9.5–17 px) was measured in
`docs/design-exploration/AUDIT.md`. For someone arriving from Chrome it fails
five ways that are about reading, not taste: 43 % of text sizes are 12.5 px or
less (§1.2); the most-used text colour `textFaint #6E7573` fails WCAG AA on all
four surfaces it sits on (4.01, 3.82, 3.78, 3.92:1); 28 of 29 icon buttons are
under 48 dp; eleven near-black surfaces span 1.26:1 end to end, so nothing
holds a screen together; the off switch is 1.26:1 and an empty PIN dot 1.79:1.
The launcher icon is still Flutter's default.

Instrument keeps the identity AUDIT §3 says the app already does better than
the majors — honest state, one accent, technical facts in a technical face —
and fixes everything measured as "cold": warm ink instead of green-grey, warm
greys, four visible surfaces, one type family skeleton (Plex Sans for words,
Plex Mono for values), 48 dp targets, a 13 sp floor.

## 1. Principles

1. ~~**Dark only.**~~ **Dark first, with a light variant that follows the system setting** (user's ruling 2026-10-06, §9). No toggle.
2. **Jade means live, or the one affirmative action — never a position.**
   Switches, checks, active tabs, step bars and markers are not jade. At most
   one jade *role* per screen (a live light repeated on several rows is one
   role).
3. **Every text pairing ≥ 4.5:1; every meaningful mark ≥ 3:1** (WCAG 1.4.3,
   1.4.11). Measured, not asserted (§2.7).
4. **No state by colour alone** (1.4.1): every state has a shape, fill or
   position as well.
5. **Words are Sans; values you could copy are Mono.** A host in the address
   pill is the one exception: it is Sans (familiarity outranks the rule
   there).
6. **The host is never ellipsized**, at any width or scale. It wraps, breaking
   after a `.`.
7. **Nothing depends on which vault is open.** Same widgets in both vaults;
   the decoy's `2d` is the no-decoy variant (no VAULT section), as built.
8. **Danger is text, an outline or a small tinted panel — never a screen
   fill.**
9. **Copy is byte-identical.** Stored case is kept (§12 Q2). Words,
   punctuation, order unchanged.

## 2. Colour

All values are `const Color` in `lib/ui/core/tokens.dart` (`C`). The class
stays `abstract final class C` with `static const` members, so no call site
changes for colour alone.

### 2.1 Surfaces — four tones

| Role | Hex | Steps |
|---|---|---|
| ink (page) | `#121110` | — |
| group (grouped rows, pill, inputs on the page, keys, skeleton, bar tracks) | `#22201D` | 1.16:1 over ink |
| sheet | `#302D29` | 1.19:1 over group; 1.38:1 over ink |
| raised (selected fill, neutral buttons, open monograms, inputs on a sheet) | `#403C37` | 1.25:1 over sheet; 1.72:1 over ink |

### 2.2 Text — three tones

| Role | Hex | Lowest pairing |
|---|---|---|
| text-1 | `#EDEAE4` | 9.11:1 (raised) |
| text-2 | `#CBC4B9` | 6.32:1 (raised) |
| text-3 | `#A8A095` | 5.30:1 (sheet). **Never on raised** (4.23:1). |

There is no disabled text colour. An inert control keeps a readable tone and
loses its container (no fill, outline or ripple); `AppToggle`'s existing 40 %
inert opacity stays (a switch with no handler is not text).

### 2.3 State

| Role | Hex | Use |
|---|---|---|
| jade | `#7FC8A9` | Live light; the one affirmative action. 9.64:1 on ink. Unchanged. |
| on-jade | `#121110` | Label on a jade fill (9.64:1). |
| danger | `#EE8D79` | Danger text and 1.5 dp outlines. 4.54:1 on raised (worst), 7.83:1 on ink. |
| danger-wash | `#2C201D` | `8c` banner, `10c` delete fill, `2c`'s panic tile fill. |
| amber | `#E0B266` | The *opening* light; the `JS` badge. |
| code | `#D9CFB8` | Code text (`2a` custom CSS/JS, `10e`). Not jade: code is not live. |

### 2.4 Lines and edges

| Role | Value | Use |
|---|---|---|
| line-soft | `#EDEAE4` @ 8 % (`0x14EDEAE4`) | Rule between rows inside a group |
| line | `#EDEAE4` @ 14 % (`0x24EDEAE4`) | A group's outline; the rule under a header or above a bar; an unselected chip's outline |
| edge | `#958D82` | Anything that must be seen as a boundary: off-switch outline, input border, empty PIN dot, idle light, sheet handle. 3.34:1 on raised (worst), 5.76:1 on ink |
| focus | `#EDEAE4` | 2 dp focus ring, 2 dp offset |

### 2.5 Reader (`6b`)

| Role | Hex |
|---|---|
| reader-bg | `#15120E` |
| reader-title | `#EFE8DC` (15.33:1) |
| reader-body | `#D3CBBE` (11.61:1) |
| reader-muted (host, labels) | `#A39A8C` (6.72:1; was 4.27:1) |

The softer theme (◑) maps title → reader-body, body → reader-muted, as built.

### 2.6 Workspace markers (`10a`, `10b` only; data, not identity)

`#C9B48A` brass, `#8FA5C8` steel, `#E0B266` amber, `#C89BB4` mauve, `#A8A095`
stone — same indices as today. Marker 0 is no longer jade, so a marker is
never mistaken for a live light. All ≥ 7.30:1 on ink.

### 2.7 Measured contrast

The full table (57 pairs, all passing) is
`docs/design-exploration/direction-b-instrument/TOKENS.md` "Measured
contrast", from `contrast-pairs.txt` with `tools/contrast.py`. Added for this
spec's folds and measured with the same tool:

| Pair | Ratio |
|---|---|
| selected-chip outline text-1 on ink | 15.71:1 |
| selected-chip outline text-1 on group | 13.53:1 |
| selected-tab outline text-2 on ink | 10.90:1 |
| danger text button on ink (`8b`) | 7.83:1 |

### 2.8 `C.*` mapping

**Kept name, new value** (call sites unchanged):

| `C.*` | Old | New | Role |
|---|---|---|---|
| `bg` | `#0F1113` | `#121110` | ink |
| `bgReader` | `#12100D` | `#15120E` | reader-bg |
| `surface` | `#15181B` | `#22201D` | group |
| `sheet` | `#141719` | `#302D29` | sheet |
| `button` | `#1C2124` | `#403C37` | raised |
| `selected` | `#20262A` | `#403C37` | raised |
| `monogramOpen` | `#20252A` | `#403C37` | raised |
| `knobOff` | `#4A5150` | `#A8A095` | text-3 (off knob) |
| `skeleton` | `#1B1F22` | `#22201D` | group |
| `barTrack` | `#1A1E21` | `#22201D` | group |
| `handle` | `#2C3134` | `#958D82` | edge |
| `textPrimary` | `#E8E9E7` | `#EDEAE4` | text-1 |
| `textSecondary` | `#D7DCDA` | `#EDEAE4` | text-1 |
| `textTertiary` | `#B9BFBD` | `#CBC4B9` | text-2 |
| `textMuted` | `#8A918F` | `#CBC4B9` | text-2 |
| `textFaint` | `#6E7573` | `#A8A095` | text-3 |
| `monogramText` | `#C7CECC` | `#EDEAE4` | text-1 |
| `icon` | `#9AA1A0` | `#CBC4B9` | text-2 |
| `chevron` | `#7E8583` | `#A8A095` | text-3 |
| `tabInactive` | `#767D7B` | `#CBC4B9` | text-2 |
| `pillText` | `#A9B0AE` | `#EDEAE4` | text-1 |
| `readerMuted` | `#8A857C` | `#A39A8C` | reader-muted |
| `readerTitle` | `#EDE7DC` | `#EFE8DC` | reader-title |
| `readerBody` | `#CFC8BC` | `#D3CBBE` | reader-body |
| `idleDot` | `#3E4644` | `#958D82` | edge |
| `pinEmpty` | `#3A403E` | `#958D82` | edge |
| `danger` | `#D66A5A` | `#EE8D79` | danger |
| `dangerSurface` | `#241C1D` | `#2C201D` | danger-wash |
| `warning` | `#D6A45B` | `#E0B266` | amber |
| `pinError` | `#4A3634` | `#EE8D79` | danger (PIN error ring) |
| `markers` | jade, `#8FA5C8`, `#D6A45B`, `#C89BB4`, `#8A918F` | brass, steel, amber, mauve, stone (§2.6) | |
| `jade` | `#7FC8A9` | unchanged | |

**Retired** — kept one release as `@Deprecated` aliases with the new value so
nothing breaks mid-plan, then removed by Plan 23's last task once no call site
reads them:

| `C.*` | Becomes |
|---|---|
| `bgPanic`, `bgRecents`, `footer` | `C.bg` (panic is not a different colour; bars are the page with a rule) |
| `raised` | `C.surface` (merged into group) |
| `trackOff` | transparent: an off switch is an unfilled track with an `C.edge` outline |
| `textDim`, `textDisabled` | `C.textFaint` |
| `dangerMuted` | `C.textMuted` (`8c`'s body is text-2 on the wash; `PillButton`'s danger sub-line is text-2) |
| `dangerPanel` | `C.dangerSurface` |
| `jadeCode` | `C.code` |
| `line05`–`line08` | `C.lineSoft` |
| `line09`–`line16` | `C.line` |

**Added:** `C.edge #958D82`, `C.focus #EDEAE4`, `C.onJade #121110`,
`C.code #D9CFB8`, `C.lineSoft 0x14EDEAE4`, `C.line 0x24EDEAE4`. No separate "raised" name is added: `C.button` and `C.selected` carry `#403C37`.

`lib/domain/models/user_script.dart:13–14` hard-codes `0xFF9FD8C0` and
`0xFFD6A45B` for `10d`'s badges: a domain model holding colours. Plan 23 moves
the choice into the view (`C.code`, `C.warning`) and leaves the domain
value as a kind, with no colour; the domain test's expectation moves with it.

## 3. Type

### 3.1 Families

| Family | Licence | Use | Files |
|---|---|---|---|
| **IBM Plex Sans** 400, 500, 600 (static) | SIL OFL 1.1 | Every word of UI | `assets/fonts/IBMPlexSans-{Regular,Medium,SemiBold}.ttf`, family `IBMPlexSans` |
| **IBM Plex Mono** 400, 500 | SIL OFL 1.1 | Values: hosts in rows, addresses, ports, counts, PIN digits, code | already bundled, unchanged |
| ~~Figtree~~ | | Retired; `assets/fonts/Figtree.ttf` removed | |

Static weights remove the `wght`-variation workaround `ui()` needs for
Figtree today (`typography.dart:7–9`). Plex Sans static files are Latin +
Latin-Ext; glyphs outside them fall back to the system font, as with Figtree.
Bundled cost +≈246 KB subset or +≈555 KB full (§12 assumption 5), against a
244.5 MB debug APK. OFL licence text ships beside the TTFs
(`assets/fonts/OFL-IBMPlex.txt`).

### 3.2 Scale (`T.*`)

Line height is given in sp and implemented as Flutter's `height` multiplier
(line ÷ size). **Smallest text anywhere: 13 sp, except route/format badges at
12 sp / 600**, which are always beside another cue.

| Role | `T.*` | Family | sp | Weight | Line | Tracking | Colour | Was |
|---|---|---|---|---|---|---|---|---|
| Display number (Today total) | **`display`** (new) | Mono | 40 | 500 | 48 | −0.4 | text-1 | `ui(34)` |
| Setup step title | `stepTitle` | Sans | 26 | 600 | 32 | −0.26 | text-1 | 22/600 |
| Screen title | `screenTitle` | Sans | 22 | 600 | 28 | 0 | text-1 | 16/600 |
| Sheet title | `sheetTitle` | Sans | 20 | 600 | 26 | 0 | text-1 | 17/600 |
| Centred form title (`2a`, `10b`, `10e`) | `appBarTitle` | Sans | 18 | 600 | 24 | 0 | text-1 | 15/600 |
| Keypad digit | **`keypad`** (new) | Mono | 28 | 400 | 32 | 0 | text-1 | `ui(22)` |
| Row title | `rowTitle` | Sans | 16 | 500 | 22 | 0 | text-1 | 14.5/500 |
| Row title, idle | `rowTitleIdle` | Sans | 16 | 500 | 22 | 0 | text-2 | 14.5/500 tertiary |
| Body | `body` | Sans | 16 | 400 | 24 | 0 | text-1 | 14 |
| Button label | **`label`** (new) | Sans | 16 | 600 | 20 | 0 | on-jade / text-1 (500 neutral) | `ui(14.5)` |
| Address host (pill) | **`address`** (new) | Sans | 16 | 500 | 20 | 0 | text-1 | `ui(11.5)` |
| Body, muted | `bodyMuted` | Sans | 15 | 400 | 22 | 0 | text-2 | 13 muted, h 1.65 |
| Row subtitle | **`sub`** (new) | Sans | 14 | 400 | 20 | 0 | text-2 | `ui(11–12.5)` |
| Value in a row | **`value`** (new) | Mono | 14 | 400 | 20 | 0 | text-2 | `mono(10.5–12)` |
| Section label | `sectionLabel` | Sans | 13 | 600 | 18 | +0.52 | text-2 | 10/500/+1.0 faint |
| Section label, live | `sectionLabelLive` | Sans | 13 | 600 | 18 | +0.52 | jade | 10/500 jade |
| Meta | `meta` | Sans | 13 | 400 | 18 | 0 | text-3 | 10.5 faint |
| Meta, idle | `metaIdle` | Sans | 13 | 400 | 18 | 0 | text-3 (merged with `meta`) | 10.5 dim |
| Meta value (host in a row) | **`metaValue`** (new) | Mono | 13 | 400 | 18 | 0 | text-3 | `mono(10.5)` |
| Summary beside a bar | `barSummary` | Sans | 13 | 400 | 18 | 0 | text-3 | 10 faint |
| Badge (`SOCKS5`, `PDF`, `WIPES ON EXIT`) | `barBadge` | Sans | 12 | 600 | 16 | +0.24 | text-2 | 10.5/500 faint |
| Tab label (dashboard bar) | **`tab`** (new) | Sans | 13 | 500 (600 selected) | 16 | 0 | text-1 selected / text-2 | `ui(10–11)` |
| Code | `code` | Mono | 13 | 400 | 22 | 0 | code | mono 11.5/1.9 jadeCode |
| Reader title / body | (`6b`'s own, three sizes) | Sans | 26/30/34 · 17/19/21 | 600 · 400 | 1.25 · 1.7 | 0 | reader tones | as built, family only |

`ui()` and `mono()` keep their signatures; `ui()` sets `fontFamily:
'IBMPlexSans'` and maps `weight` to the nearest static face (400/500/600; 700
→ 600). `containerTheme()`'s `fontFamily` becomes `'IBMPlexSans'`.

**Stored case is kept** (§12 Q2). Labels stored in capitals render in
capitals at 13/600 with +0.52 tracking; the restyle never transforms a string.

### 3.3 Literal sizes

`lib/` has 175 `ui(size: …)`/`mono(size: …)` literals (19 sizes, 9.5–34). The
screen plans replace each with the `T.*` role that names what it is. Where a
literal has no role, it moves up the ladder:

| Old | New | Old | New |
|---|---|---|---|
| 9.5–11.5 | 13 (12 only for badges) | 15–16 | 18 |
| 12–12.5 | 14 | 17–19 | 20 |
| 13–13.5 | 15 | 22 | 26 |
| 14–14.5 | 16 | 34 | 40 |

Mono follows the same ladder, capped at 14 for values in rows.

## 4. Space, shape, elevation

- **Spacing scale (dp):** 4, 8, 12, 16, 20, 24, 32, 48 (`S` class, new, in
  `tokens.dart`: `S.s1`…`S.s8`). Screen gutter 16; 20 on setup and lock.
- **Row heights (minimum; rows grow with text):** one line 56, two lines 72.
  `SettingRow` min 56; `SessionRow` min 72.
- **Radii (`R`, new):** 6 badge, 10 monogram/small chip, 14 input/row button,
  18 group/card, 28 sheet top, full (pill, primary button, switch). Six
  values, down from nineteen.
- **Group:** `C.surface` fill, 1 dp `C.line` outline, radius 18; rows inside
  separated by `C.lineSoft`. A new `Group` widget in `lib/ui/core/widgets/`.
  Hairlines stay as structure *inside* a group and as the one rule under a
  header; `Hairline` keeps its API and default `C.lineSoft`.
- **Inputs:** 1.5 dp `C.edge` border, 2 dp `C.textPrimary` when focused,
  radius 14.
- **Elevation:** one level. Sheets are `C.sheet` with a 1 dp `C.line` top edge
  and `BoxShadow(0, −12, 40, black 55 %)`. Nothing else casts a shadow.

## 5. Targets and controls

**48 × 48 dp minimum for every tappable thing**, 8 dp apart.

| Widget | Today | v2 |
|---|---|---|
| `IconTap` | default 40 | default **48**, icon 24 (22 in bars) |
| `AppToggle` | 44 × 26, jade track | **52 × 32**; off: no fill, 2 dp `C.edge` outline, 16 dp `C.knobOff` knob; on: `C.textPrimary` track, 24 dp `C.bg` knob carrying a 14 dp `check` drawn in `C.textPrimary`. **Not jade.** Whole row is the target, as built. |
| `PinDots` | 11 dp, 1.5 border | **14 dp**, 2 dp `C.edge` ring empty, `C.textPrimary` fill filled, 2 dp `C.danger` ring on error; 16 dp apart |
| `PinKeypad` keys | as built | 64 dp tall (56 under 640 dp, as built), digits `T.keypad`, keys on `C.surface` circles |
| `PillButton` | min 48, 14.5 label | primary **min 52**, label `T.label`; neutral `C.button` fill, text-1; danger: transparent, 1.5 dp `C.danger` outline, `C.danger` label, sub-line `T.sub` text-2 |
| `PillButton` (new tone `PillTone.dangerText`) | — | no fill, no outline, `C.danger` label 16/600, sub-line text-2, min 48: used by `8b`'s "Open without the tunnel" |
| Chips (workspace, route, `2a`) | fill change | 48 dp target, 36 visual; unselected: 1 dp `C.line` outline; **selected: `C.button` fill + 1.5 dp `C.textPrimary` outline + leading 16 dp `check`** |
| Segments (`2a` tabs/choices) | jade underline | **selected: 2 dp `C.textPrimary` outline + check**, no jade |
| Dashboard tabs | jade/inactive | selected: `C.button` pill + 1.5 dp `C.textMuted` outline + filled icon variant + `T.tab` 600; unselected text-2 |
| `StepProgress` | jade segments | done/current segments `C.textPrimary`, rest `C.edge`. Not jade |
| `StatusRail` / site light | jade/idle rail | 10 dp light: live `C.jade` fill; opening `C.warning` fill; idle 2 dp `C.edge` ring (`2c`, `5a` only; **removed from `1b` rows**) |
| Radio | jade | 20 dp: 2 dp `C.edge` ring; selected 2 dp `C.textPrimary` ring + 10 dp dot |
| Picker check | jade | `C.textPrimary` |
| Monogram | `monogramOpen`/surface | open `C.button`, idle `C.surface`; text text-1 / text-2; radius 10 |

## 6. Icons and the mark

- Icons stay `AppIcon` line icons drawn in `lib/ui/core/icons.dart` (2 dp
  round stroke, 24-unit grid); `test/no_glyphs_test.dart` keeps guarding it.
  Default colour `C.icon` (text-2).
- **Added glyphs** (existing names are never renamed or removed):
  `shieldHalf`, `shieldFull` (the pill's shield by security level: Standard
  → `shield` outline, Safer → `shieldHalf`, Safest → `shieldFull`;
  never coloured by level), `sitesFilled`, `todayFilled`, `settingsFilled`
  (selected tab), `caseSolid`, `caseBroken`, `caseDouble` (§8, `2b`).
- **`vault` is redrawn as the mark**: a rounded square case (radius ≈ 30 % of
  side), a lid seam at ≈ 33 % height, and one jewel dot centred in the lower
  part. On the lock screens the jewel is **not** jade (the vault mark lost jade
  in v2: nothing is live on a lock screen); it is `C.textPrimary`.
- **Launcher icon:** an adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`)
  with a solid `#121110` background, the case foreground in `#EDEAE4` with a
  `#7FC8A9` jewel inside the 66 dp safe circle, and a monochrome layer (themed
  icon). Legacy PNGs in `mipmap-*dpi` regenerated from
  `direction-b-instrument/app-icon.svg`. The manifest's `@mipmap/ic_launcher`
  reference and label do not change. This is resources only: `styles.xml`,
  the Android themes, `secure_window.dart` and `android_theme_test.dart` are
  untouched.
- Brand SVGs are kept in `docs/design-exploration/direction-b-instrument/`;
  nothing SVG ships in `assets/` (no `flutter_svg` dependency is added).

## 7. Motion

Two moments move; everything else is an effect that does not bounce.

| Moment | What | Spec |
|---|---|---|
| Unlock (`3a`/`9b` → dashboard) | The vault mark's lid seam lifts 2 dp and the mark fades | 320 ms, `Curves.easeOutCubic` |
| A protective change applies (reopen in place, New identity, route change) | The pill's case redraws (solid ↔ broken) and the light goes amber → jade | 320 ms; light 150 ms |
| Everything else | sheets, pages, toggles | as built (Flutter defaults), ≈150 ms |

`MediaQuery.disableAnimations` makes both moments 100 ms cross-fades. Motion
is Plan 23's last optional task; nothing else depends on it.

## 8. Per-screen notes (anything that is not a pure token swap)

Structure, order and copy are as built everywhere. Notes are visual only.

- **`1b` dashboard (and `3b`, `5b`).** Site rows in one `Group` per workspace
  list section, 72 dp; open rows show the jade light at the monogram's corner;
  idle rows show nothing there (no ring), a `rowTitleIdle` name and their
  age. Host in `metaValue`, the rest of the meta line in `meta`. Workspace
  chips per §5. The search field is a 48 dp `C.surface` field with a 1.5 dp
  `C.edge` border. The tab bar is `C.bg` with a `C.line` rule above; tabs per
  §5; labels `T.tab`.
- **`2b` container chrome.** Top bar 64 dp; pill 48 dp, `C.surface`, radius
  full. Inside the pill, left to right: the **case** (`caseSolid` for a Keep
  site, `caseBroken` for wipe-on-exit and throwaway, `caseDouble` edge when
  the route is Tor; 20 dp, text-2) with a `Semantics` label built from existing
  `6c` strings (`Keep for this site` / `Wipe on exit`), then the host in
  `T.address` — **wrapping, never ellipsized; the pill grows** — then the route
  badge (`T.barBadge`, existing `topBarRouteLabel` text) on its own line under
  the host when it does not fit, then the shield (by level, §6) and the
  reload/stop, each 48 dp. Panic: a 48 dp `IconTap` with a 1.5 dp `C.danger`
  outline, `C.danger` glyph. The load line is 2 dp `C.textMuted` on the bar.
  Bottom bar 56 dp, `C.bg` with a `C.line` rule; `N OPEN` set `T.tab` 600
  text-1, its chevron **text-1, not jade**.
- **`2a` add/edit site.** Tabs per §5 segments (no jade underline); fields
  per §4; workspace chips per §5; `Save` is the jade action.
- **`2c` tabs sheet.** Header count set exactly like the bar's `N OPEN`.
  Viewed container: jade light; background containers: `C.edge` ring. **24 dp
  between "Close all and wipe" and the panic tile.** Rows draw no case (no
  domain change).
- **`2d` settings.** Sections as `Group`s; section labels `T.sectionLabel`
  above each group; on-switches per §5 (not jade). The decoy shows the no-VAULT
  variant, as built.
- **`3a`/`4a`/`4c`/`9b`/`9c` lock and PIN.** `vault` mark redrawn (§6),
  text-1; dots and keys per §5; error text `C.danger`. `PinLayout`'s landscape
  split unchanged.
- **`3c` panic done.** On `C.bg`; the status words in text-1; no red fill.
- **`4b`/`5a` setup.** `StepProgress` per §5; `5a`'s checks text-1.
- **`5c` Today.** Total in `T.display`; category bars `C.textMuted` on
  `C.surface` tracks (not jade); counts in Mono.
- **`6a` permission ask.** Jade moves to **"Keep blocked"** (canvas; §12 Q6);
  "Allow once" becomes neutral. Words, order and actions unchanged.
- **`6b` reader.** Reader tones §2.5; family Plex Sans; sizes as built.
- **`6c` shield panel.** Order as built (§12 Q3). On-switches not jade; `Edit`
  is the jade action. Blocked counts in Mono.
- **`7b` row menu, `7c` held download.** Sheets per §4; `Remove site` and the
  wipe rows `C.danger`; `7c`'s `Discard` is the jade action, as built.
- **`8a` opening.** Steps in text-1 (current) / text-3 (pending); no jade
  progress line; the route line wraps, never spills.
- **`8b` refused.** `Try again` jade (primary); `Change proxy settings`
  neutral; **"Open without the tunnel" is `PillTone.dangerText`, 24 dp below**,
  with its existing sub-line. Drawn for direct, SOCKS5, Tor-clearnet (button
  present) and Tor-onion (absent), as `canOpenWithoutTunnel` already decides.
- **`8c` dropped.** Banner on `C.dangerSurface`, body text-2; `Reconnect`
  jade.
- **`10a`–`10e` management.** Groups; markers §2.6; `10c`'s delete on
  `C.dangerSurface` with a `C.danger` label; `10d`'s badges per §2.8 note;
  `10e` code in `C.code`.

## 9. Light mode

~~**None.** v2 is dark only.~~ **User's ruling 2026-10-06 (§12 Q1, DECISIONS
D9): a light variant.** Built by Plan 24.

- **When:** the app follows the phone's system setting
  (`MediaQuery.platformBrightness`). There is no in-app switch, so there is no
  new copy, and nothing differs by vault. A change of system setting while the
  app is open applies at once.
- **Same roles, second values.** Every `C.*` name keeps its role; light gives
  it a second value. Jade stays the one live/affirmative colour, darkened to
  spruce so it reads on a light page. Nothing about layout, type, targets or
  icons changes.
- **Android window themes stay dark.** `values/styles.xml` and
  `values-night/styles.xml` stay `Theme.Black` so WebView force-darkens pages
  (`test/android_theme_test.dart`). Consequences, accepted: a light phone sees
  the dark launch frame before Flutter's first frame, and pages inside light
  chrome are still asked `prefers-color-scheme: dark` when Force dark mode is on
  (a seam on `2b`, the cost the verdict named).
- **Status bar:** dark icons on light, light icons on dark
  (`SystemUiOverlayStyle`).

| `C.*` | Dark | Light | Role |
|---|---|---|---|
| `bg` | `#121110` | `#F3F0EA` | page |
| `bgReader` | `#15120E` | `#F6F1E7` | reader page |
| `surface`, `skeleton`, `barTrack` | `#22201D` | `#FFFFFF` / `#E9E4DC` / `#E9E4DC` | group |
| `sheet` | `#302D29` | `#FAF8F4` | sheet |
| `button`, `selected`, `monogramOpen` | `#403C37` | `#E3DDD3` | raised |
| `textPrimary`, `textSecondary`, `monogramText`, `pillText`, `focus` | `#EDEAE4` | `#1C1A17` | text-1 |
| `textTertiary`, `textMuted`, `icon`, `tabInactive` | `#CBC4B9` | `#4B453D` | text-2 |
| `textFaint`, `chevron`, `knobOff` | `#A8A095` | `#686157` | text-3 |
| `edge`, `handle`, `idleDot`, `pinEmpty` | `#958D82` | `#857D72` | edge |
| `line` / `lineSoft` | text-1 at 14 % / 8 % | text-1 at 14 % / 8 % | rules |
| `jade` | `#7FC8A9` | `#1D6B57` | live / one action |
| `onJade` | `#121110` | `#FFFFFF` | label on jade |
| `code` | `#D9CFB8` | `#7A5718` | code |
| `danger`, `pinError` | `#EE8D79` | `#B3261E` | danger |
| `dangerSurface` | `#2C201D` | `#FBEAE6` | danger-wash |
| `warning` | `#E0B266` | `#8A5800` | opening / warning |
| `readerMuted` / `readerTitle` / `readerBody` | as §2.5 | `#5E564B` / `#2B2620` / `#3A342C` | reader |
| `markers` | as §2.6 | `#7D6532`, `#3D5F8F`, `#8A5800`, `#8A4F72`, `#6E675D` | workspace markers |

**Measured (light), WCAG 2.1:** text-1 12.86–17.36:1, text-2 7.01–9.47:1,
text-3 4.53–6.11:1 on all four surfaces (so, as in dark, text-3 is allowed on
raised at 4.53); jade text 4.72–6.38:1; white on jade 6.38:1; code
4.85–6.55:1; danger 4.84–6.54:1, on danger-wash 5.61:1; edge 3.01–4.06:1;
reader muted/title/body on the reader page 6.41/13.32/10.93:1; markers
4.89–6.50:1. Warning is ≥ 5.31:1 on page, group and sheet (4.47:1 on raised,
where it is never set). Surfaces: page/group 1.14:1, raised/group 1.35:1 —
told apart, as in dark, by `C.line` outlines, not by fill alone.

## 10. Non-goals

- **No flow changes.** No screen added or removed, no element reordered, no
  navigation changed (panic stays top right of `2b`; `☰` stays; `6c` keeps its
  order).
- **No copy changes.** Every string byte-identical, including case.
- **No behaviour changes.** Taps, gestures, state, storage, routing, Kotlin:
  untouched. `6a`'s jade moving to "Keep blocked" is colour only; both buttons
  do what they do today.
- No in-app theme toggle (the light variant follows the system setting, §9), no new settings, no new dependency.
- No change to the Android theme, the manifest's label or `secure_window.dart`.

## 11. Testing and verification

- `test/no_glyphs_test.dart`, `test/ui/small_screen_layout_test.dart`,
  `test/ui/responsive_layout_test.dart`, `test/android_theme_test.dart` keep
  passing unchanged.
- Tests that assert a colour or size the spec changes have **only that
  expectation** updated to the new value (`test/app_theme_test.dart`: ink
  `0xFF121110`, family `IBMPlexSans`, the four named colours' new values;
  `pin_widgets_test.dart`'s error border `0xFFEE8D79`; `chrome_bars_test.dart`'s
  jade `N OPEN` chevron and `lock_body_test.dart`'s jade vault mark flip to
  text-1, as this spec intends).
- New tests: `test/ui/core/tokens_v2_test.dart` pins every §2 value and
  checks the §2.7 contrast floor in Dart (a `contrast()` helper in the test);
  a host-never-ellipsized test on `ContainerTopBar` at 320 × 568 and 2.0;
  `AppToggle`'s on-state is not jade; selected chip has a check.
- Gates after every plan: `flutter analyze` clean; `flutter test` all
  passing (record N/N); `flutter build apk --debug` zero `e:` lines.
- **Not verified on a device** until someone runs the device checks each plan
  lists.

## 12. Open questions — answered by the user, 2026-10-06

1. Dark only, or a light variant later? **A light variant** (built by Plan 24;
   see §9).
2. Sentence case for stored all-caps labels? **No — stored case kept.**
3. Layout rulings raised by the debate (`6c` leading with protection, panic
   out of the top-right corner, `☰` → `⋮`, Tor before SOCKS5): **no changes
   until the user has seen the restyle on a device.**
4. A visible word for wipe-on-exit/throwaway in the pill? **Yes** — the words
   themselves are new copy and wait for the user's wording; until then, shape
   + screen-reader label only.
5. Plex Sans subset or full? Settled by DECISIONS D8: **full, unsubset** (OFL
   Reserved Font Name).
6. `6a`'s jade on "Keep blocked"? **Yes, confirmed.**

Also ruled: a real per-workspace byte count (`10a`/`10c`) **needs a
threat-model ruling first** (a lightly used decoy would read "0 MB" beside
the real vault).

## 13. Self-review

Placeholders: scanned for TBD/TODO/"…" in values — every token has a final
hex, every `T.*` role a family, size, weight, line height and tracking; §2.8
says explicitly that no separate "raised" name is added, so an implementer
does not invent one. Contradictions checked: §1.2 (jade never a
position) against §5 (toggles, chips, tabs, steps, picks — none jade) and §8
(the one jade role per screen: `2b` the light, `2a`/`10b`/`10e` Save, `6a`
Keep blocked, `6c` Edit, `7c` Discard, `8b` Try again, `8c` Reconnect; `1b`
the live lights); §1.9 (copy byte-identical) against §3.2 (no case transform)
and §8 (`6a` colour only); §9 (dark only) against §6 (launcher resources only,
themes untouched). Ambiguities resolved: line heights are sp and converted to
multipliers; retired names live as deprecated aliases until Plan 23 removes
them, so each plan builds; the vault mark loses jade (lock screens have no
live state), which deliberately flips `lock_body_test.dart:152`; text-3 is
never placed on `C.button`/`C.selected` (4.23:1) — plans must use text-2
there. Remaining judgement left to the plans: which `T.*` role each of the 175
literals becomes, using §3.3 where no role fits.

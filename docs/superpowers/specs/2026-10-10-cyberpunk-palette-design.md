# Cyberpunk palette — design

**Date:** 2026-10-10. **Status:** draft for the user's review.
**Amends:** `2026-10-05-restyle-v2-design.md` ("Instrument") §2 (dark values)
and §4 (elevation). Every other section of v2 stands.

## 0. Context and rulings

The user asked to make the UI "a little bit" cyberpunk. Their rulings of
2026-10-10, chosen from options:

1. **Palette + glow, nothing more.** Cool blue-black surfaces, a neon live
   colour, and a soft glow. Layout, type, shapes, icons and copy are unchanged.
2. **Dark only.** The cyberpunk values replace `Palette.dark`. `Palette.light`
   (v2 §9) is untouched, and the app keeps following the system setting.
3. **Glow on live lights only.** The live light and the opening light glow in
   their own colour. Buttons, text, inputs and the focus ring stay flat.

A before/after mockup of `1b`, `2b`+`8c`, `4c` and `2d` was shown in the
brainstorming companion on 2026-10-10 and approved ("write the spec").

## 1. Principles kept from v2

All of v2 §1 still applies, in particular:

- **Jade means live, or the one affirmative action, never a position.** The
  role keeps its name (`C.jade`); only its dark value changes to neon. At most
  one jade role per screen.
- **Every text pairing ≥ 4.5:1; every meaningful mark ≥ 3:1; surfaces step
  ≥ 1.15:1**, as `test/ui/core/tokens_v2_test.dart` checks.
- **Copy is byte-identical.** No new strings, so no copy questions.
- Lines stay neutral (cool white at low alpha), **not cyan**: if the live
  colour also tinted every outline, it would stop meaning "live".

## 2. Dark palette (`Palette.dark`)

Only values change; every role and every `C.*` name stays. Ratios are WCAG 2.1
and were measured on 2026-10-10.

### 2.1 Surfaces

| Role (`Palette` fields) | Instrument | Cyberpunk | Step |
|---|---|---|---|
| ink: `bg` | `#121110` | `#0B0D12` | — |
| group: `surface`, `skeleton`, `barTrack` | `#22201D` | `#1A1F2A` | 1.18:1 over ink |
| sheet: `sheet` | `#302D29` | `#252B39` | 1.17:1 over group |
| raised: `button`, `selected`, `monogramOpen` | `#403C37` | `#31394A` | 1.22:1 over sheet |

### 2.2 Text, lines, edges

| Role (`Palette` fields) | Instrument | Cyberpunk | Worst pairing |
|---|---|---|---|
| text-1: `textPrimary`, `textSecondary`, `monogramText`, `pillText`, `focus` | `#EDEAE4` | `#E6EDF7` | 9.82:1 on raised |
| text-2: `textTertiary`, `textMuted`, `icon`, `tabInactive` | `#CBC4B9` | `#B8C3D6` | 6.51:1 on raised |
| text-3: `textFaint`, `chevron`, `knobOff` | `#A8A095` | `#97A3BA` | 5.57:1 on sheet (never on raised, as in v2) |
| edge: `edge`, `handle`, `idleDot`, `pinEmpty` | `#958D82` | `#7A87A0` | 3.20:1 on raised |
| `line` (14 %) | `0x24EDEAE4` | `0x24E6EDF7` | — |
| `lineSoft` (8 %) | `0x14EDEAE4` | `0x14E6EDF7` | — |

### 2.3 State

| Role (`Palette` fields) | Instrument | Cyberpunk | Worst pairing |
|---|---|---|---|
| jade (neon): `jade` | `#7FC8A9` | `#3DF5D0` | 8.36:1 on raised |
| on-jade: `onJade` | `#121110` | `#0B0D12` | 14.04:1 on jade |
| danger: `danger`, `pinError` | `#EE8D79` | `#FF7AA6` | 4.73:1 on raised; 7.00:1 on danger-wash |
| danger-wash: `dangerSurface` | `#2C201D` | `#2A1520` | text-1 on it 14.53:1 |
| amber: `warning` | `#E0B266` | `#F5D13D` | 7.75:1 on raised |
| code: `code` | `#D9CFB8` | `#C9B8FF` | 6.49:1 on raised |

### 2.4 Workspace markers (`markers`, same indices)

| Index | Instrument | Cyberpunk | On ink |
|---|---|---|---|
| 0 | brass `#C9B48A` | pink `#FF8FCF` | 9.33:1 |
| 1 | steel `#8FA5C8` | blue `#8FB0FF` | 9.09:1 |
| 2 | amber `#E0B266` | yellow `#F5D13D` | 13.02:1 |
| 3 | mauve `#C89BB4` | violet `#C49BFF` | 8.77:1 |
| 4 | stone `#A8A095` | grey `#97A3BA` | 7.65:1 |

None is the neon `jade`, so a marker is never mistaken for a live light (v2
§2.6). Marker 2 equals `warning`, as it did in v2.

### 2.5 Unchanged

- **Reader (`6b`):** `bgReader`, `readerTitle`, `readerBody` and `readerMuted`
  keep v2 §2.5's warm values. Reader is for long reading, and its own theme is
  a separate surface.
- **`Palette.light`**, in full.
- **Android resources:** the launcher icon (`ic_launcher_*.xml`, `#121110`
  and `#7FC8A9`) and the window themes (`Theme.Black`). The icon is brand,
  not UI, so changing it is a separate question.

## 3. Glow

A new, deliberately narrow exception to v2 §4's "Nothing else casts a shadow":

- **What glows:** the live light and the opening light, nothing else. That is
  `StatusRail`'s filled dot (dashboard rows, `2c`), the 8 dp dot that
  leads `ContainerTopBar`'s address pill, and the amber dot in `8a`'s address
  pill (`OpeningBody`), which is the same light before the page is up (added
  2026-10-10 during Plan 25's device check). An idle ring never glows.
- **How:** one `BoxShadow` in the light's own colour at 60 % alpha, blur
  radius 6, spread 0, offset 0. So jade glows neon, and amber (opening) glows
  yellow.
- **Dark only.** A glow on a light page reads as a smudge, so with
  `Palette.light` active there is no shadow.
- **Where it lives:** a `glow` flag on `Palette` (dark `true`, light `false`)
  and one helper in `tokens.dart`,
  `List<BoxShadow>? C.glow(Color light)`, which returns the shadow when the
  active palette glows and `null` otherwise. Both lights call it, so the rule
  lives in one place.
- **Motion:** the pill dot is already an `AnimatedContainer`, so its glow
  changes colour along with the fill, using the existing durations and the
  existing reduced-motion handling. No new animation.

## 4. Files touched

- `lib/ui/core/tokens.dart`: `Palette.dark`'s values (§2), the `glow` field
  on both palettes, `C.glow`, and the doc comments that name Instrument's hex
  values or describe jade's value.
- `lib/ui/core/widgets/status_rail.dart`: `boxShadow: lit ? C.glow(...) : null`.
- `lib/ui/features/container/views/container_top_bar.dart`: the pill dot's
  `boxShadow`.
- `docs/superpowers/specs/2026-10-05-restyle-v2-design.md`: a one-line
  pointer at the top of §2 and in §4's elevation bullet to this spec. The v2
  tables are left as the record of Instrument.
- `CLAUDE.md`: a row in the plan table once built.

## 5. Testing

- `test/ui/core/tokens_v2_test.dart`: the dark value expectations become §2's
  values. Its contrast, mark and surface-step floors stay unchanged and must
  pass as they are. That is the check this spec's numbers were tuned for.
- `test/app_theme_test.dart`, `test/ui/core/pin_widgets_test.dart`,
  `test/ui/features/management_restyle_v2_test.dart`: only the pinned dark
  values change (ink, jade, handle, pill text, danger-wash, pin error, marker
  2).
- New tests: `StatusRail` live and opening have one shadow in their own
  colour at 60 % alpha and blur 6, and idle has none; the same under
  `C.use(Brightness.light)` has none; the address pill's dot has the glow.
- Gates: `flutter analyze` clean; `flutter test` all passing (record N/N);
  `flutter build apk --debug` with zero `e:` lines (no Kotlin changes).
- **Device check** on the emulator in dark mode: `1b` with a live and an
  opening site, `2b`'s pill, `4c` after a wrong PIN, `8c`, `2d`, `10b`'s
  markers, and one light-mode screen to confirm nothing changed there. Use
  `adb emu screenrecord screenshot`, since `FLAG_SECURE` blanks normal
  screenshots.

## 6. Non-goals

Chamfered corners, uppercase mono labels, neon outlines, scanlines, a glow on
buttons or focus, new fonts, a theme switch in Settings, a cool Reader, and a
new launcher icon. Each would be its own ruling.

# Restyle — design

**Date:** 2026-10-02
**Status:** Questions answered by the user in conversation (2026-10-02); this
written spec awaits the user's review.
**Project:** 4 of 4 in the browser-chrome series
(`2026-09-28-browser-chrome-design.md` §0). That spec's §11 hands this project
one job: "extends `AppIcon` (§6.6) to every screen and removes the remaining
Unicode glyphs."
**Canvas:** `Sandbox Container -canvas-.dc.html` stays authoritative for copy,
colours, sizes and layout. This spec changes how marks are **drawn**, never
what a screen says, where things sit, or which colour they are.

## 0. Context

The browser-chrome spec chose the visual direction: **keep the Container look**
(graphite, jade, hairlines, Figtree + IBM Plex Mono), and draw icons as 2px
round-stroke line icons on a 24-unit grid (`AppIcon`, `lib/ui/core/icons.dart`)
instead of Unicode glyphs. Plan 12 did that for the container screen and the
widgets it added. Every other screen still draws its marks as text glyphs
(`‹ › × ⟳ ◑ ◉ ◇ ☉ ⛌ ✓ ⋯ ▲ ⌫ +`) or as Material `Icons.*`. Glyphs render in
whatever font the platform falls back to, at a weight and baseline the design
does not control. Several glyph `Text`s don't even use `ui()`, so they skip
Figtree entirely.

**Projects 2 and 3 (Tabs, Privacy controls; "Plans 15 and 16") have no plan
or spec in this repo** as of 2026-10-02: none on `main` or on any remote
branch. **User's ruling 2026-10-02: restyle `main` as it is now.** §8 tells
those projects how to stay in line.

### Decisions the user made (2026-10-02)

| Question | Decision |
|---|---|
| Plans 15/16 are missing | Restyle `main` now, including `2c`'s switcher and the ☰ menu. |
| Lock screen's `◇` and `☉` | Draw both: new `vault` and `fingerprint` glyphs. |
| `+`/`×` inside copy | Draw `10a`/`10d`'s jade `+` (a separate span in the canvas) and `10e`'s chip `×` (the canvas sets `Forum ×` as one span, but the `×` is the chip's remove affordance; the question put to the user wrongly called it a separate span, corrected here 2026-10-02 and the choice kept). `+ Add site` stays text (in the canvas the `+` is part of the label). |
| `8a`/`8b`/`8c` top bars | Swap the glyphs and keep the canvas layout. `8b`/`8c`'s `‹` and `⟳` stay inert (Known gap). |
| Screen-reader labels | Reuse §7's approved labels. New, approved word for word: `Close`, `Search`, `Settings`, `Delete`, `Remove`, `Reader theme`. Decorative marks get no label. |
| `2d`'s `‹` | Drawn **and** made to pop, like every other screen's `‹`. A deliberate behaviour change. |
| `⛌` (`8b`/`8c`) | A new `refused` glyph: a circle with a diagonal slash. Not `close`, so it can't be mistaken for a button. |
| Token drift | Name the hard-coded canvas colours as `C.*` tokens with the **same values**, and route raw `TextStyle(...)` through `ui()`/`T.*`. No new colours. |

## 1. Inventory

Every glyph or Material icon left in `lib/ui` at `e4e2a62`, with the canvas
block it comes from. "Inert" means drawn with no tap handler today.

| Canvas | File | Mark today | Canvas style |
|---|---|---|---|
| `1b` | `dashboard/views/workspace_bar.dart` | `Icons.keyboard_arrow_down` 14 | `▼` 9px `#7E8583` |
| `1b` (`1a` has it) | `dashboard/views/workspace_bar.dart` | `⋯` 15, opens Settings | `⋯` (`1a` only) |
| `1b` `3b` `5b` | `dashboard/views/dashboard_footer.dart` | `Icons.search` 20 in a 46px button | `⌕` 15px `#9AA1A0` |
| `1c` menu | `dashboard/views/workspace_menu.dart` | `Icons.check` 15 jade | `✓` 13px jade |
| `2a` | `add_site/views/add_site_screen.dart` | `×` 20 | `×` 20px `#9AA1A0` |
| `2b` | `container/views/container_bottom_bar.dart` | `▲` 9 jade in `N OPEN` | `▲` 9px jade |
| `2c` | `container/views/switcher_sheet.dart` | `◉` 15 danger in a 46px square; row `×` 16 | `◉` 15px; `×` 16px `#6E7573` |
| `2d` | `settings/views/settings_screen.dart` | `Icons.chevron_left` 20, **inert** | `‹` 16px `#9AA1A0` |
| `2d` `10a` `4b` | `core/widgets/setting_row.dart` | `›` 14 | `›` 14px `#6E7573` |
| `2d` pickers | `settings/views/auto_lock_picker.dart`, `search_engine_picker.dart` | `Icons.check` 15 jade | (as `1c`) |
| `3a` `4c` `9b` `9c` | `lock/views/lock_body.dart` | `◇` 17 in a 44px square; `☉` 24 | `◇` 17px jade (danger on `4c`); `☉` 24px jade (`#4A5150` on `4c`) |
| `3a` `4a` | `core/widgets/pin_keypad.dart` | `⌫` 22 | keypad key |
| `3c` | `panic/views/panic_screen.dart` | `◉` 16 danger in a 52px circle | `◉` 16px |
| `4b` | `setup/views/setup_decoy_screen.dart` | `›` 14 | `›` 14px |
| `5a` | `setup/views/setup_defaults_screen.dart` | `✓` 13 jade | `✓` 13px jade |
| `5c` | `report/views/today_screen.dart` | `‹` 16 | `‹` 16px |
| `6b` | `in_page/views/reader_screen.dart` | `‹` 16; `◑` 14 (`Aa` is letters, stays) | `#8A857C` |
| `8a` | `container/views/opening_screen.dart` | `‹` 16, `×` 16 in 32px boxes; `✓` 12 jade | `‹` 16px, `×` 15px, `✓` 12px |
| `8b` | `in_page/views/proxy_unreachable_screen.dart` | `‹`, `⟳` **inert** in 32px boxes; `⛌` 16 danger in 44px square | same |
| `8c` | `in_page/views/tunnel_dropped_screen.dart` | `‹`, `⟳` **inert**; `⛌` 13 danger | same |
| `10a` | `workspaces/views/workspaces_screen.dart` | `‹` 16; jade `+` 17 w300; row `›` 14 | same |
| `10b` | `workspaces/views/workspace_form_screen.dart` | `×` 20 | `×` 20px |
| `10d` | `scripts/views/scripts_and_filters_screen.dart` | `‹` 16; jade `+` 17 w300 | same |
| `10e` | `scripts/views/script_editor_screen.dart` | `‹` 16; chip text `Forum ×` | chip 12.5px |
| — (Plan 7 spec) | `search/views/search_screen.dart` | `‹` 16; `Icons.search` 18 | — |

Not in the tree, so not touched: `9a` (the Recents card is the OS's, blanked
by `FLAG_SECURE`), `1a`/`1c` (unbuilt dashboard alternatives).

**Already done by Plan 12:** container top bar, bottom bar (except `▲`), load
line, address field and suggestions, ☰ menu, find bar, save bar, panic square.

## 2. Glyph set

`AppGlyph` keeps its 15 members and their paths unchanged, and gains eight.
Same rules as §6.6: 2-unit round strokes on a 24-unit grid, drawn at the size
the caller passes, in the colour the caller passes.

| New glyph | Replaces | Drawing (24-unit grid) |
|---|---|---|
| `check` | `✓`, `Icons.check` | polyline (5, 12.5) → (10, 17.5) → (19, 7.5) |
| `plus` | `10a`/`10d`'s `+` | (12, 5)–(12, 19) and (5, 12)–(19, 12) |
| `more` | `⋯` | three **filled** dots, r 1.75, at (5.5, 12), (12, 12), (18.5, 12) |
| `vault` | `◇` | closed diamond (12, 3.5) (20.5, 12) (12, 20.5) (3.5, 12) |
| `fingerprint` | `☉` | concentric open arcs about (12, 13), r 8.5 / 5.5 / 2.5, the two inner ones running down into short tails, and a short centre stroke |
| `backspace` | `⌫` | outline (8.5, 5.5) (20, 5.5) (20, 18.5) (8.5, 18.5) (3.5, 12) closed, with an × from (11.5, 9.5) to (16.5, 14.5) |
| `refused` | `⛌` | circle r 8.5 at (12, 12) and a slash (6, 18)–(18, 6) |
| `contrast` | `◑` | circle r 8 stroked, its right half filled |

Reused existing glyphs: `back` for `‹`, `forward` for a row's `›` disclosure,
`close` for `×`, `reload` for `⟳`, `panic` for `◉`, `search` for `⌕` and
`Icons.search`, `chevronDown` for `▼`, `chevronUp` for `▲`. The canvas draws
`▲`/`▼` as filled triangles; the direction is line icons, so they become the
existing chevrons, as Plan 12 already did for the find bar's arrows.

The paths are drawn by eye: the canvas only ever names glyphs, so there is no
source path to copy.

## 3. Sizes and colours

Each icon is sized so its ink roughly matches the glyph it replaces, and keeps
the glyph's colour exactly. The box it sits in keeps the canvas size. Where a
row's height was set by a glyph's line height, the icon's tap box is no taller
than that line, so no row moves.

| Where | Widget | Icon size | Colour |
|---|---|---|---|
| Screen header `‹` (`2d`, `5c`, `10a`, `10d`, `10e`, search) | `IconTap(back, 'Back', size: 20, iconSize: 18)` | 18 | `C.icon` |
| `6b` header `‹` | same | 18 | `C.readerMuted` |
| `6b` `◑` | `IconTap(contrast, 'Reader theme', size: 20, iconSize: 16)` | 16 | `C.readerMuted` |
| `2a`, `10b` `×` | `IconTap(close, 'Close', size: 24, iconSize: 20)` | 20 | `C.icon` |
| `8a` `‹` / `×` (32px boxes, both cancel) | `IconTap(back, 'Back', size: 32, iconSize: 18)` / `IconTap(close, 'Close', size: 32, iconSize: 16)` | 18 / 16 | `C.icon` |
| `8b`/`8c` `‹` / `⟳` (inert) | `AppIcon` in the existing 32px box, no semantics | 18 / 16 | `C.icon` |
| `8b` `⛌` (44px square) | `AppIcon(refused)` | 20 | `C.danger` |
| `8c` `⛌` (banner) | `AppIcon(refused)` | 16 | `C.danger` |
| `3c` `◉` (52px circle) | `AppIcon(panic)` | 20 | `C.danger` |
| `2c` `◉` (46px square) | `AppIcon(panic)` inside the existing square, which gets `Semantics('Panic')` | 18 | `C.danger` |
| `2c` row `×` | `IconTap(close, 'Close', size: 24, iconSize: 16)` | 16 | `C.textFaint` |
| `2b` `▲` | `AppIcon(chevronUp)` | 12 | `C.jade` (canvas) |
| `1b` `▼` | `AppIcon(chevronDown)` | 14 | `C.chevron` |
| `1b` `⋯` | `IconTap(more, 'Settings', size: 24, iconSize: 18)` | 18 | `C.chevron` |
| Dashboard search (46px button) | `AppIcon(search)` in the existing button, which gets `Semantics('Search')` | 20 | `C.icon` |
| Search screen field | `AppIcon(search)`, decorative (the field has its own hint) | 18 | `C.icon` |
| Picker and workspace-menu check | `AppIcon(check)` | 15 | `C.jade` |
| `5a` `✓` | `AppIcon(check)` | 16 | `C.jade` |
| `8a` `✓` | `AppIcon(check)` | 14 | `C.jade` |
| Row `›` (`SettingRow`, `10a` rows, `4b`) | `AppIcon(forward)` | 16 | `C.textFaint` |
| `10a`/`10d` `+` | `AppIcon(plus)` | 18 | `C.jade` |
| `10e` chip `×` | name text, 6px gap, `AppIcon(close)` with `Semantics('Remove')`; the whole chip stays the tap target | 12 | `C.textSecondary` |
| Lock `◇` (44px square) | `AppIcon(vault)` | 20 | `C.jade`, `C.danger` when wrong |
| Lock `☉` | `AppIcon(fingerprint)`, decorative (`Use fingerprint` sits under it) | 28 | `C.jade` |
| Keypad `⌫` | `AppIcon(backspace)` with `Semantics('Delete')` | 24 | `C.textSecondary` |

`IconTap` dims to `C.textDisabled` when `onTap` is null, so inert icons use a
bare `AppIcon`, never an `IconTap` with no handler: the canvas draws `8b`/`8c`'s
`‹` and `⟳` in `C.icon`, not dimmed.

**Jade:** no jade is added or removed. Every jade mark above is jade in the
canvas block it comes from, so the "at most one per screen" count is the
canvas's, unchanged.

**The keypad's key value stays `'⌫'`.** `LockController`, `SetupFlow` and
`ChangePinRoute` compare against it; only its drawing changes.

## 4. Behaviour changes

Exactly one: `2d`'s `‹` pops the Settings route, as `5c`, `10a` and `10d`'s
do. `SettingsScreen` gains an `onBack` callback; `SettingsRoute` passes
`Navigator.pop`. Everything else is look only.

## 5. Token and typography drift

Same values, named; no visible change.

| Literal | Where | Becomes |
|---|---|---|
| `0xFFA9B0AE` | address-pill host text in `container_top_bar.dart`, `opening_screen.dart` | `C.pillText` |
| `0xFF2C3134` | sheet handle in `sheet.dart`, `switcher_sheet.dart` | `C.handle` |
| `0xFF1A1517` | `8c` banner fill in `tunnel_dropped_screen.dart` | `C.dangerPanel` |
| `0xFF4A3634` | `PinDots._errorBorder` | `C.pinError` |

Each value appears in the canvas (checked 2026-10-02). `Color(0x00000000)`
(transparent) is left as it is.

The four add-site tabs' private `_label` `TextStyle`s (Figtree 10, w500,
letter-spacing 1.0, `C.textFaint`) are exactly `T.sectionLabel`, and become
it. That also gives them `ui()`'s `wght` variation, which `typography.dart`
says Figtree needs to render at the right weight. Every other raw
`TextStyle(...)` in `lib/ui` styles a glyph and goes away with it.

## 6. Guarding it

A test reads every `.dart` file under `lib/` and fails if a line outside a
comment has `Icons.` or any of `‹ › × ⟳ ◑ ◉ ◇ ☉ ⛌ ✓ ⋯ ▲ ▼ ⌕ ☰ ≡`. `⌫` is
allowed only as the keypad's key value. Copy punctuation (`·`, `“ ”`) is not
in the set.

## 7. Testing and verification

- **Unit/widget:**
  - `icons_test.dart`: the enum's names in order, and every glyph paints at
    several sizes without throwing.
  - Every test that finds a widget by glyph text or `Icons.check` is changed
    to find it by semantics label (`find.bySemanticsLabel`, with
    `tester.ensureSemantics()`) or by `AppIcon` glyph. **Each assertion is
    kept**: what a tap does, what is found, and how many. At `e4e2a62` that
    is about 35 finders across 17 test files, listed in the plan.
  - New: `2d`'s back pops; the keypad's drawn `⌫` still sends `'⌫'`; `8b`/`8c`'s
    `‹`/`⟳` are drawn undimmed; the lock's `vault` mark turns danger on `4c`.
  - The guard test (§6).
- **Gate:** `flutter analyze` clean, `flutter test` all passing,
  `flutter build apk --debug` with zero `e:` lines. No Kotlin changes, so no
  JVM run is needed; if any Kotlin changes after all, run
  `cd android && ./gradlew :app:testDebugUnitTest` and read the JUnit XML.
- **Device:** no emulator in this environment. **Not verified on a device.**
  Screenshots are black under `FLAG_SECURE`, so checking looks needs a local
  debug build with it off, or a physical look. The screens to check are listed
  in the plan's final task.

## 8. Known gaps (deliberate)

- **`8b`/`8c`'s `‹` and `⟳` stay inert**, as they are today and as the canvas
  draws them (decoration, not buttons). Making them act is a behaviour change.
- **`+ Add site` keeps its text `+`.** In the canvas it's part of the label.
- **`Aa` stays letters.** It isn't a Unicode glyph, and the canvas sets it as
  text.
- **The icon paths are drawn by eye.** The canvas has no paths to copy.
- **The `9a` Recents card is not built**, so its `◇` isn't drawn.
- **Plans 15/16 don't exist yet.** Their screens aren't covered here.

## 9. Handoff to later projects

- **Tabs (project 2) and Privacy controls (project 3):** draw every icon with
  `AppIcon` and every tappable one with `IconTap` plus a label. The §6 guard
  test fails on a new glyph or `Icons.*`. A new glyph goes into `AppGlyph`
  under §2's rules. A new label is copy, so it is a design question first.
- `2c`'s switcher is restyled here; Tabs replaces it and keeps its `panic` and
  `close` icons.

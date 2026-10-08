# Restyle v2 — Light Variant Implementation Plan (Plan 24)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The app follows the phone's light/dark setting. Every `C.*` role
gets a second value (spec §9), the whole UI repaints when the system setting
changes, and the status bar icons follow.

**Architecture:**
- `C` stops being a class of `const` colours. It becomes static getters over
  the active `Palette`, either `Palette.dark` (today's values, unchanged) or
  `Palette.light` (spec §9).
- `C.use(Brightness)` switches between them. `ContainerApp` reads
  `MediaQuery.platformBrightness`, calls `C.use`, and when the value changes
  marks every element for rebuild. That includes the open vault's own
  navigator and the routes and sheets on it, which no `InheritedWidget` would
  reach.
- `ThemeData` is built from `C` per brightness.
- The Android window themes do not change.

**Why global state, not `Theme.of(context)`:** `C.*` is read in 72 files and
about 300 places, many of them without a `BuildContext` (painters, default
parameters, `T.*` getters). A context-based palette would mean rewriting each
one. A global palette with a whole-tree rebuild on the rare system switch
costs one helper, and it keeps every call site as it is, except that `const`
can no longer wrap a `C.*` value.

**Tech Stack:** Flutter/Dart 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` §9 (table
and measured contrast). Ruling: DECISIONS D9.

## Global Constraints

- As Plans 20–23: no copy, flow or behaviour change; never delete or weaken a
  test; keep the guard tests passing (`no_glyphs`, `small_screen_layout`,
  `responsive_layout`, `android_theme`).
- **Dark values are byte-identical to today's.** Every existing colour
  expectation stays valid in dark.
- **Nothing may differ by vault.** The palette depends only on the system
  setting.
- Do not touch `android/`.

## Tasks

### Task 1: Palette and `C` getters

**Files:** `lib/ui/core/tokens.dart`, `test/ui/core/tokens_v2_test.dart`, new
`test/flutter_test_config.dart`.

- [x] Failing tests:
  - `Palette.dark` holds exactly today's values.
  - `Palette.light` holds spec §9's values.
  - After `C.use(Brightness.light)`, `C.bg == Color(0xFFF3F0EA)`; after
    `C.use(Brightness.dark)`, `C.bg == Color(0xFF121110)`.
  - Every light text and mark pairing in spec §9 reaches its stated contrast
    (computed in the test).
- [x] Implement:
  - `class Palette` (a const constructor, one field per role).
  - `C` getters over `_active`; `C.markers` returns the active list.
  - `C.use`; `C.brightness`.
- [x] `test/flutter_test_config.dart`: a `testExecutable` that registers
  `setUp(() => C.use(Brightness.dark))`, so every test starts dark and
  existing expectations hold.
- [x] Gates; commit `feat(restyle-v2): light palette behind C (Plan 24 Task 1)`.

### Task 2: Drop `const` where a `C.*` value made it constant

**Files:** `lib/**`, `test/**`, as `flutter analyze` reports. Mechanical.

- [x] Remove `const` from each expression that contains a `C.*` read, and
  nothing else.
- [x] Default parameters such as `Color color = C.textPrimary` become
  nullable, resolved in the body with `color ?? C.textPrimary`. Call sites
  stay the same.
- [x] Gates; commit `refactor(restyle-v2): C is no longer const (Plan 24 Task 2)`.

### Task 3: Follow the system setting

**Files:** `lib/app.dart`, `lib/ui/core/theme.dart`, new
`lib/ui/core/palette_scope.dart`, tests.

- [x] Failing widget tests:
  - With `tester.platformDispatcher.platformBrightnessTestValue = Brightness.light`,
    `ContainerApp`'s scaffold paints `Palette.light.bg`.
  - Switching to dark while a pushed route is open repaints that route.
  - The status bar style is `SystemUiOverlayStyle.dark` in light and `.light`
    in dark.
  - `containerTheme(Brightness)` gives `ColorScheme.light`/`.dark` from `C`.
- [x] Implement `PaletteScope`:
  - It reads `MediaQuery.platformBrightnessOf`, calls `C.use`, and on a change
    rebuilds every element.
  - It wraps the app in `AnnotatedRegion<SystemUiOverlayStyle>`.
  - It sits in `MaterialApp.builder`, so the navigator's routes are below it.
  - `theme`/`darkTheme` come from `containerTheme`, and `themeMode` is system.
- [x] Hard-coded scrims (`Colors.black` at 0.32 and 0.55) stay: a scrim
  darkens in both themes.
- [x] Gates; commit `feat(restyle-v2): follow the system light/dark setting (Plan 24 Task 3)`.

### Task 4: Light-mode layout and contrast sweep

- [x] Run the guard tests (`small_screen_layout`, `responsive_layout`) once
  more with the light palette active. Use a temporary `setUp` and do not
  commit it.
- [x] Find any place that assumes dark. A colour on `C.bg` meant as "dark
  knob" is right in both themes, since it is the page colour.
- [x] Record what changed.

### Task 5: Verification and records

- [x] Three gates.
- [x] Render the main screens in light at 390 × 844 with golden-free
  screenshots, as a scratch test that writes PNGs. Look at them; do not
  commit them.
- [x] Record the results in this plan's Verification section.
- [x] Append a Plan 24 row to `CLAUDE.md` (**Not verified on a device**).
- [x] Commit `docs(restyle-v2): Plan 24 verification`.

## Verification

Executed 2026-10-06 on branch `restyle-implementation` (not merged), on top
of Plan 23 (`a34c7ad`; baseline `flutter analyze` clean, `flutter test`
1142/1142).

| Task | Commit | `flutter analyze` | `flutter test` |
|---|---|---|---|
| 1 Palette and `C` getters | `9b1d7ce` | (does not build alone, see D1) | (see D1) |
| 2 Drop `const` | `07afa64` | clean | 1146/1146 |
| 3 Follow the system setting | `c6ac92b` | clean | 1150/1150 |
| 4 Light sweep (one fix) | `f3cf6a4` | clean | 1151/1151 |
| 5 Records | this commit | clean | 1151/1151 |

`flutter build apk --debug` at `f3cf6a4`: built, zero `e:` lines. No Kotlin
and nothing under `android/` changed.

**New tests (9):** `tokens_v2_test.dart` +4 (`Palette.dark` is exactly the
v2 dark values; `Palette.light` is §9's; `C.use` switches; every light
pairing reaches its stated contrast, computed: text-1/2/3, jade, code and
danger ≥ 4.5:1 on all four surfaces, edge ≥ 3:1 on all four, warning and the
markers ≥ 4.5:1 on page, group and sheet, white on jade, danger and text-1 on
danger-wash, the reader tones on the reader page); `palette_scope_test.dart`
4 (a light phone gets `Palette.light.bg` and a light `Theme`; switching to
dark repaints a `const` widget on a route pushed on a *nested* navigator, as
the open vault's is, and back again — this one fails with the rebuild helper
disabled; the status bar is `SystemUiOverlayStyle.dark` in light and `.light`
in dark; `containerTheme(Brightness)` builds each from its palette and leaves
the active one as it was); `dashboard_footer_test.dart` +1 (Task 4's fix;
fails without it).

**Expectations changed (forced, mechanical; no value changed):**
- `test/ui/core/icons_test.dart` "the painter repaints only for a new glyph
  or colour": `const painter` → `final painter`, and `const` dropped from the
  three `AppIconPainter(…, C.*)` arguments.
- `test/ui/core/primitives_test.dart`: `const` dropped from four
  `DashedBox(…, color: C.line/C.danger)` calls.

**Decisions and deviations:**
- **D1. Task 1's commit does not build on its own.** Once `C` is getters,
  every `const` that read it is a compile error, and Task 2's commit removes
  them. Both tasks' gates were run together at `07afa64`.
- **D2. Default colour parameters keep a non-null `color`.** `AppIcon`,
  `IconTap`, `Hairline` and `DashedBox` take `Color? color` into a private
  field and expose `Color get color => _color ?? C.<default>`, so their
  constructors stay `const` and tests that read `.color` still get a colour;
  `ui()`/`mono()` resolve `color ?? C.textPrimary`/`C.textSecondary` in the
  body. Each private field carries a `// ignore: prefer_initializing_formals`
  (a private field cannot be a named formal).
- **D3. Cached values converted:** the four add-site tabs'
  `static final _label = T.sectionLabel` became getters; `8a`'s ring painter
  (`_RingGapPainter`) carried `C.warning` inside `paint` with
  `shouldRepaint => false`, so it now holds the colour and repaints when it
  changes. No `static`/`const` field in `lib/` holds a `C.*` value.
- **D4. `containerTheme(Brightness)` switches `C` while it reads it.**
  `MaterialApp` builds `theme` and `darkTheme` above `PaletteScope`, before
  the active palette is chosen, and `T.*` reads `C`; the function calls
  `C.use(brightness)` and restores the previous palette in a `finally`.
  `onPrimary` is `C.onJade` (in dark the same value as the old `C.bg`).
- **D5. `themeAnimationDuration: Duration.zero`.** `C` switches at once; a
  200 ms Material theme lerp would lag behind it.
- **D6. `ContainerApp`'s default home** is a private `_BareSurface` that reads
  `C.bg` in its own build, below `PaletteScope`; reading it in
  `ContainerApp.build` would take the palette before the scope set it.
- **D7. `PaletteScope` rebuilds in the same frame.** In its build, when the
  brightness differs from the last one applied (never on the first build),
  it calls `C.use` and marks every descendant element dirty; they rebuild in
  that frame's build pass, below it.
- **D8. Tests start dark on both sides:** `test/flutter_test_config.dart`
  calls `C.use(Brightness.dark)` before every test and, when a test binding
  is already up (every `testWidgets`), sets `platformBrightnessTestValue` to
  dark, so `ContainerApp` follows into dark too (the test binding's default
  is light). It never starts a binding for a plain `test()`.

**Task 4, the light sweep.** With a temporary config making every test light
(not committed): `small_screen_layout_test` and `responsive_layout_test` pass
(19/19). The whole suite in light failed only 10 tests, every one comparing
against a dark hex literal or `C.bg` where the code uses `C.onJade`, i.e.
expectations of the dark values, not light bugs. Searching for colours that
assumed dark found **one**: the dashboard's emphasised `+` drew its icon in
`C.bg` on jade (same as `C.onJade` only in dark); now `C.onJade` (`f3cf6a4`).
Left as they are, each right in both themes: the switch's knob and the
workspace marker's selected check in `C.bg` (the page colour, contrasting
with the text-1 fill and with each palette's markers); the scrims
(`Colors.black` at 0.32 and 0.55) and the sheet's one shadow (black 0.55,
blur 40), which reads heavier on a light page but sits over a scrim.

**Screenshots (Task 5).** A scratch widget test (deleted, not committed)
loaded the bundled IBM Plex fonts with `FontLoader`, rendered at 390 × 844
(2×) through `ContainerApp` with the platform set to light (the dashboard
through `test/support/dashboard_harness.dart`), shadows on, and wrote PNGs
from the render view's layer: `1b`, Settings and Today tabs, `2b`, `2b`'s
☰ menu, `2b` editing the address, `2c`, `6c`, `2d`, `3a` normal / wrong PIN /
welcome back, `2a` Basics and Network, `8a`, `8b`, `5c`, `5a`. Looked at:
nothing unreadable or still dark; jade is spruce with white labels on `8b`'s
Try again and `5a`'s Add your first site; danger reads on `3a`'s wrong PIN,
`8b`'s pill and the panic tiles; switches, segments and inputs keep their
outlines.

**Not verified on a device.** The system switch while the app is open, the
status bar icons and the launch frame are the "Device checks" below.

## Device checks

- Switch the phone between light and dark with the app open, both on the
  dashboard and inside a container, with a sheet up.
- Check that the status bar icons stay readable in both themes.
- Look at the launch frame on a light phone: it is dark, by design (spec §9).

### Done (2026-10-08, emulator)

Pixel_9 (API 36, WebView 154; **not a physical phone**). The emulator's system
theme was **light**, so the whole app came up in the light palette — the first
time this variant has run anywhere but a test.

- **Switched with the app open** (`cmd uimode night yes` / `no`), in all three
  places the check asks for: on the dashboard, **inside an open container**
  (both bars re-themed, the page itself was not reloaded), and **with the `6c`
  sheet up** (the sheet, its rows, its switches and the scrim all re-themed in
  place). That last one is the case this plan worries about, since the sheet
  lives on the open vault's own navigator below `PaletteScope`.
- **Status bar icons stay readable**: dark glyphs on the light palette, light
  glyphs on the dark one, switching with the theme.
- **Jade → spruce** holds where it matters: the dashboard's `+` is spruce with
  a **white** glyph on an empty workspace (the decoy's) — the one colour this
  plan's light sweep found and fixed (`C.bg` → `C.onJade`) — and neutral on a
  workspace that has sites, which is `emphasise` behaving correctly.
- **Not separately captured**: the dark launch frame on a light phone. It is
  spec §9's accepted deviation and the Android themes were not touched.

## Known gaps

- The dark launch frame on a light phone.
- With Force dark mode on, pages inside light chrome are still darkened
  (spec §9).

## Handoff

`C` is not `const`. A later plan must never cache a `C.*` value in a static
or `const` field, or that field will not change when the theme does.

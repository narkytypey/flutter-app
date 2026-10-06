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

- [ ] Failing tests:
  - `Palette.dark` holds exactly today's values.
  - `Palette.light` holds spec §9's values.
  - After `C.use(Brightness.light)`, `C.bg == Color(0xFFF3F0EA)`; after
    `C.use(Brightness.dark)`, `C.bg == Color(0xFF121110)`.
  - Every light text and mark pairing in spec §9 reaches its stated contrast
    (computed in the test).
- [ ] Implement:
  - `class Palette` (a const constructor, one field per role).
  - `C` getters over `_active`; `C.markers` returns the active list.
  - `C.use`; `C.brightness`.
- [ ] `test/flutter_test_config.dart`: a `testExecutable` that registers
  `setUp(() => C.use(Brightness.dark))`, so every test starts dark and
  existing expectations hold.
- [ ] Gates; commit `feat(restyle-v2): light palette behind C (Plan 24 Task 1)`.

### Task 2: Drop `const` where a `C.*` value made it constant

**Files:** `lib/**`, `test/**`, as `flutter analyze` reports. Mechanical.

- [ ] Remove `const` from each expression that contains a `C.*` read, and
  nothing else.
- [ ] Default parameters such as `Color color = C.textPrimary` become
  nullable, resolved in the body with `color ?? C.textPrimary`. Call sites
  stay the same.
- [ ] Gates; commit `refactor(restyle-v2): C is no longer const (Plan 24 Task 2)`.

### Task 3: Follow the system setting

**Files:** `lib/app.dart`, `lib/ui/core/theme.dart`, new
`lib/ui/core/palette_scope.dart`, tests.

- [ ] Failing widget tests:
  - With `tester.platformDispatcher.platformBrightnessTestValue = Brightness.light`,
    `ContainerApp`'s scaffold paints `Palette.light.bg`.
  - Switching to dark while a pushed route is open repaints that route.
  - The status bar style is `SystemUiOverlayStyle.dark` in light and `.light`
    in dark.
  - `containerTheme(Brightness)` gives `ColorScheme.light`/`.dark` from `C`.
- [ ] Implement `PaletteScope`:
  - It reads `MediaQuery.platformBrightnessOf`, calls `C.use`, and on a change
    rebuilds every element.
  - It wraps the app in `AnnotatedRegion<SystemUiOverlayStyle>`.
  - It sits in `MaterialApp.builder`, so the navigator's routes are below it.
  - `theme`/`darkTheme` come from `containerTheme`, and `themeMode` is system.
- [ ] Hard-coded scrims (`Colors.black` at 0.32 and 0.55) stay: a scrim
  darkens in both themes.
- [ ] Gates; commit `feat(restyle-v2): follow the system light/dark setting (Plan 24 Task 3)`.

### Task 4: Light-mode layout and contrast sweep

- [ ] Run the guard tests (`small_screen_layout`, `responsive_layout`) once
  more with the light palette active. Use a temporary `setUp` and do not
  commit it.
- [ ] Find any place that assumes dark. A colour on `C.bg` meant as "dark
  knob" is right in both themes, since it is the page colour.
- [ ] Record what changed.

### Task 5: Verification and records

- [ ] Three gates.
- [ ] Render the main screens in light at 390 × 844 with golden-free
  screenshots, as a scratch test that writes PNGs. Look at them; do not
  commit them.
- [ ] Record the results in this plan's Verification section.
- [ ] Append a Plan 24 row to `CLAUDE.md` (**Not verified on a device**).
- [ ] Commit `docs(restyle-v2): Plan 24 verification`.

## Verification

(Filled in by the executing session.)

## Device checks

- Switch the phone between light and dark with the app open, both on the
  dashboard and inside a container, with a sheet up.
- Check that the status bar icons stay readable in both themes.
- Look at the launch frame on a light phone: it is dark, by design (spec §9).

## Known gaps

- The dark launch frame on a light phone.
- With Force dark mode on, pages inside light chrome are still darkened
  (spec §9).

## Handoff

`C` is not `const`. A later plan must never cache a `C.*` value in a static
or `const` field, or that field will not change when the theme does.

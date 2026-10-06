# Critic — implementation cost (round 1)

One lens: what each direction costs to build in *this* tree, measured with
grep and one compile experiment. Effort is in agent-days of plan execution
(one session, tests green at each step), not calendar time.

## What all three pay (the shared floor)

Every direction raises the type floor, adopts 48 dp targets, replaces
hairline lists with grouped surfaces and sentence-cases labels. That floor is
already large:

- **Type.** 175 `ui(size: …)` calls in 52 files, 66 of them at 12.x sp or
  below (34 files); every `T.*` getter in `lib/ui/core/typography.dart`
  changes. Nothing here is a token swap (AUDIT §5).
- **Containment.** 46 files under `lib/ui/` draw `Hairline`/`C.line*`. A new
  grouped-surface widget (none exists in `lib/ui/core/widgets/`) has to be
  threaded through Settings, `2a`'s three tabs, `6c`, `10a`, `10d`, Today,
  `2c`, the ☰ sheet. Tests mostly find by text and glyph, so they survive.
- **Geometry.** `ContainerTopBar` (34 dp pill, 9.5 sp route label),
  `ContainerBottomBar`, `PinKeypad` (its `< 640` compact rule), `PinDots`
  (11 dp), `AppToggle` (44×26) all change size. This is where
  `test/ui/small_screen_layout_test.dart` (320×568) and
  `responsive_layout_test.dart` (landscape PIN layout, 2.0 scale monograms,
  `2a` tabs) start failing. Bigger type is overflow risk on exactly the
  screens those guards were written for.
- **Sentence case is not free in Flutter, and is a rule break.** All three
  briefs say "via CSS `text-transform`, the stored string is unchanged".
  Flutter has no text-transform: the displayed string *is* the `Text` data
  that `find.text` matches. Sentence-casing means either rewriting the
  literals or wrapping each in a transform, and either way about **90
  `find.text('ALL CAPS')` finders in 23 test files** move (`'1 OPEN'` ×7,
  `'SAVED SITES'` ×5, `'ITS OWN CONTAINER'` ×5, `'WIPES ON EXIT'` ×4,
  `'312 BLOCKED'`, `'2 OPEN SESSIONS'`…). It also collides head-on with
  CLAUDE.md's "never re-capitalise user-facing copy", so it needs a user
  ruling before any direction ships it. Cost is the same for A, B, C.
- **New glyphs** are cheap if they are `AppGlyph` painters
  (`lib/ui/core/icons.dart`); `test/no_glyphs_test.dart` only rejects Unicode
  marks and `Icons.*`. Renaming or dropping an existing glyph breaks the 35
  test files that use `findGlyph`/`findIconTap`; adding does not.
- **Motion.** Each direction adds two animated moments (unlock, reopen in
  place). Both hook onto existing state (`SessionController` transition,
  `OpenContainers.reopenInPlace`) and can be done view-side, but they need
  a reduced-motion branch and widget tests with pumped durations.
- **Launcher/logo**: new adaptive icon resources under `android/app/src/main/res/mipmap-*`. Not the Android *theme*, so in scope, but outside `lib/`.

Floor estimate: **~55–65 files in `lib/ui/`, ~30 test files, 6–8
agent-days**, before any direction-specific work.

## The light theme (A and C only) — the big one

Every `C.*` is a `static const Color`. A light theme needs the value to
depend on brightness at runtime. I copied `lib/` and `test/` to a scratch
directory, changed `C`'s 52 `static const` to `static final`, and ran
`dart analyze`: **84 errors in 45 files** (43 in `lib/`, 2 in tests) —
73 `invalid_constant`, 6 `non_constant_default_value`. The six defaults are
load-bearing: `ui()`/`mono()` default `color = C.textPrimary` /
`C.textSecondary`, and `AppIcon`, `IconTap`, `Hairline`, `DashedBox` default
to a `C` colour. That is only the compile cost of *non-const*. Making the
values actually follow `MediaQuery.platformBrightness` is one of two things:

1. **Context-scoped palette** (`ThemeExtension` or an inherited `Palette`):
   all **430 `C.` references in 71 files** become `context`-reads, every
   `T.*` getter (44 references, 27 files) needs a context, the six
   default-parameter widgets lose their defaults, and the **90 `C.*`
   references in 24 test files** need a palette instance. Correct, and the
   single largest refactor in the whole exploration: ~3–4 agent-days alone.
2. **Global palette swapped at the root** with a forced rebuild. Cheaper on
   paper, but nothing rebuilds const subtrees or widgets whose inputs did not
   change, and the obvious fix — re-keying the app root — remounts
   `AppGate`'s `_OpenVault` navigator, popping every open container on a
   system theme change. That is a behaviour change, which is forbidden.

Also on the light-theme bill:

- `lib/ui/core/theme.dart` needs a light `ThemeData` and `ColorScheme`;
  `lib/app.dart` needs `darkTheme`/`themeMode: system`.
- `test/app_theme_test.dart` asserts `Brightness.dark` and five literal
  hexes; `test/ui/core/pin_widgets_test.dart` one more (`#4A3634`).
- **Status-bar icons.** Nothing in `lib/` sets `SystemUiOverlayStyle`
  today, because white-on-black is always right. Light chrome needs it on
  every top-level surface, or the status bar is white icons on paper.
- **`lib/domain/models/user_script.dart`** hard-codes `0xFF9FD8C0` and
  `0xFFD6A45B` for the `10d` badges — a domain model holding colours, which
  must move to the UI layer to be theme-aware.
- 9 `C.line*` white-alpha hairlines and 6 `Colors.white/black.withValues`
  sites (`sheet.dart` ×4, `site_row_menu.dart`, `script_editor_screen.dart`,
  `container_screen.dart`) invert meaning on light.
- What does **not** move: `android/app/src/main/res/values/styles.xml`
  stays `Theme.Black`, `test/android_theme_test.dart` stays green, and
  `lib/data/services/secure_window.dart` only sets FLAG_SECURE and the
  recents label — untouched. The cost of that choice is A's and C's own
  admitted one: a black launch flash before a paper lock screen, and pages
  told `prefers-color-scheme: dark` inside light chrome. Neither is fixable
  without the Android change that is out of scope.

## Per direction

### A — Daylight
Floor + light theme + new fonts (Atkinson Hyperlegible Next and Mono: two
TTFs into `assets/fonts/`, `pubspec.yaml`, both families in
`typography.dart`, Figtree and Plex Mono removed; `app_theme_test.dart`'s
`'Figtree'` assert changes). Jade kept in dark, spruce in light: the jade
semantics tests (`chrome_bars_test`, `lock_body_test`,
`dashboard_footer_test`…) keep their meaning but their palette API changes.
Container-type icon in the pill needs `cookiePolicy`/`throwaway` passed into
`ContainerScreen` → `ContainerTopBar`; `ContainerRoute.build` already holds
`viewed.site` and `viewed.throwaway`, so it is a view parameter, not a
provider change. New glyphs: box solid/dashed, lid mark.
**~80–90 lib files, ~45 test files, 12–15 agent-days.**
Riskiest change: the palette refactor.

### B — Instrument
Floor + dark-only token *value* swap (the cheap path AUDIT §5 describes:
71 files follow, 7 literal-hex expectations move, merged roles can stay as
aliases so no test rename) + IBM Plex Sans (three static TTFs, pubspec, and
`typography.dart` loses its Figtree `wght`-variation workaround). Taking jade
off positions touches the 45 `C.jade` references in 30 files and redraws
`AppToggle` (white track + check); `chrome_bars_test.dart:117` (`N OPEN`
chevron is jade) and `lock_body_test.dart:152` (vault mark is jade) are
*meant* to flip. Case shape in the pill: the same view parameter as A. If
`2c` rows show solid vs broken cases, `SwitcherEntry`
(`lib/domain/models/switcher_entry.dart`) gains a field. New glyphs: case
solid/broken, shield by level (outline/half/full), direct arrow.
**~60–70 lib files, ~30 test files, 7–9 agent-days.**
Riskiest change: overflow at 320×568 and 2.0 scale from the type floor — a
known, test-guarded risk, not a structural one.

### C — Rooms
Floor + the same light-theme refactor as A + three things no other
direction has:

1. **Workspace colour in the chrome.** Only `10a`/`10b` read `C.markers`
   today. The route already watches `workspacesProvider` and has
   `viewed.site.workspaceId`, so the lookup is local — but the marker must
   be passed to `ContainerScreen`, `ContainerTopBar`, `ContainerBottomBar`,
   `OpeningBody` (`8a`), `ProxyUnreachableScreen` (`8b`),
   `TunnelDroppedScreen` (`8c`), `SiteSheet` (`6c`), `WorkspaceChips` and
   the dashboard room panel. `2c`'s room cards need it per entry, so
   `switcherEntries()` in `lib/domain/tabs.dart` must take the workspace
   list and `SwitcherEntry` gains a marker: a **domain** change with its own
   tests. `C.markers` becomes five four-value families × two themes.
2. **Jade retired as a meaning.** All 45 `C.jade` references and 4
   `C.warning` references are reassigned; `StatusRail` (3 files) becomes a
   door painter with an animated "opening" arc; ~10 test files that encode
   the jade rule (`site_sheet_test`, `switcher_sheet_test`,
   `workspace_chips_test`, `new_identity_sheet_test`, `wipe_site_sheet_test`…)
   are rewritten, not edited. The rule itself is a CLAUDE.md global
   constraint.
3. **The walled page.** `screens.html` insets the page 8 dp each side
   inside an 18 dp-radius clipped border. The page is a `PlatformViewLink`
   with `initSurfaceAndroidView` (`container_web_view.dart`): clipping a
   platform view to a rounded rect is the one place where "just visuals"
   reaches native compositing, and it can fall back to a slower composition
   mode or leave square corners on some devices. It also narrows every
   page's viewport.

No new fonts (its one saving). Figtree at 28/30 sp titles and 17 sp rows is
the biggest type increase of the three, so the most overflow risk.
**~90–100 lib files incl. 2 domain files, ~50 test files, 15–19
agent-days.**
Riskiest change: the clipped platform view — the only change in any
direction that cannot be fully checked by `flutter test` and needs a device.

## Verdict

Cheapest to most expensive: **B ≪ A < C**, roughly 1 : 1.7 : 2.1. B is the
only direction that can be done as token values plus the shared floor. A and
C both pay the context-palette refactor, which is bigger than all of B's
direction-specific work combined; C adds domain plumbing, a rewrite of the
jade-rule tests and a native-compositing risk. None of the three *requires*
a provider or controller change, but C's `2c` cards require a domain-model
change, and the cheap light-theme shortcut would cause a behaviour change, so
it is ruled out. All three need a copy ruling on sentence case before
implementation.

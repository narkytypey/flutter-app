# Cyberpunk Palette Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give dark mode a cool blue-black palette with a neon live colour, and a soft glow on the live and opening lights, changing nothing else.

**Architecture:** Every colour is read through `C.*` (`lib/ui/core/tokens.dart`), which returns the active `Palette`. Task 1 changes only `Palette.dark`'s values, so every screen re-themes with no call-site edits. Task 2 adds a `glow` flag to `Palette` and one helper, `C.glow(Color)`, which the two light widgets call. Task 3 records it in the docs and runs the gates and device check.

**Tech Stack:** Flutter stable / Dart 3, `flutter_test`. No Kotlin changes.

**Spec:** `docs/superpowers/specs/2026-10-10-cyberpunk-palette-design.md` (approved by the user 2026-10-10). It amends `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` §2 (dark values) and §4 (elevation).

**Plan number:** 25 (after restyle v2's Plans 20–24).

## Global Constraints

- Only `Palette.dark` changes. `Palette.light` is untouched, value for value.
- Reader keeps v2's warm values: `bgReader #15120E`, `readerTitle #EFE8DC`, `readerBody #D3CBBE`, `readerMuted #A39A8C`.
- Every role and every `C.*` name stays. No call site changes for colour.
- Copy is byte-identical: no string changes anywhere.
- Lines stay neutral (`0x24E6EDF7`, `0x14E6EDF7`), never cyan.
- The glow is one `BoxShadow`: the light's own colour at 60 % alpha, blur radius 6, spread 0, offset 0. It is only on `StatusRail`'s filled dot and `ContainerTopBar`'s address-pill dot, and only while the dark palette is active.
- Existing floors in `test/ui/core/tokens_v2_test.dart` stay as written: text ≥ 4.5:1, marks ≥ 3:1, surface steps ≥ 1.15:1. Only pinned hex values change.
- Out of scope: Android resources (launcher icon, window themes), fonts, shapes, layout, glow on anything else, any theme switch.
- Flutter and Gradle commands need the Bash sandbox disabled (`CLAUDE.md`, "Working on this repo").

## Review Focus

1. **An idle light never glows.** On the dashboard, idle is shown by the light being absent, and in `2c` by a hollow ring. A glow on either would read as live. Pinned in Task 2, Step 1 (`idle has no glow`).
2. **Light mode never glows, including when the phone switches theme while the app is open.** `C.use` changes the palette at runtime. Pinned in Task 2, Step 1 (`no glow under the light palette`).
3. **An opening site that goes live ends with a jade glow, not amber.** The pill dot is an `AnimatedContainer`, so a stale shadow would leave a yellow halo around a jade dot. Pinned in Task 2, Step 1 (`opening to live ends on the jade glow`).
4. **With animations off, the glow is still there.** Reduced motion swaps the duration (`stillDuration`), not the decoration. Pinned in Task 2, Step 1 (`glow holds with animations off`).
5. **The glow is clipped in a scrolling row** (dashboard list, `2c`) if a parent clips its bounds, leaving a square halo. No widget test can see this, so it is item 1 of Task 3's device check.

---

### Task 1: Cyberpunk values in `Palette.dark`

**Files:**
- Modify: `lib/ui/core/tokens.dart` (header doc comment lines 3–12; `Palette.dark`, lines 95–141)
- Test: `test/ui/core/tokens_v2_test.dart`, `test/app_theme_test.dart`, `test/ui/core/pin_widgets_test.dart`, `test/ui/features/management_restyle_v2_test.dart`, `test/ui/features/opening_screen_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `Palette.dark` with the values below. No API change.

- [ ] **Step 1: Update the pinned dark values in the tests (make them fail)**

In `test/ui/core/tokens_v2_test.dart`, replace the first two tests with:

```dart
  test('surfaces are the four cyberpunk tones', () {
    expect(C.bg, const Color(0xFF0B0D12));
    expect(C.surface, const Color(0xFF1A1F2A));
    expect(C.sheet, const Color(0xFF252B39));
    expect(C.button, const Color(0xFF31394A));
    expect(C.selected, const Color(0xFF31394A));
  });

  test('text tones and state colours', () {
    expect(C.textPrimary, const Color(0xFFE6EDF7));
    expect(C.textMuted, const Color(0xFFB8C3D6));
    expect(C.textFaint, const Color(0xFF97A3BA));
    expect(C.jade, const Color(0xFF3DF5D0));
    expect(C.danger, const Color(0xFFFF7AA6));
    expect(C.warning, const Color(0xFFF5D13D));
    expect(C.edge, const Color(0xFF7A87A0));
    expect(C.code, const Color(0xFFC9B8FF));
    expect(C.lineSoft, const Color(0x14E6EDF7));
    expect(C.line, const Color(0x24E6EDF7));
  });
```

In the same file, replace the whole `test('Palette.dark holds exactly the v2 dark values', ...)` with:

```dart
    test('Palette.dark holds exactly the cyberpunk dark values', () {
      const d = Palette.dark;
      expect(d.bg, const Color(0xFF0B0D12));
      // Reader keeps v2's warm values (cyberpunk spec §2.5).
      expect(d.bgReader, const Color(0xFF15120E));
      expect(d.surface, const Color(0xFF1A1F2A));
      expect(d.skeleton, const Color(0xFF1A1F2A));
      expect(d.barTrack, const Color(0xFF1A1F2A));
      expect(d.sheet, const Color(0xFF252B39));
      for (final c in [d.button, d.selected, d.monogramOpen]) {
        expect(c, const Color(0xFF31394A));
      }
      for (final c in [d.textPrimary, d.textSecondary, d.monogramText, d.pillText, d.focus]) {
        expect(c, const Color(0xFFE6EDF7));
      }
      for (final c in [d.textTertiary, d.textMuted, d.icon, d.tabInactive]) {
        expect(c, const Color(0xFFB8C3D6));
      }
      for (final c in [d.textFaint, d.chevron, d.knobOff]) {
        expect(c, const Color(0xFF97A3BA));
      }
      for (final c in [d.edge, d.handle, d.idleDot, d.pinEmpty]) {
        expect(c, const Color(0xFF7A87A0));
      }
      expect(d.line, const Color(0x24E6EDF7));
      expect(d.lineSoft, const Color(0x14E6EDF7));
      expect(d.jade, const Color(0xFF3DF5D0));
      expect(d.onJade, const Color(0xFF0B0D12));
      expect(d.code, const Color(0xFFC9B8FF));
      expect(d.danger, const Color(0xFFFF7AA6));
      expect(d.pinError, const Color(0xFFFF7AA6));
      expect(d.dangerSurface, const Color(0xFF2A1520));
      expect(d.warning, const Color(0xFFF5D13D));
      expect(d.readerMuted, const Color(0xFFA39A8C));
      expect(d.readerTitle, const Color(0xFFEFE8DC));
      expect(d.readerBody, const Color(0xFFD3CBBE));
      expect(d.markers, const [
        Color(0xFFFF8FCF),
        Color(0xFF8FB0FF),
        Color(0xFFF5D13D),
        Color(0xFFC49BFF),
        Color(0xFF97A3BA),
      ]);
    });
```

In the same file, in `test('C.use switches the active palette', ...)`, change the last `bg` line:

```dart
      expect(C.bg, const Color(0xFF0B0D12));
```

Leave every other test in that file (the contrast, mark, step and light-palette tests) exactly as it is.

In `test/app_theme_test.dart`, change the two colour lines in `'the app boots on the container dark theme'`, and the body of the second test:

```dart
    expect(theme.scaffoldBackgroundColor, const Color(0xFF0B0D12));
    expect(theme.colorScheme.primary, const Color(0xFF3DF5D0));
```

```dart
  test('the restyle names four canvas colours without changing them', () {
    expect(C.handle, const Color(0xFF7A87A0));
    expect(C.pillText, const Color(0xFFE6EDF7));
    expect(C.dangerSurface, const Color(0xFF2A1520));
    expect(C.pinError, const Color(0xFFFF7AA6));
  });
```

In `test/ui/core/pin_widgets_test.dart`, in `'an errored dot row uses the danger border'`:

```dart
    expect(border.top.color, const Color(0xFFFF7AA6));
```

In `test/ui/features/management_restyle_v2_test.dart`, replace the first test:

```dart
  test('the markers are the cyberpunk five: pink, blue, yellow, violet, grey', () {
    expect(C.markers, const [
      Color(0xFFFF8FCF),
      Color(0xFF8FB0FF),
      Color(0xFFF5D13D),
      Color(0xFFC49BFF),
      Color(0xFF97A3BA),
    ]);
    expect(C.markers, isNot(contains(C.jade)));
  });
```

In `test/ui/features/opening_screen_test.dart`, the loop at the end pins Instrument's jade hex, which would pass vacuously after the change. Make it read the token:

```dart
    // Nothing on 8a is jade: nothing is live yet.
    for (final icon in tester.widgetList<AppIcon>(find.byType(AppIcon))) {
      expect(icon.color, isNot(C.jade));
    }
```

`opening_screen_test.dart` does not import the tokens yet. Add `import 'package:container/ui/core/tokens.dart';` after its `icons.dart` import.

- [ ] **Step 2: Run the tests and see them fail**

Run: `flutter test test/ui/core/tokens_v2_test.dart test/app_theme_test.dart test/ui/core/pin_widgets_test.dart test/ui/features/management_restyle_v2_test.dart test/ui/features/opening_screen_test.dart`
Expected: FAIL in the value tests (for example `Expected: Color(alpha: 1.0000, red: 0.0431, ...)`, `Actual: Color(... 0.0706 ...)`). `opening_screen_test.dart` passes either way: Instrument's 8a has no jade icon.

- [ ] **Step 3: Replace `Palette.dark`'s values**

In `lib/ui/core/tokens.dart`, replace the block from `/// Spec §2: the dark values, unchanged since Plan 20.` through the closing `);` of `static const dark = Palette(` with:

```dart
  /// Cyberpunk spec (`2026-10-10-cyberpunk-palette-design.md`) §2: cool
  /// blue-black surfaces and a neon live colour. Reader keeps v2 §2.5's warm
  /// values.
  static const dark = Palette(
    bg: Color(0xFF0B0D12),
    bgReader: Color(0xFF15120E),
    surface: Color(0xFF1A1F2A),
    sheet: Color(0xFF252B39),
    button: Color(0xFF31394A),
    selected: Color(0xFF31394A),
    monogramOpen: Color(0xFF31394A),
    knobOff: Color(0xFF97A3BA),
    skeleton: Color(0xFF1A1F2A),
    barTrack: Color(0xFF1A1F2A),
    handle: Color(0xFF7A87A0),
    lineSoft: Color(0x14E6EDF7),
    line: Color(0x24E6EDF7),
    edge: Color(0xFF7A87A0),
    focus: Color(0xFFE6EDF7),
    textPrimary: Color(0xFFE6EDF7),
    textSecondary: Color(0xFFE6EDF7),
    textTertiary: Color(0xFFB8C3D6),
    textMuted: Color(0xFFB8C3D6),
    textFaint: Color(0xFF97A3BA),
    monogramText: Color(0xFFE6EDF7),
    icon: Color(0xFFB8C3D6),
    chevron: Color(0xFF97A3BA),
    tabInactive: Color(0xFFB8C3D6),
    pillText: Color(0xFFE6EDF7),
    readerMuted: Color(0xFFA39A8C),
    readerTitle: Color(0xFFEFE8DC),
    readerBody: Color(0xFFD3CBBE),
    jade: Color(0xFF3DF5D0),
    onJade: Color(0xFF0B0D12),
    code: Color(0xFFC9B8FF),
    idleDot: Color(0xFF7A87A0),
    pinEmpty: Color(0xFF7A87A0),
    danger: Color(0xFFFF7AA6),
    dangerSurface: Color(0xFF2A1520),
    warning: Color(0xFFF5D13D),
    pinError: Color(0xFFFF7AA6),
    markers: <Color>[
      Color(0xFFFF8FCF),
      Color(0xFF8FB0FF),
      Color(0xFFF5D13D),
      Color(0xFFC49BFF),
      Color(0xFF97A3BA),
    ],
  );
```

Then update the file's header doc comment (lines 3–9) to:

```dart
/// Colour tokens for the Isolated Web Container — restyle v2 ("Instrument")
/// with the cyberpunk dark palette.
///
/// Dark values come from `docs/superpowers/specs/2026-10-10-cyberpunk-palette-design.md`
/// §2, light values from `docs/superpowers/specs/2026-10-05-restyle-v2-design.md`
/// §9. Four surfaces, three text tones (each ≥ 4.5:1
/// wherever the spec lets it sit), jade for live state or the one affirmative
/// action and never for a position. If a screen needs a colour that is not
/// here, that is a design question, not an implementation one.
```

Leave the rest of the header (from `/// [Palette.dark] and [Palette.light] ...`) as it is.

- [ ] **Step 4: Run the same tests and see them pass**

Run: `flutter test test/ui/core/tokens_v2_test.dart test/app_theme_test.dart test/ui/core/pin_widgets_test.dart test/ui/features/management_restyle_v2_test.dart test/ui/features/opening_screen_test.dart`
Expected: all PASS, including the unchanged contrast, mark and surface-step floors. If a floor fails, a value in Step 3 was mistyped: compare it with the spec's §2 tables. Never loosen a floor.

- [ ] **Step 5: Run the full suite and analyzer**

Run: `flutter analyze` then `flutter test`
Expected: `No issues found!` and all tests passing. Any other failure is a test that pins an Instrument dark hex this plan missed. Update only that expectation to the spec's value, and record the file in the commit message.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/core/tokens.dart test/
git commit -m "feat(theme): cyberpunk dark palette

Cool blue-black surfaces, neon live colour, pink danger, neon yellow
amber, lavender code and new workspace markers. Light mode and Reader
are unchanged. Spec: 2026-10-10-cyberpunk-palette-design.md §2.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Glow on the live and opening lights

**Files:**
- Modify: `lib/ui/core/tokens.dart` (imports; `Palette` constructor, fields, both palettes; `C`)
- Modify: `lib/ui/core/widgets/status_rail.dart`
- Modify: `lib/ui/features/container/views/container_top_bar.dart` (the pill dot, about line 168)
- Create: `test/ui/core/glow_test.dart`

**Interfaces:**
- Consumes: `Palette.dark` and `Palette.light` from Task 1.
- Produces: `Palette.glow` (`final bool`; dark `true`, light `false`) and `static List<BoxShadow>? C.glow(Color light)`.

- [ ] **Step 1: Write the failing tests**

Create `test/ui/core/glow_test.dart`:

```dart
import 'package:container/domain/models/security_level.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/status_rail.dart';
import 'package:container/ui/features/container/views/container_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cyberpunk spec §3: the live and opening lights glow in their own colour,
/// dark palette only; nothing else does.
BoxShadow _glowOf(Color c) => BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6);

BoxDecoration _railDecoration(WidgetTester tester, Finder rail) => tester
    .widget<Container>(find.descendant(of: rail, matching: find.byType(Container)))
    .decoration! as BoxDecoration;

/// The pill dot as painted (mid-animation values included).
BoxDecoration _pillDot(WidgetTester tester) {
  final dot = find.descendant(
      of: find.byKey(const Key('address-pill')), matching: find.byType(AnimatedContainer));
  return tester
      .widget<DecoratedBox>(find.descendant(of: dot, matching: find.byType(DecoratedBox)).first)
      .decoration as BoxDecoration;
}

Widget _topBar({required bool live, bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: const Size(360, 640), disableAnimations: still),
        child: Scaffold(
          body: Column(children: [
            ContainerTopBar(
              host: 'example.com',
              routeLabel: 'SOCKS5',
              live: live,
              loading: false,
              onEditAddress: () {},
              onStop: () {},
              onReload: () {},
              onSiteDetails: () {},
              openCount: 1,
              onOpenSwitcher: () {},
              onMenu: () {},
              caseKind: CaseKind.keep,
              tor: false,
              securityLevel: SecurityLevel.standard,
            ),
          ]),
        ),
      ),
    );

void main() {
  tearDown(() => C.use(Brightness.dark));

  test('C.glow is one 60 % shadow, blur 6, in the light\'s colour, dark only', () {
    C.use(Brightness.dark);
    expect(Palette.dark.glow, isTrue);
    expect(Palette.light.glow, isFalse);
    expect(C.glow(C.jade), [_glowOf(C.jade)]);
    C.use(Brightness.light);
    expect(C.glow(C.jade), isNull);
  });

  testWidgets('a live and an opening light glow in their own colour', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Row(children: [StatusRail(live: true), StatusRail(live: false, opening: true)])));
    final rails = find.byType(StatusRail);
    expect(_railDecoration(tester, rails.at(0)).boxShadow, [_glowOf(C.jade)]);
    expect(_railDecoration(tester, rails.at(1)).boxShadow, [_glowOf(C.warning)]);
  });

  testWidgets('idle has no glow', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Row(children: [StatusRail(live: false)])));
    expect(_railDecoration(tester, find.byType(StatusRail)).boxShadow, isNull);
  });

  testWidgets('no glow under the light palette', (tester) async {
    C.use(Brightness.light);
    await tester.pumpWidget(const MaterialApp(home: Row(children: [StatusRail(live: true)])));
    expect(_railDecoration(tester, find.byType(StatusRail)).boxShadow, isNull);
    await tester.pumpWidget(_topBar(live: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, anyOf(isNull, isEmpty));
  });

  testWidgets("the address pill's dot glows jade when live", (tester) async {
    await tester.pumpWidget(_topBar(live: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, [_glowOf(C.jade)]);
  });

  testWidgets('opening to live ends on the jade glow', (tester) async {
    await tester.pumpWidget(_topBar(live: false));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, [_glowOf(C.warning)]);
    await tester.pumpWidget(_topBar(live: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).color, C.jade);
    expect(_pillDot(tester).boxShadow, [_glowOf(C.jade)]);
  });

  testWidgets('glow holds with animations off', (tester) async {
    await tester.pumpWidget(_topBar(live: true, still: true));
    await tester.pumpAndSettle();
    expect(_pillDot(tester).boxShadow, [_glowOf(C.jade)]);
  });
}
```

`ContainerTopBar`'s constructor (checked 2026-10-10) takes exactly these named parameters, plus the optional `onNextContainer`/`onPreviousContainer`, which the test leaves out. `CaseKind` is declared in `lib/domain/models/route_display.dart` and re-exported by `container_top_bar.dart`, so the test needs no extra import. If the constructor has changed since, use its current names. Do not change the widget to fit the test.

- [ ] **Step 2: Run the tests and see them fail**

Run: `flutter test test/ui/core/glow_test.dart`
Expected: compile failure, `The getter 'glow' isn't defined for the type 'Palette'` and `The method 'glow' isn't defined for the type 'C'`.

- [ ] **Step 3: Add `glow` to `Palette` and `C.glow` to `C`**

In `lib/ui/core/tokens.dart`, add below `import 'dart:ui';`:

```dart
import 'package:flutter/painting.dart' show BoxShadow;
```

In the `Palette` constructor, add after `required this.markers,`:

```dart
    required this.glow,
```

After `final List<Color> markers;`, add:

```dart
  /// Whether the live and opening lights glow (cyberpunk spec §3). Dark only:
  /// on a light page a glow reads as a smudge.
  final bool glow;
```

In `static const dark = Palette(`, after the `markers: <Color>[ ... ],` entry, add:

```dart
    glow: true,
```

In `static const light = Palette(`, after its `markers: <Color>[ ... ],` entry, add:

```dart
    glow: false,
```

In `abstract final class C`, after the `markers` getter, add:

```dart
  /// The glow around a live or opening light (cyberpunk spec §3): one shadow
  /// in [light]'s own colour at 60 %, blur 6. Null when the active palette
  /// does not glow. Only `StatusRail` and the address pill's dot call this;
  /// nothing else casts a shadow but sheets (v2 §4).
  static List<BoxShadow>? glow(Color light) => _active.glow
      ? [BoxShadow(color: light.withValues(alpha: 0.6), blurRadius: 6)]
      : null;
```

- [ ] **Step 4: Use it in `StatusRail`**

In `lib/ui/core/widgets/status_rail.dart`, replace the `decoration:` of the returned `Container` with:

```dart
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: live ? C.jade : (opening ? C.warning : null),
        border: lit ? null : Border.all(color: C.edge, width: 2),
        boxShadow: lit ? C.glow(live ? C.jade : C.warning) : null,
      ),
```

Add one sentence to the class's doc comment, after "...the dashboard's rows say idle by the missing light).":

```dart
/// A lit dot glows in its own colour (`C.glow`); an idle ring never does.
```

- [ ] **Step 5: Use it on the address pill's dot**

In `lib/ui/features/container/views/container_top_bar.dart`, in the `AnimatedContainer` that leads the pill (about line 168), replace its `decoration:` with:

```dart
                      decoration: BoxDecoration(
                        color: live ? C.jade : C.warning,
                        shape: BoxShape.circle,
                        boxShadow: C.glow(live ? C.jade : C.warning),
                      ),
```

- [ ] **Step 6: Run the glow tests and see them pass**

Run: `flutter test test/ui/core/glow_test.dart`
Expected: 7 tests PASS.

If `'no glow under the light palette'` fails on the pill dot because `pumpAndSettle` leaves a lerped empty list, that is what `anyOf(isNull, isEmpty)` allows for. Any other failure is a real bug.

- [ ] **Step 7: Full suite, analyzer and APK**

Run: `flutter analyze`, then `flutter test`, then `flutter build apk --debug`
Expected: `No issues found!`; all tests passing (record N/N for Task 3); the APK builds with zero lines starting `e:`.

`primitives_test.dart`'s `'a live light is jade...'` and `top_bar_v2_test.dart` must pass unchanged. They don't check shadows.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/core/tokens.dart lib/ui/core/widgets/status_rail.dart lib/ui/features/container/views/container_top_bar.dart test/ui/core/glow_test.dart
git commit -m "feat(theme): live and opening lights glow in dark mode

One 60 % shadow, blur 6, in the light's own colour, on StatusRail's lit
dot and the address pill's dot. None in light mode, none on an idle
ring. Spec: 2026-10-10-cyberpunk-palette-design.md §3.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Docs, gates and device check

**Files:**
- Modify: `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` (§2 intro, line ~60; §4 elevation bullet, line ~286)
- Modify: `CLAUDE.md` (plan table, after the Plan 24 row)
- Modify: this plan (append `## Verification`, `## Device checks`, `## Known gaps`, `## Handoff`)

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces: nothing in code.

- [ ] **Step 1: Point restyle v2 at the amendment**

In `docs/superpowers/specs/2026-10-05-restyle-v2-design.md`, insert directly under the `## 2. Colour` heading:

```markdown
> **Amended 2026-10-10:** the dark values in §2.1–§2.4 and §2.6 are
> superseded by `2026-10-10-cyberpunk-palette-design.md` §2 (Plan 25). The
> tables below remain the record of Instrument. Reader (§2.5) and light
> mode (§9) are unchanged.
```

At the end of the `- **Elevation:**` bullet in §4, append:

```markdown
  **Amended 2026-10-10:** the live and opening lights also glow in dark
  mode (`2026-10-10-cyberpunk-palette-design.md` §3).
```

- [ ] **Step 2: Run the gates on a clean tree and record them**

Run: `git status --short` (expect nothing but this task's doc edits), then `flutter analyze`, `flutter test`, `flutter build apk --debug 2>&1 | grep -c "^e:"`.
Expected: clean, N/N passing, `0`. Write the exact numbers into this plan under a new `## Verification` heading, with the date and commit.

- [ ] **Step 3: Device check (emulator, dark mode)**

Set up as `tool/device-check/README.md` and the emulator memory describe (test vault PIN in `emulator-test-setup`). Put the emulator in dark mode (`adb shell cmd uimode night yes`). Take every screenshot with `adb emu screenrecord screenshot <file>.png`, because `FLAG_SECURE` blanks the normal ones. Check and record each of these under `## Device checks`:

1. **`1b` with one live and one opening site:** both lights glow, and the halo is round, not clipped square by the row (Review Focus 5). Do the same in `2c` (the switcher).
2. **`2b`:** the pill dot glows yellow while opening, then neon once live.
3. **`4c` after one wrong PIN:** the error text and the dot rings are pink and readable.
4. **`8c`** (tunnel dropped, as in CLAUDE.md's 2026-10-05 Reconnect check): pink panel, one neon Reconnect.
5. **`2d` and `10b`:** cards, pills and the five markers.
6. **`6b` Reader:** still the warm paper tones.
7. **Light mode** (`adb shell cmd uimode night no`): `1b` and `2b` look exactly as before this plan, with no glow.

Anything that looks wrong is a finding to record and raise with the user, not to fix by changing a value: the values are the spec's.

- [ ] **Step 4: Close out the plan and CLAUDE.md**

Append `## Known gaps`. List: the launcher icon is still Instrument's (`#121110`/`#7FC8A9`) by spec §2.5; `app-design.pdf` and both canvas HTML files still show the old colours, as they did after v2. Add anything the device check found.

Append `## Handoff`: "Later plans read colours only through `C.*`; a new light-like mark that should glow calls `C.glow`, and nothing else may cast a shadow but sheets."

In `CLAUDE.md`'s plan table, add a row after Plan 24:

```markdown
| 25 — Cyberpunk palette | `2026-10-10-cyberpunk-palette.md` | **Done** (<date>, branch `cyberpunk-palette`) | Implements `docs/superpowers/specs/2026-10-10-cyberpunk-palette-design.md` (the user's three rulings of 2026-10-10): `Palette.dark` becomes cool blue-black with a neon live colour `#3DF5D0`, pink danger `#FF7AA6`, neon yellow amber, lavender code and pink/blue/yellow/violet/grey markers; Reader and light mode unchanged. The live and opening lights glow (`C.glow`: 60 %, blur 6) in dark mode only, the one exception to v2 §4's "only sheets cast a shadow". Gates: <analyze>, `flutter test` <N/N>, APK zero `e:`. <Device-checked … / Not verified on a device.> |
```

Fill in the angle-bracketed parts from Steps 2–3. These are not placeholders in this plan: their values only exist once the gates have run.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-10-05-restyle-v2-design.md docs/superpowers/plans/2026-10-10-cyberpunk-palette.md
git commit -m "docs: record the cyberpunk palette (Plan 25)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Do not merge or push. The user decides that (`superpowers:finishing-a-development-branch`).

## Verification

2026-10-10, on a clean tree at `e787dbb` (only Task 3's doc edits uncommitted): `flutter analyze` "No issues found!"; `flutter test` 1181/1181 (baseline 1173 + 7 glow tests + 1 for `8a`); `flutter build apk --debug` succeeding with zero `e:` lines. No Kotlin changed.

**Plan deviation (ruling):** the device check found a third opening light that §3's list missed: the amber dot in `8a`'s address pill (`OpeningBody`, `opening_screen.dart`). It is the same light that `2b`'s pill dot continues once the page is up, but it was flat while `2b`'s glowed amber. It now calls `C.glow(C.warning)`, pinned by `glow_test.dart`'s "8a's opening dot glows amber, like the pill it becomes" (RED→GREEN), and the spec's §3 list names it (`e787dbb`).

## Device checks

2026-10-10, emulator `Pixel_9` (API 36), x64 debug build of `e787dbb` installed with `adb install -r` (vault kept), screenshots from `adb emu screenrecord screenshot`. Not a physical phone. The emulator had no internet, so lights came from local pages (`pages.py`), a host server that never answers (held a site on `8a`), and Webmail timing out to an error page (a live session).

1. **Live lights:** Webmail's dashboard light (on its monogram's corner) and its `2c` light glow neon, round, with no square clipping by the row; `2c`'s background throwaway shows a plain idle ring with no glow. **The dashboard and `2c` never show an amber light:** `session_row.dart` and `switcher_sheet.dart` never pass `opening:`, so "opening" exists only in the pills. Not a regression (Instrument was the same); recorded under Known gaps.
2. **`2b`:** a live throwaway's pill dot glows neon. **`8a`:** the pill dot glows yellow (after the fix above; before it, flat).
3. **`4c`** after one wrong PIN: "Wrong PIN · 4 tries left", the vault mark and the six dot rings in pink `#FF7AA6`, readable on blue-black; keys on the group tone.
4. **`8c` not seen** (needs a proxy route whose tunnel drops; the test vault has none now). Its colours are danger text (seen on `4c`) and danger-wash (seen on `10c`'s Delete).
5. **`2d`:** cool cards and hairlines, the decoy switch on. **`10a`/`10b`:** markers pink, blue, yellow, violet, grey; Save and "+ New workspace" in neon. **`10c`:** Delete on the danger-wash (disabled until the name is typed); cancelled, nothing deleted.
6. **`6b` Reader:** still the warm paper tones; the ☰ sheet behind it is cool.
7. **Light mode** (`cmd uimode night no`): `2b` is Instrument's light palette, its pill dot spruce and flat with no glow. Dark mode restored afterwards.

Another session's reinstall replaced this build mid-check once (14:23); the check was rerun on this build after coordinating.

## Known gaps

- The launcher icon is still Instrument's (`#121110`/`#7FC8A9`), by spec §2.5.
- `app-design.pdf` and both canvas HTML files still show the old colours, as they did after restyle v2.
- No widget anywhere passes `StatusRail(opening: true)`, so the amber rail light (and its glow) is never seen on the dashboard or in `2c`; "opening" shows only in the `2b`/`8a` pills. This is older than this plan.
- `8c` was not seen on a device.

## Handoff

Later plans read colours only through `C.*`; a new light-like mark that should glow calls `C.glow`, and nothing else may cast a shadow but sheets.

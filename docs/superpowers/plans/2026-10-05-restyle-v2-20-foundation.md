# Restyle v2 — Foundation Implementation Plan (Plan 20)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lay the Instrument design system under the whole app: new colour values behind the existing `C.*` names, IBM Plex Sans in place of Figtree, the v2 `T.*` scale, spacing/radius constants, v2 shared widgets (toggle, PIN dots, pill buttons, chips, groups, tabs, step bar, lights), new glyphs and the redrawn vault mark, and the launcher icon. Every screen picks up the new colours and the new `T.*` roles at once; literal `ui(size:)` calls are converted by Plans 21–23.

**Architecture:** `C` stays `abstract final class` with `static const` members (dark only, so const survives and no call site changes for colour). Retired names stay as `@Deprecated` aliases until Plan 23 removes them. `ui()`/`mono()` keep their signatures. New widgets live in `lib/ui/core/widgets/`. Launcher icon is resources under `android/app/src/main/res/mipmap-*` only.

**Tech Stack:** Flutter 3.47.2 / Dart 3, `flutter_test`. No Kotlin, no new dependency.

**Spec:** `docs/superpowers/specs/2026-10-05-restyle-v2-design.md`. §2 (colour), §3 (type), §4 (space), §5 (controls), §6 (icons and mark) are binding for this plan.

## Global Constraints

- **Copy is byte-identical**, including case. No string added, removed or re-cased. No new screen-reader labels except where spec §8 builds one from existing strings (Plan 21).
- **No behaviour change.** Taps, state, navigation and storage are untouched.
- **Dark only.** `android/app/src/main/res/values*/styles.xml`, `lib/data/services/secure_window.dart` and `test/android_theme_test.dart` are not touched.
- **Jade is never a position** (spec §1.2): this plan takes jade off `AppToggle`, `StepProgress`, picker checks and the vault mark.
- **Icons stay `AppIcon`.** `test/no_glyphs_test.dart` passes unchanged. Existing `AppGlyph` names are never renamed or removed (35 test files use `findGlyph`).
- **Never delete or weaken a test.** A test asserting a value this plan changes gets that expectation updated to the spec's new value, and nothing else. A test failing for any other reason is a bug in the change.
- `test/ui/small_screen_layout_test.dart` and `test/ui/responsive_layout_test.dart` keep passing; fix layout, never the guard.
- **No leak count, anywhere.**
- **Gates** at the end of every task: `flutter analyze` clean, `flutter test` all passing (record N/N). At the end of the plan, also `flutter build apk --debug` with zero `e:` lines. Flutter is at `/opt/fl/flutter/bin` in the cloud container; set `PATH=/opt/fl/flutter/bin:$PATH ANDROID_HOME=/opt/android`.
- **One commit per task**, conventional style, ending with the session's attribution lines. Work on branch `restyle-implementation`.

## Review Focus

1. A deprecated alias read anywhere new: new code must use the v2 names (`C.lineSoft`, `C.line`, `C.edge`, `C.code`, `C.dangerSurface`, `C.textFaint`).
2. `text-3` (`C.textFaint`/`C.chevron`) placed on `C.button`/`C.selected` (4.23:1, fails). Use `C.textMuted` there.
3. A `const` widget whose colour now must differ: none should, since every `C` member stays `const`.
4. Bigger shared widgets (48 dp `IconTap`, 52 × 32 toggle, 14 dp dots) overflowing at 320 × 568 — `small_screen_layout_test.dart` catches it.

---

## File map

| File | Change |
|---|---|
| `lib/ui/core/tokens.dart` | v2 values; added `edge`, `focus`, `onJade`, `code`, `lineSoft`, `line`; retired names deprecated aliases; `S` spacing and `R` radii classes. |
| `lib/ui/core/typography.dart` | Plex Sans; v2 `T.*`; new roles `display`, `keypad`, `label`, `address`, `sub`, `value`, `metaValue`, `tab`. |
| `lib/ui/core/theme.dart` | Family, divider/splash from v2 lines. |
| `assets/fonts/` | Add `IBMPlexSans-{Regular,Medium,SemiBold}.ttf`, `OFL-IBMPlex.txt`; remove `Figtree.ttf`. |
| `pubspec.yaml` | `IBMPlexSans` family replaces `Figtree`. |
| `lib/ui/core/icons.dart` | Glyphs `shieldHalf`, `shieldFull`, `sitesFilled`, `todayFilled`, `settingsFilled`, `caseSolid`, `caseBroken`, `caseDouble`; `vault` redrawn as the case mark. |
| `lib/ui/core/widgets/{app_toggle,icon_tap,pill_button,pin_dots,pin_keypad,setting_row,sheet,status_rail,step_progress,monogram,hairline,dashed_box}.dart` | v2 sizes/colours (spec §5). |
| `lib/ui/core/widgets/group.dart` | **Create.** `Group` (spec §4). |
| `lib/ui/core/widgets/choice_chip.dart` | **Create.** `AppChip` — selected = fill + outline + check (spec §5). |
| `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `drawable/ic_launcher_{foreground,background,monochrome}.xml`, `mipmap-*dpi/ic_launcher.png` | Launcher icon (spec §6). |
| `test/ui/core/tokens_v2_test.dart` | **Create.** Pins §2 and the contrast floor. |
| `test/app_theme_test.dart`, `test/ui/core/pin_widgets_test.dart`, and any test asserting a changed value | Expectation → new value only. |

---

### Task 1: Tokens

**Files:** Modify `lib/ui/core/tokens.dart`; create `test/ui/core/tokens_v2_test.dart`; modify `test/app_theme_test.dart` (values only).

- [ ] **Step 1: Write the failing test** `test/ui/core/tokens_v2_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:container/ui/core/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('surfaces are the four v2 tones', () {
    expect(C.bg, const Color(0xFF121110));
    expect(C.surface, const Color(0xFF22201D));
    expect(C.sheet, const Color(0xFF302D29));
    expect(C.button, const Color(0xFF403C37));
    expect(C.selected, const Color(0xFF403C37));
  });

  test('text tones and state colours', () {
    expect(C.textPrimary, const Color(0xFFEDEAE4));
    expect(C.textMuted, const Color(0xFFCBC4B9));
    expect(C.textFaint, const Color(0xFFA8A095));
    expect(C.jade, const Color(0xFF7FC8A9));
    expect(C.danger, const Color(0xFFEE8D79));
    expect(C.warning, const Color(0xFFE0B266));
    expect(C.edge, const Color(0xFF958D82));
    expect(C.code, const Color(0xFFD9CFB8));
  });

  test('every text tone is at least 4.5:1 on every surface it may sit on', () {
    for (final s in [C.bg, C.surface, C.sheet]) {
      for (final t in [C.textPrimary, C.textMuted, C.textFaint, C.jade, C.danger, C.warning]) {
        expect(contrast(t, s), greaterThanOrEqualTo(4.5), reason: '$t on $s');
      }
    }
    for (final t in [C.textPrimary, C.textMuted, C.danger]) {
      expect(contrast(t, C.button), greaterThanOrEqualTo(4.5), reason: '$t on button');
    }
    expect(contrast(C.readerMuted, C.bgReader), greaterThanOrEqualTo(4.5));
  });

  test('every meaningful mark is at least 3:1', () {
    for (final s in [C.bg, C.surface, C.sheet, C.button]) {
      expect(contrast(C.edge, s), greaterThanOrEqualTo(3.0), reason: 'edge on $s');
    }
  });

  test('surfaces step at least 1.15:1', () {
    expect(contrast(C.surface, C.bg), greaterThanOrEqualTo(1.15));
    expect(contrast(C.sheet, C.surface), greaterThanOrEqualTo(1.15));
    expect(contrast(C.button, C.sheet), greaterThanOrEqualTo(1.15));
  });

  test('no workspace marker is jade', () {
    expect(C.markers, isNot(contains(C.jade)));
    expect(C.markers, hasLength(5));
  });
}
```

- [ ] **Step 2: Run it, expect failure**: `flutter test test/ui/core/tokens_v2_test.dart` → fails on `C.bg` and on the missing `C.edge`/`C.code`.

- [ ] **Step 3: Rewrite `lib/ui/core/tokens.dart`** with the values of spec §2.8: kept names take their new values; added `edge`, `focus`, `onJade`, `code`, `lineSoft` (`0x14EDEAE4`), `line` (`0x24EDEAE4`); retired names become `@Deprecated('restyle v2: use C.<new>') static const <name> = <new>;` (`bgPanic`, `bgRecents`, `footer` → `bg`; `raised` → `surface`; `trackOff` → `Color(0x00000000)`; `textDim`, `textDisabled` → `textFaint`; `dangerMuted` → `textMuted`; `dangerPanel` → `dangerSurface`; `jadeCode` → `code`; `line05`–`line08` → `lineSoft`; `line09`–`line16` → `line`). Add:

```dart
/// Spacing scale (spec §4).
abstract final class S {
  static const s1 = 4.0, s2 = 8.0, s3 = 12.0, s4 = 16.0, s5 = 20.0, s6 = 24.0, s7 = 32.0, s8 = 48.0;
}

/// Corner radii (spec §4).
abstract final class R {
  static const badge = 6.0, monogram = 10.0, input = 14.0, group = 18.0, sheet = 28.0, full = 999.0;
}
```

Deprecated aliases produce `deprecated_member_use` infos in analyze. Add to `analysis_options.yaml` under `analyzer: errors:` the line `deprecated_member_use_from_same_package: ignore` **with a comment naming Plan 23 Task 6 as the place it is removed**, so analyze stays clean while the aliases exist.

- [ ] **Step 4: Update `test/app_theme_test.dart` values only**: `0xFF0F1113` → `0xFF121110`; the four named colours: `C.handle` → `0xFF958D82`, `C.pillText` → `0xFFEDEAE4`, `C.dangerPanel` → `0xFF2C201D`, `C.pinError` → `0xFFEE8D79`. Update `test/ui/core/pin_widgets_test.dart:28` `0xFF4A3634` → `0xFFEE8D79`. (The `'Figtree'` assertion moves in Task 2.)

- [ ] **Step 5: Run the whole suite.** `flutter test`. Any other failure that asserts an old colour literal or `C.<name>` equality: update to the new value only if the spec changes it; record each in this plan's Verification. Any other failure is a bug.

- [ ] **Step 6: Gates and commit** — `flutter analyze` (clean), `flutter test` (N/N). `feat(restyle-v2): v2 colour tokens, spacing and radii`.

### Task 2: Plex Sans and the v2 type scale

**Files:** `assets/fonts/*`, `pubspec.yaml`, `lib/ui/core/typography.dart`, `lib/ui/core/theme.dart`, `test/app_theme_test.dart`, create `test/ui/core/typography_v2_test.dart`.

- [ ] **Step 1: Fetch the fonts** (OFL; static TTFs from Google Fonts' CSS API, which serves TTF to a plain `curl`):

```bash
mkdir -p /tmp/plex && cd /tmp/plex
curl -sS "https://fonts.googleapis.com/css2?family=IBM+Plex+Sans:wght@400;500;600" > plex.css
# three src: url(...ttf) lines in weight order 400, 500, 600
grep -o 'https://fonts.gstatic.com[^)]*\.ttf' plex.css | head -3 | nl
```
Download each to `IBMPlexSans-Regular.ttf`, `-Medium.ttf`, `-SemiBold.ttf`; confirm with `python3 -c "from fontTools.ttLib import TTFont; f=TTFont('IBMPlexSans-Medium.ttf'); print(f['name'].getDebugName(4), f['OS/2'].usWeightClass)"` (expect `IBM Plex Sans Medium 500`). If `fontTools` is present, subset to Latin + Latin-Ext: `pyftsubset X.ttf --unicodes="U+0000-024F,U+0300-036F,U+1E00-1EFF,U+2000-206F,U+20A0-20CF,U+2100-214F,U+2190-21FF,U+2212,U+25CF" --layout-features='*' --output-file=out.ttf`. Copy into `assets/fonts/`, delete `assets/fonts/Figtree.ttf`, and add `assets/fonts/OFL-IBMPlex.txt` (the OFL 1.1 text with IBM's copyright line, from the font's `name` table ID 0 and ID 13).

- [ ] **Step 2: `pubspec.yaml`** — replace the `Figtree` family with:

```yaml
    - family: IBMPlexSans
      fonts:
        - asset: assets/fonts/IBMPlexSans-Regular.ttf
        - asset: assets/fonts/IBMPlexSans-Medium.ttf
          weight: 500
        - asset: assets/fonts/IBMPlexSans-SemiBold.ttf
          weight: 600
```

- [ ] **Step 3: Failing test** `test/ui/core/typography_v2_test.dart`: assert `ui(size: 16).fontFamily == 'IBMPlexSans'`; `ui(size: 16, weight: 700).fontWeight == FontWeight.w600`; and the spec §3.2 table for every `T.*` (size, weight, colour, and `height * size` within 0.01 of the line height). Example rows:

```dart
expect(T.body.fontSize, 16); expect(T.body.height! * 16, closeTo(24, 0.01));
expect(T.sectionLabel.fontSize, 13); expect(T.sectionLabel.fontWeight, FontWeight.w600);
expect(T.sectionLabel.color, C.textMuted); expect(T.sectionLabel.letterSpacing, 0.52);
expect(T.address.fontFamily, 'IBMPlexSans'); expect(T.address.fontSize, 16);
expect(T.value.fontFamily, 'IBMPlexMono'); expect(T.display.fontSize, 40);
```

- [ ] **Step 4: Rewrite `typography.dart`**: `_sans = 'IBMPlexSans'`; `ui()` drops `fontVariations` and maps weight to `w400`/`w500`/`w600` (≥ 600 → `w600`, ≤ 400 → `w400`); `T.*` per spec §3.2, each with `height: line / size`. New roles `display`, `keypad`, `label`, `address`, `sub`, `value`, `metaValue`, `tab`. `theme.dart`: `fontFamily: 'IBMPlexSans'`, `dividerColor: C.lineSoft`, `splashColor`/`highlightColor: C.lineSoft`. `test/app_theme_test.dart`: `'Figtree'` → `'IBMPlexSans'` (value only).

- [ ] **Step 5: Run the suite.** The larger `T.*` sizes can overflow a screen under test. For each failure: if it is an overflow, fix the layout (let the row grow, wrap, or scroll — the screens already use `CenteredScroll`/scrolling sheets); never shrink the test or the spec size. Record each fix.

- [ ] **Step 6: Gates and commit** — `feat(restyle-v2): IBM Plex Sans and the v2 type scale`.

### Task 3: Glyphs and the case mark

**Files:** `lib/ui/core/icons.dart`, `test/ui/core/icons_test.dart`.

- [ ] **Step 1: Failing test**: each new glyph (`shieldHalf`, `shieldFull`, `sitesFilled`, `todayFilled`, `settingsFilled`, `caseSolid`, `caseBroken`, `caseDouble`) paints without throwing at 24 and 48 and produces a different picture from `shield`/`sites`/… (compare `PictureRecorder` output bytes via `toImage` + `toByteData`, as `icons_test.dart` already does for existing glyphs if it does; otherwise assert paint does not throw and `AppGlyph.values` contains them).
- [ ] **Step 2: Implement** on the 24-unit grid:
  - `shieldHalf`: `shield` outline + the left half filled (path from (12,3) down the centre to (12,21) and round the left edge, `PaintingStyle.fill`).
  - `shieldFull`: `shield` path filled.
  - `caseSolid`: `RRect` (4,4)-(20,20) radius 5, stroke 2; lid seam line (4,9.5)-(20,9.5).
  - `caseBroken`: same geometry drawn as dashes (3 on, 2 off along the rect; the seam solid).
  - `caseDouble`: `caseSolid` plus an outer `RRect` (2,2)-(22,22) radius 6.5, stroke 1.
  - `sitesFilled`/`todayFilled`/`settingsFilled`: the outline glyph with its main shape filled.
  - `vault` redrawn as the mark: `RRect` (3,3)-(21,21) radius 6, stroke 2; seam (3,9)-(21,9); jewel `drawCircle((12,15), 3)` filled in the icon colour.
- [ ] **Step 3: Gates and commit** — `feat(restyle-v2): case mark, shield levels, filled tab glyphs`.

### Task 4: Shared widgets

**Files:** `lib/ui/core/widgets/*` per the file map; create `group.dart`, `choice_chip.dart`; tests beside the existing widget tests (`test/ui/core/`).

- [ ] **Step 1: Failing tests** (one file `test/ui/core/widgets_v2_test.dart`):
  - `AppToggle(value: true)` paints no `C.jade` anywhere (walk `tester.widgetList<DecoratedBox>`/`Container` decorations), its size is 52 × 32, and an `AppIcon` of `AppGlyph.check` is present; `value: false` has a `C.edge` border and no fill.
  - `IconTap` default size 48.
  - `PinDots` dot size 14; error border `C.danger`.
  - `AppChip(selected: true)` shows `AppGlyph.check` and a `C.textPrimary` border; `selected: false` shows no check and a `C.line` border; its tap target is ≥ 48 tall.
  - `Group` draws `C.surface`, a 1 px `C.line` border, radius 18, and separates children with `C.lineSoft` hairlines.
  - `PillButton` primary min height 52; new `PillTone.dangerText` has no fill or border, label `C.danger`.
  - `StepProgress` uses no `C.jade`.
- [ ] **Step 2: Implement** per spec §5 table. `StatusRail` keeps its API; live `C.jade`, opening `C.warning`, idle a 2 px `C.edge` ring (a caller that must show nothing for idle passes a new `showIdle: false`, default `true`). `SettingRow`: min height 56, title `T.rowTitle`, subtitle `T.sub`, value `T.value`/`T.sub`, chevron `C.chevron`, rule `C.lineSoft`. `sheet.dart`: `C.sheet`, top radius 28, 1 px `C.line` top edge, shadow `BoxShadow(offset: Offset(0,-12), blurRadius: 40, color: Color(0x8C000000))`, handle `C.handle`, title `T.sheetTitle`; `SheetRow` min 56 with `T.rowTitle`. `PinKeypad`: digits `T.keypad`, keys on `C.surface` circles, heights as spec §5. `Monogram`: open `C.button`/idle `C.surface`, radius 10, text text-1/text-2. `Hairline` default `C.lineSoft`. `DashedBox` default `C.edge`.
- [ ] **Step 3: Run the suite**; fix overflows by layout (record each). Tests that assert old widget sizes or jade on toggles/steps/dots get their expectation updated to the spec value (record each by file:line).
- [ ] **Step 4: Gates and commit** — `feat(restyle-v2): v2 shared widgets`.

### Task 5: Launcher icon

**Files:** `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (create), `drawable/ic_launcher_foreground.xml`, `drawable/ic_launcher_background.xml`, `drawable/ic_launcher_monochrome.xml` (create), `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` (replace).

- [ ] **Step 1:** Vector drawables on a 108 × 108 viewport from `docs/design-exploration/direction-b-instrument/app-icon.svg`: background a solid `#121110` rect; foreground the case (`M44,29h20a15,15 0,0 1,15,15v20a15,15 0,0 1,-15,15h-20a15,15 0,0 1,-15,-15v-20a15,15 0,0 1,15,-15z` stroked `#EDEAE4` width 6, seam `M29,45.7H79` stroked width 6) and the jewel circle at (54,62.3) r 8.3 `#7FC8A9`; monochrome the same in `#000000`. `ic_launcher.xml`: `<adaptive-icon>` with `background`, `foreground`, `monochrome`.
- [ ] **Step 2:** Legacy PNGs: render `app-icon.svg` with `docs/design-exploration/tools/shot.mjs`-style Playwright at 48/72/96/144/192 px (mdpi…xxxhdpi), circle-masked like the existing ones; overwrite.
- [ ] **Step 3: Verify**: `git diff --stat android/` lists only `res/mipmap-*` and `res/drawable/ic_launcher_*`; `flutter test test/android_theme_test.dart` passes; `flutter build apk --debug` succeeds with zero `e:` lines; `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep ic_launcher` lists the new resources.
- [ ] **Step 4: Commit** — `feat(restyle-v2): Instrument launcher icon`.

### Task 6: Verification and records

- [ ] `flutter analyze` (clean), `flutter test` (N/N), `flutter build apk --debug` (zero `e:` lines; count with `grep -c '^e:'`). Write the numbers into this plan's Verification section, and add a Plan 20 row to `CLAUDE.md`'s plan table (append only), saying **Not verified on a device**.
- [ ] Commit — `docs(restyle-v2): Plan 20 verification`.

## Verification

Executed 2026-10-06 on branch `restyle-implementation` by the overnight run
(fire cd6e6b), commits `82874b2` (Task 1), `74f4096` (Task 2), `932e27e`
(Task 3), `f8d3392` (Task 4), `33e38ea` (Task 5) and this one.
Baseline at `main` `d0edb1c`: analyze clean, `flutter test` 1057/1057.

- `flutter analyze`: **No issues found.**
- `flutter test`: **1075/1075** (18 new: `tokens_v2_test` 6, `typography_v2_test` 3,
  `icons_test` +1, `widgets_v2_test` 8).
- `flutter build apk --debug`: **built, zero `e:` lines** (Gradle 156 s); the
  APK carries `res/mipmap-anydpi-v26/ic_launcher.xml` and the three
  `res/drawable/ic_launcher_*.xml`.
- `test/android_theme_test.dart`, `test/no_glyphs_test.dart`,
  `test/ui/small_screen_layout_test.dart`, `test/ui/responsive_layout_test.dart`
  pass unchanged.

**Expectations updated to the spec's new values (and nothing else):**
`test/app_theme_test.dart` (ink `0xFF121110`; family `IBMPlexSans`;
`C.handle` `0xFF958D82`, `C.pillText` `0xFFEDEAE4`, `C.dangerPanel`
`0xFF2C201D`, `C.pinError` `0xFFEE8D79`); `test/ui/core/pin_widgets_test.dart:28`
(error ring `0xFFEE8D79`); `test/ui/core/icons_test.dart` (the glyph list gains
restyle v2's eight; `IconTap` default 48); `test/ui/core/primitives_test.dart`
(the light is a 10 dp dot, idle an edge ring); `test/ui/core/sheet_test.dart`
(sheet radius 28); `test/ui/features/settings_test.dart:293` (row chevron 18);
`test/ui/features/container/chrome_bars_test.dart:95` (`IconTap` 48).

**Deviations from the plan text:**
- Fonts ship **unsubset** (DECISIONS D8: OFL Reserved Font Name "Plex").
  +553 KB.
- `T.tabSelected` added beside `T.tab` (the selected tab's 600 weight and
  text-1), instead of a `weight` argument at the call site.
- `IconTap` does **not** force a 48 dp minimum: the call sites that pass 28
  sit in fixed-height bars that Plans 21–23 rebuild; forcing it here would
  overflow them mid-plan. The default is 48, and each wave raises its sites.
- `PillButton` enforces a 48 dp minimum height whatever is passed; its default
  is 52.
- `StatusRail` gains `opening` as well as `showIdle`.
- An idle `Monogram` gets a 1 px `C.line` outline: it sits on a group of its
  own tone.

**Not verified on a device.**

## Device checks

On an emulator or phone: the launcher icon (adaptive, and themed with Android 13+ themed icons on); the lock screen's case mark; switches on `2d` read on/off without colour; the dashboard at 320 × 568 and font scale 2.0.

### Done (2026-10-08, emulator)

Pixel_9 (API 36, WebView 154; **not a physical phone**), the branch's own
x64-only debug build installed over the existing vault. The emulator's system
theme was **light**, so everything below was seen in the light variant
(Plan 24) unless it says otherwise.

- **Launcher icon**: the new adaptive icon on the home screen — jade ring,
  dark body, cream case mark with a jade dot. **Not checked: the Android 13+
  themed-icon variant** (themed icons were never turned on).
- **The lock screen's case mark**: drawn above `Enter your PIN`; after a wrong
  PIN it, the headline and the six dots are all danger (see Plan 22).
- **Switches read on/off without colour**: on `6c` and on `2d`, on is knob
  right + a check on the knob, off is knob left and no check, in both themes.
- **320 × 568 dp** (`wm size 640x1136`, `wm density 320`) at font scale **1.0
  and 1.3**: no overflow; the list scrolls, the search field and tab bar fit.
- **Font scale 2.0** on the dashboard and the ☰ menu: no overflow; hosts wrap,
  rows grow, `Copy link` wraps inside its tile. The workspace chips scroll
  sideways, as they are meant to.

### Done (2026-10-09, emulator)

Pixel_9 (API 36, WebView 154; **not a physical phone**), the branch's x64-only
debug build at `1a61dcf` installed over the vault.

- **The themed-icon variant**, the one gap above: with Wallpaper & style ›
  Home screen › Themed icons on, the home screen drew the monochrome layer as
  a light case mark with its dot on the launcher's tinted disc, like the
  other themed apps. Its glyph sits larger in the disc than theirs do
  (the case spans 56 of the 108 dp canvas, inside the 66 dp safe circle).
  The coloured ring around it in the bottom row is the Pixel Launcher's
  predicted-app outline, not the icon: it stays, recoloured, with themed
  icons off. Pixel Launcher shows themed icons on the home screen only; the
  app drawer keeps the full-colour icon.

## Known gaps

- Literal `ui(size:)` calls (175) still carry canvas sizes until Plans 21–23; screens look mixed between plans.
- Deprecated aliases stay until Plan 23 Task 6.

## Handoff

Plans 21–23 consume: `T.address`, `T.sub`, `T.value`, `T.metaValue`, `T.tab`, `T.label`, `T.display`, `T.keypad`; `Group`, `AppChip`, `PillTone.dangerText`, `StatusRail(showIdle:)`; glyphs `case*`, `shieldHalf/Full`, `*Filled`; `S`, `R`.

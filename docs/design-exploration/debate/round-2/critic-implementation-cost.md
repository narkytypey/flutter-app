# Round 2 — Implementation-cost critic

Lens unchanged: what each direction costs to build in this tree, in
agent-days of plan execution with tests green at each step. Every number
below was re-measured on this branch's `lib/` (last code commit `4d7ee57`).

## Re-measured: what held and what moved

**The compile experiment reproduces exactly.** I copied `lib/`, `test/`,
`pubspec.*`, `analysis_options.yaml` and `.dart_tool/` to the scratchpad,
turned `C`'s 52 `static const` (`lib/ui/core/tokens.dart:8`) into
`static final`, and ran `/opt/fl/flutter/bin/dart analyze`. The result is
**84 errors in 45 files (43 in `lib/`, 2 in `test/`)**: 73
`invalid_constant`, 6 `non_constant_default_value`, 4
`const_with_non_constant_argument` and 1 `const_initialized_with_non_constant_value`.
The six defaults are the ones I named in round 1: `icons.dart:44`,
`typography.dart:14` and `:32` (`Color color = C.textPrimary` /
`C.textSecondary`), `dashed_box.dart:12`, `hairline.dart:8` and
`icon_tap.dart:18`.

**Counts, corrected.** `C.` is referenced 467 times outside comments in 71
files (round 1 said 430). There are 90 references in 24 test files.
`C.jade` appears 42 times in 30 files. There are 66 `ui(size:` calls at
12.x or below, and 46 `lib/ui` files draw `Hairline`/`C.line*`. `SystemUiOverlayStyle` has 0
references in `lib/`.

**Sentence case: sharpened.** In 24 test files, 113 `find.text('…')`
finders match all-caps strings. Remove the values that stay upper case
(`SOCKS5`, `HTTP`, `CSS`, `THROWAWAY · SOCKS5`…) and **about 99 move**. The
most frequent are `'1 OPEN'` ×7, `'2 OPEN'` ×5, `'SAVED SITES'` ×5,
`'ITS OWN CONTAINER'` ×5, `'HOST'` ×5 and `'WIPES ON EXIT'` ×4. The cost is
the same in all three directions, and it still needs a copy ruling, since
CLAUDE.md says to "never re-capitalise".

## Withdrawn or reduced

**The light-theme refactor is smaller than the 3–4 days I gave it.** In round
1 I offered two paths: a context palette (all 467 references become
`context` reads) or a global palette with a re-keyed root. The second I
correctly ruled out, because `AppGate` keys `_OpenVault` by
`ObjectKey(database)` (`app_gate.dart:29`) and its `Navigator`
(`:74`) would be remounted, popping every container. I missed a third
path. Keep `C` as a global whose getters read the current brightness. On
`didChangePlatformBrightness`, walk the element tree and `markNeedsBuild`
every element. That preserves all `State`, so no navigator is remounted.
Its compile cost is exactly the 84 errors above, which are mechanical
(drop `const`, and turn the six defaults into `Color? color` /
`color ?? C.textPrimary`). Its risk is anything that caches a colour
outside `build`. A grep for `static final/const … = C.` finds none. I now
estimate **1.5–2 agent-days** for the palette mechanism in A or C, down
from 3–4. Everything else on the light-theme bill stands: a light
`ThemeData` in `theme.dart`, `themeMode: system` in `lib/app.dart` (today
only `theme: containerTheme()`), `SystemUiOverlayStyle` on every top-level
surface, `user_script.dart:13–14`'s two hard-coded badge colours moving out
of `domain/`, and nine white-alpha `C.line*` plus six `Colors.white/black`
sites that invert. The **second token table and its contrast pass** also
stand, and the B advocate is right about them. C measured 206 pairs, and
every future screen is reviewed twice.

**The A advocate says the splash fix is "a small phase-7 change": agreed,
with a caveat.** `test/android_theme_test.dart:11` forbids `Theme.Light` in
`values/styles.xml`. So the fix is not a light `LaunchTheme`. It is a
`drawable/launch_background.xml` in paper and a `drawable-night/` copy in
ink, both under the existing `Theme.Black` parent. That is about half a day.
It is outside `lib/`, and it does not touch `NormalTheme`, whose
`?android:colorBackground` stays black behind Flutter. So a light-mode
keyboard or resize can still show black at the window edge for a frame.

**Font bytes: withdrawn as a differentiator.** A saves about 140 KB, B adds
246 KB (if subset: B's own `TOKENS.md:197–202`, and subsetting needs a
`pyftsubset` step this repo does not have, about a quarter of a day; the
three static files installed here are 205 KB each, 615 KB unsubset). C adds
0. The debug APK is 244.5 MB, dominated by `libtor.so` (CLAUDE.md, Plan 19).
±250 KB is 0.1 %. Font choice costs roughly the same everywhere: TTFs,
`pubspec.yaml`, `typography.dart`, and `test/app_theme_test.dart`'s family
assert.

## Direction-specific, sharpened

**B — Instrument.** It needs a value swap in `tokens.dart` (dark only, so
`const` survives and the 84-error refactor is never paid), Plex Sans (which
also lets `typography.dart:7–9`'s `wght`-variation workaround go), and jade
removed from switches, checks and tabs. That last item touches some of the
42 `C.jade` sites. Two tests are meant to flip: `chrome_bars_test.dart:117`
(`expect(_glyph(tester, AppGlyph.chevronUp).color, C.jade)`) and
`lock_body_test.dart:152`. The case shape in the pill is a view parameter,
because `ContainerRoute` already holds `viewed.site` and
`viewed.throwaway`. The overflow risk is guarded by
`small_screen_layout_test.dart`, and the mockup shows the risk is
manageable. With real fonts B has **no overflow at any of six sizes**,
including 320 × 2.0, and no host is ellipsized (accessibility round 2).
**Estimate unchanged: 7–9 agent-days.**

**A — Daylight.** The floor, plus the palette mechanism (1.5–2), the light
bill and a second table (about 2), fonts, and the box mark. One new cost
comes from this round's render. A's `2b` host is ellipsized at 390 × 1.0
("forum.exampl…", 114 of 145 px), and `8a` overflows by 22 px at 320 × 2.0.
Fixing the pill layout so the host is never cut, and so the pill can grow,
is real layout work on `ContainerTopBar`. It is guarded by
`responsive_layout_test.dart` and costs about half a day. **Estimate: 10–12
agent-days** (down from 12–15).

**C — Rooms.** The same palette and light bill as A, plus three costs that
I have now checked:

1. **The walled page clips a platform view.** `.walled { margin: 0 8px;
   border: var(--wall-w) solid var(--wall); border-radius: 18px; overflow:
   hidden }` (`direction-c-rooms/screens.html:154`). The page is
   `PlatformViewLink` → `AndroidViewSurface` →
   `PlatformViewsService.initSurfaceAndroidView`
   (`container_web_view.dart:32–42`). Rounded clipping of that surface is a
   compositing change that `flutter test` cannot see, and it can only be
   proven on a device. It also takes 22 dp (8 + 3 per side) from every
   page's width, so `width=device-width` becomes 368 on a 390 phone and 298
   on a 320 one. That interacts with Plan 15's `initialScaleFor` fix, which
   was itself only found on the emulator. Allow at least 1 day with a
   device run.
2. **Domain change for `2c`.** `SwitcherEntry` has no workspace or marker
   field today (`lib/domain/models/switcher_entry.dart`, `lib/domain/tabs.dart`
   show no `markerIndex`), and `C.markers` is read only by
   `workspaces_screen.dart:138` and `workspace_form_screen.dart:162–171`.
   Rooms need it in about 10 views plus the domain builder.
3. **Retiring jade and amber as meanings.** That means 42 `C.jade` and 4
   `C.warning` references reassigned, `status_rail.dart` (used by
   `session_row.dart` and `switcher_sheet.dart`) replaced by an animated
   door painter, and about 10 tests that encode the jade rule rewritten.

The second axis is **colour-only workspace identity**. The accessibility
and threat-model critics both call it blocking, so C's real bill includes
whatever fixes it: workspace-name text in `2b`/`2c`, or neutral chrome while
browsing. Either fix removes most of what C's chrome plumbing pays for.
**Estimate: 13–16 agent-days** (down from 15–19, by the same palette
correction), before those fixes.

## Bottom line (implementation-cost lens)

Ratio about **B 1 : A 1.35 : C 1.8** (it was 1 : 1.7 : 2.1). The gap
narrowed because the light-theme mechanism is cheaper than I said, but the
order holds.

1. **B — Instrument. Cheapest.** Blocking issue: **none.** Its riskiest step
   is the type floor at 320 × 568, which is already test-guarded.
2. **A — Daylight.** Blocking issue: **none on cost alone.** The largest
   single item is the light/dark palette (84 compile errors in 45 files,
   plus a second token table and status-bar styling on every surface).
3. **C — Rooms. Most expensive.** Blocking issue: **the walled page, a
   rounded clip around the WebView platform view**
   (`container_web_view.dart:42`, `screens.html:154`). It is the only change
   in any direction that `flutter test` cannot verify, and it narrows every
   page's viewport by 22 dp.

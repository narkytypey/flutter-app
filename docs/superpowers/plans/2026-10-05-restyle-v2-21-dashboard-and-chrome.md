# Restyle v2 — Dashboard and Container Chrome Implementation Plan (Plan 21)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle `1b`/`3b`/`5b` (dashboard shell, chips, rows, search, tabs) and `2b`/`2c`/`8a` plus the container's sheets reached from the chrome (☰, find bar, address editing and suggestions, save bar, New identity) to spec v2 — including the two structural visual changes in the address pill: the host is never ellipsized, and the pill shows the container's case and the shield by security level.

**Architecture:** View-layer only. `ContainerTopBar` gains three view parameters (`caseKind`, `securityLevel`, plus a semantics label it builds from existing strings); `ContainerScreen` passes them from what `ContainerRoute` already holds (`viewed.site`, `viewed.throwaway`, the effective security level it already resolves for `6c`). No provider, controller, domain or Kotlin change.

**Tech Stack:** Flutter/Dart 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` §1, §3.3, §5, §8 (`1b`, `2b`, `2c`, `8a`). Depends on Plan 20.

## Global Constraints

As Plan 20 (copy byte-identical including case; no behaviour change; dark only; jade never a position; icons `AppIcon`; never weaken a test; layout guards keep passing; gates every task; one commit per task; branch `restyle-implementation`). In addition:

- **The host is never ellipsized** in the pill, `2c`, `8a` or the suggestions: `maxLines` removed and `softWrap` on, with a `_breakAfterDots(host)` helper that inserts U+200B ZERO WIDTH SPACE after each `.` **for layout only** — the semantics label and any `find.text` stay the plain host. Implement it as `Text.rich` with the plain host as `semanticsLabel`; tests that `find.text(host)` must keep passing (use `findRichText: true` where the finder needs it — a finder change, not a weakening).
- Every literal `ui(size:)`/`mono(size:)` in the files this plan touches becomes a `T.*` role or follows spec §3.3's ladder.
- Every retired `C.*` alias in these files is replaced by its v2 name.

## Review Focus

1. A semantics or `find.text` regression from the host wrapping helper.
2. `1b` rows: idle rows show **no** ring (`StatusRail(showIdle: false)`); `2c` and `5a` keep it.
3. One jade role per screen: `1b` live lights only (no jade chip, tab or chevron); `2b` the pill's light only (`N OPEN` chevron text-1).

---

### Task 1: Dashboard shell, chips, tabs, search (`1b`, `5b`)

**Files:** `lib/ui/features/dashboard/views/{dashboard_tab_bar,dashboard_footer,workspace_chips,empty_workspace,dashboard_screen,…}.dart`; tests under `test/ui/features/dashboard*`.

- [ ] **Step 1: Failing tests**: selected workspace chip shows `findGlyph(AppGlyph.check)`, others do not; no `C.jade` in the tab bar's paint (selected tab uses its `*Filled` glyph); tab labels are 13 sp (`T.tab`); the search field's border is `C.edge`.
- [ ] **Step 2: Implement**: chips via `AppChip`; tabs per spec §5 (filled glyph, outline, `T.tab`); search field 48 dp, `C.surface`, 1.5 dp `C.edge`, hint `T.body` in `C.textFaint`; `empty_workspace.dart` text to `T.bodyMuted`/`T.body`; `+` keeps jade (the one affirmative action on `5b`).
- [ ] **Step 3: Gates and commit** — `feat(restyle-v2): dashboard shell, chips and tabs`.

### Task 2: Site rows (`1b`, `3b`)

**Files:** `dashboard/views/session_row.dart`, the list that hosts it.

- [ ] **Step 1: Failing tests**: an idle row has no `StatusRail` ring painted (find `StatusRail` with `showIdle: false` or none); a row is ≥ 72 dp; name in `T.rowTitle`/`T.rowTitleIdle`; the meta line's host in Plex Mono (`T.metaValue`) and the rest in `T.meta`, with `find.text(meta)` still matching (use `Text.rich` with the full string as plain text).
- [ ] **Step 2: Implement**: rows inside a `Group` (rounded, `C.surface`) per list section, `C.lineSoft` between; padding 16; light at the monogram's corner; age `T.meta`.
- [ ] **Step 3: Gates and commit** — `feat(restyle-v2): dashboard site rows`.

### Task 3: Address pill and top bar (`2b`)

**Files:** `container/views/{container_top_bar,panic_square,container_screen}.dart`, `container_route.dart` (pass-through only), `test/ui/features/container_screen_test.dart`, new `test/ui/features/container/top_bar_v2_test.dart`.

- [ ] **Step 1: Failing tests** (`top_bar_v2_test.dart`):
  - At 320 × 568 and `textScaler: TextScaler.linear(2.0)`, `ContainerTopBar(host: 'forum.example.com', …)` renders every character: the `RenderParagraph` for the host reports `didExceedMaxLines == false` and no `TextOverflow.ellipsis`.
  - `caseKind: CaseKind.keep` draws `AppGlyph.caseSolid`; `wipe`/`throwaway` `caseBroken`; `tor: true` uses `caseDouble`; the case's `Semantics` label is `Keep for this site` / `Wipe on exit` (existing `6c` strings; a throwaway uses `Wipe on exit`).
  - `securityLevel: standard/safer/safest` draws `shield`/`shieldHalf`/`shieldFull`, never in `C.jade`.
  - Shield, reload/stop and panic are each ≥ 48 × 48.
- [ ] **Step 2: Implement** per spec §8 `2b`: bar 64 dp min, pill min 48 radius full `C.surface` with `C.line` border; `[case 20] [host T.address wrapping] [route badge T.barBadge, wraps under the host when narrow — use a `Wrap`] [reload/stop 48] [shield 48]`; the live dot stays (jade live / amber opening) as the pill's only jade; panic 48 dp, 1.5 dp `C.danger` outline. `enum CaseKind { keep, wipe, throwaway }` lives in the view file. `ContainerScreen`/`ContainerRoute` pass `site.cookiePolicy`/`throwaway`/route Tor/effective level — values they already hold (read `container_route.dart` for the effective level `6c` uses; if it is only computed inside the `6c` open, compute it with the same existing function, do not add a provider).
- [ ] **Step 3: Gates and commit** — `feat(restyle-v2): address pill — whole host, case and shield level`.

### Task 4: Bottom bar, find bar, address edit and suggestions, save bar

**Files:** `container/views/{container_bottom_bar,find_bar,address_edit_bar,address_suggestions,throwaway_save_bar}.dart`; `test/ui/features/chrome_bars_test.dart`.

- [ ] **Step 1:** `chrome_bars_test.dart:117` asserts the `N OPEN` chevron is `C.jade`; spec §8 makes it text-1: update that expectation to `C.textPrimary` (value only). Add a test that the bottom bar's icon taps are 48 dp.
- [ ] **Step 2: Implement**: bottom bar 56 dp `C.bg` with a `C.line` top rule; `N OPEN` `T.tab` 600 text-1; find bar and edit bar fields per spec §4 inputs; suggestions rows `T.rowTitle` + host `T.metaValue` (wrapping); save bar `T.body` + jade `Save` pill.
- [ ] **Step 3: Gates and commit** — `feat(restyle-v2): container bars and address editing`.

### Task 5: `2c` tabs sheet, ☰ menu, New identity, `8a`

**Files:** `container/views/{switcher_sheet,browser_menu_sheet,new_identity_sheet,opening_screen}.dart`.

- [ ] **Step 1: Failing tests**: in `2c`, the vertical gap between "Close all and wipe" and the panic tile is ≥ 24; the header count uses the same `TextStyle` as the bottom bar's `N OPEN`; at 320 × 568 / 2.0 `8a`'s "Connecting through …" line does not overflow.
- [ ] **Step 2: Implement**: sheets per Plan 20's `sheet.dart`; `2c` rows `T.rowTitle` + host `T.metaValue` wrapping, viewed jade light, background `C.edge` ring; ☰ rows `SheetRow`; `8a` steps text-1 current / text-3 pending, no jade line, route line wraps.
- [ ] **Step 3: Gates and commit** — `feat(restyle-v2): tabs sheet, menu, opening`.

### Task 6: Verification and records

- [ ] `flutter analyze`, `flutter test` (N/N), `flutter build apk --debug` (zero `e:`). Record in this plan; append a Plan 21 row to `CLAUDE.md` (**Not verified on a device**). Commit `docs(restyle-v2): Plan 21 verification`.

## Verification

(Filled in by the executing session.)

## Device checks

`2b` on a long host at font scale 2.0 (whole host, pill grows); a wipe-on-exit site, a throwaway and a Tor site show their case; the shield changes with `6c`'s level; `1b` idle rows show no ring.

## Known gaps

- A visible word for the case (spec §12 Q4) is not drawn.

## Handoff

Plans 22–23 reuse the wrapping-host helper (`breakAfterDots` in `lib/ui/core/host_text.dart`, created in Task 3) for `8b`/`8c`/`6c`/`7c`.

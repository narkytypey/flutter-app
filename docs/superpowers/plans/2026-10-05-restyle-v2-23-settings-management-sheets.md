# Restyle v2 — Settings, Management, Sheets and Failure States Implementation Plan (Plan 23)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Restyle every remaining screen to spec v2 — `2d` and its pickers and Default route, `2a` (add/edit site and its tabs), `10a`–`10e`, `5c` Today, the in-page sheets and screens (`6a`, `6b`, `6c`, `7b`, `7c`, `8b`, `8c`) — then remove the retired `C.*` aliases so the token layer is exactly the spec's.

**Architecture:** View-layer only, plus one domain-model tidy: `lib/domain/models/user_script.dart` stops holding colours (spec §2.8 note); the view chooses `C.code`/`C.warning` by script kind.

**Tech Stack:** Flutter/Dart 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` §2.8, §5, §8. Depends on Plan 20 (and Plan 21's `host_text.dart`).

## Global Constraints

As Plan 20. In addition:
- `6a`: jade moves to "Keep blocked" (spec §8, §12 Q6) — colour only; the buttons' words, order and handlers are unchanged, and a test pins that both still do what they did.
- `8b`: "Open without the tunnel" becomes `PillTone.dangerText` 24 dp below the others; it appears exactly when it does today (`canOpenWithoutTunnel`).
- `2d`: same widgets in both vaults; VAULT shows only when `decoyEnabledProvider` says so, as built.

## Review Focus

1. Any test asserting `6a`'s "Allow once" is jade: update to the spec (`Keep blocked` jade), value only.
2. Removing aliases (Task 6): a missed reference is a compile error, caught by analyze.

---

### Task 1: Settings (`2d`, pickers, Default route)

**Files:** `settings/views/*` except `decoy_resync_pin_screen.dart` (Plan 22).
- [x] Failing tests: sections render inside `Group`s; picker checks `C.textPrimary`; no `C.jade` in `2d` paint; at 320 × 568 / 2.0 no overflow (existing guard).
- [x] Implement; convert literals; gates; commit `feat(restyle-v2): settings`.

### Task 2: Add/edit site (`2a`) and route fields

**Files:** `add_site/views/*`, `settings/views/default_route_screen.dart` (shares `RouteFields`).
- [x] Failing tests: tab segments selected by a `C.textPrimary` outline + check, no jade underline; workspace chips `AppChip`; code in `C.code`; `Save` the one jade.
- [x] Implement; gates; commit `feat(restyle-v2): add and edit site`.

### Task 3: Workspaces and scripts (`10a`–`10e`)

**Files:** `workspaces/views/*`, `scripts/views/*`, `lib/domain/models/user_script.dart` (+ its test, value only).
- [x] Failing tests: markers are the v2 five; `10c` delete on `C.dangerSurface` with `C.danger` label; `10d` badge colours chosen in the view; `10e` code `C.code`.
- [x] Implement; gates; commit `feat(restyle-v2): workspaces and scripts`.

### Task 4: Today (`5c`) and reader (`6b`)

**Files:** `report/views/today_screen.dart`, `in_page/views/reader_screen.dart`, `test/ui/features/in_page/reader_screen_test.dart` (sizes as built; family/colour values only).
- [x] Failing tests: total in `T.display`; bars not jade; reader host `C.readerMuted` ≥ 4.5:1.
- [x] Implement; gates; commit `feat(restyle-v2): today and reader`.

### Task 5: In-page sheets and failure states (`6a`, `6c`, `7b`, `7c`, `8b`, `8c`, wipe sheet, row menu)

**Files:** `in_page/views/{permission_request_sheet,site_sheet,held_download_sheet,proxy_unreachable_screen,tunnel_dropped_screen}.dart`, `dashboard/views/{site_row_menu,wipe_site_sheet}.dart`.
- [x] Failing tests: `6a` "Keep blocked" is the jade `PillTone.primary`, "Allow once" neutral, both still call their existing callbacks; `6c` switches are v2 `AppToggle`s and `Edit` is the only jade; `8b` "Open without the tunnel" is `PillTone.dangerText`, ≥ 24 dp below "Change proxy settings", present for SOCKS5 and Tor-clearnet, absent for Tor-onion and direct (existing logic); hosts wrap (Plan 21 helper).
- [x] Implement; gates; commit `feat(restyle-v2): sheets and failure states`.

### Task 6: Remove the retired aliases

- [x] `grep -rn "C\.\(bgPanic\|bgRecents\|footer\|raised\|trackOff\|textDim\|textDisabled\|dangerMuted\|dangerPanel\|jadeCode\|line0[5-9]\|line1[0-6]\)\b" lib test` → replace each with its v2 name (spec §2.8). Delete the aliases from `tokens.dart` and the `deprecated_member_use_from_same_package` line from `analysis_options.yaml`. `test/app_theme_test.dart`'s `C.dangerPanel` assertion becomes `C.dangerSurface` with the same new value (a rename forced by the spec's retirement, not a weakening).
- [x] Gates; commit `refactor(restyle-v2): remove retired colour names`.

### Task 7 (optional): The two motion moments

- [ ] Unlock: the vault mark's seam lifts 2 dp and fades, 320 ms `Curves.easeOutCubic`, inside the lock body's transition; protective change: the pill's case cross-fades solid ↔ broken over 320 ms on reopen-in-place. Both 100 ms cross-fades under `MediaQuery.disableAnimations`. Widget tests pump the durations. Skip if it needs any controller change.

### Task 8: Verification and records

- [x] Three gates; record; append a Plan 23 row to `CLAUDE.md` (**Not verified on a device**); commit `docs(restyle-v2): Plan 23 verification`.

## Verification

Executed 2026-10-06 on `restyle-implementation`, from `4a8051d` (Plans
20–22 merged, 1104/1104). Tasks 1, 2 and 4 ran in the main tree, Tasks 3 and 5
in a worktree merged at `72a9018`. Commits: `4a068ec` (Task 1), `25731a4`
(Task 2), `47a10db` (Task 3), `65ef60a` (Task 4), `83eb940` (Task 5), `a34c7ad`
(Task 6) and this one. A rate limit stopped the first two agents part-way; their
work was resumed from the tree, not redone.

- `flutter analyze`: **No issues found.**
- `flutter test`: **1142/1142** (baseline 1104; 38 more, of which
  `settings_v2_test` 5, `add_site_v2_test` 9, `management_restyle_v2_test` 5,
  `today_v2_test` 5, `reader_screen_test` +3, `sheets_restyle_v2_test` 9). Each task's gates were run after it.
- `flutter build apk --debug`: **built, zero `e:` lines** (on `a34c7ad`).
- `test/no_glyphs_test.dart`, `test/ui/small_screen_layout_test.dart`,
  `test/ui/responsive_layout_test.dart`, `test/android_theme_test.dart`
  pass unchanged. Nothing under `android/` changed.
- No retired `C.*` name remains in `lib/` or `test/`; the
  `deprecated_member_use_from_same_package` line is gone.

**Expectations updated to the spec's new values (and nothing else):**
- `test/ui/features/settings_test.dart`: Settings' back glyph `Size(18, 18)` →
  `Size(22, 22)` (48 dp target, 22 dp glyph, spec §5).
- `test/ui/features/add_site_test.dart:51`: `2a`'s Close target `Size(24, 24)`
  → `Size(48, 48)` (spec §5).
- `test/ui/features/dashboard/site_row_menu_test.dart:69`: the wipe row
  `C.textSecondary` → `C.danger` (spec §8: the wipe rows are danger); its name
  now says "Remove site and the wipe row are the rows drawn in danger colour".
- Task 6 renames, same values: `C.textDisabled`/`C.textDim` → `C.textFaint`
  (`chrome_bars_test`, `icons_test`, `script_site_picker_test`,
  `address_and_menu_test`), `C.footer` → `C.bg`, `C.raised` → `C.surface`,
  `C.line16` → `C.line` (`primitives_test`), and `app_theme_test.dart`'s
  `C.dangerPanel` → `C.dangerSurface` (same `0xFF2C201D`).

**What changed, per screen:**
- `2d` and its pickers: sections in `Group`s, picker checks text-1, no jade.
- `2a` (and the Default route screen through `RouteFields`): new
  `FormSegment` (selected = 2 dp text-1 outline + check, no fill, no jade) for
  the four tabs, SOCKS5/HTTP/Tor and the user agents; `FormInput` (surface fill,
  1.5 dp edge border, 2 dp text-1 on focus); workspace chips `AppChip`; every
  switch a v2 `AppToggle` in a ≥ 56 dp `FormToggleRow` (Privacy's and
  Appearance's private jade switches gone); custom CSS/JS `T.code`; page zoom
  text-1 on an edge track; Save the one jade (`T.label`, 48 dp), still dimmed
  while the address is invalid.
- `10a`–`10e`: the v2 markers; `10c` Delete on `C.dangerSurface` with a
  `C.danger` label; `10d`'s badge colours chosen in the view
  (`scriptBadgeColor`: CSS `C.code`, JS `C.warning`) — `UserScript` holds no
  colour; `10e`'s code `C.code` in Plex Mono.
- `5c`: total `T.display`; every bar `C.textMuted` on a surface track (the
  amber "Permission asks" bar is no longer amber, spec §8); counts `T.value`;
  sites one `Group`.
- `6b`: host `C.readerMuted` 14 sp (≥ 4.5:1 on `C.bgReader`); 48 dp header
  targets; body line height 1.7 (spec §3.2).
- `6a`: **"Keep blocked" is the jade primary; both Allow buttons neutral** —
  same words, order and handlers (test-pinned).
- `6c`: v2 switches, Edit the only jade (48 dp), counts in Mono, rows ≥ 56.
- `7b`: the wipe row in `C.danger`; `7c`: the host line wraps, Discard jade.
- `8b`: **"Open without the tunnel" is `PillTone.dangerText`, 24 dp below
  Change proxy settings**, shown exactly when it was (test-pinned present and
  absent); the header's host wraps. `8c`: banner on `C.dangerSurface`,
  Reconnect jade; it shares `8b`'s now-public `TunnelHeader`.
- Task 6: aliases deleted; `C.readerHost` (unused after Task 4, not in the
  spec) deleted too.

**Deviations and judgement calls:**
- `8c`'s "Close and wipe" was a `C.dangerSurface` fill, invisible on the new
  danger-wash banner; it is now neutral (`C.button`, text-1). The spec does
  not name it.
- `2a`'s Network tab rows stay ungrouped as built; only Privacy's hairline
  rows became groups. SOCKS5/HTTP/Tor are segments (§5), not chips.
- Task 3's tests were written after its code (an interrupted agent had left
  the code uncommitted), so they were never seen failing. Two pre-existing
  row-tap tests failed on that code and were fixed in the code
  (`Expanded` → `Flexible`), not in the tests.
- **Task 7 (motion) was not done** (optional).

**Not verified on a device.**

## Device checks

`6a` with "Keep blocked" in jade; `8b` for SOCKS5, Tor-clearnet and Tor-onion; `6c`'s switches; Settings in the decoy (no VAULT section).

## Known gaps

`10a`/`10c` storage sizes are unchanged behaviour (spec §12 note).

## Handoff

After this plan no retired `C.*` name exists; `C`, `T`, `S`, `R` are exactly spec v2.

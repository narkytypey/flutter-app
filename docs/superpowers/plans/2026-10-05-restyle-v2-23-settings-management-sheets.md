# Restyle v2 — Settings, Management, Sheets and Failure States Implementation Plan (Plan 23)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

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
- [ ] Failing tests: sections render inside `Group`s; picker checks `C.textPrimary`; no `C.jade` in `2d` paint; at 320 × 568 / 2.0 no overflow (existing guard).
- [ ] Implement; convert literals; gates; commit `feat(restyle-v2): settings`.

### Task 2: Add/edit site (`2a`) and route fields

**Files:** `add_site/views/*`, `settings/views/default_route_screen.dart` (shares `RouteFields`).
- [ ] Failing tests: tab segments selected by a `C.textPrimary` outline + check, no jade underline; workspace chips `AppChip`; code in `C.code`; `Save` the one jade.
- [ ] Implement; gates; commit `feat(restyle-v2): add and edit site`.

### Task 3: Workspaces and scripts (`10a`–`10e`)

**Files:** `workspaces/views/*`, `scripts/views/*`, `lib/domain/models/user_script.dart` (+ its test, value only).
- [ ] Failing tests: markers are the v2 five; `10c` delete on `C.dangerSurface` with `C.danger` label; `10d` badge colours chosen in the view; `10e` code `C.code`.
- [ ] Implement; gates; commit `feat(restyle-v2): workspaces and scripts`.

### Task 4: Today (`5c`) and reader (`6b`)

**Files:** `report/views/today_screen.dart`, `in_page/views/reader_screen.dart`, `test/ui/features/in_page/reader_screen_test.dart` (sizes as built; family/colour values only).
- [ ] Failing tests: total in `T.display`; bars not jade; reader host `C.readerMuted` ≥ 4.5:1.
- [ ] Implement; gates; commit `feat(restyle-v2): today and reader`.

### Task 5: In-page sheets and failure states (`6a`, `6c`, `7b`, `7c`, `8b`, `8c`, wipe sheet, row menu)

**Files:** `in_page/views/{permission_request_sheet,site_sheet,held_download_sheet,proxy_unreachable_screen,tunnel_dropped_screen}.dart`, `dashboard/views/{site_row_menu,wipe_site_sheet}.dart`.
- [ ] Failing tests: `6a` "Keep blocked" is the jade `PillTone.primary`, "Allow once" neutral, both still call their existing callbacks; `6c` switches are v2 `AppToggle`s and `Edit` is the only jade; `8b` "Open without the tunnel" is `PillTone.dangerText`, ≥ 24 dp below "Change proxy settings", present for SOCKS5 and Tor-clearnet, absent for Tor-onion and direct (existing logic); hosts wrap (Plan 21 helper).
- [ ] Implement; gates; commit `feat(restyle-v2): sheets and failure states`.

### Task 6: Remove the retired aliases

- [ ] `grep -rn "C\.\(bgPanic\|bgRecents\|footer\|raised\|trackOff\|textDim\|textDisabled\|dangerMuted\|dangerPanel\|jadeCode\|line0[5-9]\|line1[0-6]\)\b" lib test` → replace each with its v2 name (spec §2.8). Delete the aliases from `tokens.dart` and the `deprecated_member_use_from_same_package` line from `analysis_options.yaml`. `test/app_theme_test.dart`'s `C.dangerPanel` assertion becomes `C.dangerSurface` with the same new value (a rename forced by the spec's retirement, not a weakening).
- [ ] Gates; commit `refactor(restyle-v2): remove retired colour names`.

### Task 7 (optional): The two motion moments

- [ ] Unlock: the vault mark's seam lifts 2 dp and fades, 320 ms `Curves.easeOutCubic`, inside the lock body's transition; protective change: the pill's case cross-fades solid ↔ broken over 320 ms on reopen-in-place. Both 100 ms cross-fades under `MediaQuery.disableAnimations`. Widget tests pump the durations. Skip if it needs any controller change.

### Task 8: Verification and records

- [ ] Three gates; record; append a Plan 23 row to `CLAUDE.md` (**Not verified on a device**); commit `docs(restyle-v2): Plan 23 verification`.

## Verification

(Filled in by the executing session.)

## Device checks

`6a` with "Keep blocked" in jade; `8b` for SOCKS5, Tor-clearnet and Tor-onion; `6c`'s switches; Settings in the decoy (no VAULT section).

## Known gaps

`10a`/`10c` storage sizes are unchanged behaviour (spec §12 note).

## Handoff

After this plan no retired `C.*` name exists; `C`, `T`, `S`, `R` are exactly spec v2.

# Restyle v2 — Setup, Lock and PIN Implementation Plan (Plan 22)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle `3a`/`4c`/`9b`/`9c` (lock), `3c` (panic done), `4a`/`4b`/`5a` (setup), and the decoy-resync / Change PIN screens to spec v2: the case mark without jade, 14 dp dots, Mono keypad digits, step bar and checks in text-1, 20 dp gutters.

**Architecture:** View-layer only (`lib/ui/features/{lock,panic,setup}/views/*`, `settings/views/decoy_resync_pin_screen.dart`). `PinLayout`'s landscape split is unchanged.

**Tech Stack:** Flutter/Dart 3, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-05-restyle-v2-design.md` §5, §6, §8 (`3a`…`5a`, `3c`). Depends on Plan 20.

## Global Constraints

As Plan 20. In addition: nothing on a lock screen may differ by vault; the unlock motion is not in this plan (Plan 23 Task 7, optional).

## Review Focus

1. `lock_body_test.dart:152` asserts the vault mark is jade; spec §6 makes it text-1. Update that expectation only.
2. `responsive_layout_test.dart`'s landscape PIN layout and `small_screen_layout_test.dart`'s 320 × 568 PIN screens with 14 dp dots and 28 sp digits.

---

### Task 1: Lock body and keypad (`3a`, `4c`, `9b`, `9c`)

**Files:** `lock/views/lock_body.dart` (+ screens using it); tests `test/ui/features/lock*`.
- [x] Failing tests: the mark is `AppGlyph.vault` in `C.textPrimary` (update the jade expectation at `lock_body_test.dart:152` to `C.textPrimary`); error copy is `C.danger`; headline `T.stepTitle`, body `T.bodyMuted`, counts in Mono via `T.value`.
- [x] Implement; convert literals per spec §3.3; gutters 20.
- [x] Gates; commit `feat(restyle-v2): lock screens`.

### Task 2: Setup (`4a`, `4b`, `5a`) and the PIN screens reused by Settings

**Files:** `setup/views/{setup_pin_screen,setup_decoy_screen,setup_defaults_screen}.dart`, `settings/views/decoy_resync_pin_screen.dart`.
- [x] Failing tests: `StepProgress` paints no jade; `5a`'s checks are `C.textPrimary`; the one jade action per screen is `Continue` / `Add your first site` (as built); decoy switch per `AppToggle` v2.
- [x] Implement; convert literals.
- [x] Gates; commit `feat(restyle-v2): setup and PIN screens`.

### Task 3: Panic done (`3c`)

**Files:** `panic/views/panic_screen.dart`.
- [x] Failing test: background `C.bg` (not a different colour); status words `C.textPrimary` (no jade); at 320 × 568 / 2.0 the status words wrap without overflow.
- [x] Implement; gates; commit `feat(restyle-v2): panic done`.

### Task 4: Verification and records

- [x] Three gates; record; append a Plan 22 row to `CLAUDE.md` (**Not verified on a device**); commit `docs(restyle-v2): Plan 22 verification`.

## Verification

Executed 2026-10-06 in a worktree branched from `restyle-implementation` at
`c6b46f6` (Plan 20 done). Commits `4511b1f` (Task 1), `af6c8bf` (Task 2),
`ce93453` (Task 3) and this one. Baseline at `c6b46f6`: analyze clean,
`flutter test` 1075/1075.

- `flutter analyze`: **No issues found.**
- `flutter test`: **1085/1085** (10 new: `lock_body_test` +3, `setup_test`
  +5, `panic_test` +2). Each gate was run after every task.
- `flutter build apk --debug`: **not run here** (no Kotlin or resources
  changed; the orchestrating session builds the merged tree).
- `test/no_glyphs_test.dart`, `test/ui/small_screen_layout_test.dart`,
  `test/ui/responsive_layout_test.dart`, `test/android_theme_test.dart`
  pass unchanged.
- No `ui(size:)`/`mono(size:)` literal, deprecated `C` alias or `IconTap`
  remains in the six files touched.

**Expectations updated to the spec's new values (and nothing else):**
- `test/ui/features/lock_body_test.dart:152`: the vault mark's colour
  `C.jade` → `C.textPrimary` (spec §6); the test's name at `:150` changed
  from "a drawn diamond, jade, and danger" to "a drawn case, text-1, and
  danger" so it no longer states the old value.

**What changed, per screen:**
- `3a`/`4c`/`9b`/`9c` (`lock_body.dart`): gutter 20; the case mark in
  `C.textPrimary` in a `C.line` ring (a 1.5 dp `C.danger` ring and mark after
  a wrong PIN); "Enter your PIN", "Welcome back" and "Wrong PIN · N tries
  left" in `T.stepTitle` (the last in `C.danger`); the sessions line and the
  wrong-tries note in `T.bodyMuted`; the counts (tries left, open sessions,
  seconds) in Plex Mono inside their sentences (`Text.rich`, same plain
  text); `9c`'s note a `C.surface` panel with a `C.line` outline, radius 18,
  text `T.bodyMuted`/`T.sub` text-3; "Use fingerprint" `T.sub` with a 48 dp
  target.
- `4a` (`setup_pin_screen.dart`) and the decoy re-sync / Change PIN screen
  (`decoy_resync_pin_screen.dart`): gutter 20; body `T.bodyMuted`; notices
  and "Wrong PIN" `T.body` in `C.danger`; the re-sync/Change PIN title is
  `T.stepTitle`, centred; `4a`'s Continue min 52, `T.label`, jade only once
  six digits are in (a `C.button` fill with a text-2 label before: text-3
  never on raised).
- `4b` (`setup_decoy_screen.dart`): the two rows are a `Group` (56/72 dp
  minimum, `T.rowTitle`, "Pick after setup" `T.sub`, chevron `C.chevron` 18);
  Continue at the `PillButton` default 52; "Skip for now" a 48 dp target.
- `5a` (`setup_defaults_screen.dart`): the four defaults are a `Group`; checks
  `C.textPrimary` at 20 dp; titles `T.rowTitle`, details `T.sub`.
- `3c` (`panic_screen.dart`): `C.bg`; the status lines a `Group`, labels
  `T.sectionLabel` (text-2), status words `T.sectionLabel` in `C.textPrimary`
  (no jade); title `T.sheetTitle`; body `T.bodyMuted`; a 1.5 dp `C.danger`
  ring round the panic glyph; Unlock at the `PillButton` default 52; gutter 20
  (was 34).

**Deviations and judgement calls:**
- The fingerprint glyph on `9b` stays `C.jade`: when offered, it is that
  screen's one affirmative action (§1.2), and `lock_body_test.dart:162`
  asserts it. Nothing else on any lock mood is jade (new test).
- `9c`'s "Locked after N minutes" line is a domain string
  (`AutoLockPolicy.lockedLine`), so its number is not set in Mono: splitting
  it would need a domain change.
- `3c`'s title is `T.sheetTitle` (20) by the §3.3 ladder (18 → 20); the plan
  names no role for it.
- The mark keeps its 44 dp box and 20 dp glyph (no size in the spec;
  `lock_body_test.dart:153` asserts 20).
- No layout overflow needed fixing.

**Not verified on a device.**

## Device checks

Lock in portrait and landscape at font scale 1.0 and 2.0; a wrong PIN's ring; `3c` after a panic.

## Known gaps

The unlock motion is optional (Plan 23 Task 7).

## Handoff

None beyond Plan 20's.

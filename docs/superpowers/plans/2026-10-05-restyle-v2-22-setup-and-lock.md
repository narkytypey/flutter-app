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
- [ ] Failing tests: the mark is `AppGlyph.vault` in `C.textPrimary` (update the jade expectation at `lock_body_test.dart:152` to `C.textPrimary`); error copy is `C.danger`; headline `T.stepTitle`, body `T.bodyMuted`, counts in Mono via `T.value`.
- [ ] Implement; convert literals per spec §3.3; gutters 20.
- [ ] Gates; commit `feat(restyle-v2): lock screens`.

### Task 2: Setup (`4a`, `4b`, `5a`) and the PIN screens reused by Settings

**Files:** `setup/views/{setup_pin_screen,setup_decoy_screen,setup_defaults_screen}.dart`, `settings/views/decoy_resync_pin_screen.dart`.
- [ ] Failing tests: `StepProgress` paints no jade; `5a`'s checks are `C.textPrimary`; the one jade action per screen is `Continue` / `Add your first site` (as built); decoy switch per `AppToggle` v2.
- [ ] Implement; convert literals.
- [ ] Gates; commit `feat(restyle-v2): setup and PIN screens`.

### Task 3: Panic done (`3c`)

**Files:** `panic/views/panic_screen.dart`.
- [ ] Failing test: background `C.bg` (not a different colour); status words `C.textPrimary` (no jade); at 320 × 568 / 2.0 the status words wrap without overflow.
- [ ] Implement; gates; commit `feat(restyle-v2): panic done`.

### Task 4: Verification and records

- [ ] Three gates; record; append a Plan 22 row to `CLAUDE.md` (**Not verified on a device**); commit `docs(restyle-v2): Plan 22 verification`.

## Verification

(Filled in by the executing session.)

## Device checks

Lock in portrait and landscape at font scale 1.0 and 2.0; a wrong PIN's ring; `3c` after a panic.

## Known gaps

The unlock motion is optional (Plan 23 Task 7).

## Handoff

None beyond Plan 20's.

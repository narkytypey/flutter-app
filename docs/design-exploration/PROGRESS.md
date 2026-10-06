# Restyle v2 — overnight run ledger

Read this first. It is the only thing that carries across a restart.

## Where I got to

Phases 0–2 done. Phase 3 (three directions) building in parallel subagents.

## Heartbeat

2026-10-06T04:06Z · fire-7a41e2

## Branch

design-exploration-restyle

## Next action

Phase 3: check each direction folder's files against the checklist; build whatever is missing (BRIEF, TOKENS, logos, screens blocks in the mandated order).

## Toolchain

Checked 2026-10-05T22:03Z by fire-cd6e6b: `flutter` is not on PATH, no
`ANDROID_HOME`/`ANDROID_SDK_ROOT`, Java present (`/usr/bin/java`).
Installed Flutter 3.47.2 (the version `.github/workflows/dart.yml` pins) from
storage.googleapis.com into `/opt/fl/flutter` (not persistent: a later fire
must re-download it, ~4 min:
`curl -sSfL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz | tar xJ -C /opt/fl`).
Baseline on `main` @ d0edb1c: `flutter analyze` clean, `flutter test` **1057/1057**.
Android SDK installed under `/opt/android` (cmdline-tools from
dl.google.com, then `sdkmanager "platform-tools" "platforms;android-36"
"build-tools;36.0.0"`; Gradle fetched NDK/CMake itself) and
`flutter config --android-sdk /opt/android`. Baseline
`flutter build apk --debug` on `main` @ d0edb1c: **built, zero `e:` lines**
(Gradle 315 s cold). So phase 8 has the **full toolchain**: all three gates run.
A later fire must reinstall all of it (~10 min); set
`PATH=/opt/fl/flutter/bin:$PATH ANDROID_HOME=/opt/android`.

## Directions (one-line theses)

- **A — Daylight** (`direction-a-daylight`): a browser a Chrome user already
  trusts — follows the system light/dark setting, Chrome's grammar and sizes
  (56 dp bar, 40 dp pill, 48 dp targets, 16 sp body), Atkinson Hyperlegible
  Next, grouped rounded surfaces; privacy machinery present but quiet.
- **B — Instrument** (`direction-b-instrument`): keep the dark technical
  self-image and execute it properly — warm near-black, a real IBM Plex Sans /
  Plex Mono hierarchy, every text tone AA, fewer and clearer surfaces, jade
  still the one live colour, 48 dp targets.
- **C — Rooms** (`direction-c-rooms`): make isolation *visible* — every site
  is a coloured room; its colour frames the browser chrome while you are
  inside it, so "which container am I in" is answered at a glance (and a
  throwaway, uncoloured, looks different from a saved site). Warm paper and
  ink, Figtree large and round, tinted cards instead of hairlines. Breaks
  "jade = the one colour" explicitly (argued in DECISIONS D3).

## Checklist

### Phase 0 — Setup
- [x] Create `design-exploration-restyle` from `main`
- [x] Create PROGRESS.md, DECISIONS.md, FINDINGS.md
- [x] Commit and push

### Phase 1 — Research (RESEARCH.md)
- [x] Market share 2026, two or more sources; where the user arrives from
- [x] Majors: Chrome Android, Safari iOS, Samsung Internet, Edge, Firefox, Opera
- [x] Privacy peers: Brave, DuckDuckGo, Tor Browser, Mullvad Browser, Cromite, Vivaldi, Orion
- [x] Craft outliers: Arc/Dia, Zen, Proton, Mullvad VPN, Signal, Tailscale, 1Password, Obsidian
- [x] Human factors: M3 expressive, iOS HIG, WCAG 2.1 AA, font-scale data
- [x] Human factors: intimidating privacy tools, trustworthy security UI, incognito misconceptions
- [x] "What this means for Container": 8–15 falsifiable implications
- [x] RESEARCH.md committed

### Phase 2 — Audit (AUDIT.md)
- [x] Colour token inventory and usage
- [x] Type scale inventory
- [x] Spacing, radii, density, tap targets, icon set
- [x] WCAG contrast of real pairings, AA failures listed
- [x] Strengths vs majors; failures for the bounced user
- [x] Blast radius: files reading C.* / T.*, tests asserting colours/sizes/glyphs
- [x] AUDIT.md committed

### Phase 3 — Three directions
- [x] Theses written into this file
- Direction A
  - [x] BRIEF.md
  - [x] TOKENS.md + tokens.css (contrast measured)
  - [x] logo.svg, logo-wordmark.svg, logo-monochrome.svg, app-icon.svg
  - [x] screens.html: 10 mandatory blocks
  - [x] screens.html: extended blocks
  - [x] Accessibility pass (1.3, 2.0, 320px)
- Direction B
  - [x] BRIEF.md
  - [x] TOKENS.md + tokens.css
  - [x] logos (4)
  - [x] screens.html: 10 mandatory blocks
  - [x] screens.html: extended blocks
  - [x] Accessibility pass
- Direction C
  - [ ] BRIEF.md
  - [ ] TOKENS.md + tokens.css
  - [ ] logos (4)
  - [ ] screens.html: 10 mandatory blocks
  - [ ] screens.html: extended blocks
  - [ ] Accessibility pass

### Phase 4 — Debate
- [ ] Round 1: advocate A, B, C
- [ ] Round 1: critics threat-model, accessibility, implementation-cost, familiarity
- [ ] Round 2: advocate rebuttals A, B, C
- [ ] Round 2: critic replies (4)
- [ ] VERDICT.md

### Phase 5 — Comparison page
- [ ] index.html

### Phase 6 — Spec
- [ ] docs/superpowers/specs/2026-10-05-restyle-v2-design.md
- [ ] Self-review paragraph

### Phase 7 — Plans
- [ ] Read existing plans and Known cross-plan issues
- [ ] Plan 20 — foundation
- [ ] Plan 21+ — screen waves
- [ ] Plans committed

### Phase 8 — Execute (branch restyle-implementation)
- [ ] Toolchain check recorded
- [ ] Cut restyle-implementation
- [ ] Execute plans task by task (tasks listed here once plans exist)
- [ ] CLAUDE.md plan rows

### Phase 9 — If budget remains
- [ ] Finish screen waves
- [ ] All 32 blocks in winner's screens.html
- [ ] Interaction study
- [ ] One-page rationale

## Log

- fire-7a41e2: direction A complete — 30 blocks (+ dark theme), four a11y runs clean (A/A11Y.md).

- fire-7a41e2: direction B complete — 30 blocks, four a11y runs clean (B/A11Y.md).

- 2026-10-06T04:05Z fire-7a41e2: started. Heartbeat was 6 h stale (fire-cd6e6b's parallel direction agents stopped after logos at 22:23Z; no fire between). Taking over: screens for A/B/C next. Mirror branch is now this harness's `second/gracious-cannon-vgx0f2`.

- 22:14Z fire-cd6e6b: phases 1–2 committed; three direction agents launched in parallel (A daylight, B instrument, C rooms) per DIRECTION-BRIEF.md.

- 2026-10-05T22:05Z fire-cd6e6b: started, first fire (no exploration branch on origin).

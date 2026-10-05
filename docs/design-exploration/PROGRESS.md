# Restyle v2 — overnight run ledger

Read this first. It is the only thing that carries across a restart.

## Where I got to

Phase 0 done; phase 1 starting. (Updated as the run goes.)

## Heartbeat

2026-10-05T22:05Z · fire-cd6e6b

## Branch

design-exploration-restyle

## Next action

Phase 1: run the web research (market share, majors, privacy peers, craft outliers, human factors) and write RESEARCH.md.

## Toolchain

Checked 2026-10-05T22:03Z by fire-cd6e6b: `flutter` is not on PATH, no
`ANDROID_HOME`/`ANDROID_SDK_ROOT`, Java present (`/usr/bin/java`).
Installed Flutter 3.47.2 (the version `.github/workflows/dart.yml` pins) from
storage.googleapis.com into `/opt/fl/flutter` (not persistent: a later fire
must re-download it, ~4 min:
`curl -sSfL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.2-stable.tar.xz | tar xJ -C /opt/fl`).
Baseline on `main` @ d0edb1c: `flutter analyze` clean, `flutter test` **1057/1057**.
No Android SDK yet; `flutter build apk --debug` not attempted.

## Directions (one-line theses)

- A — (to be written before phase 3 builds start)
- B —
- C —

## Checklist

### Phase 0 — Setup
- [x] Create `design-exploration-restyle` from `main`
- [x] Create PROGRESS.md, DECISIONS.md, FINDINGS.md
- [x] Commit and push

### Phase 1 — Research (RESEARCH.md)
- [ ] Market share 2026, two or more sources; where the user arrives from
- [ ] Majors: Chrome Android, Safari iOS, Samsung Internet, Edge, Firefox, Opera
- [ ] Privacy peers: Brave, DuckDuckGo, Tor Browser, Mullvad Browser, Cromite, Vivaldi, Orion
- [ ] Craft outliers: Arc/Dia, Zen, Proton, Mullvad VPN, Signal, Tailscale, 1Password, Obsidian
- [ ] Human factors: M3 expressive, iOS HIG, WCAG 2.1 AA, font-scale data
- [ ] Human factors: intimidating privacy tools, trustworthy security UI, incognito misconceptions
- [ ] "What this means for Container": 8–15 falsifiable implications
- [ ] RESEARCH.md committed

### Phase 2 — Audit (AUDIT.md)
- [ ] Colour token inventory and usage
- [ ] Type scale inventory
- [ ] Spacing, radii, density, tap targets, icon set
- [ ] WCAG contrast of real pairings, AA failures listed
- [ ] Strengths vs majors; failures for the bounced user
- [ ] Blast radius: files reading C.* / T.*, tests asserting colours/sizes/glyphs
- [ ] AUDIT.md committed

### Phase 3 — Three directions
- [ ] Theses written into this file
- Direction A
  - [ ] BRIEF.md
  - [ ] TOKENS.md + tokens.css (contrast measured)
  - [ ] logo.svg, logo-wordmark.svg, logo-monochrome.svg, app-icon.svg
  - [ ] screens.html: 10 mandatory blocks
  - [ ] screens.html: extended blocks
  - [ ] Accessibility pass (1.3, 2.0, 320px)
- Direction B
  - [ ] BRIEF.md
  - [ ] TOKENS.md + tokens.css
  - [ ] logos (4)
  - [ ] screens.html: 10 mandatory blocks
  - [ ] screens.html: extended blocks
  - [ ] Accessibility pass
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

- 2026-10-05T22:05Z fire-cd6e6b: started, first fire (no exploration branch on origin).

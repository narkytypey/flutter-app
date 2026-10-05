# Overnight task: redesign Container's whole visual identity, then build it

Run autonomously until you are out of budget. **Do not ask me questions** —
every open decision is yours to make; record it in `DECISIONS.md` with your
reasoning and move on. I am asleep. If you are unsure, pick the option you
would defend in review, write down why, and continue.

You will research, design three directions, debate them with subagents, pick
a winner, write a spec, write implementation plans, **and execute them** —
committing real code to a new branch.

## Why this exists

Container's current UI is a dense, near-black, hairline-ruled instrument
panel. It is coherent, but it is built for someone who already understands
per-site isolation, proxy routes and two-vault decoys. **The brief is users
who bounce off that UI** — people arriving from Chrome, Safari or Samsung
Internet who find it cold, cramped, or unreadable, and who do not know what a
"container" is.

The north star: *keep the privacy posture legible and uncompromised, while
making the app feel like something a normal person would choose to use.*

## What is open and what is frozen

**Everything visual is open.** Logo, wordmark, colour palette, accent colour
(jade `#7FC8A9` is droppable), light mode, typefaces, type scale, font sizes,
weights, density, spacing, corner radii, iconography, cards vs. hairlines,
elevation, motion. Nothing in `lib/ui/core/tokens.dart` or
`lib/ui/core/typography.dart` is sacred.

Two of `CLAUDE.md`'s "Global constraints" are visual and therefore **also
open, but only if you argue for overturning them explicitly in
`DECISIONS.md`**: "dark theme only, no light theme, no toggle", and "jade
means live state — never decorative, never more than one per screen". A
direction may break either; it may not break them silently.

**Frozen — do not redesign these:**
- **Flows and navigation structure.** Same screens, same order, same
  journeys. You may restyle `2b` beyond recognition; you may not decide `2b`
  should not exist or should come after `2c`. No route changes, no
  controller changes, no new providers for navigation.
- **The screen set.** All 32 blocks (`1a`–`10e`) stay.
- **User-facing copy.** Every string stays verbatim. You may change how copy
  is *set* (size, weight, case, colour) but never its words. If something
  needs a string that does not exist, record it in `DECISIONS.md` as a
  question for me and use the nearest existing string — do not invent copy.
- **Behaviour.** No feature work, no bug fixes, no logic changes. If you
  find a bug, write it into `FINDINGS.md` and leave it alone.
- **The privacy model.** Two vaults selected by PIN, per-site isolation,
  panic wipe, Tor, "the interceptor never falls back to direct", no leak
  count anywhere, no telemetry, no network request of the app's own. A
  design that leaks which vault is open, or makes the decoy distinguishable
  from the real vault, is disqualified. Settings must look identical in both
  vaults — divergence is itself the tell.

## Branches

Two branches, both off `main`. Exploration first, implementation cut from it
so the code branch carries the specs that justify it.

```
git checkout main && git pull
git checkout -b design-exploration-restyle        # phases 0-7
# ... later, after the plans are written and committed:
git checkout -b restyle-implementation            # phase 8, cut from the above
```

Commit to the branch you are on, constantly. **Never merge to `main`, never
open a pull request.** Push both branches to `origin` when they have content
so I can see them in the morning; if a push fails, keep working locally and
note it in `PROGRESS.md`.

## Where everything goes

```
docs/design-exploration/
  PROGRESS.md              <- the ledger. Read this FIRST, always.
  DECISIONS.md             <- every judgement call you made, with reasoning
  FINDINGS.md              <- bugs and oddities you spotted but did not touch
  RESEARCH.md              <- phase 1 findings, with sources
  AUDIT.md                 <- phase 2, the current design measured honestly
  index.html               <- side-by-side comparison of all three directions
  direction-a-<name>/
    BRIEF.md               <- thesis, audience, references, sacrifices
    TOKENS.md              <- palette, type scale, spacing, radii, motion
    tokens.css             <- the same values as CSS custom properties
    logo.svg               <- primary mark
    logo-wordmark.svg      <- mark + wordmark
    logo-monochrome.svg    <- single-colour fallback
    app-icon.svg           <- Android launcher icon, 108x108dp canvas
    screens.html           <- the mocked screen blocks, self-contained
  direction-b-<name>/      <- same shape
  direction-c-<name>/      <- same shape
  debate/
    round-1/<agent>.md     <- each agent's written position
    round-2/<agent>.md     <- each agent's rebuttal
    VERDICT.md             <- the ruling and the recommendation to me

docs/superpowers/specs/<today>-restyle-v2-design.md      <- phase 6
docs/superpowers/plans/<today>-restyle-v2-NN-<topic>.md  <- phase 7
```

Use the real date you are running on for those filenames.

## Surviving a session limit — read this twice

This run is expected to **hit the usage limit at least twice**. Context dies
at a limit; the branch does not. So:

1. **`PROGRESS.md` is the only thing that carries across a restart.** Create
   it in phase 0. It holds a checklist of every phase and sub-step, each
   marked `[ ]`, `[~]` (in progress) or `[x]`, plus a `## Next action` line
   naming the single next thing to do in one sentence, and a `## Branch`
   line naming which branch that action belongs on.
2. **Update `PROGRESS.md` before and after every unit of work** — not at the
   end of a phase. A unit is one screen mocked, one agent's position
   written, one palette validated, one plan task executed.
3. **`git add -A && git commit` after every unit of work.** Small, frequent,
   boringly-titled commits. Losing one commit's worth is fine; losing a
   phase is not.
4. **On resume, your first four actions are:** read `PROGRESS.md`, read
   `DECISIONS.md`, run `git branch -a` and `git log --oneline -20`, and
   check you are on the branch `## Branch` names. Then continue from
   `## Next action`. Do not re-research, do not re-plan, do not start over,
   and do not re-read the whole repo — the ledger is authoritative over your
   instincts.
5. **Never commit a tree that does not compile.** During phase 8 especially:
   if you are mid-refactor when you sense the end, finish the file you are
   in, get `flutter analyze` clean, commit, then stop.

## Phase 1 — Research (web)

Search the web properly. This is the phase that earns the rest.

**Measure the field.** Get current (2026) mobile and desktop browser market
share from more than one source, and name your sources. Establish which
browsers your target user is actually arriving from.

**Then study, in depth:**
- *The majors your user is leaving:* Chrome on Android, Safari on iOS,
  Samsung Internet, Edge, Firefox, Opera.
- *The privacy peers you are judged against:* Brave, DuckDuckGo browser,
  Tor Browser, Mullvad Browser, Cromite, Vivaldi, Orion.
- *The craft outliers worth stealing from:* Arc / Dia, Zen Browser, and
  non-browser privacy products with strong design voices — Proton, Mullvad
  VPN, Signal, Tailscale, 1Password, Obsidian.

For each, pull out what is **concrete and transferable**: actual hex values
where you can find them, typefaces and type scales, where the address bar
sits, touch-target sizes, how they visualise protection and blocked content,
how they signal a private or incognito session, how dense their lists are,
their corner radii and elevation language, how their launcher icon reads at
48px.

**Also research the human factors**, not just the aesthetics:
- Android Material 3 expressive guidance and iOS HIG where they set user
  expectations for touch targets, type ramps and motion.
- WCAG 2.1 AA contrast requirements, and what system font scale typical
  phone users actually run.
- Published research or writing on why privacy tools read as intimidating,
  and what makes a security UI trustworthy rather than alarming.
- How "incognito mode" is understood and misunderstood by ordinary users —
  this app's whole proposition depends on that mental model.

Write `RESEARCH.md`: findings organised by theme, every claim carrying its
source URL, and a closing section — **"What this means for Container"** — of
8–15 specific, falsifiable design implications. Those implications are the
input to phase 3, so make them sharp. "Be friendlier" is useless. "Row
height is 44dp against Chrome's 56dp, and the 10px tracked-out uppercase
labels fall below the legibility floor at the 1.3 font scale many users run"
is useful.

## Phase 2 — Audit the current design

Read `lib/ui/core/tokens.dart`, `lib/ui/core/typography.dart`,
`lib/ui/core/theme.dart`, `lib/ui/core/icons.dart`, everything in
`lib/ui/core/widgets/`, and `Sandbox Container -canvas-.dc.html`.

Write `AUDIT.md`: the real inventory — every colour token and where it is
used, the full type scale with its sizes and weights, spacing and radii,
density measurements (row heights, tap target sizes), and the icon set. Then
an honest critique against phase 1's findings: what the current design does
**better** than the majors (say so — this is not a demolition), and where it
specifically fails the bounced user. Compute WCAG contrast ratios for the
real text-on-surface pairings and list every one that fails AA.

**Also map the blast radius**, because you are going to implement this: which
files read `C.*` and `T.*`, how many, and which tests assert on colours,
sizes or glyphs. Put the counts in `AUDIT.md`. Phase 7 depends on them.

## Phase 3 — Three directions

Three genuinely different answers, not one answer at three temperatures.
Each must be defensible as the *best* choice for some real reader. Before
building them, write the three one-line theses into `PROGRESS.md` so a
resumed session knows the plan.

Suggested axes — use these or better ones, and record your choice:
- **A — Calm and mainstream.** Reads like a browser a normal person already
  trusts. Lighter surfaces or a true light mode, generous touch targets,
  familiar affordances, the privacy machinery present but quiet.
- **B — Confident instrument.** Keeps the technical self-image but makes it
  *beautiful* rather than merely dense: a real type hierarchy, deliberate
  colour, the current design's intent executed properly.
- **C — Something you argue for.** Your own thesis, derived from the
  research, that neither of the above covers. Take a real swing.

**Every direction must deliver all of:**

1. **`BRIEF.md`** — the thesis in a paragraph; who it is for; three to five
   named references from phase 1 and what is taken from each; what it
   deliberately sacrifices.
2. **Logo.** Hand-authored SVG, no raster, no image-generation tools. A
   primary mark, a mark-plus-wordmark lockup, a single-colour fallback, and
   an Android launcher icon respecting the 108×108dp canvas with its 72dp
   safe zone. The mark must survive 24px. Say in `BRIEF.md` what it means.
3. **`TOKENS.md` + `tokens.css`** — the complete system. Named colour roles
   (not raw swatches), each with its hex, its purpose, and **its measured
   contrast ratio against the surfaces it sits on**. Every text pairing must
   pass WCAG AA (4.5:1 body, 3:1 large text); state the ratio, do not assert
   the pass. A full type scale with family, size, weight, line height and
   letter-spacing per role — and name the typefaces concretely, with a
   licence note and a bundled-font size estimate, because **this app never
   fetches a font at runtime**; a typeface you cannot bundle under an open
   licence is not available to you. Spacing scale, corner radii, border
   treatment, elevation, motion durations and easings.
4. **`screens.html`** — self-contained mockups. One file, inline CSS, no
   external requests except a Google Fonts stylesheet if the direction needs
   one. Render each block at a realistic phone frame (390×844, and check
   320×568 too), labelled with its spec id, laid out so several are visible
   at once. **Copy transcribed verbatim** from the canvas file.

   **Mandatory blocks, in this order** — these ten carry the whole product:
   `1b` dashboard · `2b` container chrome · `2a` add site · `2c` tabs ·
   `2d` settings · `3a` lock screen · `4a` setup PIN · `5c` today ·
   `6c` shield panel · `8b` proxy refused.

   Then extend toward all 32 as budget allows, in this priority: `9b` `9c`
   `6b` `6a` `7c` `10a` `10b` `10d` `10e` `3c` `5a` `5b` `8a` `8c` `7b` `4b`
   `4c` `1a` `1c` `3b`.

5. **An accessibility pass.** The direction rendered at a 1.3 and 2.0 font
   scale and at 320px wide, with any breakage noted and fixed. This repo has
   already been bitten by exactly this (see `CLAUDE.md`'s responsiveness
   run) — do not hand me a direction that only works at one size.

Build one direction fully before starting the next, committing as you go. A
resumed session should find whole directions, not three half-built ones.

**Do not touch `lib/`, `android/`, `test/`, `assets/` or `pubspec.yaml` in
phases 1–5.** Design exploration only until the spec is approved by the
debate.

## Phase 4 — Adversarial debate

Only once all three directions exist. Spawn subagents with the `Agent` tool
and **write every position to disk** — their reports do not survive a session
limit, the files do.

**Round 1 — advocacy and attack, in parallel.** Seven agents:
- Three **advocates**, one per direction: argue your direction is the right
  choice for the bounced mainstream user, grounded in `RESEARCH.md`, and name
  the strongest objection you expect.
- Four **critics**, each given all three directions and one lens only:
  - *Threat model:* does any direction weaken the coerced-unlock posture,
    make the decoy vault distinguishable, leak which vault is open, or
    reintroduce a leak count?
  - *Accessibility:* contrast ratios recomputed independently, font scaling,
    touch targets, screen-reader labelling, colour-blind safety. Verify the
    directions' own claimed numbers rather than trusting them.
  - *Implementation cost:* measured against this actual codebase, using
    `AUDIT.md`'s blast radius — how much of `lib/ui/` and how many of the
    1000+ tests does each direction churn, and what breaks
    `test/no_glyphs_test.dart` or the token layer?
  - *Mainstream familiarity:* would a Chrome user understand this in ten
    seconds? Where does each direction still assume knowledge the user does
    not have?

Each writes a file to `debate/round-1/`. A critic must name a *specific*
failure — a hex pair, a screen id, a file — not a vibe.

**Round 2 — rebuttal.** Give each advocate the four critiques of their
direction and have them concede what is true, rebut what is not, and specify
the minimal change that fixes each conceded point. Critics get the advocates'
round-1 positions and sharpen or withdraw their objections. Written to
`debate/round-2/`.

**Then judge it yourself.** You have read everything; do not delegate the
verdict. Write `debate/VERDICT.md`:
- A scorecard across the four lenses plus aesthetic conviction, scored with
  reasons rather than numbers alone.
- Which direction you recommend and why.
- The strongest argument *against* your own recommendation, stated fairly.
- Which elements of the two rejected directions you are folding into the
  winner, and why.
- What remains genuinely unresolved and needs my decision — and what you
  assumed in the meantime so the build could proceed.

## Phase 5 — Comparison page

Write `docs/design-exploration/index.html`: the three directions side by side
for the same handful of screens, their palettes and type scales as swatch and
specimen rows, the logos at several sizes, and a link into each direction's
own `screens.html`. Mark the winner. Self-contained, readable on a phone.
This is the first thing I will open in the morning, so make it the thing that
explains everything else.

## Phase 6 — The spec

The winner, folded with whatever you lifted from the other two, written up as
a real design spec at `docs/superpowers/specs/<today>-restyle-v2-design.md`.
Follow the shape of the existing specs in that directory.

It must be complete enough to build from without rereading the debate:
- Every token, with its final value and role. This is the contract the code
  will implement.
- The full type scale, mapped **role by role onto the existing `T.*` names**
  in `lib/ui/core/typography.dart`, so the diff is legible. Say explicitly
  which `T.*` and `C.*` names are added, which are retired, and which keep
  their name but change value.
- Per-screen notes for anything that is not a pure token swap.
- The icon and logo treatment, and what lands in `assets/`.
- Light mode: whether this design has one, and if so what that does to
  `secure_window.dart`, the Android theme (`values/styles.xml` — note that
  **both themes are currently dark on purpose**, because WebView only
  darkens pages under a dark theme; changing that is a behaviour change, so
  if your design needs it, flag it as a question for me rather than doing
  it).
- An explicit **non-goals** section: no flow changes, no copy changes, no
  behaviour changes.

Commit it. Then write a one-paragraph self-review at the bottom: placeholders
scanned, internal contradictions checked, ambiguities resolved.

## Phase 7 — The plans

Invoke the `superpowers:writing-plans` skill and write the implementation
plans into `docs/superpowers/plans/`, following this repo's conventions
exactly — read two or three existing plans first, and read `CLAUDE.md`'s
"Known cross-plan issues" before writing anything.

**Decompose into 2–4 plans**, each shipping working, tested software on its
own. The natural seam, given the blast radius from `AUDIT.md`:
1. **Foundation** — `tokens.dart`, `typography.dart`, `theme.dart`,
   `icons.dart`, the logo and font assets, and the shared widgets in
   `lib/ui/core/widgets/`. Ends with the app building and every test
   passing.
2. **Screens, in waves** — grouped so each wave is independently verifiable.
   Dashboard and container chrome first, then setup and lock, then settings
   and the management screens, then the sheets and failure states.

Number them continuing this repo's sequence (the last plan is 19, so start
at 20) and name them `<today>-restyle-v2-NN-<topic>.md`.

Each plan task must state its verification commands. Commit the plans.

## Phase 8 — Execute

Cut `restyle-implementation` from the exploration branch. Then execute the
plans with `superpowers:subagent-driven-development`, or
`superpowers:executing-plans` if you are driving it yourself.

**Test-driven, per the repo's own practice.** A restyle is mostly mechanical,
but the tests are the thing that tells you whether a screen still works:

- **Never delete or weaken a test to make it pass.** If a test asserts a
  colour or a size the new design changes, update the expectation to the new
  value — and only that. If a test fails for a reason that is *not* the new
  value, you have broken something: stop and fix the code, not the test.
- `test/no_glyphs_test.dart` must keep passing. Icons stay `AppIcon` line
  icons drawn in `lib/ui/core/icons.dart`; do not reintroduce Unicode glyphs
  or `Icons.*` into `lib/`.
- `test/ui/small_screen_layout_test.dart` and
  `test/ui/responsive_layout_test.dart` must keep passing. The restyle must
  not reintroduce the overflows this repo already fixed twice.
- `test/android_theme_test.dart` guards both Android themes being dark. If
  your design needs that changed, it is a question for me — do not change
  it.
- Copy must come out byte-identical. If a copy assertion fails, you changed
  a string; put it back.

**Gates, after every plan and before every claim that something is done:**

```
flutter analyze                 # must be clean
flutter test                    # must be all-passing; record N/N
flutter build apk --debug       # must show zero "e:" lines
```

Run all three. `flutter analyze` and `flutter test` are **Dart only and
never compile the Kotlin in `android/`** — `flutter build apk --debug` is the
only check that catches a Kotlin error, and this repo has shipped
never-compiled Kotlin to a commit before because of exactly that. Flutter
and Gradle commands may need the Bash sandbox disabled.

Record the real numbers. **Never write "tests pass" without the count you
actually saw.** If a gate fails and you cannot fix it, revert to the last
green commit, write what happened in `PROGRESS.md`, and move to the next
task rather than leaving the tree broken.

Commit per plan task, with the plan and task named in the message. Keep the
tree green at every commit.

**You cannot verify this on a device** — there is no emulator in this
session. Every record you write must say **"Not verified on a device"**. Do
not claim a screen looks right; claim the tests pass and the build succeeds.

When a plan is finished, add its row to `CLAUDE.md`'s plan table in the same
style as the existing rows — what it covers, what you verified with the real
numbers, and what is left open. Append to the table; do not rewrite the file.

## Phase 9 — Only if budget remains

In this order: finish any screen waves the plans left undone; complete all 32
blocks in the winner's `screens.html` so the mockups match the code; an
animated interaction study for the key transitions; a one-page rationale I
could show someone else.

## Standing rules

- **Never stop to ask.** Decide, record in `DECISIONS.md`, continue.
- **Never claim something passes without the number.** Contrast ratios get
  computed and shown; test counts get read off the run. This repo's
  `CLAUDE.md` is full of claims that turned out to be false — do not add to
  them. When you are unsure whether something works, write that down.
- **Never change copy, flows, or behaviour.** Visuals only.
- **No app code in phases 1–5.** All the code is phase 8.
- **Commit constantly, keep the tree green**, and never merge to `main` or
  open a pull request.
- When you run out of work or budget, make sure `PROGRESS.md`'s `## Next
  action` and `## Branch` are accurate, and write a short `## Where I got
  to` at its top: which phase, which branch, what the last gate run said,
  and what I should look at first.

Start with phase 0: create the exploration branch, create `PROGRESS.md` with
the full checklist of every phase above, commit, then begin phase 1.

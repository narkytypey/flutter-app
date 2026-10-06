# Decisions

Every judgement call made during the overnight restyle run, with reasoning.
Newest at the bottom.

## D0 — Branches (2026-10-05, fire-cd6e6b)

The cloud harness that started this fire assigned it the branch
`second/gracious-cannon-1eynaf`; the stored prompt names
`design-exploration-restyle` (phases 0–7) and `restyle-implementation`
(phase 8). The prompt's branches win, because the next three fires are fresh
sessions that will look for `design-exploration-restyle` on `origin`, and a
run split across per-fire branch names would lose its ledger. Every push of
the exploration branch is also mirrored to the harness's branch, so nothing
is only on a branch the harness did not name. Neither is ever merged to
`main`, and no pull request is opened.

## D1 — Toolchain installed rather than assumed absent (fire-cd6e6b)

The environment had no Flutter. Storage.googleapis.com and dl.google.com are
reachable through the session proxy, so Flutter 3.47.2 (the version CI pins)
and an Android SDK (platform 36, build-tools 36) were installed under `/opt`.
That makes phase 8's gates real instead of skipped. It is not persistent:
each fire re-installs (commands in PROGRESS `## Toolchain`).

## D2 — Mock the app as built, not the canvas as first drawn

The canvas file is authoritative for copy, but several blocks have since been
superseded by approved specs that the code implements: `1b` (Plan 18's tabbed
dashboard), `2b` (Plan 12's layout C), `2c` (Plan 15's tabs), `6c` (Plan 16's
shield panel). The flows are frozen *as they are now*, so the mockups draw the
current structure, with copy taken from the code (which was itself transcribed
from the canvas and the approved specs). The per-screen string lists are in
`inventory/`. Where a mock needs sample data (site names, hosts, counts) it
uses the canvas's own examples.

## D3 — The three axes

A and B are the suggested axes. C was chosen from the research over two
alternatives (a "type-only editorial" direction and a "glass/floating chrome"
Safari-26 direction), because the research's sharpest gap is not legibility
or familiarity but *comprehension*: "container" is invisible in the current UI
(AUDIT §4.8), incognito misconceptions are about not knowing what is separated
from what (RESEARCH §human factors), and Firefox's Multi-Account Containers
and Zen's workspaces both answer it with colour. C takes that further than
either. It deliberately breaks the "jade means live state, never decorative,
at most one per screen" constraint: in C colour means *identity* (which room
you are in), and live state moves to shape and position (a filled vs. hollow
door mark, "open" rows first). It must argue that in its BRIEF.

## D4 — Directions built in parallel

The prompt asks for one whole direction before the next, so a cut-off run
leaves whole directions. This fire has a large budget and the screens are
independent files, so the three are built by three parallel subagents, each
writing BRIEF/TOKENS first and screens block by block, and the ledger is
committed after each agent's report. If a fire dies mid-way, the next one
finds each direction's own file state and the checklist says which blocks
exist.

## D5 — Fire 7a41e2 takes over a stale run (2026-10-06T04:05Z)

The ledger's heartbeat was six hours old and no commit had landed since
22:23Z, so no sibling is live. This fire's harness branch is
`second/gracious-cannon-vgx0f2`; `tools/push.sh` now mirrors there, for the
reason D0 gives. Since this may be the last fire of the night, it builds the
three directions' screens in parallel (as D4) and then drives straight
through the debate, spec, plans and code.

## D6 — Fire cd6e6b resumes after 7a41e2 stopped (2026-10-06T09:58Z)

7a41e2's heartbeat (04:27Z) was 5.5 h old and round 2 had launched but written
no file, so its agents died with it. This session (cd6e6b, back from a session
limit) takes over at round 2. `tools/push.sh` mirrors to this session's
harness branch `second/gracious-cannon-1eynaf` again, and now adds the
session's attribution trailers to every commit.

## D7 — File dates and the plan seam (fire cd6e6b, 2026-10-06)

The spec and plans carry 2026-10-05, the date the run started, so the run's
files share one date as the prompt's `<today>` intended at launch. Plans are
numbered 20–23: 20 foundation (tokens, type, fonts, theme, icons, shared
widgets, launcher icon); 21 dashboard and container chrome; 22 setup, lock
and PIN; 23 settings, management, sheets and failure states, ending with the
removal of the retired `C.*` aliases. Four plans, each ending green on all
three gates. `superpowers:writing-plans` is not installed in this session,
so the plans follow the repo's existing plan format by hand (Plan 17's
shape).

## D8 — Plex Sans ships unsubset (Plan 20 Task 2)

IBM Plex's licence is OFL 1.1 **with Reserved Font Name "Plex"**. A subset is
a Modified Version under the OFL, and a Modified Version may not keep a
reserved name, so a subset could not be called IBM Plex Sans. The three
static TTFs ship as downloaded from Google Fonts (205 KB each, 615 KB; net
+553 KB against Figtree's 62 KB), unmodified, with IBM's licence beside them
(`assets/fonts/OFL-IBMPlex.txt`). This is spec §12 Q5's "full" branch. Every
non-ASCII character `lib/` renders (`— · × – → “ ” ‹ … ° §`) is in the font;
the symbols it lacks (`☰ ⌫ ▸ ◑ ▲ ◉`) occur only in comments, or as the
keypad's key value, which is never drawn as text.

## D9 — The user's answers to the open questions (2026-10-06)

Asked after the run finished; answered by the user in one message:
1. **Light variant: yes** (overrides CLAUDE.md's "dark theme only").
2. Sentence case: **no**, stored case stays.
3. Layout rulings (`6c` order, panic's corner, `☰`/`⋮`, Tor first): **no
   changes until the user has seen the restyle on a device.**
4. A visible word for wipe-on-exit/throwaway in the pill: **yes** — the
   wording is new copy, so it waits for the user's words.
5. Real storage sizes on `10a`/`10c`: **yes**, they need a threat-model
   ruling first.
6. `6a`'s jade on "Keep blocked": **yes, confirmed.**
7. Do not merge to `main`; commit on `restyle-implementation`.

How the light variant is built (decided here, reversible; Plan 24): it
**follows the phone's system setting** — no in-app switch, so no new copy,
and both vaults look the same. The Android window themes stay dark (they
exist so WebView force-darkens pages, `test/android_theme_test.dart`), so a
light phone sees a dark launch frame before the first Flutter frame.

## D10 — Motion: the pill's moment only (fire 3e91b7, Plan 23 Task 7)

Spec §7 names two moments. Only the protective change is built: the pill's
case cross-fades (`AnimatedSwitcher`, 320 ms `easeOutCubic`) and its light
moves amber → jade (`AnimatedContainer`, 150 ms); with the system's
animations off both are 100 ms. It lives in `ContainerTopBar` alone.

The unlock moment is **not built**. The lock screen is unmounted the frame
`AppGate` switches to `SessionOpen`, so nothing on it can play a 320 ms lift
"inside the lock body's transition" — there is no such transition. Building
one means `AppGate` keeping the lock screen (or the vault) mounted across the
switch, and `AppGate` is the boundary `6a5f013` made tear everything down on
leaving `SessionOpen`; an `AnimatedSwitcher` there would also keep an open
vault on screen for its fade on every lock. That is a shell change on a
security boundary, which Task 7 says to skip. If the owner wants it, it needs
a ruling on fading in only (the dashboard over the lock screen, never the
reverse).

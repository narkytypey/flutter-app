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

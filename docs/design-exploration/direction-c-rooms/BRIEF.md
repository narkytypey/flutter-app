# Direction C — Rooms

## Thesis

Container's one idea — *every site runs in its own isolated container* — is
invisible today: a site row looks like a bookmark, and the whole app is the
same near-black, so a newcomer reads it as "a dark incognito browser"
(AUDIT §4.8; RESEARCH §7). Rooms makes the isolation **visible and
nameable**. Every saved site is a **box** that lives in a coloured **room**,
and the room's colour is its workspace's existing marker colour (`10b`'s five
markers, already stored per workspace in both vaults). On the dashboard the
viewed workspace is a big tinted room and its sites are white boxes inside
it; inside a site, the same colour frames the browser chrome — the top and
bottom bars, the address pill's edge, the site's card in `2c` — so "which
container am I in?" is answered before the user reads a word. Anything that is
*not* a saved site's room looks deliberately different: a **throwaway** has no
room, so it is drawn as an unwalled, dashed, hatched box; a **Tor** route
adds a second wall (a double frame) and an onion mark; a **wipe-on-exit**
site or workspace carries a small flame. Colour now means identity, so live
state moves to **shape and position**: a filled door is an open container, a
hollow door an idle one, and open sites sort first. The single affirmative
action on a screen is the one **solid ink pill**. Surfaces are warm paper and
ink, light by default and following the system, with a warm-dark
counterpart; Figtree is set large and round; IBM Plex Mono is kept only for
values.

## Who it is for

**Dana, 34, a Samsung Galaxy A-series owner who uses Chrome.** A friend told
her Container "keeps your bank separate from everything else". She installed
it, saw a black screen of grey lists, decided it was "another incognito
thing", and uninstalled it the same evening. She thinks private browsing is
"the dark mode where nobody can see what you do" — she is in Wu et al.'s 37 %
who believe incognito hides them from their employer. She is not technical,
reads at a 1.15 font scale, and holds the phone in one hand.

The test: after ten seconds on the Sites tab, Dana can say **"each site lives
in its own box, and these colours are my boxes"** — and inside Bank, she can
tell it is her green Personal room without reading the address.

## References (from RESEARCH.md) and exactly what is taken

1. **Firefox Multi-Account Containers** (RESEARCH §2 implication 6; D3) —
   the idea that a container *is* a colour, and that the colour marks the
   tab/chrome while you are in it. Taken: colour on the chrome edge, never on
   page content; one colour per container family (here: per workspace).
2. **Zen workspaces** (RESEARCH §4 "Identity per context") — whole-space
   tinting per workspace, so switching workspaces visibly changes the room
   you are standing in. Taken: the dashboard's list sits on the viewed
   workspace's tint; the chips are the rooms' doors. Not taken: Zen's
   gradients and its thin concentric logo (fails at small sizes, RESEARCH §4).
3. **Proton's master hue fading into product colours** (RESEARCH §4) — a
   family of hues with shared lightness and chroma rather than five unrelated
   swatches. Taken: the five markers are re-drawn as one family (same
   lightness band per role: *wall*, *tint*, *ink*), so no room shouts over
   another, and the app's own identity (the logo, paper, ink) stays neutral.
4. **DuckDuckGo's Fire Button** (RESEARCH §3) — burning as a friendly,
   legible action. Taken: the **flame** is the mark for wipe-on-exit, and the
   destructive confirm is the biggest target on its sheet, set apart from
   Cancel (implication 12).
5. **Material 3 Expressive containment research** (RESEARCH §5) — key
   elements found faster with containment, shape and size. Taken: rounded
   tinted cards replace hairline lists; the site box, the room panel and the
   sheet are three clearly different surfaces.

## What it deliberately sacrifices

- **The "instrument panel" self-image.** No near-black default, no tracked
  uppercase labels, no hairline-only structure. Experts lose some density:
  a Sites row is 76 dp instead of 60, so about 7 sites fit above the fold at
  390×844 instead of 10.
- **Jade as the one colour.** Jade survives only as marker 0's hue family
  (Fern). It no longer means "live".
- **A five-colour free choice without rules.** Each marker is now a fixed
  family (wall / tint / ink in light and dark); a user cannot pick an
  arbitrary hex, as today.
- **A red marker.** No room may be red, so danger (brick red) can never be
  mistaken for a room. The family is Fern, Lake, Ochre, Plum, Graphite.
- **Amber as "opening".** Ochre is a room now, so "opening" is shown by shape
  (a door with a turning arc), not by colour.

## What the logo means

A **room with an open door**: a thick-walled rounded square (the container)
with a solid arched door standing in it. It reads as "a site in its own box"
and as "a door you control". It is one physical object (RESEARCH §4: marks
built on one object survive 16 px; thin concentric strokes do not), it has no
thin lines, and it is drawn in two flat shapes so it works as an Android 13
themed (monochrome) icon. In colour, the walls are ink and the room's floor is
Fern tint, the first marker — the mark itself is "your first room". The door
is the same door shape the app uses for open/idle state, so the logo teaches
the vocabulary.

## Global constraints this direction touches

### Dark-only — broken, argued

CLAUDE.md says "Android only, dark theme only". Rooms is **light by default,
following the system setting, with a full warm-dark counterpart**. Reasons:

1. Every major browser follows the system (RESEARCH §2); a privacy app that
   refuses to looks like nobody's.
2. The user has learned **dark = private** (RESEARCH §2, §7). A dark-only
   Container spends that signal before the user does anything, and teaches
   the wrong lesson — that privacy is a colour. Rooms says privacy is *walls*:
   it must read as private in daylight.
3. Positive polarity reads better at small sizes for normal vision (RESEARCH
   §5); the room tints are also far more distinguishable on paper than on
   near-black (tints at L≈92 vs L≈18).
4. Nothing depends on the vault: the theme follows the *system* setting,
   which is the same whichever PIN was typed. The decoy looks identical.

### Light mode and WebView

The Android theme stays dark (`values/styles.xml`, guarded by
`test/android_theme_test.dart`), because WebView only force-darkens under a
dark theme. A light Flutter UI is drawn over it without touching that file.
Consequences, and how Rooms lives with them:

- **Pages are told `prefers-color-scheme: dark`** even when the chrome is
  paper. Rooms frames the page anyway: the page area is inset inside a 3 dp
  room-coloured wall, so a dark page inside a light chrome reads as "the site,
  inside its room" rather than a mismatch. The frame is the seam.
- The cold-start splash is `Theme.Black` before Flutter's first frame. In
  light mode this is a ~200 ms black flash before the paper lock screen. It
  is the same flash every Flutter app with a dark launch theme has; fixing it
  would mean a `LaunchTheme` change, which is out of this direction's scope
  and left as a phase-7 question.
- Force dark mode (`2a`, `6c`) keeps its meaning: it darkens pages, never the
  chrome.

### "Jade means live state, never decorative, at most one per screen" — overturned

That rule made jade do two jobs: *this is live* and *this is the action*. In
Rooms, colour means **identity** (which room), so jade cannot also mean live:
on a Personal (Fern) dashboard every card would be green. The rule is
replaced by three narrower rules, each enforceable:

1. **Room colour is identity, and only identity.** A room colour appears only
   where it says "this belongs to workspace X": chips, the room panel, the
   monogram tile, the chrome frame, the `2c` card. Never on a button, a
   switch, a check, a progress bar or a count. Never on page content.
2. **Live state is shape and position.** Open = filled door + listed first;
   idle = hollow door. Opening = hollow door with a turning arc. Viewed (in
   `2c`) = the card is raised and framed in its full room wall; background =
   flat. This passes for colour-blind users, which jade-vs-grey never did
   (the idle dot was 1.95:1).
3. **The single affirmative action is the one solid ink pill** on a screen
   (ink on paper 15.9:1; paper on ink in dark 15.1:1). Every other button is
   an outlined pill. Ink is never used for anything else that is filled and
   pill-shaped, so "the solid one is the one to press" is unmistakable, and
   it is colour-independent. Selection marks (checks, radios, switch on) are
   also ink, but none is a pill.

The research supports the overturn: Firefox containers and Zen workspaces
both let users tell isolated contexts apart by colour (RESEARCH §4,
implication 6); Brave's users read protection from colour before numbers
(§3); and implication 6 asks that a Keep site, a wipe-on-exit site, a
throwaway and a Tor route differ *in the chrome itself*. Rooms does that with
four independent channels (hue, frame shape, pattern, icon), so it never
leans on hue alone.

### Other constraints, kept

- **Two-vault decoy.** Colour comes from the workspace's own marker, which
  both vaults store. No per-vault theme, mark or accent; Settings identical.
- **No leak count.** None. The blocked tally (Today, `6c`) is a quiet ledger
  in ink with neutral bars — not coloured, not graded.
- **Danger is never a full-screen fill.** Brick red as text, outline, or a
  small tinted panel (`8c`'s banner, the panic button's tinted square).
- **Hairlines, not cards** — broken by design (containment replaces it),
  argued via M3 Expressive (RESEARCH §5, implication 4).
- **Mono for anything technical** — narrowed to *values* (hosts, ports, rule
  counts, code), per implication 8.

## Copy questions

1. **Throwaway in `2c` has no workspace name**, and the header's
   `<WORKSPACE NAME>` is empty for it. Rooms shows the throwaway's dashed box
   instead; no string is needed, but should the header show anything?
   (Used: nothing, as the code does.)
2. **The wipe-on-exit flame and the Tor onion need screen-reader labels.**
   Rooms reuses existing strings: `Wipe on exit` (2a/6c) for the flame and
   `Tor` (2a's chip) for the onion. Confirm these are acceptable as labels.
3. **The door mark (open / idle) has no label.** Today rows have "no extra
   label" either; the live rail was silent too. A screen-reader label for
   "open" would be new copy — question for the user. (Used: none.)

# Container's restyle, on one page

**What it is:** a visual restyle of Container, a privacy browser for
Android. Each site runs in its own isolated container, and there are two
vaults: a real one and a decoy that a different PIN opens. The style is
called **"Instrument"**. It was picked from three directions after an
adversarial debate, then written up as a spec and built on branch
`restyle-implementation` (Plans 20–23). Not merged. **Not verified on a
device.**

## The problem

A Chrome user who tried the app gave up on it. The audit (AUDIT.md) measured
why:

- text too small and too faint;
- tap targets under 48 dp;
- four surfaces that could not be told apart;
- jargon set in the loudest style on the screen;
- an overall feel that was cold.

It also found what the app already does better than the major browsers, and
should keep:

- it shows its real state honestly;
- it uses one accent colour;
- technical facts are set in a technical typeface.

## The choice

| | A: Daylight | **B: Instrument** | C: Rooms |
|---|---|---|---|
| Idea | Chrome's look, in light or dark | The current app, made warm and legible | Each workspace has its own colour |
| Coerced-unlock safety | Good after one fix | **Best: nothing depends on the vault** | Blocking: room colours can be read across a room |
| Accessibility | Second (cut the host at the default size) | **Best: no overflow at any of six sizes** | Worst: the workspace is shown by colour alone |
| Cost | 10–12 agent-days | **7–9 agent-days** | 13–16 agent-days |
| Familiarity | **Best** | Second | Worst |

B was the only direction that no lens blocked. Container exists for the
moment someone forces the owner to unlock it. B is the only direction whose
identity costs nothing in that moment.

**Strongest argument against B:** most phones are in light mode, and Chrome
users read a dark browser as "incognito". The light variant is left as an
open question (below), not ruled out.

## What changed

- **Colour.** The background moved from cold green-grey `#0F1113` to warm ink
  `#121110`. There are four visibly different surfaces and three text tones.
  Every text tone measures at least 5.30:1 in common use, and every boundary
  at least 3.3:1.
- **Jade.** It now means only "this is live" or "the one safe action on this
  screen". It is gone from switches, checks, tabs and step bars, which only
  show a position. On `6a`, the jade moved to "Keep blocked".
- **Type.** IBM Plex Sans for words and IBM Plex Mono for values. Nothing a
  user navigates by is under 13 sp; only the route badges are 12 sp.
- **Targets and safety.** Every target is at least 48 dp.
  - The host in the address pill is never cut off. It wraps after its dots, so
    `forum.example.com.evil.io` cannot hide its real domain.
  - The pill's case mark has a different shape for each container type: solid
    for keep, broken for wipe-on-exit and throwaway, double for Tor.
  - The shield fills to match the site's security level.
- **Selection.** A selected option shows a check and an outline as well as a
  colour, so colour-blind users can tell it apart.
  - On `8b`, the risky choice is a red text button, set 24 dp below the safe
    ones.
  - On `2c`, there is a 24 dp gap between "Close all and wipe" and panic.
- **Unchanged:** every word of copy, every flow and behaviour, the privacy
  model, and the Android theme.

## Evidence

- **Gates on `a34c7ad`:**
  - `flutter analyze`: clean.
  - `flutter test`: 1142/1142 (the baseline was 1057).
  - `flutter build apk --debug`: zero `e:` lines.
- **Test expectations changed:** each one moved to a value in the spec, and
  each is listed in its plan's Verification section. No test was deleted.
- **Where to see it:** `index.html` compares the three directions.
  `direction-b-instrument/screens.html` draws all 32 screens.
  `interaction-study.html` shows the motion.

## Your decisions

1. Dark only, or a light variant later? (About 1.5–2 agent-days.)
2. Sentence case for section labels? This needs an exception to "never
   re-capitalise".
3. Layout rulings the debate raised but a restyle should not make:
   - `6c` leading with protection instead of the proxy;
   - where panic sits;
   - `☰` → `⋮`;
   - Tor before SOCKS5.
4. A visible word for wipe-on-exit in the pill.
5. A rule against showing real storage sizes until the threat model allows
   them.
6. Confirm that `6a`'s jade belongs on "Keep blocked".
7. Merge `restyle-implementation`, after a look on a device (each plan has
   its own list of device checks).

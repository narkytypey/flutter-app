# Round 1 — Accessibility critic

One lens only. I did not use the directions' own tables. Every number below was
recomputed by rendering each `screens.html` in Playwright and walking every
text node and icon inside every `.phone`. For each one I composited its
computed colour, including inherited `opacity`, over the composited ancestor
backgrounds and took the WCAG ratio. I ran this on A light and dark, B, and C
Paper and Ink, at 390 wide. I also measured targets from the bounding box plus
any absolute `::before` hit area, and simulated colour blindness with the
Machado 2009 matrices at full severity, measuring separation as CIEDE2000.
The overflow checker was re-run at every required size. Scripts are in
`/tmp/claude-0/` (`audit.mjs`, `targets.mjs`, `cvd.py`).

## What all three get right

- **Text contrast holds up.** The text-node sweep found no enabled text under
  4.5:1 in any direction or theme. The only hits are disabled or inert
  controls, which WCAG exempts:
  - A `4a` disabled Continue: `#8D938E` on `#D9DED6`, 2.30:1 (2.68:1 dark).
  - C `10c` inert Delete pill: 1.84:1 Paper, 2.02:1 Ink.
  - C `2b` inert back and forward icons at 38% opacity: 1.84 to 2.60:1.

  I have one caveat on C's `10c`. If that Delete is "inert as built" rather
  than truly disabled, a user cannot read why it is there. It should be
  hidden, or exposed to TalkBack as disabled.
- **Targets are at least 48 dp** for every icon tap, chip, key and pill in all
  three. A's 52×32 switches sit in a 48-tall `.sw-hit` and whole-row taps.
  A's `8b`/`8c` 40-wide back and reload icons are deliberately inert.
- **Icon-only buttons carry labels** in the mockups. The counts of
  `aria-label` are A 37, B 42 and C 53, and they match the app's existing
  `IconTap` labels (Close, Back, Reload, Site details, Panic, Open sessions,
  Menu).

The failures are in three places: what large text does to the host, state
that only colour shows, and C's room colours.

## Direction A — Daylight

**Font scaling: claimed pass, actual fail.** `A11Y.md` says an extra run at
320 × 2.0 reports `no overflow`. Today it does not, in either theme:
`8a: <span class="t-body2"> spills 25px: "Connecting through 127.0.0.1:9050"`.
`8a` is the opening checklist, and that line names the route the user is
about to trust.

**The host is cut at 2.0.** In `2b` at 320 × 2.0 the pill reads
`forum.examp…`. `A11Y.md` says the pill wraps "with the host whole". The
render shows the host ellipsized on line one and the badge group on line two.
For a browser whose safety rests on the user checking the host, this is the
single worst large-text failure in A.

**State shown by fill alone.**
- The selected nav tab is marked by a `--tonal` pill: `#D9DED6` on card
  `#FFFFFF` is 1.37:1, and 1.20:1 in dark (`#2B302D` on `#1E2220`). The label
  only changes from ink2 to ink, and those two are 2.08:1 apart. Nothing else
  marks the selected tab. A filled-versus-outlined icon, or a 3:1 indicator,
  would fix it.
- Chips and segments are fine. `chip.sel` and `.seg .on` add a check icon, so
  their 1.26:1 fill change does not have to carry the state on its own.

**Colour-vision deficiency.**
- In light mode, markers `m0` (`#1D6B57`) and `m4` (`#5E6661`) are ΔE 2.9
  apart under deuteranopia: green and grey become one colour.
- `danger` (`#B3261E`) and `warning` (`#8F5B00`) are ΔE 2.1 apart under
  deuteranopia. Today every warning use is labelled ("Permission asks", the
  JS badge), so this is a latent risk, not a live failure.

**Verdict: pass with fixes.** It has the strongest base: a 13 sp text floor,
no enabled contrast failures, and checks on selection. It must fix the `8a`
overflow, keep the host whole at 2.0, give the nav a non-fill selected cue,
and separate `m0` from `m4`.

## Direction B — Instrument

**Font scaling: honest.** All five runs report no overflow, including
320 × 2.0. At 2.0 the host wraps rather than being cut. It breaks mid-word
(`forum / .exam / ple.c / om`) and the pill grows to about four lines. That is
ugly, but every character stays readable, which is the right trade.

**The selected chip is the weakest state cue in any direction.**
- `.chip.on` changes the fill to `--surface-raised`. That is `#403C37` on ink
  `#121110`, 1.72:1, and 1.49:1 on `--surface-group`.
- The label moves from text-2 to text-1, 1.44:1 apart, and from weight 500 to
  600.
- The unselected chip's outline is a 14% alpha line, 1.43:1.
- There is no check icon. This affects `1b`'s workspace chips, `2a`'s
  WORKSPACE row and `10b`. Under low vision, or in sunlight on a dark-only
  UI, "Personal" and "Work" look alike.
- The selected tab uses the same 1.72:1 `--surface-raised` indicator.

Add a check icon as A does, or a text-1 outline, which measures 3:1 or more.

**The text floor is 12 sp.** That covers `--fs-caption` badges and the
dashboard tab labels. It passes contrast, but the tab labels are navigation,
and 12 sp at 1.0 is the smallest of the three.

**Colour-vision deficiency is safe.** The state lights are jade `#7FC8A9`
(live), amber `#E0B266` (opening), danger `#EE8D79` (failed) and edge grey
(background). Their worst pair under deuteranopia is opening/failed at ΔE 7.0,
and each light also differs in shape or in its text:
- Idle is a hollow ring.
- Failed comes with a red-outlined pill and `8b`'s headline.
- Opening comes with `8a`'s checklist.

The markers keep at least ΔE 6.0 under every simulation.

**Verdict: pass with fixes.** It is the most robust at large text. Selection
needs a non-fill cue, and the tab labels should go to 13 sp.

## Direction C — Rooms

**Font scaling: claimed pass, actual fail, and the worst of the three.**
- At 320 × 2.0, Paper and Ink both report
  `1a: <span class="t-screen"> spills 10px: "Personal"`, against `A11Y.md`'s
  "all no overflow".
- In `2b` at 2.0 the pill shows `forum.e…`, and the throwaway frame shows
  `duckduc…`. Most of the host is gone. On a throwaway, the host is the only
  thing that says where you are.
- In `1b` at 2.0 the site name is cut to `Not…`, and the search hint wraps to
  three lines. One site row is visible above the search field and the nav.
  A and B also show about one row at that size, but both keep the name whole.

**Room identity is carried by colour alone in places that matter.**
- **`2c` switcher.** The header reads `PERSONAL`. The Wiki card (`room-lake`,
  Work) sits between Personal cards with no workspace text. Only the lake wall
  and tint say it belongs to Work, which fails WCAG 1.4.1. TalkBack would
  announce "Wiki, background · 3 min" and never say which room.
- **`2b` chrome.** The room is the tinted bars and the pill's 2 dp wall. The
  workspace name is not shown. Tint against page is 1.16:1 in Paper and
  1.19:1 in Ink, so the tint is atmosphere, not a readable signal. Only the
  wall reaches 3:1, and fern's wall on page is 4.39:1.

**Colour-vision deficiency: CIEDE2000 between rooms, at full severity.**
- **Ink tints, deuteranopia:** plum `#34222E` against graphite `#25282B` is
  **ΔE 0.9**. They are identical.
- **Paper tints, protanopia:** lake `#CFDDF0` against plum `#ECD6E8` is
  **ΔE 2.1**.
- **Paper tints, deuteranopia:** plum/graphite 3.8, lake/plum 4.6.
- **Walls** do better: the worst is lake/plum at ΔE 7.4 (protanopia, Paper)
  and 4.5 (Ink). But a 2 to 3 dp line is small, so 4.5 is marginal.

C uses five hues where A and B use them only as small markers. That means C
needs every room name on screen wherever its colour is, or a second cue such
as a pattern or a glyph per room.

**The focus ring disappears in Lake rooms.** `--focus` is `#2C6AA3`, which is
exactly `--lake-wall`. In Ink both are `#7FB0E3`. A focus ring on a walled
element in a Lake room measures 1.00:1 against the wall. Switch Access and
keyboard users lose their place.

**Red/green.** Fern (live, the affirmative action) against danger is
ΔE 9.7 or more under every simulation. That pair is fine. Danger `#B0362A`
against ochre `#8E6410` is ΔE 3.4 under deuteranopia in Paper. Ochre is a
room, so an Ochre room's chrome next to a danger outline (`8b`, panic) can
blur together.

**What C does well.**
- Throwaways get a non-colour cue: a dashed wall and a hatch.
- "Wipe on exit" is a labelled flame glyph, not a colour.
- Its segment selection uses a 3 dp outline plus a drawn check, which is the
  best selection cue of the three.
- It also has the most labels in the markup: 53 `aria-label`s and 55
  `role=button`.

**Verdict: fail as drawn.** It needs four fixes:
1. Show the workspace name as text in `2b` and on every `2c` card.
2. Give each room a non-hue cue.
3. Re-space the tints so the five rooms keep at least ΔE 5 under
   deuteranopia and protanopia in both themes.
4. Move `--focus` off the lake hue, to ink or a 2-colour ring.

## Ranking on this lens

1. **B.** It is honest at 2.0, and its colour-vision behaviour is safe. Its
   one real gap is the selection cue.
2. **A.** It is close behind, but it overstated its 2.0 results. The host cut
   and the `8a` overflow are both on the trust path.
3. **C.** Its whole premise asks colour to carry identity, and at 2.0 it
   hides the host.

All three should adopt one rule: the host is never ellipsized, at any scale.

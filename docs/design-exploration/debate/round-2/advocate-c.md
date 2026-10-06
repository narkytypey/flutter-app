# Round 2 — Advocate for Direction C (Rooms)

The critics are mostly right, and the biggest point comes from the
threat-model critic. Painting the whole browsing chrome in the room colour
makes the workspace readable from across a room. That works against the one
threat this app is built for. So I give up the walled browser and keep the
part of C that does the explaining. **Room colour stays where the owner
chooses a room: the dashboard, `2c` and `6c`'s header. While browsing, the
chrome is neutral, and the states implication 6 asks for are shown by shape
(dashed, double line, flame), never by hue.** Every concession below follows
from that.

Ratios come from `tools/contrast.py`. CVD ΔE is CIEDE2000 under Machado 2009
at full severity, in linear RGB. My script reproduces the accessibility
critic's figures exactly (Ink plum/graphite deut 0.9, Paper lake/plum prot
2.1), so the new figures can be compared with theirs.

## Threat model (critic-threat-model.md)

**T1. Room identity can be read at a distance (C "Weakens" 1). CONCEDE.**
`2b`, `8a`, `8b` and `8c` lose `.sys{background:var(--tint)}`, the tinted
bars and the 3 dp page wall (`screens.html:333–352`). Bars use `page`, the
pill uses `box` with a 2 dp `divider` edge, and the page runs edge to edge.
The pill keeps only colour-free state marks:
- throwaway: a dashed 2 dp `ink3` pill edge;
- Tor: a 2 dp inner `ink` line;
- wipe on exit: the flame beside the route badge.

The room is still one tap away, in `6c`'s header, which is on screen only
while the owner holds the sheet open. This is the critic's own condition (a).

**T2. An empty decoy is a one-colour app (C "Weakens" 2). PARTLY REBUT.** The
sparsity comes from the data, and all three directions show it.
`ensureWorkspace` gives a decoy one Personal workspace
(`app_database.dart:295`), while `seedIfEmpty` gives the real vault three
(`:310`). A and B draw it as one chip against three. Once T1 removes colour
from the browsing chrome, C draws it the same way: one chip and one room
panel, on the dashboard only. The critic's option (b), giving the decoy a
spread of colours at re-sync, would be a data-layer behaviour change, which
is frozen. **Fix:** add a parity line to TOKENS §1.3: "A room's colour comes
from `marker_index` alone. No colour, count or tint is chosen by vault, and
none appears in browsing chrome."

**T3. `10c`'s "Stored data wiped · 3 MB" (shared 2). REBUT, and flag for a
ruling.** It is canvas copy, and the screen is built
(`delete_workspace_sheet.dart:68–70`). C draws what ships. A and B leave the
screen out, which hides the problem without fixing it. Removing the line is
a copy change that only the user can rule on.

**T4. The `2d` caption states parity wrongly (shared 1). CONCEDE.** In
`screens.html:521`, replace the caption with: "Same widgets in both vaults.
The decoy's `2d` is the no-decoy variant, with no VAULT section." This
changes spec text only.

**T5. The black-to-paper flash. CONCEDE.** It is the same in both vaults, so
it is not a tell. It is the price of Paper, and implementation item I1 below
can put that price off.

## Accessibility (critic-accessibility.md)

**A1. Host ellipsized at 2.0 in `2b` and on the throwaway. CONCEDE.** Adopt
the critic's rule that the host is never ellipsized. `.host` loses `.ell`
and wraps by character, as B's does. The route badge and the flame move to a
second line. The pill's minimum height stays 48 dp.

**A2. `1a` overflows 10 px at 320 × 2.0. CONCEDE, but it is minor.** `1a`
was never built (`screens.html:1195`). **Fix:** `t-screen` scales down to
fit on one line (FittedBox), the precedent set by `2a`'s tabs in the
2026-10-05 responsiveness run.

**A3. `1b` name cut to `Not…` at 2.0. CONCEDE.** `.t-row` wraps to at most
two lines and is never ellipsized below that. The open mark and meta go
under the name when the scale is 1.3 or more.

**A4. `2c` cards show the room by colour alone (WCAG 1.4.1). CONCEDE.** Each
card's meta line starts with the workspace name, e.g. "Work · background ·
3 min". The name is data that `2c`'s header already shows, so no new copy is
added, and the same string becomes the card's TalkBack label.

**A5. `2b` shows the room only as tint. RESOLVED by T1.** No room is encoded
in `2b` any more, so nothing depends on colour alone. `6c`'s header already
prints the workspace name next to its swatch.

**A6. Five rooms need a cue other than hue. CONCEDE through A4 and A5.**
Every place a room colour appears now also shows the room's name: chips,
the panel header, the `2c` meta, `6c`, `10a` and `10b`. I do not add five
new glyphs, because the name is a stronger cue and costs nothing.

**A7. Tints collapse under CVD. CONCEDE.** In Paper, re-spacing reaches the
critic's target:

| Paper tint | old | new | ink3 on it | vs page |
|---|---|---|---|---|
| Fern | `#C7E2D1` | `#B4E0C5` | 4.54 | 1.23 |
| Lake | `#CFDDF0` | `#C3D9F7` | 4.59 | 1.22 |
| Plum | `#ECD6E8` | `#EAD3E6` | 4.71 | 1.19 |
| Graphite | `#DADDDE` | `#D7D7D7` | 4.59 | 1.22 |

Ochre stays `#EEDAB0`. The worst pair is now 5.1 (deut, plum/graphite), up
from 2.1.

In Ink, no tint that keeps ink3 at 4.5:1 or more and stays 1.15 to 1.20 from
the page gets past **3.7**. I state that limit rather than hide it. The best
set is Fern `#1C2822`, Lake `#0E2640`, Plum `#401B34`, Graphite `#232528`,
with Ochre unchanged. It raises the worst pair from 0.9 to 3.7, and room
ink still passes on every tint, with a minimum of 9.63. Because of A4 to A6,
a tint is never the only cue, and the walls carry the hue. One wall changes:
Ink Plum's `#D79BCC` becomes **`#D26DB2`** (5.54 on page, 3.93 on box, 4.61
on its tint, and onWall 5.54). The worst Ink wall pair goes from 4.5 to
**6.9**. The Paper walls are already 7.0 or more.

**A8. The focus ring matches the Lake wall. CONCEDE.** `--focus` becomes
`ink` (`#1E1B16` / `#F2EDE3`): a 3 dp ring with a 2 dp gap filled in `page`.
- ink on page: 14.49 / 15.18;
- ink on box: 16.76 / 10.75;
- ink on the lowest tint: 11.78 / 12.64.

Because of the `page` gap, the ring never touches a wall.

**A9. Danger and Ochre are ΔE 3.4 under deuteranopia in Paper. RESOLVED by
T1.** `8b`, `8c` and panic no longer sit inside a room wall. Every danger use
is also labelled (`8b` headline, `Panic`).

**A10. `10c`'s inert Delete. REBUT in part.** The control is truly disabled:
it is inert until the field matches the name (`screens.html:1286`), so WCAG
exempts it. **Fix:** set `Semantics(enabled: false)` so TalkBack says
"disabled".

## Implementation cost (critic-implementation-cost.md)

**I1. The light-theme palette refactor (3–4 agent-days, shared with A).
CONCEDE.** **Fix: ship in phases.** Phase 1 is Ink only, done as a token
*value* swap, the same cheap path B uses: `C.*` stays const. Phase 2 adds
Paper with the context palette. Phase 1 alone delivers C's comprehension
gain.

**I2. The clipped platform view, the only risk a device must check.
CONCEDE.** It goes with T1: no inset, no 18 dp radius, and no narrowed
viewport.

**I3. Marker plumbed through eight chrome widgets. Mostly REMOVED by T1.**
`ContainerScreen`, both bars and the `8a`/`8b`/`8c` bodies no longer take a
marker. What remains is the `6c` header, `WorkspaceChips`, the dashboard
panel and `2c`. `SwitcherEntry` (`lib/domain/models/switcher_entry.dart`)
still gains one `markerIndex`. The name goes into `meta`, which is already a
composed string. I concede that one domain field.

**I4. Retiring jade means rewriting about 10 tests and breaks a CLAUDE.md
global constraint. CONCEDE.** D3 permits *exploring* the break, not
shipping it. The jade rule needs a user ruling before implementation.

**I5. Figtree at 28/30 sp means the most overflow risk. CONCEDE, already
handled.** A2 and A3 are the overflows it caused, and both are fixed above.

Revised estimate: about 12 to 14 agent-days with the phasing, against 15 to
19.

## Familiarity (critic-familiarity.md)

**F1. The door in the pill reads as a padlock. CONCEDE.** The door leaves
the pill. Its slot is gone, and the host starts at the pill's left edge.

**F2. Filled and hollow doors on `1b` read as locked and unlocked. CONCEDE.**
An open site gets an 8 dp `ink` dot before its name, and an idle site gets
no mark. Open sites still sort first (Plan 18). Presence against absence is
not a colour cue. The door survives only in the logo and the unlock motion.

**F3. Every chip is tinted, so every chip looks selected. CONCEDE.**
- Unselected chip: `box` fill, a 2 dp `ink3` outline (5.02:1 or more), and
  a 10 dp room-wall dot before the name.
- Selected chip: `ink` fill, `onInk` label and a check (14.49 / 15.18). This
  is TOKENS §1.4's own selected style.

**F4. `2c` inverts selection. CONCEDE.** No card has a tint fill. Every card
sits on `box` with a 3 dp room-wall leading edge. The viewed card adds a
2 dp `ink` outline, and its meta already reads "viewing now".

**F5. Hatching reads as disabled. CONCEDE.** The hatch is dropped. A
throwaway is the dashed pill edge plus its existing `THROWAWAY` badge and
save bar.

**F6. The framed page. CONCEDE.** Resolved by T1 and I2.

**F7. The flame is unexplained. REBUT.** RESEARCH:74 and implication 12 name
DuckDuckGo's Fire Button as the model for burn actions. Every flame
appears next to the canvas's `WIPES ON EXIT` badge in `2a`, and in `5b` for
a wipe-on-exit workspace.

**Shared items 1 and 6. ACCEPT.** In `6c`, the blocked count and switches
lead, and Proxy and Cookies move down. This is a reorder, and no row
changes. In `8b`, "Open without the tunnel" becomes a text button at least
24 dp below the others.

**Shared items 4 and 5 (panic at top right, `☰`). REBUT for this round.**
Both are Plan 12 layout C, which the user approved. Moving them is a flow
ruling, not a restyle.

## Revised position

C is now "Rooms you choose, chrome that stays quiet". It keeps the original
claim: Dana sees each site in its own box on the dashboard, in `2c` and in
`6c`. What changes is where colour lives:
- colour is never the only cue;
- colour never appears while she browses;
- the throwaway, Tor and wipe-on-exit states stay visible in the pill as
  shapes.

That removes the threat critic's blocker, all four of the accessibility
critic's required fixes, the riskiest build item and three of the
familiarity critic's four misreadings. Two rule breaks remain open: retiring
jade (I4) and the light theme (I1, phased). Both need the user's ruling. If
the ruling keeps jade, C's Phase 1 still stands, with jade as the open dot
in F2.

| Criticism | Concede/Rebut | Fix |
|---|---|---|
| T1 room legible at distance | Concede | Neutral `2b`/`8a`/`8b`/`8c` chrome; room only in `6c` header |
| T2 one-colour decoy | Partly rebut | Data-driven, same as A/B chip count; parity line in TOKENS §1.3 |
| T3 `10c` "3 MB" | Rebut, flag | Canvas copy; needs user ruling |
| T4 `2d` parity caption | Concede | Caption: "decoy's `2d` is the no-decoy variant" |
| T5 launch flash | Concede | Phase Paper later (I1) |
| A1 host cut at 2.0 | Concede | Host never ellipsized; badge to line 2 |
| A2 `1a` overflow | Concede | `t-screen` scale-down-to-fit |
| A3 `1b` name cut | Concede | Row name wraps to 2 lines |
| A4 `2c` colour-only room | Concede | Workspace name in meta and label |
| A5 `2b` tint-only | Resolved | T1 |
| A6 non-hue room cue | Concede | Name wherever colour appears |
| A7 tint ΔE | Concede | Paper tints re-spaced (min 5.1); Ink 0.9→3.7 (limit); Ink plum wall `#D26DB2` (walls min 6.9) |
| A8 focus = Lake | Concede | Focus = `ink`, 3 dp with `page` gap |
| A9 danger/Ochre | Resolved | T1 |
| A10 `10c` inert Delete | Partly rebut | Truly disabled; `Semantics(enabled:false)` |
| I1 palette refactor | Concede | Phase 1 Ink-only const swap; Paper later |
| I2 clipped platform view | Concede | Page edge to edge |
| I3 marker plumbing | Mostly removed | One `SwitcherEntry.markerIndex` field |
| I4 jade-rule tests and rule | Concede | Needs user ruling |
| I5 overflow risk | Concede | A2/A3 fixes |
| F1 door = padlock | Concede | Door removed from pill |
| F2 doors = lock/unlock | Concede | 8 dp ink open dot; idle no mark |
| F3 all chips tinted | Concede | Box chips + wall dot; selected = ink + check |
| F4 `2c` inverted selection | Concede | All cards `box`; viewed = ink outline |
| F5 hatch = disabled | Concede | Hatch dropped |
| F6 framed page | Concede | Edge to edge |
| F7 flame | Rebut | Fire Button (RESEARCH:74); always beside badge |
| Shared `6c` order, `8b` buttons | Accept | Reorder rows; text button ≥ 24 dp below |
| Shared panic and `☰` | Rebut | Plan 12 layout; flow ruling |

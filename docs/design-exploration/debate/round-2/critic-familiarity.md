# Round 2 — Mainstream-familiarity critic

Lens unchanged: a Chrome-on-Android user opens each screen cold. Within ten
seconds, can they say what it is and what to press? Copy is frozen, so
everything here is about setting, order, size and glyphs. Renders are at 390
× 1.0 **with the real web fonts served** (in round 1, Google Fonts could not
be reached, so A and C rendered in a fallback face; see the accessibility
critic's round 2). Button sizes come from the bounding boxes.

## Shared findings: sharpened, narrowed or withdrawn

**1. `6c` opens on `Proxy · SOCKS5 · 127.0.0.1:9050`: narrowed. This is a
canvas question, not a direction question.** The rendered order is the same
in all three: Proxy, Cookies, Security level, Blocked here, then the
switches. But that order is the **canvas's own**. `Sandbox Container
-canvas-.dc.html:604` onward reads Proxy, Cookies, Blocked here, Force dark
mode, Desktop view. Reordering it is a layout deviation from the
authoritative spec and needs a ruling, as sentence case does. It does not
separate A, B and C. I keep it as a recommendation to the user: put
"Blocked here" and the switches first, as Firefox's and DuckDuckGo's shields
do.

**3. `2c` puts panic beside "Close all and wipe": sharpened.** Measured gaps
are **A 12 dp, B 8 dp, C 10 dp**, against implication 12's 24 dp. The
buttons are 52 dp tall in all three, and close-all spans 278–298 dp. A
Chrome user's "close all tabs" is a menu item. Here it is a primary-sized
button, with the power glyph next to it in the same row. All three fail.

**4. Panic at top right: sharpened, and the A advocate's claim does not
survive the render.** The advocate says `N OPEN` "sits where Chrome's tab
square sits" (round 1, §2). On Chrome for Android the tab-count square and ⋮
sit at the **top right** of the toolbar. In all three directions that spot
holds the 48–52 dp panic tile, and `3 open` is at the bottom centre. So the
right thumb's first habitual target is the most destructive control in the
app. A tint stops it being mistaken for a menu glyph, but not for the place
the menu lives. This is still the single biggest grammar fight, and it is
the same in all three.

**6. `8b`'s risky choice is the biggest button: sharpened.** Because "Open
without the tunnel" carries its subline ("This site will see your real IP"),
it renders **taller** than the safe action:

| | Try again | Change proxy settings | Open without the tunnel | gap above it |
|---|---|---|---|---|
| A | 342×52 | 342×52 | **342×68** | 24 dp |
| B | 350×52 | 350×52 | **350×66** | 8 dp |
| C | 328×52 | 328×52 | **328×68** | 10 dp |

Chrome's error pages give one button. Here the riskiest of three
full-width buttons has the most area. A at least separates it by 24 dp. B and
C do not. The fix is the same everywhere: render it as a text button, keep
the subline, and give it a smaller footprint.

**2, 5, 7 (`2c` as a list, `☰` for `⋮`, SOCKS5 first): unchanged.** They are
true of all three and do not separate them.

## Direction A — Daylight

**The box is Material's "archive" glyph: sharpened.** `i-box`
(`direction-a-daylight/screens.html:354`) is a lid rect, a body rect, and a
centred slot `M10 14.5h4`. That is the shape of Material's `archive` /
`inventory_2`, which Gmail and Files users know as "archive". I also missed
this in round 1: the **Sites tab icon** `i-sites` (line 351) is the same lid
and body without the slot. So the first nav item the user meets is
"archive", and the pill's container-type mark is "archive" too. The dashed
variant (`i-box-dashed`, line 355) is a dashed selection rectangle. The A
advocate argues that the mark "teaches the idea" because the user met it in
the launcher. Ten seconds is too short for that lesson. The archive meaning
arrives first.

**Mono meta wraps on half the rows: confirmed with the real font.** In the
`1b` render, 3 of 6 rows wrap at 1.0: "notes.example.org · / socks5",
"forum.example.com · / ephemeral" and "bank.example.com · pin / required".
The orphaned word reads as a second datum.

**The host is cut at 1.0: confirmed.** The `2b` pill shows "forum.exampl…"
beside `SOCKS5` (114 of 145 px). Chrome never gives up the domain. The fix is
B's layout, with the badge under the host.

**What A gets right, and it is the most of the three.** It follows the
system theme. Its `8b` puts the safe action in the only filled spruce button,
and the risky one 24 dp away. The search field "Search or type an address"
sits at the bottom, as in Chrome's own phrasing. The selected chip carries a
check (Material's filter chip).

## Direction B — Instrument

**Colourless "on" switch: largely withdrawn.** The `6c` render shows "on" as
a light, filled track with the knob at the right and a check in it, and
"off" as a dark outlined track with the knob at the left. That is Material
3's switch anatomy, without the hue: fill, knob side and the check all
agree. A Chrome user reads it correctly at a glance. The remaining cost is
small: Android settings screens train "coloured = on", and B gives that up.
The B advocate names this cost honestly.

**The host in mono: stands. The advocate agrees it is "easy to reverse".**
`2b`'s host is Plex Mono 15/500. No mainstream address bar uses mono. A
reversal should be the condition of adopting B, not an option.

**The dashed case around the `Fr` monogram: stands.** It is the only sign of
wipe-on-exit at the pill's start, and a dashed outline on dark reads as
"empty slot". B asks for a word (its copy question 1). A word is the right
answer, and it needs a copy ruling.

**`8b` gap: new.** It is only 8 dp between "Change proxy settings" and the
66 dp danger-outlined button. That is the tightest of the three.

## Direction C — Rooms

**The door as a padlock: narrowed.** `i-door-open`
(`direction-c-rooms/screens.html:286`) is a filled round-topped arch, not a
shackle over a body. Up close it reads as an arch or tombstone, not a lock.
But at 14 dp, black, at the start of the pill where Chrome showed its HTTPS
padlock until 2023, the first guess is still "secure connection". On `1b` the
same arch at each row's end (filled for Notes and Webmail, hollow for the
rest) has no legend. Open versus idle is the one state the dashboard must
show, and it is now the one that needs explaining.

**Chips: narrowed.** The render shows the selected `Personal` as saturated
Fern with white text, and `Work`/`Ephemeral` as pale filled tints. The
selected chip *is* distinguishable. But a pale filled chip is exactly
Material 3's *selected* filter-chip style, so to a Chrome/Android user, two
unselected chips look selected. Outlined unselected chips (as in A) are the
convention.

**The framed page: confirmed.** The page sits inside a 3 dp wall with 8 dp
margins (`.walled`, `screens.html:154`) and tinted bars. On a throwaway it
sits inside a dashed wall on a hatched ground, which is the web's "disabled"
pattern. Chrome's page runs edge to edge. Here it looks like an embedded
preview.

**On the C advocate's ten-second test** ("each site lives in its own box,
and these colours are my boxes"): the render shows the *box* clearly. It
also shows three unlabelled glyph families (door, flame, hatch) that the
test assumes are already learned. C makes the idea visible, but it is not
self-explanatory in ten seconds.

**What C does well.** The solid ink "Try again" and "Save as a site" are the
clearest "press this" of the three. The `6c` header names the room
("forum.example.com · Personal").

## Bottom line (familiarity lens)

1. **A — Daylight. Best.** Blocking issue: **none.** Its worst fault is the
   **box/archive glyph**, used as both the Sites tab icon and the pill's
   container mark (`screens.html:351, 354`), and it is a glyph swap. The
   host cut at 1.0 and the wrapped mono meta are layout fixes.
2. **B — Instrument.** Blocking issue: **none, provided the host leaves
   mono.** It is dark-only against the system setting, and the dashed case
   needs a word.
3. **C — Rooms. Worst.** Blocking issue: **open/idle is shown only by an
   unexplained door glyph** (`screens.html:286–287`), and the chip, hatch and
   page-frame conventions each read as something else to an Android user.

Shared across all three, and needing fixing whichever wins: panic in Chrome's
top-right tab/menu spot; panic 8–12 dp from "Close all and wipe"; and `8b`'s
riskiest button rendered as the largest.

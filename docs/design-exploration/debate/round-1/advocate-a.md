# Round 1 — the case for Direction A (Daylight)

Advocate: A. Reader to win: the bounced mainstream user, someone who arrived
from Chrome (about 17 Android users in 18, RESEARCH §1) or Samsung Internet,
found the current UI cold, cramped and hard to read, and left.

## 1. The bounce was a reading failure first

AUDIT §4 lists eight ways the app fails this user. Five of them are about
legibility and familiarity, not about brand: text too small (§4.1), secondary
text too faint (§4.2), targets too small (§4.3), surfaces you cannot tell
apart (§4.4), and "cold by construction" (§4.7). All three directions fix the
first four, since the brief requires it, and all three pass their four
overflow runs (each A11Y.md reports `no overflow` four times). So the
question is not who fixed the numbers. It is **which direction removes the
most reasons this user had to leave, at the lowest cost in new things to
learn.** Daylight does, because it is the only one that treats "looks like
the browser I already trust" as the goal and spends novelty only where
Container really is new (RESEARCH §4, "Novelty budget", the Dia lesson).

## 2. What Daylight does for that user, screen by screen

- **`2b` is Chrome's grammar at Chrome's sizes.** It has a 56 dp bar, a 48 dp
  `tonal` pill with `r.full` corners, the host at 16 sp (`T.address`), and the
  shield and reload as 48 dp hit areas at the end of the pill (TOKENS §6–7).
  Today the host is 11.5 px and the shield is 28 dp (AUDIT §1.4). Implication
  5 asks for exactly this. The tab counter `N OPEN` sits where Chrome's tab
  square sits. All three gestures the user knows (tap the address, tap the
  shield, tap the tabs) are where their thumb expects them.
- **It follows the system theme.** Every major browser follows the system
  light/dark setting and none is dark-only (RESEARCH §2). Positive polarity
  reads better, especially at small sizes (RESEARCH §5: NN/g, Piepenbrock
  2013). Preference splits roughly into thirds, so a dark-only app goes against
  about two thirds of users' own choice. Daylight ships a real light theme
  *and* a matching dark one, with jade `#7FC8A9` kept as the dark accent, so a
  user who prefers dark loses nothing.
- **It explains things in text you can read.** `ink2` takes over six failing
  or near-failing greys (`textFaint`, `textDim`, `tabInactive`…, AUDIT §2) and
  passes 4.5:1 on every surface. Section labels go from 10 px tracked caps to
  14 sp sentence case (Implication 7). The smallest text in `screens.html` is
  **13 sp**, the largest floor of the three (B and C: 12, per their A11Y.md).
  This user runs about 1.15× (one user in four or five runs larger, RESEARCH
  §5), so that extra point counts at arm's length on a bus.
- **Containment replaces near-black hairlines.** Eleven darks become three
  surfaces per theme, each ≥ 1.15:1 from the next (light card/page 1.17:1,
  dark 1.16:1; TOKENS §1). Rows are 56/72 dp M3 list items in 24 dp-radius
  groups, Chrome's tab-card radius (RESEARCH §2). M3 Expressive's research on
  containment (RESEARCH §5) is the best public evidence against bare hairline
  lists, and Daylight follows it plainly.
- **It is quiet when healthy and clear when not.** A healthy site shows one 8
  dp `accent` dot. `8b`/`8c` get a small `dangerContainer` panel and a named
  action, never a red screen (RESEARCH §6, Tor's removed red screen;
  Implication 12). `onDangerContainer` replaces the failing `dangerMuted`
  (3.89:1 → 7.78:1 light).
- **The mark teaches the idea.** The lidded box is three solid shapes and
  reads at 24 px (Implication 10). Drawn **solid** at the start of the pill it
  means a Keep site. Drawn **dashed** it means wipe-on-exit or a throwaway.
  That answers Implication 6 (the difference must be "visible in the chrome
  itself") with the logo the user already met in the launcher.
- **It is cheaper to ship.** Atkinson Hyperlegible Next + Mono come to about
  190 KB, replacing 333 KB today (TOKENS §2): a saving of about 140 KB. B's
  Plex Sans adds about 246 KB. Atkinson was designed for legibility
  (Braille Institute, RESEARCH §4). Every value (host, proxy, rule count)
  stays monospace, so the expert keeps the trust signal AUDIT §3.4 asks us to
  keep.

## 3. Honest comparison

**B — Instrument** is the best-executed dark design here, and its jade
discipline (taking jade off switches, checks and step bars) is sharper than
A's. But it fixes the reading problem while keeping the thing that made the
user decide "this is for hackers": a dark-only UI. RESEARCH §2 and §7 say the
user has learned that dark means private. A browser that is dark everywhere
signals "incognito" before anything happens, and it is wrong about Keep sites,
which stay signed in. B's own BRIEF admits it "gives up the positive-polarity
reading advantage" and "follow the system" familiarity, and compensates with
weight. Its reader, Lena, already pays for Mullvad. She is the privacy-literate
user, not the bounced one. B also has a colourless "on" switch, a convention
the user has to unlearn on day one.

**C — Rooms** has the most original idea: isolation you can see, rooms by
colour (Firefox containers, Zen; RESEARCH §4). I grant that it answers AUDIT
§4.8 more vividly than A does. But it pays for that by changing three things
this user already relies on, all at once:

1. **It overturns the jade rule.** Colour stops meaning "live", and live state
   moves to a door that is filled or hollow.
2. **It removes amber's "opening" meaning.**
3. **It locks workspace markers into fixed families.**

On top of those changes, the user has to learn a new vocabulary: walls, doors,
hatching, flames and onions. That is four visual channels to decode on the
screen where they spend the most time. RESEARCH §3 records the cost of exactly
this. Brave's extra signals read as a "scam", and Vivaldi's surface is
"overwhelming". C's room colour also lives in the chrome while the page is told
`prefers-color-scheme: dark`. It frames that mismatch with a 3 dp wall that is
one more thing to read. A frames it with an opaque bar, which looks like Chrome
does on the same page.

A takes C's best move in a smaller form. Container type is shown in the pill
by the solid or dashed box, and the route by a UI-face badge (`SOCKS5`, `Tor`,
13 sp, Implication 8). That gives the new idea **one** new sign, not a new
grammar.

## 4. The strongest objection, pre-empted

> "Daylight breaks a global constraint ('dark theme only'), and it can't even
> do it cleanly: the Android theme must stay dark for WebView force-dark
> (`test/android_theme_test.dart`), so pages are told
> `prefers-color-scheme: dark` inside light chrome, and there is a black
> splash before a light lock screen. You've made Container generic, and the
> seams show."

The answer has three parts.

1. **The constraint is a design ruling, not a privacy rule.** The privacy
   rules (two vaults, no leak count, never fall back to direct, danger never a
   fill) are all kept. The theme reads only `MediaQuery.platformBrightness`,
   which is the same whichever vault is open (Implication 15). There is no
   toggle and no new string (BRIEF, "Dark theme only"). RESEARCH Implication
   11 asks for exactly this: "a stated decision with its cost". A states the
   cost, and C, which breaks the same constraint, inherits the same seam.
2. **The seam is the one Chrome users already see.** A site with its own dark
   styles inside light chrome is what happens in Chrome when a site ignores
   the theme. A does not hide it behind a hairline. Its bars are opaque `card`
   tone, and the load line sits on the bar, not the page (BRIEF, "The cost").
   The splash fix (a `values`/`values-night` launch-theme pair) is a small
   phase-7 change, not a reason to keep a dark-only UI.
3. **"Generic" is the point on the surface, not underneath it.** Being
   distinctive through darkness is what the user bounced off (AUDIT §4.7).
   Container's real difference, isolation per site, is still there. It is
   carried by the box mark: in the launcher icon (which is Flutter's default
   today, AUDIT §1.6), on the lock screen, and at the start of every pill. In
   the unlock motion the box's lid lifts, and on reopen-in-place the box
   redraws as it is "re-sealed" (TOKENS §8, Implication 14). Dia's lesson
   (RESEARCH §4) is to keep the browser boring and spend the novelty where the
   product is new. Daylight is the only direction that does that.

The second objection I expect is about **density**: about seven sites per
screen instead of ten. All three directions pay this cost (B and C give the
same figure in their BRIEFs). Scrolling is cheaper than squinting.

## 5. What I would concede

- B's stricter jade budget (no jade on "on" switches is too far, but no jade
  on step bars and tab underlines is right) is worth adopting.
- `6a`'s filled button should follow the canvas (`Keep blocked`), as A's own
  copy question 5 leans and as B argues from RESEARCH §6's opinionated
  defaults (31 % → 58 %).
- A host breaks mid-word at 2.0× (A's copy question 6). It needs a
  break-after-`.` rule in the app, whichever direction wins.

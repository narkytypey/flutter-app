# Round 1 — Advocate for Direction B (Instrument)

## The claim

The bounced user did not leave because Container is dark. They left because
they could not **read it, hit it, or tell its parts apart**. AUDIT §4 lists
eight ways the app fails that user. Five of them are measured legibility
failures: text too small (§4.1), explanations at 4.01:1 (§4.2), 28 dp targets
(§4.3), eleven surfaces you cannot tell apart (§4.4), and jargon set as the
loudest type (§4.5). Instrument fixes all five completely and keeps the three
things AUDIT §3 says the app already does better than Chrome: honest state,
one accent, and technical facts in a technical face. A and C fix the same
five, but they also tear out a working identity and two global constraints to
fix §4.7 ("cold"). That is a matter of temperature, and B fixes it more
cheaply, with warmth.

## What B delivers against the falsifiable list

RESEARCH "What this means for Container" gives 15 checkable implications.
B's numbers against them:

- **#1 sizes.** The smallest text anywhere is 12 sp (badges, tab labels).
  Body is 16/24, row titles 16/500, explanations 15, and the address 15
  (TOKENS "Scale"). Today 43 % of sizes are 12.5 px or under (AUDIT §1.2).
- **#2 targets.** Every tappable thing is at least 48 × 48 dp. That covers the
  pill's shield and reload (28 dp today, AUDIT §1.4), chips (48 tall, 36
  visual), `2c`'s ×, and `10e`'s chip × (A11Y.md item 7). A's smallest *drawn*
  tappable box is 40 dp (A A11Y.md), behind a 48 dp hit area.
- **#3 contrast.** Every pair passes (TOKENS "Measured contrast"). The lowest
  text pair is 4.54:1 and the lowest common one is text-3 on sheet at 5.30:1.
  The off switch goes from 1.26:1 to a 5.76:1 `--edge` outline, and the empty
  PIN dot from 1.79:1 to the same. `textFaint`, the most-used text colour and
  a failure on all four surfaces (AUDIT §2), becomes `--text-3` at 7.30:1 on
  ink.
- **#4 surfaces.** Four tones, each at least 1.16:1 from its neighbour, with
  sheet over ink at 1.38:1 (today it is 1.05:1). Grouped rows sit on
  `--surface-group` with an 18 dp radius. Hairlines drop from nine alphas to
  two plus one solid edge.
- **#5 address bar.** A 64 dp bar holds a 48 dp pill, with 48 dp shield and
  reload targets (BRIEF ref. 3).
- **#7 and #8 labels and mono.** Section labels are sentence case, 14/600, in
  text-2. Plex Mono is only for values: the rule is "a name of a thing is
  Sans, a value you could copy is Mono" (TOKENS). `SOCKS5` becomes a 12 sp
  Sans badge.
- **#9 shield.** The shield shows the security level by fill (outline, half,
  full), never by a number.
- **#10 mark.** The mark is a case with a jade jewel: one physical object that
  reads at 24 px and has a solid-dot monochrome form.
- **#12 danger.** Danger is coral (`#EE8D79`) as text and a 1.5 dp outline.
  `3c` is on the page colour.
- **#13 layouts.** No overflow at 320/1.0, 390/1.3, 390/2.0 or 320/1.3, or in
  the extra 320/2.0 run (A11Y.md).
- **#14 motion.** Motion is spent on two moments only: the lid lifting at
  unlock, and the case redrawing when a protective change applies.
- **#15 decoy.** Nothing depends on which vault is open.

On the A11Y numbers all three directions pass. **Accessibility is not what
separates them.** What separates them is what each one spends to get there.

## Why B is right for the bounced user specifically

**1. It keeps the reason they installed the app.** The user arrived on a
recommendation for a *privacy tool* (RESEARCH §1: overwhelmingly from Chrome).
RESEARCH §4's calm products are not light Chrome clones. They are Tailscale's
warm ink with one rare accent, and Mullvad's dark field with green kept for
connection state. Instrument is that lesson applied: `#121110` ink-brown in
place of the cold green-grey `#0F1113`, warm text tones, and jade only where
something is live. A, by its own account, gives up "distinctiveness by
darkness" and moves all of it into one mark (A BRIEF "Sacrifices"). For a
product whose credibility *is* that it is not Chrome, looking like Chrome is
a real cost. RESEARCH §2 says the user's privacy app "should not look like
nobody's". It should not look like Chrome's either.

**2. Jade becomes a signal the user can learn in one screen.** AUDIT §3.1 and
§3.3 call honest state and a single accent the app's best features. B
tightens the rule instead of breaking it: switches, checks, tabs and step
bars stop being jade (TOKENS "Jade budget"). On `2b` the only green on the
screen is the light that says this page is live. That is RESEARCH §3's "colour
before numbers" (Brave's shield) and §6's "calm when healthy" in one mark. C
overturns the jade rule outright. Colour becomes workspace identity, and
"live" moves to door shapes the user has never seen. That is a new
vocabulary to learn on first contact, which is the opposite of what someone
who has already bounced once needs.

**3. Chrome and page agree.** The Android theme must stay dark because
WebView only force-darkens under it, and every page is told
`prefers-color-scheme: dark` (CLAUDE.md "Full app test", `61f8215`). A and C
both admit that on a light-mode phone a dark-styled page then renders inside
light chrome, and that the `Theme.Black` splash flashes before a paper lock
screen (A BRIEF "The cost"; C BRIEF "Light mode and WebView"). C has to
invent a 3 dp coloured wall to make that seam look intended. Under B, the
screen the user spends the most time on (`2b`, AUDIT §4.1) has no seam at
all.

**4. One theme to build and to keep correct.** AUDIT §5 says the restyle
"cannot be a token swap": sizes, paddings and radii are literals at 50-odd
call sites. Every direction pays that cost. A and C then pay it twice: two
token tables, two sets of contrast pairs (C measured 206), and two themes to
look at on every future screen. B ships one theme and keeps CLAUDE.md's
"dark only", "jade" and "two-vault" constraints, so no ruling is needed
before work can start.

## Honest costs

- **Polarity.** Positive polarity reads better at small sizes (RESEARCH §5),
  and B forgoes it. B pays implication 11's stated price for a dark
  direction: 16 sp body, 500 weights for anything read at a glance, and no
  text tone under 5.30:1 in common use. B also *removes* the small sizes
  where polarity matters most: nothing is under 12 sp.
- **Fonts.** Plex Sans brings the bundled fonts to about 581 KB (+246 KB).
  C stays at 333 KB and A saves about 140 KB. In exchange, UI text and values
  share one skeleton.
- **The host is in Mono.** Implication 5 asks for the host "in the UI face".
  B sets it in Plex Mono 15/500, because implication 8 calls hosts a value and
  AUDIT §3.4 calls mono-for-facts a trust signal. That is a deliberate choice
  between two implications that conflict, and it is easy to reverse.
- **Density and convention.** Rows are 72 dp, so about seven sites fit on
  screen instead of ten. A and C pay the same. B's "on" switch is a
  warm-white track rather than a coloured one, which breaks one convention so
  that green keeps a single meaning.
- **Metaphor (AUDIT §4.8).** C makes isolation more visible than B does. B
  draws it in the pill instead: a solid case for a Keep site, a broken case
  for wipe-on-exit, and a route badge plus icon. That answers implication 6
  without making colour carry it.

## The strongest objection, pre-empted

> "The user called it *cold*, and RESEARCH §2 and §7 say they read dark as
> incognito. A dark-only restyle keeps the misconception and the chill."

There are three answers.

First, *cold* was measured, and the measurement is not about darkness. AUDIT
§4.7 says cold comes from "near-black at `#0F1113`, grey-green text,
hairlines and no surfaces". B changes every item in that sentence: warm ink,
warm greys, four visible surfaces, and grouped containment.

Second, implication 6 is explicitly polarity-neutral: "*whatever a
direction's base polarity*, the difference between a saved Keep site, a
wipe-on-exit site, a throwaway and a Tor route must be visible in the chrome
itself". B's pill does that by shape and by a legible badge. Light chrome
does not cure the incognito misconception. Showing the real distinction
does, and RESEARCH §7's 37 % hold their belief about Chrome's incognito,
which is not a dark product. Signalling privacy by brightness instead is
another polarity signal, not an explanation.

Third, the evidence for warm-dark exists in RESEARCH §4: the products the
research holds up as calm and trustworthy (Mullvad, Tailscale's ink, Signal's
quiet) are dark or ink-led. The user B is built for (Lena, BRIEF) is that
product's audience.

## Verdict asked for

Choose B as the base. If the judges weigh polarity heavily, the cheapest
hedge is B's tokens plus a later light *variant*. That is far smaller than
adopting A's or C's whole reorganisation, and it keeps the jade rule, the
mark and the single theme that today's tests and constraints already assume.

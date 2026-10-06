# Round 1 — Advocate for Direction C (Rooms)

## The claim

The bounced user did not leave only because Container was hard to read. A
and B both fix the reading. Only C fixes the second reason she left: **she
never understood what the app was doing for her.** AUDIT §4.8 says it plainly.
"Every site in its own container" is invisible, and "a site row looks like a
bookmark row". RESEARCH §7 measures what fills that gap. 37 % of people think
private browsing hides them from their employer, and 39 % think it makes them
anonymous (Wu 2018; Habib 2018). RESEARCH §2 explains why the current design
feeds that belief: the user has learned that **dark = private**. A Chrome
user who meets a dark screen of grey lists does what Dana in C's BRIEF did.
She files the app under "another incognito thing" and deletes it.

Making the screens legible is necessary, and all three directions do it. But
legibility only lets her read labels. C is the only direction that also gives
her a picture of the product.

## What C gets right that the others do not

**1. It meets implication 6 head-on.** RESEARCH asks that the difference
between a Keep site, a wipe-on-exit site, a throwaway and a Tor route "be
visible in the chrome itself, not only in a 9.5 px label". The three
directions answer differently:

- A shows it with a small container-type icon at the start of the pill:
  outline box or dashed box (A BRIEF, "What the mark means").
- B shows it with a solid or broken case around the monogram, and asks
  whether it may add a word for it (B BRIEF, copy question 1).
- C gives each state its own channel (C TOKENS §1.4). A saved site sits in a
  3 dp wall in its workspace's colour. A throwaway has no room: its wall is
  dashed and its floor is hatched. A Tor route gets a double wall and the
  onion. Wipe-on-exit gets the flame.

Those channels are hue, frame shape, pattern and icon, and they do not
depend on each other. Each one passes for a colour-blind user without the
others, and each is drawn around the whole page rather than in a 24 dp corner
of the pill.

**2. It uses the evidence about how people tell isolated contexts apart.**
RESEARCH §4 ("Identity per context") and D3 cite Firefox Multi-Account
Containers and Zen. Both answer "which context am I in?" with colour, and
both are products people use for exactly Container's job. Brave's users read
protection from colour before any number (RESEARCH §3). C takes that finding
and points it at the thing that matters here, *which box this site is in*,
not at a decorative accent.

**3. It replaces darkness as the privacy signal instead of just dropping
it.** A and C both follow the system theme, for the reasons in RESEARCH §2
and §5 (polarity, familiarity, preference split in thirds). A then loses
darkness as a signal and leaves the pill icon to carry the meaning. C says
"privacy is walls" (C BRIEF, "Dark-only"), and draws a visible wall around
every page. That speaks directly to the misconception in RESEARCH §7: a
Keep site stays signed in, and it says so by being a furnished room rather
than a black void.

**4. It turns the WebView cost into structure.** All three directions keep
the Android theme dark (`test/android_theme_test.dart`), so pages are told
`prefers-color-scheme: dark`. In A, a dark page inside light chrome is a
mismatch that A calls "honest" (A BRIEF, "The cost"). In C the page is inset
inside its room wall, so a dark page reads as "the site, inside its room"
(C BRIEF, "Light mode and WebView"). It is the same constraint with a
better-looking result.

**5. The vocabulary repeats from the launcher to the switcher.** The logo is
a room with a door (C BRIEF, "What the logo means"). The filled or hollow
door is the open or idle mark on every site box (TOKENS §1.4). The door
swinging open is the unlock motion (TOKENS §3, motion 1). The wall redrawing
itself is the "protective change took effect" motion (motion 2). That is
implication 14's two moments, and each one tells the user what just happened
to her box. RESEARCH §4's "novelty budget" (Dia) says to spend expression only
on what is new. C spends it on isolation and on nothing else.

## It clears the measurable bar as well

C is not trading legibility for concept. From C A11Y and TOKENS:

- The smallest text is 12 sp: only bold badges, each on a pairing of at
  least 4.5:1. Body is 16 sp, the address is 16 sp (`T.address`), and
  section labels are 15 sp sentence case. That meets implications 1, 5 and 7.
- `ink3`, the faintest tone, is at least 4.57:1 everywhere. It replaces
  `textFaint`, which failed at 4.01:1 (AUDIT §2).
- 206 of 206 measured pairs pass.
- The off switch, the empty PIN dot and the idle door all use the 2 dp `ink3`
  outline at 5.02–6.45:1. Today the off switch is 1.26:1 and the idle dot
  1.95:1 (AUDIT §2).
- Every target is at least 48 × 48, including the pill's shield and reload,
  which are 28 dp today (implication 2).
- There is no overflow at 320 × 1.0, 1.3 or 2.0, or at 390 × 1.3 or 2.0
  (implication 13).
- No new font: 333 KB, against B's +100–250 KB for Plex Sans.

## Honest comparison

**A (Daylight)** is the safest bet for familiarity. Its Chrome grammar is the
right grammar, and C uses the same pill and target sizes. But A's single new
idea is a small icon at the start of the pill, and A sacrifices
"distinctiveness by darkness" without putting much in its place (A BRIEF,
sacrifices). Priya will recognise A in 30 seconds. I am not convinced she
will be able to say what makes it different from Chrome with a shield.

**B (Instrument)** is the best execution of the current identity. It keeps
the jade rule and the dark-only constraint, and its "saved / wiped /
throwaway" readout in the pill is a real idea. But B's persona, Lena, already
pays for Mullvad and Proton. She is the user who *stayed*, not the one who
bounced. RESEARCH §1 says the bounced user came from Chrome 17 times in 18,
and RESEARCH §5 says dark-only gives up the polarity advantage. B accepts
that cost knowingly (B BRIEF, sacrifices). It is the right direction for a
different user than the one this exploration is for.

**Where C is weaker, stated plainly:**

- Density: rows are 76 dp, so about 7 sites fit above the fold instead of 10.
  A and B have the same cost.
- It breaks more written rules than either rival: dark-only, the jade rule,
  and hairlines-not-cards.
- Two surface steps fall short of the 1.15 target: sheet on page in Paper is
  1.11, and sunken on page in Ink is 1.12 (TOKENS §1.1). The sheet relies on
  its scrim and shadow, and sunken needs a fix.
- The splash flashes black in light mode, as it does in A.

## The strongest objection, pre-empted

> "Colour-as-identity is decoration in disguise. Most users have one
> workspace, so every room is Fern and the colour says nothing. Meanwhile C
> spends the jade rule, the one honest state signal AUDIT §3.1 praises, and
> 'live' becomes a door glyph nobody will learn."

Four answers.

1. **With one workspace, the room still carries meaning, because what it
   contrasts with is "not a room".** A dashboard throwaway has no room, so it
   is dashed and hatched. A Tor site has two walls. A wipe-on-exit site has
   a flame. Those are the four states implication 6 asks for, and none of
   them needs a second hue. Colour is the fifth channel and starts paying
   once a second workspace exists. That is also the user Firefox containers
   and Zen are built for.
2. **AUDIT §3.1 praises honest state, not jade.** C keeps the honesty and
   moves it to channels that work better. Jade versus grey failed for
   colour-blind users (the idle dot was 1.95:1). The filled versus hollow
   door is 16.76 and 6.45:1 on box. Open sites still sort first, as Plan 18
   already does. The "one affirmative action per screen" half of the rule
   survives as the single solid ink pill, and you can find it without seeing
   any hue (C BRIEF, rule 3).
3. **The colour cannot spread into decoration, because its placement is
   fixed by a rule.** TOKENS §1.3 lists every place a room colour may appear
   and forbids it on buttons, switches, checks, counts and page content. That
   rule can be tested, just as `no_glyphs_test.dart` tests glyphs today.
4. **The decoy stays safe.** The colour comes from the workspace's own
   marker, which both vaults store (implication 15). The theme follows the
   system, not the vault.

The rule-breaking is the point. The current rules produced an app that, by
AUDIT §4.7, is "cold by construction" and reads as for experts. A
restyle that honours every one of them is B. A restyle aimed at the person
who left has to argue its way past at least dark-only and hairlines, as A
also does. C goes one rule further, and that extra rule buys the one thing
neither rival delivers: Dana can say "each site lives in its own box, and
these colours are my boxes" after ten seconds.

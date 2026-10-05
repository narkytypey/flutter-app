# Direction A — Daylight

## Thesis

Container should look like the browser its user already trusts, and keep its
difference for the places where the difference is real. Daylight follows the
phone's light/dark setting (a real light theme is the hero; a matching dark
theme ships beside it), uses Chrome's grammar and sizes — a 56 dp top bar
holding a 48 dp address pill, the host at 16 sp, 48 dp targets everywhere,
16 sp body, Material 3's 56/72 dp list rows — and groups rows on rounded
tonal surfaces instead of hairlines. The privacy machinery is all still there
(route, container type, shield, panic, PIN), but it is quiet while healthy and
only becomes loud — clearly, never frighteningly — when something is
abnormal. One calm green ("spruce") means *live* or *the one thing to do
here*, never decoration.

## Who it is for

**Priya, 34, Pixel 8, Chrome for nine years.** A friend told her Container is
"more private". She installed it, met a black screen of 10 px grey caps and
monospace, decided it was a tool for hackers, and uninstalled it inside 30
seconds. She never reads a settings explanation she can't read at arm's
length on a bus. She knows exactly three browser gestures: tap the address,
tap the shield, tap the tab counter. Daylight is built so that in her first
30 seconds she recognises all three, reads every line at her normal text
size (she runs 1.15×), and sees one plain thing that is new: *each site sits
in its own box*.

Secondary reader, kept: the existing expert user. Every fact they rely on
(host, route, proxy address, rule counts) is still shown, in a monospace face
— but as a *value*, never as a label.

## References (from RESEARCH.md) and exactly what is taken

1. **Chrome for Android** (RESEARCH §2) — the toolbar geometry: 56 dp bar,
   pill with a 24 dp-corner capsule (we go 48 dp tall rather than Chrome's
   40 dp, because the pill also carries the route badge and two in-pill
   targets), 24 dp icons, 48 dp touch targets, and the tab-counter idiom
   (`N OPEN` sits where Chrome's tab square sits, at the bottom bar). Also:
   **follow the system light/dark setting by default**.
2. **Material 3 / M3 Expressive** (RESEARCH §5) — the type roles (Body Large
   16/24, Title Large 22/28, Label 13+), list items 56/72 dp, the shape
   scale (8/12/16/24/28/full), *containment* (rows grouped on rounded
   surfaces, which Google measured as finding key elements faster), and the
   effects spring (damping 1.0, never bounces).
3. **Firefox / DuckDuckGo shield-in-the-address-bar** (RESEARCH §2–3) — one
   icon at the end of the pill that opens one panel (`6c`); its *colour*
   states protection before any number (Brave's finding), and the blocked
   tally stays a secondary line, never a score (DuckDuckGo retired its grade).
4. **1Password's brand refresh** (RESEARCH §4) — a desaturated, "tactile"
   accent rather than a neon one, and a mark built on one physical object
   (their keyhole; our lidded box) that survives 16–24 px.
5. **Chrome's "secure by default, mark the insecure" / Signal's absence as a
   trust signal** (RESEARCH §6) — healthy states are drawn quietly (a small
   green dot, no chatter); abnormal states (`8b`, `8c`, `4c`) get a tinted
   panel, a named action, and nothing else.

## What it deliberately sacrifices

- **The "instrument panel" self-image.** The current app reads as built for
  experts; Daylight gives that up on purpose. Experts lose the dense
  60 dp rows and the all-caps technical labels; they keep every value.
- **Density.** 72 dp rows and 16 sp body mean the dashboard shows about seven
  sites on a 390×844 phone instead of ten. Scrolling is cheaper than
  squinting.
- **Hairlines-only structure** (a CLAUDE.md global constraint). Daylight
  replaces it with containment: white groups on a grey-green page (light),
  lifted tonal groups on near-black (dark). Hairlines survive only *inside* a
  group, as decorative separators.
- **"Dark theme only"** (a CLAUDE.md global constraint) — argued below.
- **Distinctiveness by darkness.** Container no longer looks unusual at a
  glance. Its distinctiveness moves to one place: the box mark, which appears
  in the launcher icon, the lock screen and — as the container-type icon — at
  the start of every address pill.

## What the mark means

A **lidded box**: a solid rounded body with a separate lid resting on top and
a handle slot cut through the body. It is the one physical object the product
is about — *each site is kept in its own box, and the lid is shut* — and it
reads by silhouette at 24 px because it is three solid shapes, not strokes.
The same box drawn as an outline appears at the start of the address pill
for a saved site that keeps its storage; drawn **dashed** it marks a
container that will not keep anything (a wipe-on-exit site or a throwaway).
So the logo is also the first piece of UI that teaches the idea.

## Global constraints this direction touches

### Dark theme only → follow the system (broken, argued)

CLAUDE.md says "Android only, dark theme only. No light theme, no toggle."
Daylight keeps "no toggle" and breaks "dark only". The argument:

1. **Legibility.** Positive polarity (dark text on light) reads better for
   people with normal vision, and the advantage grows as text gets smaller
   (NN/g; Piepenbrock et al. 2013, RESEARCH §5). This app's most important
   text is its smallest — the explanations under each setting. Preference
   itself splits about into thirds (light / dark / follow-system, NN/g 2023),
   so a dark-only app is wrong for two thirds of its users by their own
   choice.
2. **Familiarity.** Every major browser follows the system setting by
   default; none is dark-only (RESEARCH §2). Priya's phone is light during the
   day. An app that ignores that setting is the first thing that feels
   foreign.
3. **The "dark = private" signal is spent.** Users have learned that a
   browser goes dark when it is in private mode (Chrome's incognito, Safari's
   private bar). An app that is dark *everywhere* spends that signal before the
   user does anything, and teaches the wrong lesson: that everything is
   incognito — when Keep sites in fact stay signed in (RESEARCH §7). Daylight
   stops using darkness as a privacy signal and shows the real distinctions
   instead (container-type icon and route badge in the pill, Implication 6).
4. **No toggle, no copy.** The app reads `MediaQuery.platformBrightness` and
   nothing else. There is no setting and no new string. Light and dark are
   the same layout, same tokens by role, same single accent.

**Privacy model check:** the theme depends only on the system setting, which
is identical whichever vault is open. Nothing about the theme can reveal a
second vault.

### The cost: WebView pages and `prefers-color-scheme`

The Android theme (`android/app/src/main/res/values/styles.xml`) must stay
dark — `test/android_theme_test.dart` guards it — because WebView only
honours Force dark mode under a dark theme, and every page's WebView is made
on the application's context. Daylight does **not** touch it. The Flutter UI
can be light without changing the Android theme, but every page will still be
told `prefers-color-scheme: dark`, so on a phone in light mode a site with
its own dark styles will render dark inside light chrome.

How Daylight lives with that:

- The chrome is built to look right around **either** kind of page: the top
  and bottom bars are opaque, separated from the page by their own surface
  tone (not by a hairline that vanishes against a dark page), and the load
  line sits on the bar, not the page.
- It is honest rather than hidden: the mismatch is the same thing Chrome users
  see when a site ignores their theme. It does not misrepresent anything about
  privacy.
- The Android launch theme (`Theme.Black` splash) is unchanged too, so a light
  phone gets a brief dark splash before the light UI. Recorded as a known
  cost; the fix would be a `values-night` / `values` launch theme pair, which
  changes Android resources and is out of scope for this exploration.

### The jade rule → kept, with a calmer green

"Jade `#7FC8A9` means live state or the single affirmative action on a screen
— never decorative, never more than one per screen." Daylight keeps the rule
and the hue family:

- **Dark theme:** the accent *is* jade `#7FC8A9` (9.48:1 on the page).
- **Light theme:** jade cannot be text or a fill-with-white-label on white
  (it is 1.9:1), so the light accent is **spruce `#1D6B57`**, the same hue
  taken to a depth that holds 6.38:1 on white.

Why green and not Chrome's blue: blue already means "link" inside a browser,
and Chrome is blue; a privacy app that copies Chrome's colour would read as
an imitation. Green is the colour Mullvad reserves for "connected" (RESEARCH
§4) — the exact meaning the accent has here (live, working, safe to
proceed) — and it is continuous with the existing jade, so the brand does
not reset. It is desaturated (1Password's "tactile" lesson) so it reads as
calm rather than as a success toast.

How the rule is applied, so it is checkable: **one accent-filled action per
screen at most**; live state is shown by a *small* accent mark (an 8 dp dot,
a 3 dp bar segment, a checked switch), never by tinting a whole row or card.
Switches that are on are accent (they are state, not decoration); the canvas
and the current app already do this.

### Hairlines, not cards → replaced by containment

Argued above under sacrifices. RESEARCH Implication 4 asks for at most four
surface tones, each ≥ 1.15:1 from its neighbour; Daylight uses three per theme
plus the accent container (measured in TOKENS.md).

### Everything else is kept

Two-vault model (nothing vault-dependent), no leak count anywhere, the
blocked tally stays a quiet secondary line, danger is never a full-screen
fill (it is text, an outline, or a small tinted panel), IBM-Plex-Mono's job
(values, not labels) is taken over by Atkinson Hyperlegible Mono.

## Copy questions

All copy is verbatim from the inventory; only case and setting change (via
CSS, so the stored strings are untouched). Questions found while drawing:

1. **Section labels in capitals** (`LOCK`, `BY SITE`, `HARDWARE · ALL OFF BY
   DEFAULT`, `FILTER LISTS`…) are set in sentence case with
   `text-transform`. That works for every label except ones with an acronym
   after the first word — none exist today, but `HARDWARE · ALL OFF BY
   DEFAULT` becomes "Hardware · all off by default", which reads well. No
   question, just recorded.
2. **`N OPEN SESSIONS`** (`2c`) is always plural ("1 OPEN SESSIONS"). Set in
   sentence case it reads "3 open sessions" — fine at n > 1, and the
   singular bug is an existing copy issue, not this direction's.
3. **Route labels** `SOCKS5` / `HTTP` keep their capitals (they are
   acronyms); `Tor` stays as written. The `<n> BLOCKED` and `STANDARD` meta
   in ☰ are set lowercase-with-capital ("312 blocked", "Standard").
4. **1a and 1c** were never built; their mocks use the canvas's strings
   (`Personal ▼`, `PROXY`/`TEMP`/`LOCK`, `Open · now`, `Add site`, `LIVE`,
   `SAVED`, `WORKSPACE`, `page preview`) and are labelled as canvas mocks.

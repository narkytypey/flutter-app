# Direction B — Instrument

## Thesis

Container already looks like a tool for people who care: dark, exact, with
hosts and proxy addresses set in a technical face and one green that means
"live". The person who bounced did not bounce because it looked technical;
they bounced because they could not *read* it — 10.5 px meta, a 9.5 px route
label, an 11.5 px host, a switch that is 1.26:1 off, eleven blacks you
cannot tell apart. **Instrument keeps the self-image and executes it the way
a good watch is made**: a warm near-black case, four surface tones you can
actually see, IBM Plex Sans at mainstream sizes for every word and IBM Plex
Mono only for the values those words describe, every text tone at or above
4.5:1, every mark that carries meaning at or above 3:1, 48 dp targets
everywhere. Jade stays the one live colour and becomes *more* meaningful by
being taken off everything that is not live (switches, checks, tab
underlines, step bars). And the browser chrome becomes a real readout: the
pill tells you, by shape and by a legible label, what case this page is in
— saved and kept, saved and wiped on exit, or a throwaway — and which road
it is travelling — direct, through a proxy, or through Tor.

## Who it is for

**Lena, 34, a clinic administrator in Rotterdam.** She pays for Mullvad VPN
and uses Proton Mail. She does not know what SOCKS5 is and does not want a
lesson; she wants to *feel* she has moved to a serious privacy tool, the way
the Mullvad app makes her feel — dark, calm, exact, a green light when it is
working. She came from Chrome on a Pixel, runs her phone at the default font
size (her mother runs it at 1.3), and reads her phone on the tram in
daylight. She installed Container on a colleague's recommendation, opened a
site, could not read the address or tell what the grey "SOCKS5" next to it
meant, could not see whether a switch was off, and went back to Chrome.
Instrument is built to keep her: nothing she reads is smaller than 12 sp,
the address is 15 sp, and the one thing she needs to know about each page —
*is this saved, does it vanish, which road does it take* — is drawn in the
chrome where she is already looking.

The person already using Container (the expert who set up a SOCKS5 proxy)
loses nothing: every value they check is still in Plex Mono, still exact,
now larger.

## References (from RESEARCH.md) and exactly what is taken

1. **Tailscale** (RESEARCH §4; note 03 §6). Taken: the *ink* logic — a warm
   near-black (`#121110`, ink-brown, not the cold `#0F1113` green-grey) and
   warm greys instead of neutral ones; one accent used rarely; a 4/8/12/16/
   24/32 spacing scale; type weights that do the hierarchy (Plex Sans 400/
   500/600) instead of size jumps and tracking. Not taken: their light
   canvas.
2. **Mullvad VPN** (RESEARCH §4; note 03 §4). Taken: a dark field with the
   green **reserved strictly for connection state**. Instrument applies it
   harder than the current app: an "on" switch is not jade (it is a
   position, not a live state), a picked option's check is not jade, the
   active tab's underline is not jade, the setup step bar is not jade. What
   is left jade is only what is live (an open site, the page you are on
   right now) or the one affirmative action of a screen. Mullvad's
   restraint is the brand.
3. **Chrome's own dimensions** (RESEARCH §2, Chromium `dimens.xml`). Taken:
   the address bar's grammar and size — a 64 dp bar holding a 48 dp pill,
   20+ dp corners, 48 dp targets, 24 dp icons — so the instrument is
   operated with the hands Lena already has from Chrome. The shield sits in
   the pill where Firefox, Brave and DuckDuckGo put theirs (RESEARCH §2),
   now a 48 dp target instead of 28 dp.
4. **Signal** (RESEARCH §6; note 03 §5). Taken: *absence as a trust signal*
   and "calm when healthy, loud only when abnormal". The chrome of a saved,
   direct, kept site is almost silent — a solid case and a green light. The
   readout gains words only when something is different (a proxy, Tor, a
   throwaway), and danger shows only when something is wrong, as text and
   an outline, never a fill.
5. **1Password's keyhole** (RESEARCH §4; note 03 §7). Taken: the mark is
   *one physical object* that survives 16 px — here, a case — and the hero
   colour is used once in it, small. Not taken: the burst animation (motion
   is spent on two moments only; see TOKENS.md "Motion").

## What it deliberately sacrifices

- **Light mode.** Instrument is dark-only. It gives up the positive-polarity
  reading advantage (RESEARCH §5, NN/g; Piepenbrock 2013) and the
  "follow the system" familiarity every major browser has (RESEARCH §2). It
  compensates with what the research says a dark UI needs: 16 sp body,
  medium (500) weights for anything read at a glance, warm text tones that
  do not halate the way pure white on pure black does, and no text tone
  under 4.5:1 on any surface it can land on.
- **Per-site or per-workspace colour identity.** That is direction C's
  answer. Instrument tells contexts apart by *shape* (solid vs. broken case,
  monogram vs. globe) and by *labels*, not by hue, so jade keeps its single
  meaning. Workspace markers stay as data in `10a`/`10b` only.
- **Density.** Rows are 72 dp (two lines) instead of ~60, settings rows 56+
  dp, so the dashboard shows about seven sites at 390 × 844 instead of
  about ten. Bigger type costs rows; Instrument pays it.
- **Mono as decoration.** Plex Mono leaves every label (`SOCKS5`, `N OPEN`,
  section headings, badges). It stays only on values: hosts, proxy
  addresses, counts, PIN digits, code.
- **Bytes.** Figtree (61 KB) is retired; IBM Plex Sans arrives as three
  static weights. Measured: full static cuts are 205 KB each (615 KB for
  three); subset to Latin-1 + punctuation they are 53 KB each (**159 KB for
  three**); Latin + Latin Extended + Vietnamese is 103 KB each (309 KB). The
  recommended Latin + Latin-Ext subset brings the app's bundled fonts from
  335 KB to ~581 KB (+246 KB) — or ~436 KB with the Latin-1 subset. Page
  titles in other scripts (`2c`'s page rows, `6b`'s article) fall back to
  the system font, as they do today with Figtree. See TOKENS.md "Type".
- **Jade switches.** People expect a coloured "on". Instrument's on switch
  is a warm-white track with an ink knob and a check in it: 15.7:1 against
  the page, unmistakable, and colourless. The cost is one convention; the
  gain is that jade on any screen now means only one thing.

## What the logo means

**The case.** A rounded, slightly cushioned square — a watch case, a
shipping container's end, a jewellery box — with its lid seam drawn across
the top, holding one solid round "jewel" with clear air on every side. The
air is the isolation: the thing inside touches nothing. The jewel is the one
use of jade in the mark, and the same green dot is the live light in the
browser chrome, so the icon and the app speak one sign. At 24 px the mark
reads as "a box with something in it"; in monochrome (Android 13 themed
icons) the jewel is simply a solid dot. It is one physical object, not
concentric strokes (RESEARCH implication 10; Zen's lesson).

## Global constraints this direction touches

- **Dark only — kept.** Instrument is the dark-only direction and argues for
  it above. No light theme, no toggle.
- **Jade = live state or the single affirmative action, never decorative,
  at most one per screen — kept, and tightened.** Read precisely, "one" is
  *one jade role per screen*: either the live indicators (every open site's
  light on `1b` is the same signal repeated, as the current app's rails
  are) or the single affirmative action (`Save`, `Continue`, `Try again`,
  `Discard`), never both kinds on one screen. Where the current app spends
  jade on positions (switch on, chosen check, active tab, step bar, the
  `N OPEN` chevron, the `2c` header count, panic's status words), Instrument
  takes it off. Screen-by-screen jade use is listed in TOKENS.md "Jade
  budget". Why this is a strength: on `2b`, the only green on the whole
  screen is the light that says this page is live — the one fact you want
  to read at a glance — so it is read at a glance.
- **Hairlines, not cards — bent, with an argument.** Hairlines stay the
  structural element inside a group, but rows that belong together sit on
  one grouped surface (`--surface-group`, 16 dp radius), because the
  research's containment evidence (M3 Expressive, RESEARCH §5) and the
  audit's finding that eleven darks and nine hairline alphas made layouts
  vanish (AUDIT §1.1, §2) both say a list of loose hairlines on near-black
  does not read. Three line treatments only: `--line-soft` (8 %), `--line`
  (14 %), and the solid `--edge` (≥ 3:1) for anything a user must see.
- **IBM Plex Mono for anything technical, Figtree for everything else —
  changed.** Figtree is replaced by IBM Plex Sans (the brief for this
  direction), so UI and values share one family's skeleton and the mono
  reads as the same instrument's readout. Mono is narrowed to *values*.
- **Danger is never a full-screen fill — kept.** Danger is coral text, a
  1.5 dp coral outline, or a small `--danger-wash` panel (`8c`'s banner).
  Panic (`3c`) is on the page colour, not a red screen.
- **No leak count; the blocked tally is not a score — kept.** Today (`5c`)
  shows the tally as plain mono numbers and monochrome bars, no colour
  ramp, no grade. The shield's state is drawn by *level* (outline / half /
  full for Standard / Safer / Safest), never by a number.
- **Two-vault model — kept.** Nothing depends on which vault is open: no
  per-vault tone, mark or icon. `3b` is `1b` with the decoy's data.

## Light mode and WebView

The Android theme stays dark (`values/styles.xml`, guarded by
`test/android_theme_test.dart`) because WebView only force-darkens pages
under a dark theme, and pages are told `prefers-color-scheme: dark`.
Instrument is dark everywhere, so the chrome and the page agree: a
force-darkened page sits in a warm near-black frame, and a page with its own
dark styles (Plan "Full app test", `61f8215`) looks native. The only
mismatch is a page that ignores dark mode and stays light — then the
warm-black chrome frames a white page, which is how Chrome's dark theme
looks on the same page, so it reads as normal. Reader (`6b`) keeps its own
warmer paper-dark (`--reader-*`), still dark.

## Decisions taken within the frozen rules

- **`6a`'s jade goes on `Keep blocked`, as the canvas draws it**, not on
  `Allow once` as the code does. The inventory records the code's choice as
  an unreconciled deviation, `CLAUDE.md` makes the canvas authoritative,
  and the research (RESEARCH §6, opinionated defaults: 31 % → 58 %) says the
  safe choice should be the visually dominant one. Only the styling moves;
  order and copy are unchanged. (Recorded as a copy/design question below
  in case the orchestrator rules D2 overrides it.)
- **Letter case.** Section labels and short all-caps strings are set in
  sentence case with CSS (`.sc`: lowercase + capital first letter), so the
  HTML text node stays the inventory's string. **Strings that contain a
  protocol or format name** (`SOCKS5`, `HTTP`, `TOR`, `PDF`, `CSS`, `JS`)
  keep their capitals — lower-casing `SOCKS5` would misstate it — and are
  set as a 12–13 sp badge in Plex Sans Medium with no tracking (`.badge`).
- **8b/8c header icons** stay inert as the canvas and Plan 17 draw them;
  Instrument draws them in the inert style (text-3, no target outline) so
  they do not look tappable.

## Copy questions

1. **Keep vs. wipe-on-exit in the `2b` chrome.** The pill has no string for
   a site's storage rule. Instrument draws it as *shape only* (a solid case
   vs. a broken, dashed case around the monogram) and leaves a throwaway's
   words to its existing save bar (`Not saved · wiped when you close it`).
   May the pill's second line reuse `6c`'s existing value strings
   (`Keep for this site` / `Wipe on exit`) beside the route label? Until
   ruled, the mockups show shape only.
2. **`2b` direct route.** There is never a `DIRECT` label (inventory). The
   readout shows a direct route by its icon alone (a straight arrow) and no
   word. Is the existing `Direct` (from `6c`'s Proxy value and Settings'
   Default route) allowed in the pill? Mockups: icon only.
3. **`6a` jade placement** (see above): canvas (`Keep blocked`) or code
   (`Allow once`)? Mockups follow the canvas.
4. **`2c`'s `1 OPEN SESSIONS`** is always plural in code; unchanged here.

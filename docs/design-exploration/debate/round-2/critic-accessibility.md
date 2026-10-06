# Round 2 — Accessibility critic

Lens unchanged: can someone with low vision, a large font scale, a colour
vision deficiency, or TalkBack/Switch Access use it, and does the
direction's A11Y.md tell the truth?

## Method note (it changes how anyone should read the overflow runs)

`tools/shot.mjs` loads each direction's fonts from Google Fonts
(`screens.html:9` in A and B, `:8` in C). In this sandbox Chromium cannot
reach Google Fonts, and `document.fonts` comes back **empty**, so A and C
render in a fallback face. B does not, because IBM Plex Sans/Mono are
installed in `/root/.local/share/fonts/`. That asymmetry produces false
results. A font-less run reports C failing at the *required* 390 × 2.0
(`1a "Personal" spills 2px`) and A's `3c` spilling ("DESTROYED" by 20px).
Both disappear once the real fonts are served. For this round I wrapped
`shot.mjs` with a Playwright route that serves the real Google Fonts CSS and
woff2 files fetched with curl. The log confirms "Atkinson Hyperlegible
Next", "IBM Plex Sans" and "Figtree" loaded. Every number below comes from
that run. The contrast figures come from `tools/contrast.py`. The CVD
figures are Machado 2009 at full severity plus CIEDE2000, recomputed
independently, and they match round 1 to one decimal place.

| run | A | B | C |
|---|---|---|---|
| 320×1.0, 390×1.3, 390×2.0, 320×1.3 (required) | no overflow | no overflow | no overflow |
| 320×2.0 (light and dark) | **8a spills 22px**: "Connecting through 127.0.0.1:9050" | no overflow | **1a spills 10px**: "Personal" |

All three pass the four required runs. A11Y.md for A (line 21) and C (line
22) both claim the extra 320 × 2.0 run is clean, and **neither is**. B's
claim holds.

## Direction A — Daylight

**Host cut: sharpened, and worse than I said.** In round 1 I reported the
host cut at 2.0. A probe for ellipsized elements (`text-overflow: ellipsis`
with scrollWidth > clientWidth) finds the `2b` host `.host.ell` cut **at the
default 390 × 1.0**: 114 px shown of 145 px needed, rendering
"forum.exampl…" beside `SOCKS5`, the reload and the jade shield (I took a
screenshot to confirm it). The same cut appears in `2c`, `6c` and `7c` at
1.0. At 320 × 2.0 the host is cut in `2b`, `2c`, `6a`, `6c`, `7c`, `8a`,
`8b` and `8c`, with 212 of 289 px shown. A11Y.md says the pill wraps "with
the host whole". At 1.0 it does not. The cut falls at the **end** of the
host, which hides the registrable domain: `forum.example.com.evil.io`
and `forum.example.com` would render identically. The advocate's case rests
on "Chrome's grammar at Chrome's sizes" (round 1, §2), but Chrome elides
from the left and keeps the domain visible. **This is A's blocking issue.**

**`8a` at 320 × 2.0: sharpened.** The line "Connecting through
127.0.0.1:9050" spills 22 px past the phone frame in both themes, and the
mono span carrying the address spills with it. This is the line that names
the route the user is about to trust.

**Selected nav tab: stands.** `.nav.on .ind { background: var(--tonal) }`
(`screens.html:289`). `#D9DED6` on card `#FFFFFF` measures 1.37:1, and in
dark `#2B302D` on `#1E2220` measures 1.20:1. The label goes from ink2
`#4A514C` to ink `#1A1D1B`, and nothing else changes: the icon is not filled
and there is no `aria-current`.

**CVD: stands, and it is narrow.** `m0` `#1D6B57` against `m4` `#5E6661` is
ΔE 2.9 under deuteranopia. That matters only in `10a`/`10b` (markers are 12
dp dots there, each with a name beside it), so it is a fix rather than a
block. Danger against warning is ΔE 2.1 (deut) and stays latent while every
warning carries a label.

**The advocate's "13 sp floor": confirmed.** It is the highest floor of the
three, and it is a real advantage.

## Direction B — Instrument

**Selected chip: stands, with no change since round 1.**
`.chip.on > span { background: var(--surface-raised) }` (`screens.html:178`).
`#403C37` on `#121110` measures 1.72:1, and there is no check glyph at
lines 442, 525, 1031 or 1224. Failing case: on `2a`, at outdoor brightness,
a low-vision user cannot tell whether the site will be saved into
"Personal" or "Work". The text-weight change (500 to 600) is the only other
cue. A 3:1 outline or a check would fix it.

**12 sp tab labels: stands, and it is minor.** `--fs-caption: calc(12px *
var(--scale))` is commented "the floor: badges, tab labels"
(`tokens.css:61`). It passes contrast and scales with the font size.

**Large text: confirmed best.** It is the only direction with no overflow
at 320 × 2.0 and **no host ellipsized at any size**. At 2.0 the pill
grows to four lines ("forum / .exam / ple.c / om") and keeps every
character. Its ellipsis probe hits only names and titles
("Marketplace", "New workspace"), which have other identifiers nearby.

**The advocate says "accessibility is not what separates them". I partly
reject this.** A ellipsizes the host at 1.0, and C ellipsizes it at 2.0
from 390 × 1.3 on. B keeps the host whole everywhere. On the trust-critical
string, accessibility does separate them.

## Direction C — Rooms

**Host cut: sharpened, and it starts below 2.0.** At 390 × 1.0, C
ellipsizes nothing, which is better than A. But at **320 × 1.0** (the
smallest required run) the host is cut in `8a`, `8b` and `8c` (128–132 of
146 px). At **390 × 1.3**, the scale of one user in four or five, it is cut
in `2b`, `2c`, `6a`, `6c` and `7c` (164 of 188 px). At 320 × 2.0, `2b`
shows 148 of 291 px, and the throwaway's "duckduckgo.com" shows 148 of 249.
B, by the same probe, cuts no host at any of the six sizes.

**Room identity carried by hue alone: sharpened.** The `2c` Wiki card
(`screens.html:508`) is `ccard bg room-lake`. Its text is "Wiki" and
"background · 3 min", and nothing names "Work". The note at line 485 states
the room in prose ("Wiki is in Work (Lake)"), which the user never sees.
TalkBack reads "Wiki, background · 3 min", so this fails 1.4.1. In `2b` the
tint is atmosphere (Fern tint `#C7E2D1` on paper `#F2EBE0` measures
1.16:1). The advocate claims that hue, frame, pattern and icon "each pass
for a colour-blind user without the others" (round 1, §1). That is true for
throwaway (hatch), Tor (double wall) and wipe-on-exit (flame). It is
**not** true for the fifth channel, *which* room. Hue is the only thing that
carries that, and the CVD numbers show it does not survive:

| pair (tint) | normal | deut | prot |
|---|---|---|---|
| Ink plum `#34222E` / graphite `#25282B` | 13.4 | **0.9** | 3.4 |
| Paper lake `#CFDDF0` / plum `#ECD6E8` | 15.5 | 4.6 | **2.1** |
| Paper plum / graphite `#DADDDE` | 13.6 | 3.8 | 5.9 |

Danger `#B0362A` against Ochre wall `#8E6410` is ΔE 3.4 under deut, so an
Ochre room's `8b` puts the danger outline next to a near-identical frame.

**Focus ring: withdrawn.** Round 1 measured `--focus` `#2C6AA3` against the
Lake wall `#2C6AA3` (1.00:1). But TOKENS §1.4 draws focus as a 3 dp ring
with a **2 dp offset**, so it sits on tint or page, not on the wall.
`#2C6AA3` on Lake tint `#CFDDF0` is 4.13:1, on paper `#F2EBE0` it is
4.80:1, and dark `#7FB0E3` on `#1C2938` is 6.48:1. All exceed 3:1. The
mockup's `.field.focus` (line 132) has no offset, but fields sit on `box`,
not on a wall. What remains is cosmetic: in a Lake room, focus looks like a
second wall.

**What C does well still stands.** It has the best segment selection (a 3
dp outline plus a check), the most aria-labels, and non-hue cues for three
of the four states.

## Shared rule (all three)

Never ellipsize the host. If it must shorten, elide from the **left** so
the registrable domain stays. Today's code already ellipsizes from the
right (`container_top_bar.dart:86–90`, `maxLines: 1,
overflow: TextOverflow.ellipsis`, at 11.5 px), so the winning direction
has to change it, not inherit it.

## Bottom line (accessibility lens)

1. **B — Instrument. Best.** Blocking issue: **none.** Must fix: selected
   chip and tab at 1.72:1 fill only, with no check (`screens.html:178`).
2. **A — Daylight.** Blocking issue: **the host is ellipsized from the right
   at the default 390 × 1.0** ("forum.exampl…", 114 of 145 px, in `2b`,
   `2c`, `6c` and `7c`), against its own A11Y.md. It also overflows `8a`
   by 22 px at 320 × 2.0.
3. **C — Rooms. Worst.** Blocking issue: **which room a site is in is shown
   by hue alone** (the `2c` Wiki card has no workspace text). The room tints
   collapse under CVD (plum/graphite ΔE 0.9 deut in Ink; lake/plum 2.1 prot
   in Paper). The host is also cut from 390 × 1.3 (`2b`) and 320 × 1.0
   (`8a`–`8c`).

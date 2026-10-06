# Verdict

Written by the orchestrator (fire cd6e6b, 2026-10-06) after reading all
fourteen debate files (`round-1/`, `round-2/`), the three directions' BRIEF,
TOKENS and A11Y files, RESEARCH.md and AUDIT.md. Not delegated.

## Recommendation

**Build Direction B — Instrument, as revised in its round-2 reply, with
seven elements folded in from A and C.** Dark only; warm near-black; IBM Plex
Sans for every word and IBM Plex Mono for values; four surfaces; three text
tones all ≥ 5.30:1 in common use; jade kept as the one live colour and taken
off every *position* (switches, checks, tabs, step bars); 48 dp targets; a
host that is never cut.

## Scorecard

| Lens | A — Daylight | B — Instrument | C — Rooms |
|---|---|---|---|
| **Threat model** | Good after one fix. The pill's jade check-shield "while protections are on" was an undefined binary grade that could differ between a real vault's sites and a decoy's (`A/screens.html:199`); conceded. Light theme brighter to bystanders, but it follows the phone's own setting, the same in both vaults. | **Best.** Nothing depends on the vault; the shield shows the chosen level by fill (outline/half/full), which is a mirror of a setting, not a score. Its "loud when different" pill shows no more than today's route badges (critic withdrew). | **Blocking.** Workspace hue fills the browsing chrome and is readable across a room (Fern vs Plum tint 1.01:1 — they differ in hue alone); unflagged workspaces have no colour in the decoy (`decoy_provisioner.dart:101`); an empty decoy is one colour by construction. C's round-2 concession (neutral chrome while browsing) removes most of what makes C C. |
| **Accessibility** | Second. Highest text floor (13 sp), no enabled contrast failure, check on selected chips. But the host was cut from the right **at the default 390 × 1.0** ("forum.exampl…", 114 of 145 px), `8a` spills 22 px at 320 × 2.0, and its A11Y.md claimed both passed. | **Best.** Only direction with no overflow at all six sizes measured with real fonts, and **no host ellipsized at any size**. One real fault: selection by a 1.72:1 fill with no check; conceded with a check + 15.71:1 outline. | Worst. Which room a site is in is carried by hue alone (`2c`'s Wiki card names no workspace; TalkBack reads "Wiki, background · 3 min"); tints collapse under CVD (plum/graphite ΔE 0.9 deut, lake/plum 2.1 prot); host cut from 390 × 1.3. |
| **Implementation cost** | 10–12 agent-days (critic's revised figure): the light/dark palette (84 compile errors in 45 files once `C` is non-const), a second token table, status-bar styling on every surface, the launch-flash drawable pair. | **7–9 agent-days.** A value swap in `tokens.dart` that keeps `const`; a font swap; jade off positions (two tests are *meant* to flip). Riskiest step (type floor at 320 × 568) is already test-guarded. | 13–16 agent-days, plus a rounded clip around the WebView platform view that `flutter test` cannot verify and that narrows every page by 22 dp, plus a domain field on `SwitcherEntry`. |
| **Mainstream familiarity** | **Best.** Chrome's grammar, light by system setting, filled spruce primary, search at the bottom in Chrome's own phrasing. Faults were local: the lidded-box mark is Material's *archive* glyph (used as the Sites tab and the pill mark), wrapped mono meta, the cut host. | Second, close behind once the host leaves mono (conceded). Colourless "on" switch largely withdrawn by the critic (it is M3's switch anatomy without hue). Dashed case needs a word, which is a copy question. | Worst. Door glyph reads as a padlock where Chrome kept its HTTPS lock; pale filled chips read as M3's *selected* style; hatch reads as "disabled"; the framed page reads as a preview. |
| **Aesthetic conviction** | Competent and calm, but by its own BRIEF it gives up distinctiveness and puts it all into one mark — and that mark turned out to be someone else's icon. Looks like Chrome with a shield. | **Strongest coherent identity.** It keeps what AUDIT §3 says the app already does better than the majors (honest state, one accent, technical facts in a technical face) and fixes everything AUDIT §4.7 measured as "cold": `#0F1113` green-grey → `#121110` warm ink, warm greys, four visible surfaces. One family skeleton (Plex) for words and values. | **Most original idea of the night** — isolation you can see — and the most vivid answer to AUDIT §4.8. But the idea and the threat model are in direct conflict: the louder the room colour, the more it tells a coercer. Every fix the critics demanded takes colour out of the place where it did the work. |

## Why B

1. **It is the only direction no lens blocks.** Every critic ranked B first or
   second; three ranked it first. A was blocked on two lenses before round 2
   (shield grade, cut host) and C on three.
2. **The threat model is the product.** Container exists for a coerced
   unlock. B is the only direction whose identity costs nothing on that lens,
   and dark-only is also the least conspicuous at night.
3. **It fixes what the bounced user actually measured.** AUDIT §4.1–§4.5 (too
   small, too faint, too small to hit, surfaces that cannot be told apart,
   jargon set loudest) are all fixed by B with measured numbers; §4.7 ("cold")
   is fixed with warmth instead of a polarity change.
4. **It is cheapest and keeps every written constraint** (dark only, jade
   rule, hairlines-as-structure, mono for technical facts), so it needs no
   ruling before the build starts, and the build's risk lives where tests
   already look.

## The strongest argument against this recommendation

*A Chrome user arrives with a light phone and a learned belief that dark =
incognito. B keeps a dark-only browser, so it keeps the cue that files
Container under "another incognito thing", it forgoes positive polarity's
measured reading advantage at small sizes (RESEARCH §5), and it goes against
the roughly two thirds of users who have not chosen dark (RESEARCH §2). A
fixes the same legibility failures and also meets the user in their own
theme; the familiarity critic ranks A first, and after round 2 every one of
A's faults is a one-token fix. The cost gap (A ≈ 1.35× B) is the price of
meeting the majority where they are, and splitting A into a dark-first phase
makes even that optional.*

That is a fair argument and the main reason this is a recommendation, not a
foregone conclusion. It loses here because (a) the WebView constraint means a
light Flutter UI still serves pages `prefers-color-scheme: dark`, so A's light
mode is a seam on the screen used most (`2b`), not a clean light browser;
(b) RESEARCH §7's misconception data is about Chrome's incognito, a *light*
product — polarity is not what people misunderstand, and B attacks the
misconception the way implication 6 asks, by showing the real distinction
(Keep / wipe-on-exit / throwaway / Tor) in the pill; (c) under coerced unlock
a bright screen is a cost, and A's answer ("set your phone to dark") moves
the decision to the user. **A light variant remains possible later** on top
of B's token roles (see Unresolved 1).

## Folded into B

| From | Element | Why |
|---|---|---|
| A | **13 sp floor for everything a user navigates by** (dashboard tab labels 12 → 13; only route/format badges stay 12 sp, 600, all-caps and always beside another cue) | A's floor was the accessibility critic's one unambiguous advantage; B conceded the tab labels. |
| A | **A check on every selected chip and segment** (Material's filter-chip convention), plus a 1.5 dp `--text-1` outline (15.71:1) | Fixes B's one real accessibility fault with the cue Chrome users already know. |
| A | **The risky choice on `8b` is a text button**, 24 dp below the others | Familiarity critic's measured finding (risky button rendered tallest); A was the only one with the 24 dp gap. |
| A + C | **The host is set in the UI face (Plex Sans 16/500) in the pill**, and **never ellipsized at any scale**: it wraps, breaking after `.` | All address bars use the UI face; a host cut from the right hides the registrable domain (`forum.example.com.evil.io`). Today's `container_top_bar.dart` cuts it; the restyle must change that. |
| C | **Segmented controls selected by a 2 dp `--text-1` outline plus a check** (C's segment cue, judged best of the three) | Same reasoning as the chip check; makes `2a`'s three-way choices legible without hue. |
| C | **Throwaway and Tor told apart in the pill by shape, not colour** — a broken (dashed) case for throwaway/wipe-on-exit, a doubled case edge for Tor | C's non-hue channels survived every lens; B's case already does half of it. No new copy. |
| Debate (all) | **24 dp between `2c`'s "Close all and wipe" and panic**; `2c`'s header count set exactly like the bar's `N OPEN` | Implication 12; all three failed it as drawn. |

Also carried from round 2, B's own concessions: idle rings removed from `1b`
rows (an idle row is said by absence of the light, a `--text-2` title and its
age); the `2d` rule restated as **"the same widgets in both vaults; the
decoy's `2d` is the no-decoy variant (no VAULT section)"**; `8b` drawn for Tor
twice (clearnet host: the "Open without the tunnel" text button is present, as
`canOpenWithoutTunnel` returns true and `route_display_test.dart:41` asserts;
onion host: absent); `2c` rows draw no case, so `SwitcherEntry` gains no
field.

**Rejected from A and C, with reasons:** a light theme (Unresolved 1); room
colour in the chrome (threat model); door/flame/hatch glyphs (familiarity);
the lidded-box mark (Material's archive icon); Atkinson Hyperlegible (B's one
family skeleton for words and values is the point; Plex Sans measures fine at
13 sp+); C's walled page (unverifiable platform-view clip).

## Decisions taken without a ruling (so the build could proceed)

These are assumed in the spec and plans; each is reversible.

1. **Stored case is kept.** All three directions proposed sentence case via
   CSS; Flutter has no text-transform, so it would change the `Text` data,
   which CLAUDE.md forbids ("never re-capitalise") and which moves ~99 test
   finders. Labels stay in their stored caps, restyled (13/600, +0.04 em,
   `--text-2`) — still above today's 9.5–11 px.
2. **Canvas order kept everywhere**, including `6c` (Proxy, Cookies first),
   panic at the top right of `2b`, `☰` for the menu, SOCKS5 first in `2a`.
   Each was argued in the debate; each is a layout ruling, not a restyle.
3. **`6a`'s jade goes to "Keep blocked"**, as the canvas draws it (FINDINGS 5:
   the code made "Allow once" jade with no recorded ruling). This is a colour
   change only: both buttons keep their words, order and actions. It applies
   RESEARCH §6 (opinionated safe default) and the jade rule (the affirmative
   *safe* action).
4. **Switch "on" is not jade**: a `--text-1` track, a dark handle with a check
   (B's switch; M3 anatomy without hue). The familiarity critic withdrew most of
   the objection.
5. **Fonts:** IBM Plex Sans 400/500/600 as static TTFs, Latin + Latin-Ext
   (subset if `fonttools` is available, otherwise full static files); Figtree
   retired; Plex Mono unchanged. APK cost +0.1 % against Tor's 244.5 MB.
6. **No new copy anywhere.** The wipe-on-exit case in the pill gets a
   screen-reader label built from existing `6c` strings ("Wipe on exit" /
   "Keep for this site"); visible words wait for Unresolved 4.

## Unresolved — needs your decision

1. **Dark only, or a light variant later?** B keeps "dark only". A light
   variant over B's roles costs ~1.5–2 agent-days of palette mechanism plus a
   second token table and status-bar work (implementation critic, round 2),
   and leaves the WebView `prefers-color-scheme: dark` seam. Assumed: dark only.
2. **Sentence case for labels** (needs an explicit exception to "never
   re-capitalise"; ~99 test finders). Assumed: no.
3. **Layout rulings the debate raised but a restyle should not take:** `6c`
   leading with protection (level, blocked, switches) instead of Proxy;
   panic out of Chrome's tab/menu corner; `☰` → `⋮` (`AppGlyph.more` exists);
   Tor before SOCKS5 in `2a`. Assumed: canvas order.
4. **A visible word for wipe-on-exit / throwaway in the pill** (B's copy
   question 1). Assumed: shape + screen-reader label only.
5. **`10c`/`10a` storage sizes.** Dormant today (the storage service is a
   fake returning 0 for every vault), but the day a real `bytesFor` lands, a
   lightly used decoy reads "0 MB" beside a real vault's "12 MB". Recommend a
   rule: a real byte count needs a threat-model ruling first. Assumed: no
   change (it is behaviour).
6. **`6a`'s jade** (Decision 3 above) — confirm the canvas's "Keep blocked".

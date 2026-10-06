# Round 2 — Advocate A (Daylight) answers the critics

Everything below was rechecked against the files, not taken from round 1.
Overflow: `tools/shot.mjs direction-a-daylight/screens.html` at
`w=320&scale=2.0` (light and dark). Contrast: `tools/contrast.py`. Colour
vision: Machado 2009 at full severity with CIEDE2000, which reproduces the
critic's numbers exactly (m0/m4 deuteranopia 2.9, danger/warning 2.1). Frozen
rules hold throughout: no copy, flow or behaviour change, no leak count, no
vault cue, and the Android theme stays dark.

## Threat-model critic

**TM-A1. The shield's colour grades protection.** **Concede.**
`screens.html:199` draws `.inpill.shield` in `--accent`, and TOKENS §1 lists
"the shield when protections are on" as an accent use. That is a setting, not
live state, so it breaks the jade rule, and it would render differently on a
decoy site with protections off. **Fix:** `.inpill.shield { color:
var(--ink2) }` in every state. Remove the shield from `accent`'s purpose in
TOKENS §1, and delete the sentence at `screens.html:696`. The shield then
looks the same on every site in both vaults.

**TM-A2. A light screen at night draws bystanders' eyes.** **Rebut, in
part.** Daylight follows `platformBrightness` and nothing else. A user whose
phone is dark at night (system dark mode, or the scheduled "dark at sunset"
setting most Android skins ship) gets the dark theme, with jade `#7FC8A9`. The
light theme appears only when the owner's whole phone is light, and then every
other app on it is just as bright. It is the same in both vaults, so it is not
a tell. I accept that this cost should be written down: add one line under
BRIEF "The cost".

**TM-shared 1 (`2d` caption).** **Concede.** `screens.html:572` says
"Identical in both vaults". **Fix:** change the caption to "Same widgets in
both vaults; the decoy's `2d` is the no-decoy variant (no VAULT section,
`setup_controller.dart:71`)", and draw that variant beside it.
**TM-shared 2 (`10c` MB).** A does not draw the MB figure. Ruling on it is the
user's call, and A adds no new figure. **TM-shared 5.** **Concede.** Add an
`8b` Tor frame ("Tor did not connect") with no "Open without the tunnel"
button, so `canOpenWithoutTunnel` is written into the spec.

## Accessibility critic

**AX-A1. `8a` overflows at 320 × 2.0, and A11Y.md claimed it didn't.**
**Concede. It is worse than reported.** My re-run shows the `8a` line spilling
12 px, and `3c`'s `DESTROYED` (20 px) and `WIPED` (5 px) spilling as well,
in both themes. A11Y.md's extra-run claim is false and will be struck.
**Fix:** `.ostep .t-body2 { min-width: 0; overflow-wrap: anywhere }`, with
the mono value allowed to break only after `.` and `:`. For `3c`, the `.row`
holding an `.end.wide` gets `flex-wrap: wrap`, so at large scale the value
drops below its label instead of overflowing.

**AX-A2. The host is cut at 2.0.** **Concede.** **Fix:** adopt the shared
rule "the host is never ellipsized, at any scale". `.pill .host`: no
`text-overflow`, `overflow-wrap: anywhere`, preferring breaks after `.`. The
`.pend` group (badge, reload, shield) always moves to a second line before the
host loses a character. In Flutter that means `maxLines: null` and
`softWrap: true` on the host `Text`, so `find.text` is unaffected.

**AX-A3. The selected nav tab is shown by fill alone (1.37:1 / 1.20:1).**
**Concede.** **Fix:** the selected destination gets a filled icon (three new
`AppGlyph` painters: `sitesFilled`, `todayFilled`, `settingsFilled`; the
outlined icon stays for the others) and a label weight of 700. This is Material
3's own nav-bar cue, so it is also the familiar one. The `tonal` indicator
stays as the secondary cue.

**AX-A4. Light markers `m0`/`m4` are ΔE 2.9 apart under deuteranopia.**
**Concede.** **Fix:** change light `--m4` from `#5E6661` to `#2E3430`. The
worst pair against the other four markers becomes ΔE 14.1 (deuteranopia, vs
m0), and contrast is 12.73:1 on card and 10.86:1 on page. The dark markers
already pass: m0/m4 is 12.9, and the worst dark pair is m1/m3 at 6.0
(protanopia), above the critic's ΔE 5 bar.

**AX-A5. `danger`/`warning` are ΔE 2.1 apart under deuteranopia.**
**Rebut (no change).** The critic calls this latent. Every warning use is
labelled ("Permission asks", the JS badge) or is the `8a` amber dot, which
sits beside the checklist text. The candidate that separates them
(`#9A6A00`, ΔE 6.7) falls to 4.04:1 on `page`, below 4.5 for text. Moving a
pass to a fail to fix a latent risk is the wrong trade. Dark is fine
(`#F2A49A`/`#E3B262`: 11.0).

## Implementation-cost critic

**IC-A1. The light theme is a context-palette refactor: 430 `C.` reads in 71
files, ~3–4 agent-days, 12–15 days in total.** **Concede the numbers. Rebut
the conclusion that it must ship all at once.** Daylight's dark theme is a
complete theme on its own: the same roles and jade, with `ink2` and the
surfaces already measured. **Fix: split the plan.** Phase 1 ships Daylight
dark as a value swap, which is the cheap path the critic credits to B (const
`C.*` stays, no context reads), plus fonts and geometry, at roughly B's cost.
Phase 2 adds the light theme behind the context palette (option 1; I agree
that option 2's re-keyed root is a forbidden behaviour change). Phase 2 also
carries the critic's list: `SystemUiOverlayStyle` per surface, the
`user_script.dart` badge colours moved into the UI layer, and the 9 `C.line*`
plus 6 `Colors.white/black` sites. Phase 1 is useful on its own and does not
depend on phase 2.

**IC-shared (sentence case is a re-capitalisation, and 90 finders move).**
**Concede.** This breaks the frozen copy rule. **Fix:** drop
`text-transform` (`.sentence`, `screens.html:58–59`) everywhere. Labels render
exactly as stored, in caps, at 13 sp with 0.4 letter-spacing. That keeps the
size gain over today's tracked 10 px and leaves every `find.text('ALL CAPS')`
alone. Sentence case becomes a question for the user, not part of A.

**IC-A2. New fonts (Atkinson Hyperlegible Next and Mono).** **Rebut.** It is
two TTFs, `pubspec.yaml`, `typography.dart` and one test assert, and it saves
about 140 KB.

## Familiarity critic

**FM-A1. `1b`'s mono meta wraps at 1.0** (`notes.example.org · / socks5`).
**Concede.** **Fix:** split the meta line into two spans. The host stays in
mono. ` · socks5` / ` · pin required` move to the UI face (`T.meta`, `ink2`),
and the line wraps only at the ` · ` boundary (`white-space: nowrap` per
span). Copy is unchanged.

**FM-A2. The lidded box is Material's "archive" icon, and dashed reads as
"select area".** **Concede.** Lid, body and slot are the archive glyph's
parts. **Fix:** (a) drop the slot from `logo.svg`, `app-icon.svg` and the lock
mark, leaving lid and body; (b) take the box out of the pill. A Keep site
shows nothing extra there. A throwaway shows the existing `THROWAWAY ·
<MODE>` badge (`address_suggestion.dart:42–43`), and wipe-on-exit shows the
existing `WIPES ON EXIT` string (`dashboard_body.dart:53`) in the same badge
slot. Both are existing strings and no new sign. Implication 6 is still met in
the chrome, in words. A's one new sign was one too many.

**FM-A3. The pill truncates the host to fit `SOCKS5`.** **Concede.** Same
fix as AX-A2: the badge group wraps under the host before the host is cut.

**FM-A4. `6c` opens on the proxy port, and its value wraps in mono.**
**Concede both** (shared item 1). **Fix:** reorder `6c`'s groups. First
`Blocked here · N requests` and the three protection switches, then the
security level, then Proxy and Cookies last. Proxy becomes a two-line list
item: the label on line one and the value on line two in mono, so the value
never breaks mid-value. Row order is layout; no copy changes.

**FM-shared 3 (`2c`'s two destructive buttons sit 12 dp apart).** **Concede.**
`.actions { gap: 12px }` (`screens.html:223`) becomes `gap: 24px`
(Implication 12).
**FM-shared 5 (☰ vs ⋮).** **Concede.** The menu icon becomes a vertical
three-dot `AppGlyph` (the existing `more`, rotated), with its label `Menu`
unchanged.
**FM-shared 4 (panic at top right) and 7 (SOCKS5 first).** **Rebut.** Both
positions come from the authoritative canvas and the approved layout C spec
(Plan 12). Moving panic or reordering route chips is a design ruling for the
user, not something a restyle decides. A already tints panic `danger` with a
`dangerContainer` tile, so it is not mistaken for ⋮.
**FM-shared 6 (`8b`'s equal buttons).** **Rebut for A.** The critic's own
`8b` note says spruce `Try again` dominates and the risky option is 24 dp
away.

## Revised position

The critics found real faults in A, and most are local. Some of my round-1
claims were wrong. A11Y.md's 320 × 2.0 run did not pass. The shield's colour
was a grade. Sentence case was a copy change. The box mark borrowed the
archive icon's meaning. Each of those now has a fix of one token or one rule.
What stands is the core case: the bounced Chrome user gets Chrome's grammar,
a theme that follows their phone, a 13 sp floor and no enabled contrast
failure, and A ranked first on familiarity and second, close behind B, on
accessibility and threat model. The real new concession is cost. A's light
theme is the largest refactor on the table. Split into a dark-first phase,
though, A ships at about B's cost and keeps light as a separable second plan,
so the user can choose Daylight's reading fixes without buying the palette
refactor up front.

| Criticism | Concede / rebut | Fix |
|---|---|---|
| TM-A1 shield colour grades protection | Concede | `.inpill.shield` → `--ink2` always; drop from `accent` purpose |
| TM-A2 light theme draws bystanders | Rebut (part) | Follows system dark; note cost in BRIEF |
| TM-shared 1 `2d` "identical" caption | Concede | Re-caption; draw no-decoy `2d` variant |
| TM-shared 5 Tor `8b` | Concede | Add `8b` Tor frame without the direct button |
| AX-A1 `8a` (and `3c`) overflow at 320×2.0 | Concede | `overflow-wrap` on `.ostep`; `3c` rows wrap; correct A11Y.md |
| AX-A2 host cut at 2.0 | Concede | Host never ellipsized; `.pend` wraps first |
| AX-A3 nav selection by fill | Concede | Filled icon + 700 label on selected tab |
| AX-A4 m0/m4 deuteranopia ΔE 2.9 | Concede | Light `--m4` `#2E3430` (ΔE ≥ 14.1; 12.73:1) |
| AX-A5 danger/warning ΔE 2.1 | Rebut | Labelled; the fix would fail 4.5:1 on page |
| IC-A1 palette refactor cost | Concede (cost) / rebut (all at once) | Phase 1 dark value swap; phase 2 light |
| IC-shared sentence case | Concede | Drop `text-transform`; caps at 13 sp, 0.4 tracking |
| IC-A2 fonts | Rebut | 2 TTFs, saves ~140 KB |
| FM-A1 `1b` meta wraps | Concede | Host mono, route in UI face, wrap at ` · ` |
| FM-A2 box = archive icon | Concede | Drop slot; pill uses existing `THROWAWAY`/`WIPES ON EXIT` |
| FM-A3 host truncated for badge | Concede | As AX-A2 |
| FM-A4 `6c` order, wrapped value | Concede | Status + switches first; Proxy as two-line item, last |
| FM-shared 3 `2c` buttons 12 dp apart | Concede | `gap: 24px` |
| FM-shared 5 ☰ | Concede | Vertical three-dot glyph, label `Menu` |
| FM-shared 4/7 panic position, SOCKS5 first | Rebut | Canvas and layout C spec; user's ruling |
| FM-shared 6 `8b` buttons | Rebut | Critic: spruce dominant, 24 dp gap |

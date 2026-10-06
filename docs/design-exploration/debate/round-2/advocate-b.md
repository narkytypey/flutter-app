# Round 2 — Advocate for Direction B (Instrument)

The four critics agree on B's shape: safest on the threat lens
(`critic-threat-model.md`, "Verdict: safe … strongest of the three"), first on
accessibility (`critic-accessibility.md`, "Ranking": 1. B) and cheapest to build
(`critic-implementation-cost.md`, "B ≪ A < C", 7–9 agent-days). Its real
failures are on the familiarity lens and in one state cue. I concede most of
them. Each fix below is a token or a layout value. None changes copy, flow or
behaviour. Ratios are from `tools/contrast.py`.

## Accessibility critic

**A1. The selected chip and selected tab are told apart by fill alone**
(`.chip.on` and `.tabs .on .ind` use `--surface-raised` `#403C37` on ink,
1.72:1). **Concede.** Fix for `1b`, `2a` WORKSPACE and `10b`: `.chip.on` gets
a leading 16 dp `AppGlyph.check` (it already exists, Plan 17) and a 1.5 dp
`--text-1` outline. `#EDEAE4` on `#121110` is 15.71:1, and on
`--surface-group` it is 13.53:1. Unselected chips keep the `--line` outline.
Tabs: `.tabs .on .ind` keeps its fill and adds a 1.5 dp `--text-2` outline
(10.90:1 on ink), and the selected icon becomes the filled variant of
`sites`/`today`/`settings`. That gives two non-fill cues: an outline that
passes 3:1, and a change of icon shape.

**A2. The text floor is 12 sp, and it covers navigation.** **Concede.**
`--fs-caption` moves from 12 to 13 sp for the dashboard tab labels. Route
badges (`SOCKS5`, `TOR`) stay at 12 sp: they are short, all-capital, 500
weight, and a redundant label next to an icon. The worst-case runs already
pass at 320 × 2.0 (`critic-accessibility.md`: "All five runs report no
overflow"), so 1 sp on three labels in a 64 dp bar adds no new risk.

**A3. At 2.0 the host breaks mid-word into four lines.** **Rebut, but
keep it on record.** The critic calls this "the right trade". The shared rule,
"the host is never ellipsized", is one B already meets. I propose adopting it
as a global rule in the winning spec.

## Familiarity critic

**F1. The host is set in mono in the pill.** **Concede.** In round 1 I said
this choice was "easy to reverse", and RESEARCH implication 5 asks for the host
"in the UI face" (`RESEARCH.md:199`). Fix: `.pill .host` becomes Plex Sans
16/500 in `--text-1`. Mono stays for values inside sheets (`6c`'s
`127.0.0.1:9050`, `8b`'s tunnel, the `1b` meta host). The pill is the one place
where familiarity outranks the mono rule.

**F2. The dashed case is the only sign of wipe-on-exit.** **Concede half.**
Shape alone is too weak to teach. I can't add words, because that is BRIEF Copy
question 1, which needs a ruling. The minimal fix inside the frozen rules is
this: give the case's `Semantics` label the existing `6c` value `Wipe on exit`
or `Keep for this site`, which the canvas already contains, and make the dash
1.5 dp `--edge` (5.76:1 on ink) at 4 on, 3 off, so it doesn't read as a
loading shimmer. The visible words wait for Copy question 1. I recommend
answering it yes.

**F3. An on switch without colour reads as off.** **Rebut.** B's switch is
Material 3's dark-scheme switch with the hue removed: a light filled track, a
dark 24 dp handle with a check, against a dark track with an `--edge` outline
and a 16 dp grey handle (`screens.html:141–146`). The cue Android users learn
is fill, handle size and the check, and all three are there. Hue is not one of
them. Fill alone measures 15.71:1 (`--text-1` against ink), and the off
outline is 5.76:1. Giving the track jade would bring back the "jade = settings"
noise that round 1 removed. Accessibility, the lens that measures this, did
not flag it.

**F4. Idle rings look like unread badges.** **Concede.** Fix: remove
`.lt.idle` from `1b` rows. An idle site already shows its state through its
dimmed `.mg.idle` monogram, its `--text-2` title, its age, and the absence of
a light. That is a presence-or-absence cue, not one carried by colour. `2c`'s
background light and `5a` tiles keep the ring, because there "idle" is spelled
out next to it.

**F5. In `8b`, jade and coral buttons compete.** **Concede.** This also covers
shared finding 6. Fix: `Open without the tunnel` becomes a text button: `--danger`
text (7.83:1), no outline, at least 48 dp tall, with its `small` line in
`--text-2`, 24 dp (`--s6`) below `Change proxy settings`. It stays the only
danger control, as the threat critic requires (shared finding 5), but it no
longer has the weight of a button.

**F6. `1b`'s `socks5` reads as part of the address.** **Rebut in part.** In
B only the host is mono, and `· socks5` is in Sans (`screens.html:447`). The
lower case is the stored data, so it is copy. The 4 sp gap and the
`--text-3` tone already set it apart. No change.

## Shared findings that bind B

**S1. Sentence case is a re-capitalisation and needs a ruling**
(`critic-implementation-cost.md`, about 90 test finders). **Concede, and
withdraw it.** CLAUDE.md says "never … re-capitalise". B renders every
stored ALL-CAPS string as stored: section labels at 13/600 `--text-2` with
+0.04 em tracking, and the `.sc` class is deleted. That keeps the legibility
gain from round 1 (14 → 13 sp is still above today's 9.5–11 px) and moves no
test finders.

**S2. The `2d` parity caption is wrong** (threat critic, shared 1). **Concede.**
BRIEF's "Nothing depends on which vault is open" becomes "the same widgets in
both vaults; the decoy's `2d` is the no-decoy variant (no VAULT section)",
and `screens.html`'s `2d` gets a second frame without VAULT.

**S3. `10c` reports MB wiped** (shared 2). B does not draw `10c`'s sizes. It
needs a ruling. I recommend that the sheet always shows the existing line with
its size hidden, but that is copy and not mine to decide.

**S4. Draw `8b`'s "Tor did not connect" variant** (shared 5). **Concede.**
Add the frame: the same layout with no third button, as `canOpenWithoutTunnel`
already behaves (`route_display.dart:37`).

**S5. `6c` opens on the port number** (familiarity shared 1). **Concede.**
Reorder the groups and leave the rows alone: Security level, then Blocked here
and its categories, then the switches, then permissions, then Proxy and Cookies
last. That matches Plan 16's own description of the shield panel (level,
counts, switches, permissions). The reorder is pure layout.

**S6. `2c`'s two destructive buttons sit 8 dp apart** (shared 3). **Concede.**
`.sw-actions` gap goes from `--s2` (8 dp) to `--s6` (24 dp), meeting
implication 12. The header count is set as the bottom bar's `N OPEN` label
(same 13/600 `--text-1`), so the two read as one number.

**S7. Panic sits where Chrome keeps tabs and ⋮** (shared 4). **Rebut.**
Layout C is the user-approved spec (Plan 12, `2026-09-28-browser-chrome-design.md`),
and moving panic is a layout ruling outside a restyle. B already marks it as
unlike a menu: a 1.5 dp `--danger` outline (`screens.html:213`, 7.83:1).
**`☰` vs `⋮`** (shared 5): I agree on the merits, since the sheet is an overflow
menu and `AppGlyph.more` exists. But the canvas draws `☰`, so this needs a
ruling. The cost is one glyph.

**S8. SOCKS5 first in `2a`** (shared 7). **Rebut.** The chip order is the
canvas's, and reordering a form changes its flow. Out of scope.

## Threat-model critic

**T1. "Calm when healthy, loud when different" shows an observer that Tor was
in use.** **Rebut.** Today's pill already shows every route badge, including
`THROWAWAY · TOR` (Plan 19). B shows *less* than today for direct sites and the
same for others. Whether a decoy holds proxy sites is data the owner chooses
(`resyncDecoy`), not a visual. The critic rates it "a small step up … not a new
leak". No change.

## Implementation-cost critic

**I1. If `2c` rows show solid vs broken cases, `SwitcherEntry` gains a field.**
**Concede.** `2c` rows don't draw the case, as `screens.html:552–566` already
shows. I'll state that in TOKENS so no implementer adds the domain field.
**I2. +246 KB for Plex Sans.** This is a stated cost and I keep it: one family
for UI and values, and it removes the `wght` workaround in `typography.dart`.
**I3. Overflow risk from the type floor.** True, and guarded by tests. The
rulings above (13 sp labels instead of 14, a Sans host that is narrower than mono)
lower it slightly.

## Revised position

B remains the safest, most robust and cheapest base, and after this round it
is the more familiar one as well. The host leaves mono, selection gains a check
and a 15.71:1 outline, idle rings go, `8b`'s risky option drops to a text
button, `6c` leads with protection, and B stops re-casing stored copy, which
also removes the largest test cost the critics found. What B still rejects is a
coloured "on" switch and any change to the canvas's layout (panic position,
chip order). Those need rulings, and a restyle should not decide them.

| Criticism | Concede / rebut | Fix |
|---|---|---|
| A1 selection by fill (1.72:1) | Concede | `.chip.on`: check glyph + 1.5 dp `#EDEAE4` outline (15.71:1); tab: 1.5 dp `--text-2` outline (10.90:1) + filled icon |
| A2 12 sp nav labels | Concede | `--fs-caption` tab labels 13 sp; badges stay 12 |
| A3 host wraps at 2.0 | Rebut (critic endorses) | Adopt "host never ellipsized" globally |
| F1 mono host | Concede | `.pill .host` Plex Sans 16/500 |
| F2 dashed case unexplained | Concede half | Semantics label from `6c` strings; dash 1.5 dp `#958D82` 4/3; Copy Q1 → yes |
| F3 colourless switch | Rebut | M3 dark switch minus hue; 15.71:1 fill, check, handle size |
| F4 idle rings = badges | Concede | Drop `.lt.idle` on `1b` |
| F5 / shared 6 `8b` competing buttons | Concede | Risky option → danger text button, 24 dp gap |
| F6 `socks5` in meta | Rebut | Already Sans; lower case is data |
| S1 sentence case | Concede, withdraw | Stored caps, 13/600 +0.04 em; delete `.sc` |
| S2 `2d` parity text | Concede | Reword rule; add no-VAULT frame |
| S3 `10c` MB | Ruling needed | Not drawn by B |
| S4 Tor `8b` | Concede | Add two-button frame |
| S5 `6c` order | Concede | Level → blocked → switches → permissions → proxy/cookies |
| S6 `2c` 8 dp gap, header count | Concede | Gap 24 dp; header set as `N OPEN` |
| S7 panic position, `☰` | Rebut / ruling | Spec layout C; `⋮` is one glyph if ruled |
| S8 SOCKS5 first | Rebut | Canvas order; flow |
| T1 route visibility | Rebut | Less than today's badges |
| I1 `SwitcherEntry` field | Concede | No case in `2c` rows |
| I2 font weight | Keep | Stated cost |

# Round 1 — Mainstream-familiarity critic

**Lens, and only this lens:** a Chrome-on-Android user (RESEARCH §1: 17 in 18
of the people who bounce) opens each screen cold. Can they say what it is and
what to press within ten seconds? Copy is frozen, so every finding below is
about setting, order, weight and glyphs, not words. Judged from renders at
390 × 1.0 (`tools/shot.mjs`, clipped per block): `1b`, `2a`, `2b`, `2c`,
`3a`, `6c`, `8b`.

## Shared failures (all three directions)

1. **`6c` opens on the most expert fact.** Every direction's shield panel
   puts `Proxy · SOCKS5 · 127.0.0.1:9050` as its first row, then
   `Cookies`, then `Security level`. Firefox, Brave and DuckDuckGo all open
   with one plain status line and one master control; that is the grammar
   the shield (RESEARCH §2) teaches. A Chrome user taps the shield to ask
   "am I protected here?" and is answered with a port number. Reordering
   rows is layout, not copy: lead with `Blocked here · 164 requests` and the
   protection switches, and push Proxy/Cookies to the bottom group.
2. **`2c` is a list, not Chrome's tab grid, and three nouns count the same
   thing.** The bottom bar's `3 open` and the sheet's `3 open sessions`
   (`2c` header) sit in different weights and positions, and the `Personal`
   at the header's right edge reads as a filter, not a workspace label. No
   direction draws a thumbnail or anything card-like enough to say "tabs".
   Users will find it, but it does not look like what they tapped. At
   minimum the count in the sheet header should be set like the bar's pill,
   so the two read as one thing.
3. **`2c`'s two destructive buttons sit side by side.** `Close all and wipe`
   (full width) and the panic power button (48 dp) share one row in all three.
   A Chrome user knows "close all tabs" as a menu item, never as a large
   primary-sized button, and the power glyph next to it reads as "turn off
   the app", which is close but not "destroy everything". RESEARCH
   implication 12's 24 dp separation is not met in any of the three.
4. **The power glyph as panic** (top-right of `2b`, where Chrome keeps its
   tab counter and ⋮ menu). Muscle memory sends the right thumb there for
   tabs or the menu; here it lands on the most destructive control in the
   app. All three tint it so it is not mistaken for a menu, but none moves
   it. This is the single biggest grammar fight in the chrome.
5. **`☰` instead of `⋮`.** A small thing, but Chrome's overflow is three
   vertical dots; a hamburger on Android means "navigation drawer". All three
   keep `☰` at bottom right.
6. **`8b` gives three full-width buttons equal height.** Chrome's error
   pages give one. `Open without the tunnel` is the same size as `Try again`
   in every direction, and in B and C it sits close under `Change proxy
   settings`. The risky choice should be visibly smaller (a text button), not
   only a different colour.
7. **SOCKS5 first.** `2a` Network's chips run `SOCKS5 · HTTP · Tor`, and in
   `1b` meta reads `notes.example.org · socks5`. The one route a newcomer may
   have heard of (Tor) is last; the one they have not is first and, in `1b`,
   in lowercase mono that looks like part of the address.

## Direction A — Daylight

**Most familiar of the three; fails in two specific places.**

- `1b` passes the ten-second test: light page, rounded list, a bottom search
  field "Search or type an address" in Chrome's own phrasing and position,
  green dots on the open sites. But the mono meta wraps on half the rows
  (`notes.example.org · / socks5`, `bank.example.com · pin / required`) — at
  1.0 scale. To a newcomer the wrapped `socks5` and `required` look like
  separate data. Set the meta in the UI face, or keep only the host in mono.
- **`2b`'s container-type icon is Material's "archive" icon.** The lidded
  box (and the logo on `3a`) is, glyph for glyph, the archive symbol every
  Gmail and Files user knows. In the pill, at the position where Chrome shows
  its page-info icon, the dashed variant reads as "select area". The mark
  teaches nothing in ten seconds; it borrows a meaning that is wrong.
- **`2b`'s pill truncates the host** (`forum.exampl…`) to fit the
  `SOCKS5` badge. Chrome never sacrifices the host; the badge should move
  under the host (as B does) or into the shield.
- `6c`'s Proxy value wraps across two lines of mono (`SOCKS5 · /
  127.0.0.1:9050`), making the first row of the panel the hardest to read.
- `2c`, `3a`, `8b` are the most Chrome-like of the three: spruce `Try
  again` clearly dominant, the risky option 24 dp away.

## Direction B — Instrument

**Readable and calm, but still talks to the expert first.**

- `2b`: the host is in **mono at 15 sp**. Nobody's address bar is mono
  (RESEARCH §3: "nobody uses monospace in the chrome"); here it is the first
  thing read on every page, and it says "developer tool" before anything
  else. B's own rule is "mono for values" — the host is a value, but the
  pill is the one place familiarity should win.
- **The dashed case around the `Fr` monogram** at the pill start is B's only
  sign of wipe-on-exit, and the brief admits it is shape-only (Copy question
  1). A dashed outline on dark reads as "empty slot" or "loading". It needs a
  legend that nothing provides.
- **Switches without colour (`6c`, `2a`).** An "on" switch is a warm-white
  track with an ink knob and a check. Android users read a light track on a
  dark screen as *off* far more often than as on; the check helps, but at a
  glance `Desktop view` (off, outlined) and the four on switches are told
  apart by fill alone. This spends a convention every Android settings
  screen relies on, for the sake of the jade rule.
- `1b` works: green live dots, sans names, a clear search field. The idle
  dots (hollow grey rings on the monogram corner) look like unread badges.
- `8b`: jade `Try again` and coral-outlined `Open without the tunnel` are
  both bright on black; two coloured buttons compete for the first look.
- `3a` is good: the case mark reads as a safe.

## Direction C — Rooms

**Teaches the most, but needs the most teaching; several metaphors collide
with Android ones.**

- **The door in the pill is a padlock.** On `2b` the filled arch sits exactly
  where Chrome used to put the HTTPS lock, at the same size, in black. A
  Chrome user reads "secure connection". On `1b` the same filled/hollow doors
  at row ends read as locked/unlocked, or as tombstones — not as open/idle.
  Open/idle is the one state the dashboard must show, and it is now the one
  that needs a legend.
- **Colour means two things on chips.** On `1b` and `2a` the selected
  workspace is a filled Fern chip, but the unselected `Work` is a filled Lake
  chip and `Ephemeral` a filled grey one. Every chip looks selected. Chrome
  and Material teach "the tinted chip is the chosen one"; Rooms tints all of
  them for identity.
- **`2c` inverts selection.** The viewed container is the *white* card;
  background ones are the coloured ones. The eye goes to colour, so it goes
  to the wrong rows.
- **Hatching on the throwaway (`2b` middle)** reads as "disabled" or "under
  construction" — the diagonal-stripe pattern Android and the web use for
  unavailable areas. A throwaway is fully usable.
- **The page sits inside a 3 dp room wall** with light, tinted bars around a
  dark page. Chrome's page runs edge to edge; here the page looks like an
  embedded frame or a preview, not the browser.
- **The flame** (wipe-on-exit) is legible to DuckDuckGo users and to nobody
  else; on `1b` it is a 12 dp badge on one monogram and on the `Ephemeral`
  chip, unexplained.
- Strengths: the solid ink `Save`/`Try again` pill is the clearest "press
  this" in any direction, and `8b` inside the room wall does say which site
  failed.

## Verdict

| | Ten-second read | Fights Chrome grammar | Unexplained metaphor |
|---|---|---|---|
| **A** | Yes on `1b`, `8b`, `3a`; no on the `2b` pill | panic at top right, `☰`, truncated host | box icon = Material "archive" |
| **B** | Yes on `1b`, `3a`; slower on `2b`, `6c` | mono host, colourless switches, panic, `☰` | dashed case, hollow idle rings |
| **C** | No on `1b` (doors, chips) and `2b` (door = lock) | framed page, all-tinted chips, panic, `☰` | doors, hatching, flame, room wall |

**A is the most familiar** and its failures are local (one icon, one badge
position, wrapped meta). **B** is close behind once the host leaves mono and
an "on" switch gets a fill. **C** is the boldest attempt to fix the
incognito misconception, but in ten seconds it trades one misreading
("dark = private") for three new ones (door = lock, hatch = disabled, tint =
selected); any adoption of Rooms needs a different open/idle glyph and
selection drawn by something other than hue before it meets this lens.

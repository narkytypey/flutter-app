# Round 1 — Threat-model critic

Lens: **coerced unlock.** Someone makes the owner type a PIN. The decoy vault
must look like the only vault, nothing on the lock screen may hint at a second
one, and panic, Tor and never-direct must keep working. I checked each
direction's `BRIEF.md`, `TOKENS.md` and `screens.html` against the data layer:
`lib/data/services/app_database.dart` (`ensureWorkspace`, `seedIfEmpty`),
`lib/data/repositories/decoy_provisioner.dart`, `setup_controller.dart` and
`settings_route.dart` / `settings_screen.dart`.

## How the data layer works (what the visuals depend on)

- **Markers are per-workspace data in both vaults.** `marker_index` is a
  column on `workspaces` (`app_database.dart:101`). `resyncDecoy` copies the
  real workspace's `markerIndex` with the row, and the rescue path keeps it
  too (`decoy_provisioner.dart:145`). So a synced decoy workspace has the same
  colour as its real one.
- **An empty decoy has exactly one workspace**: Personal, marker 0
  (`ensureWorkspace`, `app_database.dart:303`). The real vault is seeded with
  three: Personal 0, Work 1, Ephemeral 4 (`seedIfEmpty`, lines 320–326). The
  data model already makes a "Pick after setup" decoy sparser than the real
  vault, so any design that turns workspace count into area or colour makes
  that gap bigger.
- **Settings is not identical in both vaults, and should not be.**
  `decoy_configured` is written only to the main vault
  (`setup_controller.dart:71`). So the decoy's `2d` has no VAULT section,
  which makes it look like a vault whose owner never set up a decoy. That is
  the right outcome. A decoy whose Settings said "Decoy vault: on" would give
  itself away on the spot.

## Shared findings (all three directions)

1. **The `2d` captions state the parity rule wrongly.** A: "Identical in both
   vaults" (`direction-a-daylight/screens.html:572`). C: "decoy configured, so
   VAULT shows … Settings look identical in both vaults"
   (`direction-c-rooms/screens.html:521`). B's brief: "Nothing depends on
   which vault is open". Each one then draws VAULT with "Decoy vault" on and
   "4 selected". If an implementer read "identical" literally and showed
   VAULT in both vaults, the decoy would announce itself. The rule should
   read: *the same widgets in both vaults; the decoy's `2d` is the no-decoy
   variant.* This is a fix to the spec text, not a defect in any visual.
2. **Inherited channel: `10c` reports how much data a delete would wipe.**
   The sheet shows "Stored data wiped · 3 MB" and "Logins destroyed"
   (canvas copy, built in `delete_workspace_sheet.dart:68–70`). In a
   lightly used decoy, a coercer can long-press a workspace, read "0 MB",
   and cancel. C draws this (`direction-c-rooms/screens.html:1284–1310`).
   A and B leave it out, so they don't make it worse. It needs a ruling
   whichever direction wins.
3. **Unlock motion is safe in all three.** A's lid lifts, B's seam lifts
   (`direction-b-instrument/TOKENS.md:275`), and C's door swings open
   (`direction-c-rooms/TOKENS.md:185`). Each plays on any correct PIN and
   never on a refusal, so after a panic, when every PIN is refused, none of
   them plays. None of them depends on which vault opens.
4. **No leak count, no score.** None of the three brings either back. In all
   three, `5c` draws neutral bars with mono numbers. The `6c` tally appears as
   "Blocked here · 164 requests" (A) and as category counts (B and C). That
   is the allowed blocked tally.
5. **Never-direct holds.** In every `8b`, "Open without the tunnel" is the
   only outline-danger control, below the jade/primary action, with "This
   site will see your real IP" (canvas copy). No direction draws `8b` for a
   Tor site. The app already hides the button there
   (`route_display.dart:37`, `canOpenWithoutTunnel`). Whichever direction
   wins should draw the "Tor did not connect" variant so the absence is part
   of the spec.

## Direction A — Daylight

**Gets right.** The theme follows `platformBrightness` only, which is the same
for both vaults. The lock screens (`3a`, `4c`, `9b`, `9c`) use one mark with
no vault cue. Chips carry no colour, and markers stay a 12 dp dot in
`10a`/`10b` only (`TOKENS.md:52–57`). `3b` is `1b`'s widgets with different
data. Panic is drawn in the `2b` top bar, in `2c` and in `6c`. `3c` sits on
the ordinary page, not a red screen.

**Weakens.**
- **The shield's colour states that protection is on.** "The shield in the
  pill is spruce while protections are on" (`screens.html:696`;
  `TOKENS.md:44`, `accent #1D6B57 / #7FC8A9`). That is a binary
  protection grade, the thing the brief itself says DuckDuckGo retired. It
  shows a vault difference on any decoy site with protections off. It also
  breaks jade's rule, because "protections on" is a setting, not live
  state. Draw the shield in ink, or by level as B does.
- **The light theme draws more attention.** A paper-white screen at night is
  more visible to bystanders than dark. That is not a vault leak, but it
  costs something under this threat model, and the brief never weighs it.

**Verdict: safe to build after one fix** (shield colour). Low risk.

## Direction B — Instrument

**Gets right.** It is the closest to the current posture. It is dark-only,
which is also the least conspicuous to bystanders. The brief states "no
per-vault tone, mark or icon" and "`3b` is `1b` with the decoy's data", and
the screens do that (`screens.html:1218–1249` against 436–480). Workspace
markers stay data in `10a`/`10b` only ("tells contexts apart by shape … not
by hue", `BRIEF.md:84–87`). The shield shows Standard / Safer / Safest as
outline / half / full. That mirrors a setting the user chose; nothing is
computed, so it is not a score. `6a` puts jade on "Keep blocked", which makes
the safe choice dominant. The 4c, 9b and 9c lock marks are the same case with
no vault cue.

**Weakens.**
- **"Calm when healthy, loud when different"** (`BRIEF.md:66–68`): the pill
  stays silent for direct sites and gains words for a proxy, Tor or a
  throwaway. Someone who has watched the owner browse learns that Tor was
  in use. If the decoy then holds only direct sites (`3b`), the story
  doesn't fit. This is a small step up from today's route badge, not a new
  leak.

**Verdict: safe.** It is the strongest of the three on this lens.

## Direction C — Rooms

**Gets right.** It reads colour from the workspace's `markerIndex`, never
from the vault, and `3b`'s note correctly cites `ensureWorkspace` marker 0
= Fern (`screens.html:1255`). It keeps the five indices, so it needs no
schema change and the decoy's copies keep their colours. The lock screens and
Settings carry no room colour (`screens.html:521, 569`). No room is red, so a
room can't be mistaken for danger. The throwaway (hatched) and Tor (double
wall) states are clear.

**Weakens. This is the most serious finding of the round.**
- **Workspace identity is made legible at a distance.** The room tint
  covers the dashboard panel and the whole container chrome: the status bar,
  both bars, the pill wall and a 3 dp frame round the page
  (`TOKENS.md:84–86`; `2b` at `screens.html:330–420`, e.g.
  `.sys{background:var(--tint)}`). The brief's own success test is that the
  owner "can tell it is her green Personal room *without reading the
  address*" (`BRIEF.md:39`). An observer gets the same ability. A name can't
  be read from across a room, but Plum `#8A4C82`/`#ECD6E8` filling the screen
  can be. If the owner browses an unflagged workspace in public, the coercer
  can demand "the purple one", and the decoy, which only holds flagged
  workspaces, has none.
- **An empty decoy is one colour by construction.** One Fern room, against
  the real vault's seeded Fern/Lake/Graphite. Today that difference is one
  chip against three. Under Rooms it becomes a single-colour app against a
  multi-colour one, on every screen.
- **It draws `10c`'s "Stored data wiped · 3 MB"** (shared finding 2) without
  flagging it.
- It breaks dark-only, as A does, and adds the ~200 ms black-to-paper flash
  (`BRIEF.md:124–128`). That is the same in both vaults, so it is not a tell,
  but it does draw the eye.

**Verdict: weakens the posture.** To be acceptable it needs at least (a) room
colour confined to the dashboard and `2c`, with the container chrome neutral
while browsing, and (b) an explicit decoy-parity rule for markers. Re-sync
would need to give the decoy a matching spread of colours, which is a
data-layer change no direction proposes. Without both, I would not ship C
under a coerced-unlock threat model.

## Summary

| | Vault cue | Score/leak count | Panic/Tor/never-direct | Verdict |
|---|---|---|---|---|
| A | none; shield-colour grade | shield colour borders on a grade | intact | Ship after shield fix |
| B | none | none | intact | Safest |
| C | room colour readable at a distance; decoy one colour by construction | none | intact | Weakens; needs chrome-neutral browsing |

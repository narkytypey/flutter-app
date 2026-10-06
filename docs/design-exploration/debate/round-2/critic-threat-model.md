# Round 2 — Threat-model critic

Lens unchanged: **coerced unlock.** Someone makes the owner type a PIN. The
decoy has to pass as the only vault, the lock screens must give nothing away,
and panic, Tor and never-direct must keep working. Below, each round-1
objection is either sharpened with evidence from the tree or withdrawn. Where
an advocate's claim touches this lens, I answer it.

## Corrections to my own round 1

**Shared finding 5 (never-direct on Tor) was wrong as stated. I withdraw the
claim and replace it with a sharper one.** I wrote that the app "already hides
the button" for a Tor site. It does not. `canOpenWithoutTunnel`
(`lib/domain/models/route_display.dart:37`) returns false only for a direct
site or an **onion host**. `test/domain/route_display_test.dart:41` asserts
`canOpenWithoutTunnel(_site(ProxyMode.tor))` is **true**. So `8b` for a
clearnet site on Tor, headlined "Tor did not connect" (`route_decision.dart:89`),
offers "Open without the tunnel". That behaviour is deliberate. It is also
the single most dangerous button in the app for a Tor user, because it is the
one place this lens's "never direct" is broken by a tap. None of the three
directions draws that screen. **Whichever direction wins must draw `8b`
twice, as Tor with a clearnet host (button present, as outline-danger, with
"This site will see your real IP") and as Tor with an onion (button absent).**
This applies equally to all three directions and decides nothing between them.

**Shared finding 2 (`10c`'s "Stored data wiped · 3 MB") is dormant today. I
downgrade it from a live channel to a latent one.**
`workspaceStorageServiceProvider` is `FakeWorkspaceStorageService()`
(`lib/ui/features/workspaces/view_models/providers.dart:20–21`), and that
fake returns `0` for every workspace
(`lib/domain/services/workspace_storage_service.dart:16`). So on a device
every vault reads "0 MB", and C's own note at `direction-c-rooms/screens.html:854`
admits it ("the device reads 0 MB"). The real vault and the decoy are
identical, so there is no tell today. I was also wrong that A and B leave the
size out. All three draw it in `10a`'s meta line: A at
`direction-a-daylight/screens.html:912` ("6 sites · cookies kept · 12 MB"),
B at `direction-b-instrument/screens.html:876`, and C at
`direction-c-rooms/screens.html:860`. The risk is the day someone wires a
real `bytesFor`. A lightly used decoy then reads "0 MB" next to a real vault's
"12 MB". The winning spec should carry a rule that a real byte count needs a
threat-model ruling first. This is neutral between directions.

**Shared finding 1 (the `2d` "identical in both vaults" captions) stands.**
A's caption still reads "Identical in both vaults"
(`direction-a-daylight/screens.html:572`), and the screen under it draws the
VAULT section. That section exists only when `decoy_configured` is true, and
that flag is written to the **main** vault only
(`lib/ui/features/setup/view_models/setup_controller.dart:71`). In the decoy,
`decoyEnabledProvider` (`settings/view_models/providers.dart:51`) reads false.
The failing case: an implementer who takes the caption literally hard-codes
VAULT on, and the decoy's Settings then reads "Decoy vault · on". This is a
spec-text fix in all three directions.

## Direction A — Daylight

**Shield colour: sharpened.** The shield is drawn in `accent` in every pill
in the file. The rule is `.inpill.shield { color: var(--accent) }`
(`screens.html:199`), applied at lines 418, 438, 539, 705, 849 and 880. Its
glyph is a shield **with a checkmark** (`screens.html:334`, path
`M9 12l2.2 2.2L15.2 10`). `TOKENS.md:44` gives the trigger as "the shield
when protections are on". Nothing defines "on". `6c` has three switches
(Block WebRTC, trackers and ads, anti-fingerprinting) plus a three-step
level, and no "off" shield is drawn anywhere. The failing case: the owner
turned trackers off on a decoy site, or a site's level is Standard. If "on"
means all of them, that pill shows a grey shield where the real vault's sites
show a green check. That is exactly the protection grade that DuckDuckGo
retired. A coercer who glances at the screen reads it as "this person
protects some sites and not others" without opening anything. A green check
at 6.38:1 (`#1D6B57` on `#FFFFFF`) is the most conspicuous thing in the
light pill. **Fix:** draw the shield in `ink2` always, or by level as B
does. The A advocate already concedes B's stricter jade budget (round 1, §5).
This is the same concession applied to one more element.

**Bystander brightness: withdrawn as an objection.** A's light page `#EBEEE8`
against B's ink `#121110` is 16.10:1 in luminance, so A is far more visible
across a dark room. But the A advocate's point holds. The theme follows
`platformBrightness` only, so an owner who cares sets the phone to dark and
gets A's dark theme, which is as quiet as B. That is a choice the owner makes,
it is the same in both vaults, and it is not a tell.

## Direction B — Instrument

**"Loud when different" (`BRIEF.md:64–69`): narrowed, not blocking.** The
words in the readout are the route label that the app already shows today.
`topBarRouteLabel` (`route_display.dart:9–13`) renders `''` for direct,
`Tor` and `SOCKS5`/`HTTP`, and throwaways already read `THROWAWAY · TOR`
(`address_suggestion.dart:43`). B adds the case outline (solid or broken),
which is a shape at 24 dp and not readable from across a room. So B adds no
new channel at a distance. What remains is the same for all three: a coercer
who saw `Tor` in the owner's pill and then finds a decoy with only direct
sites has a mismatch. That is a decoy-curation problem, and no visual design
can solve it. **Withdrawn as a B-specific objection.**

B's advocate also claims that "nothing depends on which vault is open". I
checked this against `screens.html:1218–1249` and 436–480. `3b` uses the same
widgets as `1b`, and the lock marks on `4c`, `9b` and `9c` are the same case.
The claim holds.

## Direction C — Rooms

**Room colour readable at a distance: sharpened, and it is still the most
serious finding.** The C advocate answers that "the colour comes from the
workspace's own marker, which both vaults store". That is true only for
**flagged** workspaces. `resyncDecoy` skips any workspace without
`showInDecoy` (`lib/data/repositories/decoy_provisioner.dart:101`,
`if (!workspace.showInDecoy) continue;`). So a real-only workspace's hue has
no counterpart in the decoy. The hue covers the whole browsing screen. That
includes the status bar (`.sys` tinted at `screens.html:335`, 385, 488, 646,
695, 825, 1059 and 1088), both bars (`.chrome-top` and `.chrome-bot` on
`var(--tint)`, lines 149 and 160) and the 3 dp page frame. TOKENS §1.3 lists
`2b`, `8a`, `8b`, `8c` and `6c`'s header as permitted places.

The rooms differ **only by hue**. Fern tint `#C7E2D1` against Plum tint
`#ECD6E8` measures 1.01:1, and in dark `#192B22` against `#34222E` measures
1.00:1. Hue is exactly what a person with normal colour vision tells apart
across a café table, when no text can be read there. C's own success test
says so: Dana "can tell it is her green Personal room without reading the
address" (`BRIEF.md:39`). Failing scenario: the owner reads in her Plum
"Clinic" workspace on the bus. Later the coercer says "open the purple one".
The decoy has no purple room, because Clinic was never flagged.

**One-colour decoy: sharpened.** At setup, `seedIfEmpty(mainDb)`
(`setup_controller.dart:70`) gives the real vault Personal 0, Work 1 and
Ephemeral 4 (`app_database.dart:318–327`), which are Fern, Lake and
Graphite. A "Pick after setup" decoy gets only `ensureWorkspace`'s Personal
with marker 0 (`app_database.dart:303`). C's `3b` note
(`screens.html:1255`) treats "it is a Fern room like the real vault's" as
parity. It is parity for **one** room out of three. Under C, the difference
between a vault with one workspace and a vault with three is no longer one
chip against three chips. It becomes a monochrome app against a polychrome
one, on every screen including `2c`'s cards (`.ccard.bg`, line 216).

**Status: blocking.** The minimum to ship would be the following. (a) The
container chrome (`2b`, `8a`–`8c`) stays neutral, and room colour is confined
to `1b` chips/panels, `2c` and `10a`/`10b`. (b) A seeding or re-sync change
so that an empty decoy gets the same three markers as the real vault's seed.
No direction proposes (b), and it is a change to the data layer. C's
advocate calls rule-breaking "the point" (round 1, closing). That holds for
dark-only and for hairlines, but not for this one.

## Bottom line (threat-model lens)

1. **B — Instrument. Best.** Blocking issue: **none.** (It is shared by all
   three, but it must be drawn: `8b` for Tor on a clearnet host still offers
   "Open without the tunnel".)
2. **A — Daylight.** Blocking issue: **the shield in the pill is jade with a
   check while "protections are on"** (`screens.html:199`, `TOKENS.md:44`).
   That is an undefined binary grade that can differ between the real
   vault's sites and the decoy's. Drawing it in a neutral tone, or by level,
   fixes it.
3. **C — Rooms. Worst.** Blocking issue: **workspace hue fills the browsing
   chrome and is readable at a distance (Fern vs Plum tint 1.01:1, so the
   difference is in hue alone).** Unflagged workspaces have no colour
   counterpart in the decoy (`decoy_provisioner.dart:101`), and an empty
   decoy is one colour by construction (`app_database.dart:303` against
   `318–327`).

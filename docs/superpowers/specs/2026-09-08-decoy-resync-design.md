# Decoy re-sync — design

**Status:** Approved by the user 2026-09-08.

## Problem

`provisionDecoy(from:, into:)` (`lib/data/repositories/decoy_provisioner.dart`)
copies every workspace/site flagged `showInDecoy: true` from the real vault
into the decoy vault, giving each copied site a fresh `profileId`. It runs
exactly once today, inside `SetupController.complete` — the only moment the
app ever holds both vaults' data keys in memory at once, because the two-PIN
setup wizard collects both PINs back to back.

After setup, there is no reachable way to run it again. If the owner flags a
new site for the decoy, un-flags one, or the decoy's contents just go stale
next to the real vault's, nothing updates the decoy store. Plan 6's own
Known Gaps section named this directly and pointed at `provisionDecoy` as
the function a future flow should call — its handoff note names the
function `syncToDecoy(site:, decoyDatabase:)`, but that name and signature
never actually existed in the tree; this design corrects that and builds
against what's really there.

## Prerequisite: `decoyEnabled` has to become real

`SettingsScreen`'s `decoyEnabled`/`decoySiteCount` props are hardcoded
`false`/`0` at the one place that constructs the screen for real
(`dashboard_screen.dart`'s `_SettingsRoute`) — a pre-existing gap that
predates this design (the biometric-unlock plan's own stated boundary:
"every other row on that screen stays exactly as inert as it is today").
Left as-is, this new row would be exactly as unreachable as the VAULT
section's existing rows already are, in a shipped build.

Confirmed with the user: this plan also makes `decoyEnabled` real, since
otherwise the feature this design builds is unreachable outside tests.
`SetupController.complete` gains one write — a `decoy_configured` bool in
the real vault's own `app_settings` table (the same generic key-value
table `biometrics_enabled` already lives in; no schema change) — set to
`decoyPin != null`. `decoyEnabled`/`decoySiteCount` become real
`FutureProvider`s (`decoy_configured`'s value; a live count of sites with
`showInDecoy: true`) that `_SettingsRoute` reads instead of the hardcoded
literals. This only makes the VAULT section's visibility correct — it does
not build out `workspaces`, `scripts`, or `decoySites`'s own destination
screens, which remain the no-ops they are today.

## Decision: a Settings row that briefly opens the decoy vault under its own PIN

A new row, "Re-sync decoy now," in `SettingsScreen`'s existing VAULT
section (shown only when `decoyEnabled`, same as every other row there).
Tapping it pushes a dedicated PIN-entry screen. A correct decoy PIN opens
the decoy vault's `AppDatabase` for the duration of one sync call, then
closes it immediately — the decoy's key and connection never outlive that
one operation, and nothing about them is ever cached in Riverpod state the
way the real vault's session is.

This deliberately does not attempt to distinguish whether the *currently
open* session is the real vault or the decoy vault — `SettingsScreen`
already cannot tell (see its own doc comment), and fixing that is out of
scope here. A decoy session can reach this new row exactly as it can reach
every other row today. That is an accepted, pre-existing limitation, not
something this design introduces.

## PIN verification

The new screen is built from the existing low-level `PinDots`/`PinKeypad`
core widgets (`lib/ui/core/widgets/`), not `LockBody` — `LockBody` is
coupled to `LockController`/`SessionController`'s app-wide lock state
machine (resume moods, grace-period timers, biometric resume), none of
which applies to a one-off PIN check triggered from inside Settings.

The entered PIN is checked with the existing `VaultUnlocker.attempt(pin:,
slots:, gate:, now:)` — the same timing-safe, fixed-order matcher the real
lock screen uses, fed from the same `VaultStore.slots()`/`VaultStore.gate()`
this app already persists to `meta.bin`. Three outcomes:

- **Matches `VaultId.b` (the decoy):** proceed — open the decoy database
  and run the sync.
- **Matches `VaultId.a` (the vault already open in this session) or
  matches nothing:** both cases render the identical generic "wrong PIN"
  state. Re-entering the main PIN by mistake is not given a distinct
  message, for the same reason `VaultUnlocker` never short-circuits: this
  is the same PIN-guessing surface as the lock screen, and it should leak
  no more information than a typo does there.
- **Throttled:** shown as the current lockout would be on the lock screen.

Every wrong or throttled attempt calls `VaultStore.saveGate()` exactly as
`SessionController.unlock` does today — this flow shares the lock screen's
attempt-gate/lockout counter rather than getting a second, independent one.
A correct decoy-PIN entry resets that shared gate, same as any other
correct unlock.

## Sync semantics: add and remove

Today's `provisionDecoy` only upserts; it never deletes. This design turns
it into a true two-way sync: after it runs, the decoy vault holds exactly
the currently-flagged workspaces/sites — no more, no less — while never
touching anything the owner added directly while browsing inside the decoy
session itself.

The mechanism relies on an invariant `provisionDecoy` already has:
every copied row keeps the **same `id`** as its real-vault source (only a
site's `profileId` is regenerated). Nothing else in the app ever writes a
decoy-vault row using a real-vault id — a site or workspace created while
browsing inside the decoy session gets its own freshly generated id, from
the same id-generation path `AddSiteScreen`/`WorkspaceFormScreen` use
everywhere else. So: any decoy-vault row whose id matches a real-vault id
is sync-owned, full stop; any decoy-vault row whose id does not is
decoy-original content sync must never touch.

`resyncDecoy(from:, into:)` (replacing `provisionDecoy` as the function
this flow calls — see Task breakdown) does, in order:

1. Read every real-vault workspace and site (not filtered by the flag) —
   this is the full universe of ids sync is ever allowed to own.
2. Upsert every currently-flagged workspace/site into the decoy vault. For
   a site with no existing decoy-side row (a genuinely new addition), mint
   a fresh `profileId`, exactly as `provisionDecoy` does today. For a site
   that already has a decoy-side row (already synced by a prior call),
   **keep that row's existing `profileId`** rather than regenerating it —
   `profileId` is what Plan 3's WebView isolation keys cookies, cache, and
   history to, so regenerating it on every call would silently wipe an
   unchanged site's accumulated decoy browsing state each time, working
   against the entire point of a decoy that looks lived-in. This departs
   from `provisionDecoy`'s one-shot behavior deliberately; `provisionDecoy`
   itself is unaffected since every site is new on that one-shot path.
3. Delete every decoy-vault workspace whose id is in that owned universe
   but is no longer flagged. `sites.workspace_id REFERENCES workspaces(id)
   ON DELETE CASCADE` (already enforced — `PRAGMA foreign_keys = ON` is set
   in `AppDatabase.open`) removes that workspace's sites automatically, so
   this step does not need to touch them itself.
4. Delete every decoy-vault site whose id is in the owned universe, whose
   *workspace* is still flagged (kept by step 2/3), but whose id itself is
   no longer flagged.
5. Leave alone every decoy-vault row whose id is not in the owned universe
   at all.

An explicit "synced from" marker column was considered and rejected: it
needs a schema migration for something the existing id-copying invariant
already guarantees, and nothing else in the schema currently distinguishes
row provenance this way — adding one column for one feature contradicts
this codebase's existing minimal-schema-change pattern (see `CLAUDE.md`'s
"no code generation, hand-written mappers" stance on the same instinct).

## UI feedback

Success closes the PIN screen, shows a SnackBar ("Decoy vault synced"), and
returns to `SettingsScreen`. Failure keeps the PIN screen up in its wrong-PIN
state (reusing `PinDots`' existing `error: true` treatment) so the user can
retry, subject to the shared lockout above. No dedicated confirmation
screen — this matches how every other Settings action in this app behaves
(e.g. biometrics toggle, `SettingsController.setBiometricsEnabled`), and
the design spec for search/biometric unlock both avoided inventing new
full-screen moments for actions this small.

## What this does not change

- `SettingsScreen` still cannot tell which vault is open — this row is
  exactly as reachable from a decoy session as every other row already is.
  A future plan to fix that (per the code's own doc comment) is unaffected
  by and independent of this one.
- `provisionDecoy`'s call site inside `SetupController.complete` is
  unaffected in behavior (a first sync from an empty decoy vault deletes
  nothing, since step 3/4 above only ever remove rows the decoy vault
  already has) — whether that call site is renamed to call `resyncDecoy`
  instead, or `provisionDecoy` is kept as a thin alias, is an implementation
  detail for the plan, not a design decision.
- No change to `VaultStore`, `VaultUnlocker`, `CryptoService`, or any
  Kotlin/native code — everything this design needs already exists at
  that layer.

## Known gaps this design deliberately leaves

- Does not fix `SettingsScreen`'s inability to distinguish real vs. decoy
  sessions (see above) — pre-existing, out of scope, confirmed with the
  user during brainstorming.
- No progress indicator or synced-item count in the success SnackBar
  beyond the fixed "Decoy vault synced" copy — matches the low-key
  treatment other Settings actions get, and avoids inventing UI copy no
  spec calls for.
- Does not address `provisionDecoy`'s existing lack of a test for the
  workspace-becomes-unflagged-while-its-sites-stay-flagged edge case,
  beyond what this design's own task tests exercise for `resyncDecoy`.

## Testing

- Unit tests for `resyncDecoy`'s full add/keep/delete/leave-alone matrix
  (four cases from the mechanism section above), extending
  `test/data/decoy_provisioner_test.dart`'s existing fixture style.
- A `VaultUnlocker`-level test (or a thin controller-level test reusing the
  existing pattern in `test/ui/features/settings/settings_controller_test.dart`)
  confirming a decoy-PIN match opens the decoy vault and runs the sync,
  and that a same-vault match or a non-match both produce the identical
  generic rejection.
- A widget test for the new PIN-entry screen's success and wrong-PIN
  states, following `test/ui/features/lock_body_test.dart`'s existing
  pattern for `PinDots`/`PinKeypad`-based screens.
- No device/instrumentation test needed — nothing in this design touches
  the Kotlin/Android layer.

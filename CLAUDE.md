# Container — Isolated Web Container (Android)

A privacy-first Android browser where every site runs in its own isolated
"container": separate storage, per-site proxy routing, filtering, and a
two-vault decoy PIN system. Flutter UI, Kotlin platform layer.

## Source of truth for design

- `Sandbox Container -canvas-.dc.html` — **authoritative spec.** 32 screen
  blocks, each with an `id` (e.g. `id="1b"`). Exact copy, colours, sizes,
  layout. When anything conflicts, this file wins.
- `Sandbox Container.dc.html` — same screens, print layout. Not authoritative.
- `app-design.pdf` — rendered version of the canvas file, for skimming only.

Never paraphrase, re-capitalise, or "improve" user-facing copy — it is
transcribed verbatim from the HTML. If a string isn't in the spec, that's a
design question to ask about, not to invent.

## Where the work is planned

`docs/superpowers/plans/` holds one implementation plan per subsystem,
written with the `superpowers:writing-plans` skill and meant to be executed
with `superpowers:subagent-driven-development` or `superpowers:executing-plans`.
Each plan ships working, tested software on its own.

| Plan | File | Status | Covers |
|---|---|---|---|
| 1 — Foundation | `2026-08-30-isolated-web-container-01-foundation.md` | Written | Design tokens/typography, dashboard (`1b`), SQLite, domain model. Import-path bug (#1) fixed 2026-08-30. |
| 2 — Entry and identity | `2026-08-30-isolated-web-container-02-entry-and-identity.md` | Written | Setup wizard, lock screen, decoy vault, panic wipe, settings, PIN-derived crypto, lock states (`9a`–`9c`). Missing glue code (LockController, LockScreen, SetupController.complete, SetupFlow, session_controller.dart) filled in 2026-08-30 by flutter-app-1e — see Known cross-plan issues below, issue #2 fixed, plus the new Rulings section. |
| 3 — The container | `2026-08-30-isolated-web-container-03-container.md` | Written | Kotlin platform layer, per-site WebView isolation, filtering proxy, container/switcher/add-site screens. Phantom `openVault()` bug (#4/#7) fixed 2026-08-30 — see note below, the original diagnosis of that issue was inaccurate. Task 5 Step 6's `fetchThrough` was a `TODO_IMPLEMENTED_IN_STEP_7` sentinel with Step 7 only describing it in prose (a placeholder violation) and calling `ProxyProbe.reachable()` with no host/port, so it could never check the right proxy — fixed 2026-08-30 (flutter-app-42) with a real HTTP-over-socket implementation and a per-`host:port` cached `ProxyProbe`. |
| 4 — Failure states & in-page moments | `2026-08-30-isolated-web-container-04-failure-states-and-in-page-moments.md` | Written | Permission ask, reader mode, site sheet, row menu, held download, Today log, proxy-unreachable, tunnel-dropped |
| 5 — Workspaces and scripts | `2026-08-30-isolated-web-container-05-workspaces-and-scripts.md` | Written | Workspace list/create/delete (`10a`–`10c`), filter lists + script library + script editor (`10d`/`10e`). Turn 9 (`9a`–`9c`) is Plan 2's, not this plan's — see its own header note. |
| — — Integration | *(not yet written)* | Not started | Wiring Plan 4's pure screens to Plan 3's live WebView events (see Unassigned Work below) |

Each plan's own **Handoff** and **Known gaps** sections at the bottom are the
authoritative record of what it produces for later plans and what it
deliberately leaves unbuilt — check those before assuming something exists.

## Tech stack

Flutter stable / Dart 3, `flutter_riverpod`, `sqflite` (+ `sqflite_common_ffi`
for host tests), `path`, `path_provider`. Plan 2 replaces `sqflite` with
`sqflite_sqlcipher` for encrypted stores and adds `local_auth`, BouncyCastle
(Argon2id + AES-GCM via Kotlin plugin), and the Android Keystore. Plan 3
adds `androidx.webkit:webkit:1.12.0` (multi-profile WebView API) and raises
`minSdk` to 29. Fonts Figtree + IBM Plex Mono, bundled as assets, never
fetched at runtime. No code generation anywhere (no `build_runner`,
`freezed`, `drift`) — hand-written mappers only.

## Global constraints (apply everywhere, not just Plan 1)

- **Android only, dark theme only.** No light theme, no toggle.
- **No network requests of the app's own.** No account, sync, analytics, or
  telemetry, ever.
- **Jade `#7FC8A9`** means live state or the single affirmative action on a
  screen — never decorative, never more than one per screen.
- **Hairline dividers, not cards.** 1px white-alpha lines separate rows.
- **IBM Plex Mono for anything technical**, Figtree for everything else.
- **Two-vault decoy model, not a filter.** Two separate encrypted SQLite
  stores selected by which PIN unwraps them; no query anywhere filters rows
  for privacy, and no aggregate ever counts across both vaults.
- **The interceptor never falls back to direct.** A site set to a proxy that
  becomes unreachable is refused, never silently sent unproxied.
- **Threat model is coerced unlock**, not forensic disk imaging — the decoy
  vault must be convincing to a person compelling an unlock, not to someone
  imaging the device.

Each plan repeats the subset of these it depends on in its own "Global
Constraints" section — that repetition is intentional so a plan can be read
standalone.

## Known cross-plan issues (must fix before executing)

A gap analysis on 2026-08-30 found the following. Fix these in the plan
files before running them, not during.

### Blocking

1. **✅ Fixed 2026-08-30. Plan 1 Task 6 Step 11: wrong import paths in
   `main.dart`.** The plan wrote `import 'ui/features/dashboard/dashboard_screen.dart'`
   and `import 'ui/features/dashboard/providers.dart'`, but the file
   structure puts them at `dashboard/views/dashboard_screen.dart` and
   `dashboard/view_models/providers.dart`. Fixed directly in the plan file.

2. **✅ Fixed 2026-08-30 (by flutter-app-1e). Plan 2 Task 8 (not Task 7 —
   that reference was stale): `session_controller.dart` was never written.**
   `AppGate` references `sessionProvider`, `SessionUnconfigured`,
   `SessionLocked`, `SessionOpen` and `SetupFlow`, but the plan only
   described them in prose and never provided implementation code. Now
   written in full — `sealed class Session`, `SessionController extends
   Notifier<Session>` with `unlock`/`graceExpired`/`completeSetup`, plus the
   supporting providers (`vaultStoreProvider`, `cryptoServiceProvider`,
   `documentsDirectoryProvider`, `vaultOpenerProvider`,
   `initialSessionProvider`, `setupControllerProvider`). `LockController`
   (Task 5) and `SetupController.complete` (Task 6) were also missing and
   are now written; `LockScreen` and `SetupFlow` — which the original plan
   implied belonged in Tasks 5/6 — were built in Task 8 instead, because
   both need `sessionProvider`, which only exists once Task 8's
   `session_controller.dart` does. Building them earlier would have left
   Tasks 5/6 unable to compile standalone. See Plan 2 Task 8 Steps 6–22 for
   the full diff, and "Rulings recorded while fixing issue #2" below for the
   design calls made along the way.

3. **Plan 1 `Vault` vs Plan 2 `VaultId` naming collision — still open.**
   Plan 1 defines `enum Vault { a, b }` in `app_database.dart`; Plan 2
   defines `enum VaultId { a, b }` in `vault.dart`. Same concept, two names.
   Plan 2 must consolidate — either remove Plan 1's `Vault` enum or alias
   it. Fixing issue #2 needed a file path per `VaultId`, and deliberately
   did *not* fold this resolution in — `session_controller.dart`'s
   `vaultDatabasePath` bridges the two enums with an index lookup
   (`Vault.values[vault.index]`) rather than resolving the collision, so
   that closing issue #2 didn't also require a Plan 1 change out of its
   scope. Whoever picks up issue #3 should delete that bridge once a single
   enum exists.

4. **✅ Fixed 2026-08-30 (by flutter-app-42). Plan 3 Task 1's schema
   migration and its test both targeted a phantom `openVault()` function
   that was never defined in any plan.** The original diagnosis of this
   issue (below, struck through) named the wrong function: Plan 2 never
   defines or calls `openVault()` anywhere — grep confirms zero hits. Plan
   2's real function is `openEncrypted({path, dataKey})`, and Plan 1's
   `AppDatabase.open` itself is only extended with an optional `password`
   parameter, never replaced. The actual bug was Plan 3 Task 1's test
   calling a phantom `openVault(Vault.a, path:, factory:)` that no plan ever
   defined. Fixed by swapping Plan 3 Task 1 to `AppDatabase.open` +
   `seedIfEmpty`, and giving the 8 seeded `Site(...)` calls a `profileId`
   (see issue #5) in that same task.
   ~~Plan 3 Task 1 schema migration targets Plan 1's `AppDatabase.open`, but
   Plan 2 has already replaced it with encrypted `openVault()` using
   `sqflite_sqlcipher`. Plan 3's `onUpgrade` code must be reworked to apply
   inside Plan 2's `openVault()`, not Plan 1's `AppDatabase.open`.~~

5. **Plan 3 Task 1 makes `Site.profileId` required**, breaking Plan 2's call
   sites (decoy provisioner, tests). Plan 3 Step 7 acknowledges this for
   Plan 1 but not for Plan 2.

### Ordering / dependency

6. **Panic handoff is circular between Plan 2 and Plan 3.** Plan 2 creates
   `PanicService` as an interface; Plan 3 creates `wipe(profileId)`. Panic
   must call wipe *before* destroying data keys. No plan specifies how
   `PanicService` gains access to the profile-wipe capability after Plan 3
   ships. Note: Plan 2's `PanicScreen`/`PanicService` (Task 7) are also not
   wired into `AppGate` yet — `AppGate`'s `switch` has no case for a
   panicked state. Out of scope for issue #2's fix; flagged here so it
   isn't mistaken for done.

7. **✅ Fixed 2026-08-30 (by flutter-app-42).** ~~Plan 3 Task 1's test calls
   `openVault`, which is a Plan 2 concept. Plan 3's header says "Depends on
   Plan 1" but actually also requires Plan 2.~~ Same fix as #4 — the test's
   phantom `openVault` call is gone.

### Implementation bugs found while executing (2026-08-31)

Found and fixed while three sessions executed Plan 1 Task 4/5 and Plan 2
Task 1 in parallel off `plan-01-foundation`, before merging back.

8. **✅ Fixed 2026-08-31 (by flutter-app-c7).** Plan 2 Task 1's reference
   code for `AttemptGate.recordFailure` only re-locked on failure counts
   that were exact multiples of `maxTries` (`total % maxTries == 0`), so a
   6th failure arriving after the 5th failure's lockout had already expired
   did not re-lock — failing the plan's own test "the penalty repeats for
   every further failure". Fixed in the plan file to `total >= maxTries`.

9. **✅ Fixed 2026-08-31 (by flutter-app-1e).** Plan 1 Task 5's reference
   code for `dashboard_body.dart` imported `dashboard_view.dart` as if it
   were in the same directory (`views/`), but Task 5's own Step 3 puts
   `dashboard_view.dart` in `view_models/` — `session_row.dart`'s Step 4
   code already imported it correctly as `../view_models/dashboard_view.dart`.
   Fixed the same way in the plan file.

## Rulings recorded while fixing issue #2 (2026-08-30, flutter-app-1e)

Plan 2 Task 8 now documents these inline (Step 6 and Step 17); summarized
here for anyone scanning this file first.

- **`LockMood.welcomeBack` (spec `9b`) is reachable.** The original Task 8
  draft silently returned to the dashboard on any return within the grace
  period, never showing `9b` at all — dead code despite Task 5 fully
  building and testing it. Spec turn 9 lists exactly two on-resume outcomes
  (`9b`, `9c`), both lock-shaped; there is no "no screen" third outcome.
  `ReturnDestination.board` now means "come back to a screen that still
  trusts your open sessions" (`9b`), never "skip the lock screen entirely."
- **Decoy PIN entry has no screen of its own in the spec.** `4a`/`4b`/`5a`
  are the only three setup ids and `4b`'s step bar is fixed at three
  segments. `SetupFlow` reuses `SetupPinScreen` a second time for the decoy
  PIN rather than inventing a fourth screen or copy the spec never
  specified; the visible cost is the step-progress bar reading "step 1 of
  3" again during that reuse instead of a fourth segment. A real dedicated
  screen is a spec question, not a code fix.
- **`9b`'s "one tap to resume" caption is not literal.** `LockBody` (Task 5,
  already built and tested before this was noticed) renders the same
  six-dot row and full keypad for `welcomeBack` as every other lock mood.
  The built/tested widget was treated as authoritative over the option
  caption; resuming within the grace period still takes a full six-digit
  PIN. If literal one-tap resume is wanted, that is a `LockBody` change,
  not something invented at the wiring layer.

## Unassigned work (no plan owns these)

These items fall between plans. They need to be assigned to a plan (or a new
integration plan) before work on Plans 3–5 is complete.

- **Search screen.** The dashboard footer has a search button (`onSearch`)
  wired to nothing. No plan or spec screen covers search.
- **Wiring Plan 4's screens to Plan 3's events.** Permission requests,
  download holds, tunnel failures, reader extraction, Today log categories —
  Plan 4 builds pure widgets, Plan 3 builds the WebView. Nothing connects
  them.
- **Reader mode extraction.** `ReaderArticle` is rendered (Plan 4) but
  never produced. Turning a live page into structured content is unbuilt.
- **FilterEngine category tagging.** Plan 3's `FilterEngine` counts total
  blocks; Plan 4's Today log (`5c`) needs per-category breakdowns.
- **Download interception.** `HeldDownloadSheet` renders a download; nothing
  hooks Android's `DownloadListener`.
- **SiteSheet toggle persistence.** Toggling force-dark or desktop-view in
  `6c` doesn't write back to `Site`. No plan specifies the caller.
- **Biometric unlock.** Plan 2's settings shows the toggle; the actual
  Keystore-gated key mechanism is described in one sentence and unassigned.
- **Decoy auto-sync after provisioning.** Adding a `showInDecoy` site to
  the real vault after setup never copies it into the decoy store.

## Working on this repo

- No git repo initialized yet, and Flutter isn't installed on this machine as
  of the last check — Plan 1 Task 1 Step 1 bootstraps both.
- Multiple Claude sessions may be working here in parallel; check in before
  starting implementation work on a plan another session may already have
  picked up (`ListAgents` / cross-session message), since there's no git
  history yet to reveal who's touched what.
- When resuming an unfinished plan, look for a `<!-- PART-2-APPENDS-HERE -->`
  style marker or a missing "Known gaps"/"Handoff" section at the end — that
  means the plan is incomplete, not that the work described in it is done.
- **Read "Known cross-plan issues" above before executing any plan.** Several
  plans contain blocking errors (wrong imports, missing files, schema
  migration targeting the wrong function) that must be patched first.

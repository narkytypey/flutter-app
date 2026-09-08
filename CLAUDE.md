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
| 2 — Entry and identity | `2026-08-30-isolated-web-container-02-entry-and-identity.md` | **Done** (2026-09-02) | Setup wizard, lock screen, decoy vault, panic wipe, settings, PIN-derived crypto, lock states (`9a`–`9c`). **Correction, 2026-09-01:** this row previously said the missing glue code (LockController, LockScreen, SetupController.complete, SetupFlow, `session_controller.dart`) was filled in 2026-08-30 by flutter-app-1e. That was never true of this checkout at the time — verified independently by flutter-app-9c and flutter-app-f5 on 2026-09-01, and by the same-day `CLAUDE_REPORT.md` audit. **Update, 2026-09-04:** all 8 tasks are now genuinely done. Tasks 1/2/4/5/6 as recorded above; Tasks 3 (Android crypto plugin — `CryptoPlugin.kt`), 7 (panic, see issue #6), and 8 (settings/lifecycle/session gate — `session_controller.dart`, `app_gate.dart`) landed 2026-09-02 in commits `261a3fd`/`883e16f`/`26540fc`, one day after this row's 2026-09-01 "remain open" note — that note was stale by the time it was read, not wrong when written. Re-verified 2026-09-04: `flutter analyze` clean, `flutter test` 223/223 passing. |
| 3 — The container | `2026-08-30-isolated-web-container-03-container.md` | Written | Kotlin platform layer, per-site WebView isolation, filtering proxy, container/switcher/add-site screens. Phantom `openVault()` bug (#4/#7) fixed 2026-08-30 — see note below, the original diagnosis of that issue was inaccurate. Task 5 Step 6's `fetchThrough` was a `TODO_IMPLEMENTED_IN_STEP_7` sentinel with Step 7 only describing it in prose (a placeholder violation) and calling `ProxyProbe.reachable()` with no host/port, so it could never check the right proxy — fixed 2026-08-30 (flutter-app-42) with a real HTTP-over-socket implementation and a per-`host:port` cached `ProxyProbe`. |
| 4 — Failure states & in-page moments | `2026-08-30-isolated-web-container-04-failure-states-and-in-page-moments.md` | Written | Permission ask, reader mode, site sheet, row menu, held download, Today log, proxy-unreachable, tunnel-dropped |
| 5 — Workspaces and scripts | `2026-08-30-isolated-web-container-05-workspaces-and-scripts.md` | Written | Workspace list/create/delete (`10a`–`10c`), filter lists + script library + script editor (`10d`/`10e`). Turn 9 (`9a`–`9c`) is Plan 2's, not this plan's — see its own header note. |
| 6 — Integration | `2026-09-02-isolated-web-container-06-integration.md` | Written 2026-09-02 | Wires the five plans into one navigable app: `ContainerRoute` navigation shell, discriminated native events (permission asks, held downloads, tunnel-drop) reaching Plan 4's screens, per-category `FilterEngine`/`BlockedTallyRecorder` feeding a live Today log, `SiteSheet` toggle persistence, and the decoy-sync correction. Implements `docs/superpowers/specs/2026-09-02-integration-design.md` (approved by the user 2026-09-02); three places deliberately correct or narrow that spec against what the tree can actually do — see the plan's own header. 7 tasks. Being executed 2026-09-04 by a peer session (flutter-app-0f) in its own worktree. Explicitly leaves search and biometric unlock unbuilt — see Unassigned Work below. |
| 7 — Search | `2026-09-04-isolated-web-container-07-search.md` | **Done** (2026-09-08) | Wires `DashboardFooter`'s long-dead search button to a real screen: `SiteRepository.all()`, a `searchResults()` join/filter/sort across every workspace in the open vault, and a pure `SearchScreen`. Implements `docs/superpowers/specs/2026-09-04-search-screen-design.md` (brainstormed and approved by the user 2026-09-04) — that spec itself stands in for the missing canvas screen block, since search was never actually designed anywhere. 5 tasks, all executed; final-review fix wave (2026-09-08) made tapping a search result push a real `ContainerRoute` (it previously only marked the site open and popped back to the dashboard) and fixed `allSitesProvider` never being invalidated, so search now sees adds/deletes/touches made after it first loaded. |
| 9 — Decoy re-sync | `2026-09-08-decoy-resync.md` | **Done** (2026-09-08) | Gives the owner a reachable "re-sync with the decoy PIN" flow from Settings, replacing the setup-time-only `provisionDecoy` with `resyncDecoy` (`lib/data/repositories/decoy_provisioner.dart`) — a real add-and-remove sync that preserves an already-synced site's `profileId` so its decoy-side cookies/history survive repeated syncs. Persists `decoy_configured` on the real vault (`SetupController.complete`) and wires it to `decoyEnabledProvider`/`decoySiteCountProvider`, so `SettingsScreen`'s VAULT section — hardcoded invisible before this plan — now actually shows or hides based on whether a decoy was configured. Adds `DecoyResyncPinScreen` (pure widget, reuses `PinDots`/`PinKeypad`) and `DecoyResyncRoute` (reuses `LockController`, calls the new `SettingsController.resyncDecoyVault`, which checks the entered PIN against both vault slots via the existing `VaultUnlocker`/attempt-gate before opening the decoy vault just long enough to sync and close it). Implements `docs/superpowers/specs/2026-09-08-decoy-resync-design.md`. 5 tasks, all executed. |

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

3. **✅ Fixed 2026-08-31 (by flutter-app-6d, as part of Plan 2 Task 4). Plan 1
   `Vault` vs Plan 2 `VaultId` naming collision.** Plan 1 defined
   `enum Vault { a, b }` in `app_database.dart`; Plan 2 defines
   `enum VaultId { a, b }` in `vault.dart`. Same concept, two names. Task 4's
   own Step 6 was written to fix exactly this, so it was resolved in the same
   commit as that task rather than separately: `Vault` is deleted,
   `vaultFileName` now takes `VaultId`, and the two call sites the plan
   didn't list (`lib/main.dart`'s `Vault.a`, and `test/data/repositories_test.dart`'s
   two `Vault.a`/`Vault.b` uses) were fixed too, since the analyzer flagged
   both once the enum was gone. `session_controller.dart` (Plan 2 Task 8)
   does not exist yet in the tree, so there was no `vaultDatabasePath` bridge
   to delete — Task 8 will simply never need one.

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

6. **✅ Fixed 2026-09-02 (commit `883e16f`, "implement panic against real
   containers"). Panic handoff between Plan 2 and Plan 3.** ~~Plan 2 creates
   `PanicService` as an interface; Plan 3 creates `wipe(profileId)`. Panic
   must call wipe *before* destroying data keys. No plan specifies how
   `PanicService` gains access to the profile-wipe capability after Plan 3
   ships. Plan 2's `PanicScreen`/`PanicService` (Task 7) are also not wired
   into `AppGate` yet — `AppGate`'s `switch` has no case for a panicked
   state.~~ `lib/data/services/container_panic_service.dart`'s
   `ContainerPanicService.trigger()` now does exactly that ordering:
   `engine.close()` each live session (a profile can't be deleted while a
   WebView is attached to it), then `engine.wipeAll()`, then
   `closeDatabase()`/`destroyVaults()` — containers die first, while their
   ids are still readable, keys die last. Wired via `panicServiceProvider`
   in `lib/ui/features/container/view_models/providers.dart`, and `AppGate`
   (`lib/ui/features/shell/views/app_gate.dart`) now has a
   `SessionPanicked(:final report) => PanicScreen(...)` case. Verified
   2026-09-04: `flutter analyze` clean, `flutter test` 223/223 passing.

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

10. **✅ Fixed 2026-08-31 (by flutter-app-ce).** Plan 4 Task 7's widget test
    for the Today screen (spec `5c`) asserts on all four category rows and
    all four site rows plus the total block simultaneously, with no scroll.
    The default 800x600 `flutter_test` surface is shorter than that content,
    so the sliver list never builds the last row (`Webmail`) into the
    Element tree and `find.text` finds zero widgets for it — not a
    visibility issue, an existence one. Fixed by widening the test's
    surface (`tester.view.physicalSize`) before pumping, in both the plan
    file and the implementation.

11. **✅ Fixed 2026-08-31 (by flutter-app-ce).** `AppToggle` is produced by
    Plan 2 **Task 6** (setup wizard and decoy provisioning), not Task 5 (PIN
    primitives and lock screen) — every other plan that consumes it (Plan 4
    Task 5's site sheet, Plan 5's intro/Task 1/Task 2/Task 5) cited "Plan 2
    Task 5." Task 5 does not produce `AppToggle` at all; it produces
    `PinDots`, `PinKeypad`, `LockBody`, `LockController`. Also fixed a
    second, independent numbering slip in Plan 4's own intro: it called its
    own site-sheet task "Task 6" in the "Depends on" line when the task list
    has it as Task 5, and listed Task 5 among the tasks with "none of that"
    extra dependency even though Task 5 is the one that needs `AppToggle`.
    Fixed all references in the Plan 4 and Plan 5 doc files. This means
    Plan 4 Task 5 and Plan 5 Tasks 1/2/5/6 are gated behind Plan 2 Task 6
    (setup wizard), which itself needs Task 4 (`VaultStore`) — a longer
    chain than the old "Task 5" citation implied.

12. **✅ Fixed 2026-08-31 (by flutter-app-ce).** Plan 2 Task 5's `LockBody`
    widget test overflows a `RenderFlex` by 20px in the `wrong` and
    `afterTimeout` moods — same root cause as issue #10, a different
    symptom: the default 800x600 `flutter_test` surface is landscape-shaped
    and shorter than a real phone in portrait, and those two moods' extra
    footnote content doesn't fit the fixed `Expanded` region at that height.
    Verified a 400x800 portrait surface renders it with no overflow, so this
    is a test-canvas mismatch, not a real layout bug for the phone screens
    this app targets. Fixed by setting `tester.view.physicalSize` to a
    portrait size in `_pump`, in both the plan file and the test.

13. **✅ Fixed 2026-08-31 (by flutter-app-6d).** Plan 2 Task 4's own
    `vault_store_test.dart` reuses `FakeCrypto` from
    `test/domain/vault_unlocker_test.dart` (`show FakeCrypto`), but that
    fake's `randomBytes(length)` returned the same `List.filled(length, 7)`
    on every call — deterministic, not random. `VaultStore.provision` calls
    it once per salt, so vault A and vault B always got byte-identical
    salts, failing the plan's own test "the two slots have different
    salts." Separately, `FakeCrypto.deriveKek`'s simulated KEK length was
    `pin.length`-dependent (`'$pin|$saltJoin'.codeUnits`), so a 6-digit PIN
    and a 32-character generated `provisionUnopenable` PIN produced
    different-length wrapped keys — failing "both slots are the same size
    whether or not a decoy is real," the exact invariant the design depends
    on to keep a decoy indistinguishable from a real vault. Real Argon2id
    always emits a fixed-length key regardless of input length; the fake
    didn't model that. Fixed by making `randomBytes` counter-seeded (varies
    per call) and `deriveKek` a fixed-length (32-byte) hash of pin+salt
    (FNV-1a seed, splitmix64 expansion) — both only in the test fixture,
    `lib/domain/services/crypto_service.dart`'s contract is unchanged.
    Verified `vault_unlocker_test.dart`'s own 7 tests still pass, since none
    of them call `randomBytes` and `deriveKek`'s output remains a
    deterministic function of (pin, salt).

14. **✅ Fixed 2026-09-01 (by flutter-app-9c, landing Plan 2 Task 6).** Two
    bugs found verifying pre-existing uncommitted Task 6 work (StepProgress,
    AppToggle, the three setup screens, SetupController, decoy provisioner)
    that was sitting unstaged in the `worktree-plan-02-task6-setup-wizard`
    worktree against the plan's own tests:
    - `AppDatabase.open` (Plan 1) left sqflite's `singleInstance` at its
      default `true`, which caches a single connection per path. Both
      `decoy_provisioner_test.dart` and `setup_controller_test.dart` open two
      `AppDatabase`s at the literal `inMemoryDatabasePath` (one for the real
      vault, one for the decoy/second vault) — with caching on, both opens
      returned the *same* underlying connection, so provisioning "vault B"
      mutated vault A's tables via a self-referential `INSERT OR REPLACE` +
      `ON DELETE CASCADE`. Also security-relevant beyond tests: caching by
      path means reopening a vault file under a different password/data key
      would silently return the old connection instead of re-authenticating.
      Fixed with `singleInstance: false` in `AppDatabase.open`.
    - `FakeCrypto.wrap`/`unwrap` (`test/domain/vault_unlocker_test.dart`,
      reused by Task 6's `setup_controller_test.dart`) wrapped a data key as
      `[...kek, 0, ...dataKey]` and unwrapped by finding the first `0` byte.
      The KEK is 32 pseudorandom bytes and can legitimately contain `0x00`
      (~12% chance per unlock attempt), which made `indexOf(0)` find a
      spurious separator inside the KEK itself and reject a correct PIN —
      this is what made "both PINs actually unlock their own vault
      afterwards" flaky/failing for the decoy PIN specifically. Fixed with a
      length-prefixed encoding instead of a sentinel byte, in the test
      fixture only; `CryptoService`'s contract is unchanged.
    Verified full suite: 159/159 passing, `flutter analyze`: No issues found.

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

Plans 6 (Integration, written 2026-09-02) and 7 (Search, written 2026-09-04)
now own most of what this section used to list. What's left below is
genuinely unassigned; the rest is struck through with a pointer to the
task that covers it.

- ~~Search screen.~~ — Plan 7, all 5 tasks. Plan 6 explicitly deferred it
  (design spec's own scope decision); it now has its own plan and its own
  design spec (`docs/superpowers/specs/2026-09-04-search-screen-design.md`).
- **Biometric unlock.** Plan 2's settings shows the toggle; the actual
  Keystore-gated key mechanism is described in one sentence and unassigned —
  Plan 6 leaves the toggle wired to nowhere as well (see its Handoff).
  **Update, 2026-09-08:** design spec written and approved —
  `docs/superpowers/specs/2026-09-08-biometric-unlock-design.md`. Resume-only
  (never cold-unlocks, to avoid conflicting with the coerced-unlock threat
  model), Keystore RSA keypair with the private key gated by biometric auth,
  ciphertext held in memory only. Also wires `SettingsScreen` itself into
  navigation for the first time (a `⋯` icon on `WorkspaceBar`) — every other
  row on that screen stays exactly as inert as it is today. No implementation
  plan yet.
  **Update, 2026-09-08 (done):** implemented, all 8 tasks —
  `docs/superpowers/plans/2026-09-08-biometric-unlock.md` — on branch
  `plan-08-biometric-unlock` off `plan-01-foundation` @ `af9f780`. `3d49654`
  fixed two pre-flight defects; `b538e85` added the `app_settings` table and
  `SettingsRepository` (Task 1); `35d238c`/`f0b3b1e`/`bb83fc2` added the
  Keystore-backed `BiometricPlugin` and its Dart bridge, including a
  `MainActivity` base-class fix found during review (Task 2); `6825d83`
  wired resume-only biometric unlock into `SessionController` (Task 3);
  `a5a34a2` gated `LockBody`'s fingerprint prompt to `welcomeBack` resume
  only (Task 4); `61809ae` added `SettingsController` for the biometrics
  toggle (Task 5); `c3d88f8` reached Settings from the dashboard via the new
  `⋯` overflow icon (Task 6); `6051730` made panic also destroy the
  biometric Keystore key (Task 7). Task 8's full verification pass
  (2026-09-08) re-ran the suite clean: `flutter test` 270/270 passing,
  `flutter analyze` "No issues found!". Two of the design's three "known
  gaps" held up on re-read (every other `SettingsScreen` row is still inert;
  no "unavailable"/"invalidated" copy exists anywhere) — the third didn't:
  the design and `SettingsScreen`'s own doc comment claimed the screen (and
  so the biometrics toggle) is unreachable from a decoy session, but Task
  6's `⋯` icon is wired identically for every open session and nothing
  anywhere checks `SessionOpen.vault` first — consistent with
  `databaseProvider`'s existing "no code anywhere asking which one that is"
  principle in `dashboard/view_models/providers.dart`, which a vault check
  would have broken. Task 8 corrected `SettingsScreen`'s doc comment to say
  so plainly rather than add new vault-distinguishing code no task
  specified; whether to actually restrict decoy reachability is left as an
  open design question for a future task, not decided here.
  **Update, 2026-09-08 (final review — merged):** the whole-branch review
  this table entry never recorded a verdict for (the reviewing session
  ended before writing one) found the implementation above **not** safe to
  merge as-is: `SessionController._rewrapIfEnabled` called
  `BiometricService.wrap` with no error handling and never regenerated the
  Keystore keypair, so a correct PIN entered after Android invalidates the
  key (e.g. a new fingerprint enrolled) threw out of `unlock()` and left
  the user **permanently locked out of a correct-PIN vault**, with no
  in-app recovery — the design spec's own "Failure modes" section specifies
  exactly the self-heal (regenerate-then-retry) that was missing. Separately,
  `BiometricService.isAvailable()` had zero call sites, so the spec's
  "hide/disable the toggle when unavailable" requirement was unimplemented.
  Both fixed in `6ce2a04`: `_rewrapIfEnabled` now retries once after
  regenerating the keypair and fails closed (returns null, never throws)
  if that also fails; a new `biometricsAvailableProvider` gates
  `SettingsScreen`'s toggle via `AppToggle`'s existing nullable `onChanged`.
  Re-reviewed clean, no new breakage, merged to `plan-01-foundation` at
  `6ce2a04`; `flutter test` 273/273 passing, `flutter analyze` clean on the
  merged result. The review also corrected the decoy-reachability finding
  above: **endorsed** as documentation-only (an identical Settings surface
  for both vaults is required by the coerced-unlock threat model, not a gap
  in it — divergence would itself be the tell), but flagged that the shared
  global Keystore alias (`container.biometric`) does let a decoy session's
  biometrics toggle delete the *real* vault's Keystore key — correcting this
  entry's earlier claim that decoy actions "cannot cross-affect the real
  vault" (true for confidentiality/data exposure, false for this one
  availability side-channel). The regenerate-on-demand fix above already
  neutralizes the practical damage (the real vault repairs itself on its
  next correct-PIN unlock); a per-vault Keystore alias
  (`container.biometric.a`/`.b`) is logged as a follow-up, not required for
  this merge.
- ~~Wiring Plan 4's screens to Plan 3's events~~ — Plan 6 Tasks 2–4
  (`engine_events.dart`, discriminated `EngineChannel` events, `ContainerRoute`).
  Known gap: a backgrounded (non-foreground) site's events are dropped, not
  queued — no notification centre exists.
- ~~Reader mode extraction~~ — Plan 6 Task 5 (`extractArticle`). Known gap:
  the heuristic is honestly approximate outside typical article-shaped pages.
- ~~FilterEngine category tagging~~ — Plan 6 Task 1 (schema v5,
  `FilterListCategory`) and Task 3 (categorized Kotlin `FilterEngine`).
- ~~Download interception~~ — Plan 6 Task 3 (`ContainerView`'s
  `DownloadListener` → `download` event). Known gap: downloads are held,
  never actioned — no `DownloadManager` integration, matching the design
  spec's own stated scope. **Update, 2026-09-09:** real
  `DownloadManager`/`MediaStore`/private-directory integration now exists
  behind the held-download sheet's three actions (keep in container, save to
  device, discard), implementing
  `docs/superpowers/specs/2026-09-08-download-manager-integration-design.md`
  via `docs/superpowers/plans/2026-09-08-download-manager-integration.md`.
  `ProxyHttpClient` (new) centralizes the same Route-aware fetch
  `RequestInterceptor` already used for page loads, so a download's bytes
  always travel the site's actual route — refused exactly like a page load
  would be, never silently sent unproxied. `DownloadFetcher` (new) resolves
  each sheet decision: "keep in container" streams into
  `context.filesDir/downloads/<profileId>/` and opens the result via a new
  `FileProvider` (`res/xml/file_paths.xml`); "save to device" uses a manual
  fetch + `MediaStore` insert on a Proxy-routed site (the system
  `DownloadManager` cannot speak through this app's per-site proxy routing)
  and the real system `DownloadManager` on a Direct-routed site.
  `EngineChannel` gained a `resolveDownload` case and a `download_result`
  event feeding `ContainerRoute`'s outcome snackbar. Every wipe path
  (`ContainerView.dispose`'s `wipeOnExit`, the `wipe` case, and `wipeAll()`)
  now also deletes kept-in-container downloads — note `wipeAll()` deletes the
  whole `downloads/` tree inline rather than calling `deleteDownloadsDir`
  per profile, so don't "simplify" that line away.
  **Executed 2026-09-09 across three parallel sessions; Task 7 is NOT fully
  verified and this entry deliberately does not claim it is.** What is
  verified at `40a972f`, with a clean tree: `flutter analyze` clean,
  `flutter test` 299/299, `flutter build apk --debug` succeeding. What is
  not: Task 7 Step 4's two manual on-device checks were never run (no
  emulator/device in this environment), so the feature's core path is
  unvalidated end to end. Commits: `5a27dbf` (Tasks 1–6, recovered as
  uncommitted orphan work — one commit rather than the plan's six, because
  the changes interleave within shared files), `5e970f5` (the
  `ContainerView` Context fix), `deb70aa` (defect documentation), `40a972f`
  (Task 3's tests).
  **Two defects remain open and unfixed — see the plan's own "Defects found
  while executing" section:** (1) **the engine performs no TLS at all**, so
  "keep in container" fails for every `https://` download and only
  Direct-routed "save to device" works (the OS does its own TLS there);
  `RouteFailure.TLS_FAILURE` has an enum entry, a channel mapping, and
  user-facing copy, but its only producer is an `SSLException` catch that can
  never fire — evidence it was designed and dropped, not scoped out. (2)
  whether Android supports `Proxy.Type.HTTP` for a raw `Socket` is an open
  question, deciding whether the HTTP-proxy route tunnels via CONNECT or is
  non-functional. Per the user's 2026-09-09 decision these were documented
  rather than fixed as part of this plan. **Caveat, same day:** defect 1 was
  then picked up directly against `ProxyHttpClient`/`Router` under a separate
  instruction to a parallel session, so if that work landed after this entry
  was written, verify this bullet and the plan's defects section against the
  actual code before trusting either. Defect 2 remains open and unowned.
  Standing lesson from this plan: `flutter analyze` and `flutter test` are
  Dart-only and never compile `engine/`, which is how Tasks 1–6 reached a
  commit having never been compiled. `flutter build apk --debug` is the only
  check that catches Kotlin errors here.
- ~~SiteSheet toggle persistence~~ — Plan 6 Task 6. Known gap: the
  desktop-view toggle only distinguishes `android` vs. `desktop`, so
  `UserAgentMode.minimal` loses that distinction once flipped.
- ~~Decoy auto-sync after provisioning~~ — Plan 6 Task 6 gives `provisionDecoy`
  (not `syncToDecoy`, which never existed under that name) a real call path,
  but only *inside* the two-PIN setup wizard, where both vaults' data keys
  are simultaneously in memory. **Update, 2026-09-08 (done):** the
  reachable "re-sync with the decoy PIN" flow this bullet pointed to is now
  built — Plan 9, `docs/superpowers/plans/2026-09-08-decoy-resync.md`, all 5
  tasks. A new `resyncDecoy` function (add-and-remove, not `provisionDecoy`'s
  add-only) is reachable from a "Re-sync decoy now" row in Settings' VAULT
  section, gated behind a PIN-entry screen that checks the decoy PIN via the
  existing `VaultUnlocker`/attempt-gate before opening the decoy vault just
  long enough to sync and close it again.

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

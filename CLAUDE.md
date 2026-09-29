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
| 6 — Integration | `2026-09-02-isolated-web-container-06-integration.md` | **Done** (2026-09-28) | Wires the five plans into one navigable app: `ContainerRoute` navigation shell, discriminated native events (permission asks, held downloads, tunnel-drop) reaching Plan 4's screens, per-category `FilterEngine`/`BlockedTallyRecorder` feeding a live Today log, `SiteSheet` toggle persistence, and the decoy-sync correction. Implements `docs/superpowers/specs/2026-09-02-integration-design.md` (approved by the user 2026-09-02); three places deliberately correct or narrow that spec against what the tree can actually do — see the plan's own header. 7 tasks. Explicitly leaves search and biometric unlock unbuilt — see Unassigned Work below. **Update, 2026-09-28:** Tasks 1–5 landed 2026-09-04 (merge `3fc3b43`), but Tasks 6 and 7 never did — the struck-through "SiteSheet toggle persistence" bullet below claimed otherwise, and the Workspaces, Scripts and Today screens were built and tested yet unreachable from anywhere in the app. Both were executed on branch `plan-06-tasks-6-7` (commits `c9ad712`..`a7af50a`): the container toolbar's `☰` opens `SiteSheet` (`6c`), whose two switches persist and whose Edit opens the add-site form; a live `BlockedTallyController` feeds the Today log and replaces the dashboard's hardcoded-zero leak count; Today is reached from the workspace dropdown (`5c`: "reachable from the dashboard menu"); Settings' MANAGE rows open real Workspaces (`10a`–`10c`, create/edit/long-press delete, delete wipes each site's profile) and Scripts and filters (`10d`/`10e`) routes. Task 6's `syncToDecoy` half was skipped — superseded by Plan 9's `resyncDecoy`. Several places deliberately deviate from the plan's text; each is a ruling recorded in the plan's Known gaps. Verified 2026-09-28: `flutter analyze` clean, `flutter test` 333/333, `flutter build apk --debug` succeeding. **Not verified on a device.** |
| 7 — Search | `2026-09-04-isolated-web-container-07-search.md` | **Done** (2026-09-08) | Wires `DashboardFooter`'s long-dead search button to a real screen: `SiteRepository.all()`, a `searchResults()` join/filter/sort across every workspace in the open vault, and a pure `SearchScreen`. Implements `docs/superpowers/specs/2026-09-04-search-screen-design.md` (brainstormed and approved by the user 2026-09-04) — that spec itself stands in for the missing canvas screen block, since search was never actually designed anywhere. 5 tasks, all executed; final-review fix wave (2026-09-08) made tapping a search result push a real `ContainerRoute` (it previously only marked the site open and popped back to the dashboard) and fixed `allSitesProvider` never being invalidated, so search now sees adds/deletes/touches made after it first loaded. |
| 9 — Decoy re-sync | `2026-09-08-decoy-resync.md` | **Done** (2026-09-08) | Gives the owner a reachable "re-sync with the decoy PIN" flow from Settings, replacing the setup-time-only `provisionDecoy` with `resyncDecoy` (`lib/data/repositories/decoy_provisioner.dart`) — a real add-and-remove sync that preserves an already-synced site's `profileId` so its decoy-side cookies/history survive repeated syncs. Persists `decoy_configured` on the real vault (`SetupController.complete`) and wires it to `decoyEnabledProvider`/`decoySiteCountProvider`, so `SettingsScreen`'s VAULT section — hardcoded invisible before this plan — now actually shows or hides based on whether a decoy was configured. Adds `DecoyResyncPinScreen` (pure widget, reuses `PinDots`/`PinKeypad`) and `DecoyResyncRoute` (reuses `LockController`, calls the new `SettingsController.resyncDecoyVault`, which checks the entered PIN against both vault slots via the existing `VaultUnlocker`/attempt-gate before opening the decoy vault just long enough to sync and close it). Implements `docs/superpowers/specs/2026-09-08-decoy-resync-design.md`. 5 tasks, all executed. |
| 10 — HTTP CONNECT tunnel | `2026-09-09-http-connect-tunnel.md` | **Done** (2026-09-09) | Makes `ProxyMode.http` actually work by hand-writing the CONNECT tunnel AOSP removed from `java.net.Socket`. New `android/app/src/main/kotlin/com/mono/container/engine/HttpConnectTunnel.kt`: `HttpConnectTunnel.open(proxyHost, proxyPort, targetHost, targetPort)` opens a plain socket to the proxy, writes `CONNECT host:port HTTP/1.1`, requires a 2xx, drains the header block so the returned socket sits at the first byte of tunnel payload, and otherwise throws the new `ProxyTunnelException(statusCode, message)` after closing the socket. `Router.connect`'s `Route.Proxy` branch now splits on `route.socks` — SOCKS still delegated to the platform, `http` to the tunnel — and no executable `java.net.Proxy.Type.HTTP` remains in the tree. Undoes the `ca9552c` interim guard on both sides (`Router.resolve` re-admits `http` **by name**, so an unrecognised mode is still `MISCONFIGURED`; the Dart mirror in `resolveRoute` is deleted, `ProxyMode` being a closed enum). Gives `RouteFailure.PROXY_REFUSED` its first producer in this repo's history, via `RequestInterceptor` and `DownloadFetcher` mapping `ProxyTunnelException` — the existing copy `'The proxy refused the destination'` was not reworded. `ProxyHttpClient` needed no code change: `startTls` already wraps whatever socket `Router.connect` returns, against the target host. This plan has **no design spec** — it was written from defect 5 of the download-manager plan, and the user approved its three design decisions inline on 2026-09-09 (hand-rolled CONNECT over a new dependency, no proxy authentication, `PROXY_REFUSED` as the mapping). 4 tasks, all executed; commits `64c0fa6`/`f6bd41b`/`5e42dd5` plus this documentation pass. Verified 2026-09-09 on a clean tree: Kotlin JVM tests 12/12 (`HttpConnectTunnelTest` 3, `RouterTest` 5, `FilterEngineTest` 4, counts read from the JUnit XML, not from `BUILD SUCCESSFUL`), `flutter analyze` clean, `flutter test` 300/300, `flutter build apk --debug` succeeding with zero `e:` lines. **Not verified: it has never spoken to a real HTTP proxy on a real device** — every test replies from a localhost `ServerSocket` with a canned status line, and the `IllegalArgumentException("Invalid Proxy")` this work exists to fix is Android-only and cannot be reproduced on the desktop JVM the unit tests run on. See its Known gaps below. **Update, 2026-09-28:** exercised on an Android emulator (not a physical phone) through a minimal local CONNECT proxy (a Python script, not a real-world proxy): an http-mode Google site went live with every request tunnelled, and a destination the proxy deliberately routed to the wrong server was refused with `SSLHandshakeException: No subjectAltNames on the certificate match` — hostname verification against the target, over the tunnel, on Android's provider. See "Device verification" below. |
| 11 — Filter lists and scripts | `2026-09-28-filter-lists-and-scripts.md` | **Done** (2026-09-29) | Makes `10d`/`10e` real: three bundled rule files (`assets/filters/`), synced into every vault on open (`syncBundledFilterLists`, replacing the mock `seedFilterListsIfEmpty`); on open Dart sends the vault's enabled rules and the site's library scripts (`EngineExtras`), Kotlin builds the site's `FilterEngine` from them and injects each script separately, scoped to the site's origin (`UserScriptJs`). Implements `docs/superpowers/specs/2026-09-28-filter-lists-and-scripts-design.md`. Verified 2026-09-29: JVM 74/74, `flutter test` 379/379, analyze clean, APK builds; on the emulator the Social embeds and Trackers and ads switches each decide, on the next open, whether their hosts are blocked. **Script injection is not device-verified**: the script editor's "+ Add site" picker is unbuilt (`onAddSite: () {}`), so no UI can attach a script to a site. See the plan's Verification and Known gaps. |

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
  **✅ Follow-up done 2026-09-29 (branch `second/kind-cerf-0tso50`).** Each
  vault now has its own keypair, `container.biometric.<VaultId.name>`
  (`biometricAlias` in `BiometricPlugin.kt`, which refuses anything but `a`
  or `b`). Every `BiometricService` method except `isAvailable` takes the
  `VaultId`: the settings toggle makes or destroys only the open vault's key,
  a PIN unlock re-wraps under the unlocked vault's key, and resume unwraps
  with `SessionLocked.biometricVault`'s. Panic calls the new
  `destroyAllKeyPairs`, which deletes both vaults' keys *and* the old shared
  `container.biometric`, each attempted even if another throws, so panic from
  either vault clears everything. `generateKeyPair` also retires the old
  shared alias: ciphertext under it lived only in memory, so none survives
  the update. Anyone upgrading with biometrics on needs no migration, because
  the first PIN unlock finds no per-vault key and the existing self-heal
  regenerates one. Tests: `BiometricAliasTest` (Kotlin, 4); Dart tests that
  turning biometrics off in the decoy leaves the real vault's key, on makes
  only the decoy's, a decoy-PIN unlock re-wraps under the decoy's key, resume
  unwraps with the backgrounded vault's key, and panic from the decoy clears
  both. Each of those fails when the shared-key behaviour is put back.
  Verified 2026-09-29: `flutter analyze` clean, `flutter test` 369/369,
  Kotlin JVM tests 60/60 (read from the JUnit XML), `flutter build apk
  --debug` succeeding. **Not verified on a device**: the Keystore calls
  themselves cannot run on the JVM.
  **Device-verified 2026-09-29 (emulator, merged to `main`).** Which keys
  exist was read through the VM service by calling the app's own `wrap`
  channel method per vault (it never prompts, and fails with "biometric
  keypair not generated" when the alias is missing): none after setup; only
  the real vault's after turning biometrics on there; both after turning it
  on in the decoy; **the real vault's still present after turning it off in
  the decoy**; neither after panic, which showed `3c` with the app still up.
  That run also found that **biometric resume had never worked on any
  device**: the cipher used RSA-OAEP with MGF1-SHA-256, the Keystore key only
  authorizes MGF1-SHA-1 (the only MGF1 digest a key can have before API 35's
  `setMgf1Digests`), so every decrypt failed with `INCOMPATIBLE_MGF_DIGEST`
  and `unwrap` silently replied null. No prompt ever appeared. **✅ Fixed
  (`85a3d96`, branch `fix-biometric-oaep-mgf1`):** both directions share
  `biometricOaepParams` (SHA-256 OAEP, MGF1-SHA-1), pinned by
  `BiometricOaepTest` (Kotlin, 3). Seen on the emulator with an enrolled
  fingerprint: `9b` shows the system prompt and a sensor touch resumes the
  vault, both right after enabling biometrics and after a PIN unlock's
  re-wrap. Don't change the MGF1 digest back: the JVM tests cannot catch it.
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
  non-functional. *(That question is answered: it does not support it. It
  became defect (a) below, and Plan 10 then wrote the CONNECT by hand.)*
  Defect 1 was documented first and then, the same day, fixed
  at `9c598a1` after the user reversed the "document now, fix later"
  decision: `ProxyHttpClient.fetch` takes a `secure` flag and wraps the
  connected socket in an `SSLSocket` for https, with
  `endpointIdentificationAlgorithm = "HTTPS"` set before the handshake —
  the load-bearing line, since Android's default `SSLSocketFactory` validates
  the cert chain but not that the cert belongs to the host. Wrapping on top
  of `Router.connect`'s socket makes it correct for Direct and SOCKS.
  The previously-unreachable `SSLException → TLS_FAILURE` branch is now live.
  **But TLS is compiled, not proven:** nothing in this repo has ever opened a
  socket to a real server, so the handshake and
  `endpointIdentificationAlgorithm`'s behavior on Android's provider are
  untested. (An earlier version of this entry claimed the TLS wrap also made
  the HTTP-proxy defect fail *safe* via hostname verification. That was
  **wrong** — an HTTP-proxy route never reaches TLS at all; see below. That
  correction described the tree as it stood; since Plan 10 an HTTP-proxy route
  *does* reach TLS, over the CONNECT tunnel, and `startTls` wraps against the
  target host — so hostname verification is against the destination, not the
  proxy.)
  **Two further defects were found here: (a) is fixed, (b) is open and
  unowned.** (a) **✅ Fixed 2026-09-09 by Plan 10 — HTTP proxy mode *was*
  non-functional on Android.** The original record is kept below because it is
  how the defect was found and why the interim fix exists; the fix note
  follows it. `Router.connect` built
  `Socket(Proxy(Type.HTTP, ...))`, and AOSP removed HTTP-proxy support from
  `java.net.Socket` — verified in
  `$LOCALAPPDATA/Android/Sdk/sources/android-36/java/net/Socket.java`, which
  throws `IllegalArgumentException("Invalid Proxy")` at construction. It was
  user-reachable (`ProxyMode.http`, and an "HTTP" chip in the add-site
  Network tab beside SOCKS5), so every such site failed on every page load and
  download; SOCKS5 and direct were unaffected. It was also **misreported** — the
  throw lands in `RequestInterceptor`'s catch-all and surfaces as
  `UPSTREAM_TIMEOUT`, "The destination did not respond," for a destination
  never contacted — and **fails late**, since `ProxyProbe` opens a plain
  socket to the proxy and succeeds, so the site looks healthy until it
  doesn't. **Interim fix, same day** *(since undone by Plan 10 — see the Real
  fix below; described here in the present tense it was written in)***:**
  `Router.resolve` and its Dart mirror
  `resolveRoute` refuse any non-`socks5` mode up front as `MISCONFIGURED`,
  so the failure is immediate and honestly labelled rather than a late bogus
  timeout; `RequestInterceptor` maps `IllegalArgumentException` the same way as
  defence in depth. This fixes the reporting, **not the feature** — an HTTP
  proxy still cannot work, and the reused "This site has no proxy configured"
  copy is still inaccurate (it has one; Android just cannot open it). Better
  copy would be a new string, which the spec does not provide. The "HTTP" chip
  in the Network tab was left in place because it is in the authoritative
  canvas spec — removing it is a design decision, not a bug fix. A real fix
  means implementing CONNECT by hand.
  **Real fix, 2026-09-09 (Plan 10, commits `64c0fa6`/`f6bd41b`/`5e42dd5`):**
  CONNECT is now implemented by hand in `HttpConnectTunnel.kt`, `Router.connect`
  routes `socks = false` proxies through it, and the `ca9552c` interim guard is
  undone on both sides — `Router.resolve` re-admits `http` **by name** (an
  unrecognised mode is still `MISCONFIGURED`, which is the property that guard
  protected), and the Dart mirror is deleted. So the inaccurate "This site has
  no proxy configured" copy is no longer shown for an http site, and a proxy
  that refuses CONNECT now reports `PROXY_REFUSED`, "The proxy refused the
  destination" — that failure's first producer ever. The "HTTP" chip is still
  in place and now backed by something that works. **Verified only by JVM unit
  tests against a localhost fake proxy and a clean APK build; it has never run
  against a real HTTP proxy on a real device**, and the Android-only
  `IllegalArgumentException` it fixes cannot even be reproduced on the desktop
  JVM those tests run on. See Plan 10's row and its known gaps. (b)
  `DownloadFetcher.fetchTo` passes no request headers, so keep-in-container
  sends neither `User-Agent` nor `Cookie` while `saveViaDownloadManager` sends
  both — a cookie-gated download succeeds via Direct save-to-device and fails
  via keep-in-container.
  **✅ Fixed 2026-09-28 on branch `fix-download-request-headers`.** Both
  download paths now build their headers in one pure function,
  `downloadRequest()` in `DownloadFetcher.kt`. The cookies come from **the
  site's own profile** (`ProfileManager.profileFor(...).cookieManager`), not
  `CookieManager.getInstance()`: that is the default profile's jar, which holds
  nothing an isolated site set, so the old `saveViaDownloadManager` was sending
  the wrong jar too. That profile lookup goes through androidx.webkit's
  UI-thread-only `ProfileStore`, so `DownloadFetcher.requestFor` is called from
  `EngineChannel.resolveDownload` on the platform thread, and only the
  network/disk work in `DownloadFetcher.run` goes to the executor. Don't move
  `requestFor` back inside `run`. Also fixed `ProxyHttpClient.fetch` sending
  `Host` without the port on non-default ports (RFC 9110 §7.2). It affected
  proxied page loads as well as downloads. Verified 2026-09-28: Kotlin JVM
  tests 23/23 (read from the JUnit XML; new `DownloadRequestTest` 7 and
  `ProxyHttpClientTest` 4), `flutter analyze` clean, `flutter test` 300/300,
  `flutter build apk --debug` succeeding. **Not verified on a device** — the
  UI-thread requirement in particular is from the library's contract, not
  observed.
  Standing lesson from this plan: `flutter analyze` and `flutter test` are
  Dart-only and never compile `engine/`, which is how Tasks 1–6 reached a
  commit having never been compiled. `flutter build apk --debug` is the only
  check that catches Kotlin errors here.
- ~~SiteSheet toggle persistence~~ — Plan 6 Task 6, **actually landed
  2026-09-28** (this bullet was struck through on 2026-09-04 while the task
  was still unexecuted). Known gaps: the desktop-view toggle only
  distinguishes `android` vs. `desktop`, so `UserAgentMode.minimal` loses
  that distinction once flipped; and a change applies the next time the site
  is opened, since `ContainerEngine` has no call to re-apply settings to a
  live view.
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
- **Gaps Plan 10 (HTTP CONNECT tunnel) leaves open.** The mode works now; these
  are the edges it deliberately does not cover, recorded verbatim from that
  plan's Task 4 Step 3 so they are not rediscovered as bugs:
  - **No proxy authentication.** A proxy answering `407 Proxy Authentication
    Required` is reported as `PROXY_REFUSED` and the request fails. There is no
    credential storage, no `Proxy-Authorization` header, and no UI for either.
    Authenticated HTTP proxies do not work.
  - **No CONNECT for SOCKS.** Unchanged and correct — SOCKS is still delegated
    to the platform, which supports it.
  - **Untested against a real proxy.** Every test in Tasks 1 and 2 talks to a
    `ServerSocket` on localhost that replies with a canned status line. Real
    proxies vary in header handling, keep-alive behaviour and error bodies.
    This shares the limitation of the whole engine: **Task 7 Step 4 of the
    download-manager plan is recorded UNREACHABLE because no Android device is
    available here.**
  - **`ProxyProbe` still probes the proxy, not the tunnel.** `ProxyProbe.reachable`
    opens a plain socket to `host:port`, so a proxy that is up but refuses
    CONNECT to a given destination still reports reachable, and the site reads
    as correctly configured until the request fails. Narrower than before this
    plan — the failure is now named correctly rather than reported as a timeout
    — but the ordering is unchanged.

  Two further gaps came out of the branch review rather than the plan, both
  verified against the tree at `5e42dd5`. Task 4 recorded them unfixed because
  that task changes documentation only; **both were then fixed at `81a69f2`**,
  after an independent re-run of the four verification commands. The findings
  are kept as written because they record what the review actually caught —
  each carries its own resolution:
  - **`ProxyHttpClient.startTls`'s doc comment now asserts the opposite of what
    the code does.** It still reads "There is deliberately no CONNECT-tunnel
    case here … a `Route.Proxy` with `socks = false` throws
    `IllegalArgumentException` at socket construction and never reaches this
    function." Since `f6bd41b` that socket arrives on every `https` load through
    an HTTP proxy, and the enumeration just above it ("a direct socket or a
    SOCKS-routed one") is missing its third case. Behaviour is correct — the
    wrap uses the target host, so hostname verification is against the
    destination — but the stale sentence sits on the one function whose
    `endpointIdentificationAlgorithm` line the tunnel's security depends on,
    telling a future auditor the case cannot exist. A comment-only fix.
    **Fixed at `81a69f2`:** the enumeration now names all three socket kinds and
    the paragraph says the HTTP-proxy case does reach the function, and why that
    makes the certificate check meaningful on a proxied route. No code changed.
  - **`DownloadFetcher.failureFor` mis-names a direct site's `ConnectException`.**
    It mirrors `RequestInterceptor`'s mapping, but the two have different
    preconditions: `RequestInterceptor.fetchThrough` runs only for
    `Route.Proxy`, while `DownloadFetcher` applies the same lambda to
    `keepInContainer`, which runs for any route including `Route.Direct`. A
    refused connection on a direct-routed keep-in-container download therefore
    reports `PROXY_UNREACHABLE` and renders as "Cannot reach the proxy" for a
    site that has no proxy at all; before `5e42dd5` the reason was null and the
    user saw the accurate "Download failed". Gating the proxy-flavoured entries
    on `route is Route.Proxy` would fix it. Not a routing-constraint violation
    — nothing goes direct that should not — only copy accuracy on a path this
    branch newly made reachable.
    **Fixed at `81a69f2`:** `failureFor` now takes the route and maps a
    `ConnectException` to `PROXY_UNREACHABLE` only for a `Route.Proxy`, falling
    back to `UPSTREAM_TIMEOUT` ("The destination did not respond") for a direct
    one. That is the honest member of the five existing `RouteFailure` strings —
    a direct site's refused connection genuinely is the destination failing to
    answer. No copy was reworded and no enum value was added, since either would
    be a spec question rather than a bug fix.

## Device verification (2026-09-28, branch `device-verification-fixes`)

First time the app ran on Android at all: an `sdk_gphone64_x86_64` emulator,
driven through `adb`/`uiautomator`. Screenshots come back solid black because
the app sets `FLAG_SECURE` (`secure_window.dart`) — read the UI tree instead.
Every bug below passed `flutter test` and the JVM tests; each was invisible to
them for the reason given.

Fixed, each with a regression test except the manifest:
- `3d0a778` — **no `INTERNET` permission in the main manifest.** Flutter's
  template declares it only for debug/profile, so a release build could load
  nothing.
- `a42896d` — **`EngineChannel.open` probed the proxy on the main thread.**
  Android throws `NetworkOnMainThreadException`, `ProxyProbe` read that as
  unreachable, and every proxied site was refused. The probe now runs on the
  network executor; `PendingOpens` tickets stop an open overtaken by `close`
  or panic's `wipeAll` from registering late (and from recreating a profile
  panic just deleted).
- `7996a17` — **every site hung on the opening checklist.** `ContainerRoute`
  waited for `live` before building the view whose first load is what reports
  `live`; and `sessionForSiteProvider` read its snapshot before subscribing,
  losing a registration that landed in between. `FakeContainerEngine` had
  reported sessions as `live` immediately, hiding both — it now has
  `opensLive: false`/`markLive` for tests that need the real handoff.
- `339afcf` — **a failed keep-in-container download left a truncated file**,
  one more per retry. `writeDownload` writes a `.part`, checks
  `Content-Length`, rejects non-2xx, and renames only on success.
- `6a5f013` (branch `fix-lock-covers-routes`) — **locking or panicking left
  every pushed screen on top of the lock and panic screens.** `AppGate` is
  `MaterialApp.home` and the dashboard pushed containers, Settings, Search and
  Today onto the root navigator above it, so leaving `SessionOpen` swapped only
  the bottom route: a site stayed live over `LockScreen` with no PIN asked, and
  queued snackbars (`Decoy vault synced`) carried over too. The open vault now
  gets its own `Navigator` and `ScaffoldMessenger` inside `AppGate`
  (`_OpenVault`), so leaving `SessionOpen` tears everything down. **Accepted
  cost (user's call):** a `9b` return closes the open sites and lands on the
  dashboard after the PIN, not back inside the site. Seen on the emulator:
  `9b` covers a container and Settings, and Android back still pops a
  container. Don't move pushes back onto the root navigator, and don't add a
  `useRootNavigator: true` sheet or dialog — either reopens the hole.
- `cec9e45`..`56483c1` (branch `fix-panic-fails-open`) — **panic failed open,
  and no wipe of a used site ever worked.** Four bugs, each hidden behind the
  one before it because panic had never completed on a device:
  1. `cec9e45` — **WebView will not delete a profile this process has
     loaded.** Chromium's `AwBrowserContextStore::Delete` returns `kInUse` for
     any context with a live instance and never releases one, so every wipe of
     a site used since start threw "Cannot delete in-use profile": panic's
     `wipeAll`, `2c`'s "Close all and wipe", and — silently, swallowed in
     Flutter's platform-view dispose — every ephemeral site's wipe on exit.
     (It is not about the view being attached: detaching first was tried on
     the emulator and changed nothing.) `ProfileManager.wipe` now deletes when
     it can, otherwise journals the profile in
     `filesDir/pending-profile-deletions` (`PendingDeletions.kt`) and clears
     its cookies, web storage and geolocation grants in place;
     `MainActivity` sweeps the journal before anything can load a profile; a
     profile used again (`profileFor`) drops out of it. **Accepted gap:** what
     the profile APIs cannot clear (history, network state) stays on disk
     until the next start — unreachable from the app meanwhile. Don't
     "simplify" `wipe` back to a bare `deleteProfile`.
  2. `4f02968` — **panic's order was absolute.** A throwing container step
     aborted it before any key died. `ContainerPanicService.trigger` now runs
     container steps best-effort and always runs the three key steps.
  3. `66b5fad` — **`CryptoPlugin` replied `Unit`** for `destroyDeviceKey`,
     which `StandardMessageCodec` cannot encode: the app crashed mid-panic.
     Replies go through `channelReply`.
  4. `56483c1` — **panic never deleted the vault stores** (`PanicService`'s
     documented step 3), so the next setup opened the old ciphertext with a
     new key and hung on "file is not a database". Panic now deletes both
     stores after the keys; setup deletes any store it finds first.
  Seen on the emulator: panic from inside a site shows `3c`, the app stays up,
  `meta.bin` and `store-1.db` are gone, the loaded profiles are journaled, a
  cold restart leaves WebView with zero profiles, and setup works again; an
  ephemeral site's close journals its profile with no exception.

Seen working on the emulator: setup wizard with both PINs, lock/wrong-PIN/
unlock (`9a`), the encrypted vault surviving a reinstall, a direct HTTPS site,
an http-proxy site over the CONNECT tunnel (see Plan 10's row), the held
download sheet, and a direct-route save to device via `DownloadManager`.

Still open:
- **`2c`'s "Close all and wipe" leaves you on a dead container.** Now that the
  wipe no longer throws, `ContainerRoute.onCloseAllAndWipe` reaches its
  `Navigator.pop(context)` — which closes the switcher sheet on top, not the
  route under it, so the user lands on that site's opening checklist
  (`8a`) instead of the dashboard. `onCloseSession` likely has the same
  shape. Found 2026-09-28 verifying the panic fix; unowned.
  **✅ Fixed 2026-09-29 (`64d72ae`, merged to `main`).** `ContainerScreen`'s
  switcher now dismisses itself by its own context before reporting either
  close action, so the route's `Navigator.pop` pops the route; closing some
  *other* site's session no longer pops the route at all. Two widget tests
  push `ContainerRoute` over a stand-in home route and assert you land on
  it. The fix was found as uncommitted work in an agent worktree and
  committed during the branch merge. **Not verified on a device.**
  *(Seen once on the emulator 2026-09-29: closing the viewed site from the
  switcher's `×` landed on the dashboard. "Close all and wipe" was not
  tried.)*
- **Keep-in-container over HTTPS fails mid-body on the emulator** with
  `SSLProtocolException: Read error` (BoringSSL `BAD_RECORD_MAC`), now
  reported as `TLS_FAILURE` with nothing left on disk. A standalone probe
  reproduced it on the emulator with a plain `SSLSocket` too, and the same
  probe on the host JVM succeeded 6/6 — so it is most likely the emulator's
  network, but that is unproven until it is tried on a physical phone.
- **The held-download sheet showed "0 B"** for a 190 KB PDF. The size is
  `DownloadListener`'s `contentLength`, passed through unchanged; why it was 0
  was not investigated.
  **Cause found 2026-09-29 (from Chromium source, not seen on a device).**
  WebView never reports "unknown" as `-1` here: Chromium's
  `DownloadResponseHandler` sets `total_bytes = head.content_length > 0 ?
  head.content_length : 0`, and that is the value WebView hands
  `DownloadListener`. So `0` means "no length known", and which route the site
  is on decides why:
  - **Direct:** Chromium's own network stack fetches it, so `0` means the
    server sent no `Content-Length` (a chunked, or HTTP/2 streamed, response).
    The size is unknowable before the download without a request, and the app
    must not make one of its own.
  - **Proxied (SOCKS5 or HTTP):** `RequestInterceptor.fetchThrough` returns a
    `WebResourceResponse`, and WebView sets `content_length` from
    `InputStream.available()` on that body. Here that is the raw socket stream,
    so it reports however many bytes happen to be buffered: usually 0, never
    reliably the file size. The site's own `Content-Length` is appended as a
    header afterwards and never read back into that field, so the size is lost
    even when the server sent it.
  Spec `7c` has no copy for an unknown size (its only example is "1.4 MB ·
  from forum.example.com"), so the fix waited on a design answer.
  **✅ Fixed 2026-09-29 (branch `second/kind-cerf-0tso50`). User's ruling: an
  unknown size is left out, and the line reads "from forum.example.com".** No
  new words were added and no request is made. `heldDownloadSize` in
  `DownloadSize.kt` decides the size:
  - **Direct:** WebView's `contentLength` when it is above 0, otherwise
    unknown.
  - **Proxied (`proxyMode != "direct"`):** only the length the server
    declared. `RequestInterceptor.fetchThrough` records it per URL into the
    view's `DeclaredLengths` (in memory, bounded, gone with the view), and the
    `DownloadListener` takes it from there. A `Transfer-Encoding` or a
    non-identity `Content-Encoding` means no declared length.
  An unknown size crosses the channel as `null`, and `HeldDownload.sizeBytes`
  is `int?`. The listener cannot call `currentRoute()` to tell the two routes
  apart, because that probes the proxy on the main thread. Tests:
  `DownloadSizeTest` (Kotlin, 11), and on the Dart side the sheet's
  unknown-size line and the channel decoding `null`. Verified 2026-09-29:
  `flutter analyze` clean, `flutter test` 371/371, Kotlin JVM tests 71/71,
  `flutter build apk --debug` succeeding. **Not verified on a device**, and
  `RequestInterceptor`'s URL key matching the listener's URL comes from
  WebView's contract, not from observation.
  **Device-verified 2026-09-29 (emulator, merged to `main`)**, with a site
  whose URL is the file itself and a local Python CONNECT proxy for the
  http-mode cases: w3.org's 13,264-byte `dummy.pdf` (sends `Content-Length`)
  read "13.0 KB · from www.w3.org" both direct and over the tunnel, so the
  URL keys do match; `httpbin.org/stream-bytes` (chunked, no length) read
  "from httpbin.org" both direct and over the tunnel. The direct runs made no
  proxy connection; the proxied ones made one each.

Found while verifying the above (2026-09-29), both unowned:
- **The decoy vault's `+ Add site` crashes** when the decoy was set up with
  "Pick after setup" (no sites): the decoy vault has no workspaces, and
  `AddSiteScreen` takes `widget.workspaces.first`
  (`add_site_screen.dart:46`), so it throws `Bad state: No element` and shows
  a red error screen. That is a crash in exactly the session a coerced
  unlock opens. Which workspace an empty decoy should get is a design
  question, so this was not fixed.
  **✅ Fixed 2026-09-29 (branch `fix-empty-decoy-workspace`). User's ruling:
  the empty decoy gets a Personal workspace.** `ensureWorkspace`
  (`app_database.dart`) gives any vault with no workspaces a Personal one
  (keep storage, marker 0), and `SessionController` runs it on both `unlock`
  and `resumeWithBiometric`. It never asks which vault is open, so the real
  vault gets the same repair if its owner deletes every workspace, and an
  install that already has an empty decoy is repaired on its next unlock. Its
  id is fresh (`newProfileId()`), never a real-vault id such as
  `ws-personal`, so `resyncDecoy` counts it as decoy-original and never
  deletes it or the sites added to it; don't "tidy" that id into a fixed
  one. ~~**Known gap:** if the owner later flags the real vault's Personal for
  the decoy and re-syncs, the decoy shows two workspaces named Personal.~~
  **✅ Fixed 2026-09-29 (branch `fix-decoy-duplicate-personal`, raised by the
  ultrareview).** `resyncDecoy` now folds any decoy-original workspace with
  the same name as a synced one into it (`_mergeSameNamed`): its sites move
  over by `UPDATE`, keeping their ids, `profileId`s and script assignments,
  and the emptied row is deleted. The fix also found a **pre-existing
  re-sync bug**: an already-synced workspace was re-written with the
  repository's REPLACE upsert, whose delete cascaded to *every* site in it,
  so any site the owner added in the decoy inside a synced workspace was
  deleted on every re-sync. Such workspaces are now updated in place. Don't
  switch either write back to `upsert`: both cascades are silent. Tests: six
  new in `decoy_provisioner_test.dart`; the cascade one fails on the old
  code.
  Tests: `ensure_workspace_test.dart` (5, including the re-sync case), two
  in `session_controller_test.dart`. `lock_screen_test.dart`'s resume test
  now lets the extra sqflite query finish in `tester.runAsync`. Verified
  2026-09-29: `flutter analyze` clean, `flutter test` 378/378, `flutter build
  apk --debug` succeeding. Seen on the emulator as an upgrade: the previous
  build set up with an empty decoy, then this build installed over it with
  data kept. The decoy dashboard read "Personal", `+ Add site` opened with
  WORKSPACE Personal, and a saved site appeared on the decoy board. Re-sync
  on the device was not tried; the unit test covers it against real SQLite.
- **A site reopened after its settings changed while its session was still
  open sometimes hung on `8a`'s "Connecting through 10.0.2.2:8888"**, with no
  request reaching the proxy. Leaving to the dashboard and opening the site
  again loaded it. Seen twice while switching a site's proxy mode; the exact
  steps were not pinned down and the cause was not investigated.
  **✅ Root-caused and fixed 2026-09-29 (branch `fix-connecting-hang`). It was
  worse than a hang: the reopened page loaded under the site's *old*
  settings, so a site switched from direct to a proxy went out direct.**
  Reproduced on the emulator with plain `https://example.com`: open it
  direct, back out (its session stays open), switch it to HTTP
  `10.0.2.2:8888`, reopen. It hung on the checklist with the page already
  rendered underneath and **zero** connections at the proxy. Cause:
  `sessionForSiteProvider` still held the previous visit's session, so
  `ContainerRoute` built `ContainerWebView` before its own `open` returned.
  `ContainerViewFactory` binds a view to whatever session the site has at
  creation (the old one, old config, and `RequestInterceptor` routes by that
  config). `open` then registered a new `Session` with no view. The new
  session only went live if the old view's first load happened to finish
  after that; `reload` and reader mode, which look up the new session's
  view, found null. Making the provider auto-dispose would not help: its
  snapshot would still return the old session until the new `open`
  registers. Fix: `ContainerRoute` shows only the checklist until its own
  `open` has returned (`_openReturned`), since by then the native map holds
  the new session. Test: `container_route_test.dart`'s "a reopened site
  builds no page view until its own open returns" (fails without the fix).
  Verified 2026-09-29: `flutter analyze` clean, `flutter test` 379/379,
  `flutter build apk --debug` succeeding; the same emulator repro now goes
  live with no overlay, every request goes through the proxy, and ⟳ reloads
  through it. Don't build the page view off a session the route did not
  open itself.

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

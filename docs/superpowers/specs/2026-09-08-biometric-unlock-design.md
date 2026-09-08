# Biometric unlock — design

**Status:** Approved by the user 2026-09-08.

## Problem

Plan 2's `SettingsScreen` already renders a "Unlock with biometrics" toggle
(spec `2d`) and `LockBody` already renders a "Use fingerprint" affordance
(spec turn 9), but neither is wired to anything — `LockScreen.onBiometric`
is a literal no-op, annotated as a known gap. No plan owns the actual
mechanism. `CLAUDE.md`'s "Unassigned work" section names this directly.

Two things discovered while scoping this turned out to matter more than
that one-line description suggested, and both are settled below rather
than left implicit:

1. **`SettingsScreen` itself is unreachable.** Nothing in the app ever
   navigates to it, and none of its rows persist anything — not just
   biometrics, all of them. This design wires the minimum path needed to
   make the biometrics row real; every other row is explicitly left as
   inert as it is today (see "Known gaps").
2. **A fingerprint is far easier to compel than a PIN.** This app's own
   stated threat model is coerced unlock, not forensic imaging. Android's
   `BiometricPrompt` also can't distinguish which enrolled finger was
   used, so there is no way to have "the real fingerprint" and "the decoy
   fingerprint" — biometric auth can only ever gate one vault. If it could
   cold-open the real vault directly, anyone able to force a thumbprint
   (including pressing a sleeping or unconscious owner's finger to the
   sensor) bypasses the entire decoy system in one motion, no PIN
   knowledge required.

## Decision: biometric unlock is resume-only

Biometric auth never opens a vault from a cold, fully-locked state. It
only re-confirms identity for a vault that is **already open in this
session** and sitting in the `welcomeBack` grace window (spec `9b`,
`AutoLockPolicy.oneMinute`). A cold app start, or a lock past the grace
deadline (`afterTimeout`, spec `9c`), always requires the full PIN for
either vault — so a coercer forcing a thumbprint on a freshly-locked or
newly-started phone gets nothing, exactly as today.

This is a deliberate, user-approved trade-off against the more
conventional "fingerprint opens the app" UX, made explicitly because that
conventional version conflicts with this app's own stated threat model.

Concretely: `LockBody`'s fingerprint affordance, currently rendered for
`LockMood.normal`, `welcomeBack` and `afterTimeout` alike, is narrowed to
render only for `welcomeBack`, and only when the app actually has
something to resume with (see "Session model" below). This changes
already-shipped Plan 2 behavior and its widget test
(`test/ui/features/lock_body_test.dart`, which currently asserts
`find.text('Use fingerprint')` for `LockMood.normal`); that assertion is
removed for `normal` and kept for `welcomeBack`.

## Mechanism: Keystore-backed, ciphertext held in memory only

An `AndroidKeyStore` RSA-2048 keypair, alias `container.biometric`:

- The **private** key requires authentication —
  `setUserAuthenticationRequired(true)`,
  `setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)`,
  `setInvalidatedByBiometricEnrollment(true)` — and is only ever used
  inside a `Cipher` bound to a `BiometricPrompt`'s `CryptoObject`.
- The **public** key has no restriction, so wrapping the data key never
  shows a prompt.

Nothing biometric-related is ever written to disk. The vault's data key
is wrapped with the public key and the ciphertext lives only in Riverpod
state (`SessionOpen`/`SessionLocked`, see below); it evaporates on
process death exactly like everything else in that state, which is
correct — a killed process is a cold start, and a cold start requires the
PIN under the decision above regardless.

This also means a compromised/hooked process can't simply force a
"success" callback the way it could with a plain boolean
authentication check (e.g. `local_auth`'s `authenticate()`): the actual
decrypt only succeeds if the OS's biometric stack authorizes the Keystore
operation.

## Session model

`SessionOpen` (`lib/ui/features/shell/view_models/session_controller.dart`)
gains two fields:

```dart
class SessionOpen extends Session {
  const SessionOpen({
    required this.vault,
    required this.database,
    required this.dataKey,             // NEW
    this.biometricWrappedKey,          // NEW
  });

  final VaultId vault;
  final AppDatabase database;
  final Uint8List dataKey;
  final Uint8List? biometricWrappedKey;
}
```

Retaining `dataKey` here is not a new category of exposure: the SQLCipher
connection already held by `database` necessarily keeps the equivalent
key material resident in the platform layer for as long as the session is
open, so `SessionController` holding a second reference to the same bytes
for the same span adds nothing new. What must *not* happen — and doesn't,
under this design — is the raw key surviving into `SessionLocked`, i.e.
into the backgrounded/locked window. Only `biometricWrappedKey`
(ciphertext) crosses that boundary:

```dart
class SessionLocked extends Session {
  const SessionLocked({
    required this.mood,
    required this.gate,
    this.openSessionCount = 0,
    this.lockDeadline,
    this.biometricVault,               // NEW
    this.biometricWrappedKey,          // NEW
  });

  final LockMood mood;
  final AttemptGate gate;
  final int openSessionCount;
  final DateTime? lockDeadline;
  final VaultId? biometricVault;
  final Uint8List? biometricWrappedKey;
}
```

Both new `SessionLocked` fields are non-null only when `mood ==
LockMood.welcomeBack` and biometrics was enabled for that vault.
`LockScreen` passes `LockBody(biometricAvailable: session.mood ==
LockMood.welcomeBack && session.biometricWrappedKey != null, ...)`, and
`LockBody` gates `_biometric()` on that flag instead of `mood != wrong`.

### Wiring through `SessionController`

- **`unlock(pin)` success (`Unlocked` case) and `completeSetup`**: after
  opening the database, if `app_settings.biometrics_enabled` is true for
  the vault just opened, call `biometricService.wrap(dataKey)` and set the
  result as `SessionOpen.biometricWrappedKey`. This makes every fresh PIN
  unlock self-healing — it re-wraps under whatever Keystore key currently
  exists, so a key regenerated after being invalidated (see "Failure
  modes") repairs itself on the next ordinary unlock with no separate
  recovery flow.
- **`_handleReturn(ReturnDestination.board)`** (entering `welcomeBack`):
  carry `current.vault` and `current.biometricWrappedKey` onto the new
  `SessionLocked`, instead of discarding them. `current.dataKey` is
  *not* carried forward — it is dropped along with the rest of
  `SessionOpen` when the database closes.
- **New `resumeWithBiometric()`**: mirrors `unlock`'s `Unlocked` branch but
  skips PIN/Argon2id entirely:

  ```dart
  Future<void> resumeWithBiometric() async {
    final current = state;
    if (current is! SessionLocked ||
        current.mood != LockMood.welcomeBack ||
        current.biometricWrappedKey == null) {
      return;
    }
    final dataKey =
        await ref.read(biometricServiceProvider).unwrap(current.biometricWrappedKey!);
    if (dataKey == null) return; // cancelled, failed, or invalidated
    final database = await ref.read(vaultOpenerProvider)(
      path: vaultDatabasePath(
          ref.read(documentsDirectoryProvider), current.biometricVault!),
      dataKey: dataKey,
    );
    state = SessionOpen(
      vault: current.biometricVault!,
      database: database,
      dataKey: dataKey,
      biometricWrappedKey: current.biometricWrappedKey,
    );
  }
  ```

  A `null` return (cancel, failed match, or an invalidated key — see
  below) is silent and non-fatal: the lock screen simply stays up with the
  PIN keypad still available, exactly as "PIN always available as
  fallback" (the toggle's own subtitle) promises.
- **`graceExpired`**: unchanged; dropping the rest of `SessionLocked`
  already drops the two new fields with it.

## Enabling / disabling (Settings)

Enabling biometrics needs the vault's raw data key at the moment it's
turned on, which `SessionOpen` now holds for exactly this reason:

- **Enable**: `SettingsController.setBiometricsEnabled(true)` calls
  `biometricService.generateKeyPair()` (creates the Keystore alias if
  absent), then wraps the current `SessionOpen.dataKey` and updates
  `SessionOpen.biometricWrappedKey` via a new
  `SessionController.setBiometricWrapped(Uint8List)` method, then writes
  `app_settings.biometrics_enabled = '1'` through the vault's own
  database. No re-authentication prompt is needed for this step — turning
  the toggle on happens from inside an already-open, already-authenticated
  session.
- **Disable**: writes `biometrics_enabled = '0'`, calls
  `biometricService.destroyKeyPair()`, and calls
  `SessionController.setBiometricWrapped(null)` to clear the in-memory
  ciphertext immediately rather than waiting for the next background.
- **Panic**: `ContainerPanicService.trigger()` gains one more teardown
  callback, `destroyBiometricKey`, run alongside the existing
  `destroyVaults`/`closeDatabase` calls, wired to
  `biometricService.destroyKeyPair()`. Order doesn't matter relative to
  the existing steps — the Keystore alias is independent of the vault
  files and the device key.

## New pieces

**`lib/domain/services/biometric_service.dart`** (new interface,
mirrors `CryptoService`'s shape):

```dart
abstract interface class BiometricService {
  /// Hardware present and at least one biometric enrolled. `SettingsScreen`
  /// hides/disables the toggle entirely when this is false — no plan or
  /// spec screen covers that copy, so this stays a disabled row rather than
  /// inventing text.
  Future<bool> isAvailable();

  Future<void> generateKeyPair();

  /// Public-key encrypt. No prompt.
  Future<Uint8List> wrap(Uint8List dataKey);

  /// Shows the system `BiometricPrompt`. Null on cancel, failed match, or
  /// `KeyPermanentlyInvalidatedException` — never throws for any of those,
  /// since a wrong or missing fingerprint is an expected negative result,
  /// the same convention `CryptoService.unwrap` already uses for a wrong PIN.
  Future<Uint8List?> unwrap(Uint8List wrapped);

  Future<void> destroyKeyPair();
}
```

**`lib/data/services/android_biometric_service.dart`** — `MethodChannel`
bridge, `com.mono.container/biometric`, same pattern as
`android_crypto_service.dart`.

**`android/app/src/main/kotlin/com/mono/container/BiometricPlugin.kt`**
(new, alongside `CryptoPlugin.kt`/`SecureWindowPlugin.kt`) — owns the
keypair lifecycle and the `BiometricPrompt`/`CryptoObject` calls. Needs
the `FragmentActivity` (`MainActivity` already is one, via
`FlutterActivity`) to show the system prompt, so it's constructed the
same way `SecureWindowPlugin(this)` is, and registered in
`MainActivity.configureFlutterEngine` alongside the other two channels.
Catches `KeyPermanentlyInvalidatedException` around the cipher
`init`/`doFinal` in `unwrap` and treats it as a null result after deleting
the now-useless alias — see "Failure modes".

**`app_settings` table** — schema v5 → v6 in
`lib/data/services/app_database.dart`:

```sql
CREATE TABLE app_settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
```

One row, `('biometrics_enabled', '1'|'0')`, written by
`onCreate` as absent-by-default and by `onUpgrade`'s `if (from < 6)`
step for existing installs. This lives inside each vault's own
SQLCipher-encrypted database — not the plaintext-visible
`vault_store.json` — so a decoy vault simply never having this row (or
having its own independent value) cannot leak which slot is real the way
a difference in `vault_store.json`'s two slots would. No decoy-side
mirroring is needed, unlike `VaultStore.provisionUnopenable`'s handling of
the PIN slots.

**`lib/data/repositories/settings_repository_sqlite.dart`** (new, small):

```dart
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool fallback = false});
  Future<void> setBool(String key, bool value);
}
```

**`lib/ui/features/settings/view_models/providers.dart`** (new) —
`settingsControllerProvider`, a `Notifier` reading/writing only
`biometrics_enabled` through `SettingsRepository` and calling
`SessionController`'s enable/disable methods above. `autoLockLabel`,
`decoyEnabled`, `decoySiteCount`, `hideFromSwitcher`, `panicOnFlip`, and
`onPanicLabel` are supplied as static values matching current real
behavior (`'After 1 min'` for the hardcoded `AutoLockPolicy.oneMinute`,
`hideFromSwitcher: true` for the FLAG_SECURE that's already always on,
the rest inert placeholders) — see "Known gaps."

## Navigation: reaching Settings

Screen `1b` (the dashboard as actually implemented) has no settings entry
point in the authoritative spec at all — only the alternate, unimplemented
`1a` grid layout has an overflow icon. Per the user's direction, a small
`⋯` icon is added to `WorkspaceBar`
(`lib/ui/features/dashboard/views/workspace_bar.dart`)'s trailing area,
next to the existing session-count text, reusing `1a`'s own icon rather
than inventing a new affordance:

```dart
final VoidCallback onOverflow;   // NEW constructor param
```

`dashboard_screen.dart` wires it to push `SettingsScreen` through a small
connected wrapper, following the same `_settingsRoute`-style pattern Plan
6 Task 7 already established for other screens pushed from the dashboard.

## Failure modes

- **Biometric hardware absent or nothing enrolled**: `isAvailable()`
  false → Settings hides/disables the row; nothing else in this design
  activates.
- **User cancels or fails the prompt**: `unwrap` returns null;
  `resumeWithBiometric` is a no-op; PIN entry is still live underneath.
- **New fingerprint enrolled after biometrics was turned on**: the
  Keystore private key is auto-invalidated by the OS.
  `KeyPermanentlyInvalidatedException` inside `unwrap` is caught in
  `BiometricPlugin`, which deletes the now-dead alias and returns null —
  the same "silent no-op, PIN still works" path as any other failure.
  `biometrics_enabled` is left `true` in `app_settings`; the next
  successful PIN unlock's self-healing re-wrap (see "Wiring through
  `SessionController`" above) regenerates the keypair and repairs it with
  no dedicated recovery UI, since no spec screen covers that copy either.
- **Process killed while `SessionLocked.welcomeBack`**: state is gone;
  next launch is a cold start; PIN required. Correct under the resume-only
  decision, not a bug to guard against.

## Testing

- `test/ui/features/shell/session_controller_test.dart` (extend): fake
  `BiometricService` (mirrors the existing `FakeCrypto` pattern) —
  enable → background → `resumeWithBiometric` reaches `SessionOpen`;
  wrong-PIN entry during `welcomeBack` still works alongside a pending
  biometric ciphertext; `unwrap` returning null leaves the lock screen
  locked; disabling clears `biometricWrappedKey` immediately; a fresh PIN
  unlock re-wraps and repairs a previously-cleared ciphertext.
- `test/ui/features/lock_body_test.dart`: update the existing
  `LockMood.normal` assertion to expect no fingerprint affordance; add a
  `welcomeBack` + `biometricAvailable: true` case asserting it appears,
  and a `welcomeBack` + `biometricAvailable: false` case asserting it
  doesn't.
- `test/ui/features/settings_test.dart` (extend): toggling the biometrics
  row calls through to the controller; other rows' callbacks are
  unchanged no-ops.
- `test/ui/features/dashboard/workspace_bar_test.dart` (new): tapping the
  new `⋯` icon calls `onOverflow`.
- `test/data/app_settings_migration_test.dart` (new, same naming
  convention as the existing `test/data/filter_list_category_migration_test.dart`
  for the v4 → v5 step): v5 → v6 upgrade creates `app_settings` with no
  data loss to existing tables; a fresh `onCreate` install also has the
  table.
- Kotlin: no instrumentation test is added for `BiometricPlugin` unless
  `CryptoPlugin`/`SecureWindowPlugin` already have one to mirror —
  `BiometricPrompt` itself cannot be driven from a JVM unit test, only a
  real or emulated device with an enrolled biometric, which is outside
  this repo's current test setup.

## Known gaps this design accepts

- **Every other `SettingsScreen` row stays exactly as inert as it is
  today.** `Auto-lock`'s value is shown but not editable, `Change main
  PIN` does nothing, decoy management fields are static placeholders, and
  `panicOnFlip`/`onPanicLabel` are hardcoded. Only the biometrics row
  becomes real. This matches the precedent Plan 6's own handoff already
  records for this exact toggle ("Plan 6 leaves the toggle wired to
  nowhere as well") — now narrowed to the rows this plan doesn't touch.
- **No "biometrics unavailable" copy exists in any spec.** The disabled
  state when `isAvailable()` is false has no designed string; the row is
  simply disabled rather than inventing explanatory copy.
- **No dedicated UI for the invalidated-key repair.** It heals silently on
  the next PIN unlock, per "Failure modes" above, rather than surfacing
  anything to the user in the moment their fingerprint stopped working.
- **Decoy vault never has a biometrics option.** Settings is a real-vault
  surface only (existing `SettingsScreen` doc comment), and this design
  doesn't change that — consistent with biometric auth only ever being
  able to gate one vault at all (see "Problem" above).

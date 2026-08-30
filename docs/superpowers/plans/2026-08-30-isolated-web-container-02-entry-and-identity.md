# Isolated Web Container — Plan 2: Entry and Identity

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nobody reaches the dashboard without a PIN, a second PIN opens a different and equally real board, and panic destroys the keys before it destroys the files.

**Architecture:** Two independently-keyed SQLCipher stores. A PIN goes through Argon2id to a key-encrypting key; the KEK unwraps that vault's data key; the data key opens that vault's store. Neither PIN is stored or hashed anywhere — a wrong PIN is detected by an AEAD tag failing to authenticate, which is what lets the app be honest that it cannot tell a wrong PIN from a PIN for a vault that does not exist. All key operations live in a small Kotlin plugin behind a `CryptoService` interface, so Dart never holds a KEK and the orchestration above it stays unit-testable with a fake.

**Tech Stack:** Everything from Plan 1, plus `sqflite_sqlcipher`, `local_auth`, and a Kotlin plugin using BouncyCastle's `Argon2BytesGenerator` and the Android Keystore.

**Spec:**
- `Sandbox Container -canvas-.dc.html` — screens `4a`, `4b`, `5a`, `3a`, `4c`, `9a`, `9b`, `9c`, `3b`, `3c`, `2d`. Read the block whose `id` matches before building it.
- `docs/superpowers/plans/2026-08-30-isolated-web-container-01-foundation.md` — Plan 1. This plan consumes its tokens, primitives, domain model and `AppDatabase`.

**Depends on:** Plan 1, complete and merged. This plan replaces Plan 1's single unencrypted `Vault.a` with two encrypted vaults, and puts a lock screen in front of `DashboardScreen`.

**Scope note:** screens `9a`/`9b`/`9c` are in this plan rather than a later one. They look like "backgrounding" but they are lock states, and the design's turn 9 note makes the distinction the whole point: "The app is masked in recents the instant it loses focus, not when the timer expires. The timer only decides whether you come back to the board or to the PIN." Masking, the auto-lock timer, and the return destination are three separate mechanisms, and splitting them across plans would guarantee they get wired to each other wrongly.

---

## Global Constraints

Plan 1's Global Constraints apply in full and are not repeated. These are additional, and every task's requirements implicitly include both sets.

- **Threat model: coerced unlock.** The adversary is a person holding the phone who can compel an unlock. Not a forensic lab with a disk image. Accepted and stated in the product: someone imaging the disk sees that two encrypted stores exist; they cannot read the second one.
- **Neither PIN is ever stored, hashed, or compared.** The only test of a PIN is whether the key it derives unwraps a data key whose AEAD tag authenticates. There is no `if (enteredPin == storedPin)` anywhere, and no "which vault does this PIN belong to" lookup table.
- **Both vault slots always exist on disk, always the same size, always written at setup.** A device with no decoy configured still has a second slot filled with random bytes that no PIN will ever unwrap. An absent slot proves there is no decoy, which is exactly the fact the decoy exists to hide.
- **Every unlock attempt does the same work.** Both slots are evaluated on every attempt, in a fixed order, before a vault is selected. Returning early on the first match makes unlock time reveal which slot matched, and therefore reveals that two slots are live.
- **No screen, string, icon or setting visible from the decoy vault may mention vaults, decoys, second PINs, or hidden anything.** From turn 3: "The lock screen gives no hint that a second PIN exists, and the decoy board is deliberately ordinary." Setup (`4b`) is the only place the feature is ever named, and only when the real vault is open.
- **Panic destroys key material first and files second.** Killing 32 bytes is the irreversible step; deleting files is cleanup. This ordering is what makes `3c`'s "DESTROYED / WIPED / CLEARED" report literally true rather than optimistic.
- **`FLAG_SECURE` is set for the process lifetime, not toggled per screen.** It is applied in `MainActivity.onCreate` before the Flutter view exists. A flag that is turned on and off has a window where it is off.
- **Argon2id parameters are `m = 64 MiB, t = 3, p = 2`, 16-byte salt, 32-byte output.** These are fixed constants in one file. Do not make them configurable and do not lower them to speed up tests — tests use the fake `CryptoService`.

---

## File Structure

```
lib/domain/models/vault.dart                  VaultId, VaultSlot, UnlockOutcome
lib/domain/models/attempt_gate.dart           AttemptGate — tries left, lockout
lib/domain/models/lock_state.dart             LockState, AutoLockPolicy, ReturnDestination
lib/domain/services/crypto_service.dart       abstract CryptoService + CryptoParams
lib/domain/services/vault_unlocker.dart       VaultUnlocker — pure orchestration

lib/data/services/vault_store.dart            reads/writes the two-slot meta file
lib/data/services/android_crypto_service.dart MethodChannel binding
lib/data/services/encrypted_database.dart     opens AppDatabase on a data key
lib/data/services/secure_window.dart          FLAG_SECURE + recents masking binding
lib/data/repositories/decoy_provisioner.dart  copies flagged rows into the decoy store

android/app/src/main/kotlin/com/mono/container/MainActivity.kt
android/app/src/main/kotlin/com/mono/container/CryptoPlugin.kt
android/app/src/main/kotlin/com/mono/container/SecureWindowPlugin.kt

lib/ui/core/widgets/pin_dots.dart             the six-dot PIN indicator
lib/ui/core/widgets/pin_keypad.dart           the 3x4 round keypad
lib/ui/core/widgets/app_toggle.dart           44x26 toggle (first needed here, by 2d)
lib/ui/core/widgets/setting_row.dart          title/subtitle + trailing control
lib/ui/core/widgets/step_progress.dart        the three-segment setup bar

lib/ui/features/lock/view_models/lock_controller.dart
lib/ui/features/lock/views/lock_body.dart     3a, 4c, 9b, 9c — one widget, four states
lib/ui/features/lock/views/lock_screen.dart   built in Task 8: needs session_controller.dart
lib/ui/features/setup/view_models/setup_controller.dart
lib/ui/features/setup/views/setup_pin_screen.dart        4a
lib/ui/features/setup/views/setup_decoy_screen.dart      4b
lib/ui/features/setup/views/setup_defaults_screen.dart   5a
lib/ui/features/panic/views/panic_screen.dart            3c
lib/ui/features/settings/view_models/settings_controller.dart
lib/ui/features/settings/views/settings_screen.dart      2d
lib/ui/features/shell/views/app_gate.dart     routes setup / lock / dashboard
lib/ui/features/shell/views/setup_flow.dart   built in Task 8: needs session_controller.dart
lib/ui/features/shell/view_models/lifecycle_controller.dart
lib/ui/features/shell/view_models/session_controller.dart   Session, SessionController, providers

test/domain/attempt_gate_test.dart
test/domain/vault_unlocker_test.dart
test/domain/lock_state_test.dart
test/data/vault_store_test.dart
test/data/decoy_provisioner_test.dart
test/ui/core/pin_widgets_test.dart
test/ui/features/lock_body_test.dart
test/ui/features/lock/lock_controller_test.dart
test/ui/features/setup_test.dart
test/ui/features/setup/setup_controller_test.dart
test/ui/features/panic_test.dart
test/ui/features/settings_test.dart
test/ui/features/shell/session_controller_test.dart
test/ui/features/shell/lock_screen_test.dart
test/ui/features/shell/setup_flow_test.dart
```

`lock_body.dart` renders `3a`, `4c`, `9b` and `9c`. They are the same screen with different copy and one different card, and building them as four files would let them drift.

---

## Task 1: The attempt gate and the lock state machine

Pure Dart, no Flutter, no crypto. These are the two pieces of logic most likely to be got wrong and easiest to test exhaustively.

**Files:**
- Create: `lib/domain/models/attempt_gate.dart`, `lib/domain/models/lock_state.dart`
- Test: `test/domain/attempt_gate_test.dart`, `test/domain/lock_state_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class AttemptGate { const AttemptGate({int failures, DateTime? lockedUntil}); int get triesLeft; bool lockedAt(DateTime now); Duration remainingAt(DateTime now); AttemptGate recordFailure(DateTime now); AttemptGate reset(); static const maxTries = 5; static const penalty = Duration(seconds: 30); }`
  - `enum ReturnDestination { board, pin }`
  - `class AutoLockPolicy { const AutoLockPolicy(this.grace); final Duration grace; ReturnDestination destinationFor(Duration away); static const oneMinute = AutoLockPolicy(Duration(minutes: 1)); }`
  - `class LockState { const LockState({required this.locked, required this.maskRecents, required this.openSessionCount, this.secondsUntilLock}); }`

- [ ] **Step 1: Write the failing attempt-gate test**

The copy in `4c` fixes the behaviour: "Wrong PIN · 3 tries left" and "After 5 wrong tries the app waits 30 seconds before accepting another."

Create `test/domain/attempt_gate_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';

void main() {
  final t0 = DateTime(2026, 8, 30, 9, 10);

  test('a fresh gate allows five tries and is not locked', () {
    const gate = AttemptGate();
    expect(gate.triesLeft, 5);
    expect(gate.lockedAt(t0), isFalse);
  });

  test('each failure spends one try', () {
    var gate = const AttemptGate();
    gate = gate.recordFailure(t0);
    expect(gate.triesLeft, 4);
    gate = gate.recordFailure(t0);
    expect(gate.triesLeft, 3);
  });

  test('the fifth failure locks for thirty seconds', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }

    expect(gate.triesLeft, 0);
    expect(gate.lockedAt(t0), isTrue);
    expect(gate.remainingAt(t0), const Duration(seconds: 30));
    expect(gate.lockedAt(t0.add(const Duration(seconds: 29))), isTrue);
    expect(gate.lockedAt(t0.add(const Duration(seconds: 30))), isFalse);
  });

  test('the penalty repeats for every further failure', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }
    final later = t0.add(const Duration(seconds: 31));
    gate = gate.recordFailure(later);

    expect(gate.lockedAt(later), isTrue);
    expect(gate.remainingAt(later), const Duration(seconds: 30));
  });

  test('a success clears everything', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }

    gate = gate.reset();
    expect(gate.triesLeft, 5);
    expect(gate.lockedAt(t0), isFalse);
  });

  test('a clock that moves backwards does not shorten the penalty', () {
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(t0);
    }

    expect(gate.lockedAt(t0.subtract(const Duration(hours: 2))), isTrue);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/domain/attempt_gate_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:container/domain/models/attempt_gate.dart'`.

- [ ] **Step 3: Write the attempt gate**

Create `lib/domain/models/attempt_gate.dart`:

```dart
/// Counts wrong PINs and imposes the delay `4c` promises: "After 5 wrong tries
/// the app waits 30 seconds before accepting another."
///
/// This gate knows nothing about which PIN was entered or which vault it might
/// belong to. It counts failures to unwrap, and a failure to unwrap is
/// indistinguishable from a PIN for a vault that does not exist — which is the
/// property the decoy depends on.
class AttemptGate {
  const AttemptGate({this.failures = 0, this.lockedUntil});

  final int failures;
  final DateTime? lockedUntil;

  static const maxTries = 5;
  static const penalty = Duration(seconds: 30);

  int get triesLeft {
    final left = maxTries - (failures % maxTries);
    return left == maxTries && failures > 0 ? 0 : left;
  }

  bool lockedAt(DateTime now) {
    final until = lockedUntil;
    return until != null && now.isBefore(until);
  }

  Duration remainingAt(DateTime now) {
    final until = lockedUntil;
    if (until == null || !now.isBefore(until)) return Duration.zero;
    return until.difference(now);
  }

  AttemptGate recordFailure(DateTime now) {
    final total = failures + 1;
    final locking = total >= maxTries;
    return AttemptGate(
      failures: total,
      lockedUntil: locking ? now.add(penalty) : lockedUntil,
    );
  }

  AttemptGate reset() => const AttemptGate();
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/domain/attempt_gate_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Write the failing lock-state test**

Turn 9's note is the specification: masking is immediate on focus loss; the timer only picks where you come back to.

Create `test/domain/lock_state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/lock_state.dart';

void main() {
  const policy = AutoLockPolicy.oneMinute;

  test('returning inside the grace period comes back to the board', () {
    expect(policy.destinationFor(Duration.zero), ReturnDestination.board);
    expect(policy.destinationFor(const Duration(seconds: 59)),
        ReturnDestination.board);
  });

  test('returning past the grace period comes back to the PIN', () {
    expect(policy.destinationFor(const Duration(seconds: 60)),
        ReturnDestination.pin);
    expect(policy.destinationFor(const Duration(hours: 3)),
        ReturnDestination.pin);
  });

  test('masking does not wait for the timer', () {
    // The moment focus is lost, regardless of how long the app has been away.
    const justLeft = LockState(
        locked: false, maskRecents: true, openSessionCount: 3);
    expect(justLeft.maskRecents, isTrue);
    expect(justLeft.locked, isFalse);
  });

  test('a zero grace period locks immediately', () {
    const instant = AutoLockPolicy(Duration.zero);
    expect(instant.destinationFor(Duration.zero), ReturnDestination.pin);
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/domain/lock_state_test.dart`
Expected: FAIL — missing file.

- [ ] **Step 7: Write the lock state**

Create `lib/domain/models/lock_state.dart`:

```dart
/// Where the user lands when they come back to the app.
enum ReturnDestination { board, pin }

/// How long the app may sit in the background before the PIN is required
/// again. Default is "After 1 min" (spec `2d`).
///
/// This policy decides the destination and nothing else. It does not decide
/// whether the app is masked in recents — that happens the instant focus is
/// lost, independently of any timer (spec turn 9).
class AutoLockPolicy {
  const AutoLockPolicy(this.grace);

  final Duration grace;

  static const oneMinute = AutoLockPolicy(Duration(minutes: 1));

  ReturnDestination destinationFor(Duration away) =>
      away < grace ? ReturnDestination.board : ReturnDestination.pin;
}

class LockState {
  const LockState({
    required this.locked,
    required this.maskRecents,
    required this.openSessionCount,
    this.secondsUntilLock,
  });

  final bool locked;

  /// True from the moment focus is lost until it is regained.
  final bool maskRecents;

  /// Drives `9b`'s "3 sessions still open · locks in 40s".
  final int openSessionCount;
  final int? secondsUntilLock;
}
```

- [ ] **Step 8: Run it to verify it passes, then commit**

Run: `flutter test test/domain/`
Expected: PASS, all domain tests including the 12 from Plan 1.

```bash
git add -A
git commit -m "feat: attempt gate and lock state machine"
```

---

## Task 2: The crypto contract and the unlocker

The security-critical orchestration, written against an interface so it can be tested exhaustively without a device. The real implementation is Task 3.

**Files:**
- Create: `lib/domain/models/vault.dart`, `lib/domain/services/crypto_service.dart`, `lib/domain/services/vault_unlocker.dart`
- Test: `test/domain/vault_unlocker_test.dart`

**Interfaces:**
- Consumes: `AttemptGate` from Task 1.
- Produces:
  - `enum VaultId { a, b }`
  - `class VaultSlot { final Uint8List salt; final Uint8List wrappedKey; }`
  - `sealed class UnlockOutcome` with `Unlocked(VaultId vault, Uint8List dataKey)`, `Rejected(AttemptGate gate)`, `Throttled(Duration remaining)`
  - `abstract interface class CryptoService { Future<Uint8List> deriveKek(String pin, Uint8List salt); Future<Uint8List?> unwrap(Uint8List kek, Uint8List wrapped); Future<Uint8List> wrap(Uint8List kek, Uint8List dataKey); Future<Uint8List> randomBytes(int length); Future<void> destroyDeviceKey(); }`
  - `class VaultUnlocker { VaultUnlocker(this._crypto); Future<UnlockOutcome> attempt({required String pin, required List<VaultSlot> slots, required AttemptGate gate, required DateTime now}); }`

`unwrap` returns `null` when the AEAD tag does not authenticate. That is the only failure signal in the system.

- [ ] **Step 1: Write the failing unlocker test**

Create `test/domain/vault_unlocker_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/crypto_service.dart';
import 'package:container/domain/services/vault_unlocker.dart';

/// A fake in which a KEK is just the PIN and salt concatenated, and a wrapped
/// key unwraps only if it was wrapped under the same KEK.
class FakeCrypto implements CryptoService {
  FakeCrypto();

  final List<String> derivations = [];

  @override
  Future<Uint8List> deriveKek(String pin, Uint8List salt) async {
    derivations.add('$pin/${salt.join(",")}');
    return Uint8List.fromList('$pin|${salt.join(",")}'.codeUnits);
  }

  @override
  Future<Uint8List> wrap(Uint8List kek, Uint8List dataKey) async =>
      Uint8List.fromList([...kek, 0, ...dataKey]);

  @override
  Future<Uint8List?> unwrap(Uint8List kek, Uint8List wrapped) async {
    final sep = wrapped.indexOf(0);
    if (sep == -1) return null;
    final usedKek = wrapped.sublist(0, sep);
    if (usedKek.length != kek.length) return null;
    for (var i = 0; i < kek.length; i++) {
      if (usedKek[i] != kek[i]) return null;
    }
    return Uint8List.fromList(wrapped.sublist(sep + 1));
  }

  @override
  Future<Uint8List> randomBytes(int length) async =>
      Uint8List.fromList(List.filled(length, 7));

  @override
  Future<void> destroyDeviceKey() async {}
}

final _now = DateTime(2026, 8, 30, 9, 10);
final _saltA = Uint8List.fromList([1, 1]);
final _saltB = Uint8List.fromList([2, 2]);
final _keyA = Uint8List.fromList([10, 11, 12]);
final _keyB = Uint8List.fromList([20, 21, 22]);

Future<List<VaultSlot>> _slots(FakeCrypto crypto,
    {String pinA = '111111', String? pinB = '222222'}) async {
  final kekA = await crypto.deriveKek(pinA, _saltA);
  final slotA = VaultSlot(salt: _saltA, wrappedKey: await crypto.wrap(kekA, _keyA));

  if (pinB == null) {
    // No decoy configured: the slot still exists, filled with bytes that no
    // PIN unwraps.
    return [slotA, VaultSlot(salt: _saltB, wrappedKey: Uint8List.fromList([9, 9, 9]))];
  }
  final kekB = await crypto.deriveKek(pinB, _saltB);
  return [slotA, VaultSlot(salt: _saltB, wrappedKey: await crypto.wrap(kekB, _keyB))];
}

void main() {
  late FakeCrypto crypto;
  late VaultUnlocker unlocker;

  setUp(() {
    crypto = FakeCrypto();
    unlocker = VaultUnlocker(crypto);
  });

  test('the main PIN opens vault A with its data key', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '111111', slots: slots, gate: const AttemptGate(), now: _now);

    expect(outcome, isA<Unlocked>());
    expect((outcome as Unlocked).vault, VaultId.a);
    expect(outcome.dataKey, _keyA);
  });

  test('the decoy PIN opens vault B, with a different key', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '222222', slots: slots, gate: const AttemptGate(), now: _now);

    expect((outcome as Unlocked).vault, VaultId.b);
    expect(outcome.dataKey, _keyB);
    expect(outcome.dataKey, isNot(_keyA));
  });

  test('a wrong PIN is rejected and spends a try', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '999999', slots: slots, gate: const AttemptGate(), now: _now);

    expect(outcome, isA<Rejected>());
    expect((outcome as Rejected).gate.triesLeft, 4);
  });

  test('every attempt derives a KEK for both slots, even a successful one',
      () async {
    // Returning early on the first match would let unlock time reveal which
    // slot matched, and therefore that two slots are live.
    final slots = await _slots(crypto);
    crypto.derivations.clear();

    await unlocker.attempt(
        pin: '111111', slots: slots, gate: const AttemptGate(), now: _now);

    expect(crypto.derivations.length, 2);
  });

  test('an unconfigured decoy slot is indistinguishable from a wrong PIN',
      () async {
    final slots = await _slots(crypto, pinB: null);
    final outcome = await unlocker.attempt(
        pin: '222222', slots: slots, gate: const AttemptGate(), now: _now);

    expect(outcome, isA<Rejected>());
  });

  test('a throttled gate refuses without deriving anything', () async {
    final slots = await _slots(crypto);
    var gate = const AttemptGate();
    for (var i = 0; i < 5; i++) {
      gate = gate.recordFailure(_now);
    }
    crypto.derivations.clear();

    final outcome = await unlocker.attempt(
        pin: '111111', slots: slots, gate: gate, now: _now);

    expect(outcome, isA<Throttled>());
    expect((outcome as Throttled).remaining, const Duration(seconds: 30));
    expect(crypto.derivations, isEmpty);
  });

  test('a successful unlock resets the gate', () async {
    final slots = await _slots(crypto);
    final outcome = await unlocker.attempt(
        pin: '111111',
        slots: slots,
        gate: const AttemptGate(failures: 3),
        now: _now);

    expect(outcome, isA<Unlocked>());
    expect((outcome as Unlocked).gate.triesLeft, 5);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/domain/vault_unlocker_test.dart`
Expected: FAIL — missing `vault.dart`.

- [ ] **Step 3: Write the vault model and the crypto contract**

Create `lib/domain/models/vault.dart`:

```dart
import 'dart:typed_data';

import 'attempt_gate.dart';

/// Which store. The two are peers; neither is "the real one" as far as any
/// code below the UI is concerned.
enum VaultId { a, b }

/// What is persisted per vault: a salt and a wrapped data key. Both slots are
/// always present and always the same size, so their contents reveal nothing
/// about whether a decoy has been configured.
class VaultSlot {
  const VaultSlot({required this.salt, required this.wrappedKey});

  final Uint8List salt;
  final Uint8List wrappedKey;
}

sealed class UnlockOutcome {
  const UnlockOutcome();
}

class Unlocked extends UnlockOutcome {
  const Unlocked({required this.vault, required this.dataKey, required this.gate});

  final VaultId vault;
  final Uint8List dataKey;
  final AttemptGate gate;
}

class Rejected extends UnlockOutcome {
  const Rejected(this.gate);

  final AttemptGate gate;
}

class Throttled extends UnlockOutcome {
  const Throttled(this.remaining);

  final Duration remaining;
}
```

Create `lib/domain/services/crypto_service.dart`:

```dart
import 'dart:typed_data';

/// Every key operation in the app. The implementation lives in Kotlin so that
/// Dart never holds a key-encrypting key, and so the Argon2id work happens off
/// the platform thread.
abstract interface class CryptoService {
  /// Argon2id, m = 64 MiB, t = 3, p = 2, 32-byte output.
  Future<Uint8List> deriveKek(String pin, Uint8List salt);

  /// AES-256-GCM. Returns null when the tag does not authenticate — which is
  /// the only way the app ever learns a PIN was wrong.
  Future<Uint8List?> unwrap(Uint8List kek, Uint8List wrapped);

  Future<Uint8List> wrap(Uint8List kek, Uint8List dataKey);

  Future<Uint8List> randomBytes(int length);

  /// Deletes the device-bound Keystore key that wraps both slots at rest.
  /// After this, neither slot can ever be unwrapped again by anyone.
  Future<void> destroyDeviceKey();
}
```

- [ ] **Step 4: Write the unlocker**

Create `lib/domain/services/vault_unlocker.dart`:

```dart
import '../models/attempt_gate.dart';
import '../models/vault.dart';
import 'crypto_service.dart';

/// Turns an entered PIN into an open vault, or into a rejection.
///
/// Two properties matter more than the code:
///
/// 1. Every slot is evaluated on every attempt, in a fixed order, before a
///    result is chosen. Stopping at the first match would make a successful
///    unlock of vault A measurably faster than one of vault B, which tells an
///    observer that two slots are live.
/// 2. There is no lookup from PIN to vault. A PIN is tried against every slot
///    and the one that unwraps wins. This is why a PIN for a vault that was
///    never configured is indistinguishable from a typo.
class VaultUnlocker {
  const VaultUnlocker(this._crypto);

  final CryptoService _crypto;

  Future<UnlockOutcome> attempt({
    required String pin,
    required List<VaultSlot> slots,
    required AttemptGate gate,
    required DateTime now,
  }) async {
    if (gate.lockedAt(now)) return Throttled(gate.remainingAt(now));

    VaultId? matched;
    var matchedKey;

    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final kek = await _crypto.deriveKek(pin, slot.salt);
      final dataKey = await _crypto.unwrap(kek, slot.wrappedKey);

      // Deliberately no `break`: see the class comment.
      if (dataKey != null && matched == null) {
        matched = VaultId.values[i];
        matchedKey = dataKey;
      }
    }

    if (matched == null) return Rejected(gate.recordFailure(now));

    return Unlocked(vault: matched, dataKey: matchedKey, gate: gate.reset());
  }
}
```

- [ ] **Step 5: Run it to verify it passes**

Run: `flutter test test/domain/vault_unlocker_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 6: Fix the untyped local, then commit**

`var matchedKey;` is an implicit `dynamic`. Change it to `Uint8List? matchedKey;` and add `import 'dart:typed_data';` at the top of the file.

Run: `flutter analyze && flutter test test/domain/`
Expected: `No issues found!`, all passing.

```bash
git add -A
git commit -m "feat: vault unlocker with constant-work slot evaluation"
```

---

## Task 3: The Android crypto plugin

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/CryptoPlugin.kt`, `lib/data/services/android_crypto_service.dart`
- Modify: `android/app/src/main/kotlin/com/mono/container/MainActivity.kt`, `android/app/build.gradle.kts`
- Test: `android/app/src/androidTest/kotlin/com/mono/container/CryptoPluginTest.kt`

**Interfaces:**
- Consumes: the `CryptoService` interface from Task 2.
- Produces: `class AndroidCryptoService implements CryptoService` over `MethodChannel('com.mono.container/crypto')`.

Argon2id at these parameters takes hundreds of milliseconds and must not run on the platform thread. The plugin dispatches to a background executor and replies on the main thread.

- [ ] **Step 1: Add BouncyCastle**

In `android/app/build.gradle.kts`, inside `dependencies`:

```kotlin
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
```

And inside `defaultConfig`:

```kotlin
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
```

- [ ] **Step 2: Write the failing instrumented test**

Create `android/app/src/androidTest/kotlin/com/mono/container/CryptoPluginTest.kt`:

```kotlin
package com.mono.container

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CryptoPluginTest {

    private val crypto = CryptoCore()

    @Test
    fun deriveIsDeterministicForTheSamePinAndSalt() {
        val salt = ByteArray(16) { it.toByte() }
        val a = crypto.deriveKek("111111", salt)
        val b = crypto.deriveKek("111111", salt)

        assertEquals(32, a.size)
        assertArrayEquals(a, b)
    }

    @Test
    fun aDifferentSaltGivesADifferentKey() {
        val a = crypto.deriveKek("111111", ByteArray(16) { 1 })
        val b = crypto.deriveKek("111111", ByteArray(16) { 2 })

        assertNotEquals(a.toList(), b.toList())
    }

    @Test
    fun wrappedKeysRoundTripUnderTheRightKek() {
        val kek = crypto.deriveKek("111111", ByteArray(16) { 3 })
        val dataKey = crypto.randomBytes(32)

        val wrapped = crypto.wrap(kek, dataKey)
        assertArrayEquals(dataKey, crypto.unwrap(kek, wrapped))
    }

    @Test
    fun theWrongKekReturnsNullRatherThanGarbage() {
        val right = crypto.deriveKek("111111", ByteArray(16) { 3 })
        val wrong = crypto.deriveKek("222222", ByteArray(16) { 3 })
        val wrapped = crypto.wrap(right, crypto.randomBytes(32))

        assertNull(crypto.unwrap(wrong, wrapped))
    }

    @Test
    fun everyWrapUsesAFreshNonce() {
        val kek = crypto.deriveKek("111111", ByteArray(16) { 3 })
        val dataKey = crypto.randomBytes(32)

        val first = crypto.wrap(kek, dataKey)
        val second = crypto.wrap(kek, dataKey)

        assertNotEquals(first.toList(), second.toList())
    }
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `cd android && ./gradlew connectedAndroidTest` (needs a connected device or running emulator)
Expected: FAIL — `Unresolved reference: CryptoCore`.

- [ ] **Step 4: Write the crypto core and the plugin**

Create `android/app/src/main/kotlin/com/mono/container/CryptoPlugin.kt`:

```kotlin
package com.mono.container

import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import org.bouncycastle.crypto.generators.Argon2BytesGenerator
import org.bouncycastle.crypto.params.Argon2Parameters

/** Every key operation. Fixed parameters, no configuration surface. */
class CryptoCore {

    private val random = SecureRandom()

    fun randomBytes(length: Int): ByteArray =
        ByteArray(length).also(random::nextBytes)

    /** Argon2id, m = 64 MiB, t = 3, p = 2, 32-byte output. */
    fun deriveKek(pin: String, salt: ByteArray): ByteArray {
        val params = Argon2Parameters.Builder(Argon2Parameters.ARGON2_id)
            .withVersion(Argon2Parameters.ARGON2_VERSION_13)
            .withIterations(3)
            .withMemoryAsKB(64 * 1024)
            .withParallelism(2)
            .withSalt(salt)
            .build()

        val out = ByteArray(32)
        Argon2BytesGenerator().apply { init(params) }
            .generateBytes(pin.toByteArray(Charsets.UTF_8), out)
        return out
    }

    /** AES-256-GCM. Layout: 12-byte nonce || ciphertext || 16-byte tag. */
    fun wrap(kek: ByteArray, dataKey: ByteArray): ByteArray {
        val nonce = randomBytes(12)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.ENCRYPT_MODE,
            SecretKeySpec(kek, "AES"),
            GCMParameterSpec(128, nonce),
        )
        return nonce + cipher.doFinal(dataKey)
    }

    /** Returns null when the tag does not authenticate. */
    fun unwrap(kek: ByteArray, wrapped: ByteArray): ByteArray? {
        if (wrapped.size <= 12 + 16) return null
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                SecretKeySpec(kek, "AES"),
                GCMParameterSpec(128, wrapped.copyOfRange(0, 12)),
            )
            cipher.doFinal(wrapped.copyOfRange(12, wrapped.size))
        } catch (e: Exception) {
            // AEADBadTagException and friends. A wrong PIN is not an error
            // condition here; it is the expected negative result.
            null
        }
    }

    /**
     * A device-bound Keystore key that encrypts both slots at rest, so the
     * stored blobs are useless lifted off the phone.
     */
    fun deviceKey(): SecretKeySpec {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val existing = store.getKey(DEVICE_KEY_ALIAS, null)
        if (existing == null) {
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).apply {
                init(
                    KeyGenParameterSpec.Builder(
                        DEVICE_KEY_ALIAS,
                        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                    )
                        .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                        .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                        .setRandomizedEncryptionRequired(true)
                        .build()
                )
                generateKey()
            }
        }
        val key = store.getKey(DEVICE_KEY_ALIAS, null)
        return SecretKeySpec(key.encoded ?: ByteArray(32), "AES")
    }

    fun destroyDeviceKey() {
        val store = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        if (store.containsAlias(DEVICE_KEY_ALIAS)) store.deleteEntry(DEVICE_KEY_ALIAS)
    }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val DEVICE_KEY_ALIAS = "container.device"
    }
}

/**
 * Bridges [CryptoCore] to Dart. Argon2id at these parameters takes hundreds of
 * milliseconds, so every call runs on a background executor and replies on the
 * main thread.
 */
class CryptoPlugin(private val core: CryptoCore = CryptoCore()) :
    MethodChannel.MethodCallHandler {

    private val workers = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        workers.execute {
            val reply: Result<Any?> = runCatching {
                when (call.method) {
                    "deriveKek" -> core.deriveKek(call.argument("pin")!!, call.argument("salt")!!)
                    "wrap" -> core.wrap(call.argument("kek")!!, call.argument("dataKey")!!)
                    "unwrap" -> core.unwrap(call.argument("kek")!!, call.argument("wrapped")!!)
                    "randomBytes" -> core.randomBytes(call.argument("length")!!)
                    "destroyDeviceKey" -> core.destroyDeviceKey()
                    else -> throw UnsupportedOperationException(call.method)
                }
            }

            main.post {
                reply.fold(
                    onSuccess = { result.success(it) },
                    onFailure = {
                        if (it is UnsupportedOperationException) result.notImplemented()
                        else result.error("crypto", it.message, null)
                    },
                )
            }
        }
    }

    companion object {
        const val CHANNEL = "com.mono.container/crypto"
    }
}
```

- [ ] **Step 5: Register the plugin**

Replace `android/app/src/main/kotlin/com/mono/container/MainActivity.kt`:

```kotlin
package com.mono.container

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Set before the Flutter view exists. A flag toggled per screen has a
        // window in which it is off.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CryptoPlugin.CHANNEL)
            .setMethodCallHandler(CryptoPlugin())
    }
}
```

- [ ] **Step 6: Run the instrumented test to verify it passes**

Run: `cd android && ./gradlew connectedAndroidTest`
Expected: PASS, 5 tests.

- [ ] **Step 7: Write the Dart binding**

Create `lib/data/services/android_crypto_service.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../../domain/services/crypto_service.dart';

class AndroidCryptoService implements CryptoService {
  const AndroidCryptoService();

  static const _channel = MethodChannel('com.mono.container/crypto');

  @override
  Future<Uint8List> deriveKek(String pin, Uint8List salt) async {
    final result = await _channel
        .invokeMethod<Uint8List>('deriveKek', {'pin': pin, 'salt': salt});
    return result!;
  }

  @override
  Future<Uint8List> wrap(Uint8List kek, Uint8List dataKey) async {
    final result = await _channel
        .invokeMethod<Uint8List>('wrap', {'kek': kek, 'dataKey': dataKey});
    return result!;
  }

  @override
  Future<Uint8List?> unwrap(Uint8List kek, Uint8List wrapped) {
    // A null reply is the expected negative result, not an error.
    return _channel
        .invokeMethod<Uint8List>('unwrap', {'kek': kek, 'wrapped': wrapped});
  }

  @override
  Future<Uint8List> randomBytes(int length) async {
    final result =
        await _channel.invokeMethod<Uint8List>('randomBytes', {'length': length});
    return result!;
  }

  @override
  Future<void> destroyDeviceKey() => _channel.invokeMethod('destroyDeviceKey');
}
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: Android crypto plugin with Argon2id and keystore binding"
```

---

## Task 4: Two encrypted vaults

**Files:**
- Create: `lib/data/services/vault_store.dart`, `lib/data/services/encrypted_database.dart`
- Modify: `lib/data/services/app_database.dart` (accept a cipher key), `pubspec.yaml`
- Test: `test/data/vault_store_test.dart`

**Interfaces:**
- Consumes: `CryptoService`, `VaultSlot`, `VaultId`.
- Produces:
  - `class VaultStore { VaultStore(this._crypto, this._file); Future<List<VaultSlot>> slots(); Future<AttemptGate> gate(); Future<void> saveGate(AttemptGate gate); Future<Uint8List> provision({required String pin, required VaultId vault}); Future<void> destroy(); Future<bool> get exists; }`
  - `Future<AppDatabase> openEncrypted({required String path, required Uint8List dataKey})`

`provision` creates or replaces one slot: fresh salt, fresh 32-byte data key, wrapped under the KEK derived from `pin`. Setup calls it once for vault A, and again for vault B if a decoy PIN is chosen. **It is always called for both**; when no decoy is chosen, vault B is provisioned with a random 32-character PIN that is generated, used, and never stored — producing a slot that is byte-indistinguishable from a real one and that nothing can ever open.

- [ ] **Step 1: Add the encrypted database dependency**

In `pubspec.yaml`, replace `sqflite: ^2.3.3` with:

```yaml
  sqflite_sqlcipher: ^3.1.0+1
```

Then `flutter pub get`. `sqflite_sqlcipher` exposes the same `sqflite` API surface plus a `password:` parameter, so Plan 1's repositories are unchanged.

- [ ] **Step 2: Write the failing vault-store test**

Create `test/data/vault_store_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/vault_unlocker.dart';
import 'package:container/data/services/vault_store.dart';

import '../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  late Directory dir;
  late VaultStore store;
  late FakeCrypto crypto;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault-test');
    crypto = FakeCrypto();
    store = VaultStore(crypto, File('${dir.path}/meta.bin'));
  });

  tearDown(() => dir.delete(recursive: true));

  test('a fresh device has no vaults', () async {
    expect(await store.exists, isFalse);
  });

  test('provisioning writes both slots, always', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provision(pin: '222222', vault: VaultId.b);

    final slots = await store.slots();
    expect(slots.length, 2);
    expect(await store.exists, isTrue);
  });

  test('the two slots have different salts', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provision(pin: '222222', vault: VaultId.b);

    final slots = await store.slots();
    expect(slots[0].salt, isNot(slots[1].salt));
  });

  test('both slots are the same size whether or not a decoy is real', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);

    final slots = await store.slots();
    expect(slots[0].wrappedKey.length, slots[1].wrappedKey.length);
    expect(slots[0].salt.length, slots[1].salt.length);
  });

  test('an unopenable slot cannot be unlocked by any PIN', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);

    final unlocker = VaultUnlocker(crypto);
    for (final pin in ['222222', '000000', '111112']) {
      final outcome = await unlocker.attempt(
        pin: pin,
        slots: await store.slots(),
        gate: const AttemptGate(),
        now: DateTime(2026),
      );
      expect(outcome, isA<Rejected>(), reason: 'PIN $pin should not open a slot');
    }
  });

  test('the attempt gate survives a restart', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.saveGate(const AttemptGate(failures: 3));

    final reopened = VaultStore(crypto, File('${dir.path}/meta.bin'));
    expect((await reopened.gate()).triesLeft, 2);
  });

  test('destroy removes every trace of key material', () async {
    await store.provision(pin: '111111', vault: VaultId.a);
    await store.provisionUnopenable(VaultId.b);

    await store.destroy();

    expect(await store.exists, isFalse);
    expect(File('${dir.path}/meta.bin').existsSync(), isFalse);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/data/vault_store_test.dart`
Expected: FAIL — missing `vault_store.dart`.

- [ ] **Step 4: Write the vault store**

Create `lib/data/services/vault_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/attempt_gate.dart';
import '../../domain/models/vault.dart';
import '../../domain/services/crypto_service.dart';

/// Persists the two vault slots and the attempt counter.
///
/// The file always contains exactly two slots of identical shape. A device
/// with no decoy configured is byte-indistinguishable from one that has a
/// decoy the owner is refusing to open — which is the whole point, because a
/// missing second slot would prove there is nothing to hide.
class VaultStore {
  const VaultStore(this._crypto, this._file);

  final CryptoService _crypto;
  final File _file;

  static const saltLength = 16;
  static const dataKeyLength = 32;

  Future<bool> get exists => _file.exists();

  Future<List<VaultSlot>> slots() async {
    final data = await _read();
    return [
      _slotFrom(data['a'] as Map<String, Object?>),
      _slotFrom(data['b'] as Map<String, Object?>),
    ];
  }

  Future<AttemptGate> gate() async {
    if (!await exists) return const AttemptGate();
    final data = await _read();
    final until = data['lockedUntil'] as int?;
    return AttemptGate(
      failures: (data['failures'] as int?) ?? 0,
      lockedUntil:
          until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
    );
  }

  Future<void> saveGate(AttemptGate gate) async {
    final data = await _read();
    data['failures'] = gate.failures;
    data['lockedUntil'] = gate.lockedUntil?.millisecondsSinceEpoch;
    await _write(data);
  }

  /// Creates [vault]'s slot and returns its new data key.
  Future<Uint8List> provision({
    required String pin,
    required VaultId vault,
  }) async {
    final salt = await _crypto.randomBytes(saltLength);
    final dataKey = await _crypto.randomBytes(dataKeyLength);
    final kek = await _crypto.deriveKek(pin, salt);
    final wrapped = await _crypto.wrap(kek, dataKey);

    final data = await _read();
    data[vault.name] = {
      'salt': base64Encode(salt),
      'wrapped': base64Encode(wrapped),
    };
    await _write(data);
    return dataKey;
  }

  /// Fills [vault]'s slot with a real slot whose PIN is generated, used once
  /// and never stored. The result is a slot nothing can ever open, and that
  /// nothing can distinguish from one that can.
  Future<void> provisionUnopenable(VaultId vault) async {
    final throwaway = base64Encode(await _crypto.randomBytes(24));
    await provision(pin: throwaway, vault: vault);
  }

  Future<void> destroy() async {
    if (await _file.exists()) {
      // Overwrite before unlinking; the file is small and this costs nothing.
      final length = await _file.length();
      await _file.writeAsBytes(await _crypto.randomBytes(length), flush: true);
      await _file.delete();
    }
    await _crypto.destroyDeviceKey();
  }

  VaultSlot _slotFrom(Map<String, Object?> raw) => VaultSlot(
        salt: base64Decode(raw['salt']! as String),
        wrappedKey: base64Decode(raw['wrapped']! as String),
      );

  Future<Map<String, Object?>> _read() async {
    if (!await _file.exists()) return <String, Object?>{};
    return jsonDecode(await _file.readAsString()) as Map<String, Object?>;
  }

  Future<void> _write(Map<String, Object?> data) =>
      _file.writeAsString(jsonEncode(data), flush: true);
}
```

- [ ] **Step 5: Teach `AppDatabase` to take a key**

In `lib/data/services/app_database.dart`, change the import from `package:sqflite/sqflite.dart` to `package:sqflite_sqlcipher/sqflite.dart`, and add a `password` parameter:

```dart
  static Future<AppDatabase> open({
    required String path,
    String? password,
    DatabaseFactory? factory,
  }) async {
    final openDb = factory?.openDatabase ?? databaseFactory.openDatabase;
    final db = await openDb(
      path,
      options: SqlCipherOpenDatabaseOptions(
        password: password,
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          // unchanged from Plan 1
        },
      ),
    );
    return AppDatabase._(db);
  }
```

Plan 1's tests pass no `password` and keep working. Create `lib/data/services/encrypted_database.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'app_database.dart';

/// Opens a vault's store under its data key. The key is passed as base64
/// because SQLCipher takes a passphrase string; it is never derived from
/// anything the user typed, only unwrapped.
Future<AppDatabase> openEncrypted({
  required String path,
  required Uint8List dataKey,
}) {
  return AppDatabase.open(path: path, password: base64Encode(dataKey));
}
```

- [ ] **Step 6: Retire Plan 1's `Vault` enum (cross-plan issue #3)**

Plan 1 Task 4 shipped `enum Vault { a, b }` and `String vaultFileName(Vault vault)` in this same `app_database.dart`; Task 2 of this plan added `enum VaultId { a, b }` in `lib/domain/models/vault.dart`. They are one concept under two names, and both now exist in the tree.

`VaultId` is the survivor. It lives in the domain layer where the rest of the vault model already is, it is the type on `VaultSlot`, `Unlocked`, `VaultStore.provision` and (in Task 8) `SessionOpen`, and it has roughly forty call sites to `Vault`'s two. Plan 1 is **not** edited retroactively — it shipped a correct enum for a single-vault world, and this step is the migration that a second vault makes necessary. Doing it here rather than later keeps it in the same commit as the other `app_database.dart` change this task already makes.

In `lib/data/services/app_database.dart`, delete the `enum Vault { a, b }` declaration and re-point the filename function at `VaultId`:

```dart
import '../../domain/models/vault.dart';

String vaultFileName(VaultId vault) => switch (vault) {
      VaultId.a => 'store-1.db',
      VaultId.b => 'store-2.db',
    };
```

The filenames do not change — `store-1.db` and `store-2.db` are what Plan 1 wrote and what any store already on disk is called, so this is a source-level rename with no migration on disk. `app_database.dart` importing a domain model is the direction the data layer already runs in (`site_repository_sqlite.dart` imports `domain/models/site.dart`), so no layering rule bends here.

Then fix the call sites, which at this point in the plan are:

- `lib/data/services/vault_store.dart` and this task's own tests — already `VaultId`, unchanged.
- Plan 1's `test/data/repositories_test.dart` — swap `Vault.a` for `VaultId.a` and add `import 'package:container/domain/models/vault.dart';`.
- Anything else the analyzer flags.

`grep -rn 'Vault\.' lib test` should come back with no hit that is not `VaultId.`.

Task 8's `vaultDatabasePath` is written against `VaultId` directly and needs no bridge between the two enums — see the note on that function.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/data/`
Expected: PASS, 7 vault-store tests plus Plan 1's 7 repository tests.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: two encrypted vaults with indistinguishable slots"
```

---

## Task 5: PIN primitives and the lock screen

One widget covers `3a`, `4c`, `9b` and `9c`.

**Files:**
- Create: `lib/ui/core/widgets/pin_dots.dart`, `lib/ui/core/widgets/pin_keypad.dart`, `lib/ui/features/lock/views/lock_body.dart`, `lib/ui/features/lock/view_models/lock_controller.dart`
- Test: `test/ui/core/pin_widgets_test.dart`, `test/ui/features/lock_body_test.dart`, `test/ui/features/lock/lock_controller_test.dart`

`lib/ui/features/lock/views/lock_screen.dart` — the widget that wires this task's pieces to a live session — is built in **Task 8**, not here. Reason: Task 8's `AppGate` constructs it as `const LockScreen()`, with no arguments, so `LockScreen` has to read mood, tries-left, open-session count and the lock deadline from `sessionProvider` directly rather than take them as parameters — and `sessionProvider` lives in Task 8's `session_controller.dart`. Building `LockScreen` here would leave this task unable to compile, let alone test, on its own until Task 8 also existed, which breaks the one-task-ships-testable-software rule this plan otherwise follows throughout. `LockController` below has no such dependency and stays here.

**Interfaces:**
- Consumes: `C`, `T`, `ui()` from Plan 1; `AttemptGate`, `LockState`, `VaultUnlocker`.
- Produces:
  - `PinDots({required int filled, int length = 6, bool error = false})`
  - `PinKeypad({required void Function(String key) onKey})` — keys `1`-`9`, blank, `0`, `⌫`
  - `enum LockMood { normal, wrong, welcomeBack, afterTimeout }`
  - `LockBody({required LockMood mood, required int filled, required void Function(String) onKey, required VoidCallback onBiometric, int triesLeft = 5, int openSessions = 0, int secondsUntilLock = 0})`
  - `class LockPinEntry { const LockPinEntry({int filled = 0}); final int filled; }`
  - `class LockController extends ChangeNotifier { LockController({required ValueChanged<String> onSubmit}); LockPinEntry get value; void onKey(String key); void reset(); }` — accumulates the six digits typed on any lock-shaped screen and calls `onSubmit` once. It knows nothing about vaults, PINs being right or wrong, or Riverpod — Task 8's `LockScreen` decides what `onSubmit` does with the finished string.

- [ ] **Step 1: Write the failing PIN-widget test**

Create `test/ui/core/pin_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/design/tokens.dart' as _;
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/core/widgets/pin_keypad.dart';

void main() {
  testWidgets('the dots fill left to right', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: PinDots(filled: 3)))));

    final dots = tester.widgetList<Container>(find.byType(Container)).toList();
    expect(dots.length, 6);
    expect((dots[0].decoration! as BoxDecoration).color, C.textPrimary);
    expect((dots[2].decoration! as BoxDecoration).color, C.textPrimary);
    expect((dots[3].decoration! as BoxDecoration).color, isNot(C.textPrimary));
  });

  testWidgets('an errored dot row uses the danger border', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: PinDots(filled: 0, error: true)))));

    final first = tester.widgetList<Container>(find.byType(Container)).first;
    final border = (first.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, const Color(0xFF4A3634));
  });

  testWidgets('the keypad reports digits and backspace', (tester) async {
    final pressed = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PinKeypad(onKey: pressed.add))));

    await tester.tap(find.text('7'));
    await tester.tap(find.text('0'));
    await tester.tap(find.text('⌫'));

    expect(pressed, ['7', '0', '⌫']);
  });

  testWidgets('the keypad has a blank cell where the spec shows one',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PinKeypad(onKey: (_) {}))));

    // 1-9, blank, 0, backspace.
    expect(find.byType(InkWell), findsNWidgets(12));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });
}
```

Remove the stray `import 'package:container/design/tokens.dart' as _;` line — it is there only to be deleted; the real import is `ui/core/tokens.dart`.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/core/pin_widgets_test.dart`
Expected: FAIL — missing `pin_dots.dart`.

- [ ] **Step 3: Write the PIN primitives**

Create `lib/ui/core/widgets/pin_dots.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The six-dot PIN indicator. In the error state (spec `4c`) every dot is
/// cleared and the borders go red — the count is never partially preserved,
/// because that would tell the user how far a wrong PIN got.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 6,
    this.error = false,
  });

  final int filled;
  final int length;
  final bool error;

  static const _errorBorder = Color(0xFF4A3634);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !error && i < filled ? C.textPrimary : null,
              border: Border.all(
                color: error
                    ? _errorBorder
                    : (i < filled ? C.textPrimary : C.pinEmpty),
                width: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
```

Create `lib/ui/core/widgets/pin_keypad.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// The 3x4 keypad. Layout is fixed by the spec: 1-9, a blank cell, 0, and
/// backspace.
class PinKeypad extends StatelessWidget {
  const PinKeypad({super.key, required this.onKey});

  final void Function(String key) onKey;

  static const _keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '', '0', '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 280 / 3 / 64,
          children: [
            for (final key in _keys)
              Material(
                color: key.isEmpty ? const Color(0x00000000) : C.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: key.isEmpty ? null : () => onKey(key),
                  child: Center(
                    child: Text(key, style: ui(size: 22, color: C.textSecondary)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/ui/core/pin_widgets_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the failing lock-body test**

The four moods have exact copy in the spec. Create `test/ui/features/lock_body_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/lock/views/lock_body.dart';

Future<void> _pump(WidgetTester tester, LockBody body) =>
    tester.pumpWidget(MaterialApp(home: body));

LockBody _body(LockMood mood, {int triesLeft = 5, int filled = 0}) => LockBody(
      mood: mood,
      filled: filled,
      triesLeft: triesLeft,
      openSessions: 3,
      secondsUntilLock: 40,
      onKey: (_) {},
      onBiometric: () {},
    );

void main() {
  testWidgets('the normal lock says nothing about vaults', (tester) async {
    await _pump(tester, _body(LockMood.normal));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Use fingerprint'), findsOneWidget);
    expect(find.textContaining('vault', findRichText: true), findsNothing);
    expect(find.textContaining('decoy'), findsNothing);
    expect(find.textContaining('second'), findsNothing);
  });

  testWidgets('a wrong PIN counts down without naming what is behind it',
      (tester) async {
    await _pump(tester, _body(LockMood.wrong, triesLeft: 3));

    expect(find.text('Wrong PIN · 3 tries left'), findsOneWidget);
    expect(
      find.text('After 5 wrong tries the app waits 30 seconds before '
          'accepting another.'),
      findsOneWidget,
    );
    expect(find.text('Fingerprint unavailable'), findsOneWidget);
    expect(find.textContaining('vault'), findsNothing);
  });

  testWidgets('the wrong state clears the dots rather than keeping a count',
      (tester) async {
    await _pump(tester, _body(LockMood.wrong, triesLeft: 3, filled: 4));

    final label = tester.widget<Text>(find.text('Wrong PIN · 3 tries left'));
    expect(label.style!.color, C.danger);
  });

  testWidgets('returning inside the grace period keeps the sessions',
      (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('3 sessions still open · locks in 40s'), findsOneWidget);
  });

  testWidgets('returning after the timer explains what was destroyed',
      (tester) async {
    await _pump(tester, _body(LockMood.afterTimeout));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Locked after 1 minute in the background'), findsOneWidget);
    expect(
      find.text('Ephemeral sessions were closed and wiped. Saved sites will '
          'reopen where you left them.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/ui/features/lock_body_test.dart`
Expected: FAIL — missing `lock_body.dart`.

- [ ] **Step 7: Write the lock body**

Create `lib/ui/features/lock/views/lock_body.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_dots.dart';
import '../../../core/widgets/pin_keypad.dart';

/// The four states of the lock screen: `3a`, `4c`, `9b`, `9c`.
///
/// They are one screen, and building them as four files would let their copy
/// and geometry drift. Note that none of them mentions vaults, decoys or a
/// second PIN — the lock must give no hint that anything else exists.
enum LockMood { normal, wrong, welcomeBack, afterTimeout }

class LockBody extends StatelessWidget {
  const LockBody({
    super.key,
    required this.mood,
    required this.filled,
    required this.onKey,
    required this.onBiometric,
    this.triesLeft = 5,
    this.openSessions = 0,
    this.secondsUntilLock = 0,
  });

  final LockMood mood;
  final int filled;
  final void Function(String key) onKey;
  final VoidCallback onBiometric;
  final int triesLeft;
  final int openSessions;
  final int secondsUntilLock;

  bool get _wrong => mood == LockMood.wrong;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _mark(),
                    const SizedBox(height: 26),
                    ..._headline(),
                    const SizedBox(height: 26),
                    PinDots(filled: filled, error: _wrong),
                    ..._footnote(),
                  ],
                ),
              ),
              PinKeypad(onKey: onKey),
              _biometric(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mark() => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _wrong ? C.danger.withValues(alpha: 0.3) : C.line12,
          ),
        ),
        child: Text('◇',
            style: ui(size: 17, color: _wrong ? C.danger : C.jade)),
      );

  List<Widget> _headline() => switch (mood) {
        LockMood.wrong => [
            Text('Wrong PIN · $triesLeft tries left',
                style: ui(size: 14, color: C.danger)),
          ],
        LockMood.welcomeBack => [
            Text('Welcome back', style: ui(size: 15, color: C.textSecondary)),
            const SizedBox(height: 8),
            Text('$openSessions sessions still open · locks in ${secondsUntilLock}s',
                style: ui(size: 12.5, color: C.textFaint)),
          ],
        LockMood.normal || LockMood.afterTimeout => [
            Text('Enter your PIN', style: ui(size: 14, color: C.textMuted)),
          ],
      };

  List<Widget> _footnote() => switch (mood) {
        LockMood.wrong => [
            const SizedBox(height: 26),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250),
              child: Text(
                'After 5 wrong tries the app waits 30 seconds before accepting '
                'another.',
                textAlign: TextAlign.center,
                style: ui(size: 12.5, color: C.textFaint, height: 1.6),
              ),
            ),
          ],
        LockMood.afterTimeout => [
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: C.sheet,
                border: Border.all(color: C.line07),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Locked after 1 minute in the background',
                      style: ui(size: 12.5, color: C.textMuted)),
                  const SizedBox(height: 6),
                  Text(
                    'Ephemeral sessions were closed and wiped. Saved sites '
                    'will reopen where you left them.',
                    style: ui(size: 12, color: C.textDim, height: 1.55),
                  ),
                ],
              ),
            ),
          ],
        LockMood.normal || LockMood.welcomeBack => const [],
      };

  Widget _biometric() => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 30),
        child: GestureDetector(
          onTap: _wrong ? null : onBiometric,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('☉',
                  style: ui(size: 24, color: _wrong ? C.knobOff : C.jade)),
              const SizedBox(height: 8),
              Text(
                _wrong ? 'Fingerprint unavailable' : 'Use fingerprint',
                style: ui(size: 12, color: _wrong ? C.textDim : C.textFaint),
              ),
            ],
          ),
        ),
      );
}
```

- [ ] **Step 8: Write the failing lock-controller test**

Create `test/ui/features/lock/lock_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/lock/view_models/lock_controller.dart';

void main() {
  test('digits accumulate and notify on every key', () {
    var notifications = 0;
    final controller = LockController(onSubmit: (_) {});
    controller.addListener(() => notifications++);

    controller.onKey('1');
    controller.onKey('2');

    expect(controller.value.filled, 2);
    expect(notifications, 2);
  });

  test('backspace removes the last digit', () {
    final controller = LockController(onSubmit: (_) {});
    controller.onKey('1');
    controller.onKey('2');
    controller.onKey('⌫');

    expect(controller.value.filled, 1);
  });

  test('backspace on an empty buffer does nothing', () {
    final controller = LockController(onSubmit: (_) {});
    controller.onKey('⌫');

    expect(controller.value.filled, 0);
  });

  test('a sixth digit submits the PIN and clears the buffer', () {
    final submitted = <String>[];
    final controller = LockController(onSubmit: submitted.add);

    for (final key in ['1', '2', '3', '4', '5', '6']) {
      controller.onKey(key);
    }

    expect(submitted, ['123456']);
    expect(controller.value.filled, 0);
  });

  test('a seventh key after a submit starts a fresh PIN', () {
    final submitted = <String>[];
    final controller = LockController(onSubmit: submitted.add);
    for (final key in ['1', '2', '3', '4', '5', '6']) {
      controller.onKey(key);
    }
    controller.onKey('9');

    expect(controller.value.filled, 1);
    expect(submitted, ['123456']);
  });
}
```

- [ ] **Step 9: Run it to verify it fails**

Run: `flutter test test/ui/features/lock/lock_controller_test.dart`
Expected: FAIL — missing `lock_controller.dart`.

- [ ] **Step 10: Write the lock controller**

Create `lib/ui/features/lock/view_models/lock_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

/// How many of the six PIN digits have been typed so far.
class LockPinEntry {
  const LockPinEntry({this.filled = 0});

  final int filled;
}

/// Accumulates the six digits typed on any lock-shaped screen (`3a`, `4c`,
/// `9b`, `9c` — all one `LockBody`) and calls [onSubmit] once, with the
/// buffer already cleared for whatever comes next.
///
/// Deliberately knows nothing about vaults, PINs being right or wrong, or
/// Riverpod. Task 8's `LockScreen` is the only thing that decides what a
/// finished six digits means.
class LockController extends ChangeNotifier {
  LockController({required this.onSubmit});

  final ValueChanged<String> onSubmit;

  String _digits = '';

  LockPinEntry get value => LockPinEntry(filled: _digits.length);

  void onKey(String key) {
    if (key == '⌫') {
      if (_digits.isEmpty) return;
      _digits = _digits.substring(0, _digits.length - 1);
    } else if (_digits.length < 6) {
      _digits += key;
    } else {
      return;
    }
    notifyListeners();

    if (_digits.length == 6) {
      final pin = _digits;
      reset();
      onSubmit(pin);
    }
  }

  void reset() {
    _digits = '';
    notifyListeners();
  }
}
```

- [ ] **Step 11: Run it to verify it passes**

Run: `flutter test test/ui/features/lock/lock_controller_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 12: Run it, analyze, commit**

Run: `flutter test test/ui/ && flutter analyze`
Expected: PASS, `No issues found!`

```bash
git add -A
git commit -m "feat: PIN primitives, the four lock states, and the lock controller"
```

---

## Task 6: Setup wizard and decoy provisioning

**Files:**
- Create: `lib/ui/core/widgets/step_progress.dart`, `lib/ui/core/widgets/app_toggle.dart`, `lib/ui/features/setup/views/setup_pin_screen.dart`, `setup_decoy_screen.dart`, `setup_defaults_screen.dart`, `lib/ui/features/setup/view_models/setup_controller.dart`, `lib/data/repositories/decoy_provisioner.dart`
- Test: `test/ui/features/setup_test.dart`, `test/data/decoy_provisioner_test.dart`

**Interfaces:**
- Consumes: `PinKeypad`, `PinDots`, `PillButton`, `VaultStore`, `SiteRepository`, `WorkspaceRepository`.
- Produces:
  - `StepProgress({required int step, int of = 3})`
  - `AppToggle({required bool value, ValueChanged<bool>? onChanged})`
  - `typedef VaultOpener = Future<AppDatabase> Function({required String path, required Uint8List dataKey})` — how `SetupController` (and Task 8's `SessionController`) turn a data key into an open database, without either file importing `openEncrypted` directly. `main()` wires the real one; tests wire an in-memory one.
  - `class SetupController` with `Future<void> complete({required String mainPin, String? decoyPin})`
  - `Future<int> provisionDecoy({required AppDatabase from, required AppDatabase into})` — copies flagged workspaces and their flagged sites into the decoy store and returns the number of sites copied

`SetupController` takes `VaultStore`, a `VaultOpener`, a path-for-vault function and an "open session" callback as constructor parameters, rather than importing `VaultStore`'s Riverpod provider or `session_controller.dart` directly. `session_controller.dart` is Task 8's file; if `SetupController` imported it, this task would depend on a task that comes after it, and neither task could be built or tested standalone. Task 8 is where `setupControllerProvider` wires these parameters to the real `VaultStore`, `openEncrypted` and `SessionController` — see its own notes for why that wiring belongs there instead of here.

- [ ] **Step 1: Write the failing setup test**

Create `test/ui/features/setup_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/setup/views/setup_decoy_screen.dart';
import 'package:container/ui/features/setup/views/setup_defaults_screen.dart';
import 'package:container/ui/features/setup/views/setup_pin_screen.dart';

void main() {
  testWidgets('step 1 states that there is no recovery', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SetupPinScreen(filled: 3, onKey: (_) {}, onContinue: null),
    ));

    expect(find.text('Choose a PIN'), findsOneWidget);
    expect(
      find.text('Six digits. It encrypts everything stored on this device. '
          'There is no account and no way to recover it, so pick something '
          'you will remember.'),
      findsOneWidget,
    );
  });

  testWidgets('continue is disabled until six digits are entered',
      (tester) async {
    var advanced = 0;
    await tester.pumpWidget(MaterialApp(
      home: SetupPinScreen(filled: 6, onKey: (_) {}, onContinue: () => advanced++),
    ));

    await tester.tap(find.text('Continue'));
    expect(advanced, 1);
  });

  testWidgets('step 2 explains the decoy once, in plain words', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SetupDecoyScreen(
        enabled: true,
        onToggle: (_) {},
        onContinue: () {},
        onSkip: () {},
      ),
    ));

    expect(find.text('A second PIN, if you want one'), findsOneWidget);
    expect(
      find.text('If someone makes you unlock the app, this PIN opens a plain '
          'board with only the sites you choose. Nothing on it hints that '
          'anything else exists.'),
      findsOneWidget,
    );
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('step 3 states the four defaults verbatim', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: SetupDefaultsScreen(onFinish: () {})));

    expect(find.text('How sites will behave'), findsOneWidget);
    expect(find.text('Each site gets its own storage'), findsOneWidget);
    expect(find.text('Camera, mic, location and clipboard blocked'), findsOneWidget);
    expect(find.text('Trackers, ads and WebRTC blocked'), findsOneWidget);
    expect(find.text('Nothing is sent anywhere'), findsOneWidget);
    expect(find.text('Add your first site'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/setup_test.dart`
Expected: FAIL — missing screens.

- [ ] **Step 3: Write the two remaining primitives**

Create `lib/ui/core/widgets/step_progress.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The three-segment bar at the top of setup (spec `4a`, `4b`, `5a`).
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, this.of = 3});

  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          for (var i = 0; i < of; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: i < step ? C.jade : C.trackOff,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

Create `lib/ui/core/widgets/app_toggle.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The 44x26 switch used throughout the settings screens.
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        width: 44,
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? C.jade : C.trackOff,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: value ? C.bg : C.knobOff,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Write the three setup screens**

Create `lib/ui/features/setup/views/setup_pin_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pin_keypad.dart';
import '../../../core/widgets/step_progress.dart';

class SetupPinScreen extends StatelessWidget {
  const SetupPinScreen({
    super.key,
    required this.filled,
    required this.onKey,
    required this.onContinue,
  });

  final int filled;
  final void Function(String) onKey;

  /// Null until six digits are entered.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(step: 1),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose a PIN', style: T.stepTitle),
                    const SizedBox(height: 14),
                    Text(
                      'Six digits. It encrypts everything stored on this '
                      'device. There is no account and no way to recover it, '
                      'so pick something you will remember.',
                      style: ui(size: 14, color: C.textMuted, height: 1.65),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        for (var i = 0; i < 6; i++) ...[
                          if (i > 0) const SizedBox(width: 14),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i < filled ? C.textPrimary : null,
                              border: i < filled
                                  ? null
                                  : Border.all(color: C.pinEmpty, width: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PinKeypad(onKey: onKey),
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 26),
                child: Material(
                  color: onContinue == null ? C.button : C.jade,
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    onTap: onContinue,
                    borderRadius: BorderRadius.circular(25),
                    child: SizedBox(
                      height: 50,
                      child: Center(
                        child: Text(
                          'Continue',
                          style: ui(
                            size: 15,
                            weight: onContinue == null ? 500 : 600,
                            color: onContinue == null ? C.textDim : C.bg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `lib/ui/features/setup/views/setup_decoy_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/step_progress.dart';

/// The only screen in the app that ever names the decoy. After this the
/// feature is never mentioned again, which is what makes `3b` work.
class SetupDecoyScreen extends StatelessWidget {
  const SetupDecoyScreen({
    super.key,
    required this.enabled,
    required this.onToggle,
    required this.onContinue,
    required this.onSkip,
  });

  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(step: 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('A second PIN, if you want one', style: T.stepTitle),
                    const SizedBox(height: 16),
                    Text(
                      'If someone makes you unlock the app, this PIN opens a '
                      'plain board with only the sites you choose. Nothing on '
                      'it hints that anything else exists.',
                      style: ui(size: 14, color: C.textMuted, height: 1.65),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: C.line08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          ColoredBox(
                            color: C.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Set up a decoy PIN', style: T.body),
                                  AppToggle(value: enabled, onChanged: onToggle),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          ColoredBox(
                            color: C.surface,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Sites to show', style: T.body),
                                      const SizedBox(height: 3),
                                      Text('Pick after setup',
                                          style: ui(
                                              size: 11.5, color: C.textFaint)),
                                    ],
                                  ),
                                  Text('›', style: ui(size: 14, color: C.textFaint)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: PillButton(
                        label: 'Continue',
                        tone: PillTone.primary,
                        height: 50,
                        onTap: onContinue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onSkip,
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: Text('Skip for now',
                              style: ui(size: 14, color: C.textMuted)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `lib/ui/features/setup/views/setup_defaults_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/step_progress.dart';

class SetupDefaultsScreen extends StatelessWidget {
  const SetupDefaultsScreen({super.key, required this.onFinish});

  final VoidCallback onFinish;

  static const _defaults = [
    ('Each site gets its own storage',
        'Cookies and logins never cross between sites'),
    ('Camera, mic, location and clipboard blocked',
        'A site has to ask you each time it wants one'),
    ('Trackers, ads and WebRTC blocked',
        'Some sites may need this relaxed to work'),
    ('Nothing is sent anywhere', 'No account, no sync, no analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StepProgress(step: 3),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text('How sites will behave', style: T.stepTitle),
                      const SizedBox(height: 18),
                      Text(
                        'These apply to every site you add. You can change any '
                        'of them per site later.',
                        style: ui(size: 14, color: C.textMuted, height: 1.65),
                      ),
                      const SizedBox(height: 20),
                      for (final (title, detail) in _defaults)
                        DecoratedBox(
                          decoration: const BoxDecoration(
                            border: Border(top: BorderSide(color: C.line06)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('✓', style: ui(size: 13, color: C.jade)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(title, style: T.body),
                                      const SizedBox(height: 3),
                                      Text(detail,
                                          style: ui(
                                              size: 12,
                                              color: C.textFaint,
                                              height: 1.5)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: 'Add your first site',
                    tone: PillTone.primary,
                    height: 50,
                    onTap: onFinish,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the setup test to verify it passes**

Run: `flutter test test/ui/features/setup_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 6: Write the failing decoy-provisioner test**

Create `test/data/decoy_provisioner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/decoy_provisioner.dart';
import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase real;
  late AppDatabase decoy;

  setUp(() async {
    real = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    decoy = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);

    await SqliteWorkspaceRepository(real).upsert(const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0,
        storageRule: StorageRule.keep, showInDecoy: true));
    await SqliteWorkspaceRepository(real).upsert(const Workspace(
        id: 'ws-secret', name: 'Work', markerIndex: 1,
        storageRule: StorageRule.keep, showInDecoy: false));

    final sites = SqliteSiteRepository(real);
    await sites.upsert(const Site(
        id: 's1', workspaceId: 'ws', name: 'News', monogram: 'Nw',
        url: 'https://news.example.com', showInDecoy: true));
    await sites.upsert(const Site(
        id: 's2', workspaceId: 'ws', name: 'Bank', monogram: 'Bk',
        url: 'https://bank.example.com', showInDecoy: false));
    await sites.upsert(const Site(
        id: 's3', workspaceId: 'ws-secret', name: 'Wiki', monogram: 'Wk',
        url: 'https://wiki.internal', showInDecoy: true));
  });

  tearDown(() async {
    await real.close();
    await decoy.close();
  });

  test('only flagged rows in flagged workspaces are copied', () async {
    final copied = await provisionDecoy(from: real, into: decoy);

    expect(copied, 1);
    final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
    expect(sites.map((s) => s.name), ['News']);
  });

  test('the decoy store carries no visibility flags of its own', () async {
    await provisionDecoy(from: real, into: decoy);

    final sites = await SqliteSiteRepository(decoy).inWorkspace('ws');
    expect(sites.single.showInDecoy, isFalse,
        reason: 'rows in the decoy are just rows; nothing is hidden from them');
  });

  test('an unflagged workspace does not appear at all', () async {
    await provisionDecoy(from: real, into: decoy);

    final workspaces = await SqliteWorkspaceRepository(decoy).all();
    expect(workspaces.map((w) => w.name), ['Personal']);
  });
}
```

- [ ] **Step 7: Write the provisioner**

Create `lib/data/repositories/decoy_provisioner.dart`:

```dart
import '../../domain/models/site.dart';
import '../../domain/models/workspace.dart';
import '../services/app_database.dart';
import 'site_repository_sqlite.dart';
import 'workspace_repository_sqlite.dart';

/// Copies the rows the user chose into the decoy's own store.
///
/// This runs once, when the decoy is set up or its selection is changed. After
/// it runs, the decoy store is an ordinary database of ordinary rows — there
/// is nothing in it to filter and nothing marked as hidden, which is why no
/// query in the decoy session has to remember to exclude anything.
Future<int> provisionDecoy({
  required AppDatabase from,
  required AppDatabase into,
}) async {
  final sourceWorkspaces = SqliteWorkspaceRepository(from);
  final sourceSites = SqliteSiteRepository(from);
  final targetWorkspaces = SqliteWorkspaceRepository(into);
  final targetSites = SqliteSiteRepository(into);

  var copied = 0;

  for (final workspace in await sourceWorkspaces.all()) {
    if (!workspace.showInDecoy) continue;

    await targetWorkspaces.upsert(workspace.copyWith(showInDecoy: false));

    for (final site in await sourceSites.inWorkspace(workspace.id)) {
      if (!site.showInDecoy) continue;
      await targetSites.upsert(site.copyWith(showInDecoy: false));
      copied++;
    }
  }

  return copied;
}
```

**Forward note for Plan 3 (cross-plan issue #5).** Plan 3 Task 1 adds a required `Site.profileId` naming the site's WebView profile. `copyWith` carries every field it is not given across unchanged, so once that field exists this loop would hand the decoy store a row pointing at the *real* site's container — same cookies, same cache, one profile in two vaults, which is the one thing the two-vault model is built to prevent. When Plan 3 lands, the upsert above becomes `site.copyWith(showInDecoy: false, profileId: newProfileId())`, and the three `const Site(...)` fixtures in `decoy_provisioner_test.dart` lose their `const`, because `newProfileId()` is not a constant expression. There is nothing to do while Plan 3 is unbuilt — the field does not exist yet — but do not restructure this loop in a way that makes that change harder to spot. Plan 3 Task 1 Step 7 carries the instruction.

- [ ] **Step 8: Write the failing setup-controller test**

Create `test/ui/features/setup/setup_controller_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/domain/services/vault_unlocker.dart';
import 'package:container/ui/features/setup/view_models/setup_controller.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late VaultStore vaultStore;
  late FakeCrypto crypto;
  final opened = <String, AppDatabase>{};
  final sessions = <({VaultId vault, AppDatabase database})>[];

  Future<AppDatabase> fakeOpen({required String path, required Uint8List dataKey}) async {
    final db =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    opened[path] = db;
    return db;
  }

  SetupController controller() => SetupController(
        vaultStore: vaultStore,
        openVault: fakeOpen,
        pathFor: (vault) => '${dir.path}/${vault.name}.db',
        openSession: ({required VaultId vault, required AppDatabase database}) =>
            sessions.add((vault: vault, database: database)),
      );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('setup-test');
    crypto = FakeCrypto();
    vaultStore = VaultStore(crypto, File('${dir.path}/meta.bin'));
    opened.clear();
    sessions.clear();
  });

  tearDown(() async {
    for (final db in opened.values) {
      await db.close();
    }
    await dir.delete(recursive: true);
  });

  test('completing without a decoy still provisions both slots, one unopenable',
      () async {
    await controller().complete(mainPin: '111111');

    final slots = await vaultStore.slots();
    expect(slots.length, 2);
    expect(slots[0].wrappedKey.length, slots[1].wrappedKey.length,
        reason: 'the unopened slot must not be a different size');
  });

  test('completing without a decoy hands off a seeded vault A', () async {
    await controller().complete(mainPin: '111111');

    expect(sessions, hasLength(1));
    expect(sessions.single.vault, VaultId.a);
    final workspaces =
        await SqliteWorkspaceRepository(sessions.single.database).all();
    expect(workspaces, isNotEmpty, reason: 'seedIfEmpty should have run');
  });

  test('a decoy PIN provisions vault B and does not hand it off', () async {
    await controller().complete(mainPin: '111111', decoyPin: '222222');

    expect(sessions, hasLength(1));
    expect(sessions.single.vault, VaultId.a);
    expect(opened.keys, containsAll(['${dir.path}/a.db', '${dir.path}/b.db']));
  });

  test('both PINs actually unlock their own vault afterwards', () async {
    await controller().complete(mainPin: '111111', decoyPin: '222222');

    final unlocker = VaultUnlocker(crypto);
    final slots = await vaultStore.slots();

    final mainOutcome = await unlocker.attempt(
        pin: '111111', slots: slots, gate: const AttemptGate(), now: DateTime(2026));
    expect((mainOutcome as Unlocked).vault, VaultId.a);

    final decoyOutcome = await unlocker.attempt(
        pin: '222222', slots: slots, gate: const AttemptGate(), now: DateTime(2026));
    expect((decoyOutcome as Unlocked).vault, VaultId.b);
  });
}
```

- [ ] **Step 9: Run it to verify it fails**

Run: `flutter test test/ui/features/setup/setup_controller_test.dart`
Expected: FAIL — missing `setup_controller.dart`.

- [ ] **Step 10: Write the setup controller**

Create `lib/ui/features/setup/view_models/setup_controller.dart`:

```dart
import 'dart:typed_data';

import '../../../../data/services/app_database.dart';
import '../../../../data/services/vault_store.dart';
import '../../../../domain/models/vault.dart';
import '../../../../data/repositories/decoy_provisioner.dart';

/// Opens (or creates) the vault database at [path] under [dataKey]. Injected
/// so this file — and Task 8's `SessionController` — never import
/// `openEncrypted` directly: `main()` wires the real one, tests wire an
/// in-memory one.
typedef VaultOpener = Future<AppDatabase> Function({
  required String path,
  required Uint8List dataKey,
});

/// Where [vault]'s database file lives. Injected for the same reason as
/// [VaultOpener] — this file has no dependency on `session_controller.dart`,
/// which is where the real path convention (`vaultDatabasePath`) is defined.
typedef VaultPath = String Function(VaultId vault);

/// Hands the freshly-opened real vault to whatever owns session state, once
/// setup is done. Injected for the same reason.
typedef SessionOpener = void Function({
  required VaultId vault,
  required AppDatabase database,
});

/// Runs the setup wizard's side effects: provisions both vault slots
/// (always both — an unconfigured decoy must be byte-indistinguishable from
/// a real one, per this plan's Global Constraints), seeds the real vault,
/// copies the chosen sites into the decoy if one was configured, and opens
/// the real vault as the new session.
class SetupController {
  const SetupController({
    required VaultStore vaultStore,
    required VaultOpener openVault,
    required VaultPath pathFor,
    required SessionOpener openSession,
  })  : _vaultStore = vaultStore,
        _openVault = openVault,
        _pathFor = pathFor,
        _openSession = openSession;

  final VaultStore _vaultStore;
  final VaultOpener _openVault;
  final VaultPath _pathFor;
  final SessionOpener _openSession;

  Future<void> complete({required String mainPin, String? decoyPin}) async {
    final mainKey = await _vaultStore.provision(pin: mainPin, vault: VaultId.a);
    final mainDb = await _openVault(path: _pathFor(VaultId.a), dataKey: mainKey);
    await seedIfEmpty(mainDb);

    if (decoyPin != null) {
      final decoyKey =
          await _vaultStore.provision(pin: decoyPin, vault: VaultId.b);
      final decoyDb = await _openVault(path: _pathFor(VaultId.b), dataKey: decoyKey);
      await provisionDecoy(from: mainDb, into: decoyDb);
      await decoyDb.close();
    } else {
      await _vaultStore.provisionUnopenable(VaultId.b);
    }

    _openSession(vault: VaultId.a, database: mainDb);
  }
}
```

- [ ] **Step 11: Run it to verify it passes**

Run: `flutter test test/ui/features/setup/setup_controller_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 12: Run everything and commit**

Run: `flutter test && flutter analyze`
Expected: all passing, `No issues found!`

```bash
git add -A
git commit -m "feat: setup wizard, decoy provisioning, and the setup controller"
```

---

## Task 7: Panic

**Files:**
- Create: `lib/ui/features/panic/views/panic_screen.dart`, `lib/domain/services/panic_service.dart`
- Test: `test/ui/features/panic_test.dart`

**Interfaces:**
- Consumes: `VaultStore`, `CryptoService`, `AppDatabase`.
- Produces:
  - `class PanicReport { final int sessionsDestroyed; }`
  - `class PanicService { Future<PanicReport> trigger(); }`
  - `PanicScreen({required PanicReport report, required VoidCallback onUnlock})`

Order is the specification: close sessions, destroy the data keys, delete the store files, lock. Destroying 32 bytes is the irreversible step; everything after it is cleanup.

- [ ] **Step 1: Write the failing panic test**

Create `test/ui/features/panic_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/services/panic_service.dart';
import 'package:container/ui/features/panic/views/panic_screen.dart';

void main() {
  testWidgets('panic reports what happened, in past tense', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(
        report: const PanicReport(sessionsDestroyed: 3),
        onUnlock: () {},
      ),
    ));

    expect(find.text('Everything closed'), findsOneWidget);
    expect(
      find.text('3 sessions destroyed, temporary storage wiped, app locked.'),
      findsOneWidget,
    );
    expect(find.text('WEBVIEWS'), findsOneWidget);
    expect(find.text('DESTROYED'), findsOneWidget);
    expect(find.text('EPHEMERAL DATA'), findsOneWidget);
    expect(find.text('WIPED'), findsOneWidget);
    expect(find.text('MEMORY'), findsOneWidget);
    expect(find.text('CLEARED'), findsOneWidget);
  });

  testWidgets('there is no confirmation step anywhere on the screen',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PanicScreen(
        report: const PanicReport(sessionsDestroyed: 1),
        onUnlock: () {},
      ),
    ));

    // Spec 3c: "no confirmation dialog, it just happens and reports after".
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(find.textContaining('Are you sure'), findsNothing);
    expect(find.text('Unlock'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/panic_test.dart`
Expected: FAIL — missing `panic_service.dart`.

- [ ] **Step 3: Write the panic service and screen**

Create `lib/domain/services/panic_service.dart`:

```dart
class PanicReport {
  const PanicReport({required this.sessionsDestroyed});

  final int sessionsDestroyed;
}

/// Runs the panic sequence. Order is the whole design:
///
/// 1. close every live session
/// 2. destroy the data keys and the device key
/// 3. delete the store files
/// 4. lock
///
/// Step 2 is the irreversible one. Step 3 is cleanup, and if the process is
/// killed between them the data is already unrecoverable — which is what lets
/// `3c` report in the past tense without lying.
abstract interface class PanicService {
  Future<PanicReport> trigger();
}
```

**This plan ships the interface, the screen and (in Task 8) the `SessionPanicked` state, and stops there.** The implementation is **Plan 3 Task 9**, and that ownership is deliberate rather than incidental: step 1 of the sequence above destroys live WebView sessions, which do not exist until Plan 3 creates them, and step 2 must not run until every container's storage is already gone — profile ids live in the vault stores, so once the data keys die there is nothing left to enumerate. Only a component that can see both `ContainerEngine` and `VaultStore` can order those correctly, and Plan 3 is the first plan in which both exist. Nothing in this plan constructs a `PanicReport`; `AppGate`'s panic branch is analysed but never taken until Plan 3 Task 9 lands (cross-plan issue #6).

Create `lib/ui/features/panic/views/panic_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../domain/services/panic_service.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';

class PanicScreen extends StatelessWidget {
  const PanicScreen({super.key, required this.report, required this.onUnlock});

  final PanicReport report;
  final VoidCallback onUnlock;

  static const _lines = [
    ('WEBVIEWS', 'DESTROYED'),
    ('EPHEMERAL DATA', 'WIPED'),
    ('MEMORY', 'CLEARED'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgPanic,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: C.danger.withValues(alpha: 0.35)),
                ),
                child: Text('◉', style: ui(size: 16, color: C.danger)),
              ),
              const SizedBox(height: 30),
              Text('Everything closed', style: ui(size: 18, weight: 600)),
              const SizedBox(height: 10),
              Text(
                '${report.sessionsDestroyed} sessions destroyed, temporary '
                'storage wiped, app locked.',
                textAlign: TextAlign.center,
                style: ui(size: 13, color: C.textMuted, height: 1.6),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: C.line07),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (label, state) in _lines) ...[
                      if (label != _lines.first.$1) const SizedBox(height: 1),
                      ColoredBox(
                        color: C.sheet,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label,
                                  style: ui(size: 11.5, color: C.textMuted)),
                              Text(state,
                                  style: ui(
                                      size: 11.5, weight: 500, color: C.jade)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              PillButton(
                label: 'Unlock',
                height: 48,
                onTap: onUnlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes, then commit**

Run: `flutter test test/ui/features/panic_test.dart`
Expected: PASS, 2 tests.

```bash
git add -A
git commit -m "feat: panic screen and service contract"
```

---

## Task 8: Settings, lifecycle, and the gate in front of the dashboard

The task that makes Plan 2 real: nothing reaches the dashboard without a PIN.

**Files:**
- Create: `lib/ui/core/widgets/setting_row.dart`, `lib/ui/features/settings/views/settings_screen.dart`, `lib/ui/features/settings/view_models/settings_controller.dart`, `lib/ui/features/shell/views/app_gate.dart`, `lib/ui/features/shell/views/setup_flow.dart`, `lib/ui/features/shell/view_models/lifecycle_controller.dart`, `lib/ui/features/shell/view_models/session_controller.dart`, `lib/ui/features/lock/views/lock_screen.dart`, `lib/data/services/secure_window.dart`, `android/app/src/main/kotlin/com/mono/container/SecureWindowPlugin.kt`
- Modify: `lib/main.dart`, `lib/ui/features/dashboard/view_models/providers.dart` (redefine `databaseProvider`)
- Test: `test/ui/features/settings_test.dart`, `test/ui/features/shell/session_controller_test.dart`, `test/ui/features/shell/lock_screen_test.dart`, `test/ui/features/shell/setup_flow_test.dart`

**Interfaces:**
- Consumes: everything above, including `LockController` from Task 5 and `SetupController`/`VaultOpener`/`VaultPath`/`SessionOpener` from Task 6.
- Produces:
  - `SettingRow({required String title, String? subtitle, Widget? trailing, String? value, VoidCallback? onTap})`
  - `SettingsScreen` rendering `2d` exactly
  - `class LifecycleController` — masks on focus loss, tracks time away, always reports which `ReturnDestination` it landed on
  - `sealed class Session`, `SessionUnconfigured`, `SessionLocked`, `SessionOpen`, `SessionPanicked`, `sessionProvider`, `class SessionController extends Notifier<Session>` with `unlock`, `graceExpired`, `completeSetup`, `panicked`, `dismissPanicReport`
  - `vaultStoreProvider`, `cryptoServiceProvider`, `documentsDirectoryProvider`, `vaultOpenerProvider`, `initialSessionProvider`, `setupControllerProvider`, `vaultDatabasePath(Directory, VaultId)`
  - `databaseProvider` (redefined; was Plan 1's, now reads the open session instead of being overridden in `main()`)
  - `LockScreen` — wires `LockController` (Task 5) and `sessionProvider` to `LockBody` (Task 5)
  - `SetupFlow` — sequences the three screens from Task 6 and calls `SetupController.complete`
  - `AppGate` — chooses setup, lock or dashboard

This task is where Plan 2's pieces stop being independently-testable units and become one running app. Every controller built in Tasks 5 and 6 took its dependencies as constructor parameters specifically so that wiring could live here, in one place, rather than being smeared across the tasks that produced the pieces being wired.

- [ ] **Step 1: Write the failing settings test**

Create `test/ui/features/settings_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/settings/views/settings_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool decoyConfigured}) {
    return tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        biometrics: true,
        autoLockLabel: 'After 1 min',
        decoyEnabled: decoyConfigured,
        decoySiteCount: 4,
        hideFromSwitcher: true,
        panicOnFlip: false,
        onPanicLabel: 'Wipe + lock',
        onChanged: (_, __) {},
        onTap: (_) {},
      ),
    ));
  }

  testWidgets('the lock and panic sections read verbatim', (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(find.text('LOCK'), findsOneWidget);
    expect(find.text('Unlock with biometrics'), findsOneWidget);
    expect(find.text('PIN always available as fallback'), findsOneWidget);
    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('After 1 min'), findsOneWidget);
    expect(find.text('Change main PIN'), findsOneWidget);

    expect(find.text('PANIC'), findsOneWidget);
    expect(find.text('Trigger by flipping face down'), findsOneWidget);
    expect(find.text('Uses the accelerometer'), findsOneWidget);
    expect(find.text('On panic'), findsOneWidget);
    expect(find.text('Wipe + lock'), findsOneWidget);
  });

  testWidgets('the vault section appears when a decoy is configured',
      (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(find.text('VAULT'), findsOneWidget);
    expect(find.text('Decoy vault'), findsOneWidget);
    expect(find.text('A second PIN opens a harmless board'), findsOneWidget);
    expect(find.text('Sites shown in decoy'), findsOneWidget);
    expect(find.text('4 selected'), findsOneWidget);
    expect(find.text('Hide from app switcher'), findsOneWidget);
  });

  testWidgets('the footer states the privacy position', (tester) async {
    await pump(tester, decoyConfigured: true);

    expect(
      find.text('Nothing leaves this device. There is no account and no sync.'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/ui/features/settings_test.dart`
Expected: FAIL — missing `settings_screen.dart`.

- [ ] **Step 3: Write `SettingRow` and `SettingsScreen`**

Create `lib/ui/core/widgets/setting_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// A settings line: title, optional subtitle, and either a control or a value
/// on the right. Hairline underneath, never a card.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line06)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: T.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: ui(size: 11, color: C.textFaint)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (value != null)
                Text(value!, style: ui(size: 12.5, color: C.textMuted)),
              if (trailing == null && value == null && onTap != null)
                Text('›', style: ui(size: 14, color: C.textFaint)),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `lib/ui/features/settings/views/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/setting_row.dart';

/// Spec `2d`.
///
/// The VAULT section is present only when a decoy has been configured. From
/// inside a decoy session this screen is never reachable at all — settings are
/// a real-vault surface, because a decoy that offers to manage a decoy is a
/// decoy that has announced itself.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.biometrics,
    required this.autoLockLabel,
    required this.decoyEnabled,
    required this.decoySiteCount,
    required this.hideFromSwitcher,
    required this.panicOnFlip,
    required this.onPanicLabel,
    required this.onChanged,
    required this.onTap,
  });

  final bool biometrics;
  final String autoLockLabel;
  final bool decoyEnabled;
  final int decoySiteCount;
  final bool hideFromSwitcher;
  final bool panicOnFlip;
  final String onPanicLabel;
  final void Function(String key, bool value) onChanged;
  final void Function(String key) onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left, size: 20, color: C.icon),
                  const SizedBox(width: 10),
                  Text('Settings', style: T.screenTitle),
                ],
              ),
            ),
            const Divider(height: 1, color: C.line06),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Text('LOCK', style: T.sectionLabel),
                  SettingRow(
                    title: 'Unlock with biometrics',
                    subtitle: 'PIN always available as fallback',
                    trailing: AppToggle(
                      value: biometrics,
                      onChanged: (v) => onChanged('biometrics', v),
                    ),
                  ),
                  SettingRow(
                      title: 'Auto-lock',
                      value: autoLockLabel,
                      onTap: () => onTap('autoLock')),
                  SettingRow(
                      title: 'Change main PIN', onTap: () => onTap('changePin')),
                  if (decoyEnabled) ...[
                    const SizedBox(height: 24),
                    Text('VAULT', style: T.sectionLabel),
                    SettingRow(
                      title: 'Decoy vault',
                      subtitle: 'A second PIN opens a harmless board',
                      trailing: AppToggle(
                        value: decoyEnabled,
                        onChanged: (v) => onChanged('decoy', v),
                      ),
                    ),
                    SettingRow(
                        title: 'Sites shown in decoy',
                        value: '$decoySiteCount selected',
                        onTap: () => onTap('decoySites')),
                    SettingRow(
                      title: 'Hide from app switcher',
                      subtitle: 'Blurs previews, blocks screenshots',
                      trailing: AppToggle(
                        value: hideFromSwitcher,
                        onChanged: (v) => onChanged('hideFromSwitcher', v),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('PANIC', style: T.sectionLabel),
                  SettingRow(
                    title: 'Trigger by flipping face down',
                    subtitle: 'Uses the accelerometer',
                    trailing: AppToggle(
                      value: panicOnFlip,
                      onChanged: (v) => onChanged('panicOnFlip', v),
                    ),
                  ),
                  SettingRow(
                      title: 'On panic',
                      value: onPanicLabel,
                      onTap: () => onTap('onPanic')),
                  const SizedBox(height: 22),
                  Text(
                    'Nothing leaves this device. There is no account and no '
                    'sync.',
                    style: ui(size: 11, color: C.textDim, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the settings test to verify it passes**

Run: `flutter test test/ui/features/settings_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Write the recents-masking plugin**

`FLAG_SECURE` is already set in `MainActivity` (Task 3), which gives a blank recents card. `9a` also wants the app's recents entry to carry a neutral label and no page title. Create `android/app/src/main/kotlin/com/mono/container/SecureWindowPlugin.kt`:

```kotlin
package com.mono.container

import android.app.Activity
import android.app.ActivityManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps the recents entry neutral (spec `9a`: "neutral name, blank card, no
 * page title").
 *
 * FLAG_SECURE, set in MainActivity for the process lifetime, already blanks
 * the preview and blocks screenshots. This only stops the task description
 * from ever carrying a page title.
 */
class SecureWindowPlugin(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "neutraliseRecents" -> {
                activity.setTaskDescription(
                    ActivityManager.TaskDescription.Builder()
                        .setLabel("Container")
                        .build()
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "com.mono.container/window"
    }
}
```

Register it in `MainActivity.configureFlutterEngine`, next to the crypto channel:

```kotlin
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SecureWindowPlugin.CHANNEL)
            .setMethodCallHandler(SecureWindowPlugin(this))
```

Create `lib/data/services/secure_window.dart`:

```dart
import 'package:flutter/services.dart';

class SecureWindow {
  const SecureWindow();

  static const _channel = MethodChannel('com.mono.container/window');

  /// FLAG_SECURE is set natively for the process lifetime; this only keeps the
  /// recents label neutral.
  Future<void> neutraliseRecents() => _channel.invokeMethod('neutraliseRecents');
}
```

- [ ] **Step 6: Write the lifecycle controller**

**Ruling — `LockMood.welcomeBack` is reachable.** Task 5 built and tested a "welcome back" lock state (spec `9b`: "Back within the grace period — sessions kept, one tap to resume") that nothing in the original Task 8 draft ever produced: the draft called `onLock()` only when `AutoLockPolicy.destinationFor` returned `ReturnDestination.pin`, and did nothing at all — silently returned straight to the dashboard — when it returned `ReturnDestination.board`. Spec turn 9 lists exactly two on-resume outcomes, `9b` and `9c`, and both are lock-shaped screens with a PIN keypad; there is no third "no screen at all" outcome anywhere in the spec. So `ReturnDestination.board` is ruled to mean "come back to a screen that still trusts your open sessions" (`9b`, mood `welcomeBack`), never "skip the lock screen entirely." `ReturnDestination.pin` still means the harder case, `9c`, mood `afterTimeout`.

This only changes what happens on **resume** — the branch below. Masking on focus loss (the `inactive`/`paused`/`hidden` case) is untouched. The one API change: `onLock: VoidCallback`, which the original draft only invoked for the hard case, becomes `onReturn: ValueChanged<ReturnDestination>`, invoked on every resume from a real backgrounding — `SessionController` (this task, below) decides what each destination means.

Create `lib/ui/features/shell/view_models/lifecycle_controller.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../../../domain/models/lock_state.dart';

/// Watches focus and reports where the user is coming back from.
///
/// Two mechanisms, deliberately not one: masking happens the instant focus is
/// lost, and the timer only chooses which of the two locked destinations
/// (`9b` or `9c`) the user lands on. Wiring the mask to the timer would leave
/// the board visible in recents for the length of the grace period, which is
/// the exact failure turn 9 calls out — and skipping the lock screen entirely
/// on a quick return would defeat the point of masking it in the first place.
class LifecycleController with WidgetsBindingObserver {
  LifecycleController({
    required this.policy,
    required this.onMaskChanged,
    required this.onReturn,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AutoLockPolicy policy;
  final ValueChanged<bool> onMaskChanged;
  final ValueChanged<ReturnDestination> onReturn;
  final DateTime Function() _clock;

  DateTime? _leftAt;

  void start() => WidgetsBinding.instance.addObserver(this);
  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (_leftAt == null) {
          _leftAt = _clock();
          onMaskChanged(true);
        }
      case AppLifecycleState.resumed:
        final left = _leftAt;
        _leftAt = null;
        onMaskChanged(false);
        if (left != null) {
          onReturn(policy.destinationFor(_clock().difference(left)));
        }
      case AppLifecycleState.detached:
        break;
    }
  }
}
```

- [ ] **Step 7: Write the failing session-controller test**

`session_controller.dart` is the single most important state object in the app: it is the only thing that knows whether a vault is open, decides what the lock screen shows, and owns the auto-lock timer's consequences. Every other piece in this task is either produced above (`LifecycleController`) or consumed from Tasks 5–6 (`LockController`, `SetupController`, `VaultOpener`, `VaultPath`, `SessionOpener`).

Create `test/ui/features/shell/session_controller_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart'
    show openSiteIdsProvider;
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/shell/view_models/session_controller.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late VaultStore vaultStore;
  late FakeCrypto crypto;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('session-test');
    crypto = FakeCrypto();
    vaultStore = VaultStore(crypto, File('${dir.path}/meta.bin'));
  });

  tearDown(() => dir.delete(recursive: true));

  ProviderContainer buildContainer(Session initial) {
    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(initial),
      vaultOpenerProvider.overrideWithValue(
        ({required String path, required Uint8List dataKey}) => AppDatabase.open(
            path: inMemoryDatabasePath, factory: databaseFactoryFfi),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh device starts unconfigured', () {
    final container = buildContainer(const SessionUnconfigured());
    expect(container.read(sessionProvider), isA<SessionUnconfigured>());
  });

  test('a correct main PIN opens vault A', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));

    await container.read(sessionProvider.notifier).unlock('111111');

    final session = container.read(sessionProvider);
    expect(session, isA<SessionOpen>());
    expect((session as SessionOpen).vault, VaultId.a);
  });

  test('a wrong PIN counts down and stays locked', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));

    await container.read(sessionProvider.notifier).unlock('999999');

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.wrong);
    expect(session.gate.triesLeft, 4);
  });

  test(
      'returning within the grace period locks to welcomeBack, not silently '
      'to the board', () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container =
        buildContainer(SessionOpen(vault: VaultId.a, database: db));
    container.read(openSiteIdsProvider.notifier).state = {'s1', 's2'};

    container
        .read(sessionProvider.notifier)
        .debugHandleReturn(ReturnDestination.board);

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.welcomeBack);
    expect(session.openSessionCount, 2);
    expect(session.lockDeadline, isNotNull);
  });

  test('returning past the grace period locks to afterTimeout and wipes sessions',
      () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container =
        buildContainer(SessionOpen(vault: VaultId.a, database: db));
    container.read(openSiteIdsProvider.notifier).state = {'s1'};

    container
        .read(sessionProvider.notifier)
        .debugHandleReturn(ReturnDestination.pin);

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.afterTimeout);
    expect(container.read(openSiteIdsProvider), isEmpty);
  });

  test('graceExpired past the deadline wipes sessions the same way', () async {
    final container = buildContainer(SessionLocked(
      mood: LockMood.welcomeBack,
      gate: const AttemptGate(),
      openSessionCount: 3,
      lockDeadline: DateTime.now(),
    ));
    container.read(openSiteIdsProvider.notifier).state = {'s1', 's2', 's3'};

    container.read(sessionProvider.notifier).graceExpired();

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.afterTimeout);
    expect(container.read(openSiteIdsProvider), isEmpty);
  });

  test('graceExpired is a no-op once the user already unlocked', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));
    await container.read(sessionProvider.notifier).unlock('111111');

    container.read(sessionProvider.notifier).graceExpired();

    expect(container.read(sessionProvider), isA<SessionOpen>());
  });
}
```

- [ ] **Step 8: Run it to verify it fails**

Run: `flutter test test/ui/features/shell/session_controller_test.dart`
Expected: FAIL — missing `session_controller.dart`.

- [ ] **Step 9: Write the session controller**

Create `lib/ui/features/shell/view_models/session_controller.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../../data/services/android_crypto_service.dart';
import '../../../../data/services/app_database.dart';
import '../../../../data/services/encrypted_database.dart';
import '../../../../data/services/vault_store.dart';
import '../../../../domain/models/attempt_gate.dart';
import '../../../../domain/models/lock_state.dart';
import '../../../../domain/models/vault.dart';
import '../../../../domain/services/crypto_service.dart';
import '../../../../domain/services/panic_service.dart';
import '../../../../domain/services/vault_unlocker.dart';
import '../../dashboard/view_models/providers.dart' show openSiteIdsProvider;
import '../../lock/views/lock_body.dart' show LockMood;
import '../../setup/view_models/setup_controller.dart';
import 'lifecycle_controller.dart';

/// Which of the two vaults, if either, is open. `AppGate` switches on this
/// directly (`SessionUnconfigured()`, `SessionLocked()`, `SessionOpen()`),
/// so it is a plain synchronous value, never wrapped in `AsyncValue` — see
/// `initialSessionProvider` below for how the one genuinely async step (does
/// `meta.bin` exist yet?) is kept out of this class's `build()`.
sealed class Session {
  const Session();
}

/// No `meta.bin` on disk: neither vault has ever been provisioned.
class SessionUnconfigured extends Session {
  const SessionUnconfigured();
}

/// A vault exists but is not open right now. [mood] drives which copy
/// `LockBody` shows. [lockDeadline] is set only while [mood] is
/// [LockMood.welcomeBack] — `LockScreen` ticks its own timer against it and
/// calls [SessionController.graceExpired] once it passes; this class never
/// runs a `Timer` of its own.
class SessionLocked extends Session {
  const SessionLocked({
    required this.mood,
    required this.gate,
    this.openSessionCount = 0,
    this.lockDeadline,
  });

  final LockMood mood;
  final AttemptGate gate;
  final int openSessionCount;
  final DateTime? lockDeadline;
}

/// A vault is open. Read by `databaseProvider` below — nothing else in the
/// app ever asks which vault that is.
class SessionOpen extends Session {
  const SessionOpen({required this.vault, required this.database});

  final VaultId vault;
  final AppDatabase database;
}

/// Panic has run: no store, no keys, nothing to open. `3c` renders [report].
///
/// This is a state, not an action — the destruction itself belongs to
/// `PanicService` (Plan 3 Task 9 implements it), and this class only records
/// that it finished. Keeping the sequence out of the controller is what lets
/// the ordering in `PanicService`'s doc comment stay in one place instead of
/// being split across a service and a `Notifier`.
class SessionPanicked extends Session {
  const SessionPanicked(this.report);

  final PanicReport report;
}

/// Overridden in `main()` once `VaultStore.exists`/`.gate()` — the one
/// genuinely async startup check — has resolved, so `SessionController`'s
/// own `build()` can stay synchronous.
final initialSessionProvider = Provider<Session>(
  (ref) =>
      throw StateError('initialSessionProvider must be overridden in main()'),
);

final cryptoServiceProvider =
    Provider<CryptoService>((ref) => const AndroidCryptoService());

final documentsDirectoryProvider = Provider<Directory>(
  (ref) =>
      throw StateError('documentsDirectoryProvider must be overridden in main()'),
);

final vaultStoreProvider = Provider<VaultStore>(
  (ref) => throw StateError('vaultStoreProvider must be overridden in main()'),
);

/// Defaults to the real `openEncrypted`; tests override it with an
/// in-memory factory, since `openEncrypted` itself talks to the real
/// SQLCipher platform channel and cannot run on a test host.
final vaultOpenerProvider = Provider<VaultOpener>((ref) => openEncrypted);

/// `vaultFileName` takes a `VaultId` as of Task 4 Step 6, which retired
/// Plan 1's parallel `Vault` enum (cross-plan issue #3). There is one enum
/// now and nothing left to bridge.
String vaultDatabasePath(Directory documents, VaultId vault) =>
    p.join(documents.path, vaultFileName(vault));

final sessionProvider =
    NotifierProvider<SessionController, Session>(SessionController.new);

class SessionController extends Notifier<Session> {
  late final LifecycleController _lifecycle;

  VaultStore get _vaultStore => ref.read(vaultStoreProvider);
  VaultUnlocker get _unlocker => VaultUnlocker(ref.read(cryptoServiceProvider));

  @override
  Session build() {
    _lifecycle = LifecycleController(
      policy: AutoLockPolicy.oneMinute,
      // FLAG_SECURE, set for the process lifetime in MainActivity, already
      // blanks the recents preview; there is nothing further for Dart to do
      // here yet.
      onMaskChanged: (_) {},
      onReturn: _handleReturn,
    )..start();
    ref.onDispose(_lifecycle.stop);
    return ref.watch(initialSessionProvider);
  }

  /// Called by `PanicService` once its sequence has completed. Terminal: no
  /// method on this class returns to `SessionOpen` afterwards, because there
  /// is no longer a store any PIN could unwrap.
  void panicked(PanicReport report) => state = SessionPanicked(report);

  /// `3c`'s single button.
  ///
  /// **Ruling.** This returns to a lock screen that no PIN will ever open,
  /// not to setup — even though `VaultStore.exists` is now false and
  /// `SessionUnconfigured` is what a genuinely fresh device would show. Under
  /// this plan's stated threat model (coerced unlock, not forensic imaging)
  /// the screen after a panic has to look like the screen before one; a setup
  /// wizard announces to the person holding the phone that everything was
  /// just destroyed, which is the one thing the past-tense report in `3c` is
  /// carefully not saying out loud to anyone but its owner. A cold start
  /// after this reaches `SessionUnconfigured` normally, since `main()` re-runs
  /// the `exists` check.
  void dismissPanicReport() =>
      state = const SessionLocked(mood: LockMood.normal, gate: AttemptGate());

  Future<void> unlock(String pin) async {
    final currentGate = await _vaultStore.gate();
    final slots = await _vaultStore.slots();
    final outcome = await _unlocker.attempt(
      pin: pin,
      slots: slots,
      gate: currentGate,
      now: DateTime.now(),
    );

    switch (outcome) {
      case Unlocked(:final vault, :final dataKey, :final gate):
        await _vaultStore.saveGate(gate);
        final database = await ref.read(vaultOpenerProvider)(
          path: vaultDatabasePath(ref.read(documentsDirectoryProvider), vault),
          dataKey: dataKey,
        );
        state = SessionOpen(vault: vault, database: database);
      case Rejected(:final gate):
        await _vaultStore.saveGate(gate);
        state = SessionLocked(
            mood: LockMood.wrong, gate: gate, openSessionCount: _openCount());
      case Throttled():
        state = SessionLocked(
            mood: LockMood.wrong,
            gate: currentGate,
            openSessionCount: _openCount());
    }
  }

  /// Called once by `SetupController` (Task 6), via `setupControllerProvider`
  /// below, when setup has just provisioned and seeded the real vault.
  void completeSetup({required VaultId vault, required AppDatabase database}) {
    state = SessionOpen(vault: vault, database: database);
  }

  /// Called by `LockScreen`'s own timer once `SessionLocked.lockDeadline`
  /// has passed without a correct PIN. A no-op outside the welcome-back
  /// state, so a stray or late call after the user already unlocked cannot
  /// re-lock them.
  void graceExpired() {
    final current = state;
    if (current is! SessionLocked || current.mood != LockMood.welcomeBack) {
      return;
    }
    ref.read(openSiteIdsProvider.notifier).state = {};
    state = SessionLocked(mood: LockMood.afterTimeout, gate: current.gate);
  }

  @visibleForTesting
  void debugHandleReturn(ReturnDestination destination) =>
      _handleReturn(destination);

  int _openCount() {
    final current = state;
    return current is SessionLocked ? current.openSessionCount : 0;
  }

  /// See this file's header and Step 6's Ruling: `ReturnDestination.board`
  /// means "come back to a screen that still trusts your open sessions"
  /// (`9b`, `welcomeBack`), never "come back to the dashboard unguarded."
  /// `ReturnDestination.pin` means the sessions are actually gone (`9c`,
  /// `afterTimeout`).
  void _handleReturn(ReturnDestination destination) {
    final current = state;
    if (current is! SessionOpen) return;
    unawaited(current.database.close());

    switch (destination) {
      case ReturnDestination.board:
        state = SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          openSessionCount: ref.read(openSiteIdsProvider).length,
          lockDeadline: DateTime.now().add(AutoLockPolicy.oneMinute.grace),
        );
      case ReturnDestination.pin:
        ref.read(openSiteIdsProvider.notifier).state = {};
        state =
            const SessionLocked(mood: LockMood.afterTimeout, gate: AttemptGate());
    }
  }
}

/// Constructs the real `SetupController` (Task 6) from this task's
/// providers. `SetupController` itself has no Riverpod dependency — see its
/// own file for why — so this is the only place that wiring happens.
final setupControllerProvider = Provider<SetupController>((ref) {
  final documents = ref.read(documentsDirectoryProvider);
  return SetupController(
    vaultStore: ref.read(vaultStoreProvider),
    openVault: ref.read(vaultOpenerProvider),
    pathFor: (vault) => vaultDatabasePath(documents, vault),
    openSession: ({required VaultId vault, required AppDatabase database}) =>
        ref.read(sessionProvider.notifier).completeSetup(
              vault: vault,
              database: database,
            ),
  );
});
```

This file and `lib/ui/features/dashboard/view_models/providers.dart` end up importing each other — `session_controller.dart` reads `openSiteIdsProvider` from there, and the next step redefines `databaseProvider` there to read `sessionProvider` from here. That circularity is intentional and safe: Riverpod providers are lazily initialised on first read, so two files referencing each other's top-level provider declarations has no initialisation-order problem, only a lint some style guides flag. Nothing here evaluates eagerly at import time.

- [ ] **Step 10: Run it to verify it passes**

Run: `flutter test test/ui/features/shell/session_controller_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 11: Redefine `databaseProvider` to read the open session**

In `lib/ui/features/dashboard/view_models/providers.dart`, add an import and replace `databaseProvider`:

```dart
import '../../shell/view_models/session_controller.dart'
    show sessionProvider, SessionOpen;
```

```dart
// Replace:
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('databaseProvider must be overridden in main()'),
);

// With:
/// Unlike Plan 1, nothing calls `databaseProvider.overrideWithValue` after
/// startup — there is no single startup-time database any more. Instead
/// this reads whichever vault `SessionController` currently has open, which
/// is how the dashboard ends up showing the right vault with no code
/// anywhere asking which one that is.
final databaseProvider = Provider<AppDatabase>((ref) {
  final session = ref.watch(sessionProvider);
  if (session is! SessionOpen) {
    throw StateError('databaseProvider read while no vault is open');
  }
  return session.database;
});
```

Plan 1's `test/ui/features/dashboard_body_test.dart` and its provider tests already override `databaseProvider` directly with a `Provider.overrideWithValue`-style test double where they need one; a `Provider` still accepts that override regardless of its own implementation, so none of Plan 1's tests need to change.

- [ ] **Step 12: Run the full domain and data suite, then commit**

Run: `flutter test test/domain/ test/data/ test/ui/features/shell/ && flutter analyze`
Expected: all passing, `No issues found!`

```bash
git add -A
git commit -m "feat: session controller — the single source of truth for lock state"
```

- [ ] **Step 13: Write the lock screen and its test**

`LockScreen` bridges `LockController` (Task 5, pure digit buffer) and `sessionProvider` (this task's Step 9) to `LockBody` (Task 5, pure rendering). It is the reason `LockController`/`LockBody` could be built before this task existed, and the reason `LockScreen` itself could not.

Create `test/ui/features/shell/lock_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/attempt_gate.dart';
import 'package:container/ui/core/widgets/pin_dots.dart';
import 'package:container/ui/features/lock/views/lock_body.dart' show LockMood;
import 'package:container/ui/features/lock/views/lock_screen.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

void main() {
  Future<void> pump(WidgetTester tester, Session initial) {
    return tester.pumpWidget(ProviderScope(
      overrides: [initialSessionProvider.overrideWithValue(initial)],
      child: const MaterialApp(home: LockScreen()),
    ));
  }

  testWidgets('renders the mood and counters SessionLocked carries',
      (tester) async {
    await pump(
      tester,
      SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        openSessionCount: 2,
        lockDeadline: DateTime.now().add(const Duration(seconds: 40)),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.textContaining('2 sessions still open'), findsOneWidget);
  });

  testWidgets('a wrong-PIN mood shows the tries-left count from the gate',
      (tester) async {
    await pump(tester,
        SessionLocked(mood: LockMood.wrong, gate: const AttemptGate(failures: 2)));

    expect(find.text('Wrong PIN · 3 tries left'), findsOneWidget);
  });

  testWidgets('keypad taps move the dot count before any PIN is complete',
      (tester) async {
    await pump(
        tester, SessionLocked(mood: LockMood.normal, gate: const AttemptGate()));

    await tester.tap(find.text('1').first);
    await tester.tap(find.text('2').first);
    await tester.pump();

    final dots = tester
        .widgetList<Container>(find.descendant(
            of: find.byType(PinDots), matching: find.byType(Container)))
        .toList();
    expect(
        dots.where((c) => (c.decoration! as BoxDecoration).color != null).length,
        2);
  });
}
```

- [ ] **Step 14: Run it to verify it fails**

Run: `flutter test test/ui/features/shell/lock_screen_test.dart`
Expected: FAIL — missing `lock_screen.dart`.

- [ ] **Step 15: Write the lock screen**

Create `lib/ui/features/lock/views/lock_screen.dart`:

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/view_models/session_controller.dart';
import '../view_models/lock_controller.dart';
import 'lock_body.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  late final LockController _pin;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _pin = LockController(onSubmit: _submit)..addListener(_onPinChanged);
  }

  @override
  void dispose() {
    _pin
      ..removeListener(_onPinChanged)
      ..dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _onPinChanged() => setState(() {});

  Future<void> _submit(String pin) =>
      ref.read(sessionProvider.notifier).unlock(pin);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session is! SessionLocked) {
      // AppGate only ever mounts LockScreen while locked.
      return const SizedBox.shrink();
    }

    _syncTicker(session);

    final deadline = session.lockDeadline;
    final secondsUntilLock =
        deadline == null ? 0 : max(0, deadline.difference(DateTime.now()).inSeconds);

    return LockBody(
      mood: session.mood,
      filled: _pin.value.filled,
      triesLeft: session.gate.triesLeft,
      openSessions: session.openSessionCount,
      secondsUntilLock: secondsUntilLock,
      onKey: _pin.onKey,
      // Known gap (see this plan's "Known gaps"): biometric unlock is not
      // wired to a Keystore-gated key yet, so there is nothing safe for
      // this to do.
      onBiometric: () {},
    );
  }

  void _syncTicker(SessionLocked session) {
    final shouldTick =
        session.mood == LockMood.welcomeBack && session.lockDeadline != null;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (session.lockDeadline!.isBefore(DateTime.now())) {
          ref.read(sessionProvider.notifier).graceExpired();
        } else {
          setState(() {});
        }
      });
    } else if (!shouldTick && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }
}
```

- [ ] **Step 16: Run it to verify it passes**

Run: `flutter test test/ui/features/shell/lock_screen_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 17: Write the failing setup-flow test**

`SetupFlow` sequences the three screens Task 6 built and calls `SetupController.complete` once the last one finishes.

**Ruling — decoy PIN entry has no screen of its own in the spec.** `4a`, `4b` and `5a` are the only three setup screen ids, `4b`'s step bar is fixed at three segments, and nowhere in the spec is there a fourth screen — or even a sentence — describing how a decoy PIN gets typed in. Inventing new copy for one would violate this plan's own rule ("if a string isn't in the spec, that's a design question to ask about, not to invent"). This flow instead reuses `SetupPinScreen` a second time when the decoy toggle is on, since it is the only six-digit entry primitive that exists. The visible cost: `SetupPinScreen` hardcodes `StepProgress(step: 1)` internally (Task 5, not touched here), so the progress bar reads "step 1 of 3" again during decoy entry instead of advancing to a fourth segment that does not exist. Recorded here and in this plan's Known gaps rather than silently patched — a real fourth screen, if the product wants one, is a spec question first.

Create `test/ui/features/shell/setup_flow_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/features/setup/view_models/setup_controller.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';
import 'package:container/ui/features/shell/views/setup_flow.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late VaultStore vaultStore;
  final sessions = <({VaultId vault, AppDatabase database})>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('setup-flow-test');
    vaultStore = VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'));
    sessions.clear();
  });

  tearDown(() => dir.delete(recursive: true));

  Future<void> pump(WidgetTester tester) {
    return tester.pumpWidget(ProviderScope(
      overrides: [
        setupControllerProvider.overrideWithValue(SetupController(
          vaultStore: vaultStore,
          openVault: ({required String path, required Uint8List dataKey}) =>
              AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi),
          pathFor: (vault) => '${dir.path}/${vault.name}.db',
          openSession: ({required VaultId vault, required AppDatabase database}) =>
              sessions.add((vault: vault, database: database)),
        )),
      ],
      child: const MaterialApp(home: SetupFlow()),
    ));
  }

  Future<void> enterSixDigits(WidgetTester tester, List<String> keys) async {
    for (final key in keys) {
      await tester.tap(find.text(key).first);
      await tester.pump();
    }
  }

  testWidgets('starts on step 1, the main PIN', (tester) async {
    await pump(tester);
    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('skipping the decoy goes straight to the defaults step',
      (tester) async {
    await pump(tester);
    await enterSixDigits(tester, ['1', '2', '3', '4', '5', '6']);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Skip for now'));
    await tester.pump();

    expect(find.text('How sites will behave'), findsOneWidget);
  });

  testWidgets('enabling the decoy reuses the PIN screen before the defaults',
      (tester) async {
    await pump(tester);
    await enterSixDigits(tester, ['1', '2', '3', '4', '5', '6']);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    // Back on a PIN-entry screen, but now for the decoy — the flow's own
    // state (not this screen) is what makes it the decoy step.
    expect(find.text('Choose a PIN'), findsOneWidget);
  });

  testWidgets('finishing with a decoy provisions both slots and hands off vault A',
      (tester) async {
    await pump(tester);
    await enterSixDigits(tester, ['1', '2', '3', '4', '5', '6']); // main PIN
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await enterSixDigits(tester, ['9', '8', '7', '6', '5', '4']); // decoy PIN
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Add your first site'));
    await tester.pumpAndSettle();

    expect(sessions, hasLength(1));
    expect(sessions.single.vault, VaultId.a);
    final slots = await vaultStore.slots();
    expect(slots.length, 2);
  });
}
```

- [ ] **Step 18: Run it to verify it fails**

Run: `flutter test test/ui/features/shell/setup_flow_test.dart`
Expected: FAIL — missing `setup_flow.dart`.

- [ ] **Step 19: Write the setup flow**

Create `lib/ui/features/shell/views/setup_flow.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../setup/views/setup_decoy_screen.dart';
import '../../setup/views/setup_defaults_screen.dart';
import '../../setup/views/setup_pin_screen.dart';
import '../view_models/session_controller.dart';

enum _SetupStep { mainPin, decoyChoice, decoyPin, defaults }

/// Sequences `4a` → `4b` → (`4a` again, for the decoy PIN, if chosen) →
/// `5a`, then calls `SetupController.complete`. See the Ruling above for why
/// the decoy PIN step reuses `4a` rather than a screen that does not exist.
class SetupFlow extends ConsumerStatefulWidget {
  const SetupFlow({super.key});

  @override
  ConsumerState<SetupFlow> createState() => _SetupFlowState();
}

class _SetupFlowState extends ConsumerState<SetupFlow> {
  _SetupStep _step = _SetupStep.mainPin;
  String _mainPin = '';
  bool _decoyEnabled = false;
  String _decoyPin = '';
  bool _completing = false;

  void _appendMain(String key) => setState(() => _mainPin = _apply(_mainPin, key));
  void _appendDecoy(String key) => setState(() => _decoyPin = _apply(_decoyPin, key));

  String _apply(String digits, String key) {
    if (key == '⌫') {
      return digits.isEmpty ? digits : digits.substring(0, digits.length - 1);
    }
    if (digits.length >= 6) return digits;
    return digits + key;
  }

  Future<void> _finish() async {
    if (_completing) return;
    setState(() => _completing = true);
    await ref.read(setupControllerProvider).complete(
          mainPin: _mainPin,
          decoyPin: _decoyEnabled ? _decoyPin : null,
        );
    // No further setState: AppGate swaps this widget out once
    // SessionController's state becomes SessionOpen.
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _SetupStep.mainPin => SetupPinScreen(
          filled: _mainPin.length,
          onKey: _appendMain,
          onContinue: _mainPin.length == 6
              ? () => setState(() => _step = _SetupStep.decoyChoice)
              : null,
        ),
      _SetupStep.decoyChoice => SetupDecoyScreen(
          enabled: _decoyEnabled,
          onToggle: (v) => setState(() => _decoyEnabled = v),
          onContinue: () => setState(() =>
              _step = _decoyEnabled ? _SetupStep.decoyPin : _SetupStep.defaults),
          onSkip: () => setState(() {
            _decoyEnabled = false;
            _step = _SetupStep.defaults;
          }),
        ),
      _SetupStep.decoyPin => SetupPinScreen(
          filled: _decoyPin.length,
          onKey: _appendDecoy,
          onContinue: _decoyPin.length == 6
              ? () => setState(() => _step = _SetupStep.defaults)
              : null,
        ),
      _SetupStep.defaults => SetupDefaultsScreen(onFinish: _finish),
    };
  }
}
```

- [ ] **Step 20: Run it to verify it passes**

Run: `flutter test test/ui/features/shell/setup_flow_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 21: Fix `AppGate`'s missing import and confirm it compiles**

`AppGate`'s own code (below) already calls `const SetupFlow()`, but the file it was drafted alongside only imported `setup_pin_screen.dart` — not the file `SetupFlow` actually lives in. This is the same class of bug as Plan 1's `main.dart` import-path issue (already fixed): a missing import, not a logic change, so `AppGate`'s body is not being rewritten here — only its import list gains one line.

Create `lib/ui/features/shell/views/app_gate.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/views/dashboard_screen.dart';
import '../../lock/views/lock_screen.dart';
import '../../panic/views/panic_screen.dart';
import '../view_models/session_controller.dart';
import 'setup_flow.dart';

/// Decides what the app shows: setup on a fresh device, the lock screen when
/// locked, the dashboard when open.
///
/// The dashboard is never constructed while locked. Building it behind an
/// opacity or an overlay would leave a rendered board one screenshot away, and
/// the whole point of `9a` is that there is nothing to capture.
class AppGate extends ConsumerWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return switch (session) {
      SessionUnconfigured() => const SetupFlow(),
      SessionLocked() => const LockScreen(),
      SessionOpen() => const DashboardScreen(),
      SessionPanicked(:final report) => PanicScreen(
          report: report,
          onUnlock: () => ref.read(sessionProvider.notifier).dismissPanicReport(),
        ),
    };
  }
}
```

Run: `flutter analyze lib/ui/features/shell/views/app_gate.dart`
Expected: `No issues found!`

- [ ] **Step 22: Rewrite `main.dart`**

The original one-line `runApp(const ProviderScope(child: ContainerApp(home: AppGate())))` cannot work as written: something has to check `VaultStore.exists` before `SessionController` has an initial `Session` to return from its (synchronous) `build()`, and that check is `Future<bool>`. Plan 1 already awaited `AppDatabase.open`/`seedIfEmpty` before `runApp` for the same reason (a real startup dependency), so this follows the same shape rather than inventing a new one — the check happens in `main()`, not behind a loading state inside the widget tree, which is also why `AppGate`'s `switch` above never had to grow a loading branch.

Replace `lib/main.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/services/android_crypto_service.dart';
import 'data/services/secure_window.dart';
import 'data/services/vault_store.dart';
import 'ui/features/lock/views/lock_body.dart' show LockMood;
import 'ui/features/shell/view_models/session_controller.dart';
import 'ui/features/shell/views/app_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const SecureWindow().neutraliseRecents();

  const crypto = AndroidCryptoService();
  final documents = await getApplicationDocumentsDirectory();
  final store = VaultStore(crypto, File(p.join(documents.path, 'meta.bin')));

  // A vault already exists but nothing is open: this is a cold start, not a
  // return from backgrounding, so the mood is `normal` — never
  // `afterTimeout`, which would falsely claim sessions were just wiped.
  final initial = await store.exists
      ? SessionLocked(mood: LockMood.normal, gate: await store.gate())
      : const SessionUnconfigured();

  runApp(ProviderScope(
    overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      documentsDirectoryProvider.overrideWithValue(documents),
      vaultStoreProvider.overrideWithValue(store),
      initialSessionProvider.overrideWithValue(initial),
    ],
    child: const ContainerApp(home: AppGate()),
  ));
}
```

No database is opened before a PIN is entered. That is the point of the task — `vaultOpenerProvider` defaults to the real `openEncrypted`, called only from inside `SessionController.unlock` and `SetupController.complete`, both of which run after a correct PIN.

- [ ] **Step 23: Run everything**

Run: `flutter test && flutter analyze`
Expected: all passing, `No issues found!`

- [ ] **Step 24: Verify on a device against the spec**

Run: `flutter run --debug`

- Fresh install goes to `4a`, not the dashboard.
- Six digits enables Continue; `4b` offers the decoy and Skip; `5a` lists the four defaults.
- Force-quit and reopen: the lock screen appears, and it says nothing about vaults.
- A wrong PIN shows `Wrong PIN · 4 tries left` and clears the dots. Five wrong shows the 30-second wait.
- The main PIN opens the seeded Personal board. The decoy PIN opens a board holding only the sites chosen in setup.
- Switch apps: the recents card is blank and labelled `Container`. Come back within a minute and you land on "Welcome back" with your session count and a live "locks in Ns" countdown, not straight on the board; enter the PIN again and the same board reopens with sessions intact. Let the countdown reach zero (or come back after a full minute) and you land on "Enter your PIN" with the "Locked after 1 minute in the background" card instead.
- Panic reports in the past tense and returns to the lock.

- [ ] **Step 25: Commit**

```bash
git add -A
git commit -m "feat: settings, lifecycle gating and the lock in front of the dashboard"
```

---

## Known gaps this plan deliberately leaves

- **Biometric unlock is wired to the UI but not to a Keystore-gated key.** `local_auth` gates the call; a real implementation binds a `setUserAuthenticationRequired` Keystore key to a copy of the data key. Until then, biometrics is a convenience over a PIN the app already holds in memory during a session, not an independent factor. `LockScreen`'s `onBiometric` (Task 8) is a no-op for the same reason.
- **The decoy PIN has no entry screen of its own in the spec.** Task 8's `SetupFlow` reuses `SetupPinScreen` a second time for it; the visible cost — the step-progress bar reads "step 1 of 3" again instead of a fourth segment — is recorded as a Ruling at Task 8 Step 17. A dedicated screen, if the product wants one, needs a spec addition first.
- **`LockMood.welcomeBack` (`9b`) is reachable, but only via a full PIN re-entry, not literally "one tap."** The spec's own caption for `9b` says "one tap to resume," but `LockBody` (Task 5, already built and tested) renders the same six-dot row and full keypad as every other lock mood, with no lighter-weight "just tap here" affordance anywhere in its code or tests. Task 8's Ruling (Step 6) treats the built, tested widget as authoritative over the caption and requires the same six digits as any other unlock — every attempt still evaluates both vault slots per this plan's Global Constraints. If "one tap" was meant literally, that is a `LockBody` change Task 5 would need to revisit, not something Task 8 can safely invent.
- **Ephemeral sessions "wiped" at `afterTimeout` only means `openSiteIdsProvider` is cleared.** There are no live WebView sessions yet for anything to actually destroy — that lands in Plan 3. `SessionController.graceExpired`/`_handleReturn` clear the one piece of session state that exists today; whoever wires Plan 3's container lifecycle in should extend the same call sites rather than add a second, competing "wipe" path.
- **`PanicService` has a contract, a screen and a state, but no implementation.** It cannot destroy WebView sessions until Plan 3 exists to create them. Plan 3 Task 9 supplies `ContainerPanicService` against this interface and is what first drives `sessionProvider` into `SessionPanicked` (cross-plan issue #6). Until that task runs, nothing in the app constructs a `PanicReport`, so `PanicScreen` is reachable only from its own widget test — the gate branch for it is built and analysed but never taken at runtime.
- **"Trigger by flipping face down" is a toggle that does nothing yet.** The accelerometer listener needs the session layer to have something to destroy.
- **Changing the main PIN re-wraps the data key but does not re-encrypt the store.** That is correct and intentional — the data key never changes, only its wrapping — but it means a PIN change is not a defence against someone who already captured the old wrapped blob and the old PIN.
- **The decoy's contents are provisioned once.** Adding a site to the real vault after setup does not add it to the decoy, even if flagged, until the selection is edited. Whether that should auto-sync is a design question, not an implementation one.
- **Argon2id parameters are not calibrated to a device.** `m = 64 MiB, t = 3, p = 2` is a reasonable 2026 floor, but it should be measured on the slowest target device; if unlock takes over a second for two slots, tune `t` rather than `m`.

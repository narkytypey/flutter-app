# Biometric Unlock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire Plan 2's dead "Unlock with biometrics" toggle and "Use fingerprint" affordance to a real, resume-only biometric mechanism, and give `SettingsScreen` its first real navigation entry point.

**Architecture:** An `AndroidKeyStore` RSA keypair (Kotlin `BiometricPlugin`) whose private key is gated by `BiometricPrompt`; the vault's data key is wrapped with the public key the instant a session backgrounds into the `welcomeBack` grace window, and only that ciphertext — never the raw key — crosses into `SessionLocked`. A successful fingerprint unwraps it and reopens the vault exactly like a correct PIN would. Settings gains a real controller for the biometrics row only; a new `⋯` icon on `WorkspaceBar` is the first way to reach `SettingsScreen` at all.

**Tech Stack:** Flutter/Dart 3, `flutter_riverpod`, `sqflite_sqlcipher` (+ `sqflite_common_ffi` for host tests), Kotlin, `androidx.biometric`, Android Keystore (`AndroidKeyStore` provider, RSA/OAEP).

**Spec:** `docs/superpowers/specs/2026-09-08-biometric-unlock-design.md`

## Global Constraints

- **Android only, dark theme only.** No light theme, no toggle.
- **No network requests of the app's own.** No account, sync, analytics, or telemetry, ever.
- **Jade `#7FC8A9`** means live state or the single affirmative action on a screen — never decorative, never more than one per screen. (Not introduced by this plan — no new jade usage beyond the existing `_biometric()` mark.)
- **IBM Plex Mono for anything technical**, Figtree for everything else. (Not touched by this plan — no new text styles introduced.)
- **Two-vault decoy model, not a filter.** No query anywhere filters rows for privacy, and no aggregate ever counts across both vaults. The new `app_settings` table lives inside each vault's own encrypted database and is never compared across vaults.
- **The interceptor never falls back to direct.** (Not touched by this plan.)
- **Threat model is coerced unlock**, not forensic imaging. Biometric unlock is resume-only for exactly this reason — see the spec's "Decision" section.
- **Biometric unlock never cold-opens a vault.** It only re-confirms identity for a vault already open in this session, during the `welcomeBack` grace window. A cold app start or a lock past the grace deadline always requires the full PIN.

---

## Task 1: `app_settings` table and `SettingsRepository`

**Files:**
- Modify: `lib/data/services/app_database.dart`
- Modify: `lib/domain/repositories/repositories.dart`
- Create: `lib/data/repositories/settings_repository_sqlite.dart`
- Test: `test/data/app_settings_migration_test.dart`

**Interfaces:**
- Consumes: `AppDatabase.open(...)` (existing), `AppDatabase.db` (existing `Database`).
- Produces: `abstract interface class SettingsRepository { Future<bool> getBool(String key, {bool fallback = false}); Future<void> setBool(String key, bool value); }`, `class SqliteSettingsRepository implements SettingsRepository`. Later tasks read/write the `'biometrics_enabled'` key through this.

- [ ] **Step 1: Write the failing migration test**

Create `test/data/app_settings_migration_test.dart`:

```dart
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('a fresh database has the app_settings table, defaulting to false',
      () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final repository = SqliteSettingsRepository(database);

    expect(await repository.getBool('biometrics_enabled'), isFalse);
  });

  test('setBool persists, and existing tables are unaffected', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final repository = SqliteSettingsRepository(database);

    await repository.setBool('biometrics_enabled', true);

    expect(await repository.getBool('biometrics_enabled'), isTrue);
    await seedIfEmpty(database);
    final workspaces = await database.db.query('workspaces');
    expect(workspaces, isNotEmpty, reason: 'seeding must still work post-migration');
  });

  test('setBool can flip a key back to false', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final repository = SqliteSettingsRepository(database);

    await repository.setBool('biometrics_enabled', true);
    await repository.setBool('biometrics_enabled', false);

    expect(await repository.getBool('biometrics_enabled'), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/app_settings_migration_test.dart`
Expected: FAIL — `settings_repository_sqlite.dart` does not exist yet, and `app_settings` is not a table.

- [ ] **Step 3: Add the `app_settings` table (schema v5 → v6)**

In `lib/data/services/app_database.dart`, bump the version and add the table to both `onCreate` and `onUpgrade`:

```dart
  static const schemaVersion = 6;
```

Inside `onCreate`, after the existing `await db.execute(_createScriptSites);` line, add:

```dart
          await db.execute(_createAppSettings);
```

Inside `onUpgrade`, after the existing `if (from < 5) { ... }` block, add:

```dart
          if (from < 6) {
            await db.execute(_createAppSettings);
          }
```

Add the new table constant near the other `_create*` constants (after `_createScriptSites`):

```dart
/// One row per key. Lives inside each vault's own encrypted database, never
/// in the plaintext-visible `vault_store.json` — see the biometric-unlock
/// design spec's "New pieces" section for why that boundary matters.
const _createAppSettings = '''
  CREATE TABLE app_settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
''';
```

- [ ] **Step 4: Add the `SettingsRepository` interface**

In `lib/domain/repositories/repositories.dart`, append:

```dart
abstract interface class SettingsRepository {
  Future<bool> getBool(String key, {bool fallback = false});
  Future<void> setBool(String key, bool value);
}
```

- [ ] **Step 5: Implement `SqliteSettingsRepository`**

Create `lib/data/repositories/settings_repository_sqlite.dart`:

```dart
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../../domain/repositories/repositories.dart';
import '../services/app_database.dart';

class SqliteSettingsRepository implements SettingsRepository {
  const SqliteSettingsRepository(this._database);

  final AppDatabase _database;

  @override
  Future<bool> getBool(String key, {bool fallback = false}) async {
    final rows = await _database.db
        .query('app_settings', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return fallback;
    return rows.first['value'] == '1';
  }

  @override
  Future<void> setBool(String key, bool value) async {
    await _database.db.insert(
      'app_settings',
      {'key': key, 'value': value ? '1' : '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/data/app_settings_migration_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Run the full existing schema/repository suite to check for fallout**

Run: `flutter test test/data/`
Expected: PASS — the version bump to 6 must not break `filter_list_category_migration_test.dart`, `site_migration_test.dart`, or any other existing schema test.

- [ ] **Step 8: Commit**

```bash
git add lib/data/services/app_database.dart lib/domain/repositories/repositories.dart lib/data/repositories/settings_repository_sqlite.dart test/data/app_settings_migration_test.dart
git commit -m "feat: add the app_settings table and SettingsRepository"
```

---

## Task 2: `BiometricService` — Kotlin plugin and Dart bridge

**Files:**
- Create: `lib/domain/services/biometric_service.dart`
- Create: `lib/data/services/android_biometric_service.dart`
- Create: `android/app/src/main/kotlin/com/mono/container/BiometricPlugin.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/MainActivity.kt`
- Modify: `android/app/build.gradle.kts`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `abstract interface class BiometricService { Future<bool> isAvailable(); Future<void> generateKeyPair(); Future<Uint8List> wrap(Uint8List dataKey); Future<Uint8List?> unwrap(Uint8List wrapped); Future<void> destroyKeyPair(); }`, `class AndroidBiometricService implements BiometricService`. Task 3 wires this behind a `biometricServiceProvider`.

There is no JVM-runnable unit test for `BiometricPlugin` — `BiometricPrompt` needs a real or emulated device with an enrolled biometric to drive, which is outside this repo's current test setup (the same reason `CryptoPlugin`/`SecureWindowPlugin` have none). This task's verification is `flutter analyze` plus the Dart-side contract, exercised for real starting in Task 3's tests via a fake.

- [ ] **Step 1: Add the `BiometricService` interface**

Create `lib/domain/services/biometric_service.dart`:

```dart
import 'dart:typed_data';

/// Every biometric-gated key operation. Kotlin owns the actual Keystore
/// keypair and the `BiometricPrompt` UI, mirroring `CryptoService`'s split
/// between Dart contract and platform implementation.
abstract interface class BiometricService {
  /// Hardware present and at least one biometric enrolled.
  Future<bool> isAvailable();

  /// (Re)creates the device's Keystore keypair, discarding any previous one
  /// — any ciphertext wrapped under the old keypair becomes unusable.
  Future<void> generateKeyPair();

  /// Public-key encrypt. Never shows a prompt.
  Future<Uint8List> wrap(Uint8List dataKey);

  /// Shows the system biometric prompt. Null on cancel, failed match, or an
  /// invalidated key — never throws for any of those, the same convention
  /// `CryptoService.unwrap` uses for a wrong PIN.
  Future<Uint8List?> unwrap(Uint8List wrapped);

  Future<void> destroyKeyPair();
}
```

- [ ] **Step 2: Add the Dart `MethodChannel` bridge**

Create `lib/data/services/android_biometric_service.dart`:

```dart
import 'package:flutter/services.dart';

import '../../domain/services/biometric_service.dart';

class AndroidBiometricService implements BiometricService {
  const AndroidBiometricService();

  static const _channel = MethodChannel('com.mono.container/biometric');

  @override
  Future<bool> isAvailable() async =>
      (await _channel.invokeMethod<bool>('isAvailable')) ?? false;

  @override
  Future<void> generateKeyPair() => _channel.invokeMethod('generateKeyPair');

  @override
  Future<Uint8List> wrap(Uint8List dataKey) async {
    final result =
        await _channel.invokeMethod<Uint8List>('wrap', {'dataKey': dataKey});
    return result!;
  }

  @override
  Future<Uint8List?> unwrap(Uint8List wrapped) {
    // A null reply covers cancel, failed match, and an invalidated key alike
    // — same convention CryptoService.unwrap uses for a wrong PIN.
    return _channel.invokeMethod<Uint8List>('unwrap', {'wrapped': wrapped});
  }

  @override
  Future<void> destroyKeyPair() => _channel.invokeMethod('destroyKeyPair');
}
```

- [ ] **Step 3: Add the `androidx.biometric` dependency**

In `android/app/build.gradle.kts`, inside the existing `dependencies { ... }` block (alongside `bcprov-jdk18on` and `androidx.webkit`), add:

```kotlin
    implementation("androidx.biometric:biometric:1.1.0")
```

- [ ] **Step 4: Implement `BiometricPlugin.kt`**

Create `android/app/src/main/kotlin/com/mono/container/BiometricPlugin.kt`:

```kotlin
package com.mono.container

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.spec.MGF1ParameterSpec
import javax.crypto.Cipher
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource

/**
 * The Keystore half. An RSA-2048 keypair whose private key requires a
 * biometric before it can be used: `wrap` (public key) never prompts;
 * decrypting needs a [BiometricPrompt]-authorized [Cipher], set up by
 * [BiometricPlugin.unwrap] below.
 */
class BiometricCore {
    private val store: KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    fun isAvailable(context: android.content.Context): Boolean =
        BiometricManager.from(context)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS

    fun generateKeyPair() {
        if (store.containsAlias(ALIAS)) store.deleteEntry(ALIAS)
        val builder = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        } else {
            @Suppress("DEPRECATION")
            builder.setUserAuthenticationValidityDurationSeconds(-1)
        }
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, KEYSTORE).apply {
            initialize(builder.build())
            generateKeyPair()
        }
    }

    fun destroyKeyPair() {
        if (store.containsAlias(ALIAS)) store.deleteEntry(ALIAS)
    }

    /** Public-key encrypt. The public key is not Keystore-authorization-gated
     * — only the private key entry is — so this never touches biometric auth. */
    fun wrap(dataKey: ByteArray): ByteArray {
        val cert = store.getCertificate(ALIAS)
            ?: error("biometric keypair not generated")
        val cipher = oaepCipher()
        cipher.init(Cipher.ENCRYPT_MODE, cert.publicKey, oaepParams())
        return cipher.doFinal(dataKey)
    }

    /** A `Cipher` bound to the auth-gated private key, ready for
     * [BiometricPrompt.CryptoObject]. Throws [KeyPermanentlyInvalidatedException]
     * if a new biometric was enrolled since the key was made. */
    fun privateCipherForDecrypt(): Cipher {
        val key = store.getKey(ALIAS, null) as PrivateKey
        val cipher = oaepCipher()
        cipher.init(Cipher.DECRYPT_MODE, key, oaepParams())
        return cipher
    }

    private fun oaepCipher(): Cipher = Cipher.getInstance("RSA/ECB/OAEPPadding")

    private fun oaepParams() = OAEPParameterSpec(
        "SHA-256", "MGF1", MGF1ParameterSpec.SHA256, PSource.PSpecified.DEFAULT,
    )

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val ALIAS = "container.biometric"
    }
}

/** Bridges [BiometricCore] to Dart and owns the [BiometricPrompt] UI, which
 * needs a [FragmentActivity] — `MainActivity` already is one via
 * `FlutterActivity`. */
class BiometricPlugin(
    private val activity: FragmentActivity,
    private val core: BiometricCore = BiometricCore(),
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(core.isAvailable(activity))
            "generateKeyPair" -> runCatching(core::generateKeyPair)
                .fold({ result.success(null) }, { result.error("biometric", it.message, null) })
            "wrap" -> {
                val dataKey = call.argument<ByteArray>("dataKey")!!
                runCatching { core.wrap(dataKey) }
                    .fold({ result.success(it) }, { result.error("biometric", it.message, null) })
            }
            "unwrap" -> unwrap(call.argument<ByteArray>("wrapped")!!, result)
            "destroyKeyPair" -> {
                core.destroyKeyPair()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun unwrap(wrapped: ByteArray, result: MethodChannel.Result) {
        val cipher = try {
            core.privateCipherForDecrypt()
        } catch (e: KeyPermanentlyInvalidatedException) {
            // A new fingerprint was enrolled since the key was made. Fails
            // closed: null, same as any other unwrap failure, and the dead
            // alias is cleared so a later `generateKeyPair` starts fresh.
            core.destroyKeyPair()
            result.success(null)
            return
        } catch (e: Exception) {
            result.success(null)
            return
        }

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    val decrypted = try {
                        authResult.cryptoObject!!.cipher!!.doFinal(wrapped)
                    } catch (e: Exception) {
                        null
                    }
                    result.success(decrypted)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Cancel and every other terminal error: a null reply,
                    // the same convention CryptoService.unwrap uses for a
                    // wrong PIN. No spec screen covers error copy, so
                    // nothing is surfaced beyond falling back to the PIN
                    // keypad still on screen underneath.
                    result.success(null)
                }

                override fun onAuthenticationFailed() {
                    // One failed match does not end the prompt; the system
                    // UI lets the user try again. No reply yet.
                }
            },
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock")
            .setSubtitle("Use your fingerprint to resume")
            .setNegativeButtonText("Use PIN instead")
            .build()

        prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
    }

    companion object {
        const val CHANNEL = "com.mono.container/biometric"
    }
}
```

- [ ] **Step 5: Register the plugin in `MainActivity`**

In `android/app/src/main/kotlin/com/mono/container/MainActivity.kt`, inside `configureFlutterEngine`, after the existing `SecureWindowPlugin` registration:

```kotlin
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BiometricPlugin.CHANNEL)
            .setMethodCallHandler(BiometricPlugin(this))
```

- [ ] **Step 6: Verify the Dart side analyzes clean and the Android side compiles**

Run: `flutter analyze`
Expected: No issues found.

Run: `flutter build apk --debug` (or, if no Android SDK/emulator is available in this environment, at minimum confirm Gradle sync by running the project's usual Android build check — see this repo's own build notes if `flutter build` cannot complete here).
Expected: Kotlin compiles with no errors from `BiometricPlugin.kt` or the `MainActivity.kt` edit.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/services/biometric_service.dart lib/data/services/android_biometric_service.dart android/app/src/main/kotlin/com/mono/container/BiometricPlugin.kt android/app/src/main/kotlin/com/mono/container/MainActivity.kt android/app/build.gradle.kts
git commit -m "feat: add the Keystore-backed BiometricPlugin and its Dart bridge"
```

---

## Task 3: `SessionController` — resume-only biometric wiring

**Files:**
- Modify: `lib/ui/features/shell/view_models/session_controller.dart`
- Modify: `lib/ui/features/setup/view_models/setup_controller.dart`
- Modify: `test/ui/features/setup/setup_controller_test.dart`
- Test: `test/ui/features/shell/session_controller_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository`/`SqliteSettingsRepository` (Task 1), `BiometricService`/`AndroidBiometricService` (Task 2), `Unlocked`/`Rejected`/`Throttled` (existing, `vault_unlocker.dart`).
- Produces: `SessionOpen` gains `required Uint8List dataKey` and `Uint8List? biometricWrappedKey`; `SessionLocked` gains `VaultId? biometricVault` and `Uint8List? biometricWrappedKey`; `biometricServiceProvider`; `SessionController.resumeWithBiometric()`, `SessionController.setBiometricWrapped(Uint8List?)`. `completeSetup` gains `required Uint8List dataKey`. Task 4 (`LockScreen`), Task 5 (`SettingsController`), and Task 7 (panic) all read these.

- [ ] **Step 1: Write the failing tests**

In `test/ui/features/shell/session_controller_test.dart`, add the fake and the new test cases. First, extend the imports and add `FakeBiometricService` near the top of the file (after the existing imports, before `void main()`):

```dart
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/domain/services/biometric_service.dart';
```

```dart
class FakeBiometricService implements BiometricService {
  bool available = true;
  bool unwrapSucceeds = true;
  bool keyPairGenerated = false;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> generateKeyPair() async => keyPairGenerated = true;

  @override
  Future<Uint8List> wrap(Uint8List dataKey) async => dataKey;

  @override
  Future<Uint8List?> unwrap(Uint8List wrapped) async =>
      unwrapSucceeds ? wrapped : null;

  @override
  Future<void> destroyKeyPair() async => keyPairGenerated = false;
}
```

Update `buildContainer` to include a safe default (existing tests keep passing unchanged):

```dart
  ProviderContainer buildContainer(Session initial) {
    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(initial),
      biometricServiceProvider.overrideWithValue(FakeBiometricService()),
      vaultOpenerProvider.overrideWithValue(
        ({required String path, required Uint8List dataKey}) => AppDatabase.open(
            path: inMemoryDatabasePath, factory: databaseFactoryFfi),
      ),
    ]);
    addTearDown(container.dispose);
    return container;
  }
```

The two existing tests that construct `SessionOpen` directly (`'returning within the grace period...'` and `'returning past the grace period...'`) now need the new required `dataKey` argument — update both call sites:

```dart
        buildContainer(SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32)));
```

Extend `'a correct main PIN opens vault A'` with one more assertion (biometrics disabled by default, so nothing is wrapped):

```dart
  test('a correct main PIN opens vault A', () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final container = buildContainer(
        SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate()));

    await container.read(sessionProvider.notifier).unlock('111111');

    final session = container.read(sessionProvider);
    expect(session, isA<SessionOpen>());
    expect((session as SessionOpen).vault, VaultId.a);
    expect(session.biometricWrappedKey, isNull);
  });
```

Then append these new tests at the end of `main()`, before the closing `}`:

```dart
  test('unlocking with biometrics already enabled for the vault re-wraps the data key',
      () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteSettingsRepository(db).setBool('biometrics_enabled', true);
    final biometrics = FakeBiometricService();

    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(
          SessionLocked(mood: LockMood.normal, gate: await vaultStore.gate())),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).unlock('111111');

    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, isNotNull);
  });

  test('a wrong PIN during welcomeBack keeps the pending biometric ciphertext',
      () async {
    await vaultStore.provision(pin: '111111', vault: VaultId.a);
    await vaultStore.provisionUnopenable(VaultId.b);
    final wrapped = Uint8List.fromList([9, 9, 9]);
    final container = buildContainer(SessionLocked(
      mood: LockMood.welcomeBack,
      gate: await vaultStore.gate(),
      biometricVault: VaultId.a,
      biometricWrappedKey: wrapped,
    ));

    await container.read(sessionProvider.notifier).unlock('000000');

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.mood, LockMood.wrong);
    expect(session.biometricVault, VaultId.a);
    expect(session.biometricWrappedKey, wrapped);
  });

  test('returning within the grace period carries a pending biometric wrap forward',
      () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final wrapped = Uint8List.fromList([1, 2, 3]);
    final container = buildContainer(SessionOpen(
      vault: VaultId.a,
      database: db,
      dataKey: Uint8List(32),
      biometricWrappedKey: wrapped,
    ));

    container
        .read(sessionProvider.notifier)
        .debugHandleReturn(ReturnDestination.board);

    final session = container.read(sessionProvider) as SessionLocked;
    expect(session.biometricVault, VaultId.a);
    expect(session.biometricWrappedKey, wrapped);
  });

  test('resumeWithBiometric reopens the vault without a PIN', () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final biometrics = FakeBiometricService();
    final wrapped = Uint8List.fromList([4, 5, 6]);

    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        biometricVault: VaultId.a,
        biometricWrappedKey: wrapped,
      )),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async => db),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).resumeWithBiometric();

    final session = container.read(sessionProvider);
    expect(session, isA<SessionOpen>());
    expect((session as SessionOpen).vault, VaultId.a);
  });

  test('resumeWithBiometric does nothing when the prompt is cancelled or fails',
      () async {
    final biometrics = FakeBiometricService()..unwrapSucceeds = false;
    final container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      vaultStoreProvider.overrideWithValue(vaultStore),
      documentsDirectoryProvider.overrideWithValue(dir),
      initialSessionProvider.overrideWithValue(SessionLocked(
        mood: LockMood.welcomeBack,
        gate: const AttemptGate(),
        biometricVault: VaultId.a,
        biometricWrappedKey: Uint8List.fromList([4, 5, 6]),
      )),
      biometricServiceProvider.overrideWithValue(biometrics),
      vaultOpenerProvider.overrideWithValue(
          ({required String path, required Uint8List dataKey}) async =>
              AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi)),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionProvider.notifier).resumeWithBiometric();

    expect(container.read(sessionProvider), isA<SessionLocked>());
  });

  test('setBiometricWrapped updates an open session in place', () async {
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final container = buildContainer(
        SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32)));

    container
        .read(sessionProvider.notifier)
        .setBiometricWrapped(Uint8List.fromList([1]));

    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, Uint8List.fromList([1]));
  });

  test('setBiometricWrapped is a no-op once the vault has closed', () async {
    final container = buildContainer(
        const SessionLocked(mood: LockMood.afterTimeout, gate: AttemptGate()));

    container
        .read(sessionProvider.notifier)
        .setBiometricWrapped(Uint8List.fromList([1]));

    expect(container.read(sessionProvider), isA<SessionLocked>());
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/ui/features/shell/session_controller_test.dart`
Expected: FAIL to compile — `biometricServiceProvider`, `resumeWithBiometric`, `setBiometricWrapped`, and the new `SessionOpen`/`SessionLocked` fields don't exist yet.

- [ ] **Step 3: Update `SessionOpen` and `SessionLocked`**

In `lib/ui/features/shell/view_models/session_controller.dart`, add the import:

```dart
import 'dart:typed_data';
```

Replace the `SessionOpen` class:

```dart
/// A vault is open. Read by `databaseProvider` below — nothing else in the
/// app ever asks which vault that is.
///
/// [dataKey] is not a new exposure: the SQLCipher connection [database]
/// already holds the equivalent key material resident for as long as the
/// session is open, so a second reference to the same bytes here adds
/// nothing. [biometricWrappedKey], once set, is ciphertext the vault's
/// public Keystore key produced — safe to hold indefinitely, since reading
/// it back requires a successful fingerprint.
class SessionOpen extends Session {
  const SessionOpen({
    required this.vault,
    required this.database,
    required this.dataKey,
    this.biometricWrappedKey,
  });

  final VaultId vault;
  final AppDatabase database;
  final Uint8List dataKey;
  final Uint8List? biometricWrappedKey;
}
```

Replace the `SessionLocked` class:

```dart
/// A vault exists but is not open right now. [mood] drives which copy
/// `LockBody` shows. [lockDeadline] is set only while [mood] is
/// [LockMood.welcomeBack] — `LockScreen` ticks its own timer against it and
/// calls [SessionController.graceExpired] once it passes; this class never
/// runs a `Timer` of its own.
///
/// [biometricVault] and [biometricWrappedKey] are non-null only while
/// [mood] is [LockMood.welcomeBack] and biometrics was enabled for the
/// vault that just backgrounded — never during a cold lock. This is what
/// makes biometric unlock resume-only: nothing here can open a vault this
/// session hasn't already opened once with a PIN.
class SessionLocked extends Session {
  const SessionLocked({
    required this.mood,
    required this.gate,
    this.openSessionCount = 0,
    this.lockDeadline,
    this.biometricVault,
    this.biometricWrappedKey,
  });

  final LockMood mood;
  final AttemptGate gate;
  final int openSessionCount;
  final DateTime? lockDeadline;
  final VaultId? biometricVault;
  final Uint8List? biometricWrappedKey;
}
```

- [ ] **Step 4: Add `biometricServiceProvider`**

After the existing `cryptoServiceProvider` definition, add:

```dart
final biometricServiceProvider =
    Provider<BiometricService>((ref) => const AndroidBiometricService());
```

Add the two new imports at the top of the file, alongside the existing `android_crypto_service.dart` import:

```dart
import '../../../../data/services/android_biometric_service.dart';
import '../../../../data/repositories/settings_repository_sqlite.dart';
import '../../../../domain/services/biometric_service.dart';
```

- [ ] **Step 5: Rewrite `unlock`, and add `_rewrapIfEnabled`, `resumeWithBiometric`, `setBiometricWrapped`**

Replace `SessionController.unlock`:

```dart
  Future<void> unlock(String pin) async {
    final previous = state;
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
        state = SessionOpen(
          vault: vault,
          database: database,
          dataKey: dataKey,
          biometricWrappedKey: await _rewrapIfEnabled(database, dataKey),
        );
      case Rejected(:final gate):
        await _vaultStore.saveGate(gate);
        state = SessionLocked(
          mood: LockMood.wrong,
          gate: gate,
          openSessionCount: _openCount(),
          biometricVault: previous is SessionLocked ? previous.biometricVault : null,
          biometricWrappedKey:
              previous is SessionLocked ? previous.biometricWrappedKey : null,
        );
      case Throttled():
        state = SessionLocked(
          mood: LockMood.wrong,
          gate: currentGate,
          openSessionCount: _openCount(),
          biometricVault: previous is SessionLocked ? previous.biometricVault : null,
          biometricWrappedKey:
              previous is SessionLocked ? previous.biometricWrappedKey : null,
        );
    }
  }

  /// Every fresh PIN unlock is self-healing: if biometrics is on for this
  /// vault, re-wrap under whatever Keystore key currently exists. This is
  /// how a key invalidated by new biometric enrollment (see
  /// `BiometricPlugin.unwrap`'s `KeyPermanentlyInvalidatedException`
  /// handling) repairs itself with no dedicated recovery flow.
  Future<Uint8List?> _rewrapIfEnabled(AppDatabase database, Uint8List dataKey) async {
    final enabled =
        await SqliteSettingsRepository(database).getBool('biometrics_enabled');
    if (!enabled) return null;
    return ref.read(biometricServiceProvider).wrap(dataKey);
  }

  /// `LockBody.onBiometric`'s target once `LockScreen` decides biometrics is
  /// on offer (`biometricAvailable`, Task 4). A no-op — the lock screen
  /// stays up with the PIN keypad still available — on cancel, a failed
  /// match, or an invalidated key, since [BiometricService.unwrap] returns
  /// null for all three.
  Future<void> resumeWithBiometric() async {
    final current = state;
    if (current is! SessionLocked ||
        current.mood != LockMood.welcomeBack ||
        current.biometricWrappedKey == null ||
        current.biometricVault == null) {
      return;
    }
    final dataKey = await ref
        .read(biometricServiceProvider)
        .unwrap(current.biometricWrappedKey!);
    if (dataKey == null) return;
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

  /// Called by `SettingsController` (Task 5) right after enabling or
  /// disabling biometrics. A no-op if the vault has since closed from
  /// under it.
  void setBiometricWrapped(Uint8List? wrapped) {
    final current = state;
    if (current is! SessionOpen) return;
    state = SessionOpen(
      vault: current.vault,
      database: current.database,
      dataKey: current.dataKey,
      biometricWrappedKey: wrapped,
    );
  }
```

- [ ] **Step 6: Carry the biometric fields through `_handleReturn` and update `completeSetup`**

Replace the `ReturnDestination.board` case inside `_handleReturn`:

```dart
      case ReturnDestination.board:
        state = SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          openSessionCount: ref.read(openSiteIdsProvider).length,
          lockDeadline: DateTime.now().add(AutoLockPolicy.oneMinute.grace),
          biometricVault: current.vault,
          biometricWrappedKey: current.biometricWrappedKey,
        );
```

(`current` is already known to be `SessionOpen` at this point — the method's existing guard clause above it, `if (current is! SessionOpen) return;`, is unchanged.)

Replace `completeSetup`:

```dart
  /// Called once by `SetupController` (Task 6), via `setupControllerProvider`
  /// below, when setup has just provisioned and seeded the real vault.
  /// Biometrics can't be enabled yet at this point — Settings is
  /// unreachable during setup — so this never wraps anything.
  void completeSetup({
    required VaultId vault,
    required AppDatabase database,
    required Uint8List dataKey,
  }) {
    state = SessionOpen(vault: vault, database: database, dataKey: dataKey);
  }
```

Update `setupControllerProvider`'s `openSession` callback:

```dart
final setupControllerProvider = Provider<SetupController>((ref) {
  final documents = ref.read(documentsDirectoryProvider);
  return SetupController(
    vaultStore: ref.read(vaultStoreProvider),
    openVault: ref.read(vaultOpenerProvider),
    pathFor: (vault) => vaultDatabasePath(documents, vault),
    openSession: (
            {required VaultId vault,
            required AppDatabase database,
            required Uint8List dataKey}) =>
        ref.read(sessionProvider.notifier).completeSetup(
              vault: vault,
              database: database,
              dataKey: dataKey,
            ),
  );
});
```

- [ ] **Step 7: Widen `SetupController`'s `SessionOpener` and its call site**

In `lib/ui/features/setup/view_models/setup_controller.dart`, replace the `SessionOpener` typedef:

```dart
typedef SessionOpener = void Function({
  required VaultId vault,
  required AppDatabase database,
  required Uint8List dataKey,
});
```

Replace the last line of `SetupController.complete`:

```dart
    _openSession(vault: VaultId.a, database: mainDb, dataKey: mainKey);
```

- [ ] **Step 8: Fix `setup_controller_test.dart`'s fake to match**

In `test/ui/features/setup/setup_controller_test.dart`, update the `sessions` list's record type and the fake `openSession`:

```dart
  final sessions = <({VaultId vault, AppDatabase database, Uint8List dataKey})>[];
```

```dart
        openSession: (
                {required VaultId vault,
                required AppDatabase database,
                required Uint8List dataKey}) =>
            sessions.add((vault: vault, database: database, dataKey: dataKey)),
```

- [ ] **Step 9: Run the tests to verify they pass**

Run: `flutter test test/ui/features/shell/session_controller_test.dart test/ui/features/setup/setup_controller_test.dart`
Expected: PASS — all tests in both files.

- [ ] **Step 10: Run the full test suite to check for fallout**

Run: `flutter test`
Expected: everything passes except `test/ui/features/lock_body_test.dart` and `test/ui/features/shell/lock_screen_test.dart`, which Task 4 fixes — confirm those are the *only* failures, and that they fail for the reason this task predicts (`SessionOpen`'s new required `dataKey` parameter, or `LockBody`'s not-yet-added `biometricAvailable` parameter), not some other regression.

- [ ] **Step 11: Commit**

```bash
git add lib/ui/features/shell/view_models/session_controller.dart lib/ui/features/setup/view_models/setup_controller.dart test/ui/features/shell/session_controller_test.dart test/ui/features/setup/setup_controller_test.dart
git commit -m "feat: resume-only biometric unlock in SessionController"
```

---

## Task 4: `LockBody` gating and `LockScreen` wiring

**Files:**
- Modify: `lib/ui/features/lock/views/lock_body.dart`
- Modify: `lib/ui/features/lock/views/lock_screen.dart`
- Modify: `test/ui/features/lock_body_test.dart`
- Modify: `test/ui/features/shell/lock_screen_test.dart`

**Interfaces:**
- Consumes: `SessionController.resumeWithBiometric()`, `SessionLocked.biometricWrappedKey` (Task 3).
- Produces: `LockBody` gains `bool biometricAvailable = false`; the fingerprint affordance now renders only when `mood == LockMood.welcomeBack && biometricAvailable`.

- [ ] **Step 1: Write the failing `LockBody` tests**

In `test/ui/features/lock_body_test.dart`, update the `_body` helper to accept the new parameters:

```dart
LockBody _body(
  LockMood mood, {
  int triesLeft = 5,
  int filled = 0,
  bool biometricAvailable = false,
  VoidCallback onBiometric = _defaultOnBiometric,
}) => LockBody(
      mood: mood,
      filled: filled,
      triesLeft: triesLeft,
      openSessions: 3,
      secondsUntilLock: 40,
      onKey: (_) {},
      onBiometric: onBiometric,
      biometricAvailable: biometricAvailable,
    );

void _defaultOnBiometric() {}
```

Remove the fingerprint assertion from the `normal` test and add its negation:

```dart
  testWidgets('the normal lock says nothing about vaults', (tester) async {
    await _pump(tester, _body(LockMood.normal));

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Use fingerprint'), findsNothing);
    expect(find.textContaining('vault', findRichText: true), findsNothing);
    expect(find.textContaining('decoy'), findsNothing);
    expect(find.textContaining('second'), findsNothing);
  });
```

Remove the now-nonexistent "Fingerprint unavailable" assertion from the `wrong` test:

```dart
  testWidgets('a wrong PIN counts down without naming what is behind it',
      (tester) async {
    await _pump(tester, _body(LockMood.wrong, triesLeft: 3));

    expect(find.text('Wrong PIN · 3 tries left'), findsOneWidget);
    expect(
      find.text('After 5 wrong tries the app waits 30 seconds before '
          'accepting another.'),
      findsOneWidget,
    );
    expect(find.text('Use fingerprint'), findsNothing);
    expect(find.textContaining('vault'), findsNothing);
  });
```

Add a negation to the `afterTimeout` test:

```dart
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
    expect(find.text('Use fingerprint'), findsNothing);
  });
```

Add three new tests at the end of `main()`:

```dart
  testWidgets('welcomeBack offers fingerprint only when biometrics is available',
      (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack, biometricAvailable: true));

    expect(find.text('Use fingerprint'), findsOneWidget);
  });

  testWidgets('welcomeBack hides fingerprint when biometrics is unavailable',
      (tester) async {
    await _pump(tester, _body(LockMood.welcomeBack));

    expect(find.text('Use fingerprint'), findsNothing);
  });

  testWidgets('tapping the fingerprint prompt calls onBiometric', (tester) async {
    var tapped = false;
    await _pump(
      tester,
      _body(LockMood.welcomeBack,
          biometricAvailable: true, onBiometric: () => tapped = true),
    );

    await tester.tap(find.text('Use fingerprint'));
    expect(tapped, isTrue);
  });
```

- [ ] **Step 2: Run the `LockBody` tests to verify they fail**

Run: `flutter test test/ui/features/lock_body_test.dart`
Expected: FAIL — `biometricAvailable` is not a parameter of `LockBody` yet, and the fingerprint text still appears in `normal`/`wrong`/`afterTimeout`.

- [ ] **Step 3: Add `biometricAvailable` and re-gate `_biometric()`**

In `lib/ui/features/lock/views/lock_body.dart`, update the constructor and fields:

```dart
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
    this.biometricAvailable = false,
  });

  final LockMood mood;
  final int filled;
  final void Function(String key) onKey;
  final VoidCallback onBiometric;
  final int triesLeft;
  final int openSessions;
  final int secondsUntilLock;
  final bool biometricAvailable;

  bool get _wrong => mood == LockMood.wrong;

  /// Resume-only: the fingerprint prompt only ever appears for a vault this
  /// session already opened once with a PIN and is now re-confirming
  /// during the welcome-back grace window — never for a cold lock. See the
  /// biometric-unlock design spec's "Decision" section for why.
  bool get _showBiometric => mood == LockMood.welcomeBack && biometricAvailable;
```

Update `build`'s children list:

```dart
              PinKeypad(onKey: onKey),
              if (_showBiometric) _biometric(),
```

Simplify `_biometric()` — it is now only ever built while not-wrong-and-welcomeBack, so the disabled-state branch is dead:

```dart
  Widget _biometric() => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 30),
        child: GestureDetector(
          onTap: onBiometric,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('☉', style: ui(size: 24, color: C.jade)),
              const SizedBox(height: 8),
              Text('Use fingerprint', style: ui(size: 12, color: C.textFaint)),
            ],
          ),
        ),
      );
```

- [ ] **Step 4: Run the `LockBody` tests to verify they pass**

Run: `flutter test test/ui/features/lock_body_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Write the failing `LockScreen` test**

In `test/ui/features/shell/lock_screen_test.dart`, add imports:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/vault.dart';

import 'session_controller_test.dart' show FakeBiometricService;
```

Add two new tests at the end of `main()`:

```dart
  testWidgets('tapping the fingerprint prompt resumes without a PIN',
      (tester) async {
    final dir = await Directory.systemTemp.createTemp('lock-screen-test');
    addTearDown(() => dir.delete(recursive: true));
    final db = await AppDatabase.open(
        path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    final biometrics = FakeBiometricService();

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialSessionProvider.overrideWithValue(SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          biometricVault: VaultId.a,
          biometricWrappedKey: Uint8List.fromList([1, 2, 3]),
        )),
        documentsDirectoryProvider.overrideWithValue(dir),
        biometricServiceProvider.overrideWithValue(biometrics),
        vaultOpenerProvider.overrideWithValue(
            ({required String path, required Uint8List dataKey}) async => db),
      ],
      child: const MaterialApp(home: LockScreen()),
    ));

    expect(find.text('Use fingerprint'), findsOneWidget);
    await tester.tap(find.text('Use fingerprint'));
    await tester.pumpAndSettle();

    expect(find.byType(LockBody), findsNothing);
  });

  testWidgets('a cancelled fingerprint prompt leaves the lock screen up',
      (tester) async {
    final biometrics = FakeBiometricService()..unwrapSucceeds = false;

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        initialSessionProvider.overrideWithValue(SessionLocked(
          mood: LockMood.welcomeBack,
          gate: const AttemptGate(),
          biometricVault: VaultId.a,
          biometricWrappedKey: Uint8List.fromList([1, 2, 3]),
        )),
        biometricServiceProvider.overrideWithValue(biometrics),
      ],
      child: const MaterialApp(home: LockScreen()),
    ));

    await tester.tap(find.text('Use fingerprint'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
```

Also import `LockBody` itself (used by the `findsNothing` assertion):

```dart
import 'package:container/ui/features/lock/views/lock_body.dart' show LockBody, LockMood;
```

(this replaces the existing narrower `show LockMood` import on that line).

- [ ] **Step 6: Run the test to verify it fails**

Run: `flutter test test/ui/features/shell/lock_screen_test.dart`
Expected: FAIL — `LockScreen`'s `onBiometric` is still the no-op stub, so nothing resumes and `biometricAvailable` is never passed through.

- [ ] **Step 7: Wire `LockScreen.onBiometric`**

In `lib/ui/features/lock/views/lock_screen.dart`, add a method next to `_submit`:

```dart
  Future<void> _resumeWithBiometric() =>
      ref.read(sessionProvider.notifier).resumeWithBiometric();
```

Replace the `LockBody(...)` construction:

```dart
    return LockBody(
      mood: session.mood,
      filled: _pin.value.filled,
      triesLeft: session.gate.triesLeft,
      openSessions: session.openSessionCount,
      secondsUntilLock: secondsUntilLock,
      onKey: _pin.onKey,
      onBiometric: _resumeWithBiometric,
      biometricAvailable: session.biometricWrappedKey != null,
    );
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/ui/features/shell/lock_screen_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 9: Run the full suite**

Run: `flutter test`
Expected: PASS, no failures anywhere.

- [ ] **Step 10: Commit**

```bash
git add lib/ui/features/lock/views/lock_body.dart lib/ui/features/lock/views/lock_screen.dart test/ui/features/lock_body_test.dart test/ui/features/shell/lock_screen_test.dart
git commit -m "feat: gate LockBody's fingerprint prompt to welcomeBack resume only"
```

---

## Task 5: `SettingsController` — enable/disable business logic

**Files:**
- Create: `lib/ui/features/settings/view_models/providers.dart`
- Test: `test/ui/features/settings/settings_controller_test.dart`

**Interfaces:**
- Consumes: `SettingsRepository`/`SqliteSettingsRepository` (Task 1), `BiometricService` (Task 2), `biometricServiceProvider`, `sessionProvider`, `SessionOpen`, `SessionController.setBiometricWrapped` (Task 3), `databaseProvider` (existing, `lib/ui/features/dashboard/view_models/providers.dart`).
- Produces: `settingsRepositoryProvider`, `biometricsEnabledProvider` (`FutureProvider<bool>`), `SettingsController.setBiometricsEnabled(bool)`, `settingsControllerProvider`. Task 6 reads all four.

- [ ] **Step 1: Write the failing test**

Create `test/ui/features/settings/settings_controller_test.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/vault_store.dart';
import 'package:container/domain/models/vault.dart';
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:container/ui/features/shell/view_models/session_controller.dart';

import '../../../domain/vault_unlocker_test.dart' show FakeCrypto;
import '../shell/session_controller_test.dart' show FakeBiometricService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  late FakeBiometricService biometrics;
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings-controller-test');
    db = await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    biometrics = FakeBiometricService();
    container = ProviderContainer(overrides: [
      cryptoServiceProvider.overrideWithValue(FakeCrypto()),
      vaultStoreProvider.overrideWithValue(
          VaultStore(FakeCrypto(), File('${dir.path}/meta.bin'))),
      documentsDirectoryProvider.overrideWithValue(dir),
      biometricServiceProvider.overrideWithValue(biometrics),
      initialSessionProvider.overrideWithValue(
          SessionOpen(vault: VaultId.a, database: db, dataKey: Uint8List(32))),
    ]);
    addTearDown(container.dispose);
  });

  tearDown(() => dir.delete(recursive: true));

  test('enabling biometrics generates a keypair, wraps the open session\'s '
      'data key, and persists the setting', () async {
    await container.read(settingsControllerProvider).setBiometricsEnabled(true);

    expect(biometrics.keyPairGenerated, isTrue);
    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, isNotNull);
    expect(await container.read(settingsRepositoryProvider).getBool('biometrics_enabled'),
        isTrue);
  });

  test('disabling clears the in-memory ciphertext immediately', () async {
    await container.read(settingsControllerProvider).setBiometricsEnabled(true);

    await container.read(settingsControllerProvider).setBiometricsEnabled(false);

    expect(biometrics.keyPairGenerated, isFalse);
    final session = container.read(sessionProvider) as SessionOpen;
    expect(session.biometricWrappedKey, isNull);
    expect(await container.read(settingsRepositoryProvider).getBool('biometrics_enabled'),
        isFalse);
  });

  test('biometricsEnabledProvider reflects the persisted setting', () async {
    expect(await container.read(biometricsEnabledProvider.future), isFalse);

    await container.read(settingsControllerProvider).setBiometricsEnabled(true);
    container.invalidate(biometricsEnabledProvider);

    expect(await container.read(biometricsEnabledProvider.future), isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/features/settings/settings_controller_test.dart`
Expected: FAIL to compile — `lib/ui/features/settings/view_models/providers.dart` does not exist yet.

- [ ] **Step 3: Implement `SettingsController`**

Create `lib/ui/features/settings/view_models/providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/settings_repository_sqlite.dart';
import '../../../../domain/repositories/repositories.dart' show SettingsRepository;
import '../../dashboard/view_models/providers.dart' show databaseProvider;
import '../../shell/view_models/session_controller.dart'
    show biometricServiceProvider, sessionProvider, SessionOpen;

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SqliteSettingsRepository(ref.watch(databaseProvider)),
);

/// Backs `SettingsScreen`'s LOCK section biometrics row. Every other row on
/// that screen is still a static placeholder — see this plan's Known Gaps.
final biometricsEnabledProvider = FutureProvider<bool>(
  (ref) => ref.watch(settingsRepositoryProvider).getBool('biometrics_enabled'),
);

class SettingsController {
  SettingsController(this._ref);

  final Ref _ref;

  /// Turning this on happens from inside an already-open, already-
  /// authenticated session, so no PIN re-entry is needed — `SessionOpen`
  /// already holds the raw data key this wraps. Turning it off clears the
  /// in-memory ciphertext immediately, rather than waiting for the next
  /// time the app backgrounds.
  Future<void> setBiometricsEnabled(bool value) async {
    final biometrics = _ref.read(biometricServiceProvider);
    final repository = _ref.read(settingsRepositoryProvider);

    if (value) {
      await biometrics.generateKeyPair();
      final session = _ref.read(sessionProvider);
      if (session is SessionOpen) {
        final wrapped = await biometrics.wrap(session.dataKey);
        _ref.read(sessionProvider.notifier).setBiometricWrapped(wrapped);
      }
    } else {
      await biometrics.destroyKeyPair();
      _ref.read(sessionProvider.notifier).setBiometricWrapped(null);
    }

    await repository.setBool('biometrics_enabled', value);
    _ref.invalidate(biometricsEnabledProvider);
  }
}

final settingsControllerProvider = Provider((ref) => SettingsController(ref));
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/features/settings/settings_controller_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS everywhere.

- [ ] **Step 6: Commit**

```bash
git add lib/ui/features/settings/view_models/providers.dart test/ui/features/settings/settings_controller_test.dart
git commit -m "feat: add SettingsController for the biometrics toggle"
```

---

## Task 6: Reaching Settings — `WorkspaceBar`'s `⋯` icon and dashboard navigation

**Files:**
- Modify: `lib/ui/features/dashboard/views/workspace_bar.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_body.dart`
- Modify: `lib/ui/features/dashboard/views/dashboard_screen.dart`
- Test: `test/ui/features/dashboard/workspace_bar_test.dart`

**Interfaces:**
- Consumes: `biometricsEnabledProvider`, `settingsControllerProvider` (Task 5), `SettingsScreen` (existing, unmodified).
- Produces: `WorkspaceBar` gains `required VoidCallback onOverflow`; `DashboardBody` gains `required VoidCallback onOverflow`; `DashboardScreen` pushes a real, connected `SettingsScreen`.

- [ ] **Step 1: Write the failing `WorkspaceBar` test**

Create `test/ui/features/dashboard/workspace_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/dashboard/views/workspace_bar.dart';

void main() {
  Widget harness({required VoidCallback onOverflow}) => MaterialApp(
        home: WorkspaceBar(
          name: 'Personal',
          trailing: '2 SESSIONS · 0 LEAKS',
          trailingIsBadge: false,
          onTap: () {},
          onOverflow: onOverflow,
        ),
      );

  testWidgets('the workspace name and trailing text still render',
      (tester) async {
    await tester.pumpWidget(harness(onOverflow: () {}));

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('2 SESSIONS · 0 LEAKS'), findsOneWidget);
  });

  testWidgets('tapping the overflow icon calls onOverflow', (tester) async {
    var tapped = false;
    await tester.pumpWidget(harness(onOverflow: () => tapped = true));

    await tester.tap(find.text('⋯'));
    expect(tapped, isTrue);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/features/dashboard/workspace_bar_test.dart`
Expected: FAIL — `WorkspaceBar` has no `onOverflow` parameter yet.

- [ ] **Step 3: Add the `⋯` icon to `WorkspaceBar`**

In `lib/ui/features/dashboard/views/workspace_bar.dart`, update the constructor:

```dart
class WorkspaceBar extends StatelessWidget {
  const WorkspaceBar({
    super.key,
    required this.name,
    required this.trailing,
    required this.trailingIsBadge,
    required this.onTap,
    required this.onOverflow,
  });

  final String name;
  final String trailing;
  final bool trailingIsBadge;
  final VoidCallback onTap;
  final VoidCallback onOverflow;
```

Replace the `Row`'s trailing `Text` with a `Row` that also carries the new icon:

```dart
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailing,
                    style: trailingIsBadge ? T.barBadge : T.barSummary,
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: onOverflow,
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Text('⋯', style: TextStyle(fontSize: 15, color: C.chevron)),
                    ),
                  ),
                ],
              ),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ui/features/dashboard/workspace_bar_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Thread `onOverflow` through `DashboardBody`**

In `lib/ui/features/dashboard/views/dashboard_body.dart`, add the field:

```dart
class DashboardBody extends StatelessWidget {
  const DashboardBody({
    super.key,
    required this.view,
    required this.onWorkspaceTap,
    required this.onAddSite,
    required this.onSearch,
    required this.onOpenSite,
    required this.onSiteMenu,
    required this.onOverflow,
  });

  final DashboardView view;
  final VoidCallback onWorkspaceTap;
  final VoidCallback onAddSite;
  final VoidCallback onSearch;
  final void Function(String siteId) onOpenSite;
  final void Function(String siteId) onSiteMenu;
  final VoidCallback onOverflow;
```

Pass it to `WorkspaceBar`:

```dart
            WorkspaceBar(
              name: view.workspaceName,
              trailing: view.wipesOnExit
                  ? 'WIPES ON EXIT'
                  : '${view.sessionCount} SESSIONS · ${view.leakCount} LEAKS',
              trailingIsBadge: view.wipesOnExit,
              onTap: onWorkspaceTap,
              onOverflow: onOverflow,
            ),
```

- [ ] **Step 6: Wire `DashboardScreen` to push a connected `SettingsScreen`**

In `lib/ui/features/dashboard/views/dashboard_screen.dart`, add imports:

```dart
import '../../settings/view_models/providers.dart'
    show biometricsEnabledProvider, settingsControllerProvider;
import '../../settings/views/settings_screen.dart';
```

Add `onOverflow` to the `DashboardBody(...)` construction inside `build`:

```dart
            onOverflow: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const _SettingsRoute())),
```

Add the new route widget at the bottom of the file, alongside `_SearchRoute`:

```dart
class _SettingsRoute extends ConsumerWidget {
  const _SettingsRoute();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometrics = ref.watch(biometricsEnabledProvider);
    return SettingsScreen(
      biometrics: biometrics.value ?? false,
      autoLockLabel: 'After 1 min',
      decoyEnabled: false,
      decoySiteCount: 0,
      hideFromSwitcher: true,
      panicOnFlip: false,
      onPanicLabel: 'Wipe + lock',
      onChanged: (key, value) {
        if (key == 'biometrics') {
          ref.read(settingsControllerProvider).setBiometricsEnabled(value);
        }
      },
      onTap: (_) {},
    );
  }
}
```

- [ ] **Step 7: Run the full suite**

Run: `flutter test`
Expected: PASS everywhere — `dashboard_screen.dart`/`dashboard_body.dart` have no existing dedicated widget test file to update (checked: none exists), so this step's only job is confirming nothing else broke.

- [ ] **Step 8: Manual sanity check of the analyzer**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 9: Commit**

```bash
git add lib/ui/features/dashboard/views/workspace_bar.dart lib/ui/features/dashboard/views/dashboard_body.dart lib/ui/features/dashboard/views/dashboard_screen.dart test/ui/features/dashboard/workspace_bar_test.dart
git commit -m "feat: reach Settings from the dashboard via a new overflow icon"
```

---

## Task 7: Panic destroys the biometric key too

**Files:**
- Modify: `lib/data/services/container_panic_service.dart`
- Modify: `lib/ui/features/container/view_models/providers.dart`
- Modify: `test/data/container_panic_service_test.dart`

**Interfaces:**
- Consumes: `BiometricService.destroyKeyPair()` (Task 2), `biometricServiceProvider` (Task 3).
- Produces: `ContainerPanicService` gains a fourth required constructor parameter, `Future<void> Function() destroyBiometricKey`.

- [ ] **Step 1: Write the failing test**

In `test/data/container_panic_service_test.dart`, update all four `ContainerPanicService(...)` construction sites to pass `destroyBiometricKey`, and extend the first test to observe it:

```dart
  test('every container is destroyed before anything else is', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));

    final order = <String>[];
    final service = ContainerPanicService(
      engine: engine,
      closeDatabase: () async => order.add('close:${engine.wipedAll}'),
      destroyVaults: () async => order.add('destroy:${engine.wipedAll}'),
      destroyBiometricKey: () async => order.add('biometric:${engine.wipedAll}'),
    );

    await service.trigger();

    expect(engine.wipedAll, isTrue);
    // All three later steps observed the profiles as already gone.
    expect(order, ['close:true', 'destroy:true', 'biometric:true']);
  });

  test('live sessions are closed before the profiles are wiped', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));

    await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async {},
      destroyBiometricKey: () async {},
    ).trigger();

    expect(engine.closed, ['a', 'b']);
  });

  test('the report counts what was destroyed', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));
    await engine.open(_site('c'));

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async {},
      destroyBiometricKey: () async {},
    ).trigger();

    expect(report.sessionsDestroyed, 3);
  });

  test('panic on a cold app with nothing open still completes', () async {
    final engine = FakeContainerEngine();
    var destroyed = false;

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async => destroyed = true,
      destroyBiometricKey: () async {},
    ).trigger();

    expect(report.sessionsDestroyed, 0);
    expect(destroyed, isTrue);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/data/container_panic_service_test.dart`
Expected: FAIL to compile — `destroyBiometricKey` is not a parameter of `ContainerPanicService` yet.

- [ ] **Step 3: Add the parameter and call it**

In `lib/data/services/container_panic_service.dart`:

```dart
class ContainerPanicService implements PanicService {
  ContainerPanicService({
    required ContainerEngine engine,
    required Future<void> Function() closeDatabase,
    required Future<void> Function() destroyVaults,
    required Future<void> Function() destroyBiometricKey,
  })  : _engine = engine,
        _closeDatabase = closeDatabase,
        _destroyVaults = destroyVaults,
        _destroyBiometricKey = destroyBiometricKey;

  // ignore_for_file: prefer_initializing_formals — see the constructor's
  // existing rationale above for the other three fields; the same applies
  // to `_destroyBiometricKey`.
  final ContainerEngine _engine;
  final Future<void> Function() _closeDatabase;
  final Future<void> Function() _destroyVaults;
  final Future<void> Function() _destroyBiometricKey;

  @override
  Future<PanicReport> trigger() async {
    // Snapshot before destroying: this is what `3c` reports.
    final live = await _engine.liveSessions();

    // `ProfileStore.deleteProfile` throws while a profile is attached to a
    // live WebView, so detaching first is not optional politeness.
    for (final session in live) {
      await _engine.close(session.siteId);
    }

    await _engine.wipeAll();
    await _closeDatabase();
    await _destroyVaults();
    await _destroyBiometricKey();

    return PanicReport(sessionsDestroyed: live.length);
  }
}
```

- [ ] **Step 4: Wire the real callback in `panicServiceProvider`**

In `lib/ui/features/container/view_models/providers.dart`, update the import's `show` clause:

```dart
import '../../shell/view_models/session_controller.dart'
    show sessionProvider, vaultStoreProvider, biometricServiceProvider, SessionOpen;
```

Update `panicServiceProvider`:

```dart
final panicServiceProvider = Provider<PanicService>((ref) {
  return ContainerPanicService(
    engine: ref.read(containerEngineProvider),
    closeDatabase: () async {
      final session = ref.read(sessionProvider);
      if (session is SessionOpen) await session.database.close();
    },
    destroyVaults: () => ref.read(vaultStoreProvider).destroy(),
    destroyBiometricKey: () => ref.read(biometricServiceProvider).destroyKeyPair(),
  );
});
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/data/container_panic_service_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Run the full suite**

Run: `flutter test`
Expected: PASS everywhere.

- [ ] **Step 7: Commit**

```bash
git add lib/data/services/container_panic_service.dart lib/ui/features/container/view_models/providers.dart test/data/container_panic_service_test.dart
git commit -m "feat: panic also destroys the biometric Keystore key"
```

---

## Task 8: Full verification pass

**Files:** none (verification only — fix inline if anything is found).

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: every test passes, including all seven prior tasks' additions and every pre-existing test this plan touched (`session_controller_test.dart`, `setup_controller_test.dart`, `lock_body_test.dart`, `lock_screen_test.dart`, `container_panic_service_test.dart`, plus the schema tests under `test/data/`).

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 3: Re-read the spec's "Known gaps" section and confirm each is still true of the tree**

Open `docs/superpowers/specs/2026-09-08-biometric-unlock-design.md`'s "Known gaps this design accepts" section and check, by reading the actual current code (not by assuming):
- `SettingsScreen`'s `Auto-lock`, `Change main PIN`, decoy fields, and `panicOnFlip`/`onPanicLabel` are still static/inert in `_SettingsRoute` (`dashboard_screen.dart`).
- No copy was invented anywhere for an "unavailable" or "invalidated" biometric state.
- Nothing added a biometrics option anywhere reachable from a decoy session.

If any of these turns out untrue (something crept in during implementation that this plan didn't intend), fix it now rather than leaving the spec's record of the tree's known gaps stale.

- [ ] **Step 4: Update `CLAUDE.md`'s tracking entry**

In `CLAUDE.md`, find the "Unassigned work" bullet for biometric unlock (search for `**Biometric unlock.**`) and replace its "Update, 2026-09-08" note with one recording that implementation is done — name the actual commits from Tasks 1–7 once they exist, and note the final `flutter test`/`flutter analyze` results from Steps 1–2 above, following the same style as this file's other "✅ Fixed" / "**Update:**" entries elsewhere in the "Known cross-plan issues" and plan-table sections.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: record biometric unlock as implemented"
```

---

## Known gaps this plan accepts (inherited from the spec)

- Every `SettingsScreen` row other than biometrics stays exactly as inert as it is today.
- No "biometrics unavailable" or "invalidated key" copy exists anywhere — both fail silently to the PIN fallback.
- The decoy vault never has a biometrics option; `SettingsScreen` remains a real-vault-only surface.
- No Kotlin instrumentation test exists for `BiometricPlugin` — `BiometricPrompt` cannot be driven from a JVM unit test.

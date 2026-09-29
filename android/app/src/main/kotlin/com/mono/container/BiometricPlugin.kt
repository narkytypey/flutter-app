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

/** The single alias both vaults shared before each got its own. */
internal const val LEGACY_BIOMETRIC_ALIAS = "container.biometric"

/**
 * One keypair per vault, so turning biometrics off in one vault cannot
 * delete the other's key. [vault] is Dart's `VaultId.name`; anything else is
 * refused rather than mapped to an alias nothing else would ever clean up.
 */
internal fun biometricAlias(vault: String?): String {
    require(vault == "a" || vault == "b") { "unknown vault: $vault" }
    return "$LEGACY_BIOMETRIC_ALIAS.$vault"
}

/** Everything panic deletes: both vaults' keys, and the pre-split shared one. */
internal val allBiometricAliases: List<String> =
    listOf(LEGACY_BIOMETRIC_ALIAS, biometricAlias("a"), biometricAlias("b"))

/**
 * The Keystore half. An RSA-2048 keypair per vault whose private key requires
 * a biometric before it can be used: `wrap` (public key) never prompts;
 * decrypting needs a [BiometricPrompt]-authorized [Cipher], set up by
 * [BiometricPlugin.unwrap] below.
 */
class BiometricCore {
    private val store: KeyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    fun isAvailable(context: android.content.Context): Boolean =
        BiometricManager.from(context)
            .canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS

    fun generateKeyPair(alias: String) {
        destroyKeyPair(alias)
        // Ciphertext under the shared key only ever lived in memory, so none
        // survived the update that split it; the first per-vault key retires it.
        destroyKeyPair(LEGACY_BIOMETRIC_ALIAS)
        val builder = KeyGenParameterSpec.Builder(
            alias,
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

    fun destroyKeyPair(alias: String) {
        if (store.containsAlias(alias)) store.deleteEntry(alias)
    }

    /** Panic's step: every alias gets its attempt even if an earlier one throws. */
    fun destroyAllKeyPairs() {
        allBiometricAliases
            .mapNotNull { runCatching { destroyKeyPair(it) }.exceptionOrNull() }
            .firstOrNull()
            ?.let { throw it }
    }

    /** Public-key encrypt. The public key is not Keystore-authorization-gated
     * — only the private key entry is — so this never touches biometric auth. */
    fun wrap(alias: String, dataKey: ByteArray): ByteArray {
        val cert = store.getCertificate(alias)
            ?: error("biometric keypair not generated")
        val cipher = oaepCipher()
        cipher.init(Cipher.ENCRYPT_MODE, cert.publicKey, oaepParams())
        return cipher.doFinal(dataKey)
    }

    /** A `Cipher` bound to the auth-gated private key, ready for
     * [BiometricPrompt.CryptoObject]. Throws [KeyPermanentlyInvalidatedException]
     * if a new biometric was enrolled since the key was made. */
    fun privateCipherForDecrypt(alias: String): Cipher {
        val key = store.getKey(alias, null) as PrivateKey
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
    }
}

/** Bridges [BiometricCore] to Dart and owns the [BiometricPrompt] UI, which
 * needs a [FragmentActivity] — `MainActivity` already is one via
 * `FlutterFragmentActivity`. */
class BiometricPlugin(
    private val activity: FragmentActivity,
    private val core: BiometricCore = BiometricCore(),
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(core.isAvailable(activity))
            "generateKeyPair" -> runCatching {
                core.generateKeyPair(biometricAlias(call.argument("vault")))
            }.fold({ result.success(null) }, { result.error("biometric", it.message, null) })
            "wrap" -> {
                val dataKey = call.argument<ByteArray>("dataKey")!!
                runCatching { core.wrap(biometricAlias(call.argument("vault")), dataKey) }
                    .fold({ result.success(it) }, { result.error("biometric", it.message, null) })
            }
            "unwrap" -> unwrap(call.argument("vault"), call.argument<ByteArray>("wrapped")!!, result)
            "destroyKeyPair" -> runCatching {
                core.destroyKeyPair(biometricAlias(call.argument("vault")))
            }.fold({ result.success(null) }, { result.error("biometric", it.message, null) })
            "destroyAllKeyPairs" -> runCatching(core::destroyAllKeyPairs)
                .fold({ result.success(null) }, { result.error("biometric", it.message, null) })
            else -> result.notImplemented()
        }
    }

    private fun unwrap(vault: String?, wrapped: ByteArray, result: MethodChannel.Result) {
        val alias = runCatching { biometricAlias(vault) }.getOrElse {
            result.success(null)
            return
        }
        val cipher = try {
            core.privateCipherForDecrypt(alias)
        } catch (e: KeyPermanentlyInvalidatedException) {
            // A new fingerprint was enrolled since the key was made. Fails
            // closed: null, same as any other unwrap failure, and the dead
            // alias is cleared so a later `generateKeyPair` starts fresh.
            core.destroyKeyPair(alias)
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

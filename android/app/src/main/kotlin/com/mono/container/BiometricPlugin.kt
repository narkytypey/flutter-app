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
 * `FlutterFragmentActivity`. */
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

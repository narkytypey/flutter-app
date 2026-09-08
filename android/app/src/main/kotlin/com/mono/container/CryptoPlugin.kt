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

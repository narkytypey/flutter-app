package com.mono.container

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.security.KeyPairGenerator
import java.security.spec.MGF1ParameterSpec
import javax.crypto.Cipher

/**
 * Android Keystore refuses to decrypt RSA-OAEP with an MGF1 digest the key
 * was not authorized for, and before API 35 a key can only be authorized for
 * MGF1 with SHA-1. MGF1 with SHA-256 made every biometric unwrap fail on a
 * device with `INCOMPATIBLE_MGF_DIGEST`, which the JVM cannot reproduce; the
 * parameters the Keystore is handed can be pinned here.
 */
class BiometricOaepTest {

    @Test fun `MGF1 uses SHA-1, the only MGF1 digest Keystore allows before API 35`() {
        val mgf = biometricOaepParams.mgfParameters as MGF1ParameterSpec
        assertEquals("MGF1", biometricOaepParams.mgfAlgorithm)
        assertEquals(MGF1ParameterSpec.SHA1.digestAlgorithm, mgf.digestAlgorithm)
    }

    @Test fun `the OAEP digest is SHA-256, the one the key authorizes`() {
        assertEquals("SHA-256", biometricOaepParams.digestAlgorithm)
    }

    @Test fun `a data key round-trips under these parameters`() {
        val pair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
        val dataKey = ByteArray(32) { it.toByte() }
        val encrypt = Cipher.getInstance("RSA/ECB/OAEPPadding")
            .apply { init(Cipher.ENCRYPT_MODE, pair.public, biometricOaepParams) }
        val decrypt = Cipher.getInstance("RSA/ECB/OAEPPadding")
            .apply { init(Cipher.DECRYPT_MODE, pair.private, biometricOaepParams) }
        assertArrayEquals(dataKey, decrypt.doFinal(encrypt.doFinal(dataKey)))
    }
}

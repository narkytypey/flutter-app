package com.mono.container

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * Both vaults used to share `container.biometric`, so turning biometrics off
 * in a decoy session deleted the real vault's key too. The Keystore itself
 * cannot run on the JVM; the alias mapping it is keyed by can.
 */
class BiometricAliasTest {

    @Test fun `each vault has its own alias`() {
        assertEquals("container.biometric.a", biometricAlias("a"))
        assertEquals("container.biometric.b", biometricAlias("b"))
        assertNotEquals(biometricAlias("a"), biometricAlias("b"))
    }

    @Test fun `neither vault maps to the old shared alias`() {
        assertNotEquals(LEGACY_BIOMETRIC_ALIAS, biometricAlias("a"))
        assertNotEquals(LEGACY_BIOMETRIC_ALIAS, biometricAlias("b"))
    }

    @Test fun `an unknown or missing vault is refused`() {
        for (vault in listOf(null, "", "c", "A", "a.b")) {
            assertThrows(IllegalArgumentException::class.java) { biometricAlias(vault) }
        }
    }

    @Test fun `panic deletes both vaults' keys and the old shared one`() {
        assertEquals(
            setOf("container.biometric", "container.biometric.a", "container.biometric.b"),
            allBiometricAliases.toSet(),
        )
    }
}

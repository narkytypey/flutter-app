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

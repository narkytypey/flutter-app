package com.mono.container

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `destroyDeviceKey` returns `Unit`, and `StandardMessageCodec` cannot encode
 * `kotlin.Unit`: replying with it threw on the main thread and killed the app
 * mid-panic, after the vault keys were gone but before `3c` or the biometric
 * key step. It went unnoticed because panic had never got that far before.
 */
class ChannelReplyTest {

    @Test fun `a method with nothing to return replies null, not Unit`() {
        assertNull(channelReply(Unit))
    }

    @Test fun `a real value passes through unchanged`() {
        val bytes = byteArrayOf(1, 2, 3)
        assertArrayEquals(bytes, channelReply(bytes) as ByteArray)
    }
}

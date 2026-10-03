package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Android's runtime permission dialog, asked only for what the app does not
 * hold yet, one request at a time; every waiter hears back once its
 * permissions have been asked, whatever the person chose.
 */
class PermissionAsksTest {

    private val held = mutableSetOf<String>()
    private val launched = mutableListOf<List<String>>()
    private val asks = PermissionAsks(held = { it in held }, launch = { launched += it.toList() })

    @Test fun `permissions already held answer at once, with no dialog`() {
        held += "CAMERA"
        var answered = 0
        asks.ask(listOf("CAMERA")) { answered++ }
        assertEquals(1, answered)
        assertEquals(emptyList<List<String>>(), launched)
    }

    @Test fun `nothing to ask answers at once`() {
        var answered = 0
        asks.ask(emptyList()) { answered++ }
        assertEquals(1, answered)
        assertEquals(emptyList<List<String>>(), launched)
    }

    @Test fun `a missing permission is asked, and the waiter answered on the result`() {
        var answered = 0
        asks.ask(listOf("CAMERA", "RECORD_AUDIO")) { answered++ }
        assertEquals(listOf(listOf("CAMERA", "RECORD_AUDIO")), launched)
        assertEquals(0, answered)
        held += "CAMERA"
        asks.onResult()
        assertEquals(1, answered)
    }

    @Test fun `a refusal still answers the waiter`() {
        var answered = 0
        asks.ask(listOf("CAMERA")) { answered++ }
        asks.onResult()
        assertEquals(1, answered)
        assertEquals(1, launched.size)
    }

    @Test fun `only the missing permissions are asked`() {
        held += "CAMERA"
        asks.ask(listOf("CAMERA", "RECORD_AUDIO")) {}
        assertEquals(listOf(listOf("RECORD_AUDIO")), launched)
    }

    @Test fun `an ask for what is already being asked waits for that dialog`() {
        var first = 0
        var second = 0
        asks.ask(listOf("CAMERA")) { first++ }
        asks.ask(listOf("CAMERA")) { second++ }
        assertEquals(1, launched.size)
        asks.onResult()
        assertEquals(1, first)
        assertEquals(1, second)
    }

    @Test fun `an ask for something else waits its turn, then gets its own dialog`() {
        var camera = 0
        var mic = 0
        asks.ask(listOf("CAMERA")) { camera++ }
        asks.ask(listOf("RECORD_AUDIO")) { mic++ }
        assertEquals(listOf(listOf("CAMERA")), launched)
        asks.onResult()
        assertEquals(1, camera)
        assertEquals(0, mic)
        assertEquals(listOf(listOf("CAMERA"), listOf("RECORD_AUDIO")), launched)
        asks.onResult()
        assertEquals(1, mic)
    }

    @Test fun `a later round asks again`() {
        asks.ask(listOf("CAMERA")) {}
        asks.onResult()
        asks.ask(listOf("CAMERA")) {}
        assertEquals(2, launched.size)
    }

    @Test fun `cancelled waiters are never answered`() {
        var answered = 0
        asks.ask(listOf("CAMERA")) { answered++ }
        asks.cancelAll()
        asks.onResult()
        assertEquals(0, answered)
    }
}

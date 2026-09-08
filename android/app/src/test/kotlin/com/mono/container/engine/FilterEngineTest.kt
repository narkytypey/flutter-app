package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FilterEngineTest {

    private val engine = FilterEngine(mapOf(
        "trackers" to listOf("||track.example.net^"),
        "ads" to listOf("||ads.example.com^"),
    ))

    @Test fun `a tracker host is blocked under the trackers category`() {
        assertEquals("trackers", engine.matches("https://track.example.net/pixel.gif"))
    }

    @Test fun `an ad host is blocked under the ads category`() {
        assertEquals("ads", engine.matches("https://ads.example.com/banner.js"))
    }

    @Test fun `an unlisted host is not blocked`() {
        assertNull(engine.matches("https://forum.example.com/thread"))
    }

    @Test fun `each category counts independently`() {
        engine.matches("https://track.example.net/a")
        engine.matches("https://track.example.net/b")
        engine.matches("https://ads.example.com/c")
        assertEquals(2, engine.countFor("trackers"))
        assertEquals(1, engine.countFor("ads"))
    }
}

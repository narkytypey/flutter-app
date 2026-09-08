package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FilterEngineTest {

    private val engine = FilterEngine(
        listOf("||ads.example.com^", "||track.example.net^", "!a comment", "")
    )

    @Test fun `a listed host is blocked`() {
        assertTrue(engine.matches("https://ads.example.com/banner.js"))
    }

    @Test fun `a subdomain of a listed host is blocked`() {
        assertTrue(engine.matches("https://cdn.ads.example.com/x.gif"))
    }

    @Test fun `an unlisted host is allowed`() {
        assertFalse(engine.matches("https://forum.example.com/thread"))
    }

    @Test fun `comments and blank lines are not rules`() {
        assertFalse(engine.matches("https://a-comment/"))
    }

    @Test fun `blocked requests are counted`() {
        engine.matches("https://ads.example.com/a")
        engine.matches("https://track.example.net/b")
        engine.matches("https://forum.example.com/c")
        assertEquals(2, engine.blockedCount)
    }
}

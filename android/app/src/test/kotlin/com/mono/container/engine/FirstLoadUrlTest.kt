package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** A typed address is only the first load; the stored one stays the site's identity. */
class FirstLoadUrlTest {

    @Test fun `a typed http or https address is loaded first`() {
        assertEquals("https://a.example/t/9", firstLoadUrl("https://a.example", "https://a.example/t/9"))
        assertEquals("http://a.example/", firstLoadUrl("https://a.example", "http://a.example/"))
    }

    @Test fun `no typed address loads the stored one`() {
        assertEquals("https://a.example", firstLoadUrl("https://a.example", null))
    }

    @Test fun `an address the guard refuses loads the stored one`() {
        val stored = "https://a.example"
        assertEquals(stored, firstLoadUrl(stored, "javascript:alert(1)"))
        assertEquals(stored, firstLoadUrl(stored, "file:///etc/hosts"))
        assertEquals(stored, firstLoadUrl(stored, " https://a.example"))
    }
}

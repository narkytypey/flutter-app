package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

class InjectedScriptsFromTest {

    @Test fun `reads each script in order`() {
        val scripts = injectedScriptsFrom(listOf(
            mapOf("kind" to "css", "code" to "a{}", "atDocumentStart" to true),
            mapOf("kind" to "js", "code" to "x()", "atDocumentStart" to false),
        ))
        assertEquals(listOf(
            InjectedScript("css", "a{}", true),
            InjectedScript("js", "x()", false),
        ), scripts)
    }

    @Test fun `absent means none, and a malformed entry is skipped`() {
        assertEquals(emptyList<InjectedScript>(), injectedScriptsFrom(null))
        assertEquals(
            listOf(InjectedScript("js", "ok()", false)),
            injectedScriptsFrom(listOf(mapOf("kind" to "css"), mapOf("kind" to "js", "code" to "ok()"))),
        )
    }
}

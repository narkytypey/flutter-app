package com.mono.container.engine

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReaderJsTest {

    // Removing the live page's styles left it unstyled after Reader closed (2026-10-09).
    @Test fun `reader strips a copy of the body, never the page`() {
        assertTrue(READER_JS.contains("var body = document.body.cloneNode(true);"))
        assertTrue(READER_JS.contains("body.querySelectorAll('script,style,noscript,template,nav,aside,footer').forEach(e=>e.remove());"))
        assertFalse(READER_JS.contains("document.querySelectorAll("))
        assertFalse(READER_JS.contains("document.body.querySelectorAll("))
    }

    @Test fun `reader picks its article from the copy`() {
        assertTrue(READER_JS.contains("var candidates = body.querySelectorAll('article,main,div,section');"))
    }
}

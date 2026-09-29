package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The held-download sheet showed "0 B" for a 190 KB PDF on the emulator.
 * Chromium reports an unknown length as 0, and on a proxied site WebView sizes
 * our intercepted response from `InputStream.available()`, so neither number
 * could be shown as it was.
 */
class DownloadSizeTest {

    @Test fun `a direct site's zero is unknown, not empty`() {
        assertNull(heldDownloadSize(proxied = false, listenerLength = 0, declared = null))
    }

    @Test fun `a direct site's real length is shown`() {
        assertEquals(194_560L, heldDownloadSize(proxied = false, listenerLength = 194_560, declared = null))
    }

    @Test fun `a proxied site ignores WebView's number and uses the declared one`() {
        assertEquals(194_560L, heldDownloadSize(proxied = true, listenerLength = 16_384, declared = 194_560))
    }

    @Test fun `a proxied site with no declared length is unknown`() {
        assertNull(heldDownloadSize(proxied = true, listenerLength = 16_384, declared = null))
    }

    @Test fun `a declared length is read whatever its header's case`() {
        assertEquals(1024L, declaredLength(mapOf("Content-Length" to "1024")))
        assertEquals(1024L, declaredLength(mapOf("content-length" to " 1024 ")))
        assertEquals(0L, declaredLength(mapOf("Content-Length" to "0")))
    }

    @Test fun `no usable Content-Length declares nothing`() {
        assertNull(declaredLength(emptyMap()))
        assertNull(declaredLength(mapOf("Content-Length" to "lots")))
        assertNull(declaredLength(mapOf("Content-Length" to "-1")))
    }

    @Test fun `Transfer-Encoding overrides Content-Length`() {
        assertNull(declaredLength(mapOf("Content-Length" to "1024", "Transfer-Encoding" to "chunked")))
    }

    @Test fun `an encoded body's Content-Length is not the file's size`() {
        assertNull(declaredLength(mapOf("Content-Length" to "1024", "Content-Encoding" to "gzip")))
        assertEquals(1024L, declaredLength(mapOf("Content-Length" to "1024", "Content-Encoding" to "identity")))
    }

    @Test fun `a recorded length is taken once`() {
        val lengths = DeclaredLengths()
        lengths.record("https://example.com/a.pdf", mapOf("Content-Length" to "194560"))

        assertEquals(194_560L, lengths.take("https://example.com/a.pdf"))
        assertNull(lengths.take("https://example.com/a.pdf"))
    }

    @Test fun `a later response without a length clears the earlier one`() {
        val lengths = DeclaredLengths()
        lengths.record("https://example.com/a.pdf", mapOf("Content-Length" to "194560"))
        lengths.record("https://example.com/a.pdf", mapOf("Transfer-Encoding" to "chunked"))

        assertNull(lengths.take("https://example.com/a.pdf"))
    }

    @Test fun `the oldest entries go once the record is full`() {
        val lengths = DeclaredLengths(capacity = 2)
        lengths.record("https://example.com/1", mapOf("Content-Length" to "1"))
        lengths.record("https://example.com/2", mapOf("Content-Length" to "2"))
        lengths.record("https://example.com/3", mapOf("Content-Length" to "3"))

        assertNull(lengths.take("https://example.com/1"))
        assertEquals(2L, lengths.take("https://example.com/2"))
        assertEquals(3L, lengths.take("https://example.com/3"))
    }
}

package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** The media type and charset a proxied response is handed to WebView with. */
class RequestInterceptorMediaTypeTest {

    @Test fun `reads a lowercase content-type header`() {
        assertEquals("text/html" to "utf-8", mediaTypeOf(mapOf("content-type" to "text/html")))
    }

    @Test fun `reads the charset parameter whatever its case`() {
        assertEquals("text/html" to "ISO-8859-1", mediaTypeOf(mapOf("Content-Type" to "text/html; Charset=ISO-8859-1")))
    }

    @Test fun `a quoted charset loses its quotes`() {
        assertEquals("text/html" to "utf-8", mediaTypeOf(mapOf("Content-Type" to "text/html; charset=\"utf-8\"")))
    }

    @Test fun `no content-type is an octet stream`() {
        assertEquals("application/octet-stream" to "utf-8", mediaTypeOf(emptyMap()))
    }
}

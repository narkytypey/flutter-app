package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Covers the split between [DownloadFetcher]'s Android-bound half (which
 * reads the user agent and the cookie jar off the platform) and the pure
 * half tested here, which decides what the download's GET actually says.
 *
 * The headers are the point: `saveViaDownloadManager` has always sent a
 * User-Agent and a Cookie, and the manual fetch path sent neither, so a
 * cookie-gated download succeeded via save-to-device and failed via
 * keep-in-container.
 */
class DownloadRequestTest {

    private val ua = "Mozilla/5.0 (Linux; Android 13) Chrome/126.0.0.0"

    @Test fun `sends the user agent it was given`() {
        val request = downloadRequest("https://example.com/a.pdf", ua, null)
        assertEquals(ua, request.headers["User-Agent"])
    }

    @Test fun `sends the cookies the page would have sent`() {
        val request = downloadRequest("https://example.com/a.pdf", ua, "session=abc; theme=dark")
        assertEquals("session=abc; theme=dark", request.headers["Cookie"])
    }

    @Test fun `omits Cookie entirely when the jar has nothing for this url`() {
        assertFalse(downloadRequest("https://example.com/a.pdf", ua, null).headers.containsKey("Cookie"))
        assertFalse(downloadRequest("https://example.com/a.pdf", ua, "").headers.containsKey("Cookie"))
    }

    @Test fun `defaults the port from the scheme`() {
        assertEquals(443, downloadRequest("https://example.com/a.pdf", ua, null).port)
        assertEquals(80, downloadRequest("http://example.com/a.pdf", ua, null).port)
        assertEquals(8443, downloadRequest("https://example.com:8443/a.pdf", ua, null).port)
    }

    @Test fun `marks only https as secure`() {
        assertTrue(downloadRequest("https://example.com/a.pdf", ua, null).secure)
        assertFalse(downloadRequest("http://example.com/a.pdf", ua, null).secure)
    }

    @Test fun `keeps the query string on the path`() {
        assertEquals("/d?id=7&token=x", downloadRequest("https://example.com/d?id=7&token=x", ua, null).path)
    }

    @Test fun `asks for the root of a bare host`() {
        assertEquals("/", downloadRequest("https://example.com", ua, null).path)
    }
}

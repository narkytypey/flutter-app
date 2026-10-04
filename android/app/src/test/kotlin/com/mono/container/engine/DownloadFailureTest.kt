package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DownloadFailureTest {
    private val proxied = Route.Proxy("127.0.0.1", 9050, socks = true)

    @Test fun `a rejected login names itself`() {
        assertEquals(RouteFailure.PROXY_LOGIN_REJECTED, downloadFailureFor(ProxyLoginRejectedException("x"), proxied))
    }

    /** Plan D8: an onion download on a direct route would send the name to DNS. */
    @Test fun `an onion download is refused on a direct route only`() {
        assertTrue(refusesOnionDownload(Route.Direct, "http://abc.onion/file.pdf"))
        assertTrue(refusesOnionDownload(Route.Direct, "https://ABC.ONION./file.pdf"))
        assertTrue(refusesOnionDownload(Route.Direct, "http://a_b.onion/file.pdf"))
        assertFalse(refusesOnionDownload(Route.Direct, "https://example.com/file.pdf"))
        assertFalse(refusesOnionDownload(Route.Tor("/s", ProxyLogin("u", "p")), "http://abc.onion/file.pdf"))
        assertFalse(refusesOnionDownload(Route.Proxy("127.0.0.1", 9050, socks = true), "http://abc.onion/file.pdf"))
    }

    @Test fun `the existing mapping is unchanged`() {
        assertEquals(RouteFailure.PROXY_REFUSED, downloadFailureFor(ProxyTunnelException(403, "x"), proxied))
        assertEquals(RouteFailure.UPSTREAM_TIMEOUT, downloadFailureFor(java.net.SocketTimeoutException("x"), proxied))
        assertEquals(RouteFailure.TLS_FAILURE, downloadFailureFor(javax.net.ssl.SSLException("x"), proxied))
        assertEquals(RouteFailure.PROXY_UNREACHABLE, downloadFailureFor(java.net.ConnectException("x"), proxied))
        assertEquals(RouteFailure.UPSTREAM_TIMEOUT, downloadFailureFor(java.net.ConnectException("x"), Route.Direct))
        assertNull(downloadFailureFor(IllegalStateException("x"), proxied))
    }
}

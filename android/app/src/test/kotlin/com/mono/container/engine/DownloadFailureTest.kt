package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DownloadFailureTest {
    private val proxied = Route.Proxy("127.0.0.1", 9050, socks = true)

    @Test fun `a rejected login names itself`() {
        assertEquals(RouteFailure.PROXY_LOGIN_REJECTED, downloadFailureFor(ProxyLoginRejectedException("x"), proxied))
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

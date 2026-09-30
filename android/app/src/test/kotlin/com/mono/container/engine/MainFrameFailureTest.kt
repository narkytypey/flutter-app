package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** P2 spec §3.3: Chromium does the TLS now, so a failed handshake reaches us as a WebView error code. */
class MainFrameFailureTest {

    @Test fun `a failed TLS handshake is a TLS failure`() {
        assertEquals(RouteFailure.TLS_FAILURE, mainFrameFailure(-11)) // WebViewClient.ERROR_FAILED_SSL_HANDSHAKE
    }

    @Test fun `every other error is left to WebView's own error page`() {
        for (code in listOf(-1, -2, -5, -6, -8, -12)) { // UNKNOWN, HOST_LOOKUP, PROXY_AUTHENTICATION, CONNECT, TIMEOUT, BAD_URL
            assertNull(mainFrameFailure(code))
        }
    }
}

package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Found on a device: WebView's own Autofill sends every form it sees to
 * content-autofill.googleapis.com from the browser process, where no site's
 * interceptor can see it, so on a proxied site it went direct. There is no
 * WebView setting to turn it off. The proxy override sends that one host to a
 * proxy that cannot answer, and nothing else anywhere near it.
 */
class AutofillBlockTest {

    private val config = autofillBlockConfig()

    /**
     * With reverse bypass the bypass list is the list of hosts that use the
     * proxy. `<-loopback>` is how Chromium spells "no implicit rules", which
     * keeps localhost off that list.
     */
    @Test fun `only the autofill host is sent to the override proxy`() {
        assertTrue(config.isReverseBypassEnabled)
        assertEquals(listOf("content-autofill.googleapis.com", "<-loopback>"), config.bypassRules)
    }

    /** No app can bind a port below 1024, so nothing can ever answer there. */
    @Test fun `the override proxy is a loopback port no app can listen on`() {
        assertEquals(listOf("127.0.0.1:1"), config.proxyRules.map { it.url })
    }

    /** A DIRECT rule would let Chromium fall back to going direct once the proxy fails. */
    @Test fun `there is no direct fallback`() {
        assertTrue(config.proxyRules.none { it.url.startsWith("direct", ignoreCase = true) })
    }
}

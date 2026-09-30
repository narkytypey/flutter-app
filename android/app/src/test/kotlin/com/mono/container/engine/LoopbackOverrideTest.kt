package com.mono.container.engine

import androidx.webkit.ProxyConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P2 spec §1.3: one process-wide override sends every scheme of every site to
 * the loopback proxy, localhost included, with nothing to fall back to.
 */
class LoopbackOverrideTest {

    private val config = loopbackProxyConfig(4321)

    @Test fun `every scheme goes to the loopback proxy`() {
        assertEquals(listOf("http://127.0.0.1:4321"), config.proxyRules.map { it.url })
        assertEquals(listOf(ProxyConfig.MATCH_ALL_SCHEMES), config.proxyRules.map { it.schemeFilter })
    }

    /** `<-loopback>` is how Chromium spells "no implicit rules": localhost is not bypassed. */
    @Test fun `localhost and loopback addresses go through it too`() {
        assertEquals(listOf("<-loopback>"), config.bypassRules)
        assertFalse(config.isReverseBypassEnabled)
    }

    /** A DIRECT rule would let Chromium go direct once the loopback proxy fails. */
    @Test fun `there is no direct fallback`() {
        assertTrue(config.proxyRules.none { it.url.startsWith("direct", ignoreCase = true) })
    }
}

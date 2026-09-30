package com.mono.container.engine

import androidx.webkit.ProxyConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

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

    /** Design question 1 (user's ruling, 2026-09-30): an open waits until WebView says the override is in force. */
    @Test fun `waiting for the override returns only once its listener has run`() {
        val applied = OverrideApplied()
        val returned = CountDownLatch(1)
        Thread { applied.await(); returned.countDown() }.apply { isDaemon = true }.start()
        assertFalse(returned.await(200, TimeUnit.MILLISECONDS))
        assertFalse(applied.isApplied)
        applied.markApplied()
        assertTrue(returned.await(5, TimeUnit.SECONDS))
        assertTrue(applied.isApplied)
    }

    @Test fun `once applied, waiting returns at once`() {
        val applied = OverrideApplied()
        applied.markApplied()
        val returned = CountDownLatch(1)
        Thread { applied.await(); returned.countDown() }.apply { isDaemon = true }.start()
        assertTrue(returned.await(1, TimeUnit.SECONDS))
    }
}

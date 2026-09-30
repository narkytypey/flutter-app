package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * What the interceptor does with one request, decided before any Android type
 * is built. Since P2 (spec §1.4) Chromium fetches everything else itself,
 * through the loopback proxy, which routes it by site.
 */
class DispositionTest {

    /**
     * Found on a device: a page's pagehide `sendBeacon` and keepalive `fetch`
     * went direct when its WebView was destroyed. A closing view refuses
     * everything, so nothing from a closing page reaches even the loopback
     * proxy, and decides that without consulting the filter list.
     */
    @Test fun `a closing view refuses every request without consulting the filter list`() {
        var asked = false
        assertEquals(Disposition.Closed, dispositionFor(closing = true, blockedByFilter = { asked = true; true }))
        assertEquals(false, asked)
    }

    @Test fun `an open view blocks what a filter list matches`() {
        assertEquals(Disposition.Blocked, dispositionFor(closing = false, blockedByFilter = { true }))
    }

    @Test fun `everything else is Chromium's to fetch, through the loopback proxy`() {
        assertEquals(Disposition.ByWebView, dispositionFor(closing = false, blockedByFilter = { false }))
    }
}

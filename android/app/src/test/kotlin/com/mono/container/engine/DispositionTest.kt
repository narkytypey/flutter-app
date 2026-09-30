package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** What the interceptor does with one request, decided before any Android type is built. */
class DispositionTest {

    private val proxy = Route.Proxy("10.0.2.2", 1080, socks = true)

    /**
     * Found on a device: a page's pagehide `sendBeacon` and keepalive `fetch`
     * went direct when its WebView was destroyed, because destroy() had
     * already dropped the view's interception hook. A closing view now
     * refuses everything, and must decide that without probing the route
     * (that is network I/O) or consulting the filter list.
     */
    @Test fun `a closing view refuses every request without asking for a route`() {
        var asked = false
        val disposition = dispositionFor(
            closing = true,
            blockedByFilter = { asked = true; false },
            route = { asked = true; Route.Direct },
        )
        assertEquals(Disposition.Closed, disposition)
        assertEquals(false, asked)
    }

    @Test fun `a closing view refuses even what a direct route would fetch`() {
        assertEquals(Disposition.Closed, dispositionFor(closing = true, blockedByFilter = { false }, route = { Route.Direct }))
    }

    @Test fun `an open view blocks what a filter list matches`() {
        assertEquals(Disposition.Blocked, dispositionFor(closing = false, blockedByFilter = { true }, route = { proxy }))
    }

    @Test fun `an open view on a direct route lets WebView fetch`() {
        assertEquals(Disposition.ByWebView, dispositionFor(closing = false, blockedByFilter = { false }, route = { Route.Direct }))
    }

    @Test fun `an open view on a proxy fetches through it`() {
        assertEquals(Disposition.Through(proxy), dispositionFor(closing = false, blockedByFilter = { false }, route = { proxy }))
    }

    @Test fun `an open view on a refused route is refused with its failure`() {
        val route = Route.Refused(RouteFailure.PROXY_UNREACHABLE)
        assertEquals(
            Disposition.Refused(RouteFailure.PROXY_UNREACHABLE),
            dispositionFor(closing = false, blockedByFilter = { false }, route = { route }),
        )
    }
}

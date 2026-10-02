package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** Proxy-auth spec §3, ruling 6: what a route refusal does, by the phase of the session it reached. */
class RouteRefusalTest {
    @Test fun `an opening session is refused, a live one hears tunnel_dropped, any other ignores it`() {
        assertEquals(RefusalAction.REFUSE_SESSION, refusalActionFor(Session.PHASE_OPENING))
        assertEquals(RefusalAction.TUNNEL_DROPPED, refusalActionFor(Session.PHASE_LIVE))
        assertEquals(RefusalAction.IGNORE, refusalActionFor(Session.PHASE_BACKGROUND))
        assertEquals(RefusalAction.IGNORE, refusalActionFor(Session.PHASE_REFUSED))
    }

    /** Spec §3: route-wide for a proxied route only; every other upstream failure stays unreported (P2 plan deviation 1). */
    @Test fun `only a rejected login on a proxied route is reported`() {
        val proxied = Route.Proxy("127.0.0.1", 9050, socks = true)
        assertEquals(RouteFailure.PROXY_LOGIN_REJECTED, reportedUpstreamFailure(ProxyLoginRejectedException("x"), proxied))
        assertEquals(null, reportedUpstreamFailure(ProxyLoginRejectedException("x"), Route.Direct))
        assertEquals(null, reportedUpstreamFailure(ProxyTunnelException(5, "x"), proxied))
        assertEquals(null, reportedUpstreamFailure(java.net.SocketTimeoutException("x"), proxied))
    }
}

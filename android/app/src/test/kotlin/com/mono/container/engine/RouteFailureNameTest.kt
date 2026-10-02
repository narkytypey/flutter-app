package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** `routeFailureToDartName` falls back to `misconfigured`, so a kind it forgets is silently mislabelled. */
class RouteFailureNameTest {
    @Test fun `every failure crosses the channel under its own Dart name`() {
        assertEquals(
            mapOf(
                "PROXY_UNREACHABLE" to "proxyUnreachable",
                "PROXY_REFUSED" to "proxyRefused",
                "UPSTREAM_TIMEOUT" to "upstreamTimeout",
                "TLS_FAILURE" to "tlsFailure",
                "MISCONFIGURED" to "misconfigured",
                "UNSUPPORTED" to "unsupported",
                "PROXY_LOGIN_REJECTED" to "proxyLoginRejected",
            ),
            RouteFailure.values().associate { it.name to routeFailureToDartName(it.name) },
        )
    }
}

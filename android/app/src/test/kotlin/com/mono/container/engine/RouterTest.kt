package com.mono.container.engine

import org.junit.Assert.assertTrue
import org.junit.Test

class RouterTest {

    private fun config(mode: String = "socks5", host: String? = "127.0.0.1", port: Int? = 9050) =
        SiteConfig(
            siteId = "s", profileId = "a".repeat(32), url = "https://forum.example.com",
            proxyMode = mode, proxyHost = host, proxyPort = port,
            blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
            allowCamera = false, allowMicrophone = false, allowLocation = false,
            allowClipboard = false, userAgentMode = "android", forceDark = true,
            pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
        )

    @Test fun `direct site routes direct`() {
        assertTrue(Router.resolve(config(mode = "direct"), proxyReachable = false) is Route.Direct)
    }

    @Test fun `proxied site with reachable proxy routes through it`() {
        assertTrue(Router.resolve(config(), proxyReachable = true) is Route.Proxy)
    }

    @Test fun `proxied site with unreachable proxy refuses and never goes direct`() {
        val route = Router.resolve(config(), proxyReachable = false)
        assertTrue(route is Route.Refused)
        assertTrue((route as Route.Refused).failure == RouteFailure.PROXY_UNREACHABLE)
    }

    @Test fun `proxied site with no host is misconfigured`() {
        val route = Router.resolve(config(host = null), proxyReachable = true)
        assertTrue((route as Route.Refused).failure == RouteFailure.MISCONFIGURED)
    }
}

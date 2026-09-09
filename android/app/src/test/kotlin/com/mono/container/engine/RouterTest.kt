package com.mono.container.engine

import org.junit.Assert.assertEquals
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

    /**
     * Proves an `http` route reaches the destination through a CONNECT tunnel.
     *
     * The assertion is on the request line, not merely on connecting, because
     * this test runs on a desktop JVM where `java.net.Socket` still honours
     * `Proxy.Type.HTTP` — the removal this tunnel exists to work around is
     * Android's alone, so a JVM test can never reproduce the
     * `IllegalArgumentException("Invalid Proxy")` a device throws. What it can
     * reproduce is the behaviour the old path got wrong even where it worked:
     * the JDK resolves the target itself and sends `CONNECT <ip>:443`, leaking
     * a local DNS lookup and hiding the hostname from the proxy.
     * [HttpConnectTunnel] sends the authority verbatim and resolves nothing.
     */
    @Test fun `an http-proxied route opens a CONNECT tunnel to the target authority`() {
        val proxy = java.net.ServerSocket(0)
        val requestLines = java.util.concurrent.ArrayBlockingQueue<String>(1)
        Thread {
            runCatching {
                proxy.accept().use { client ->
                    val input = client.getInputStream()
                    val builder = StringBuilder()
                    while (true) {
                        val byte = input.read()
                        if (byte == -1 || byte == '\n'.code) break
                        if (byte != '\r'.code) builder.append(byte.toChar())
                    }
                    while (true) {
                        val line = StringBuilder()
                        while (true) {
                            val byte = input.read()
                            if (byte == -1 || byte == '\n'.code) break
                            if (byte != '\r'.code) line.append(byte.toChar())
                        }
                        if (line.isEmpty()) break
                    }
                    requestLines.offer(builder.toString())
                    client.getOutputStream().write(
                        "HTTP/1.1 200 Connection established\r\n\r\n".toByteArray(Charsets.US_ASCII)
                    )
                    client.getOutputStream().flush()
                }
            }
        }.apply { isDaemon = true }.start()

        val route = Route.Proxy("127.0.0.1", proxy.localPort, socks = false)
        Router.connect(route, "example.com", 443).use { socket ->
            assertTrue(socket.isConnected)
        }
        assertEquals(
            "CONNECT example.com:443 HTTP/1.1",
            requestLines.poll(5, java.util.concurrent.TimeUnit.SECONDS),
        )
        proxy.close()
    }
}

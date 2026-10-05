package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
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

    @Test fun `a tor site routes to Tor's socket with its own login, whatever was typed`() {
        val site = config(mode = "tor", host = null, port = null)
            .copy(proxyLogin = ProxyLogin("typed", "pw"), proxyLoginPerSite = false)
        val route = Router.resolve(site, proxyReachable = true, torSocket = "/data/files/tor/socks:0")
        assertEquals(Route.Tor("/data/files/tor/socks:0", perSiteLogin(site.profileId)), route)
    }

    /** Review Focus 3. */
    @Test fun `a tor site with Tor not ready is refused, never direct`() {
        val route = Router.resolve(config(mode = "tor", host = null, port = null), proxyReachable = false, torSocket = "/s")
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), route)
    }

    @Test fun `a tor site with no socket is refused`() {
        val route = Router.resolve(config(mode = "tor", host = null, port = null), proxyReachable = true, torSocket = null)
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), route)
    }

    @Test fun `a tor route connects through the local socket and names the target to Tor`() {
        val server = java.net.ServerSocket(0)
        val hosts = java.util.concurrent.ArrayBlockingQueue<String>(1)
        Thread {
            runCatching {
                server.accept().use { client ->
                    val input = java.io.DataInputStream(client.getInputStream())
                    val out = client.getOutputStream()
                    input.readFully(ByteArray(3))
                    out.write(byteArrayOf(5, 2))
                    input.readUnsignedByte()
                    input.readFully(ByteArray(input.readUnsignedByte()))
                    input.readFully(ByteArray(input.readUnsignedByte()))
                    out.write(byteArrayOf(1, 0))
                    input.readFully(ByteArray(4))
                    hosts += String(ByteArray(input.readUnsignedByte()).also(input::readFully))
                    input.readFully(ByteArray(2))
                    out.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0))
                    out.flush()
                }
            }
        }.start()
        val paths = mutableListOf<String>()

        val socket = Router.connect(
            Route.Tor("/data/files/tor/socks:0", ProxyLogin("u", "p")), "abc.onion", 443,
            local = { path ->
                paths += path
                java.net.Socket("127.0.0.1", server.localPort)
            },
        )

        assertEquals(listOf("/data/files/tor/socks:0"), paths)
        assertEquals("abc.onion", hosts.poll(5, java.util.concurrent.TimeUnit.SECONDS))
        socket.close()
        server.close()
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

    /**
     * A SOCKS5 route hands the proxy the hostname (address type 3), never an
     * address resolved on the device. A resolved `InetSocketAddress` makes the
     * platform send address type 1 or 4, after a DNS lookup of its own — the
     * leak this pins. The target is `localhost` because it always resolves on
     * the device: a name that fails to resolve silently becomes an unresolved
     * address, which would hide the bug.
     */
    @Test fun `a socks5 route sends the target hostname to the proxy unresolved`() {
        val proxy = java.net.ServerSocket(0)
        val requests = java.util.concurrent.ArrayBlockingQueue<String>(1)
        Thread {
            runCatching {
                proxy.accept().use { client ->
                    val input = java.io.DataInputStream(client.getInputStream())
                    val out = client.getOutputStream()
                    input.readUnsignedByte()                       // version
                    repeat(input.readUnsignedByte()) { input.readUnsignedByte() }
                    out.write(byteArrayOf(5, 0)); out.flush()      // no auth
                    input.readUnsignedByte(); input.readUnsignedByte(); input.readUnsignedByte()
                    val addressType = input.readUnsignedByte()
                    val host = when (addressType) {
                        3 -> String(ByteArray(input.readUnsignedByte()).also { input.readFully(it) }, Charsets.US_ASCII)
                        1 -> ByteArray(4).also { input.readFully(it) }.joinToString(".") { (it.toInt() and 0xff).toString() }
                        else -> ByteArray(16).also { input.readFully(it) }.toString()
                    }
                    val port = input.readUnsignedShort()
                    requests.offer("$addressType $host:$port")
                    out.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0)); out.flush()
                }
            }
        }.apply { isDaemon = true }.start()

        val route = Route.Proxy("127.0.0.1", proxy.localPort, socks = true)
        Router.connect(route, "localhost", 443).use { socket ->
            assertTrue(socket.isConnected)
        }
        assertEquals("3 localhost:443", requests.poll(5, java.util.concurrent.TimeUnit.SECONDS))
        proxy.close()
    }

    @Test fun `a direct site opens without a proxy override`() {
        assertEquals(Route.Direct, routeAtOpen(config(mode = "direct"), proxyOverride = false, awaitOverride = { fail("waited") }) { Route.Direct })
    }

    /** P2 spec §1.4: refused, never sent direct, and not even probed. */
    @Test fun `a proxied site is refused when WebView cannot override its proxy`() {
        for (mode in listOf("socks5", "http")) {
            var probed = false
            val route = routeAtOpen(config(mode = mode), proxyOverride = false, awaitOverride = { fail("waited") }) { probed = true; Route.Direct }
            assertEquals(Route.Refused(RouteFailure.UNSUPPORTED), route)
            assertFalse(probed)
        }
    }

    @Test fun `with the override a proxied site is resolved as before`() {
        val proxied = Route.Proxy("127.0.0.1", 9050, socks = true)
        assertEquals(proxied, routeAtOpen(config(), proxyOverride = true, awaitOverride = {}) { proxied })
    }

    /**
     * Design question 1 (user's ruling, 2026-09-30): WebView applies the
     * override asynchronously, and until it has, a request goes direct. Every
     * site's open, direct ones too (Autofill is blocked only by the override),
     * waits for it before its route is decided, so no site's view exists
     * before the override is in force.
     */
    @Test fun `with the override every site waits for it to apply before its route is decided`() {
        for (mode in listOf("direct", "socks5", "http")) {
            val steps = mutableListOf<String>()
            routeAtOpen(config(mode = mode), proxyOverride = true, awaitOverride = { steps += "await" }) {
                steps += "resolve"; Route.Direct
            }
            assertEquals(listOf("await", "resolve"), steps)
        }
    }

    // --- Design question 2: a direct route honours the system proxy ----------

    /** An HTTP proxy on localhost that records one request line, answers 200 and holds the tunnel. */
    private fun fakeHttpProxy(requestLines: java.util.concurrent.BlockingQueue<String>): java.net.ServerSocket {
        val proxy = java.net.ServerSocket(0)
        Thread {
            runCatching {
                proxy.accept().use { client ->
                    requestLines.offer(readHead(client.getInputStream())!!.first())
                    client.getOutputStream().write("HTTP/1.1 200 Connection established\r\n\r\n".toByteArray(Charsets.US_ASCII))
                    client.getOutputStream().flush()
                    client.getInputStream().read()
                }
            }
        }.apply { isDaemon = true }.start()
        return proxy
    }

    /** User's ruling, 2026-09-30: on a network whose Wi-Fi sets a proxy, direct sites go through it, as they did before the override. */
    @Test fun `a direct route tunnels through the system proxy to the target authority`() {
        val requestLines = java.util.concurrent.ArrayBlockingQueue<String>(1)
        fakeHttpProxy(requestLines).use { proxy ->
            Router.connect(Route.Direct, "example.test", 443) { SystemProxy("127.0.0.1", proxy.localPort) }.use { socket ->
                assertTrue(socket.isConnected)
            }
            assertEquals("CONNECT example.test:443 HTTP/1.1", requestLines.poll(5, java.util.concurrent.TimeUnit.SECONDS))
        }
    }

    @Test fun `a direct route to an excluded host connects straight, past the system proxy`() {
        java.net.ServerSocket(0).use { target ->
            // Nothing listens on the "proxy": going through it would fail.
            val closedPort = java.net.ServerSocket(0).use { it.localPort }
            val proxy = SystemProxy("127.0.0.1", closedPort, exclusions = listOf("localhost"))
            Router.connect(Route.Direct, "localhost", target.localPort) { proxy }.use { socket ->
                assertEquals(target.localPort, socket.port)
            }
        }
    }

    @Test fun `with no system proxy a direct route connects straight`() {
        java.net.ServerSocket(0).use { target ->
            Router.connect(Route.Direct, "localhost", target.localPort) { null }.use { socket ->
                assertEquals(target.localPort, socket.port)
            }
        }
    }

    /** The system proxy is for direct sites only: a proxied site reaches its own proxy as before. */
    @Test fun `a proxied route ignores the system proxy`() {
        val systemLines = java.util.concurrent.ArrayBlockingQueue<String>(1)
        val siteLines = java.util.concurrent.ArrayBlockingQueue<String>(1)
        fakeHttpProxy(systemLines).use { system ->
            fakeHttpProxy(siteLines).use { site ->
                Router.connect(Route.Proxy("127.0.0.1", site.localPort, socks = false), "example.test", 443) {
                    SystemProxy("127.0.0.1", system.localPort)
                }.use { assertTrue(it.isConnected) }
                assertEquals("CONNECT example.test:443 HTTP/1.1", siteLines.poll(5, java.util.concurrent.TimeUnit.SECONDS))
                assertNull(systemLines.poll(200, java.util.concurrent.TimeUnit.MILLISECONDS))
            }
        }
    }

    @Test fun `a proxied route carries the site's login`() {
        val typed = ProxyLogin("alice", "s3cret")
        for (mode in listOf("socks5", "http")) {
            val route = Router.resolve(config(mode = mode).copy(proxyLogin = typed), proxyReachable = true) as Route.Proxy
            assertEquals(typed, route.login)
        }
    }

    /** Ruling 7: the automatic login applies to HTTP proxies as well as SOCKS5. */
    @Test fun `a per-site route carries the login derived from its profile`() {
        for (mode in listOf("socks5", "http")) {
            val route = Router.resolve(config(mode = mode).copy(proxyLoginPerSite = true), proxyReachable = true) as Route.Proxy
            assertEquals(perSiteLogin("a".repeat(32)), route.login)
        }
    }

    @Test fun `a proxied route with no login carries none`() {
        assertNull((Router.resolve(config(), proxyReachable = true) as Route.Proxy).login)
    }

    /** Spec §2.1: a direct route never carries a login. */
    @Test fun `a direct site with a login still routes direct`() {
        val config = config(mode = "direct").copy(proxyLogin = ProxyLogin("alice", "s3cret"), proxyLoginPerSite = true)
        assertEquals(Route.Direct, Router.resolve(config, proxyReachable = true))
    }

    @Test fun `currentRoute never probes for a direct site, even with a leftover proxy`() {
        val probed = mutableListOf<String>()
        val route = config(mode = "direct", host = "10.0.2.2", port = 8888)
            .currentRoute { host, port -> probed += "$host:$port"; true }
        assertEquals(Route.Direct, route)
        assertTrue(probed.isEmpty())
    }

    @Test fun `currentRoute never probes for an unknown mode, and refuses it`() {
        val probed = mutableListOf<String>()
        val route = config(mode = "ftp").currentRoute { host, port -> probed += "$host:$port"; true }
        assertEquals(Route.Refused(RouteFailure.MISCONFIGURED), route)
        assertTrue(probed.isEmpty())
    }

    @Test fun `currentRoute probes the proxy of a socks5 or http site`() {
        for (mode in listOf("socks5", "http")) {
            val probed = mutableListOf<String>()
            val reachable = config(mode = mode).currentRoute { host, port -> probed += "$host:$port"; true }
            assertTrue(reachable is Route.Proxy)
            assertEquals(listOf("127.0.0.1:9050"), probed)
            assertEquals(Route.Refused(RouteFailure.PROXY_UNREACHABLE), config(mode = mode).currentRoute { _, _ -> false })
        }
    }
}

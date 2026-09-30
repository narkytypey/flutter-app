package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.DataInputStream
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.Base64
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Callable
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * P2 spec §7: the loopback proxy against fake upstream servers on localhost.
 * Destinations are `localhost`, not `127.0.0.1`, which the proxy refuses (plan
 * deviation 2).
 */
class LoopbackProxyTest {

    private fun config(profileId: String, mode: String = "direct", host: String? = null, port: Int? = null) = SiteConfig(
        siteId = "site-$profileId", profileId = profileId, url = "https://forum.example.com",
        proxyMode = mode, proxyHost = host, proxyPort = port,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    /** Routes every config as its own settings say, with the proxy taken as reachable. */
    private val bySettings: (SiteConfig) -> Route = { Router.resolve(it, proxyReachable = true) }

    private fun auth(credential: ProxyCredential) =
        "Proxy-Authorization: Basic " +
            Base64.getEncoder().encodeToString("${credential.user}:${credential.password}".toByteArray()) + "\r\n"

    private fun send(proxy: LoopbackProxy, head: String): Socket =
        Socket("127.0.0.1", proxy.port).apply {
            soTimeout = 5_000
            getOutputStream().write(head.toByteArray(Charsets.ISO_8859_1))
            getOutputStream().flush()
        }

    private fun responseHead(socket: Socket): List<String> = readHead(socket.getInputStream())!!

    private fun statusOf(socket: Socket): Int = responseHead(socket).first().split(' ')[1].toInt()

    /** True once the proxy has closed [socket]; false when it is still open after its read timeout. */
    private fun closedByProxy(socket: Socket): Boolean =
        runCatching { socket.getInputStream().read() == -1 }.getOrElse { it !is SocketTimeoutException }

    private fun ping(socket: Socket, byte: Int = 'p'.code) {
        socket.getOutputStream().write(byte)
        socket.getOutputStream().flush()
        assertEquals(byte, socket.getInputStream().read())
    }

    /** Echoes every byte of every connection, counting connections, bytes and ends. */
    private class EchoServer : AutoCloseable {
        val server = ServerSocket(0)
        val accepted = AtomicInteger()
        val received = AtomicInteger()
        val ended = CountDownLatch(1)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    while (true) {
                        val socket = server.accept()
                        accepted.incrementAndGet()
                        Thread {
                            runCatching {
                                socket.use {
                                    while (true) {
                                        val byte = socket.getInputStream().read()
                                        if (byte == -1) break
                                        received.incrementAndGet()
                                        socket.getOutputStream().write(byte)
                                        socket.getOutputStream().flush()
                                    }
                                }
                            }
                            ended.countDown()
                        }.apply { isDaemon = true }.start()
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    /** A SOCKS5 server that records `<address type> <host>:<port>` and reports success. */
    private class FakeSocks : AutoCloseable {
        val server = ServerSocket(0)
        val requests = ArrayBlockingQueue<String>(4)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    while (true) {
                        val client = server.accept()
                        runCatching {
                            val input = DataInputStream(client.getInputStream())
                            val out = client.getOutputStream()
                            input.readUnsignedByte()
                            repeat(input.readUnsignedByte()) { input.readUnsignedByte() }
                            out.write(byteArrayOf(5, 0)); out.flush()
                            input.readUnsignedByte(); input.readUnsignedByte(); input.readUnsignedByte()
                            val type = input.readUnsignedByte()
                            val host = when (type) {
                                3 -> String(ByteArray(input.readUnsignedByte()).also { input.readFully(it) }, Charsets.US_ASCII)
                                1 -> ByteArray(4).also { input.readFully(it) }.joinToString(".") { (it.toInt() and 0xff).toString() }
                                else -> "v6"
                            }
                            requests.offer("$type $host:${input.readUnsignedShort()}")
                            out.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0)); out.flush()
                            input.read()
                        }
                        runCatching { client.close() }
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    /** An HTTP proxy that records its request line, answers 200, and holds the tunnel. */
    private class FakeHttpProxy : AutoCloseable {
        val server = ServerSocket(0)
        val requestLines = ArrayBlockingQueue<String>(1)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    server.accept().use { client ->
                        requestLines.offer(readHead(client.getInputStream())!!.first())
                        client.getOutputStream().write("HTTP/1.1 200 Connection established\r\n\r\n".toByteArray())
                        client.getOutputStream().flush()
                        client.getInputStream().read()
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    /**
     * An origin server that records one request's head and body, answers
     * [response], then keeps its side open, as a server that ignores
     * `Connection: close` would, until the client goes.
     */
    private class FakeOrigin(private val response: String) : AutoCloseable {
        val server = ServerSocket(0)
        val heads = ArrayBlockingQueue<List<String>>(1)
        val bodies = ArrayBlockingQueue<String>(1)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    server.accept().use { socket ->
                        val input = socket.getInputStream()
                        val head = readHead(input)!!
                        val length = head.firstOrNull { it.startsWith("Content-Length:", ignoreCase = true) }
                            ?.substringAfter(':')?.trim()?.toInt() ?: 0
                        val body = ByteArray(length).also { DataInputStream(input).readFully(it) }
                        heads.offer(head)
                        bodies.offer(String(body, Charsets.ISO_8859_1))
                        socket.getOutputStream().write(response.toByteArray(Charsets.ISO_8859_1))
                        socket.getOutputStream().flush()
                        input.read()
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    @Test fun `the listener is bound to 127_0_0_1 only`() {
        LoopbackProxy(SiteCredentials(), bySettings).start().use { proxy ->
            assertEquals("127.0.0.1", proxy.address.hostAddress)
            assertTrue(proxy.port > 0)
        }
    }

    @Test fun `no credentials get a 407 with the app's realm, and nothing is forwarded`() {
        EchoServer().use { echo ->
            LoopbackProxy(SiteCredentials(), bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n\r\n").use { socket ->
                    val head = responseHead(socket)
                    assertEquals("HTTP/1.1 407 Proxy Authentication Required", head.first())
                    assertTrue("Proxy-Authenticate: Basic realm=\"container\"" in head)
                }
                assertEquals(0, echo.accepted.get())
            }
        }
    }

    @Test fun `a wrong credential gets 403 and the connection is closed`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        LoopbackProxy(credentials, bySettings).start().use { proxy ->
            val fake = Base64.getEncoder().encodeToString("${"0".repeat(32)}:${"0".repeat(32)}".toByteArray())
            send(proxy, "CONNECT localhost:443 HTTP/1.1\r\nProxy-Authorization: Basic $fake\r\n\r\n").use { socket ->
                assertEquals(403, statusOf(socket))
                assertEquals(-1, socket.getInputStream().read())
            }
        }
    }

    @Test fun `a closed session's credential gets 403`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        val credential = credentials.credentialFor("p1")
        credentials.unbind("p1")
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credential)}\r\n").use { socket ->
                    assertEquals(403, statusOf(socket))
                }
                assertEquals(0, echo.accepted.get())
            }
        }
    }

    @Test fun `the Autofill host is refused with valid credentials, and no route is asked for`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        var asked = false
        LoopbackProxy(credentials, resolve = { asked = true; Route.Direct }).start().use { proxy ->
            send(proxy, "CONNECT content-autofill.googleapis.com:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(403, statusOf(socket))
            }
        }
        assertFalse(asked)
    }

    /** Review Focus 3. */
    @Test fun `garbage gets 400 and nothing is forwarded`() {
        EchoServer().use { echo ->
            LoopbackProxy(SiteCredentials(), bySettings).start().use { proxy ->
                send(proxy, "HELLO\r\n\r\n").use { socket -> assertEquals(400, statusOf(socket)) }
                assertEquals(0, echo.accepted.get())
            }
        }
    }

    @Test fun `a direct site's CONNECT answers 200 and relays both ways`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals("HTTP/1.1 200 Connection Established", responseHead(socket).first())
                    ping(socket)
                }
            }
        }
    }

    @Test fun `closing the page's side ends the upstream side`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                val socket = send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n")
                assertEquals(200, statusOf(socket))
                ping(socket)
                socket.close()
                assertTrue(echo.ended.await(5, TimeUnit.SECONDS))
            }
        }
    }

    @Test fun `the upstream closing ends the page's side`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        ServerSocket(0).use { upstream ->
            Thread { runCatching { upstream.accept().close() } }.apply { isDaemon = true }.start()
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${upstream.localPort} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                    assertEquals(-1, socket.getInputStream().read())
                }
            }
        }
    }

    @Test fun `each credential is routed by its own site`() {
        FakeSocks().use { socks ->
            EchoServer().use { echo ->
                val credentials = SiteCredentials()
                credentials.bind("direct", ProxyBinding(config("direct")) {})
                credentials.bind("socks", ProxyBinding(config("socks", mode = "socks5", host = "127.0.0.1", port = socks.port)) {})
                LoopbackProxy(credentials, bySettings).start().use { proxy ->
                    send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("socks"))}\r\n").use { socket ->
                        assertEquals(200, statusOf(socket))
                    }
                    // Address type 3: the SOCKS proxy got the hostname, and the device looked nothing up.
                    assertEquals("3 example.test:443", socks.requests.poll(5, TimeUnit.SECONDS))

                    send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("direct"))}\r\n").use { socket ->
                        assertEquals(200, statusOf(socket))
                        ping(socket)
                    }
                    assertEquals(1, echo.accepted.get())
                    assertNull(socks.requests.poll(200, TimeUnit.MILLISECONDS))
                }
            }
        }
    }

    @Test fun `an http proxy site is tunnelled with CONNECT to the target authority`() {
        FakeHttpProxy().use { upstream ->
            val credentials = SiteCredentials()
            credentials.bind("p1", ProxyBinding(config("p1", mode = "http", host = "127.0.0.1", port = upstream.port)) {})
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                }
                assertEquals("CONNECT example.test:443 HTTP/1.1", upstream.requestLines.poll(5, TimeUnit.SECONDS))
            }
        }
    }

    @Test fun `a refused route answers 502 and tells the site`() {
        val reported = CopyOnWriteArrayList<RouteFailure>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1", mode = "socks5")) { reported += it })
        var connected = false
        LoopbackProxy(
            credentials,
            resolve = { Route.Refused(RouteFailure.PROXY_UNREACHABLE) },
            connect = { _, _, _ -> connected = true; Socket() },
        ).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(502, statusOf(socket))
            }
        }
        assertEquals(listOf(RouteFailure.PROXY_UNREACHABLE), reported)
        assertFalse(connected)
    }

    /** Plan deviation 1: a single connection's failure is answered, never reported. */
    @Test fun `an upstream that refuses the destination answers 502 and reports nothing`() {
        val reported = CopyOnWriteArrayList<RouteFailure>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1", mode = "http", host = "127.0.0.1", port = 1)) { reported += it })
        LoopbackProxy(credentials, bySettings, connect = { _, _, _ -> throw ProxyTunnelException(403, "refused") }).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(502, statusOf(socket))
            }
        }
        assertTrue(reported.isEmpty())
    }

    @Test fun `an upstream timeout answers 504`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        LoopbackProxy(credentials, bySettings, connect = { _, _, _ -> throw java.net.SocketTimeoutException("slow") }).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(504, statusOf(socket))
            }
        }
    }

    /** Review Focus 5: the credential never reaches the origin. */
    @Test fun `an http request is sent on in origin form, without the credential, and its response relayed`() {
        FakeOrigin("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: keep-alive\r\n\r\nok").use { origin ->
            val credentials = SiteCredentials()
            credentials.bind("p1", ProxyBinding(config("p1")) {})
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(
                    proxy,
                    "POST http://localhost:${origin.port}/form?x=1 HTTP/1.1\r\nHost: localhost:${origin.port}\r\n" +
                        auth(credentials.credentialFor("p1")) +
                        "Proxy-Connection: keep-alive\r\nContent-Length: 3\r\n\r\na=1",
                ).use { socket ->
                    val head = responseHead(socket)
                    assertEquals("HTTP/1.1 200 OK", head.first())
                    assertTrue("Connection: close" in head)
                    assertFalse("Connection: keep-alive" in head)
                    assertEquals("ok", String(ByteArray(2).also { DataInputStream(socket.getInputStream()).readFully(it) }))
                }
                val sent = origin.heads.poll(5, TimeUnit.SECONDS)!!
                assertEquals("POST /form?x=1 HTTP/1.1", sent.first())
                assertTrue("Connection: close" in sent)
                assertTrue(sent.none { it.startsWith("Proxy-", ignoreCase = true) })
                assertEquals("a=1", origin.bodies.poll(5, TimeUnit.SECONDS))
            }
        }
    }

    /** Review Focus 4. */
    @Test fun `many tunnels at once each relay their own bytes`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                val pool = Executors.newFixedThreadPool(20)
                val results = (1..20).map { byte ->
                    pool.submit(Callable {
                        send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                            assertEquals(200, statusOf(socket))
                            socket.getOutputStream().write(byte)
                            socket.getOutputStream().flush()
                            socket.getInputStream().read()
                        }
                    })
                }
                results.forEachIndexed { index, result -> assertEquals(index + 1, result.get(10, TimeUnit.SECONDS)) }
                pool.shutdownNow()
            }
        }
    }

    // --- Open problem 1: a tunnel must not outlive its session or its route ---

    @Test fun `closing a session closes its open tunnel on both sides, and nothing more crosses`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                    ping(socket)
                    credentials.unbind("p1")
                    assertTrue("the upstream side is still open", echo.ended.await(5, TimeUnit.SECONDS))
                    assertTrue("the page's side is still open", closedByProxy(socket))
                    runCatching { socket.getOutputStream().write('x'.code); socket.getOutputStream().flush() }
                    Thread.sleep(200)
                    assertEquals(1, echo.received.get())
                }
            }
        }
    }

    /** The emulator's case: a direct site edited to SOCKS5 and reopened on the same profile. */
    @Test fun `a bind that moves the site to another route closes the tunnel opened on the old one`() {
        FakeSocks().use { socks ->
            EchoServer().use { echo ->
                val credentials = SiteCredentials()
                credentials.bind("p1", ProxyBinding(config("p1")) {})
                val credential = credentials.credentialFor("p1")
                LoopbackProxy(credentials, bySettings).start().use { proxy ->
                    send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credential)}\r\n").use { old ->
                        assertEquals(200, statusOf(old))
                        ping(old)
                        credentials.bind("p1", ProxyBinding(config("p1", mode = "socks5", host = "127.0.0.1", port = socks.port)) {})
                        assertTrue(echo.ended.await(5, TimeUnit.SECONDS))
                        assertTrue(closedByProxy(old))
                    }
                    // The same credential's next tunnel goes out on the new route.
                    send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credential)}\r\n").use { socket ->
                        assertEquals(200, statusOf(socket))
                    }
                    assertEquals("3 example.test:443", socks.requests.poll(5, TimeUnit.SECONDS))
                    assertEquals(1, echo.accepted.get())
                }
            }
        }
    }

    /** Any bind that replaces a binding closes its tunnels: the proxy cannot resolve a route on the main thread to compare. */
    @Test fun `a bind that replaces the binding closes its tunnels even on the same route`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                    ping(socket)
                    credentials.bind("p1", ProxyBinding(config("p1")) {})
                    assertTrue(echo.ended.await(5, TimeUnit.SECONDS))
                    assertTrue(closedByProxy(socket))
                }
            }
        }
    }

    @Test fun `closing one session leaves another session's tunnel open`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        credentials.bind("p2", ProxyBinding(config("p2")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { first ->
                    send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p2"))}\r\n").use { second ->
                        assertEquals(200, statusOf(first))
                        assertEquals(200, statusOf(second))
                        credentials.unbind("p1")
                        assertTrue(closedByProxy(first))
                        ping(second)
                    }
                }
            }
        }
    }

    @Test fun `a session closed while its upstream is still connecting gets no tunnel`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        val connecting = CountDownLatch(1)
        val connected = CountDownLatch(1)
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings, connect = { _, _, _ ->
                connecting.countDown()
                connected.await(5, TimeUnit.SECONDS)
                Socket("localhost", echo.port)
            }).start().use { proxy ->
                send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertTrue(connecting.await(5, TimeUnit.SECONDS))
                    credentials.unbind("p1")
                    connected.countDown()
                    assertNull("the page got a reply", runCatching { readHead(socket.getInputStream()) }.getOrNull())
                    // The upstream connection that finished after the close was closed, and carried nothing.
                    assertTrue(echo.ended.await(5, TimeUnit.SECONDS))
                    assertEquals(0, echo.received.get())
                }
            }
        }
    }

    @Test fun `closing a session ends its forwarded request on both sides`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        val requested = CountDownLatch(1)
        val originClosed = CountDownLatch(1)
        ServerSocket(0).use { origin ->
            Thread {
                runCatching {
                    origin.accept().use { socket ->
                        readHead(socket.getInputStream())
                        requested.countDown()
                        // Never answers: the request is still in flight when the session closes.
                        while (socket.getInputStream().read() != -1) Unit
                    }
                }
                originClosed.countDown()
            }.apply { isDaemon = true }.start()
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(
                    proxy,
                    "GET http://localhost:${origin.localPort}/ HTTP/1.1\r\nHost: localhost:${origin.localPort}\r\n" +
                        auth(credentials.credentialFor("p1")) + "\r\n",
                ).use { socket ->
                    assertTrue(requested.await(5, TimeUnit.SECONDS))
                    credentials.unbind("p1")
                    assertTrue("the origin side is still open", originClosed.await(5, TimeUnit.SECONDS))
                    assertTrue("the page's side is still open", closedByProxy(socket))
                }
            }
        }
    }

    /** The site's next session must not hear a failure from a connection of its last one. */
    @Test fun `a route refused after its session closed is not reported`() {
        val reported = CopyOnWriteArrayList<RouteFailure>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1", mode = "socks5")) { reported += it })
        val resolving = CountDownLatch(1)
        val resolved = CountDownLatch(1)
        LoopbackProxy(credentials, resolve = {
            resolving.countDown()
            resolved.await(5, TimeUnit.SECONDS)
            Route.Refused(RouteFailure.PROXY_UNREACHABLE)
        }).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertTrue(resolving.await(5, TimeUnit.SECONDS))
                credentials.unbind("p1")
                resolved.countDown()
                assertTrue(closedByProxy(socket))
            }
        }
        Thread.sleep(200)
        assertTrue(reported.isEmpty())
    }

    // --- Open problem 2: a device run's request log --------------------------

    /** `android.util.Log` throws on the JVM's stub android.jar; it once turned every reply into a silent close. */
    @Test fun `a logger that throws changes nothing`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings, log = { throw RuntimeException("Method d in android.util.Log not mocked") }).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n\r\n").use { socket ->
                    assertEquals(407, statusOf(socket))
                }
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                    ping(socket)
                }
            }
        }
    }

    @Test fun `each request is logged with its outcome, and never its credential`() {
        val lines = CopyOnWriteArrayList<String>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        credentials.bind("p2", ProxyBinding(config("p2", mode = "socks5")) {})
        EchoServer().use { echo ->
            LoopbackProxy(
                credentials,
                resolve = { if (it.proxyMode == "socks5") Route.Refused(RouteFailure.PROXY_UNREACHABLE) else Route.Direct },
                log = { lines += it },
            ).start().use { proxy ->
                send(proxy, "HELLO\r\n\r\n").use { socket -> assertEquals(400, statusOf(socket)) }
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n\r\n").use { socket -> assertEquals(407, statusOf(socket)) }
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                    ping(socket)
                }
                send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p2"))}\r\n").use { socket ->
                    assertEquals(502, statusOf(socket))
                }
            }
            // Each line is written before its reply, so the order is the requests' order.
            assertEquals(
                listOf(
                    "? -> 400",
                    "CONNECT localhost:${echo.port} -> 407",
                    "CONNECT localhost:${echo.port} -> 200 tunnel",
                    "CONNECT example.test:443 -> 502 refused route (PROXY_UNREACHABLE)",
                ),
                lines.toList(),
            )
        }
        val secrets = listOf("p1", "p2").map(credentials::credentialFor).flatMap { listOf(it.user, it.password) }
        assertTrue(lines.none { line -> secrets.any { it in line } })
    }

    @Test fun `a failed upstream connection is logged with its status and error type`() {
        val lines = CopyOnWriteArrayList<String>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        LoopbackProxy(
            credentials, bySettings,
            connect = { _, _, _ -> throw SocketTimeoutException("slow") },
            log = { lines += it },
        ).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(504, statusOf(socket))
            }
        }
        assertEquals(listOf("CONNECT example.test:443 -> 504 upstream failed (SocketTimeoutException)"), lines.toList())
    }
}

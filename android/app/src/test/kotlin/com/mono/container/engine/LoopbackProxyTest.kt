package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.DataInputStream
import java.net.ServerSocket
import java.net.Socket
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

    private fun ping(socket: Socket, byte: Int = 'p'.code) {
        socket.getOutputStream().write(byte)
        socket.getOutputStream().flush()
        assertEquals(byte, socket.getInputStream().read())
    }

    /** Echoes every byte of every connection, counting connections and ends. */
    private class EchoServer : AutoCloseable {
        val server = ServerSocket(0)
        val accepted = AtomicInteger()
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
}

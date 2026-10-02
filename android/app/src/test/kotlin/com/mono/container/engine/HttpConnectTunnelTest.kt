package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.net.ServerSocket
import java.util.concurrent.ArrayBlockingQueue

class HttpConnectTunnelTest {

    /**
     * A fake HTTP proxy on an ephemeral port. Accepts one connection, records
     * the request head it was sent, replies with [response], then (for a 200)
     * echoes whatever the client writes next so the test can prove the socket
     * is still usable as a tunnel afterwards.
     */
    private class FakeProxy(private val response: String, private val echo: Boolean) : AutoCloseable {
        val server = ServerSocket(0)
        val heads = ArrayBlockingQueue<List<String>>(1)

        init {
            Thread {
                runCatching {
                    server.accept().use { client ->
                        val input = client.getInputStream()
                        heads.offer(readHead(input)!!)
                        val out = client.getOutputStream()
                        out.write(response.toByteArray(Charsets.US_ASCII))
                        out.flush()
                        if (echo) {
                            val byte = input.read()
                            if (byte != -1) { out.write(byte); out.flush() }
                        }
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    @Test fun `sends CONNECT with the target authority, not the proxy's`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
            HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443).close()
            assertEquals("CONNECT example.com:443 HTTP/1.1", proxy.heads.take().first())
        }
    }

    /**
     * RFC 9110 §7.2: an IPv6 literal in an authority is bracketed. The loopback
     * proxy hands over the host without brackets (`parseAuthority`), so a
     * direct site behind a Wi-Fi proxy, or an http-mode site, at
     * `https://[2001:db8::1]/` would otherwise send `CONNECT 2001:db8::1:443`.
     */
    @Test fun `brackets an IPv6 literal target, once`() {
        for (target in listOf("2001:db8::1", "[2001:db8::1]")) {
            FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
                HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, target, 443).close()
                assertEquals("CONNECT [2001:db8::1]:443 HTTP/1.1", proxy.heads.take().first())
            }
        }
    }

    @Test fun `returns a still-open socket on 200`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = true).use { proxy ->
            HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443).use { socket ->
                assertTrue(socket.isConnected)
                assertTrue(!socket.isClosed)
                // The header block must have been consumed: the next byte the
                // client reads is tunnel payload, not a leftover header line.
                socket.getOutputStream().write('x'.code)
                socket.getOutputStream().flush()
                assertEquals('x'.code, socket.getInputStream().read())
            }
        }
    }

    @Test fun `throws ProxyTunnelException when the proxy refuses`() {
        FakeProxy("HTTP/1.1 403 Forbidden\r\n\r\n", echo = false).use { proxy ->
            try {
                HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443)
                fail("expected ProxyTunnelException")
            } catch (error: ProxyTunnelException) {
                assertEquals(403, error.statusCode)
            }
        }
    }

    @Test fun `with a login it sends Proxy-Authorization Basic`() {
        for ((login, encoded) in listOf(ProxyLogin("user", "pass") to "dXNlcjpwYXNz", ProxyLogin("ünï", "p:w") to "w7xuw686cDp3")) {
            FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
                HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443, login).close()
                assertTrue("Proxy-Authorization: Basic $encoded" in proxy.heads.take())
            }
        }
    }

    @Test fun `without a login it sends no Proxy-Authorization`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
            HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443).close()
            assertTrue(proxy.heads.take().none { it.startsWith("Proxy-Authorization", ignoreCase = true) })
        }
    }

    /** Ruling 4: any 407 is a rejected login, whether one was sent or not. */
    @Test fun `a 407 is a rejected login, with or without one`() {
        for (login in listOf(null, ProxyLogin("alice", "s3cret"))) {
            FakeProxy("HTTP/1.1 407 Proxy Authentication Required\r\n\r\n", echo = false).use { proxy ->
                try {
                    HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443, login)
                    fail("expected ProxyLoginRejectedException")
                } catch (error: ProxyLoginRejectedException) {
                    assertFalse("s3cret" in error.message.orEmpty())
                    assertFalse("example.com" in error.message.orEmpty())
                }
            }
        }
    }

    @Test fun `the router sends an http route's login`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
            Router.connect(Route.Proxy("127.0.0.1", proxy.server.localPort, socks = false, login = ProxyLogin("user", "pass")), "example.com", 443).close()
            assertTrue("Proxy-Authorization: Basic dXNlcjpwYXNz" in proxy.heads.take())
        }
    }
}

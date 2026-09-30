package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.net.ServerSocket
import java.util.concurrent.ArrayBlockingQueue

class HttpConnectTunnelTest {

    /**
     * A fake HTTP proxy on an ephemeral port. Accepts one connection, records
     * the request line it was sent, replies with [response], then (for a 200)
     * echoes whatever the client writes next so the test can prove the socket
     * is still usable as a tunnel afterwards.
     */
    private class FakeProxy(private val response: String, private val echo: Boolean) : AutoCloseable {
        val server = ServerSocket(0)
        val requestLines = ArrayBlockingQueue<String>(1)

        init {
            Thread {
                runCatching {
                    server.accept().use { client ->
                        val input = client.getInputStream()
                        val requestLine = readLine(input)
                        while (readLine(input).isNotEmpty()) { /* drain headers */ }
                        requestLines.offer(requestLine)
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

        private fun readLine(input: java.io.InputStream): String {
            val line = StringBuilder()
            while (true) {
                val byte = input.read()
                if (byte == -1 || byte == '\n'.code) break
                if (byte != '\r'.code) line.append(byte.toChar())
            }
            return line.toString()
        }

        override fun close() = server.close()
    }

    @Test fun `sends CONNECT with the target authority, not the proxy's`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
            HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443).close()
            assertEquals("CONNECT example.com:443 HTTP/1.1", proxy.requestLines.take())
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
                assertEquals("CONNECT [2001:db8::1]:443 HTTP/1.1", proxy.requestLines.take())
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
        FakeProxy("HTTP/1.1 407 Proxy Authentication Required\r\n\r\n", echo = false).use { proxy ->
            try {
                HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443)
                fail("expected ProxyTunnelException")
            } catch (error: ProxyTunnelException) {
                assertEquals(407, error.statusCode)
            }
        }
    }
}

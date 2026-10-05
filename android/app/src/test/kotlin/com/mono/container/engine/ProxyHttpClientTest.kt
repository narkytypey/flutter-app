package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.ServerSocket
import java.util.concurrent.ArrayBlockingQueue

/**
 * Guards the wire format [ProxyHttpClient.fetch] writes. Nothing tested it
 * before, which is how a download could be built to carry headers and still
 * have them silently dropped on the way out.
 *
 * The fake speaks plain http on localhost, so these exercise [Route.Direct]
 * only — TLS and the CONNECT tunnel have their own coverage.
 */
class ProxyHttpClientTest {

    /** Accepts one connection, records the whole request head, replies 200. */
    private class FakeOrigin(
        private val body: String = "hi",
        private val responseHead: String = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n",
    ) : AutoCloseable {
        val server = ServerSocket(0)
        val heads = ArrayBlockingQueue<List<String>>(1)

        init {
            Thread {
                runCatching {
                    server.accept().use { client ->
                        val input = client.getInputStream()
                        val head = mutableListOf<String>()
                        while (true) {
                            val line = readLine(input)
                            if (line.isEmpty()) break
                            head.add(line)
                        }
                        heads.offer(head)
                        val out = client.getOutputStream()
                        out.write("$responseHead$body".toByteArray(Charsets.US_ASCII))
                        out.flush()
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

    private fun fetchAgainst(origin: FakeOrigin, headers: Map<String, String>) =
        ProxyHttpClient.fetch(Route.Direct, "127.0.0.1", origin.server.localPort, false, "GET", "/a.pdf", headers)

    @Test fun `writes every request header it is given`() {
        FakeOrigin().use { origin ->
            fetchAgainst(origin, mapOf("User-Agent" to "Chrome/126", "Cookie" to "session=abc")).body.close()
            val head = origin.heads.take()
            assertTrue("User-Agent: Chrome/126" in head)
            assertTrue("Cookie: session=abc" in head)
        }
    }

    @Test fun `writes the request line and Host before any given header`() {
        FakeOrigin().use { origin ->
            fetchAgainst(origin, mapOf("User-Agent" to "Chrome/126")).body.close()
            val head = origin.heads.take()
            assertEquals("GET /a.pdf HTTP/1.1", head[0])
            // The fake listens on an ephemeral port, never 80, so the port
            // must be on the line.
            assertEquals("Host: 127.0.0.1:${origin.server.localPort}", head[1])
        }
    }

    @Test fun `leaves the port off Host only when it is the scheme's default`() {
        assertEquals("example.com", ProxyHttpClient.hostHeader("example.com", 80, secure = false))
        assertEquals("example.com", ProxyHttpClient.hostHeader("example.com", 443, secure = true))
        assertEquals("example.com:8443", ProxyHttpClient.hostHeader("example.com", 8443, secure = true))
        assertEquals("example.com:443", ProxyHttpClient.hostHeader("example.com", 443, secure = false))
        assertEquals("example.com:80", ProxyHttpClient.hostHeader("example.com", 80, secure = true))
    }

    @Test fun `reads back the status line and headers`() {
        FakeOrigin().use { origin ->
            val response = fetchAgainst(origin, emptyMap())
            assertEquals(200, response.status)
            assertEquals("OK", response.reason)
            assertEquals("text/plain", response.headers["Content-Type"])
            assertEquals("hi", response.body.use { it.readBytes().toString(Charsets.US_ASCII) })
        }
    }

    /**
     * Header names are case-insensitive (RFC 9110 §5.1). A server that sends
     * `content-type` must be read exactly like one that sends `Content-Type`:
     * a case-sensitive lookup turned such a page into a held download.
     */
    @Test fun `response headers are found whatever their case`() {
        val head = "HTTP/1.1 200 OK\r\ncontent-type: text/html\r\nCONTENT-LENGTH: 3\r\n\r\n"
        FakeOrigin(body = "<p>", responseHead = head).use { origin ->
            val response = fetchAgainst(origin, emptyMap())
            response.body.close()
            assertEquals("text/html", response.headers["Content-Type"])
            assertEquals("3", response.headers["content-length"])
        }
    }

    /**
     * Found on a device: example.org over SOCKS5 showed its chunk sizes
     * (`2c9`, `0`) as page text, because the raw framing was handed to WebView
     * as the body. The body is now decoded, and `Content-Length` — which a
     * `Transfer-Encoding` overrides (RFC 9112 §6.3) — no longer describes it,
     * so it is dropped.
     */
    @Test fun `a chunked body is handed on decoded, with no declared length`() {
        val head = "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nTransfer-Encoding: chunked\r\nContent-Length: 999\r\n\r\n"
        val body = "5;x=y\r\nhello\r\n6\r\n world\r\n0\r\nX-Trailer: t\r\n\r\n"
        FakeOrigin(body = body, responseHead = head).use { origin ->
            val response = fetchAgainst(origin, emptyMap())
            assertEquals("hello world", response.body.use { it.readBytes().toString(Charsets.US_ASCII) })
            assertEquals(null, response.headers["Content-Length"])
        }
    }

    /** A failed TLS handshake used to leave the connected socket open. */
    @Test fun `a fetch that fails after connecting closes its socket`() {
        ServerSocket(0).use { server ->
            val closedByClient = ArrayBlockingQueue<Boolean>(1)
            Thread {
                runCatching {
                    server.accept().use { client ->
                        client.soTimeout = 5_000
                        // Not TLS: the client's handshake fails on this.
                        client.getOutputStream().apply { write("HTTP/1.1 200 OK\r\n\r\n".toByteArray()); flush() }
                        val closed = try {
                            val buffer = ByteArray(4096)
                            while (client.getInputStream().read(buffer) != -1) { /* the ClientHello */ }
                            true
                        } catch (_: java.net.SocketTimeoutException) {
                            false
                        } catch (_: java.io.IOException) {
                            true // reset: closed too
                        }
                        closedByClient.offer(closed)
                    }
                }
            }.apply { isDaemon = true }.start()
            try {
                ProxyHttpClient.fetch(Route.Direct, "127.0.0.1", server.localPort, true, "GET", "/", emptyMap())
                org.junit.Assert.fail("a TLS handshake against plain http must fail")
            } catch (_: java.io.IOException) {
            }
            assertEquals(true, closedByClient.poll(10, java.util.concurrent.TimeUnit.SECONDS))
        }
    }
}

package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.EOFException
import java.io.InputStream

/**
 * Every HTTP head this engine reads from the network is bounded: a line by
 * [MAX_HTTP_LINE], a head by [MAX_HTTP_HEAD]. Before, a peer that sent bytes
 * with no newline grew a StringBuilder until the app ran out of memory.
 */
class HttpHeadLimitsTest {

    private fun stream(text: String) = ByteArrayInputStream(text.toByteArray(Charsets.ISO_8859_1))

    /** Endless bytes with no newline, as a hostile peer would send. */
    private fun endless(byte: Char = 'a') = object : InputStream() {
        override fun read(): Int = byte.code
    }

    @Test fun `reads CRLF and bare LF lines, null at a clean end`() {
        val head = HttpHeadReader(stream("one\r\ntwo\n\r\n"))
        assertEquals("one", head.readLine())
        assertEquals("two", head.readLine())
        assertEquals("", head.readLine())
        assertNull(head.readLine())
    }

    @Test fun `a line at the cap is read, one over it is refused`() {
        val atCap = "a".repeat(MAX_HTTP_LINE)
        assertEquals(atCap, HttpHeadReader(stream("$atCap\r\n")).readLine())
        assertThrows(HttpHeadTooLargeException::class.java) {
            HttpHeadReader(stream("${atCap}a\r\n")).readLine()
        }
    }

    @Test fun `an endless line is refused rather than read for ever`() {
        assertThrows(HttpHeadTooLargeException::class.java) { HttpHeadReader(endless()).readLine() }
    }

    @Test fun `many short lines past the head cap are refused`() {
        val line = "X-A: " + "b".repeat(1000) + "\r\n"
        val head = HttpHeadReader(stream(line.repeat(MAX_HTTP_HEAD / line.length + 2)))
        assertThrows(HttpHeadTooLargeException::class.java) { while (true) head.readLine() }
    }

    @Test fun `readLineOrThrow treats end of stream before the newline as EOF`() {
        assertThrows(EOFException::class.java) { HttpHeadReader(stream("partial")).readLineOrThrow("x") }
    }

    @Test fun `a response with an endless status line is refused`() {
        assertThrows(HttpHeadTooLargeException::class.java) { ProxyHttpClient.readResponse(endless()) }
    }

    @Test fun `a response with an endless header block is refused`() {
        val headers = object : InputStream() {
            private val prefix = "HTTP/1.1 200 OK\r\n".toByteArray()
            private var i = 0
            override fun read(): Int = if (i < prefix.size) prefix[i++].toInt() else "X: y\r\n"[(i++ - prefix.size) % 6].code
        }
        assertThrows(HttpHeadTooLargeException::class.java) { ProxyHttpClient.readResponse(headers) }
    }

    @Test fun `a normal response head still reads, and an empty one is a 502`() {
        val response = ProxyHttpClient.readResponse(stream("HTTP/1.1 404 Not Found\r\nContent-Length: 2\r\n\r\nhi"))
        assertEquals(404, response.status)
        assertEquals("2", response.headers["content-length"])
        assertEquals("hi", response.body.readBytes().toString(Charsets.US_ASCII))
        assertEquals(502, ProxyHttpClient.readResponse(stream("")).status)
    }

    @Test fun `a CONNECT answer that ends before its blank line is an EOF, not a tunnel`() {
        assertThrows(EOFException::class.java) {
            HttpConnectTunnel.readStatus(stream("HTTP/1.1 200 Connection established\r\n"))
        }
        assertThrows(EOFException::class.java) {
            HttpConnectTunnel.readStatus(stream("HTTP/1.1 200 Connection established\r\nVia: x\r\n"))
        }
        assertThrows(EOFException::class.java) { HttpConnectTunnel.readStatus(stream("")) }
    }

    @Test fun `a whole CONNECT answer still gives its status`() {
        assertEquals(200, HttpConnectTunnel.readStatus(stream("HTTP/1.1 200 OK\r\nVia: x\r\n\r\n")))
        assertEquals(403, HttpConnectTunnel.readStatus(stream("HTTP/1.1 403 Forbidden\r\n\r\n")))
    }

    @Test fun `a CONNECT answer with an endless line is refused`() {
        assertThrows(HttpHeadTooLargeException::class.java) { HttpConnectTunnel.readStatus(endless()) }
    }

    @Test fun `a chunk size line with no end is refused`() {
        assertThrows(HttpHeadTooLargeException::class.java) { ChunkedBody(endless('0')).read() }
    }

    @Test fun `an endless chunked trailer is refused`() {
        val wire = object : InputStream() {
            private val prefix = "0\r\n".toByteArray()
            private var i = 0
            override fun read(): Int = if (i < prefix.size) prefix[i++].toInt() else "T: v\r\n"[(i++ - prefix.size) % 6].code
        }
        assertThrows(HttpHeadTooLargeException::class.java) { ChunkedBody(wire).read() }
    }

    @Test fun `a body of many chunks is not refused for its framing adding up`() {
        // Each chunk's framing is 6 bytes; 20 000 chunks is more than MAX_HTTP_HEAD of framing.
        val wire = "1\r\na\r\n".repeat(20_000) + "0\r\n\r\n"
        val decoded = ChunkedBody(stream(wire)).readBytes()
        assertEquals(20_000, decoded.size)
    }
}

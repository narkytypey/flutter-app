package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.IOException

/** RFC 9112 §7.1 chunked framing, decoded before WebView or a file sees it. */
class ChunkedBodyTest {

    private fun decode(wire: String): String =
        ChunkedBody(ByteArrayInputStream(wire.toByteArray(Charsets.US_ASCII))).readBytes().toString(Charsets.US_ASCII)

    @Test fun `joins the chunks and drops the framing`() {
        assertEquals("hello world", decode("5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n"))
    }

    @Test fun `reads chunk sizes in either case of hex`() {
        assertEquals("0123456789", decode("a\r\n0123456789\r\n0\r\n\r\n"))
        assertEquals("0123456789", decode("A\r\n0123456789\r\n0\r\n\r\n"))
    }

    @Test fun `ignores chunk extensions`() {
        assertEquals("hello", decode("5;name=value;flag\r\nhello\r\n0;last\r\n\r\n"))
    }

    @Test fun `consumes the trailer section and reads nothing after it`() {
        val wire = "5\r\nhello\r\n0\r\nX-Checksum: abc\r\nX-Other: d\r\n\r\nNEXT"
        val underlying = ByteArrayInputStream(wire.toByteArray(Charsets.US_ASCII))
        assertEquals("hello", ChunkedBody(underlying).readBytes().toString(Charsets.US_ASCII))
        assertEquals("NEXT", underlying.readBytes().toString(Charsets.US_ASCII))
    }

    @Test fun `reads in bulk across chunk boundaries`() {
        val body = ChunkedBody(ByteArrayInputStream("3\r\nabc\r\n3\r\ndef\r\n0\r\n\r\n".toByteArray(Charsets.US_ASCII)))
        val buffer = ByteArray(10)
        val first = body.read(buffer, 0, 10)
        assertEquals("abc", String(buffer, 0, first, Charsets.US_ASCII))
        val second = body.read(buffer, 0, 10)
        assertEquals("def", String(buffer, 0, second, Charsets.US_ASCII))
        assertEquals(-1, body.read(buffer, 0, 10))
    }

    /** A body cut off mid-chunk must fail, not read as a complete, shorter one. */
    @Test fun `a body that ends inside a chunk is an error`() {
        assertThrows(IOException::class.java) { decode("a\r\nhello") }
    }

    @Test fun `a body that ends before the last chunk is an error`() {
        assertThrows(IOException::class.java) { decode("5\r\nhello\r\n") }
    }

    @Test fun `a size that is not hex is an error`() {
        assertThrows(IOException::class.java) { decode("zz\r\nhello\r\n0\r\n\r\n") }
    }
}

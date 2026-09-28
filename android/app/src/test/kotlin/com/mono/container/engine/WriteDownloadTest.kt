package com.mono.container.engine

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.io.IOException
import java.io.InputStream

/**
 * [writeDownload] is what decides whether a fetched download becomes a file.
 *
 * Found on a device: a TLS read error mid-body left a truncated PDF in the
 * container, and each retry added another (`name (1).pdf`), none of them
 * openable. Nothing checked the status either, so a login page served with a
 * 401 would have been kept as the "file".
 */
class WriteDownloadTest {

    @get:Rule val folder = TemporaryFolder()

    private val pdf = "%PDF-1.4 body %%EOF".toByteArray()

    private fun response(status: Int, body: InputStream, contentLength: Int? = null) =
        ProxyHttpClient.FetchedResponse(
            status, "OK",
            if (contentLength != null) mapOf("Content-Length" to "$contentLength") else emptyMap(),
            body,
        )

    private fun leftovers() = folder.root.listFiles()!!.map { it.name }

    @Test fun `a complete body becomes the target and nothing else`() {
        val target = folder.root.resolve("a.pdf")
        writeDownload(response(200, ByteArrayInputStream(pdf), pdf.size), target)
        assertArrayEquals(pdf, target.readBytes())
        assertEquals(listOf("a.pdf"), leftovers())
    }

    @Test fun `without a Content-Length whatever arrives is kept`() {
        val target = folder.root.resolve("a.pdf")
        writeDownload(response(200, ByteArrayInputStream(pdf)), target)
        assertArrayEquals(pdf, target.readBytes())
    }

    @Test fun `a body shorter than its Content-Length leaves no file`() {
        val target = folder.root.resolve("a.pdf")
        try {
            writeDownload(response(200, ByteArrayInputStream(pdf), pdf.size + 100), target)
            fail("a truncated body must not be accepted")
        } catch (e: IncompleteDownloadException) {
            assertEquals(pdf.size.toLong(), e.received)
            assertEquals(pdf.size + 100L, e.expected)
        }
        assertTrue(leftovers().isEmpty())
    }

    @Test fun `a read error mid-body leaves no file and surfaces the original error`() {
        val boom = javax.net.ssl.SSLProtocolException("Read error")
        val failing = object : InputStream() {
            var sent = 0
            override fun read(): Int = if (sent++ < 4) 'x'.code else throw boom
        }
        val target = folder.root.resolve("a.pdf")
        try {
            writeDownload(response(200, failing, 100), target)
            fail("the read error must propagate")
        } catch (e: IOException) {
            // The same exception, so failureFor can still name it TLS_FAILURE.
            assertSame(boom, e)
        }
        assertTrue(leftovers().isEmpty())
    }

    @Test fun `a non-2xx status writes nothing`() {
        val target = folder.root.resolve("a.pdf")
        try {
            writeDownload(response(401, ByteArrayInputStream("<h1>Login required</h1>".toByteArray())), target)
            fail("an error page must not be kept as the file")
        } catch (e: DownloadRejectedException) {
            assertEquals(401, e.status)
        }
        assertFalse(target.exists())
        assertTrue(leftovers().isEmpty())
    }
}

package com.mono.container.engine

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.ByteArrayInputStream
import java.io.InputStream

/**
 * A kept download still running when its site is wiped, or the app panics,
 * must not land in the container afterwards: before [DownloadWipes], the
 * worker renamed its `.part` into a directory the wipe had just emptied, and
 * then opened it in a viewer.
 */
class DownloadWipesTest {

    @get:Rule val folder = TemporaryFolder()

    private val body = "%PDF-1.4 body %%EOF".toByteArray()

    private fun response(input: InputStream = ByteArrayInputStream(body)) =
        ProxyHttpClient.FetchedResponse(200, "OK", mapOf("Content-Length" to "${body.size}"), input)

    @Test fun `a fresh ticket is not wiped`() {
        val wipes = DownloadWipes()
        assertFalse(wipes.isWiped(wipes.ticket("p1")))
    }

    @Test fun `a wipe of the ticket's profile wipes it, another profile's does not`() {
        val wipes = DownloadWipes()
        val ticket = wipes.ticket("p1")
        wipes.wiped("p2")
        assertFalse(wipes.isWiped(ticket))
        wipes.wiped("p1")
        assertTrue(wipes.isWiped(ticket))
        // A download begun after the wipe (a wipe-on-exit site reopened) is not.
        assertFalse(wipes.isWiped(wipes.ticket("p1")))
    }

    @Test fun `panic wipes every ticket taken before it`() {
        val wipes = DownloadWipes()
        val a = wipes.ticket("p1")
        val b = wipes.ticket("p2")
        wipes.wipedAll()
        assertTrue(wipes.isWiped(a))
        assertTrue(wipes.isWiped(b))
        assertFalse(wipes.isWiped(wipes.ticket("p1")))
    }

    @Test fun `a download whose site was wiped mid-body leaves nothing behind`() {
        val wipes = DownloadWipes()
        val ticket = wipes.ticket("p1")
        val target = folder.root.resolve("a.pdf")
        // The wipe lands while the body is still arriving.
        val slow = object : InputStream() {
            private val inner = ByteArrayInputStream(body)
            override fun read(): Int {
                val byte = inner.read()
                if (byte == -1) wipes.wiped("p1")
                return byte
            }
        }
        try {
            writeDownload(response(slow), target) { move -> wipes.unlessWiped(ticket, move) }
            fail("a wiped site's download must not land")
        } catch (_: DownloadWipedException) {
        }
        assertFalse(target.exists())
        assertTrue(folder.root.listFiles()!!.isEmpty())
    }

    @Test fun `a download whose site was not wiped lands`() {
        val wipes = DownloadWipes()
        val ticket = wipes.ticket("p1")
        val target = folder.root.resolve("a.pdf")
        wipes.wiped("other")
        writeDownload(response(), target) { move -> wipes.unlessWiped(ticket, move) }
        assertTrue(target.exists())
    }

    @Test fun `writeDownload closes the body when the part file cannot be made`() {
        var closed = false
        val input = object : ByteArrayInputStream(body) {
            override fun close() { closed = true }
        }
        val target = folder.root.resolve("missing-dir/a.pdf")
        try {
            writeDownload(response(input), target)
            fail("there is no directory to write into")
        } catch (_: java.io.IOException) {
        }
        assertTrue(closed)
    }

    @Test fun `writeDownload closes the body when the commit refuses`() {
        var closed = false
        val input = object : ByteArrayInputStream(body) {
            override fun close() { closed = true }
        }
        runCatching { writeDownload(response(input), folder.root.resolve("a.pdf")) { throw DownloadWipedException() } }
        assertTrue(closed)
        assertTrue(folder.root.listFiles()!!.isEmpty())
    }
}

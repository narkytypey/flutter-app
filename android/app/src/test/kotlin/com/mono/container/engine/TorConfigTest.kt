package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

/** Built-in Tor spec §4.1, §4.5, §5.3 and plan D1–D4: what Tor is told, and where it keeps things. */
class TorConfigTest {

    private val files = File("data", "files")

    @Test fun `the SOCKS socket is ours, in files tor`() {
        assertEquals(File(File(files, "tor"), "socks:0"), TorFiles.socket(files))
        assertEquals(File(files, "tor"), TorFiles.socketDir(files))
    }

    /** Plan D2: tor-android parses the text after the last colon of the listener as a port. */
    @Test fun `the socket's listener parses as port 0, the way TorService reads it`() {
        val value = "\"unix:${TorFiles.socket(files).absolutePath}\""
        assertEquals(0, Integer.parseInt(value.substring(value.lastIndexOf(':') + 1, value.length - 1)))
    }

    @Test fun `torrc names the Unix socket with circuit isolation by login`() {
        val socket = TorFiles.socket(files)
        assertTrue(torrc(socket).contains("SocksPort unix:\"${socket.absolutePath}\" IsolateSOCKSAuth\n"))
    }

    /** Plan D3: the library's defaults open TCP 9050 and 8118; nothing of ours may. */
    @Test fun `torrc opens no TCP port`() {
        val text = torrc(TorFiles.socket(files))
        assertTrue(text.contains("HTTPTunnelPort 0\n"))
        assertTrue(text.contains("ControlPort 0\n"))
        assertFalse(text.contains("9050"))
        assertFalse(text.contains("8118"))
    }

    @Test fun `panic's list is our socket directory and the two tor-android picks`() {
        val data = File("data")
        val cache = File("cache")
        assertEquals(
            listOf(File(files, "tor"), File(data, "app_TorService"), File(cache, "TorService")),
            TorFiles.all(files, data, cache),
        )
    }

    @Test fun `a bootstrap phase gives its percentage`() {
        assertEquals(45, bootstrapPercent("NOTICE BOOTSTRAP PROGRESS=45 TAG=loading_descriptors SUMMARY=\"Loading relay descriptors\""))
        assertEquals(100, bootstrapPercent("NOTICE BOOTSTRAP PROGRESS=100 TAG=done SUMMARY=\"Done\""))
        assertEquals(0, bootstrapPercent("NOTICE BOOTSTRAP PROGRESS=0 TAG=starting SUMMARY=\"Starting\""))
    }

    @Test fun `no phase, or no percentage in it, is none`() {
        assertNull(bootstrapPercent(null))
        assertNull(bootstrapPercent(""))
        assertNull(bootstrapPercent("NOTICE BOOTSTRAP TAG=starting"))
    }

    /** Review Focus 4. */
    @Test fun `an onion host is one in any case, with or without a trailing dot`() {
        assertTrue(isOnionHost("duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion"))
        assertTrue(isOnionHost("ABC.ONION."))
        assertTrue(isOnionHost("www.abc.onion"))
        assertTrue(isOnionHost("onion"))
        assertFalse(isOnionHost("onion.example.com"))
        assertFalse(isOnionHost("example.com"))
        assertFalse(isOnionHost("notonion"))
    }

    @Test fun `a wipe deletes every directory and leaves the marker`() {
        val root = Files.createTempDirectory("tor-wipe").toFile()
        val dirs = listOf(File(root, "a"), File(root, "b"))
        dirs.forEach { File(it, "state").apply { parentFile.mkdirs(); writeText("guards") } }
        val marker = File(root, "tor-wipe-pending")

        TorWipe.wipe(dirs, marker)

        assertTrue(dirs.none { it.exists() })
        assertTrue(marker.exists())
        root.deleteRecursively()
    }

    /** Plan D4: Tor's own shutdown may write its state again after panic's delete. */
    @Test fun `a sweep with the marker deletes them again and removes the marker`() {
        val root = Files.createTempDirectory("tor-sweep").toFile()
        val dirs = listOf(File(root, "a"))
        val marker = File(root, "tor-wipe-pending").apply { writeText("") }
        File(dirs[0], "state").apply { parentFile.mkdirs(); writeText("written after the wipe") }

        TorWipe.sweep(dirs, marker)

        assertFalse(dirs[0].exists())
        assertFalse(marker.exists())
        root.deleteRecursively()
    }

    @Test fun `a sweep without the marker deletes nothing`() {
        val root = Files.createTempDirectory("tor-keep").toFile()
        val dirs = listOf(File(root, "a"))
        File(dirs[0], "state").apply { parentFile.mkdirs(); writeText("guards") }

        TorWipe.sweep(dirs, File(root, "tor-wipe-pending"))

        assertTrue(File(dirs[0], "state").exists())
        root.deleteRecursively()
    }
}

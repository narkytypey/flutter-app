package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * A throwaway's profile is on disk while its page is open (browser-chrome
 * spec §5.4). If the app dies before `ContainerView.dispose`, nothing else
 * would ever wipe it, so it is listed from before it exists until it is
 * wiped or kept, and every start wipes whatever is still listed.
 */
class ThrowawayJournalTest {

    @get:Rule val folder = TemporaryFolder()

    private val file get() = java.io.File(folder.root, "throwaway-profiles")

    private fun journal() = ThrowawayJournal(file)

    @Test fun `a throwaway stays listed across a restart`() {
        journal().add("t1")
        assertEquals(listOf("t1"), journal().names())
    }

    @Test fun `the file holds profile ids and nothing else`() {
        val journal = journal()
        journal.add("t1")
        journal.add("t2")
        assertEquals("t1\nt2\n", file.readText())
    }

    @Test fun `a wipe on dispose forgets the throwaway, after wiping`() {
        val journal = journal()
        journal.add("t1")
        val calls = mutableListOf<String>()

        wipeThenForget("t1", journal) { calls += "wipe while listed: ${journal.names()}" }

        assertEquals(listOf("wipe while listed: [t1]"), calls)
        assertTrue(journal().names().isEmpty())
    }

    @Test fun `a wipe that throws leaves it listed for the next start`() {
        val journal = journal()
        journal.add("t1")

        runCatching { wipeThenForget("t1", journal) { throw IllegalStateException("store gone") } }

        assertEquals(listOf("t1"), journal().names())
    }

    @Test fun `a wipe-on-exit site that was never a throwaway leaves the journal alone`() {
        val journal = journal()
        journal.add("t1")

        wipeThenForget("s1", journal) {}

        assertEquals(listOf("t1"), journal().names())
    }

    @Test fun `keeping a throwaway stops its wipe and forgets it`() {
        val journal = journal()
        journal.add("t1")
        var wipesOnExit = true

        keepThrowaway("t1", journal) { wipesOnExit = false }

        assertFalse(wipesOnExit)
        assertTrue(journal().names().isEmpty())
    }

    @Test fun `the start sweep wipes every listed profile and removes the file`() {
        val journal = journal()
        journal.add("t1")
        journal.add("t2")
        val wiped = mutableListOf<String>()

        journal.sweep { wiped += it }

        assertEquals(listOf("t1", "t2"), wiped)
        assertTrue(journal().names().isEmpty())
        assertFalse(file.exists())
    }

    @Test fun `a profile whose start wipe throws is tried again next start`() {
        val journal = journal()
        journal.add("gone")
        journal.add("stuck")

        journal.sweep { if (it == "stuck") throw IllegalStateException("store unavailable") }

        assertEquals(listOf("stuck"), journal().names())
    }

    @Test fun `panic clears the journal`() {
        val journal = journal()
        journal.add("t1")
        journal.add("t2")

        journal.clear()

        assertTrue(journal().names().isEmpty())
        assertFalse(file.exists())
    }
}

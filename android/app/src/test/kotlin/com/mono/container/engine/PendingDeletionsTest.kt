package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

/**
 * WebView will not delete a profile this process has loaded — Chromium's
 * `AwBrowserContextStore::Delete` returns `kInUse` for any context with a live
 * instance, and nothing ever releases one. So a wipe of a profile that was used
 * since start can only clear it now and delete it at the next start, before
 * anything loads it. Before this, every such wipe threw: panic failed open,
 * and ephemeral sites were silently never wiped.
 */
class PendingDeletionsTest {

    @get:Rule val folder = TemporaryFolder()

    private fun journal() = PendingDeletions(java.io.File(folder.root, "pending-profile-deletions"))

    @Test fun `a pending deletion survives a restart`() {
        journal().add("p1")
        assertEquals(listOf("p1"), journal().names())
    }

    @Test fun `adding the same profile twice lists it once`() {
        val pending = journal()
        pending.add("p1")
        pending.add("p1")
        assertEquals(listOf("p1"), pending.names())
    }

    @Test fun `a profile used again is no longer pending`() {
        val pending = journal()
        pending.add("p1")
        pending.add("p2")
        pending.remove("p1")
        assertEquals(listOf("p2"), journal().names())
    }

    @Test fun `the sweep deletes what it can and keeps the rest for next time`() {
        val pending = journal()
        pending.add("gone")
        pending.add("stuck")
        val deleted = mutableListOf<String>()

        pending.sweep { name ->
            if (name == "stuck") throw IllegalStateException("Cannot delete in-use profile $name")
            deleted += name
        }

        assertEquals(listOf("gone"), deleted)
        assertEquals(listOf("stuck"), journal().names())
    }

    @Test fun `a profile nothing has loaded is deleted outright and never journaled`() {
        val pending = journal()
        val calls = mutableListOf<String>()

        wipeProfile("p1", delete = { calls += "delete" }, clear = { calls += "clear" }, pending = pending)

        assertEquals(listOf("delete"), calls)
        assertTrue(pending.names().isEmpty())
    }

    @Test fun `a loaded profile is journaled, then cleared in place`() {
        val pending = journal()
        val calls = mutableListOf<String>()

        wipeProfile(
            "p1",
            delete = { throw IllegalStateException("Cannot delete in-use profile p1") },
            clear = { calls += "clear:${pending.names()}" },
            pending = pending,
        )

        // Journaled before clearing, so a clear that dies halfway still gets
        // the profile deleted at the next start.
        assertEquals(listOf("clear:[p1]"), calls)
        assertEquals(listOf("p1"), journal().names())
    }

    @Test fun `a loaded profile whose clearing fails is still journaled`() {
        val pending = journal()

        runCatching {
            wipeProfile(
                "p1",
                delete = { throw IllegalStateException("Cannot delete in-use profile p1") },
                clear = { throw RuntimeException("cookie store unavailable") },
                pending = pending,
            )
        }

        assertEquals(listOf("p1"), journal().names())
    }

    @Test fun `deleting outright also drops an older pending entry`() {
        val pending = journal()
        pending.add("p1")

        wipeProfile("p1", delete = {}, clear = {}, pending = pending)

        assertTrue(journal().names().isEmpty())
    }
}

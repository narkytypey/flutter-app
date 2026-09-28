package com.mono.container.engine

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `open` decides its route on a worker thread and registers the session
 * afterwards, so a `close` or a panic can land in between. Without these
 * tickets the late registration brought back a session nobody held and, after
 * panic, recreated the profile panic had just deleted.
 */
class PendingOpensTest {

    private val opens = PendingOpens()

    @Test fun `an open nobody interrupted may register`() {
        val ticket = opens.begin("s1")
        assertTrue(opens.finish("s1", ticket))
    }

    @Test fun `a close during the open revokes it`() {
        val ticket = opens.begin("s1")
        opens.cancel("s1")
        assertFalse(opens.finish("s1", ticket))
    }

    @Test fun `panic revokes every open in flight`() {
        val a = opens.begin("s1")
        val b = opens.begin("s2")
        opens.cancelAll()
        assertFalse(opens.finish("s1", a))
        assertFalse(opens.finish("s2", b))
    }

    @Test fun `closing another site leaves this one alone`() {
        val ticket = opens.begin("s1")
        opens.cancel("s2")
        assertTrue(opens.finish("s1", ticket))
    }

    @Test fun `a newer open of the same site supersedes the older one`() {
        val older = opens.begin("s1")
        val newer = opens.begin("s1")
        assertFalse(opens.finish("s1", older))
        assertTrue(opens.finish("s1", newer))
    }

    @Test fun `a ticket registers at most once`() {
        val ticket = opens.begin("s1")
        assertTrue(opens.finish("s1", ticket))
        assertFalse(opens.finish("s1", ticket))
    }
}

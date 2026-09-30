package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * A closing view loads about:blank first, so the old page's unload handlers
 * run while the view can still intercept (and refuse) what they send, and
 * only then is destroyed. Without a finished blank page it is destroyed after
 * a timeout, so a page that never finishes cannot keep a view alive.
 */
class TeardownTest {

    @Test fun `destroys once about blank has finished`() {
        var destroyed = 0
        val teardown = Teardown { destroyed++ }
        teardown.pageFinished("about:blank")
        assertEquals(1, destroyed)
    }

    @Test fun `the old page finishing late does not destroy early`() {
        var destroyed = 0
        val teardown = Teardown { destroyed++ }
        teardown.pageFinished("https://example.org/")
        assertEquals(0, destroyed)
    }

    @Test fun `the timeout destroys when about blank never finishes`() {
        var destroyed = 0
        val teardown = Teardown { destroyed++ }
        teardown.timedOut()
        assertEquals(1, destroyed)
    }

    @Test fun `destroys only once, whichever comes first`() {
        var destroyed = 0
        val teardown = Teardown { destroyed++ }
        teardown.pageFinished("about:blank")
        teardown.timedOut()
        teardown.pageFinished("about:blank")
        assertEquals(1, destroyed)
    }
}

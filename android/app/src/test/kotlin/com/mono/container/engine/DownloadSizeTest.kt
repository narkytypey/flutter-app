package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The held-download sheet showed "0 B" for a 190 KB PDF on the emulator.
 * Chromium reports an unknown length as 0. Since P2 Chromium fetches every
 * site's pages itself, so that is the only rule, on every route.
 */
class DownloadSizeTest {

    @Test fun `zero is unknown, not empty`() {
        assertNull(heldDownloadSize(0))
    }

    @Test fun `a real length is shown`() {
        assertEquals(194_560L, heldDownloadSize(194_560))
    }
}

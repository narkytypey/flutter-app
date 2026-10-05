package com.mono.container.engine

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GoesLiveOnDownloadTest {
    @Test fun `an opening session whose first load became a download goes live`() {
        assertTrue(goesLiveOnDownload(Session.PHASE_OPENING))
    }

    @Test fun `a download changes nothing for a session past opening`() {
        assertFalse(goesLiveOnDownload(Session.PHASE_LIVE))
        assertFalse(goesLiveOnDownload(Session.PHASE_BACKGROUND))
        // A refused site is never made live by anything but a reopen.
        assertFalse(goesLiveOnDownload(Session.PHASE_REFUSED))
    }
}

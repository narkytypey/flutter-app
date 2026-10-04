package com.mono.container.engine

import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** Built-in Tor spec §5.4: on Tor, WebRTC is always blocked. */
class TorShieldsTest {
    private fun site(mode: String, blockWebRtc: Boolean) = SiteConfig(
        siteId = "s", profileId = "p", url = "https://example.com",
        proxyMode = mode, proxyHost = null, proxyPort = null,
        blockWebRtc = blockWebRtc, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    @Test fun `a Tor site blocks WebRTC whatever was stored`() {
        assertTrue(site("tor", blockWebRtc = false).withTorShields().blockWebRtc)
    }

    @Test fun `any other site keeps its own choice`() {
        val direct = site("direct", blockWebRtc = false)
        assertSame(direct, direct.withTorShields())
        assertFalse(direct.withTorShields().blockWebRtc)
    }
}

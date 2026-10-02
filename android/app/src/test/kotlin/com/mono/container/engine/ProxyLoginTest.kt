package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProxyLoginTest {

    private fun config(perSite: Boolean = false, login: ProxyLogin? = null, profileId: String = "a".repeat(32)) = SiteConfig(
        siteId = "s", profileId = profileId, url = "https://forum.example.com",
        proxyMode = "socks5", proxyHost = "127.0.0.1", proxyPort = 9050,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
        proxyLogin = login, proxyLoginPerSite = perSite,
    )

    /** Spec §2.3, pinned to a vector computed outside the app (Python hashlib). */
    @Test fun `the per-site login is the SHA-256 of the profile id, split in two`() {
        assertEquals(
            ProxyLogin("227a50371d9f5a0c087f526719d0233a", "d7185dbae8318e755468638506428456"),
            perSiteLogin("a".repeat(32)),
        )
    }

    @Test fun `the per-site login is stable for a profile and differs across profiles`() {
        assertEquals(perSiteLogin("p1"), perSiteLogin("p1"))
        assertNotEquals(perSiteLogin("p1"), perSiteLogin("p2"))
    }

    @Test fun `the per-site login does not contain the profile id`() {
        val profileId = "0123456789abcdef0123456789abcdef"
        val login = perSiteLogin(profileId)
        assertFalse(profileId in login.user)
        assertFalse(profileId in login.password)
    }

    @Test fun `a login prints neither half`() {
        val login = ProxyLogin("alice", "s3cret")
        assertEquals("ProxyLogin(redacted)", login.toString())
        val printed = config(login = login).toString()
        assertFalse("alice" in printed)
        assertFalse("s3cret" in printed)
    }

    @Test fun `a typed login needs a non-empty user, and a missing password is empty`() {
        assertNull(proxyLoginFrom(null, "pw"))
        assertNull(proxyLoginFrom("", "pw"))
        assertEquals(ProxyLogin("alice", ""), proxyLoginFrom("alice", null))
        assertEquals(ProxyLogin("alice", " pw "), proxyLoginFrom("alice", " pw "))
    }

    /** Spec §2.1: per-site wins over a typed login; otherwise the typed one; otherwise none. */
    @Test fun `which login a site uses`() {
        val typed = ProxyLogin("alice", "s3cret")
        assertEquals(perSiteLogin("a".repeat(32)), loginFor(config(perSite = true, login = typed)))
        assertEquals(typed, loginFor(config(login = typed)))
        assertNull(loginFor(config()))
    }
}

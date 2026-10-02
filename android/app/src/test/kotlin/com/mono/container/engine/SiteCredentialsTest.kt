package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P2 spec §2: another app on the device can connect to a loopback port, so
 * the loopback proxy's credentials are what stop it being an open relay into
 * the user's proxy. Chromium caches a profile's credential for the whole
 * process, through locks and wipes, so a credential is fixed per profile and
 * is valid only while that profile's site has an open session.
 */
class SiteCredentialsTest {

    private fun config(profileId: String, mode: String = "direct") = SiteConfig(
        siteId = "site-$profileId", profileId = profileId, url = "https://forum.example.com",
        proxyMode = mode, proxyHost = null, proxyPort = null,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    private fun binding(profileId: String, mode: String = "direct") = ProxyBinding(config(profileId, mode)) {}

    @Test fun `a credential is 128 random bits each for user and password`() {
        val credential = SiteCredentials().credentialFor("p1")
        assertTrue(credential.user.matches(Regex("[0-9a-f]{32}")))
        assertTrue(credential.password.matches(Regex("[0-9a-f]{32}")))
        assertNotEquals(credential.user, credential.password)
    }

    @Test fun `each profile gets its own credential`() {
        val credentials = SiteCredentials()
        val a = credentials.credentialFor("p1")
        val b = credentials.credentialFor("p2")
        assertNotEquals(a.user, b.user)
        assertNotEquals(a.password, b.password)
    }

    @Test fun `a profile's credential is the same for the whole run`() {
        val credentials = SiteCredentials()
        assertSame(credentials.credentialFor("p1"), credentials.credentialFor("p1"))
    }

    @Test fun `a credential finds its site only while the site's session is open`() {
        val credentials = SiteCredentials()
        val credential = credentials.credentialFor("p1")
        assertNull(credentials.lookup(credential.user, credential.password))

        val open = binding("p1")
        credentials.bind("p1", open)
        assertSame(open, credentials.lookup(credential.user, credential.password))

        credentials.unbind("p1")
        assertNull(credentials.lookup(credential.user, credential.password))
    }

    /** Review Focus 1: after a lock Chromium still sends the credential it cached. */
    @Test fun `a site opened again is found by the credential Chromium already holds`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1"))
        val cached = credentials.credentialFor("p1")
        credentials.unbind("p1")

        val reopened = binding("p1")
        credentials.bind("p1", reopened)
        assertSame(reopened, credentials.lookup(cached.user, cached.password))
    }

    /** Review Focus 2: a reopen replaces the binding, so routing follows the newest settings. */
    @Test fun `a reopened site is routed by its newest settings`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1", mode = "direct"))
        credentials.bind("p1", binding("p1", mode = "socks5"))
        val credential = credentials.credentialFor("p1")
        assertEquals("socks5", credentials.lookup(credential.user, credential.password)!!.config.proxyMode)
    }

    /**
     * A still-open site opened again on the same profile, whose new route is
     * refused (say, switched to a proxy that is down): its last binding must
     * end, or the profile went on being routed by its old settings, and its
     * pooled tunnels stayed open, until the next close.
     */
    @Test fun `a reopen whose route is refused ends the site's last binding`() {
        val credentials = SiteCredentials()
        val last = binding("p1", mode = "direct")
        credentials.openSession(null, "p1", last)

        credentials.openSession("p1", "p1", null)

        val credential = credentials.credentialFor("p1")
        assertNull(credentials.lookup(credential.user, credential.password))
        assertTrue(last.isRevoked)
    }

    @Test fun `a credential never finds another profile's site`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1"))
        credentials.bind("p2", binding("p2"))
        val credential = credentials.credentialFor("p2")
        assertEquals("site-p2", credentials.lookup(credential.user, credential.password)!!.config.siteId)
    }

    @Test fun `a wrong password or a rearranged pair finds nothing`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1"))
        val credential = credentials.credentialFor("p1")
        assertNull(credentials.lookup(credential.user, "0".repeat(32)))
        assertNull(credentials.lookup(credential.password, credential.user))
        assertNull(credentials.lookup("${credential.user}:${credential.password}", ""))
    }

    @Test fun `a credential never prints itself`() {
        val credential = SiteCredentials().credentialFor("p1")
        assertFalse(credential.toString().contains(credential.user))
        assertFalse(credential.toString().contains(credential.password))
    }

    @Test fun `the proxy's own challenge is answered with the profile's credential`() {
        val credential = SiteCredentials().credentialFor("p1")
        assertSame(credential, proxyAuthAnswer("127.0.0.1", "container") { credential })
    }

    /** Review Focus 5: a site's own HTTP auth never gets the proxy credential. */
    @Test fun `a site's own challenge gets no credential`() {
        val never: () -> ProxyCredential = { throw AssertionError("a site's challenge must not read the credential") }
        assertNull(proxyAuthAnswer("forum.example.com", "container", never))
        assertNull(proxyAuthAnswer("127.0.0.1", "Members only", never))
        assertNull(proxyAuthAnswer(null, null, never))
    }
}

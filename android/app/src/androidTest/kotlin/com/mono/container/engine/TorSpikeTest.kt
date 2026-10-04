package com.mono.container.engine

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Built-in Tor spec §4.4's spike, on a device against the real Tor network:
 * tor-android with a Unix SOCKS port, TLS over [StreamSocket] on Android's
 * provider, no TCP listener of ours, and a second start after a stop.
 */
@RunWith(AndroidJUnit4::class)
class TorSpikeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    private fun onMain(block: () -> Unit) = instrumentation.runOnMainSync(block)

    private fun site() = SiteConfig(
        siteId = "spike", profileId = "spike-profile", url = "https://check.torproject.org",
        proxyMode = "tor", proxyHost = null, proxyPort = null,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    private fun listening(port: Int) = runCatching {
        Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), 500) }
        true
    }.getOrDefault(false)

    private fun isTorBody(): String {
        val route = Router.resolve(site(), proxyReachable = true, torSocket = TorFiles.socket(context.filesDir).absolutePath)
        val response = ProxyHttpClient.fetch(route, "check.torproject.org", 443, true, "GET", "/api/ip", emptyMap())
        return response.body.readBytes().toString(Charsets.UTF_8)
    }

    @Test(timeout = 600_000)
    fun torRunsOverItsUnixSocketCarriesTlsAndStartsAgain() {
        val runtime = TorRuntime(TorServiceDaemon(context))
        onMain { runtime.hold("spike") }
        assertTrue("Tor did not bootstrap", runtime.awaitReady("spike"))

        // Plan D3: neither of the library's default TCP ports is open.
        assertFalse("9050 is listening", listening(9050))
        assertFalse("8118 is listening", listening(8118))

        val body = isTorBody()
        assertTrue(body, body.contains("\"IsTor\":true"))

        // release() lingers, so stop at once to make the next hold a real second start.
        onMain { runtime.stopAll() }
        Thread.sleep(5_000)

        onMain { runtime.hold("spike") }
        assertTrue("Tor did not bootstrap a second time", runtime.awaitReady("spike"))
        val again = isTorBody()
        assertTrue(again, again.contains("\"IsTor\":true"))
        onMain { runtime.stopAll() }
    }
}

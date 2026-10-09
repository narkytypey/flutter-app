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
 * provider, no TCP listener of ours, and a second start after a stop, each
 * run in a `:tor` process of its own.
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

    /**
     * [isTorBody], tried up to [attempts] times on the same Tor: an exit relay
     * can drop a new stream (`connection closed` in the TLS handshake), which
     * says nothing about the run. Each failure is logged, so the rate shows.
     */
    private fun isTorBodyWithin(attempts: Int, label: String): String {
        var last: Exception? = null
        repeat(attempts) { attempt ->
            try {
                return isTorBody()
            } catch (e: java.io.IOException) {
                android.util.Log.w("TorSpikeTest", "$label attempt ${attempt + 1}: $e")
                last = e
            }
        }
        throw last!!
    }

    @Test(timeout = 600_000)
    fun torRunsOverItsUnixSocketCarriesTlsAndStartsAgain() {
        val runtime = TorRuntime(TorProcessDaemon(context))
        try {
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
        } finally {
            onMain { runtime.stopAll() }
        }
    }

    /** True once [present] matches whether the system lists a `:tor` process, polled for at most [withinMs]. */
    private fun torProcess(present: Boolean, withinMs: Long): Boolean {
        val deadline = System.currentTimeMillis() + withinMs
        while (System.currentTimeMillis() < deadline) {
            if (torProcessPids(context).isNotEmpty() == present) return true
            Thread.sleep(100)
        }
        return torProcessPids(context).isNotEmpty() == present
    }

    /**
     * Tor cannot be run twice in one process (`tor_api.h`, Tor bug 23847): on
     * a device the fourth run in the app's process aborted it, `SIGABRT` in
     * `pubsub_install` (2026-10-09). Each run now has a `:tor` process of its
     * own: six starts in this one process each bootstrap in a new `:tor` and
     * carry a request over Tor, Tor never runs here, and every stop leaves no `:tor` process behind.
     */
    @Test(timeout = 900_000)
    fun everyRunHasAProcessOfItsOwnAndAStopEndsIt() {
        assertTrue("an earlier :tor process is still listed", torProcess(false, 15_000))
        val runtime = TorRuntime(TorProcessDaemon(context))
        val pids = mutableListOf<Int>()
        try {
            repeat(6) { run ->
                onMain { runtime.hold("run") }
                assertTrue("run ${run + 1}: Tor did not bootstrap", runtime.awaitReady("run"))
                val listed = torProcessPids(context)
                assertTrue("run ${run + 1}: one :tor process, not $listed", listed.size == 1)
                pids += listed.single()
                assertTrue("run ${run + 1}: Tor ran in the app's process", liveTorThreads().isEmpty())
                val body = isTorBodyWithin(attempts = 3, label = "run ${run + 1}")
                assertTrue("run ${run + 1}: $body", body.contains("\"IsTor\":true"))
                onMain { runtime.stopAll() }
                assertTrue("run ${run + 1}: the :tor process outlived the stop", torProcess(false, 10_000))
            }
        } finally {
            onMain { runtime.stopAll() }
        }
        assertTrue("a :tor process served two runs: $pids", pids.toSet().size == pids.size)
    }

    /** A stop before Tor has even connected still leaves no `:tor` process, and the next run bootstraps. */
    @Test(timeout = 600_000)
    fun anEarlyStopEndsTorAndTheNextRunStarts() {
        assertTrue("an earlier :tor process is still listed", torProcess(false, 15_000))
        val runtime = TorRuntime(TorProcessDaemon(context))
        try {
            onMain { runtime.hold("early") }
            assertTrue(":tor never started", torProcess(true, 10_000))
            onMain { runtime.stopAll() }
            assertTrue("the :tor process outlived an early stop", torProcess(false, 10_000))

            onMain { runtime.hold("next") }
            assertTrue("Tor did not bootstrap after an early stop", runtime.awaitReady("next"))
            val body = isTorBody()
            assertTrue(body, body.contains("\"IsTor\":true"))
        } finally {
            onMain { runtime.stopAll() }
        }
        assertTrue("the :tor process outlived the last stop", torProcess(false, 10_000))
    }
}

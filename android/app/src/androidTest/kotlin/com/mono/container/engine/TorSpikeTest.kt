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

    /** True once [alive] matches whether a thread named `tor` is alive, polled for at most [withinMs]. */
    private fun torAlive(alive: Boolean, withinMs: Long, pollMs: Long = 100): Boolean {
        val deadline = System.currentTimeMillis() + withinMs
        while (System.currentTimeMillis() < deadline) {
            if (liveTorThreads().isNotEmpty() == alive) return true
            Thread.sleep(pollMs)
        }
        return liveTorThreads().isNotEmpty() == alive
    }

    private fun torEnds(withinMs: Long) = torAlive(false, withinMs)

    /**
     * Plan 19 final review, Important #1 and #2 (`TorRuns`), on a device: a
     * stop before Tor's control connection exists still ends Tor, and a start
     * right after a stop never runs a second `tor_run_main` beside the old one.
     * Before `08489c2` the second can also show as the process aborting in
     * `pubsub_install`; that is a failure too.
     */
    @Test(timeout = 600_000)
    fun anEarlyStopEndsTorAndAQuickStartNeverRunsTwo() {
        // Another test's Tor still exiting would make the next hold wait, and
        // the early stop would then cancel a start that never ran.
        assertTrue("an earlier Tor is still running", torEnds(15_000))
        var most = 0
        val sampling = Thread {
            while (!Thread.currentThread().isInterrupted) {
                most = maxOf(most, liveTorThreads().size)
                try { Thread.sleep(20) } catch (_: InterruptedException) { break }
            }
        }.apply { isDaemon = true; start() }
        val runtime = TorRuntime(TorServiceDaemon(context))
        try {
            onMain { runtime.hold("early") }
            // tor_run_main has begun, so the control connection is at most just
            // opening. Whether the stop took its HALT path cannot be seen from
            // here (ServiceRun.controllable is private): check logcat.
            assertTrue("Tor never started", torAlive(true, 10_000, pollMs = 5))
            onMain { runtime.stopAll() }
            // The stop waits 5 s for the control connection, then settles.
            assertTrue("Tor outlived a stop before its control connection (most $most)", torEnds(30_000))

            onMain { runtime.hold("quick") }
            assertTrue("Tor did not bootstrap (most $most)", runtime.awaitReady("quick"))
            onMain { runtime.stopAll() }
            onMain { runtime.hold("quick") }
            assertTrue(
                "Tor did not bootstrap right after a stop: the network, or the old Tor took over 10 s to exit (most $most)",
                runtime.awaitReady("quick"),
            )
            val body = isTorBody()
            assertTrue(body, body.contains("\"IsTor\":true"))
            onMain { runtime.stopAll() }
            assertTrue("Tor outlived the last stop (most $most)", torEnds(15_000))
        } finally {
            onMain { runtime.stopAll() }
            sampling.interrupt()
            sampling.join()
        }
        assertTrue("$most tor threads were alive at once", most <= 1)
    }
}

package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Built-in Tor spec §4.2–§4.3: when Tor runs, and what a waiting open hears. */
class TorRuntimeTest {

    /** Counts starts and stops; the test speaks for Tor through [events]. */
    private class FakeTor : TorDaemon {
        var starts = 0
        var stops = 0
        @Volatile var events: TorEvents? = null
        override fun start(events: TorEvents) {
            starts++
            this.events = events
        }
        override fun stop() {
            stops++
        }
    }

    /** Captures the linger stop; the test runs it when the delay would have passed. */
    private class Sched {
        val tasks = mutableListOf<() -> Unit>()
        val delays = mutableListOf<Long>()
        fun schedule(delay: Long, task: () -> Unit) {
            delays += delay
            tasks += task
        }
        fun runAll() = tasks.toList().also { tasks.clear() }.forEach { it() }
    }

    /** A large [pollMs] makes the wake-up signal load-bearing; the stall tests pass a small one. */
    private fun runtime(tor: FakeTor, stallMs: Long = 60_000, pollMs: Long = 60_000, sched: Sched = Sched()) =
        TorRuntime(tor, stallMs = stallMs, pollMs = pollMs, schedule = sched::schedule)

    /** [TorRuntime.awaitReady] on another thread, as an open runs it; the returned
     *  function gives its answer, or null if it had none within 5 s. */
    private fun waitOn(runtime: TorRuntime, holder: String, heard: MutableList<Int> = mutableListOf()): () -> Boolean? {
        val answer = AtomicReference<Boolean?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(runtime.awaitReady(holder) { synchronized(heard) { heard += it } })
            done.countDown()
        }.start()
        return { if (done.await(5, TimeUnit.SECONDS)) answer.get() else null }
    }

    private fun eventually(condition: () -> Boolean) {
        val until = System.currentTimeMillis() + 5_000
        while (!condition()) {
            check(System.currentTimeMillis() < until) { "condition never held" }
            Thread.sleep(5)
        }
    }

    @Test fun `nothing starts Tor until a site holds it`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        assertEquals(0, tor.starts)
        assertEquals(TorRuntime.State.Off, runtime.state)
        assertFalse(runtime.isReady)
    }

    @Test fun `the first hold starts Tor and a second joins the same start`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        assertEquals(1, tor.starts)
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }

    @Test fun `a waiting open hears the percentage and is let through at 100`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val heard = mutableListOf<Int>()
        val answer = waitOn(runtime, "a", heard)

        tor.events!!.progress(45)
        eventually { synchronized(heard) { 45 in heard } }
        tor.events!!.progress(100)

        assertEquals(true, answer())
        assertTrue(runtime.isReady)
        assertEquals(1, tor.starts)
    }

    @Test fun `a hold while Tor is ready waits for nothing`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.progress(100)
        runtime.hold("b")
        assertTrue(runtime.awaitReady("b"))
        assertEquals(1, tor.starts)
    }

    @Test fun `the last release lets a waiting open go and stops Tor after the linger`() {
        val tor = FakeTor()
        val sched = Sched()
        val runtime = runtime(tor, sched = sched)
        runtime.hold("a")
        val answer = waitOn(runtime, "a")

        runtime.release("a")

        assertEquals(false, answer())
        assertEquals(0, tor.stops)
        assertEquals(listOf(TorRuntime.LINGER_MS), sched.delays)
        sched.runAll()
        assertEquals(1, tor.stops)
        assertEquals(TorRuntime.State.Off, runtime.state)
    }

    @Test fun `a hold during the linger keeps the same run`() {
        val tor = FakeTor()
        val sched = Sched()
        val runtime = runtime(tor, sched = sched)
        runtime.hold("a")
        runtime.release("a")
        runtime.hold("b")
        val state = runtime.state

        sched.runAll()

        assertEquals(0, tor.stops)
        assertEquals(1, tor.starts)
        assertEquals(state, runtime.state)
    }

    @Test fun `a release, hold and release again stops only after the last linger`() {
        val tor = FakeTor()
        val sched = Sched()
        val runtime = runtime(tor, sched = sched)
        runtime.hold("a")
        runtime.release("a")
        runtime.hold("a")
        runtime.release("a")
        sched.tasks.first()()
        assertEquals(0, tor.stops)
        sched.tasks.last()()
        assertEquals(1, tor.stops)
    }

    @Test fun `the linger stop is cancelled by stopAll`() {
        val tor = FakeTor()
        val sched = Sched()
        val runtime = runtime(tor, sched = sched)
        runtime.hold("a")
        runtime.release("a")
        runtime.stopAll()
        assertEquals(1, tor.stops)

        sched.runAll()

        assertEquals(1, tor.stops)
    }

    /** Review Focus 2. */
    @Test fun `releasing one of two holders keeps Tor running for the other`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        val first = waitOn(runtime, "a")
        val second = waitOn(runtime, "b")

        runtime.release("a")
        assertEquals(false, first())
        assertEquals(0, tor.stops)

        tor.events!!.progress(100)
        assertEquals(true, second())
    }

    @Test fun `a failure refuses every waiting open and stops Tor`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        val first = waitOn(runtime, "a")
        val second = waitOn(runtime, "b")

        tor.events!!.failed()

        assertEquals(false, first())
        assertEquals(false, second())
        assertEquals(1, tor.stops)
        assertEquals(TorRuntime.State.Failed, runtime.state)
    }

    /** Spec §4.3: no new percentage for the stall time is a failure. */
    @Test fun `progress that stops moving for the stall time fails Tor`() {
        val tor = FakeTor()
        val runtime = runtime(tor, stallMs = 100, pollMs = 10)
        runtime.hold("a")
        tor.events!!.progress(30)

        assertEquals(false, waitOn(runtime, "a")())
        assertEquals(TorRuntime.State.Failed, runtime.state)
        assertEquals(1, tor.stops)
    }

    @Test fun `the same percentage again does not count as moving`() {
        val tor = FakeTor()
        val runtime = runtime(tor, stallMs = 150, pollMs = 10)
        runtime.hold("a")
        tor.events!!.progress(30)
        val answer = waitOn(runtime, "a")
        repeat(10) {
            tor.events!!.progress(30)
            Thread.sleep(20)
        }
        assertEquals(false, answer())
    }

    @Test fun `a hold after a failure starts Tor again`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.failed()

        runtime.hold("a")

        assertEquals(2, tor.starts)
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }

    @Test fun `a stopped run's late events count for nothing`() {
        val tor = FakeTor()
        val sched = Sched()
        val runtime = runtime(tor, sched = sched)
        runtime.hold("a")
        val old = tor.events!!
        runtime.release("a")
        sched.runAll()
        runtime.hold("a")

        old.progress(100)
        assertFalse(runtime.isReady)
        old.failed()
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }

    /** Review Focus 3: a live site's Tor dying must read as not ready. */
    @Test fun `Tor failing after it was ready leaves it not ready`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.progress(100)
        assertTrue(runtime.isReady)

        tor.events!!.failed()

        assertFalse(runtime.isReady)
        assertEquals(TorRuntime.State.Failed, runtime.state)
        assertEquals(1, tor.stops)
    }

    /** Review Focus 1: a lock ends every wait and stops Tor. */
    @Test fun `stopAll lets go of every holder and every waiter`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        val first = waitOn(runtime, "a")
        val second = waitOn(runtime, "b")

        runtime.stopAll()

        assertEquals(false, first())
        assertEquals(false, second())
        assertEquals(1, tor.stops)
        runtime.hold("c")
        assertEquals(2, tor.starts)
    }

    @Test fun `stopAll after a failure does not stop Tor twice`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.failed()
        runtime.stopAll()
        assertEquals(1, tor.stops)
        assertEquals(TorRuntime.State.Off, runtime.state)
    }

    @Test fun `releasing a site that never held Tor changes nothing`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.release("z")
        assertEquals(0, tor.stops)
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }

    private fun torSite(siteId: String = "a") = SiteConfig(
        siteId = siteId, profileId = "p-$siteId", url = "https://check.torproject.org",
        proxyMode = "tor", proxyHost = null, proxyPort = null,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    @Test fun `an open of another route resolves as it always has`() {
        val direct = torSite().copy(proxyMode = "direct")
        assertEquals(Route.Direct, routeForOpen(direct, null, null, {}) { Route.Direct })
    }

    @Test fun `a Tor open waits, hears the percentage, and gets Tor's route`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val heard = mutableListOf<Int>()
        val answer = AtomicReference<Route?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(routeForOpen(torSite(), runtime, "/s", { synchronized(heard) { heard += it } }))
            done.countDown()
        }.start()

        tor.events!!.progress(60)
        eventually { synchronized(heard) { 60 in heard } }
        tor.events!!.progress(100)

        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertTrue(synchronized(heard) { 100 in heard })
        assertEquals(Route.Tor("/s", perSiteLogin("p-a")), answer.get())
    }

    @Test fun `a Tor open whose Tor fails is refused, never direct`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val answer = AtomicReference<Route?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(routeForOpen(torSite(), runtime, "/s", {}))
            done.countDown()
        }.start()

        tor.events!!.failed()

        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), answer.get())
    }

    /** Review Focus 1: a lock (stopAll) while the open waits. */
    @Test fun `a Tor open let go of while it waits is refused`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val answer = AtomicReference<Route?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(routeForOpen(torSite(), runtime, "/s", {}))
            done.countDown()
        }.start()

        runtime.stopAll()

        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), answer.get())
    }

    @Test fun `a Tor open with no Tor installed is refused`() {
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), routeForOpen(torSite(), null, null, {}))
    }
}

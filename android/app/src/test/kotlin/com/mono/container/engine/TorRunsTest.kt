package com.mono.container.engine

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Plan 19 final review, Important #1 and #2: a second `tor_run_main` never
 * starts while the old `tor` thread lives, and a stop that comes before Tor's
 * control connection exists does not orphan Tor.
 *
 * The old Tor is a real thread named `tor`, as tor-android names it, so the
 * production probe is the one under test.
 */
class TorRunsTest {

    private val log: MutableList<String> = Collections.synchronizedList(mutableListOf())

    /** Speaks for one bound service. [onHalt] lets a test end its Tor when told to. */
    private inner class FakeRun(val name: String) : TorRun {
        @Volatile override var connected = false
        @Volatile override var controllable = false
        @Volatile var bindThrows = false
        @Volatile var torAliveAtBind: Boolean? = null
        @Volatile var bindThread: String? = null
        @Volatile var unbindThread: String? = null
        @Volatile var onHalt: () -> Unit = {}

        override fun bind() {
            torAliveAtBind = torAlive()
            bindThread = Thread.currentThread().name
            log += "$name bind"
            if (bindThrows) throw IllegalStateException("not bound")
        }

        override fun quiet() {
            log += "$name quiet"
        }

        override fun unbind() {
            unbindThread = Thread.currentThread().name
            log += "$name unbind"
        }

        override fun halt() {
            log += "$name halt"
            onHalt()
        }
    }

    private class Events : TorEvents {
        val failures = AtomicInteger()
        override fun progress(percent: Int) = Unit
        override fun failed() {
            failures.incrementAndGet()
        }
    }

    private val mainThread = Executors.newSingleThreadExecutor { Thread(it, "main") }
    private val mainPosts = AtomicInteger()
    private val oldTors = mutableListOf<CountDownLatch>()

    private fun main(task: () -> Unit) {
        mainPosts.incrementAndGet()
        mainThread.execute(task)
    }

    /** A thread named `tor`, alive until the returned latch is counted down. */
    private fun liveTor(): CountDownLatch {
        val exit = CountDownLatch(1)
        oldTors += exit
        val started = CountDownLatch(1)
        Thread({
            started.countDown()
            exit.await()
        }, "tor").apply { isDaemon = true }.start()
        started.await()
        return exit
    }

    private fun torAlive() = Thread.getAllStackTraces().keys.any { it.name == "tor" && it.isAlive }

    private fun endTor(exit: CountDownLatch) {
        exit.countDown()
        eventually { !torAlive() }
    }

    @After fun tearDown() {
        oldTors.forEach { it.countDown() }
        eventually { !torAlive() }
        mainThread.shutdownNow()
    }

    private fun eventually(condition: () -> Boolean) {
        val until = System.currentTimeMillis() + 5_000
        while (!condition()) {
            check(System.currentTimeMillis() < until) { "condition never held; log: $log" }
            Thread.sleep(5)
        }
    }

    /** Lets every task already posted to the fake main thread run. */
    private fun drainMain() {
        mainThread.submit {}.get(5, TimeUnit.SECONDS)
    }

    private fun runs(
        made: MutableList<FakeRun>,
        joinMs: Long = 2_000,
        controlWaitMs: Long = 2_000,
    ) = TorRuns(
        newRun = { FakeRun(('a' + made.size).toString()).also { made += it } },
        main = ::main,
        joinMs = joinMs,
        controlWaitMs = controlWaitMs,
        settleMs = 20,
        pollMs = 5,
    )

    // Important #1: never a second tor_run_main beside a live one.

    @Test fun `with no tor thread alive, start binds at once on the calling thread`() {
        val made = mutableListOf<FakeRun>()
        runs(made).start(Events())
        assertEquals(listOf("a bind"), log.toList())
        assertEquals(Thread.currentThread().name, made[0].bindThread)
        assertEquals(0, mainPosts.get())
    }

    @Test fun `a live tor thread defers the bind, on the main thread, until it has died`() {
        val made = mutableListOf<FakeRun>()
        val old = liveTor()
        runs(made).start(Events())
        Thread.sleep(200)
        assertFalse("bound beside a live tor thread: $log", "a bind" in log)

        old.countDown()
        eventually { "a bind" in log }
        assertEquals(false, made[0].torAliveAtBind)
        assertEquals("main", made[0].bindThread)
    }

    @Test fun `a tor thread still alive after the bound fails the run and never binds`() {
        val made = mutableListOf<FakeRun>()
        liveTor()
        val events = Events()
        runs(made, joinMs = 200).start(events)
        eventually { events.failures.get() == 1 }
        drainMain()
        assertFalse("a bind" in log)
        assertEquals(1, events.failures.get())
    }

    @Test fun `a stop during the wait cancels the deferred bind`() {
        val made = mutableListOf<FakeRun>()
        val old = liveTor()
        val events = Events()
        val runs = runs(made)
        runs.start(events)
        runs.stop()
        endTor(old)
        Thread.sleep(100)
        drainMain()
        assertFalse("a bind" in log)
        assertFalse("a unbind" in log)
        assertEquals(0, events.failures.get())
    }

    @Test fun `a bind that throws fails the run and lets go of whatever it registered`() {
        val made = mutableListOf<FakeRun>()
        val events = Events()
        val runs = TorRuns(
            newRun = { FakeRun("a").also { it.bindThrows = true; made += it } },
            main = ::main,
        )
        runs.start(events)
        assertEquals(1, events.failures.get())
        assertTrue("a unbind" in log)
    }

    // Important #2: a stop before the control connection exists.

    @Test fun `a stop before the control connection exists keeps the binding, then halts Tor and unbinds`() {
        val made = mutableListOf<FakeRun>()
        val runs = runs(made)
        runs.start(Events())
        val run = made[0]
        val tor = liveTor() // the service's own tor thread, inside tor_run_main
        run.onHalt = { tor.countDown() }

        runs.stop()
        assertEquals("heard nothing more at once", listOf("a bind", "a quiet"), log.toList())
        Thread.sleep(100)
        assertFalse("unbound before Tor could be told to stop: $log", "a unbind" in log)

        run.connected = true
        run.controllable = true
        eventually { "a unbind" in log }
        assertTrue(log.indexOf("a halt") in 0 until log.indexOf("a unbind"))
        assertEquals("main", run.unbindThread)
    }

    @Test fun `a stop whose control connection never appears unbinds after the bound, without halting`() {
        val made = mutableListOf<FakeRun>()
        val runs = runs(made, controlWaitMs = 200)
        runs.start(Events())
        liveTor()
        val stoppedAt = System.nanoTime()
        runs.stop()
        eventually { "a unbind" in log }
        assertTrue((System.nanoTime() - stoppedAt) / 1_000_000 >= 200)
        assertFalse("a halt" in log)
    }

    @Test fun `a stop with the control connection up unbinds at once`() {
        val made = mutableListOf<FakeRun>()
        val runs = runs(made)
        runs.start(Events())
        liveTor()
        made[0].connected = true
        made[0].controllable = true
        runs.stop()
        assertTrue("a unbind" in log)
        assertFalse("a halt" in log)
    }

    @Test fun `a stop of a connected run whose tor thread has ended unbinds at once`() {
        val made = mutableListOf<FakeRun>()
        val runs = runs(made)
        runs.start(Events())
        made[0].connected = true
        runs.stop()
        assertTrue("a unbind" in log)
    }

    @Test fun `a start while the last stop still waits binds only after that stop has halted and unbound`() {
        val made = mutableListOf<FakeRun>()
        val runs = runs(made)
        runs.start(Events())
        val first = made[0]
        val tor = liveTor()
        first.onHalt = { tor.countDown() }
        runs.stop()

        runs.start(Events())
        Thread.sleep(100)
        assertFalse("b bind" in log)

        first.connected = true
        first.controllable = true
        eventually { "b bind" in log }
        val order = listOf("a halt", "a unbind", "b bind").map(log::indexOf)
        assertEquals("$log", order.sorted(), order)
        assertTrue(order.all { it >= 0 })
        assertEquals(false, made[1].torAliveAtBind)
    }
}

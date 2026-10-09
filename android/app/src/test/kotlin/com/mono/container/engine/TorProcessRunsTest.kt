package com.mono.container.engine

import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Collections
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * Every Tor run in a process of its own: Tor cannot be run twice in one
 * process (`tor_api.h`, BUG 23847; the fourth run aborted the app with
 * `SIGABRT` in `pubsub_install`). A start kills whatever `:tor` process is
 * left and binds only once it is gone; a stop kills it at once; a `:tor`
 * process that dies by itself is a failed run, not a dead app.
 */
class TorProcessRunsTest {

    private val log: MutableList<String> = Collections.synchronizedList(mutableListOf())

    /** The `:tor` processes the system lists, by pid. */
    private val processes: MutableList<Int> = Collections.synchronizedList(mutableListOf())
    private var nextPid = 100

    /** Pids a kill leaves listed until [reap]; the rest vanish at once. */
    private val lingering: MutableSet<Int> = Collections.synchronizedSet(mutableSetOf())

    private inner class FakeLink(val name: String) : TorHostLink {
        @Volatile var events: TorEvents? = null
        @Volatile var bindThrows = false
        @Volatile var processesAtBind: List<Int>? = null
        @Volatile var pid = -1

        override fun bind(events: TorEvents) {
            processesAtBind = processes.toList()
            log += "$name bind"
            if (bindThrows) throw IllegalStateException("not bound")
            this.events = events
            pid = nextPid++
            processes += pid
        }

        override fun unbind() {
            log += "$name unbind"
        }
    }

    private class Events : TorEvents {
        val failures = AtomicInteger()
        val percents: MutableList<Int> = Collections.synchronizedList(mutableListOf())
        override fun progress(percent: Int) {
            percents += percent
        }
        override fun failed() {
            failures.incrementAndGet()
        }
    }

    private val mainThread = Executors.newSingleThreadExecutor { Thread(it, "main") }

    private fun main(task: () -> Unit) {
        mainThread.execute(task)
    }

    private fun kill(pid: Int) {
        log += "kill $pid"
        if (pid !in lingering) processes.remove(pid)
    }

    private fun reap(pid: Int) {
        lingering.remove(pid)
        processes.remove(pid)
    }

    private val links = mutableListOf<FakeLink>()

    private fun runs(goneWaitMs: Long = 2_000) = TorProcessRuns(
        newLink = { FakeLink("run${links.size + 1}").also { links += it } },
        torProcesses = { processes.toList() },
        kill = ::kill,
        main = ::main,
        goneWaitMs = goneWaitMs,
        pollMs = 5,
    )

    /** Runs [block] on the fake main thread and waits for it, as the engine's open and close do. */
    private fun onMain(block: () -> Unit) {
        val done = CountDownLatch(1)
        main {
            try {
                block()
            } finally {
                done.countDown()
            }
        }
        assertTrue(done.await(5, TimeUnit.SECONDS))
    }

    /** Waits for every task already posted to the fake main thread. */
    private fun drainMain() = onMain {}

    private fun eventually(what: String, check: () -> Boolean) {
        val deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5)
        while (!check()) {
            if (System.nanoTime() > deadline) throw AssertionError("never: $what; log $log")
            Thread.sleep(5)
        }
    }

    @After
    fun tearDown() {
        mainThread.shutdownNow()
    }

    @Test
    fun `with no tor process left, a start binds at once`() {
        val runs = runs()
        onMain { runs.start(Events()) }
        assertEquals(listOf("run1 bind"), log)
        assertEquals(emptyList<Int>(), links[0].processesAtBind)
    }

    @Test
    fun `a stop unbinds and kills the tor process at once`() {
        val runs = runs()
        onMain { runs.start(Events()) }
        val pid = links[0].pid
        onMain { runs.stop() }
        assertEquals(listOf("run1 bind", "run1 unbind", "kill $pid"), log)
        assertEquals(emptyList<Int>(), processes)
    }

    @Test
    fun `every start after a stop binds in a new process, never the old one`() {
        val runs = runs()
        repeat(6) {
            onMain { runs.start(Events()) }
            eventually("run ${it + 1} bound") { links.size == it + 1 && links[it].events != null }
            onMain { runs.stop() }
        }
        assertEquals(6, links.map { it.pid }.toSet().size)
        links.forEach { assertEquals(emptyList<Int>(), it.processesAtBind) }
    }

    @Test
    fun `a start kills a leftover tor process and binds only once it is gone`() {
        processes += 7
        lingering += 7
        val runs = runs()
        onMain { runs.start(Events()) }
        eventually("leftover killed") { "kill 7" in log }
        drainMain()
        assertTrue("bound beside the old process: $log", "run1 bind" !in log)
        reap(7)
        eventually("bound") { "run1 bind" in log }
        assertEquals(emptyList<Int>(), links[0].processesAtBind)
    }

    @Test
    fun `a leftover that never goes fails the run instead of binding beside it`() {
        processes += 7
        lingering += 7
        val runs = runs(goneWaitMs = 100)
        val events = Events()
        onMain { runs.start(events) }
        eventually("failed") { events.failures.get() == 1 }
        drainMain()
        assertTrue("bound beside the old process: $log", "run1 bind" !in log)
    }

    @Test
    fun `a stop while the start waits for the leftover cancels the bind`() {
        processes += 7
        lingering += 7
        val runs = runs()
        val events = Events()
        onMain { runs.start(events) }
        eventually("leftover killed") { "kill 7" in log }
        onMain { runs.stop() }
        reap(7)
        Thread.sleep(50)
        drainMain()
        assertTrue("bound after its stop: $log", "run1 bind" !in log)
        assertEquals(0, events.failures.get())
    }

    @Test
    fun `progress reaches the runtime while the run is current`() {
        val runs = runs()
        val events = Events()
        onMain { runs.start(events) }
        links[0].events!!.progress(40)
        links[0].events!!.progress(100)
        assertEquals(listOf(40, 100), events.percents)
    }

    @Test
    fun `nothing a stopped run says reaches the runtime`() {
        val runs = runs()
        val events = Events()
        onMain { runs.start(events) }
        val stale = links[0].events!!
        onMain { runs.stop() }
        stale.progress(50)
        stale.failed()
        assertEquals(emptyList<Int>(), events.percents)
        assertEquals(0, events.failures.get())
    }

    @Test
    fun `a tor process that dies by itself fails the run once, and its leftovers are killed`() {
        val runs = runs()
        val events = Events()
        onMain { runs.start(events) }
        val pid = links[0].pid
        val link = links[0].events!!
        link.failed()
        link.failed()
        assertEquals(1, events.failures.get())
        assertTrue(log.containsAll(listOf("run1 unbind", "kill $pid")))
        // The runtime then stops the failed run: nothing more to do.
        onMain { runs.stop() }
        assertEquals(1, log.count { it == "run1 unbind" })
    }

    @Test
    fun `a bind the system refuses fails the run`() {
        val runs = TorProcessRuns(
            newLink = { FakeLink("run1").apply { bindThrows = true }.also { links += it } },
            torProcesses = { processes.toList() },
            kill = ::kill,
            main = ::main,
        )
        val events = Events()
        onMain { runs.start(events) }
        assertEquals(1, events.failures.get())
    }
}

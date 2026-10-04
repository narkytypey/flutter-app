package com.mono.container.engine

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/** tor-android's `TorService` names the thread that runs `tor_run_main` this (checked with `javap`). */
internal const val TOR_THREAD_NAME = "tor"

/**
 * Every live thread named [TOR_THREAD_NAME]: a Tor still inside
 * `tor_run_main`, or tearing down after it. None of the app's own threads
 * has that name (they are `tor-bootstrap`, `tor-linger` and `tor-wait`).
 * Enumerated from the root thread group rather than with
 * `Thread.getAllStackTraces`, which would capture every thread's stack on
 * the main thread.
 */
internal fun liveTorThreads(): List<Thread> {
    var root = Thread.currentThread().threadGroup ?: return emptyList()
    while (true) root = root.parent ?: break
    // enumerate drops whatever does not fit, so leave room for threads started meanwhile.
    val threads = arrayOfNulls<Thread>(root.activeCount() * 2 + 16)
    val count = root.enumerate(threads, true)
    return threads.take(count).filterNotNull().filter { it.name == TOR_THREAD_NAME && it.isAlive }
}

/** One tor-android run as [TorRuns] drives it: the bound service on a device, a fake in the JVM tests. */
internal interface TorRun {
    /** Registers for the service's broadcasts and binds it. Main thread; throws if it cannot. */
    fun bind()

    /** Stops hearing the run: nothing it says reaches [TorRuntime] afterwards. Any thread. */
    fun quiet()

    /** [quiet], then lets go of the binding (destroying the service), if [bind] got that far. Idempotent. */
    fun unbind()

    /** The service has connected. */
    val connected: Boolean

    /** The service has connected and its control connection to Tor exists. */
    val controllable: Boolean

    /** Tells Tor to exit at once over the control connection (`SIGNAL HALT`). */
    fun halt()
}

/**
 * The order of tor-android runs (Plan 19 final review, Important #1 and #2),
 * kept free of Android so the JVM tests can drive it.
 *
 * - **Never two `tor_run_main`s.** `TorService.onDestroy` releases its run
 *   lock before Tor has even been asked to exit, so a new service can start a
 *   second Tor beside the old one, which aborts the process (`SIGABRT` in
 *   `pubsub_install`). A start therefore binds only once the last stop has
 *   let go of its service and no thread named `tor` is alive. It waits off
 *   the main thread, at most [joinMs], then binds on the main thread; an old
 *   Tor still alive after that fails the run (`8b`, Try again), never a
 *   second Tor. A stop during the wait cancels the bind. Because the old
 *   `tor` thread's last broadcast (`STOPPING`) is sent before it dies, and
 *   the receiver is registered only at the bind, the new run cannot hear it.
 * - **A stop never orphans Tor.** `onDestroy` asks Tor to exit only over the
 *   control connection, which exists only some time after the service
 *   starts. A stop before then keeps the binding and waits off the main
 *   thread, at most [controlWaitMs], for the connection; [settleMs] after it
 *   appears (the service authenticates on it first, and Tor drops a
 *   connection whose first command is anything else) it sends `HALT`, then
 *   unbinds. If it never appears the stop unbinds anyway. Either way the run
 *   is quiet at once, so [TorRuntime] hears nothing more from it.
 *
 * [start] and [stop] are serialised by [TorRuntime]'s lock, on any thread.
 * [TorEvents.failed] is never called holding this class's lock, which would
 * invert the order against [TorRuntime]'s.
 */
internal class TorRuns(
    private val newRun: (TorEvents) -> TorRun,
    private val main: (() -> Unit) -> Unit,
    private val background: (() -> Unit) -> Unit = { Thread(it, "tor-wait").apply { isDaemon = true }.start() },
    private val torThreads: () -> List<Thread> = ::liveTorThreads,
    private val joinMs: Long = JOIN_MS,
    private val controlWaitMs: Long = CONTROL_WAIT_MS,
    private val settleMs: Long = SETTLE_MS,
    private val pollMs: Long = WAIT_POLL_MS,
) : TorDaemon {

    private class Entry(val run: TorRun, val events: TorEvents) {
        /** Both guarded by the entry itself. */
        var stopped = false
        var bound = false
    }

    private val lock = Any()
    private var current: Entry? = null

    /** Counted down once the last waiting stop has unbound. At most one is pending: a run binds only after it. */
    private var retiring: CountDownLatch? = null

    override fun start(events: TorEvents) {
        val entry = Entry(newRun(events), events)
        val waitFor: CountDownLatch?
        synchronized(lock) {
            current = entry
            waitFor = retiring?.takeIf { it.count > 0 }
        }
        if (waitFor == null && torThreads().isEmpty()) {
            bind(entry)
            return
        }
        background {
            val gone = oldTorGone(waitFor)
            main { if (gone) bind(entry) else fail(entry) }
        }
    }

    override fun stop() {
        val entry: Entry
        val bound: Boolean
        synchronized(lock) {
            entry = current ?: return
            current = null
            bound = synchronized(entry) {
                entry.stopped = true
                entry.bound
            }
        }
        entry.run.quiet()
        if (!bound) return
        val run = entry.run
        // Up: the service's onDestroy asks Tor to exit. Connected with no Tor thread: nothing is running.
        if (run.controllable || (run.connected && torThreads().isEmpty())) {
            run.unbind()
            return
        }
        val unbound = CountDownLatch(1)
        synchronized(lock) { retiring = unbound }
        background {
            try {
                haltOnceControllable(run)
            } finally {
                main {
                    try {
                        run.unbind()
                    } finally {
                        unbound.countDown()
                    }
                }
            }
        }
    }

    private fun bind(entry: Entry) {
        val bound = synchronized(entry) {
            if (entry.stopped) return
            runCatching { entry.run.bind() }.isSuccess.also { entry.bound = it }
        }
        if (!bound) fail(entry)
    }

    /** Ends [entry] as a failure, unless a stop got there first. */
    private fun fail(entry: Entry) {
        synchronized(lock) {
            synchronized(entry) {
                if (entry.stopped) return
                entry.stopped = true
            }
            if (current === entry) current = null
        }
        runCatching { entry.run.unbind() }
        entry.events.failed()
    }

    /** True once [retiring] has unbound and no `tor` thread is alive, within [joinMs]. */
    private fun oldTorGone(retiring: CountDownLatch?): Boolean {
        val deadline = now() + joinMs
        if (retiring != null && !retiring.await(joinMs, TimeUnit.MILLISECONDS)) return false
        while (true) {
            val alive = torThreads()
            if (alive.isEmpty()) return true
            val left = deadline - now()
            if (left <= 0) return false
            alive.first().join(left)
        }
    }

    /**
     * Waits for [run]'s control connection, at most [controlWaitMs], and halts
     * Tor through it [settleMs] after it appears (even past the bound). Returns
     * early if the service connected and its Tor has already ended.
     */
    private fun haltOnceControllable(run: TorRun) {
        val deadline = now() + controlWaitMs
        var seenAt = -1L
        while (seenAt >= 0 || now() < deadline) {
            if (seenAt >= 0 || run.controllable) {
                if (seenAt < 0) seenAt = now()
                if (now() - seenAt >= settleMs) {
                    runCatching { run.halt() }
                    return
                }
            } else if (run.connected && torThreads().isEmpty()) {
                return
            }
            Thread.sleep(pollMs)
        }
    }

    private fun now() = System.nanoTime() / 1_000_000

    companion object {
        /** How long a start waits for the old Tor to end before failing. */
        const val JOIN_MS = 10_000L

        /** How long a stop keeps its binding waiting for Tor's control connection. */
        const val CONTROL_WAIT_MS = 5_000L

        /** How long after the control connection appears the service has to authenticate on it. */
        const val SETTLE_MS = 500L

        const val WAIT_POLL_MS = 50L
    }
}

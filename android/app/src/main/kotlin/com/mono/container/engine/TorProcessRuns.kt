package com.mono.container.engine

/**
 * One Tor run as [TorProcessRuns] drives it: the host service bound in a
 * `:tor` process ([TorProcessDaemon]'s link on a device), a fake in the JVM
 * tests.
 */
internal interface TorHostLink {
    /**
     * Binds the host service, which starts Tor in its process. [events] hears
     * the run, on any thread; the host dying is [TorEvents.failed]. Main
     * thread; throws if the system refuses the bind.
     */
    fun bind(events: TorEvents)

    /** Lets go of the binding. Idempotent. */
    fun unbind()
}

/**
 * Every Tor run in a process of its own. Tor cannot be run twice in one
 * process: `tor_api.h` says a second `tor_run_main` "may crash or behave
 * strangely" (Tor bug 23847), and on a device the fourth run in the app's
 * process aborted it (`SIGABRT` in `pubsub_install`, 2026-10-09). So Tor runs
 * in `:tor` ([TorHostService]), which kills itself when its service is
 * destroyed, and:
 *
 * - **A start binds only in a new process.** Any `:tor` process still listed
 *   belongs to a stopped run: the start kills it and binds once the system no
 *   longer lists one, waiting off the main thread at most [goneWaitMs]. A
 *   process still listed after that fails the run (`8b`, Try again), never a
 *   bind beside it. A stop during the wait cancels the bind.
 * - **A stop is a kill.** It unbinds and kills the `:tor` process at once, so
 *   Tor ends at every lock and panic however far it got. Nothing the stopped
 *   run says afterwards reaches [TorRuntime].
 * - **Tor dying is a failed run, not a dead app.** The host's death is
 *   [TorEvents.failed], heard once; the run is unbound and its process
 *   killed.
 *
 * [start] and [stop] are serialised by [TorRuntime]'s lock, on any thread.
 * [TorEvents.failed] is never called holding this class's lock.
 */
internal class TorProcessRuns(
    private val newLink: () -> TorHostLink,
    private val torProcesses: () -> List<Int>,
    private val kill: (Int) -> Unit,
    private val main: (() -> Unit) -> Unit,
    private val background: (() -> Unit) -> Unit = { Thread(it, "tor-wait").apply { isDaemon = true }.start() },
    private val goneWaitMs: Long = GONE_WAIT_MS,
    private val pollMs: Long = POLL_MS,
) : TorDaemon {

    private inner class Entry(val link: TorHostLink, val events: TorEvents) : TorEvents {
        /** Guarded by the entry itself. */
        var stopped = false

        override fun progress(percent: Int) {
            if (synchronized(this) { stopped }) return
            events.progress(percent)
        }

        override fun failed() = fail(this)
    }

    private val lock = Any()
    private var current: Entry? = null

    override fun start(events: TorEvents) {
        val entry = Entry(newLink(), events)
        synchronized(lock) { current = entry }
        val leftovers = torProcesses()
        if (leftovers.isEmpty()) {
            bind(entry)
            return
        }
        leftovers.forEach(kill)
        background {
            val gone = leftoversGone()
            main { if (gone) bind(entry) else fail(entry) }
        }
    }

    override fun stop() {
        val entry = synchronized(lock) {
            val entry = current ?: return
            current = null
            entry
        }
        synchronized(entry) { entry.stopped = true }
        end(entry)
    }

    private fun bind(entry: Entry) {
        val bound = synchronized(entry) {
            if (entry.stopped) return
            runCatching { entry.link.bind(entry) }.isSuccess
        }
        if (!bound) fail(entry)
    }

    /** Ends [entry] as a failure, unless a stop or an earlier failure got there first. */
    private fun fail(entry: Entry) {
        synchronized(lock) {
            synchronized(entry) {
                if (entry.stopped) return
                entry.stopped = true
            }
            if (current === entry) current = null
        }
        end(entry)
        entry.events.failed()
    }

    private fun end(entry: Entry) {
        runCatching { entry.link.unbind() }
        torProcesses().forEach { runCatching { kill(it) } }
    }

    /** True once the system lists no `:tor` process, within [goneWaitMs]. */
    private fun leftoversGone(): Boolean {
        val deadline = now() + goneWaitMs
        while (true) {
            if (torProcesses().isEmpty()) return true
            if (now() >= deadline) return false
            Thread.sleep(pollMs)
        }
    }

    private fun now() = System.nanoTime() / 1_000_000

    companion object {
        /** How long a start waits for a killed `:tor` process to go before failing. */
        const val GONE_WAIT_MS = 10_000L

        const val POLL_MS = 50L
    }
}

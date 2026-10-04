package com.mono.container.engine

import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/** What [TorRuntime] drives: tor-android's service on a device ([TorServiceDaemon]), a fake in the JVM tests. */
interface TorDaemon {
    /** Starts Tor. [events] hears it, on any thread, until [stop]. */
    fun start(events: TorEvents)

    /** Stops Tor. Nothing the stopped run says afterwards counts. */
    fun stop()
}

interface TorEvents {
    /** Tor's bootstrap percentage; 100 is ready. */
    fun progress(percent: Int)

    /** Tor reported an error, or stopped by itself. */
    fun failed()
}

/**
 * The process's one Tor (built-in Tor spec §4.2, ruling 1): off until a site
 * on the Tor route holds it, stopped when the last one lets go.
 *
 * [hold], [release] and [stopAll] run on the main thread, as the engine's
 * open and close do. [awaitReady] blocks, so never there. Each run has a
 * generation; whatever a stopped or failed run says afterwards is ignored.
 */
class TorRuntime(
    private val daemon: TorDaemon,
    private val now: () -> Long = System::currentTimeMillis,
    private val stallMs: Long = STALL_MS,
    private val pollMs: Long = POLL_MS,
) {
    sealed class State {
        data object Off : State()
        data class Starting(val percent: Int) : State()
        data object Ready : State()
        data object Failed : State()
    }

    private val lock = ReentrantLock()
    private val changed = lock.newCondition()
    private val holders = HashSet<String>()
    private var generation = 0
    private var lastMovedAt = 0L
    private var current: State = State.Off

    val state: State get() = lock.withLock { current }

    val isReady: Boolean get() = state == State.Ready

    /** [holder] (a site id) needs Tor: it starts if it is off or has failed. */
    fun hold(holder: String) {
        lock.withLock {
            holders += holder
            if (current == State.Off || current == State.Failed) begin()
        }
    }

    /** [holder] no longer needs Tor; its wait, if any, ends false. The last one stops Tor. */
    fun release(holder: String) {
        lock.withLock {
            if (!holders.remove(holder)) return
            changed.signalAll()
            if (holders.isEmpty()) halt(State.Off)
        }
    }

    /** Every lock and panic: nothing holds Tor, every wait ends, and it stops. */
    fun stopAll() {
        lock.withLock {
            holders.clear()
            halt(State.Off)
        }
    }

    /**
     * Blocks until Tor is ready (true), or until it fails, stalls ([stallMs]
     * with no new percentage, spec §4.3) or [holder] lets go of it (false).
     * [onProgress] hears each new percentage while it waits.
     */
    fun awaitReady(holder: String, onProgress: (Int) -> Unit = {}): Boolean {
        var heard = -1
        lock.withLock {
            while (true) {
                if (holder !in holders) return false
                when (val seen = current) {
                    State.Ready -> return true
                    State.Off, State.Failed -> return false
                    is State.Starting -> {
                        if (seen.percent != heard) {
                            heard = seen.percent
                            onProgress(heard)
                        }
                        val idle = now() - lastMovedAt
                        if (idle >= stallMs) {
                            halt(State.Failed)
                            return false
                        }
                        changed.await(minOf(pollMs, stallMs - idle), TimeUnit.MILLISECONDS)
                    }
                }
            }
        }
    }

    /** Called holding [lock]. */
    private fun begin() {
        val run = ++generation
        current = State.Starting(0)
        lastMovedAt = now()
        changed.signalAll()
        daemon.start(object : TorEvents {
            override fun progress(percent: Int) = onProgress(run, percent)
            override fun failed() = onFailed(run)
        })
    }

    private fun onProgress(run: Int, percent: Int) {
        lock.withLock {
            if (run != generation) return
            val starting = current as? State.Starting ?: return
            when {
                percent >= 100 -> current = State.Ready
                percent > starting.percent -> {
                    current = State.Starting(percent)
                    lastMovedAt = now()
                }
                else -> return
            }
            changed.signalAll()
        }
    }

    private fun onFailed(run: Int) {
        lock.withLock {
            if (run != generation) return
            halt(State.Failed)
        }
    }

    /** Ends the current run, if one is going, and forgets it. Called holding [lock]. */
    private fun halt(next: State) {
        val running = current is State.Starting || current == State.Ready
        generation++
        current = next
        changed.signalAll()
        if (running) daemon.stop()
    }

    companion object {
        /** Spec §4.3: two minutes with no new percentage is a failure. */
        const val STALL_MS = 120_000L
        const val POLL_MS = 500L
    }
}

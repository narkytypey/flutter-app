package com.mono.container.engine

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import org.torproject.jni.TorService
import java.io.File

/**
 * tor-android's [TorService], bound while Tor is needed (spec §4.2).
 * Unbinding destroys the service, which shuts Tor down. It runs only inside
 * the `:tor` process, started by [TorHostService]; the app drives Tor through
 * [TorProcessDaemon], which kills that process at every stop, so here only
 * [start] is ever called.
 *
 * [TorRuns] orders the runs: a start waits for the last Tor to end, and a
 * stop before Tor's control connection exists halts Tor once it does (Plan 19
 * final review, Important #1 and #2). This class is only the service side.
 *
 * The service broadcasts only on and off, so progress is read by polling its
 * control connection's `status/bootstrap-phase` (plan D5). An error
 * broadcast, the service stopping or the binding dying is a failure;
 * [TorRuntime] ignores whatever a stopped run still says. Calls are
 * serialised by [TorRuntime]'s lock; any thread.
 */
class TorServiceDaemon(private val context: Context) : TorDaemon {

    private val runs = TorRuns(
        newRun = { events -> ServiceRun(context, events) },
        main = { task -> Handler(Looper.getMainLooper()).post(task) },
    )

    override fun start(events: TorEvents) = runs.start(events)

    override fun stop() = runs.stop()

    private class ServiceRun(private val context: Context, private val events: TorEvents) : TorRun, ServiceConnection {
        @Volatile private var service: TorService? = null

        /** The old run's service broadcasts OFF late; ignore everything before our own connect. */
        @Volatile private var ownConnect = false

        @Volatile private var quiet = false
        @Volatile private var registered = false
        @Volatile private var bindCalled = false

        private val poller = Thread({ poll() }, "tor-bootstrap").apply { isDaemon = true }

        private val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (!ownConnect || quiet) return
                val status = intent.getStringExtra(TorService.EXTRA_STATUS)
                if (intent.action == TorService.ACTION_ERROR ||
                    status == TorService.STATUS_STOPPING || status == TorService.STATUS_OFF
                ) {
                    events.failed()
                }
            }
        }

        override val connected: Boolean get() = service != null

        override val controllable: Boolean get() = service?.torControlConnection != null

        override fun bind() {
            val socket = TorFiles.socket(context.filesDir)
            prepareSocketDir(socket)
            TorService.getTorrc(context).apply { parentFile?.mkdirs() }.writeText(torrc(socket))
            LocalBroadcastManager.getInstance(context).registerReceiver(
                receiver,
                IntentFilter().apply {
                    addAction(TorService.ACTION_STATUS)
                    addAction(TorService.ACTION_ERROR)
                },
            )
            registered = true
            bindCalled = true
            if (!context.bindService(Intent(context, TorService::class.java), this, Context.BIND_AUTO_CREATE)) {
                throw IllegalStateException("TorService could not be bound")
            }
        }

        override fun quiet() {
            quiet = true
            poller.interrupt()
            if (registered) {
                registered = false
                runCatching { LocalBroadcastManager.getInstance(context).unregisterReceiver(receiver) }
            }
        }

        override fun unbind() {
            quiet()
            if (bindCalled) {
                bindCalled = false
                runCatching { context.unbindService(this) }
            }
        }

        override fun halt() {
            service?.torControlConnection?.shutdownTor("HALT")
        }

        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            service = (binder as TorService.LocalBinder).service
            ownConnect = true
            if (!quiet && poller.state == Thread.State.NEW) poller.start()
        }

        override fun onServiceDisconnected(name: ComponentName) {
            if (!quiet) events.failed()
        }

        private fun poll() {
            try {
                // The control connection exists some time after the service starts, and
                // the service authenticates on it first: ask only once it has been there a
                // whole poll (the library logs a NullPointerException for every earlier ask).
                var controlSeen = false
                while (!quiet) {
                    val control = service?.torControlConnection != null
                    val percent = if (control && controlSeen) {
                        runCatching { service?.getInfo("status/bootstrap-phase") }.getOrNull()?.let(::bootstrapPercent)
                    } else {
                        null
                    }
                    controlSeen = control
                    if (percent != null) events.progress(percent)
                    // After ready, Tor's death is the STOPPING broadcast.
                    if (percent == 100) return
                    Thread.sleep(TorRuntime.POLL_MS)
                }
            } catch (_: InterruptedException) {
                // Stopped.
            }
        }

        /** Owner-only (0700), and no stale socket from a run that was killed. */
        private fun prepareSocketDir(socket: File) {
            val dir = socket.parentFile!!
            dir.mkdirs()
            dir.setReadable(false, false)
            dir.setWritable(false, false)
            dir.setExecutable(false, false)
            dir.setReadable(true, true)
            dir.setWritable(true, true)
            dir.setExecutable(true, true)
            socket.delete()
        }
    }
}

/** The process's one Tor (spec §4.1), installed by [com.mono.container.MainActivity] before any open. */
internal object Tor {
    @Volatile var runtime: TorRuntime? = null
        private set

    @Volatile var socketPath: String? = null
        private set

    @Synchronized fun install(context: Context) {
        if (runtime != null) return
        socketPath = TorFiles.socket(context.filesDir).absolutePath
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        runtime = TorRuntime(
            TorProcessDaemon(context.applicationContext),
            schedule = { delayMs, task -> main.postDelayed(task, delayMs) },
        )
    }
}

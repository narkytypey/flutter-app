package com.mono.container.engine

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.os.IBinder
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import org.torproject.jni.TorService
import java.io.File

/**
 * The real [TorDaemon]: tor-android's [TorService], bound while Tor is needed
 * (spec §4.2). Unbinding destroys the service, which shuts Tor down.
 *
 * The service broadcasts only on and off, so progress is read by polling its
 * control connection's `status/bootstrap-phase` (plan D5). An error
 * broadcast, the service stopping or the binding dying is a failure;
 * [TorRuntime] ignores whatever a stopped run still says. Main thread only,
 * like [TorRuntime.hold].
 */
class TorServiceDaemon(private val context: Context) : TorDaemon {

    private var run: Run? = null

    private class Run(val events: TorEvents) : ServiceConnection {
        @Volatile var service: TorService? = null

        val poller = Thread({ poll() }, "tor-bootstrap").apply { isDaemon = true }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val status = intent.getStringExtra(TorService.EXTRA_STATUS)
                if (intent.action == TorService.ACTION_ERROR ||
                    status == TorService.STATUS_STOPPING || status == TorService.STATUS_OFF
                ) {
                    events.failed()
                }
            }
        }

        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            service = (binder as TorService.LocalBinder).service
            poller.start()
        }

        override fun onServiceDisconnected(name: ComponentName) = events.failed()

        private fun poll() {
            try {
                while (!Thread.currentThread().isInterrupted) {
                    runCatching { service?.getInfo("status/bootstrap-phase") }.getOrNull()
                        ?.let(::bootstrapPercent)
                        ?.let(events::progress)
                    Thread.sleep(TorRuntime.POLL_MS)
                }
            } catch (_: InterruptedException) {
                // Stopped.
            }
        }
    }

    override fun start(events: TorEvents) {
        val socket = TorFiles.socket(context.filesDir)
        prepareSocketDir(socket)
        TorService.getTorrc(context).apply { parentFile?.mkdirs() }.writeText(torrc(socket))

        val next = Run(events)
        LocalBroadcastManager.getInstance(context).registerReceiver(
            next.receiver,
            IntentFilter().apply {
                addAction(TorService.ACTION_STATUS)
                addAction(TorService.ACTION_ERROR)
            },
        )
        run = next
        if (!context.bindService(Intent(context, TorService::class.java), next, Context.BIND_AUTO_CREATE)) {
            events.failed()
        }
    }

    override fun stop() {
        val current = run ?: return
        run = null
        current.poller.interrupt()
        LocalBroadcastManager.getInstance(context).unregisterReceiver(current.receiver)
        runCatching { context.unbindService(current) }
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

/** The process's one Tor (spec §4.1), installed by [com.mono.container.MainActivity] before any open. */
internal object Tor {
    @Volatile var runtime: TorRuntime? = null
        private set

    @Volatile var socketPath: String? = null
        private set

    @Synchronized fun install(context: Context) {
        if (runtime != null) return
        socketPath = TorFiles.socket(context.filesDir).absolutePath
        runtime = TorRuntime(TorServiceDaemon(context.applicationContext))
    }
}

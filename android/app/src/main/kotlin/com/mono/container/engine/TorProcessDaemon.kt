package com.mono.container.engine

import android.app.ActivityManager
import android.app.Application
import android.app.Service
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.Process
import android.os.RemoteException

/** The name, after the package's, of the process Tor runs in (the manifest's `android:process`). */
internal const val TOR_PROCESS_SUFFIX = ":tor"

/**
 * The real [TorDaemon]: Tor in a `:tor` process of its own, one process per
 * run ([TorProcessRuns] says why). The app binds [TorHostService] there,
 * which runs tor-android's service through [TorServiceDaemon] and reports
 * Tor's progress and failure back over a [Messenger].
 */
class TorProcessDaemon(private val context: Context) : TorDaemon {

    private val runs = TorProcessRuns(
        newLink = { HostLink(context) },
        torProcesses = { torProcessPids(context) },
        kill = { Process.killProcess(it) },
        main = { task -> Handler(Looper.getMainLooper()).post(task) },
    )

    override fun start(events: TorEvents) = runs.start(events)

    override fun stop() = runs.stop()

    /** One binding of [TorHostService]; its replies arrive on the main thread. */
    private class HostLink(private val context: Context) : TorHostLink, ServiceConnection {
        @Volatile private var events: TorEvents? = null
        @Volatile private var bound = false

        private val replies = Messenger(
            Handler(Looper.getMainLooper()) { message ->
                when (message.what) {
                    TorHostService.MSG_PROGRESS -> events?.progress(message.arg1)
                    TorHostService.MSG_FAILED -> events?.failed()
                }
                true
            },
        )

        override fun bind(events: TorEvents) {
            this.events = events
            if (!context.bindService(Intent(context, TorHostService::class.java), this, Context.BIND_AUTO_CREATE)) {
                // A refused bind must still be let go of.
                runCatching { context.unbindService(this) }
                throw IllegalStateException("Tor's host service could not be bound")
            }
            bound = true
        }

        override fun unbind() {
            events = null
            if (bound) {
                bound = false
                runCatching { context.unbindService(this) }
            }
        }

        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            val start = Message.obtain(null, TorHostService.MSG_START).apply { replyTo = replies }
            try {
                Messenger(binder).send(start)
            } catch (_: RemoteException) {
                events?.failed()
            }
        }

        /** The `:tor` process died: Tor aborted, or the system killed it. */
        override fun onServiceDisconnected(name: ComponentName) {
            events?.failed()
        }

        override fun onBindingDied(name: ComponentName) {
            events?.failed()
        }

        override fun onNullBinding(name: ComponentName) {
            events?.failed()
        }
    }
}

/** The pids of this app's `:tor` processes, as the system lists them (never this process). */
internal fun torProcessPids(context: Context): List<Int> {
    val name = context.packageName + TOR_PROCESS_SUFFIX
    val self = Process.myPid()
    return context.getSystemService(ActivityManager::class.java)
        ?.runningAppProcesses.orEmpty()
        .filter { it.processName == name && it.pid != self }
        .map { it.pid }
}

/**
 * Tor's host, alone in the `:tor` process (manifest). The app's bind starts
 * Tor through [TorServiceDaemon] on the first [MSG_START]; its progress and
 * failure go back to the message's `replyTo`. When the service is destroyed
 * (the app unbound it, or the app's process died), it kills its own process:
 * Tor cannot be run twice in one process, so this one never outlives its
 * run.
 */
class TorHostService : Service() {
    private var started = false

    private val incoming by lazy {
        Messenger(
            Handler(Looper.getMainLooper()) { message ->
                if (message.what == MSG_START) start(message.replyTo)
                true
            },
        )
    }

    override fun onBind(intent: Intent): IBinder = incoming.binder

    private fun start(reply: Messenger?) {
        if (started || reply == null) return
        started = true
        TorServiceDaemon(applicationContext).start(object : TorEvents {
            override fun progress(percent: Int) = send(reply, MSG_PROGRESS, percent)
            override fun failed() = send(reply, MSG_FAILED, 0)
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        // Never the app's own process, whatever the manifest says.
        if (Application.getProcessName().endsWith(TOR_PROCESS_SUFFIX)) Process.killProcess(Process.myPid())
    }

    private fun send(reply: Messenger, what: Int, arg: Int) {
        try {
            reply.send(Message.obtain(null, what, arg, 0))
        } catch (_: RemoteException) {
            // The app is gone; its unbind destroys this service.
        }
    }

    internal companion object {
        const val MSG_START = 1
        const val MSG_PROGRESS = 2
        const val MSG_FAILED = 3
    }
}

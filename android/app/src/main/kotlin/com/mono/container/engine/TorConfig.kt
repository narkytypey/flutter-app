package com.mono.container.engine

import java.io.File

/**
 * Where built-in Tor keeps things (spec §4.1, §4.5, plan D1). Pure, so the
 * JVM tests read it; [TorServiceDaemon] and panic use it on the device.
 */
object TorFiles {
    /** Ours, owner-only: Tor will not make a SOCKS socket where others can enter. */
    fun socketDir(filesDir: File) = File(filesDir, "tor")

    /**
     * Tor's SOCKS port (spec §4.4). The name ends `:0` on purpose (plan D2):
     * once Tor is up, tor-android's `TorService` reads `net/listeners/socks`
     * and parses the text after the last `:` as a port, in a thread whose
     * catch does not cover a `NumberFormatException`. A plain path would crash
     * the app; this one parses as port 0.
     */
    fun socket(filesDir: File) = File(socketDir(filesDir), "socks:0")

    /**
     * Everything Tor keeps: our socket directory, and the data (with its torrc)
     * and cache directories tor-android sets on Tor's command line, which no
     * torrc can move (plan D1).
     */
    fun all(filesDir: File, dataDir: File, cacheDir: File): List<File> = listOf(
        socketDir(filesDir),
        File(dataDir, "app_TorService"),
        File(cacheDir, "TorService"),
    )

    /** Left by panic until the next start has deleted Tor's state again (plan D4). */
    fun wipeMarker(filesDir: File) = File(filesDir, "tor-wipe-pending")
}

/**
 * The torrc `TorService` reads with `-f` (spec §4.1). Its lines replace the
 * same options in tor-android's defaults file, which opens TCP 9050 and 8118
 * (plan D3). `IsolateSOCKSAuth` gives each SOCKS login its own circuit (§5.2).
 */
fun torrc(socket: File): String = buildString {
    append("SocksPort unix:\"${socket.absolutePath}\" IsolateSOCKSAuth\n")
    append("HTTPTunnelPort 0\n")
    append("ControlPort 0\n")
}

private val BOOTSTRAP_PROGRESS = Regex("""\bPROGRESS=(\d{1,3})\b""")

/** The percentage in Tor's `status/bootstrap-phase` (plan D5), or null without one. */
fun bootstrapPercent(phase: String?): Int? =
    phase?.let { BOOTSTRAP_PROGRESS.find(it) }?.groupValues?.get(1)?.toIntOrNull()?.coerceIn(0, 100)

/**
 * An onion service's name (spec §5.3): reachable only through Tor, so never
 * looked up or sent direct. Letter case and one trailing dot change nothing.
 */
fun isOnionHost(host: String): Boolean {
    val name = host.trimEnd('.').lowercase()
    return name == "onion" || name.endsWith(".onion")
}

/** Panic's part for Tor (spec §4.5, plan D4). */
object TorWipe {
    /** Deletes [dirs]. The marker is written first, so a crash midway still leaves work for [sweep]. */
    fun wipe(dirs: List<File>, marker: File) {
        marker.parentFile?.mkdirs()
        marker.writeText("")
        for (dir in dirs) dir.deleteRecursively()
    }

    /** At start, before Tor can run: finishes a wipe that Tor's own shutdown may have undone. */
    fun sweep(dirs: List<File>, marker: File) {
        if (!marker.exists()) return
        for (dir in dirs) dir.deleteRecursively()
        if (dirs.none { it.exists() }) marker.delete()
    }
}

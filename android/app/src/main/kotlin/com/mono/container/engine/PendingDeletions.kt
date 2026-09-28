package com.mono.container.engine

import java.io.File

/**
 * Profiles to delete at the next engine start, one opaque profile id per line.
 *
 * WebView will not delete a profile this process has loaded: Chromium's
 * `AwBrowserContextStore::Delete` answers `kInUse` for any context with a live
 * instance, and nothing ever releases one short of the process dying. So a
 * profile used since start can only be cleared in place (see [ProfileManager])
 * and deleted properly later — here, before anything has loaded it again.
 *
 * Holds random ids only, never a host, name or URL. It sits in plaintext in
 * `filesDir`, which is within the threat model: coerced unlock, not disk
 * imaging.
 */
class PendingDeletions(private val file: File) {

    @Synchronized
    fun names(): List<String> =
        if (file.exists()) file.readLines().filter { it.isNotBlank() } else emptyList()

    @Synchronized
    fun add(name: String) {
        val current = names()
        if (name !in current) write(current + name)
    }

    /** A profile loaded again is live data now, not leftovers. */
    @Synchronized
    fun remove(name: String) {
        val current = names()
        if (name in current) write(current - name)
    }

    /**
     * Calls [delete] for each pending profile, and keeps any whose delete threw
     * so the start after this one tries again.
     */
    @Synchronized
    fun sweep(delete: (String) -> Unit) {
        write(names().filter { name -> runCatching { delete(name) }.isFailure })
    }

    private fun write(names: List<String>) {
        if (names.isEmpty()) {
            file.delete()
            return
        }
        val tmp = File(file.parentFile, "${file.name}.tmp")
        tmp.writeText(names.joinToString("\n", postfix = "\n"))
        if (!tmp.renameTo(file)) {
            file.delete()
            tmp.renameTo(file)
        }
    }
}

/**
 * Deletes [name] outright if nothing in this process has loaded it; otherwise
 * journals it for the next start and then clears it in place. Journaled first,
 * so a clear that dies halfway still ends in a real deletion.
 *
 * Any failure other than "in use" — the default profile, a store that is gone —
 * propagates: those are not leftovers a later start could fix.
 */
internal fun wipeProfile(
    name: String,
    delete: () -> Unit,
    clear: () -> Unit,
    pending: PendingDeletions,
) {
    try {
        delete()
        pending.remove(name)
    } catch (_: IllegalStateException) {
        pending.add(name)
        clear()
    }
}

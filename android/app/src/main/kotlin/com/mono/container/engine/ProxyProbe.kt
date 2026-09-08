package com.mono.container.engine

import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.ConcurrentHashMap

/**
 * Caches TCP reachability per `host:port` for 5 seconds behind a 2-second
 * connect timeout. A page can pull in dozens of subresources within a few
 * hundred milliseconds; probing on every one would turn one slow connect
 * into sixty.
 */
object ProxyProbe {
    private data class Entry(val reachable: Boolean, val checkedAtMs: Long)

    private val cache = ConcurrentHashMap<String, Entry>()
    private const val CACHE_MS = 5_000L
    private const val CONNECT_TIMEOUT_MS = 2_000

    fun reachable(host: String, port: Int): Boolean {
        val key = "$host:$port"
        val now = System.currentTimeMillis()
        cache[key]?.let { if (now - it.checkedAtMs < CACHE_MS) return it.reachable }

        val result = runCatching {
            Socket().use { it.connect(InetSocketAddress(host, port), CONNECT_TIMEOUT_MS) }
            true
        }.getOrDefault(false)

        cache[key] = Entry(result, now)
        return result
    }
}

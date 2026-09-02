package com.mono.container.engine

import java.net.URI
import java.util.concurrent.atomic.AtomicInteger

/**
 * Domain-blocking only: `||host^` rules. Feeds spec `2a`'s
 * "Local filter lists · 42 rules matched today" and Plan 1's leak count.
 */
class FilterEngine(rules: List<String>) {

    private val blockedHosts: Set<String> = rules
        .map { it.trim() }
        .filter { it.startsWith("||") && it.endsWith("^") }
        .map { it.removePrefix("||").removeSuffix("^").lowercase() }
        .toSet()

    private val counter = AtomicInteger(0)
    val blockedCount: Int get() = counter.get()

    fun matches(url: String): Boolean {
        val host = runCatching { URI(url).host }.getOrNull()?.lowercase()
            ?: return false
        val hit = blockedHosts.any { host == it || host.endsWith(".$it") }
        if (hit) counter.incrementAndGet()
        return hit
    }
}

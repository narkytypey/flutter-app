package com.mono.container.engine

import java.net.URI
import java.util.concurrent.atomic.AtomicInteger

/**
 * Domain-blocking only: `||host^` rules, now grouped by category so `2a`'s
 * match count and the Today log (`5c`) can tell trackers from ads. Feeds
 * spec `2a`'s "Local filter lists · 42 rules matched today".
 */
class FilterEngine(rulesByCategory: Map<String, List<String>>) {

    private data class CategorySet(val hosts: Set<String>, val counter: AtomicInteger)

    private val categories: Map<String, CategorySet> = rulesByCategory.mapValues { (_, rules) ->
        CategorySet(
            hosts = rules
                .map { it.trim() }
                .filter { it.startsWith("||") && it.endsWith("^") }
                .map { it.removePrefix("||").removeSuffix("^").lowercase() }
                .toSet(),
            counter = AtomicInteger(0),
        )
    }

    val blockedCount: Int get() = categories.values.sumOf { it.counter.get() }

    fun countFor(category: String): Int = categories[category]?.counter?.get() ?: 0

    /** Returns the category that matched, or `null` if nothing did. */
    fun matches(url: String): String? {
        val host = runCatching { URI(url).host }.getOrNull()?.lowercase() ?: return null
        for ((name, set) in categories) {
            if (set.hosts.any { host == it || host.endsWith(".$it") }) {
                set.counter.incrementAndGet()
                return name
            }
        }
        return null
    }
}

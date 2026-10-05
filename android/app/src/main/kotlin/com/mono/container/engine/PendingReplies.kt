package com.mono.container.engine

/**
 * Replies still owed to callers, each answered exactly once.
 *
 * WebView never runs an `evaluateJavascript` callback for a page destroyed
 * while the script runs, so a caller waiting on one (reader mode's
 * `extractArticle`, which Dart awaits over the method channel) would wait for
 * ever. Every such callback goes through [add]; [cancelAll] answers whatever is
 * still owed with null when the page closes, and a late real answer after that
 * is dropped.
 *
 * Not thread-safe: the platform (main) thread only, as WebView's callbacks are.
 */
class PendingReplies<T> {
    private val owed = LinkedHashSet<Reply>()

    inner class Reply internal constructor(private val onResult: (T?) -> Unit) {
        private var answered = false

        fun answer(value: T?) {
            if (answered) return
            answered = true
            owed.remove(this)
            onResult(value)
        }
    }

    fun add(onResult: (T?) -> Unit): Reply = Reply(onResult).also { owed += it }

    val size: Int get() = owed.size

    fun cancelAll() {
        owed.toList().forEach { it.answer(null) }
    }
}

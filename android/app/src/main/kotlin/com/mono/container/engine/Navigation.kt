package com.mono.container.engine

/** One `navigation` event (browser-chrome spec §3.1): what the chrome shows about a page. */
data class NavigationSnapshot(
    val url: String,
    val title: String,
    val canGoBack: Boolean,
    val canGoForward: Boolean,
    val loading: Boolean,
    /** 0–100. */
    val progress: Int,
) {
    /** Also what `navigationState` returns; Dart decodes both the same way. */
    fun toEvent(siteId: String): Map<String, Any?> = mapOf(
        "type" to "navigation",
        "siteId" to siteId,
        "url" to url,
        "title" to title,
        "canGoBack" to canGoBack,
        "canGoForward" to canGoForward,
        "loading" to loading,
        "progress" to progress,
    )
}

/**
 * Folds WebView's page callbacks — `onPageStarted`, `onPageFinished`,
 * `doUpdateVisitedHistory`, `onProgressChanged`, `onReceivedTitle` — into one
 * state. History (`canGoBack`/`canGoForward`) is read from the WebView at
 * [snapshot] time. Main thread only, like the WebView that feeds it.
 */
class NavigationTracker(initialUrl: String) {
    private var url = initialUrl
    private var title = ""

    /** The view starts loading its site's address as soon as it exists. */
    private var loading = true
    private var progress = 0

    fun started(url: String) {
        this.url = url
        loading = true
        // A new load after a finished one restarts the line. WebView may
        // report its first progress before this callback, so a lower value
        // already reported for this load is kept.
        if (progress >= 100) progress = 0
    }

    fun finished(url: String) {
        this.url = url
        loading = false
        progress = 100
    }

    fun stopped() {
        loading = false
    }

    fun visited(url: String) {
        this.url = url
    }

    fun progressed(percent: Int) {
        progress = percent.coerceIn(0, 100)
    }

    fun titled(title: String?) {
        this.title = title.orEmpty()
    }

    fun snapshot(canGoBack: Boolean, canGoForward: Boolean) =
        NavigationSnapshot(url, title, canGoBack, canGoForward, loading, progress)
}

/** The `find_result` event (spec §6.5). [activeMatch] is WebView's zero-based ordinal. */
fun findResultEvent(siteId: String, activeMatch: Int, matchCount: Int): Map<String, Any?> = mapOf(
    "type" to "find_result",
    "siteId" to siteId,
    "activeMatch" to activeMatch,
    "matchCount" to matchCount,
)

private val loadableUrl = Regex("^https?://[^/?#\\s]+", RegexOption.IGNORE_CASE)

/**
 * Whether `loadUrl` may load [url]: `http` or `https`, with a host, from the
 * very first character. Nothing else — `javascript:` would run in the page,
 * `file:` and `content:` read the device, `intent:` leaves the container.
 * Dart's parser never sends any of them; this refuses them anyway.
 */
fun isLoadableUrl(url: String): Boolean = loadableUrl.find(url) != null

/**
 * What a container's view loads first: the address the owner typed, when
 * there is one and [isLoadableUrl] allows it, otherwise the site's own.
 * The stored address itself is loaded as it always was — it is whatever the
 * add-site form accepted, and guarding it could stop an existing site
 * loading. The typed one is for that first load only: the session's
 * identity, script scope and prompts stay on the stored address.
 */
fun firstLoadUrl(storedUrl: String, typedUrl: String?): String =
    if (typedUrl != null && isLoadableUrl(typedUrl)) typedUrl else storedUrl

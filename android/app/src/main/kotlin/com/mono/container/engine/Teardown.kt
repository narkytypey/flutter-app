package com.mono.container.engine

/** What [RequestInterceptor] does with one request, decided before any Android type is built. */
internal sealed class Disposition {
    /** The view is closing: refused, and reported to no one. */
    object Closed : Disposition()
    /** A filter list matched: an empty 204. */
    object Blocked : Disposition()
    /** Chromium fetches it, through the loopback proxy, on the site's route (P2 spec §1.4). */
    object ByWebView : Disposition()
}

/**
 * [closing] is checked first and alone. A view is closing from the moment it
 * is disposed until WebView is destroyed, and what a page sends then — its
 * pagehide beacons, keepalive fetches — is refused outright: never routed,
 * never direct, and never even handed to the loopback proxy (user's ruling,
 * 2026-09-30).
 */
internal fun dispositionFor(closing: Boolean, blockedByFilter: () -> Boolean): Disposition {
    if (closing) return Disposition.Closed
    if (blockedByFilter()) return Disposition.Blocked
    return Disposition.ByWebView
}

/**
 * The end of a view's life. Found on a device: destroying the WebView
 * straight away ran the page's unload handlers after its interception hook
 * was gone, so their keepalive requests went out direct. So a closing view
 * first loads [BLANK], which unloads the old page while the view can still
 * refuse what it sends, and [destroy] runs once that blank page has finished —
 * or after [TIMEOUT_MS], so a page that never finishes cannot keep the view
 * alive. Either way it runs exactly once.
 */
internal class Teardown(private val destroy: () -> Unit) {
    private var done = false

    fun pageFinished(url: String) {
        if (url == BLANK) finish()
    }

    fun timedOut() = finish()

    private fun finish() {
        if (done) return
        done = true
        destroy()
    }

    companion object {
        const val BLANK = "about:blank"
        const val TIMEOUT_MS = 1_000L
    }
}

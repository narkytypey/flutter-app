package com.mono.container.engine

/** Tabs spec §5.2 (user's ruling, 2026-10-02): live pages per container. */
const val MAX_PAGES_PER_CONTAINER = 6

/** A page id: random, runtime only, never reused (tabs spec §2). */
fun newPageId(): String = "p-" + java.util.UUID.randomUUID().toString()

/** What `onCreateWindow` does with one request (tabs spec §5.2). */
internal enum class NewWindowAction {
    /** No user gesture: nothing opens, nothing is shown. */
    REFUSE,
    /** At the cap: read the URL with a capture view and load it in the opener. */
    LOAD_IN_PLACE,
    /** A new page in the same container, brought to the front. */
    NEW_PAGE,
}

internal fun newWindowAction(isUserGesture: Boolean, livePages: Int): NewWindowAction = when {
    !isUserGesture -> NewWindowAction.REFUSE
    livePages >= MAX_PAGES_PER_CONTAINER -> NewWindowAction.LOAD_IN_PLACE
    else -> NewWindowAction.NEW_PAGE
}

/**
 * The URL a capped link loads in its opener, or null to drop it: only
 * http/https with a host ([isLoadableUrl]). `window.open()` with no URL has
 * nothing to load.
 */
internal fun inPlaceUrl(captured: String?): String? =
    captured?.takeIf { isLoadableUrl(it) }

/**
 * Runs [whenAllDone] once, after every page in [pageIds] has reported
 * destroyed (tabs spec §5.8a): a container's wipe waits for every page's
 * Teardown. A page reporting twice counts once, an unknown id is ignored, and
 * an empty [pageIds] runs it at once.
 */
internal class CloseCountdown(pageIds: Collection<String>, private val whenAllDone: () -> Unit) {
    private val remaining = pageIds.toMutableSet()
    private var done = false

    init {
        if (remaining.isEmpty()) finish()
    }

    fun destroyed(pageId: String) {
        if (!remaining.remove(pageId)) return
        if (remaining.isEmpty()) finish()
    }

    private fun finish() {
        if (done) return
        done = true
        whenAllDone()
    }
}

/** The `pages` list a session map carries: id and opener, opening order. */
internal fun pagesToEvent(pages: List<Pair<String, String?>>): List<Map<String, Any?>> =
    pages.map { (id, opener) -> mapOf("pageId" to id, "openerPageId" to opener) }

/** The `page_opened` event (tabs spec §3.1). */
internal fun pageOpenedEvent(siteId: String, pageId: String, openerPageId: String?): Map<String, Any?> =
    mapOf("type" to "page_opened", "siteId" to siteId, "pageId" to pageId, "openerPageId" to openerPageId)

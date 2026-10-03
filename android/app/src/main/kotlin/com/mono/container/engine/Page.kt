package com.mono.container.engine

import android.content.Context
import android.content.MutableContextWrapper
import android.view.ViewGroup
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature

/** What a page tells its engine. Every call is on the main thread. */
interface PageEvents {
    /** Every finished main-frame load; the engine moves an opening session live. */
    fun loaded(page: Page)

    /** A live permission ask; returns its request id, or null when it was
     *  answered at once (keep blocked) and must not be stored. */
    fun ask(page: Page, pending: PendingPermission): String?

    /** A held download; returns its request id. [sizeBytes] is null when the
     *  size is unknown — see [heldDownloadSize]. */
    fun download(page: Page, url: String, mimeType: String, fileName: String, sizeBytes: Long?, kindLabel: String): String

    /** Every change to what the page is doing: browser-chrome spec §3.1's `navigation` event. */
    fun navigated(page: Page, snapshot: NavigationSnapshot)

    /** A finished count for the current find: spec §6.5's `find_result` event. */
    fun found(page: Page, activeMatch: Int, matchCount: Int)

    /** `onCreateWindow`; true when [resultMsg] was handled. */
    fun newWindow(page: Page, isUserGesture: Boolean, resultMsg: android.os.Message): Boolean

    /** The page's own `window.close()`. */
    fun closeRequested(page: Page)

    /** Hardware [resources] the site's config or session already grants. */
    fun grantHardware(request: android.webkit.PermissionRequest, resources: List<String>)
}

/**
 * One page of a container (tabs spec §3.1): one WebView on the session's
 * profile and route, alive until [close] — not until its platform view goes.
 * [PageHost] only attaches and detaches it. Main thread only.
 *
 * Everything the old platform view did to its WebView happens here: the
 * settings, the profile before the first load, the request interceptor's
 * client, the chrome client, the find and download listeners, Shields and the
 * user scripts, service-worker routing, and the [Teardown] that ends it.
 *
 * [firstUrl] is loaded at once; null for a link's page, whose first
 * navigation `onCreateWindow`'s transport hands over.
 */
class Page(
    val id: String,
    val openerId: String?,
    private val appContext: Context,
    private val config: SiteConfig,
    private val session: Session,
    profiles: ProfileManager,
    credentials: SiteCredentials,
    firstUrl: String?,
    private val events: PageEvents,
) {
    /**
     * Swapped to the host's context while attached, back to the app's after:
     * the WebView exists before any view does, and outlives each one.
     */
    private val context = MutableContextWrapper(appContext)

    private var closed = false

    /** This page's own: true from [close] until WebView is destroyed; read on
     *  WebView's IO threads. Never another page's (tabs spec §2): the
     *  interceptor is shared by a session's pages, the flag is not. */
    private val closing = java.util.concurrent.atomic.AtomicBoolean(false)
    private var clearCacheOnDestroy = false
    private var onDestroyed: () -> Unit = {}
    private val teardown = Teardown { destroy() }

    /** Declared before `init`, which hands the clients that feed it to the WebView. */
    private val navigation = NavigationTracker(firstUrl ?: "")

    /** The last `navigation` snapshot, for `navigationState`: Dart may start
     *  listening after the first load has already reported (browser-chrome
     *  spec §3.2). */
    var snapshot: NavigationSnapshot? = null
        private set

    /** From the session's config, like everything else here: every page of a
     *  container, a link's included, is built by `EngineChannel.newPage`. */
    private val policy = securityPolicyFor(config.securityLevel)

    val webView: WebView = WebView(context).apply {
        settings.javaScriptEnabled = policy.javaScriptEnabled
        settings.blockNetworkImage = policy.blockNetworkImage
        settings.domStorageEnabled = true
        settings.userAgentString = userAgentFor(config.userAgentMode, context)
        // Tabs spec §5.2: a link may ask for a new window; script alone may not.
        settings.setSupportMultipleWindows(true)
        settings.javaScriptCanOpenWindowsAutomatically = false
        settings.mediaPlaybackRequiresUserGesture = true
        settings.setSafeBrowsingEnabled(false)   // pings Google directly; see Constraints
        // Pinch zoom. WebView ignores pinches unless its built-in zoom is on;
        // the on-screen +/- buttons that come with it stay hidden. A page whose
        // viewport says `user-scalable=no` still cannot be zoomed.
        settings.setSupportZoom(true)
        settings.builtInZoomControls = true
        settings.displayZoomControls = false

        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, config.forceDark)
        }
        setInitialScale(initialScaleFor(config.pageZoom, context.resources.displayMetrics.density))
    }

    init {
        // Must precede the first load, or the request goes to the default store.
        // For a link's page it precedes the transport's first navigation too.
        androidx.webkit.WebViewCompat.setProfile(webView, config.profileId)
        val interceptor = session.interceptor
        webView.webViewClient = interceptor.clientFor(
            config,
            { credentials.credentialFor(config.profileId) },
            onLoaded = { if (!closing.get()) events.loaded(this) },
            page = object : PageCallbacks {
                override fun started(url: String) = report { navigation.started(url) }
                override fun finished(url: String) {
                    if (closing.get()) teardown.pageFinished(url) else report { navigation.finished(url) }
                }
                override fun visited(url: String) = report { navigation.visited(url) }
            },
            closing = { closing.get() },
        )
        webView.webChromeClient = Shields.chromeClientFor(
            config, session, { pending -> events.ask(this, pending) },
            onProgress = { percent -> report { navigation.progressed(percent) } },
            onTitle = { title -> report { navigation.titled(title) } },
            onNewWindow = { gesture, message -> !closed && events.newWindow(this, gesture, message) },
            onCloseWindow = { if (!closed) events.closeRequested(this) },
            onPreGranted = { request, resources -> events.grantHardware(request, resources) },
        )
        // Reported once counting is done, so the find bar never shows a
        // count that is still climbing.
        webView.setFindListener { activeMatch, matchCount, isDoneCounting ->
            if (isDoneCounting && !closed) events.found(this, activeMatch, matchCount)
        }
        Shields.apply(webView, config, policy,
            onFingerprintNoiseApplied = { session.counters.fingerprinting.incrementAndGet() })

        webView.setDownloadListener { url, _, contentDisposition, mimeType, contentLength ->
            if (closed) return@setDownloadListener
            val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val extension = MimeTypeMap.getFileExtensionFromUrl(url).ifEmpty {
                mimeType?.substringAfter('/') ?: ""
            }
            val resolvedMimeType = mimeType?.ifEmpty { null } ?: "application/octet-stream"
            // Chromium fetched this on every route since P2, so its
            // contentLength means the same everywhere: 0 is unknown.
            val size = heldDownloadSize(contentLength)
            events.download(this, url, resolvedMimeType, fileName, size, extension.uppercase().ifEmpty { "FILE" })
        }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
            routeServiceWorkers(
                WebViewServiceWorkerControllers(profiles), config.profileId,
                site = interceptor.serviceWorkerClient(config), refuseAll = RequestInterceptor.refuseAll,
            )
        }

        if (firstUrl != null) webView.loadUrl(firstUrl)
    }

    /** Applies [change] to the navigation state and reports the result,
     *  unless this page is already closed. */
    private fun report(change: () -> Unit) {
        if (closed) return
        change()
        val next = navigation.snapshot(webView.canGoBack(), webView.canGoForward())
        snapshot = next
        events.navigated(this, next)
    }

    /** Shown: into [frame], on [hostContext], resumed (tabs spec §5.6). */
    fun attach(frame: FrameLayout, hostContext: Context) {
        if (closed) return
        (webView.parent as? ViewGroup)?.removeView(webView)
        context.baseContext = hostContext
        frame.addView(
            webView,
            FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT),
        )
        webView.onResume()
    }

    /** No longer shown: out of [frame] and paused. Never destroyed here. A
     *  frame the page has already left (a newer host took it) changes nothing. */
    fun detach(frame: FrameLayout) {
        if (webView.parent !== frame) return
        frame.removeView(webView)
        if (!closed) webView.onPause()
        context.baseContext = appContext
    }

    fun reload() {
        if (!closed) webView.reload()
    }

    fun goBack() {
        if (!closed && webView.canGoBack()) webView.goBack()
    }

    fun goForward() {
        if (!closed && webView.canGoForward()) webView.goForward()
    }

    fun stop() {
        if (closed) return
        webView.stopLoading()
        report { navigation.stopped() }
    }

    /** Loads [url] in this page, on its container's route. Refuses every
     *  scheme but http and https — see [isLoadableUrl]. */
    fun load(url: String) {
        if (!closed && isLoadableUrl(url)) webView.loadUrl(url)
    }

    fun find(query: String) {
        if (!closed) webView.findAllAsync(query)
    }

    fun findNext(forward: Boolean) {
        if (!closed) webView.findNext(forward)
    }

    fun clearFind() {
        if (!closed) webView.clearMatches()
    }

    /** Runs the reader-mode JS heuristic and hands the parsed article back
     * on the platform thread. `null` when nothing article-shaped was found. */
    fun extractArticle(onResult: (Map<String, Any?>?) -> Unit) {
        if (closed) return onResult(null)
        // A page closed mid-script never runs this callback: [close] answers
        // it null instead, and a late answer after that is dropped.
        val reply = readerReplies.add(onResult)
        webView.evaluateJavascript(READER_JS) { raw ->
            val json = raw?.takeIf { it != "null" }
            reply.answer(json?.let(::parseReaderJson))
        }
    }

    private val readerReplies = PendingReplies<Map<String, Any?>>()

    /**
     * Ends this page without letting its last requests escape ([Teardown]):
     * from here every request is refused, `about:blank` unloads the page, and
     * WebView is destroyed once that finishes or after [Teardown.TIMEOUT_MS].
     * [onDone] runs once, after the destroy. [clearCache] empties the
     * profile's HTTP cache through this WebView first: a wipe, and the
     * profile has no cache clear of its own (see `ProfileManager.wipe`).
     * Idempotent: a second call changes nothing.
     */
    fun close(clearCache: Boolean, onDone: () -> Unit) {
        if (closed) return
        closed = true
        closing.set(true)
        readerReplies.cancelAll()
        clearCacheOnDestroy = clearCache
        onDestroyed = onDone
        webView.stopLoading()
        webView.loadUrl(Teardown.BLANK)
        android.os.Handler(android.os.Looper.getMainLooper())
            .postDelayed({ teardown.timedOut() }, Teardown.TIMEOUT_MS)
    }

    private fun destroy() {
        readerReplies.cancelAll()
        if (clearCacheOnDestroy) webView.clearCache(true)
        (webView.parent as? ViewGroup)?.removeView(webView)
        context.baseContext = appContext
        webView.destroy()
        onDestroyed()
    }
}

/**
 * `setInitialScale` for a site's Page zoom. Its unit is a percentage of
 * physical pixels, so the zoom is scaled by the screen's density; passing it
 * through drew every page at 1/density and ignored `width=device-width`. At
 * 100% the scale is WebView's own (0), which honours the page's viewport.
 */
internal fun initialScaleFor(pageZoom: Int, density: Float): Int =
    if (pageZoom == 100) 0 else Math.round(pageZoom * density)

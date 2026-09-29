package com.mono.container.engine

import android.content.Context
import android.view.View
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.webkit.WebSettings
import androidx.webkit.ServiceWorkerControllerCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.platform.PlatformView

class ContainerView(
    private val context: Context,
    private val config: SiteConfig,
    private val profiles: ProfileManager,
    private val interceptor: RequestInterceptor,
    private val session: Session,
    /** Throwaways still on disk (spec §5.4); a wipe here takes this one off. */
    private val throwaways: ThrowawayJournal,
    private val onLive: () -> Unit = {},
    private val onAsk: (PendingPermission) -> String = { "" },
    /** [sizeBytes] is null when the size is unknown — see [heldDownloadSize]. */
    private val onDownload: (url: String, mimeType: String, fileName: String, sizeBytes: Long?, kindLabel: String) -> String = { _, _, _, _, _ -> "" },
    /** Every change to what the page is doing: browser-chrome spec §3.1's `navigation` event. */
    private val onNavigation: (NavigationSnapshot) -> Unit = {},
    /** A finished count for the current find: spec §6.5's `find_result` event. */
    private val onFindResult: (activeMatch: Int, matchCount: Int) -> Unit = { _, _ -> },
) : PlatformView {

    private var disposed = false

    private val declaredLengths = DeclaredLengths()

    /** Declared before `init`, which hands the clients that feed it to the WebView. */
    private val navigation = NavigationTracker(config.url)

    private val webView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.userAgentString = userAgentFor(config.userAgentMode, context)
        settings.setSupportMultipleWindows(false)
        settings.mediaPlaybackRequiresUserGesture = true
        settings.setSafeBrowsingEnabled(false)   // pings Google directly; see Constraints

        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, config.forceDark)
        }
        setInitialScale(config.pageZoom)
    }

    init {
        // Must precede the first load, or the request goes to the default store.
        androidx.webkit.WebViewCompat.setProfile(webView, config.profileId)
        webView.webViewClient = interceptor.clientFor(config, onLive, declaredLengths, object : PageCallbacks {
            override fun started(url: String) = report { navigation.started(url) }
            override fun finished(url: String) = report { navigation.finished(url) }
            override fun visited(url: String) = report { navigation.visited(url) }
        })
        webView.webChromeClient = Shields.chromeClientFor(
            config, session, onAsk,
            onProgress = { percent -> report { navigation.progressed(percent) } },
            onTitle = { title -> report { navigation.titled(title) } },
        )
        // Reported once counting is done, so the find bar never shows a
        // count that is still climbing.
        webView.setFindListener { activeMatch, matchCount, isDoneCounting ->
            if (isDoneCounting && !disposed) onFindResult(activeMatch, matchCount)
        }
        Shields.apply(webView, config) { session.counters.fingerprinting.incrementAndGet() }

        webView.setDownloadListener { url, _, contentDisposition, mimeType, contentLength ->
            val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val extension = MimeTypeMap.getFileExtensionFromUrl(url).ifEmpty {
                mimeType?.substringAfter('/') ?: ""
            }
            val resolvedMimeType = mimeType?.ifEmpty { null } ?: "application/octet-stream"
            // Not currentRoute(): that probes the proxy, and this is the main
            // thread. Any mode but direct means RequestInterceptor supplied
            // this response, so contentLength is not the server's number.
            val size = heldDownloadSize(config.proxyMode != "direct", contentLength, declaredLengths.take(url))
            onDownload(url, resolvedMimeType, fileName, size, extension.uppercase().ifEmpty { "FILE" })
        }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
            ServiceWorkerControllerCompat.getInstance()
                .setServiceWorkerClient(interceptor.serviceWorkerClient(config))
        }

        webView.loadUrl(config.url)
    }

    override fun getView(): View = webView

    /** Applies [change] to the navigation state and reports the result,
     *  unless this view is already gone. */
    private fun report(change: () -> Unit) {
        if (disposed) return
        change()
        onNavigation(navigation.snapshot(webView.canGoBack(), webView.canGoForward()))
    }

    fun reload() {
        if (!disposed) webView.reload()
    }

    fun goBack() {
        if (!disposed && webView.canGoBack()) webView.goBack()
    }

    fun goForward() {
        if (!disposed && webView.canGoForward()) webView.goForward()
    }

    fun stop() {
        if (disposed) return
        webView.stopLoading()
        report { navigation.stopped() }
    }

    /** Loads [url] in this container, on its own route. Refuses every scheme
     *  but http and https — see [isLoadableUrl]. */
    fun load(url: String) {
        if (!disposed && isLoadableUrl(url)) webView.loadUrl(url)
    }

    fun find(query: String) {
        if (!disposed) webView.findAllAsync(query)
    }

    fun findNext(forward: Boolean) {
        if (!disposed) webView.findNext(forward)
    }

    fun clearFind() {
        if (!disposed) webView.clearMatches()
    }

    /** Runs the reader-mode JS heuristic and hands the parsed article back
     * on the platform thread. `null` when nothing article-shaped was found. */
    fun extractArticle(onResult: (Map<String, Any?>?) -> Unit) {
        if (disposed) {
            onResult(null)
            return
        }
        webView.evaluateJavascript(READER_JS) { rawJson ->
            val json = rawJson?.takeIf { it != "null" }
            if (json == null) {
                onResult(null)
                return@evaluateJavascript
            }
            onResult(parseReaderJson(json))
        }
    }

    /**
     * Idempotent: `close` on the engine channel and Flutter tearing the
     * platform view down both land here, in either order, and destroying a
     * WebView twice is not safe.
     */
    override fun dispose() {
        if (disposed) return
        disposed = true
        webView.stopLoading()
        // The session's flag, not the config's: `keep` turns it off for a
        // throwaway saved as a site while its page is still open.
        val wipe = session.wipeOnExit
        // The profile this view used cannot be deleted until the next start
        // (see ProfileManager.wipe), and its HTTP cache has no profile-level
        // clear — the view is the only handle on it, so empty it now.
        if (wipe) webView.clearCache(true)
        webView.destroy()
        if (wipe) {
            // Off the throwaway journal only once the wipe has run: a wipe
            // that throws leaves it for the next start's sweep.
            wipeThenForget(config.profileId, throwaways) {
                deleteDownloadsDir(context, config.profileId)
                profiles.wipe(config.profileId)
            }
        }
    }

}

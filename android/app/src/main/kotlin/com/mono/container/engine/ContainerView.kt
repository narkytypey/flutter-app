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
    context: Context,
    private val config: SiteConfig,
    private val profiles: ProfileManager,
    private val interceptor: RequestInterceptor,
    private val session: Session,
    private val onLive: () -> Unit = {},
    private val onAsk: (PendingPermission) -> String = { "" },
    private val onDownload: (fileName: String, sizeBytes: Long, kindLabel: String) -> Unit = { _, _, _ -> },
) : PlatformView {

    private var disposed = false

    private val webView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.userAgentString = userAgentFor(config.userAgentMode)
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
        webView.webViewClient = interceptor.clientFor(config, onLive)
        webView.webChromeClient = Shields.chromeClientFor(config, session, onAsk)
        Shields.apply(webView, config) { session.counters.fingerprinting.incrementAndGet() }

        webView.setDownloadListener { url, _, contentDisposition, mimeType, contentLength ->
            val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val extension = MimeTypeMap.getFileExtensionFromUrl(url).ifEmpty {
                mimeType?.substringAfter('/') ?: ""
            }
            onDownload(fileName, contentLength, extension.uppercase().ifEmpty { "FILE" })
        }

        if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
            ServiceWorkerControllerCompat.getInstance()
                .setServiceWorkerClient(interceptor.serviceWorkerClient(config))
        }

        webView.loadUrl(config.url)
    }

    override fun getView(): View = webView

    fun reload() {
        if (!disposed) webView.reload()
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
        webView.destroy()
        if (config.wipeOnExit) profiles.wipe(config.profileId)
    }

    private fun userAgentFor(mode: String): String = when (mode) {
        "desktop" -> "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        "minimal" -> "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
        else -> WebSettings.getDefaultUserAgent(webView.context)
    }
}

package com.mono.container.engine

import android.webkit.HttpAuthHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.ByteArrayInputStream

/** The page events [ContainerView] builds its navigation state from. */
interface PageCallbacks {
    fun started(url: String) {}
    fun finished(url: String) {}
    fun visited(url: String) {}

    companion object {
        val NONE = object : PageCallbacks {}
    }
}

/**
 * A site's WebView hooks. Since P2 (spec §1.4) Chromium does every fetch
 * itself, through the loopback proxy, which routes it by the site's credential
 * — so proxied sites keep cookies, follow redirects and send POST bodies. What
 * is left here happens before a request reaches Chromium's network stack: a
 * closing view refuses everything, and a filter-list match is blocked.
 * [onRefused] hears a main frame's failure ([mainFrameFailure]).
 */
class RequestInterceptor(private val filters: FilterEngine, private val onRefused: (RouteFailure) -> Unit = {}) {
    /** [proxyCredential] answers the loopback proxy's `407` (P2 spec §1.4): every
     *  call, at once, from memory. [page] hears the page starting, finishing and
     *  moving through history (browser-chrome spec §3.1). [closing] is this one
     *  view's: once it is true, every request is refused (see [dispositionFor]).
     *  It is per view, not per interceptor, because a session — and its
     *  interceptor — outlives the views that show it. */
    fun clientFor(
        config: SiteConfig,
        proxyCredential: () -> ProxyCredential,
        onLoaded: () -> Unit = {},
        page: PageCallbacks = PageCallbacks.NONE,
        closing: () -> Boolean = { false },
    ): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
            intercept(config, request, closing())

        override fun onReceivedHttpAuthRequest(view: WebView, handler: HttpAuthHandler, host: String?, realm: String?) {
            val answer = proxyAuthAnswer(host, realm, proxyCredential)
            if (answer != null) handler.proceed(answer.user, answer.password)
            else super.onReceivedHttpAuthRequest(view, handler, host, realm)
        }

        /** A subresource's failure never takes over the screen (P2 spec §3.3). */
        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            if (request.isForMainFrame && !closing()) mainFrameFailure(error.errorCode)?.let(onRefused)
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
            if (url != null) page.started(url)
        }

        override fun onPageFinished(view: WebView, url: String?) {
            onLoaded()
            if (url != null) page.finished(url)
        }

        override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
            if (url != null) page.visited(url)
        }
    }

    /** A service worker's requests for [config]'s site, gated like its pages. */
    fun serviceWorkerClient(config: SiteConfig): (WebResourceRequest) -> WebResourceResponse? = { request -> intercept(config, request) }

    private fun intercept(config: SiteConfig, request: WebResourceRequest, closing: Boolean = false): WebResourceResponse? =
        when (dispositionFor(closing, blockedByFilter = { config.blockTrackers && filters.matches(request.url.toString()) != null })) {
            Disposition.Closed -> closed()
            Disposition.Blocked -> blocked()
            Disposition.ByWebView -> null
        }

    companion object {
        /** For requests that belong to no site: refused, and reported to no one. */
        val refuseAll: (WebResourceRequest) -> WebResourceResponse? = { closed() }

        private fun closed() = WebResourceResponse(
            "text/plain", "utf-8", 523, "Refused", emptyMap(), ByteArrayInputStream(ByteArray(0))
        )
    }

    private fun blocked() = WebResourceResponse("text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0)))
}

/**
 * The failure a main frame's WebView error reports, or null. Chromium does the
 * TLS since P2 (spec §3.3), so a handshake that fails arrives as
 * `ERROR_FAILED_SSL_HANDSHAKE`. Every other code — the loopback proxy's `502`
 * and `504` included — is left to WebView's own error page. Certificate errors
 * never come here: they go to `onReceivedSslError`, whose default cancels.
 */
internal fun mainFrameFailure(errorCode: Int): RouteFailure? =
    if (errorCode == WebViewClient.ERROR_FAILED_SSL_HANDSHAKE) RouteFailure.TLS_FAILURE else null

package com.mono.container.engine

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

class RequestInterceptor(private val filters: FilterEngine, private val onRefused: (RouteFailure) -> Unit = {}) {
    /** [lengths] records each proxied response's declared length, for the
     *  view's held-download sheet. [page] hears the page starting, finishing
     *  and moving through history (browser-chrome spec §3.1). */
    fun clientFor(
        config: SiteConfig,
        onLoaded: () -> Unit = {},
        lengths: DeclaredLengths? = null,
        page: PageCallbacks = PageCallbacks.NONE,
    ): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? = intercept(config, request, lengths)

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

    /** A service worker's requests for [config]'s site, routed like its pages. */
    fun serviceWorkerClient(config: SiteConfig): (WebResourceRequest) -> WebResourceResponse? = { request -> intercept(config, request) }

    private fun intercept(config: SiteConfig, request: WebResourceRequest, lengths: DeclaredLengths? = null): WebResourceResponse? {
        if (config.blockTrackers && filters.matches(request.url.toString()) != null) return blocked()
        return when (val route = config.currentRoute()) {
            is Route.Direct -> null
            is Route.Proxy -> fetchThrough(route, request, lengths)
            is Route.Refused -> { onRefused(route.failure); refused(route.failure) }
        }
    }

    companion object {
        /** For requests that belong to no site: refused, and reported to no one. */
        val refuseAll: (WebResourceRequest) -> WebResourceResponse? = { closed() }

        private fun closed() = WebResourceResponse(
            "text/plain", "utf-8", 523, "Refused", emptyMap(), ByteArrayInputStream(ByteArray(0))
        )
    }

    private fun blocked() = WebResourceResponse("text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0)))

    private fun refused(failure: RouteFailure) = WebResourceResponse(
        "text/plain", "utf-8", 523, "Route refused", mapOf("X-Container-Refusal" to failure.name), ByteArrayInputStream(ByteArray(0))
    )

    private fun fetchThrough(route: Route.Proxy, request: WebResourceRequest, lengths: DeclaredLengths?): WebResourceResponse {
        val url = request.url
        val host = url.host ?: return refused(RouteFailure.MISCONFIGURED)
        val port = if (url.port != -1) url.port else if (url.scheme == "https") 443 else 80
        return runCatching {
            val path = (url.path?.ifEmpty { "/" } ?: "/") + (url.query?.let { "?$it" } ?: "")
            val response = ProxyHttpClient.fetch(route, host, port, url.scheme == "https", request.method, path, request.requestHeaders)
            lengths?.record(url.toString(), response.headers)
            val (mimeType, charset) = mediaTypeOf(response.headers)
            WebResourceResponse(mimeType, charset, response.status, response.reason, response.headers, response.body)
        }.getOrElse { error ->
            refused(when (error) {
                is ProxyTunnelException -> RouteFailure.PROXY_REFUSED
                is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
                is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
                is java.net.ConnectException -> RouteFailure.PROXY_UNREACHABLE
                // Router.resolve admits only the modes connect() can open, so
                // nothing reaches this today. Kept so that any future
                // unsupported Proxy.Type can never again surface to the user
                // as a bogus upstream timeout.
                is IllegalArgumentException -> RouteFailure.MISCONFIGURED
                else -> RouteFailure.UPSTREAM_TIMEOUT
            })
        }
    }
}

/**
 * The media type and charset WebView is handed for a proxied response.
 *
 * Header names and parameter names are case-insensitive (RFC 9110 §5.1,
 * §8.3.1), and a parameter value may be quoted. A case-sensitive lookup made
 * a server that sends `content-type` look like it sent none, so its page was
 * held as a download.
 */
internal fun mediaTypeOf(headers: Map<String, String>): Pair<String, String> {
    val contentType = headers.entries.firstOrNull { it.key.equals("Content-Type", ignoreCase = true) }?.value
    val parts = contentType?.split(';').orEmpty()
    val mimeType = parts.firstOrNull()?.trim()?.ifEmpty { null } ?: "application/octet-stream"
    val charset = parts.drop(1)
        .map { it.trim() }
        .firstOrNull { it.startsWith("charset=", ignoreCase = true) }
        ?.substringAfter('=')?.trim()?.removeSurrounding("\"")?.ifEmpty { null }
        ?: "utf-8"
    return mimeType to charset
}

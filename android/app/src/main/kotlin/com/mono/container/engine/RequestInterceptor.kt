package com.mono.container.engine

import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.ServiceWorkerClientCompat
import java.io.ByteArrayInputStream

class RequestInterceptor(private val filters: FilterEngine, private val onRefused: (RouteFailure) -> Unit = {}) {
    /** [lengths] records each proxied response's declared length, for the
     *  view's held-download sheet. */
    fun clientFor(config: SiteConfig, onLoaded: () -> Unit = {}, lengths: DeclaredLengths? = null): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? = intercept(config, request, lengths)
        override fun onPageFinished(view: WebView, url: String) = onLoaded()
    }

    fun serviceWorkerClient(config: SiteConfig): ServiceWorkerClientCompat = object : ServiceWorkerClientCompat() {
        override fun shouldInterceptRequest(request: WebResourceRequest): WebResourceResponse? = intercept(config, request)
    }

    private fun intercept(config: SiteConfig, request: WebResourceRequest, lengths: DeclaredLengths? = null): WebResourceResponse? {
        if (config.blockTrackers && filters.matches(request.url.toString()) != null) return blocked()
        return when (val route = config.currentRoute()) {
            is Route.Direct -> null
            is Route.Proxy -> fetchThrough(route, request, lengths)
            is Route.Refused -> { onRefused(route.failure); refused(route.failure) }
        }
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
            val contentType = response.headers["Content-Type"]
            val mimeType = contentType?.substringBefore(';')?.trim() ?: "application/octet-stream"
            val charset = contentType?.substringAfter("charset=", "")?.trim()?.ifEmpty { null } ?: "utf-8"
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

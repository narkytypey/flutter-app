package com.mono.container.engine

import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.ServiceWorkerClientCompat
import java.io.ByteArrayInputStream

class RequestInterceptor(private val filters: FilterEngine, private val onRefused: (RouteFailure) -> Unit = {}) {
    fun clientFor(config: SiteConfig, onLoaded: () -> Unit = {}): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? = intercept(config, request)
        override fun onPageFinished(view: WebView, url: String) = onLoaded()
    }

    fun serviceWorkerClient(config: SiteConfig): ServiceWorkerClientCompat = object : ServiceWorkerClientCompat() {
        override fun shouldInterceptRequest(request: WebResourceRequest): WebResourceResponse? = intercept(config, request)
    }

    private fun intercept(config: SiteConfig, request: WebResourceRequest): WebResourceResponse? {
        if (config.blockTrackers && filters.matches(request.url.toString()) != null) return blocked()
        return when (val route = config.currentRoute()) {
            is Route.Direct -> null
            is Route.Proxy -> fetchThrough(route, request)
            is Route.Refused -> { onRefused(route.failure); refused(route.failure) }
        }
    }

    private fun blocked() = WebResourceResponse("text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0)))

    private fun refused(failure: RouteFailure) = WebResourceResponse(
        "text/plain", "utf-8", 523, "Route refused", mapOf("X-Container-Refusal" to failure.name), ByteArrayInputStream(ByteArray(0))
    )

    private fun fetchThrough(route: Route.Proxy, request: WebResourceRequest): WebResourceResponse {
        val url = request.url
        val host = url.host ?: return refused(RouteFailure.MISCONFIGURED)
        val port = if (url.port != -1) url.port else if (url.scheme == "https") 443 else 80
        return runCatching {
            val path = (url.path?.ifEmpty { "/" } ?: "/") + (url.query?.let { "?$it" } ?: "")
            val response = ProxyHttpClient.fetch(route, host, port, request.method, path, request.requestHeaders)
            val contentType = response.headers["Content-Type"]
            val mimeType = contentType?.substringBefore(';')?.trim() ?: "application/octet-stream"
            val charset = contentType?.substringAfter("charset=", "")?.trim()?.ifEmpty { null } ?: "utf-8"
            WebResourceResponse(mimeType, charset, response.status, response.reason, response.headers, response.body)
        }.getOrElse { error ->
            refused(when (error) {
                is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
                is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
                is java.net.ConnectException -> RouteFailure.PROXY_UNREACHABLE
                else -> RouteFailure.UPSTREAM_TIMEOUT
            })
        }
    }
}

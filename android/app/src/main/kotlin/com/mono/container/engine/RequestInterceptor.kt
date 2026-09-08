package com.mono.container.engine

import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.ServiceWorkerClientCompat
import java.io.ByteArrayInputStream

class RequestInterceptor(
    private val filters: FilterEngine,
    private val onRefused: (RouteFailure) -> Unit = {},
) {

    /** One client per site. This is what `ProxyController` could never do. */
    fun clientFor(
        config: SiteConfig,
        onLoaded: () -> Unit = {},
    ): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(
            view: WebView,
            request: WebResourceRequest,
        ): WebResourceResponse? = intercept(config, request)

        override fun onPageFinished(view: WebView, url: String) {
            onLoaded()
        }
    }

    /**
     * Service-worker-issued requests bypass [WebViewClient] entirely, so the
     * same filter-and-route logic has to be registered again here — see
     * "What the interceptor cannot see" in Global Constraints. Without this, a
     * site with a service worker routes around every guarantee in this plan.
     */
    fun serviceWorkerClient(config: SiteConfig): ServiceWorkerClientCompat =
        object : ServiceWorkerClientCompat() {
            override fun shouldInterceptRequest(
                request: WebResourceRequest,
            ): WebResourceResponse? = intercept(config, request)
        }

    private fun intercept(config: SiteConfig, request: WebResourceRequest): WebResourceResponse? {
        val url = request.url.toString()

        if (config.blockTrackers && filters.matches(url) != null) return blocked()

        return when (val route = config.currentRoute()) {
            is Route.Direct -> null   // let WebView fetch it itself
            is Route.Proxy -> fetchThrough(route, request)
            is Route.Refused -> { onRefused(route.failure); refused(route.failure) }
        }
    }

    /** A 204 with no body. The request is simply not made. */
    private fun blocked() = WebResourceResponse(
        "text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0))
    )

    /**
     * Turn 8's rule at the only layer that can enforce it. Returning a response
     * here means WebView never opens its own socket — which is precisely why
     * there is no silent direct fallback anywhere in this app.
     */
    private fun refused(failure: RouteFailure) = WebResourceResponse(
        "text/plain", "utf-8", 523, "Route refused",
        mapOf("X-Container-Refusal" to failure.name), ByteArrayInputStream(ByteArray(0))
    )

    /**
     * Fetches via [ProxyHttpClient] and streams the response straight back to
     * WebView. Never returns null on failure — see the class doc — every exit
     * is either a real response or [refused].
     */
    private fun fetchThrough(
        route: Route.Proxy,
        request: WebResourceRequest,
    ): WebResourceResponse {
        val url = request.url
        val host = url.host ?: return refused(RouteFailure.MISCONFIGURED)
        val targetPort = if (url.port != -1) url.port else if (url.scheme == "https") 443 else 80

        return runCatching {
            val path = (url.path?.ifEmpty { "/" } ?: "/") + (url.query?.let { "?$it" } ?: "")
            val response = ProxyHttpClient.fetch(
                route, host, targetPort, request.method, path, request.requestHeaders,
            )
            val contentType = response.headers["Content-Type"]
            val mimeType = contentType?.substringBefore(';')?.trim()
                ?: "application/octet-stream"
            val charset = contentType?.substringAfter("charset=", "")?.trim()
                ?.ifEmpty { null } ?: "utf-8"
            WebResourceResponse(
                mimeType, charset, response.status, response.reason, response.headers, response.body,
            )
        }.getOrElse { error ->
            refused(
                when (error) {
                    is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
                    is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
                    is java.net.ConnectException -> RouteFailure.PROXY_UNREACHABLE
                    else -> RouteFailure.UPSTREAM_TIMEOUT
                }
            )
        }
    }
}

package com.mono.container.engine

import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.ServiceWorkerClientCompat
import java.io.ByteArrayInputStream

class RequestInterceptor(private val filters: FilterEngine) {

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

        if (config.blockTrackers && filters.matches(url)) return blocked()

        return when (val route = Router.resolve(config, proxyReachable(config))) {
            is Route.Direct -> null   // let WebView fetch it itself
            is Route.Proxy -> fetchThrough(route, request)
            is Route.Refused -> refused(route.failure)
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
     * Opens the socket, writes a bare HTTP/1.1 request line, and streams the
     * response straight back to WebView. Never returns null on failure — see
     * the class doc — every exit is either a real response or [refused].
     */
    private fun fetchThrough(
        route: Route.Proxy,
        request: WebResourceRequest,
    ): WebResourceResponse {
        val url = request.url
        val host = url.host ?: return refused(RouteFailure.MISCONFIGURED)
        val targetPort = if (url.port != -1) url.port else if (url.scheme == "https") 443 else 80

        return runCatching {
            val socket = Router.connect(route, host, targetPort)
            socket.soTimeout = 15_000
            val out = socket.getOutputStream()
            val path = url.path.ifEmpty { "/" } + (url.query?.let { "?$it" } ?: "")
            out.write("${request.method} $path HTTP/1.1\r\n".toByteArray(Charsets.US_ASCII))
            out.write("Host: $host\r\n".toByteArray(Charsets.US_ASCII))
            request.requestHeaders.forEach { (k, v) ->
                out.write("$k: $v\r\n".toByteArray(Charsets.US_ASCII))
            }
            out.write("Connection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
            out.flush()

            val input = socket.getInputStream()
            val (status, reason, headers) = readStatusAndHeaders(input)
            val contentType = headers["Content-Type"]
            val mimeType = contentType?.substringBefore(';')?.trim()
                ?: "application/octet-stream"
            val charset = contentType?.substringAfter("charset=", "")?.trim()
                ?.ifEmpty { null } ?: "utf-8"
            WebResourceResponse(mimeType, charset, status, reason, headers, input)
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

    /**
     * Reads one CRLF-terminated line a byte at a time. A [java.io.BufferedReader]
     * would over-read into its own buffer and swallow the first bytes of the
     * response body along with the headers; this stops exactly at the blank
     * line so [input] is positioned at byte zero of the body for the caller.
     */
    private fun readLine(input: java.io.InputStream): String {
        val line = StringBuilder()
        while (true) {
            val b = input.read()
            if (b == -1 || b == '\n'.code) break
            if (b != '\r'.code) line.append(b.toChar())
        }
        return line.toString()
    }

    private fun readStatusAndHeaders(
        input: java.io.InputStream,
    ): Triple<Int, String, Map<String, String>> {
        val statusLine = readLine(input)
        val parts = statusLine.split(' ', limit = 3)
        val status = parts.getOrNull(1)?.toIntOrNull() ?: 502
        val reason = parts.getOrNull(2) ?: "OK"

        val headers = mutableMapOf<String, String>()
        while (true) {
            val line = readLine(input)
            if (line.isEmpty()) break
            val idx = line.indexOf(':')
            if (idx > 0) headers[line.substring(0, idx).trim()] = line.substring(idx + 1).trim()
        }
        return Triple(status, reason, headers)
    }

    /** `config`, not a bare host/port: each site can point at a different proxy. */
    private fun proxyReachable(config: SiteConfig): Boolean {
        val host = config.proxyHost ?: return false
        val port = config.proxyPort ?: return false
        return ProxyProbe.reachable(host, port)
    }
}

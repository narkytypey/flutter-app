package com.mono.container.engine

import java.io.InputStream

/** Shared bare HTTP client for proxied page and download requests. */
object ProxyHttpClient {
    data class FetchedResponse(val status: Int, val reason: String, val headers: Map<String, String>, val body: InputStream)

    fun fetch(
        route: Route,
        host: String,
        port: Int,
        secure: Boolean,
        method: String,
        path: String,
        requestHeaders: Map<String, String>,
    ): FetchedResponse {
        val connected = Router.connect(route, host, port)
        connected.soTimeout = 15_000
        val socket = startTls(connected, host, port, secure)
        val out = socket.getOutputStream()
        out.write("$method $path HTTP/1.1\r\n".toByteArray(Charsets.US_ASCII))
        out.write("Host: $host\r\n".toByteArray(Charsets.US_ASCII))
        requestHeaders.forEach { (key, value) -> out.write("$key: $value\r\n".toByteArray(Charsets.US_ASCII)) }
        out.write("Connection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
        out.flush()
        val input = socket.getInputStream()
        val parts = readLine(input).split(' ', limit = 3)
        val status = parts.getOrNull(1)?.toIntOrNull() ?: 502
        val reason = parts.getOrNull(2) ?: "OK"
        val headers = mutableMapOf<String, String>()
        while (true) {
            val line = readLine(input)
            if (line.isEmpty()) break
            val separator = line.indexOf(':')
            if (separator > 0) headers[line.substring(0, separator).trim()] = line.substring(separator + 1).trim()
        }
        return FetchedResponse(status, reason, headers, input)
    }

    /**
     * Wraps a connected socket in TLS for https targets, and returns it
     * unchanged for http ones.
     *
     * This layers on top of whatever [Router.connect] produced — a direct
     * socket or a SOCKS-routed one — because both already speak end to end
     * with the target.
     *
     * There is deliberately no CONNECT-tunnel case here. Android removed
     * `Proxy.Type.HTTP` support from [java.net.Socket] (see the
     * `// Android-changed: Removed HTTP proxy support.` marker in libcore), so
     * a [Route.Proxy] with `socks = false` throws `IllegalArgumentException`
     * at socket construction and never reaches this function. Implementing
     * CONNECT by hand is what would make an HTTP-proxy socket arrive here.
     *
     * `endpointIdentificationAlgorithm` is not optional. The default
     * [javax.net.ssl.SSLSocketFactory] validates the certificate chain but does
     * **not** check that the certificate belongs to [host], so omitting it
     * would accept any valid certificate from any server — an encrypted
     * connection to possibly the wrong peer, which is worse than an honest
     * plaintext failure because it looks safe. Requires API 24+; minSdk is 29.
     */
    private fun startTls(socket: java.net.Socket, host: String, port: Int, secure: Boolean): java.net.Socket {
        if (!secure) return socket
        val factory = javax.net.ssl.SSLSocketFactory.getDefault() as javax.net.ssl.SSLSocketFactory
        val tls = factory.createSocket(socket, host, port, true) as javax.net.ssl.SSLSocket
        tls.sslParameters = tls.sslParameters.apply { endpointIdentificationAlgorithm = "HTTPS" }
        tls.startHandshake()
        return tls
    }

    private fun readLine(input: InputStream): String {
        val line = StringBuilder()
        while (true) {
            val byte = input.read()
            if (byte == -1 || byte == '\n'.code) break
            if (byte != '\r'.code) line.append(byte.toChar())
        }
        return line.toString()
    }
}

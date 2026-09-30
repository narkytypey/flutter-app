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
        out.write("Host: ${hostHeader(host, port, secure)}\r\n".toByteArray(Charsets.US_ASCII))
        requestHeaders.forEach { (key, value) -> out.write("$key: $value\r\n".toByteArray(Charsets.US_ASCII)) }
        out.write("Connection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
        out.flush()
        val input = socket.getInputStream()
        val parts = readLine(input).split(' ', limit = 3)
        val status = parts.getOrNull(1)?.toIntOrNull() ?: 502
        val reason = parts.getOrNull(2) ?: "OK"
        // Header names are case-insensitive (RFC 9110 §5.1): every reader —
        // the interceptor, the download size, the download writer — looks
        // names up in this map, so it is the one place that has to know.
        val headers = java.util.TreeMap<String, String>(String.CASE_INSENSITIVE_ORDER)
        while (true) {
            val line = readLine(input)
            if (line.isEmpty()) break
            val separator = line.indexOf(':')
            if (separator > 0) headers[line.substring(0, separator).trim()] = line.substring(separator + 1).trim()
        }
        return FetchedResponse(status, reason, headers, bodyOf(input, headers))
    }

    /**
     * The body as its bytes, not its framing. Whenever `Transfer-Encoding` is
     * present, `Content-Length` is removed: the former overrides the latter
     * (RFC 9112 §6.3), so it never describes these bytes. When the last
     * transfer coding is `chunked`, the framing is decoded here, and `chunked`
     * is dropped from the list if other codings precede it.
     * `Transfer-Encoding` itself is kept whenever it was sent.
     */
    private fun bodyOf(input: InputStream, headers: MutableMap<String, String>): InputStream {
        val codings = headers["Transfer-Encoding"]?.split(',')?.map { it.trim() }?.filter { it.isNotEmpty() }
            ?: return input
        headers.remove("Content-Length")
        if (!codings.last().equals("chunked", ignoreCase = true)) return input
        val rest = codings.dropLast(1)
        headers["Transfer-Encoding"] = if (rest.isEmpty()) "chunked" else rest.joinToString(", ")
        return ChunkedBody(input)
    }

    /**
     * The `Host` value for [host]:[port]. RFC 9110 §7.2 requires the port
     * whenever it is not the scheme's default, and an origin serving several
     * sites on one non-default port routes by exactly this line — without it
     * the request can reach the wrong virtual host.
     */
    internal fun hostHeader(host: String, port: Int, secure: Boolean): String =
        if (port == (if (secure) 443 else 80)) host else "$host:$port"

    /**
     * Wraps a connected socket in TLS for https targets, and returns it
     * unchanged for http ones.
     *
     * This layers on top of whatever [Router.connect] produced — a direct
     * socket, a SOCKS-routed one, or an HTTP-proxy socket already tunnelled by
     * [HttpConnectTunnel] — because all three already speak end to end with
     * the target.
     *
     * The HTTP-proxy case reaches this function. Android removed
     * `Proxy.Type.HTTP` support from [java.net.Socket] (see the
     * `// Android-changed: Removed HTTP proxy support.` marker in libcore), so
     * [HttpConnectTunnel] issues the CONNECT by hand and returns a socket whose
     * payload is relayed to the target. Wrapping that socket therefore
     * negotiates TLS with the destination, not with the proxy — which is what
     * makes the certificate check below meaningful on a proxied route.
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

/**
 * Decodes RFC 9112 §7.1 chunked framing: each chunk is a hex size (with any
 * `;extension` ignored), CRLF, that many bytes, CRLF; a zero size ends the
 * body, and the trailer section after it is read and discarded up to its
 * blank line, so nothing past the body is consumed.
 *
 * A stream that ends before the zero-size chunk throws rather than ending
 * early: a cut-off body must never pass for a complete, shorter one.
 */
class ChunkedBody(private val input: java.io.InputStream) : java.io.InputStream() {
    private var remaining = 0L
    private var finished = false

    override fun read(): Int {
        val one = ByteArray(1)
        return if (read(one, 0, 1) == -1) -1 else one[0].toInt() and 0xff
    }

    override fun read(buffer: ByteArray, offset: Int, length: Int): Int {
        if (length == 0) return 0
        if (finished) return -1
        if (remaining == 0L) {
            remaining = nextChunkSize()
            if (remaining == 0L) {
                while (readLine().isNotEmpty()) { /* trailer fields are not used */ }
                finished = true
                return -1
            }
        }
        val count = input.read(buffer, offset, minOf(length.toLong(), remaining).toInt())
        if (count == -1) throw java.io.EOFException("chunked body ended inside a chunk")
        remaining -= count
        if (remaining == 0L && readLine().isNotEmpty()) throw java.io.IOException("chunk not followed by CRLF")
        return count
    }

    override fun close() = input.close()

    private fun nextChunkSize(): Long {
        val size = readLine().substringBefore(';').trim()
        val hex = size.isNotEmpty() && size.length <= 15 &&
            size.all { it in '0'..'9' || it in 'a'..'f' || it in 'A'..'F' }
        if (!hex) throw java.io.IOException("bad chunk size: $size")
        return size.toLong(16)
    }

    private fun readLine(): String {
        val line = StringBuilder()
        while (true) {
            val byte = input.read()
            if (byte == -1) throw java.io.EOFException("chunked body ended before its last chunk")
            if (byte == '\n'.code) return line.toString()
            if (byte != '\r'.code) line.append(byte.toChar())
        }
    }
}

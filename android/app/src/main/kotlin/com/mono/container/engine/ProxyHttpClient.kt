package com.mono.container.engine

import java.io.InputStream

/**
 * Shared HTTP/1.1-over-socket client used by [RequestInterceptor] (page
 * loads) and, in a later plan step, downloads — one place that knows how to
 * open a [Route] and speak bare HTTP over it, instead of two copies of the
 * same byte-at-a-time header parser.
 */
object ProxyHttpClient {

    data class FetchedResponse(
        val status: Int,
        val reason: String,
        val headers: Map<String, String>,
        val body: InputStream,
    )

    /**
     * Opens a socket for [route] (via [Router.connect]), writes a bare
     * HTTP/1.1 request line, Host header, [requestHeaders] and a blank line,
     * then reads back the status line and headers. [FetchedResponse.body] is
     * the still-open response [InputStream], positioned at byte zero of the
     * body. Never called for [Route.Refused] — see [Router.connect].
     */
    fun fetch(
        route: Route,
        host: String,
        port: Int,
        method: String,
        path: String,
        requestHeaders: Map<String, String>,
    ): FetchedResponse {
        val socket = Router.connect(route, host, port)
        socket.soTimeout = 15_000
        val out = socket.getOutputStream()
        out.write("$method $path HTTP/1.1\r\n".toByteArray(Charsets.US_ASCII))
        out.write("Host: $host\r\n".toByteArray(Charsets.US_ASCII))
        requestHeaders.forEach { (k, v) ->
            out.write("$k: $v\r\n".toByteArray(Charsets.US_ASCII))
        }
        out.write("Connection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
        out.flush()

        val input = socket.getInputStream()
        val (status, reason, headers) = readStatusAndHeaders(input)
        return FetchedResponse(status, reason, headers, input)
    }

    /**
     * Reads one CRLF-terminated line a byte at a time. A [java.io.BufferedReader]
     * would over-read into its own buffer and swallow the first bytes of the
     * response body along with the headers; this stops exactly at the blank
     * line so the input stream is positioned at byte zero of the body for the
     * caller.
     */
    private fun readLine(input: InputStream): String {
        val line = StringBuilder()
        while (true) {
            val b = input.read()
            if (b == -1 || b == '\n'.code) break
            if (b != '\r'.code) line.append(b.toChar())
        }
        return line.toString()
    }

    private fun readStatusAndHeaders(
        input: InputStream,
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
}

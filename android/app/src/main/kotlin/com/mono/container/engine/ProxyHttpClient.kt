package com.mono.container.engine

import java.io.InputStream

/** Shared bare HTTP client for proxied page and download requests. */
object ProxyHttpClient {
    data class FetchedResponse(val status: Int, val reason: String, val headers: Map<String, String>, val body: InputStream)

    fun fetch(route: Route, host: String, port: Int, method: String, path: String, requestHeaders: Map<String, String>): FetchedResponse {
        val socket = Router.connect(route, host, port)
        socket.soTimeout = 15_000
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

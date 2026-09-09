package com.mono.container.engine

import java.io.IOException
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Raised when a proxy answers CONNECT with anything other than 2xx — a 407
 * wanting credentials, a 403 refusing the destination, a 502 failing to reach
 * it. Carries [statusCode] so callers can tell those apart if they ever need
 * to; today they all map to one failure.
 */
class ProxyTunnelException(val statusCode: Int, message: String) : IOException(message)

/**
 * Opens an HTTP CONNECT tunnel by hand.
 *
 * Android removed `Proxy.Type.HTTP` from [java.net.Socket] — see the
 * `// Android-changed: Removed HTTP proxy support.` marker in libcore's
 * `Socket.java` — so OpenJDK's `HttpConnectSocketImpl`, which would have
 * issued this CONNECT, does not exist here. Constructing a socket with a
 * `Type.HTTP` proxy throws `IllegalArgumentException("Invalid Proxy")`
 * instead. This object is that missing implementation.
 *
 * The returned socket is connected to the proxy but addressed to the target:
 * everything written after CONNECT succeeds is relayed end to end, which is
 * what makes it safe for [ProxyHttpClient] to negotiate TLS over it.
 */
object HttpConnectTunnel {
    private const val CONNECT_TIMEOUT_MS = 15_000

    fun open(proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int): Socket {
        val socket = Socket()
        try {
            socket.connect(InetSocketAddress(proxyHost, proxyPort), CONNECT_TIMEOUT_MS)
            socket.soTimeout = CONNECT_TIMEOUT_MS
            val authority = "$targetHost:$targetPort"
            val out = socket.getOutputStream()
            out.write("CONNECT $authority HTTP/1.1\r\n".toByteArray(Charsets.US_ASCII))
            out.write("Host: $authority\r\n".toByteArray(Charsets.US_ASCII))
            out.write("\r\n".toByteArray(Charsets.US_ASCII))
            out.flush()

            val status = readStatus(socket.getInputStream())
            if (status !in 200..299) {
                throw ProxyTunnelException(status, "Proxy refused CONNECT to $authority (HTTP $status)")
            }
            return socket
        } catch (error: Throwable) {
            // Never leak a half-open socket to the proxy. Closing here also
            // means a caller that catches the exception has nothing to clean up.
            runCatching { socket.close() }
            throw error
        }
    }

    /**
     * Reads the status line and drains the header block, leaving the stream
     * positioned at the first byte of tunnel payload. The body of a CONNECT
     * response is empty by definition, so there is nothing else to consume.
     */
    private fun readStatus(input: InputStream): Int {
        val statusLine = readLine(input)
        while (readLine(input).isNotEmpty()) { /* drain headers */ }
        return statusLine.split(' ', limit = 3).getOrNull(1)?.toIntOrNull() ?: 502
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

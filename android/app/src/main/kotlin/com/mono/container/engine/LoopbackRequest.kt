package com.mono.container.engine

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.SocketTimeoutException
import java.net.URI
import java.util.Base64

/**
 * Chromium's Autofill server-prediction host (`kDefaultAutofillServerURL`).
 * WebView queries it for every form, from the browser process, carrying the
 * profile's credential once the site has authenticated (findings, table
 * (B)). There can be only one proxy override per process, so the loopback
 * proxy refuses this host itself. It replaces `AutofillBlock.kt`.
 */
internal const val AUTOFILL_QUERY_HOST = "content-autofill.googleapis.com"

/** A request head larger than this is refused. Chromium's own are a few KB. */
internal const val MAX_HEAD_BYTES = 64 * 1024

/**
 * The lines of one HTTP head, up to its blank line, or null when the stream
 * ends first or the head passes [limit]. [input] is left at the first byte
 * after the head, so a body or tunnel payload can be read from it next. Bytes
 * are read as ISO-8859-1, so writing a line back reproduces it exactly.
 */
internal fun readHead(input: InputStream, limit: Int = MAX_HEAD_BYTES): List<String>? {
    val lines = mutableListOf<String>()
    val line = ByteArrayOutputStream()
    var total = 0
    while (true) {
        val byte = input.read()
        if (byte == -1 || ++total > limit) return null
        if (byte != '\n'.code) {
            line.write(byte)
            continue
        }
        val text = String(line.toByteArray(), Charsets.ISO_8859_1).removeSuffix("\r")
        line.reset()
        if (text.isNotEmpty()) lines += text
        else if (lines.isNotEmpty()) return lines
        // A blank line before the request line is ignored (RFC 9112 §2.2).
    }
}

/** One request to the loopback proxy. [path] is the origin-form path and query, or null for `CONNECT`. */
internal data class ProxyRequest(
    val method: String,
    val host: String,
    val port: Int,
    val path: String?,
    val version: String,
    val headers: List<Pair<String, String>>,
) {
    fun header(name: String): String? = headers.firstOrNull { it.first.equals(name, ignoreCase = true) }?.second
}

/**
 * Parses the two request shapes Chromium sends to an http proxy: `CONNECT
 * host:port` and an absolute-form `http://` request. Anything else is null.
 */
internal fun parseRequest(lines: List<String>): ProxyRequest? {
    val parts = lines.firstOrNull()?.split(' ') ?: return null
    if (parts.size != 3) return null
    val (method, target, version) = parts
    if (version != "HTTP/1.1" && version != "HTTP/1.0") return null
    val headers = lines.drop(1).map { line ->
        val colon = line.indexOf(':')
        if (colon <= 0) return null
        line.substring(0, colon).trim() to line.substring(colon + 1).trim()
    }
    if (method == "CONNECT") {
        val (host, port) = parseAuthority(target) ?: return null
        return ProxyRequest(method, host, port, null, version, headers)
    }
    val uri = runCatching { URI(target) }.getOrNull() ?: return null
    if (!uri.scheme.equals("http", ignoreCase = true)) return null
    val host = uri.host?.removeSurrounding("[", "]")?.ifEmpty { null } ?: return null
    val port = if (uri.port == -1) 80 else uri.port
    val path = (uri.rawPath?.ifEmpty { null } ?: "/") + (uri.rawQuery?.let { "?$it" } ?: "")
    return ProxyRequest(method, host, port, path, version, headers)
}

/** `host:port` or `[v6]:port`, with the port in 1..65535; otherwise null. */
internal fun parseAuthority(authority: String): Pair<String, Int>? {
    val host: String
    val portText: String
    if (authority.startsWith("[")) {
        val close = authority.indexOf(']')
        if (close < 0 || authority.getOrNull(close + 1) != ':') return null
        host = authority.substring(1, close)
        portText = authority.substring(close + 2)
    } else {
        val colon = authority.indexOf(':')
        if (colon <= 0 || authority.lastIndexOf(':') != colon) return null
        host = authority.substring(0, colon)
        portText = authority.substring(colon + 1)
    }
    if (host.isEmpty()) return null
    val port = portText.toIntOrNull()?.takeIf { it in 1..65535 } ?: return null
    return host to port
}

/** A `Proxy-Authorization: Basic` value's user and password, or null for anything else. */
internal fun basicCredentials(value: String): Pair<String, String>? {
    val parts = value.trim().split(Regex("\\s+"), limit = 2)
    if (parts.size != 2 || !parts[0].equals("Basic", ignoreCase = true)) return null
    val decoded = runCatching { String(Base64.getDecoder().decode(parts[1]), Charsets.UTF_8) }.getOrNull() ?: return null
    val colon = decoded.indexOf(':')
    if (colon < 0) return null
    return decoded.substring(0, colon) to decoded.substring(colon + 1)
}

/** What the loopback proxy does with one request. */
internal sealed class ProxyDecision {
    /** Answer [status] and close; nothing is forwarded. */
    data class Reply(val status: Int) : ProxyDecision()

    /** `200`, then relay bytes both ways to [host]:[port] on [binding]'s route. */
    class Tunnel(val host: String, val port: Int, val binding: ProxyBinding) : ProxyDecision()

    /** Send [head] and [bodyLength] body bytes to [host]:[port], relay the response, close. */
    class Forward(val host: String, val port: Int, val head: String, val bodyLength: Long, val binding: ProxyBinding) : ProxyDecision()
}

/**
 * P2 spec §1.1 and §2. The order matters:
 * 1. what the proxy never forwards, whatever the credentials — the Autofill
 *    host, and a destination named [LOOPBACK_HOST], which only the proxy
 *    itself may challenge as;
 * 2. no credentials: `407`, so the site's view answers with its own;
 * 3. credentials that find no open session: `403`, never a second `407`.
 */
internal fun decide(request: ProxyRequest?, lookup: (String, String) -> ProxyBinding?): ProxyDecision {
    if (request == null) return ProxyDecision.Reply(400)
    val host = request.host.trimEnd('.')
    if (host.equals(AUTOFILL_QUERY_HOST, ignoreCase = true) || host == LOOPBACK_HOST) return ProxyDecision.Reply(403)

    val authorization = request.header("Proxy-Authorization") ?: return ProxyDecision.Reply(407)
    val (user, password) = basicCredentials(authorization) ?: return ProxyDecision.Reply(403)
    val binding = lookup(user, password) ?: return ProxyDecision.Reply(403)
    // Built-in Tor spec §5.3: an onion name on a direct route is never looked
    // up nor sent anywhere, and does not start Tor.
    if (binding.config.proxyMode == "direct" && isOnionHost(host)) return ProxyDecision.Reply(403)

    if (request.path == null) return ProxyDecision.Tunnel(request.host, request.port, binding)

    if (request.header("Transfer-Encoding") != null) return ProxyDecision.Reply(411)
    val lengthHeader = request.header("Content-Length")
    val length = if (lengthHeader == null) 0L else lengthHeader.toLongOrNull()?.takeIf { it >= 0 } ?: return ProxyDecision.Reply(400)
    return ProxyDecision.Forward(request.host, request.port, originFormHead(request), length, binding)
}

/** Headers that belong to one hop, or to the loopback proxy alone. */
private val HOP_BY_HOP = setOf("proxy-authorization", "proxy-authenticate", "proxy-connection", "connection", "keep-alive")

/**
 * [request] as its origin server receives it: an origin-form request line,
 * none of [HOP_BY_HOP] — so the site's credential never leaves the device —
 * and `Connection: close`, so the connection carries this one request.
 */
internal fun originFormHead(request: ProxyRequest): String = buildString {
    append("${request.method} ${request.path} ${request.version}\r\n")
    for ((name, value) in request.headers) {
        if (name.lowercase() !in HOP_BY_HOP) append("$name: $value\r\n")
    }
    append("Connection: close\r\n\r\n")
}

/**
 * A relayed response head, with `Connection: close` in place of whatever
 * [HOP_BY_HOP] headers it had, so Chromium never reuses this connection for
 * another host. An origin's `Proxy-Authenticate` is dropped: only the proxy
 * challenges for the proxy.
 */
internal fun closingResponseHead(lines: List<String>): String = buildString {
    append(lines.first()).append("\r\n")
    for (line in lines.drop(1)) {
        if (line.substringBefore(':').trim().lowercase() !in HOP_BY_HOP) append(line).append("\r\n")
    }
    append("Connection: close\r\n\r\n")
}

/** The loopback proxy's own replies: empty, always closing, and only a `407` carries the challenge. */
internal fun statusResponse(status: Int): ByteArray {
    val reason = when (status) {
        400 -> "Bad Request"
        403 -> "Forbidden"
        407 -> "Proxy Authentication Required"
        411 -> "Length Required"
        502 -> "Bad Gateway"
        504 -> "Gateway Timeout"
        else -> "Error"
    }
    val challenge = if (status == 407) "Proxy-Authenticate: Basic realm=\"$PROXY_REALM\"\r\n" else ""
    return "HTTP/1.1 $status $reason\r\n${challenge}Content-Length: 0\r\nConnection: close\r\n\r\n"
        .toByteArray(Charsets.ISO_8859_1)
}

internal val CONNECTION_ESTABLISHED: ByteArray =
    "HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray(Charsets.ISO_8859_1)

/**
 * The status a failed upstream connection is answered with (spec §3.3): `504`
 * for a timeout (`UPSTREAM_TIMEOUT`), and `502` for everything else — an
 * upstream proxy refusing the destination (`PROXY_REFUSED`), a destination
 * that cannot be reached. Not reported to the site: the proxy cannot tell a
 * main frame from a subresource (plan deviation 1).
 */
internal fun upstreamFailureStatus(error: Throwable): Int = if (error is SocketTimeoutException) 504 else 502

/**
 * The failure a failed upstream connection reports to its site, or null.
 * Only a rejected login on a proxied route: it is the route's fault, not one
 * destination's, so every request on it would fail the same way (proxy-auth
 * spec §3). Every other failure stays unreported (plan deviation 1).
 */
internal fun reportedUpstreamFailure(error: Throwable, route: Route): RouteFailure? =
    if (error is ProxyLoginRejectedException && route is Route.Proxy) RouteFailure.PROXY_LOGIN_REJECTED else null

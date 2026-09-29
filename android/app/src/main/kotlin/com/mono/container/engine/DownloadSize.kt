package com.mono.container.engine

/**
 * The size a held download's sheet shows, or null when nothing honest is
 * known, in which case the sheet leaves the size out.
 *
 * WebView's `contentLength` cannot be passed through as it is. Chromium sets
 * it to `content_length > 0 ? content_length : 0`, so 0 means unknown rather
 * than empty. For a proxied site it is not the server's length at all: WebView
 * sizes a response [RequestInterceptor] supplied from `InputStream.available()`
 * on its body, which is however much of the socket happens to be buffered. So
 * a proxied site uses only the length the server declared ([declared]).
 */
internal fun heldDownloadSize(proxied: Boolean, listenerLength: Long, declared: Long?): Long? =
    if (proxied) declared else listenerLength.takeIf { it > 0 }

/**
 * The body length [headers] declare, or null when they declare none that
 * describes the bytes: `Transfer-Encoding` overrides `Content-Length` (RFC 9112
 * §6.3), and under a `Content-Encoding` it counts the encoded bytes.
 */
internal fun declaredLength(headers: Map<String, String>): Long? {
    fun header(name: String) =
        headers.entries.firstOrNull { it.key.equals(name, ignoreCase = true) }?.value?.trim()
    if (header("Transfer-Encoding") != null) return null
    val encoding = header("Content-Encoding")
    if (encoding != null && !encoding.equals("identity", ignoreCase = true)) return null
    return header("Content-Length")?.toLongOrNull()?.takeIf { it >= 0 }
}

/**
 * The [declaredLength] of each proxied response one view received, by URL,
 * until its `DownloadListener` asks. In memory only, and owned by the view, so
 * it goes when the view does. Bounded, because nearly every entry is a
 * subresource that never becomes a download.
 */
class DeclaredLengths(private val capacity: Int = 64) {
    private val byUrl = object : LinkedHashMap<String, Long>() {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Long>) = size > capacity
    }

    /** Called on WebView's IO threads. A response without a length clears any
     *  earlier one for the same URL. */
    @Synchronized fun record(url: String, headers: Map<String, String>) {
        val length = declaredLength(headers)
        if (length == null) byUrl.remove(url) else byUrl[url] = length
    }

    /** Called on the main thread, by the `DownloadListener`. */
    @Synchronized fun take(url: String): Long? = byUrl.remove(url)
}

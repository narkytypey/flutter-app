package com.mono.container.engine

/**
 * The size a held download's sheet shows, or null when nothing honest is
 * known, in which case the sheet leaves the size out.
 *
 * Chromium sets WebView's `contentLength` to `content_length > 0 ?
 * content_length : 0`, so 0 means unknown rather than empty. Since P2 Chromium
 * fetches every site's pages itself, proxied ones included (spec §1.4), so
 * this is the rule on every route.
 */
internal fun heldDownloadSize(listenerLength: Long): Long? = listenerLength.takeIf { it > 0 }

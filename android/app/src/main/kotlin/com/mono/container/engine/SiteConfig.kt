package com.mono.container.engine

/**
 * Mirrors the map [com.mono.container's Dart `ChannelContainerEngine.open`]
 * sends across the `com.mono.container/engine` method channel — one field
 * per key, same names. This is the only shape Kotlin knows about a site.
 */
data class SiteConfig(
    val siteId: String,
    val profileId: String,
    val url: String,
    val proxyMode: String,
    val proxyHost: String?,
    val proxyPort: Int?,
    val blockWebRtc: Boolean,
    val blockTrackers: Boolean,
    val antiFingerprinting: Boolean,
    val allowCamera: Boolean,
    val allowMicrophone: Boolean,
    val allowLocation: Boolean,
    val allowClipboard: Boolean,
    val userAgentMode: String,
    val forceDark: Boolean,
    val pageZoom: Int,
    val customCss: String,
    val customJs: String,
    val wipeOnExit: Boolean,
)

/** Wraps a string for safe embedding inside injected JavaScript. */
fun String.asJsString(): String {
    val escaped = this
        .replace("\\", "\\\\")
        .replace("'", "\\'")
        .replace("\n", "\\n")
        .replace("\r", "")
    return "'$escaped'"
}

fun userAgentFor(mode: String, context: android.content.Context): String = when (mode) {
    "desktop" -> "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    "minimal" -> "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
    else -> android.webkit.WebSettings.getDefaultUserAgent(context)
}

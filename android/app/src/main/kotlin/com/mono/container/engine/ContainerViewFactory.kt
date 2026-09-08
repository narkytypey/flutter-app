package com.mono.container.engine

import android.content.Context
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Builds the WebView behind spec `2b`'s page area.
 *
 * The creation params carry only a `siteId`: every other field was already
 * registered by `open`, and re-sending them here would let the view and the
 * session disagree about the same site. A view for a site that was never
 * opened is a programming error, not a state to render — it would have to
 * either invent a config or fall back to the default profile, and the second
 * is exactly what Global Constraints forbids.
 */
class ContainerViewFactory(
    private val engine: EngineChannel,
    private val profiles: ProfileManager,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val siteId = params?.get("siteId") as? String
            ?: error("A container view needs a siteId.")
        val session = engine.session(siteId)
            ?: error("open() must precede the container view for $siteId.")

        val view = ContainerView(
            context = context,
            config = session.config,
            profiles = profiles,
            interceptor = session.interceptor,
            session = session,
            onLive = { engine.markLive(siteId) },
            onAsk = { pending ->
                val requestId = engine.nextRequestId()
                val host = runCatching { java.net.URI(session.config.url).host }.getOrNull()
                    ?: session.config.url
                val kind = when (pending) {
                    is PendingPermission.Geolocation -> "location"
                    is PendingPermission.Hardware -> if (pending.toAsk.contains(
                            android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE)) "microphone" else "camera"
                }
                engine.onPermissionAskPublic(siteId, host, kind, requestId)
                requestId
            },
            onDownload = { url, mimeType, fileName, sizeBytes, kindLabel ->
                val requestId = engine.nextRequestId()
                engine.onDownload(siteId, requestId, url, mimeType, fileName, sizeBytes, kindLabel)
                requestId
            },
        )
        engine.attachView(siteId, view)
        return view
    }
}

package com.mono.container.engine

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * The page area's platform view (tabs spec §3.1). It shows one [Page] and
 * never destroys it: disposing the view only detaches and pauses the page,
 * which lives until its container closes (or the page itself is closed).
 */
class PageHost(context: Context, private val page: Page?) : PlatformView {
    private val frame = FrameLayout(context)

    init {
        page?.attach(frame, context)
    }

    override fun getView(): View = frame

    override fun dispose() {
        page?.detach(frame)
    }
}

/**
 * Builds spec `2b`'s page area. The creation params carry only a `pageId`,
 * which `open` or `page_opened` gave Dart; the view never looks a page up by
 * site (tabs spec §2), so it can never show a newer or older session's page
 * than the one Dart asked for. A missing `pageId` is a programming error. A
 * page id the engine no longer holds — closed while Dart was building its
 * view — gets an empty view: nothing loads, and no config is invented for it.
 */
class PageHostFactory(private val engine: EngineChannel) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val pageId = (args as? Map<*, *>)?.get("pageId") as? String
            ?: error("A page view needs a pageId.")
        return PageHost(context, engine.page(pageId))
    }
}

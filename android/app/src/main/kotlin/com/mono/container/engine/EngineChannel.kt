package com.mono.container.engine

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * One open container. It owns its own [FilterEngine] rather than sharing one,
 * because `2c` and the Today log report a blocked count *per site*; a single
 * shared counter could only ever report an app-wide total.
 */
class Session(val config: SiteConfig, rules: List<String>) {

    val filters = FilterEngine(rules)
    val interceptor = RequestInterceptor(filters)

    var phase: String = PHASE_OPENING
    var lastActiveAtMs: Long? = null
    var view: ContainerView? = null

    fun toMap(): Map<String, Any?> = mapOf(
        "siteId" to config.siteId,
        "phase" to phase,
        "lastActiveAt" to lastActiveAtMs,
        "blockedCount" to filters.blockedCount,
    )

    companion object {
        const val PHASE_OPENING = "opening"
        const val PHASE_LIVE = "live"
        const val PHASE_BACKGROUND = "background"
        const val PHASE_REFUSED = "refused"
    }
}

/**
 * Routes `com.mono.container/engine` and pushes the live session list to
 * `com.mono.container/sessions`.
 *
 * `liveSessions` and the event sink serialise through the same [Session.toMap],
 * so a snapshot and a subscription can never disagree about what is open.
 *
 * Every method here runs on the platform thread, which is where WebView work
 * must happen anyway.
 */
class EngineChannel(
    private val context: Context,
    private val profiles: ProfileManager,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val sessions = LinkedHashMap<String, Session>()
    private var sink: EventChannel.EventSink? = null

    /** Read once. The list ships in the APK; it is never fetched. */
    private val rules: List<String> by lazy {
        runCatching {
            context.assets.open("filters/default.txt").bufferedReader().readLines()
        }.getOrDefault(emptyList())
    }

    fun attach(messenger: BinaryMessenger) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(this)
    }

    // --- The seam the view factory reads -----------------------------------

    /** The config `open` registered, or null when no `open` preceded the view. */
    fun session(siteId: String): Session? = sessions[siteId]

    fun attachView(siteId: String, view: ContainerView) {
        sessions[siteId]?.view = view
    }

    /** Called by [ContainerView] when the first load finishes. */
    fun markLive(siteId: String) {
        val session = sessions[siteId] ?: return
        if (session.phase == Session.PHASE_REFUSED) return
        session.phase = Session.PHASE_LIVE
        session.lastActiveAtMs = System.currentTimeMillis()
        emit()
    }

    // --- Method channel ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isolationAvailable" -> result.success(profiles.isAvailable())
                "open" -> result.success(open(call))
                "close" -> {
                    close(call.argument<String>("siteId")!!)
                    result.success(null)
                }
                "reload" -> {
                    sessions[call.argument<String>("siteId")]?.view?.reload()
                    result.success(null)
                }
                "wipe" -> {
                    profiles.wipe(call.argument<String>("profileId")!!)
                    result.success(null)
                }
                "wipeAll" -> {
                    wipeAll()
                    result.success(null)
                }
                "liveSessions" -> result.success(sessions.values.map(Session::toMap))
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("engine", e.message, null)
        }
    }

    private fun open(call: MethodCall): Map<String, Any?> {
        val config = configFrom(call)
        val session = Session(config, rules)
        sessions[config.siteId] = session

        if (!profiles.isAvailable()) {
            // Global Constraints: refuse rather than share the default profile.
            session.phase = Session.PHASE_REFUSED
        } else {
            // Creates the profile now so the view can attach it before its
            // first load, and so a wipe has something to delete.
            profiles.profileFor(config.profileId)
            session.lastActiveAtMs = System.currentTimeMillis()
        }

        emit()
        return session.toMap()
    }

    private fun close(siteId: String) {
        val session = sessions.remove(siteId) ?: return
        // Flutter disposes the platform view when its AndroidView leaves the
        // tree, but `close` can also arrive from `2c` while the view is
        // detached — ContainerView.dispose is idempotent for that reason.
        session.view?.dispose()
        emit()
    }

    /**
     * Panic's first step. `deleteProfile` throws while a profile is attached to
     * a live WebView, so every session closes before the store is emptied.
     */
    private fun wipeAll() {
        for (siteId in sessions.keys.toList()) close(siteId)
        profiles.wipeAll()
    }

    private fun configFrom(call: MethodCall) = SiteConfig(
        siteId = call.argument<String>("siteId")!!,
        profileId = call.argument<String>("profileId")!!,
        url = call.argument<String>("url")!!,
        proxyMode = call.argument<String>("proxyMode")!!,
        proxyHost = call.argument<String>("proxyHost"),
        proxyPort = call.argument<Int>("proxyPort"),
        blockWebRtc = call.argument<Boolean>("blockWebRtc") ?: true,
        blockTrackers = call.argument<Boolean>("blockTrackers") ?: true,
        antiFingerprinting = call.argument<Boolean>("antiFingerprinting") ?: true,
        allowCamera = call.argument<Boolean>("allowCamera") ?: false,
        allowMicrophone = call.argument<Boolean>("allowMicrophone") ?: false,
        allowLocation = call.argument<Boolean>("allowLocation") ?: false,
        allowClipboard = call.argument<Boolean>("allowClipboard") ?: false,
        userAgentMode = call.argument<String>("userAgentMode") ?: "android",
        forceDark = call.argument<Boolean>("forceDark") ?: true,
        pageZoom = call.argument<Int>("pageZoom") ?: 100,
        customCss = call.argument<String>("customCss") ?: "",
        customJs = call.argument<String>("customJs") ?: "",
        wipeOnExit = call.argument<Boolean>("wipeOnExit") ?: false,
    )

    // --- Event channel -----------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        // A subscriber that arrives after the first container opened would
        // otherwise see nothing until the next change.
        emit()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun emit() {
        sink?.success(sessions.values.map(Session::toMap))
    }

    companion object {
        const val METHOD_CHANNEL = "com.mono.container/engine"
        const val EVENT_CHANNEL = "com.mono.container/sessions"
        const val VIEW_TYPE = "com.mono.container/view"
    }
}

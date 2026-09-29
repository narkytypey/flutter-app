package com.mono.container.engine

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger

/** Tracks fingerprinting and permission-ask blocks — the two categories
 * `FilterEngine` never sees, because they never touch the network layer. */
class SideCounters {
    val fingerprinting = AtomicInteger(0)
    val permissionAsks = AtomicInteger(0)
}

sealed class PendingPermission {
    abstract val requestId: String
    /**
     * [toAsk] is what the live ask is actually about — the resources with no
     * stored `allow*` flag and no existing session grant. [granted] is the
     * disjoint subset already pre-authorized (stored flag, or an earlier
     * "allow while open" this session) that rode along in the same
     * `onPermissionRequest` callback. Keeping them separate is what lets
     * [EngineChannel.resolvePermission] answer "keep blocked" for [toAsk]
     * without silently revoking [granted] — see issue found in Task 3
     * review: passing the *combined* resource list into a single field made
     * `keepBlocked` deny resources the stored config had already granted.
     */
    data class Hardware(
        override val requestId: String,
        val request: android.webkit.PermissionRequest,
        val toAsk: List<String>,
        val granted: List<String> = emptyList(),
    ) : PendingPermission()
    data class Geolocation(
        override val requestId: String,
        val origin: String,
        val callback: android.webkit.GeolocationPermissions.Callback,
    ) : PendingPermission()
}

data class PendingDownload(
    val url: String,
    val mimeType: String,
    val fileName: String,
    val sizeBytes: Long?,
    val kindLabel: String,
)

/**
 * One open container. It owns its own [FilterEngine] rather than sharing one,
 * because `2c` and the Today log report a blocked count *per site*. Its
 * rules are the open vault's enabled lists, sent by Dart with each open.
 */
class Session(val config: SiteConfig) {

    val filters = FilterEngine(config.filterRules)
    val counters = SideCounters()
    val interceptor = RequestInterceptor(filters) { onTunnelDropped?.invoke(it) }
    val pendingPermissions = LinkedHashMap<String, PendingPermission>()
    val pendingDownloads = LinkedHashMap<String, PendingDownload>()

    /** Kinds granted for the rest of this session by an "allow while open"
     * decision. Cleared implicitly when the session closes with the object. */
    val sessionGrants = mutableSetOf<String>()

    var phase: String = PHASE_OPENING
    var lastActiveAtMs: Long? = null
    var failure: String? = null
    var view: ContainerView? = null

    /** Set by [EngineChannel] after construction; lets a live session's
     * dropped tunnel reach the event sink without `Session` holding a
     * reference to the channel itself. */
    var onTunnelDropped: ((RouteFailure) -> Unit)? = null

    fun toMap(): Map<String, Any?> = mapOf(
        "siteId" to config.siteId,
        "phase" to phase,
        "lastActiveAt" to lastActiveAtMs,
        "blockedCount" to filters.blockedCount + counters.fingerprinting.get() + counters.permissionAsks.get(),
        "categoryCounts" to mapOf(
            "trackers" to filters.countFor("trackers"),
            "ads" to filters.countFor("ads"),
            "fingerprinting" to counters.fingerprinting.get(),
            "permissionAsks" to counters.permissionAsks.get(),
        ),
        "failure" to failure,
    )

    companion object {
        const val PHASE_OPENING = "opening"
        const val PHASE_LIVE = "live"
        const val PHASE_BACKGROUND = "background"
        const val PHASE_REFUSED = "refused"
    }
}

/**
 * One ticket per `open` whose route is still being decided off the main
 * thread. `close` and panic's `wipeAll` revoke tickets, and an open whose
 * ticket was revoked must not register: it would bring back a session nobody
 * holds, and after panic its `profileFor` would recreate a profile panic had
 * just deleted. Main-thread only, like the session map it guards.
 */
class PendingOpens {
    private val tickets = HashMap<String, Any>()

    /** A newer open of the same site supersedes any older one still in flight. */
    fun begin(siteId: String): Any = Any().also { tickets[siteId] = it }

    fun cancel(siteId: String) {
        tickets.remove(siteId)
    }

    fun cancelAll() = tickets.clear()

    /** True, once, if [ticket] is still the current open for [siteId]. */
    fun finish(siteId: String, ticket: Any): Boolean {
        if (tickets[siteId] !== ticket) return false
        tickets.remove(siteId)
        return true
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
    private val pendingOpens = PendingOpens()
    private var sink: EventChannel.EventSink? = null
    private var requestCounter = 0
    /** Blocking network work: route probes and download fetches. Never the main thread. */
    private val networkExecutor = java.util.concurrent.Executors.newCachedThreadPool()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val downloadFetcher = DownloadFetcher(context, profiles)

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
        emitSessions()
    }

    /** Called by [RequestInterceptor] when a *live* session's fetch starts
     * refusing mid-browse — spec §3's `tunnel_dropped`, distinct from an
     * initial-connect [Session.PHASE_REFUSED]. */
    private fun onTunnelDropped(siteId: String, failure: RouteFailure) {
        val session = sessions[siteId] ?: return
        if (session.phase != Session.PHASE_LIVE) return
        sink?.success(mapOf(
            "type" to "tunnel_dropped",
            "siteId" to siteId,
            "host" to (runCatching { java.net.URI(session.config.url).host }.getOrNull() ?: session.config.url),
            "droppedAtMs" to System.currentTimeMillis(),
        ))
    }

    /** Called by [ContainerViewFactory]'s `onAsk` callback when a hardware
     * permission the site's stored config does not already grant is
     * requested live. */
    fun onPermissionAskPublic(siteId: String, host: String, kind: String, requestId: String) {
        sessions[siteId]?.counters?.permissionAsks?.incrementAndGet()
        sink?.success(mapOf(
            "type" to "permission_request",
            "siteId" to siteId, "host" to host, "kind" to kind, "requestId" to requestId,
        ))
    }

    /** Called by [ContainerView]'s `DownloadListener`. */
    fun onDownload(siteId: String, requestId: String, url: String, mimeType: String, fileName: String, sizeBytes: Long?, kindLabel: String) {
        val session = sessions[siteId] ?: return
        session.pendingDownloads[requestId] = PendingDownload(url, mimeType, fileName, sizeBytes, kindLabel)
        val host = runCatching { java.net.URI(session.config.url).host }.getOrNull()
            ?: session.config.url
        sink?.success(mapOf(
            "type" to "download",
            "siteId" to siteId, "fileName" to fileName, "sizeBytes" to sizeBytes,
            "sourceHost" to host, "kindLabel" to kindLabel, "requestId" to requestId,
        ))
    }

    // --- Method channel ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isolationAvailable" -> result.success(profiles.isAvailable())
                "open" -> open(call, result)
                "close" -> {
                    close(call.argument<String>("siteId")!!)
                    result.success(null)
                }
                "reload" -> {
                    sessions[call.argument<String>("siteId")]?.view?.reload()
                    result.success(null)
                }
                "wipe" -> {
                    val profileId = call.argument<String>("profileId")!!
                    deleteDownloadsDir(context, profileId)
                    profiles.wipe(profileId)
                    result.success(null)
                }
                "wipeAll" -> {
                    wipeAll()
                    result.success(null)
                }
                "liveSessions" -> result.success(sessions.values.map(Session::toMap))
                "resolvePermission" -> {
                    resolvePermission(call.argument<String>("requestId")!!, call.argument<String>("decision")!!)
                    result.success(null)
                }
                "resolveDownload" -> {
                    resolveDownload(call.argument<String>("requestId")!!, call.argument<String>("decision")!!)
                    result.success(null)
                }
                "extractArticle" -> extractArticle(call.argument<String>("siteId")!!, result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("engine", e.message, null)
        }
    }

    /**
     * Decides the route off the main thread, then registers the session back
     * on it.
     *
     * The split is load-bearing. `currentRoute()` probes a proxy with a
     * blocking connect, and Android throws `NetworkOnMainThreadException` for
     * any socket opened on this thread — which [ProxyProbe]'s `runCatching`
     * reads as "unreachable". Deciding the route here therefore refused every
     * proxied site on a device, with copy claiming nothing was listening,
     * while the JVM unit tests (which have no such rule) all passed. The
     * session map and `ProfileStore` are main-thread state, so everything
     * except the probe stays here.
     *
     * An open that [close] or [wipeAll] overtook while its probe ran is
     * answered without being registered — see [PendingOpens].
     */
    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val config = configFrom(call)
        if (!profiles.isAvailable()) {
            result.success(register(config, route = null))
            return
        }
        val ticket = pendingOpens.begin(config.siteId)
        networkExecutor.execute {
            val route = runCatching { config.currentRoute() }
            mainHandler.post {
                if (!pendingOpens.finish(config.siteId, ticket)) {
                    result.success(Session(config).toMap())
                    return@post
                }
                // Off onMethodCall's try/catch now, so a throw here would
                // crash the main thread rather than reach Dart as an error.
                route.mapCatching { register(config, it) }.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("engine", it.message, null) },
                )
            }
        }
    }

    /** [route] is null only when isolation itself is unavailable. */
    private fun register(config: SiteConfig, route: Route?): Map<String, Any?> {
        val session = Session(config)
        session.onTunnelDropped = { failure -> onTunnelDropped(config.siteId, failure) }
        sessions[config.siteId] = session

        when (route) {
            null -> {
                // Global Constraints: refuse rather than share the default profile.
                session.phase = Session.PHASE_REFUSED
                session.failure = null // no route was even attempted; isolation itself is unavailable
            }
            is Route.Refused -> {
                session.phase = Session.PHASE_REFUSED
                session.failure = route.failure.name.let(::routeFailureToDartName)
            }
            else -> {
                // Creates the profile now so the view can attach it before its
                // first load, and so a wipe has something to delete.
                profiles.profileFor(config.profileId)
                session.lastActiveAtMs = System.currentTimeMillis()
            }
        }

        emitSessions()
        return session.toMap()
    }

    private fun resolvePermission(requestId: String, decisionName: String) {
        for (session in sessions.values) {
            val pending = session.pendingPermissions.remove(requestId) ?: continue
            when (pending) {
                is PendingPermission.Hardware -> when (decisionName) {
                    "keepBlocked" -> {
                        // Only the resources this ask was actually about are
                        // refused — a resource already pre-authorized by the
                        // stored config (`granted`) is honored regardless of
                        // this decision, per "a stored allow* flag pre-grants
                        // silently."
                        if (pending.granted.isNotEmpty()) {
                            pending.request.grant(pending.granted.toTypedArray())
                        } else {
                            pending.request.deny()
                        }
                    }
                    else -> {
                        if (decisionName == "allowWhileOpen") {
                            session.sessionGrants.addAll(pending.toAsk)
                        }
                        pending.request.grant((pending.granted + pending.toAsk).toTypedArray())
                    }
                }
                is PendingPermission.Geolocation -> when (decisionName) {
                    "keepBlocked" -> pending.callback.invoke(pending.origin, false, false)
                    else -> {
                        if (decisionName == "allowWhileOpen") session.sessionGrants.add("geolocation")
                        pending.callback.invoke(pending.origin, true, false)
                    }
                }
            }
            return
        }
        // The request already timed out or its site closed — a silent no-op,
        // per this plan's Known Gaps on backgrounded events.
    }

    private fun resolveDownload(requestId: String, decisionName: String) {
        for (session in sessions.values) {
            val pending = session.pendingDownloads.remove(requestId) ?: continue
            if (decisionName == "discard") return
            // Built here, on the platform thread, because it reads the site's
            // profile through androidx.webkit's UI-thread-only ProfileStore.
            // Only the network and disk work below goes to the executor.
            val request = runCatching { downloadFetcher.requestFor(session.config, pending) }
                .getOrElse {
                    emitDownloadResult(requestId, DownloadOutcome.Failed(null))
                    return
                }
            networkExecutor.execute {
                val outcome = downloadFetcher.run(session.config, pending, request, decisionName)
                mainHandler.post { emitDownloadResult(requestId, outcome) }
            }
            return
        }
    }

    private fun emitDownloadResult(requestId: String, outcome: DownloadOutcome) {
        val (name, reason) = when (outcome) {
            is DownloadOutcome.Saved -> "saved" to null
            is DownloadOutcome.Kept -> "kept" to null
            is DownloadOutcome.Failed -> "failed" to outcome.reason?.name?.let(::routeFailureToDartName)
        }
        sink?.success(mapOf("type" to "download_result", "requestId" to requestId, "outcome" to name, "reason" to reason))
    }

    private fun extractArticle(siteId: String, result: MethodChannel.Result) {
        val view = sessions[siteId]?.view
        if (view == null) {
            result.success(null)
            return
        }
        view.extractArticle { article -> result.success(article) }
    }

    private fun close(siteId: String) {
        pendingOpens.cancel(siteId)
        val session = sessions.remove(siteId) ?: return
        // Flutter disposes the platform view when its AndroidView leaves the
        // tree, but `close` can also arrive from `2c` while the view is
        // detached — ContainerView.dispose is idempotent for that reason.
        session.view?.dispose()
        emitSessions()
    }

    /**
     * Panic's first step. `deleteProfile` throws while a profile is attached to
     * a live WebView, so every session closes before the store is emptied.
     */
    private fun wipeAll() {
        pendingOpens.cancelAll()
        for (siteId in sessions.keys.toList()) close(siteId)
        java.io.File(context.filesDir, "downloads").deleteRecursively()
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
        filterRules = call.argument<Map<String, List<String>>>("filterRules") ?: emptyMap(),
        userScripts = injectedScriptsFrom(call.argument<List<Map<String, Any?>>>("userScripts")),
    )

    fun nextRequestId(): String = "req-${++requestCounter}"

    // --- Event channel -----------------------------------------------------

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        // A subscriber that arrives after the first container opened would
        // otherwise see nothing until the next change.
        emitSessions()
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun emitSessions() {
        sink?.success(mapOf("type" to "sessions", "sessions" to sessions.values.map(Session::toMap)))
    }

    companion object {
        const val METHOD_CHANNEL = "com.mono.container/engine"
        const val EVENT_CHANNEL = "com.mono.container/sessions"
        const val VIEW_TYPE = "com.mono.container/view"
    }
}

/** Dart's `RouteFailure` enum is lowerCamelCase; Kotlin's is SCREAMING_SNAKE. */
fun routeFailureToDartName(kotlinName: String): String = when (kotlinName) {
    "PROXY_UNREACHABLE" -> "proxyUnreachable"
    "PROXY_REFUSED" -> "proxyRefused"
    "UPSTREAM_TIMEOUT" -> "upstreamTimeout"
    "TLS_FAILURE" -> "tlsFailure"
    else -> "misconfigured"
}

/**
 * Reader-mode heuristic: strips obvious chrome, then picks the element with
 * the highest text-to-tag-node-count ratio as the likely article body. This
 * is the plan's one honestly-approximate piece — see Known Gaps.
 */
const val READER_JS = """
(function(){
  document.querySelectorAll('script,style,nav,aside,footer').forEach(e=>e.remove());
  var candidates = document.body.querySelectorAll('article,main,div,section');
  var best = null, bestScore = 0;
  candidates.forEach(function(el){
    var text = el.innerText || '';
    var tags = el.querySelectorAll('*').length || 1;
    var score = text.length / tags;
    if (text.length > 200 && score > bestScore) { bestScore = score; best = el; }
  });
  if (!best) return null;
  var paragraphs = [];
  best.querySelectorAll('p,h1,h2,h3,li').forEach(function(el){
    var t = (el.innerText || '').trim();
    if (t.length > 20) paragraphs.push(t);
  });
  if (paragraphs.length === 0) return null;
  var words = paragraphs.join(' ').split(/\s+/).length;
  return JSON.stringify({
    host: location.host,
    title: document.title,
    paragraphs: paragraphs,
    minutesToRead: Math.max(1, Math.round(words / 200)),
  });
})();
"""

fun parseReaderJson(json: String): Map<String, Any?>? = runCatching {
    // evaluateJavascript double-encodes the string result; strip one layer.
    val unescaped = org.json.JSONTokener(json).nextValue() as String
    val obj = org.json.JSONObject(unescaped)
    val paragraphs = obj.getJSONArray("paragraphs")
    mapOf(
        "host" to obj.getString("host"),
        "title" to obj.getString("title"),
        "paragraphs" to (0 until paragraphs.length()).map { paragraphs.getString(it) },
        "minutesToRead" to obj.getInt("minutesToRead"),
    )
}.getOrNull()

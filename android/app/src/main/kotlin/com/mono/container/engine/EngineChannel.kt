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
class Session(
    val config: SiteConfig,
    /** The address typed to open it, for the view's first load only: [config]
     * keeps the stored one, which scopes scripts and names the site. */
    val initialUrl: String? = null,
) {

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

    /** Opening order (tabs spec §3.1). A closing page has already left, so
     *  this counts live pages only. */
    val pages = LinkedHashMap<String, Page>()

    /** Which page asked each pending permission or held download, by request id. */
    val pageOf = HashMap<String, String>()

    /** Starts as the config's; `keep` turns it off for a throwaway saved as a
     *  site while its page is still open (spec §5.3). A `close` without its
     *  own `wipe` reads this, not the config. */
    var wipeOnExit: Boolean = config.wipeOnExit

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
        "pages" to pagesToEvent(pages.values.map { it.id to it.openerId }),
        "grants" to SessionGrants.kindsOf(sessionGrants),
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

/** "Keep blocked": only the resources this ask was about are refused — a
 *  resource already pre-authorized by the stored config (`granted`) is honored
 *  regardless, per "a stored allow* flag pre-grants silently." */
internal fun answerKeepBlocked(pending: PendingPermission) = when (pending) {
    is PendingPermission.Hardware ->
        if (pending.granted.isNotEmpty()) pending.request.grant(pending.granted.toTypedArray())
        else pending.request.deny()
    is PendingPermission.Geolocation -> pending.callback.invoke(pending.origin, false, false)
}

/** What a route refusal reported by the loopback proxy does to the session it reached. */
internal enum class RefusalAction { REFUSE_SESSION, TUNNEL_DROPPED, IGNORE }

/**
 * Proxy-auth spec §3, ruling 6. A session still opening is refused, so `8b`
 * names the failure instead of the first load ending on WebView's own error
 * page. A live one hears `tunnel_dropped` (`8c`), as before. A backgrounded or
 * refused one ignores it, as before.
 */
internal fun refusalActionFor(phase: String): RefusalAction = when (phase) {
    Session.PHASE_OPENING -> RefusalAction.REFUSE_SESSION
    Session.PHASE_LIVE -> RefusalAction.TUNNEL_DROPPED
    else -> RefusalAction.IGNORE
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
    /** Throwaways whose profile may still be on disk; see [ThrowawayJournal]. */
    val throwaways: ThrowawayJournal,
    /** Which credential routes which open site through the loopback proxy (P2 spec §2). */
    val credentials: SiteCredentials,
    /** Whether WebView's traffic goes through the loopback proxy at all (P2 spec §1.3). */
    private val proxyOverride: Boolean,
    /** Blocks until WebView has applied that override; see [routeAtOpen]. */
    private val awaitOverride: () -> Unit,
    /** Shows Android's runtime permission dialog; [onAndroidPermissionsResult] follows. */
    launchPermissionDialog: (Array<String>) -> Unit,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, PageEvents {

    private val sessions = LinkedHashMap<String, Session>()
    private val pendingOpens = PendingOpens()
    private var sink: EventChannel.EventSink? = null
    private var requestCounter = 0
    /** Blocking network work: route probes and download fetches. Never the main thread. */
    private val networkExecutor = java.util.concurrent.Executors.newCachedThreadPool()
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private val downloadFetcher = DownloadFetcher(context, profiles)
    private val permissionAsks = PermissionAsks(::holds, launchPermissionDialog)

    private fun holds(permission: String) =
        context.checkSelfPermission(permission) == android.content.pm.PackageManager.PERMISSION_GRANTED

    /** Android's permission dialog was answered. */
    fun onAndroidPermissionsResult() = permissionAsks.onResult()

    /**
     * Grants [resources] to [request] once Android's permissions for them have
     * been asked: the page gets only what the app may use, and a refusal
     * everywhere is a deny. [then] hears what was granted.
     */
    private fun grantCapture(
        request: android.webkit.PermissionRequest,
        resources: List<String>,
        then: (granted: List<String>) -> Unit = {},
    ) {
        permissionAsks.ask(androidPermissionsFor(resources)) {
            val grantable = grantableResources(resources, ::holds)
            if (grantable.isEmpty()) request.deny() else request.grant(grantable.toTypedArray())
            then(grantable)
        }
    }

    override fun grantHardware(request: android.webkit.PermissionRequest, resources: List<String>) =
        grantCapture(request, resources)

    private var methods: MethodChannel? = null
    private var events: EventChannel? = null

    fun attach(messenger: BinaryMessenger) {
        methods = MethodChannel(messenger, METHOD_CHANNEL).also { it.setMethodCallHandler(this) }
        events = EventChannel(messenger, EVENT_CHANNEL).also { it.setStreamHandler(this) }
    }

    /**
     * The Flutter engine this channel serves is going away (the Activity
     * finished: back on the dashboard). A page owns its WebView apart from
     * any platform view (tabs spec §3), so nothing else would close it: the
     * pages would live on in the process, holding their profiles, under a
     * new engine whose Dart side starts at a cold lock with nothing open.
     * Every container is closed as at a lock, a throwaway or wipe-on-exit
     * site wiped after its Teardown. Nothing is reported: no one listens.
     */
    fun detach() {
        sink = null
        methods?.setMethodCallHandler(null)
        events?.setStreamHandler(null)
        methods = null
        events = null
        permissionAsks.cancelAll()
        closeAll()
    }

    // --- Pages -------------------------------------------------------------

    /** The page with [pageId], in whichever session holds it; null once it
     *  has started closing. [PageHostFactory] binds a view to exactly this. */
    fun page(pageId: String): Page? {
        for (session in sessions.values) session.pages[pageId]?.let { return it }
        return null
    }

    /** The registered session [page] belongs to, or null once the page (or
     *  its session) has started closing: a closing page speaks for no one. */
    private fun sessionOf(page: Page): Session? =
        sessions.values.firstOrNull { it.pages[page.id] === page }

    private fun newPage(session: Session, openerId: String?, firstUrl: String?): Page {
        val page = Page(newPageId(), openerId, context, session.config, session, profiles, credentials, firstUrl, this)
        session.pages[page.id] = page
        return page
    }

    /** Called on every finished main-frame load. */
    fun markLive(siteId: String) {
        val session = sessions[siteId] ?: return
        if (session.phase == Session.PHASE_REFUSED) return
        session.phase = Session.PHASE_LIVE
        session.lastActiveAtMs = System.currentTimeMillis()
        emitSessions()
    }

    override fun loaded(page: Page) {
        val session = sessionOf(page) ?: return
        markLive(session.config.siteId)
    }

    /**
     * A hardware or location permission the site's stored config does not
     * already grant, asked live. A page that is closing has no one to ask:
     * it is answered "keep blocked" at once.
     */
    override fun ask(page: Page, pending: PendingPermission): String {
        val requestId = nextRequestId()
        val session = sessionOf(page) ?: return requestId.also { answerKeepBlocked(pending) }
        session.pageOf[requestId] = page.id
        session.counters.permissionAsks.incrementAndGet()
        val kind = when (pending) {
            is PendingPermission.Geolocation -> "location"
            is PendingPermission.Hardware -> if (pending.toAsk.contains(
                    android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE)) "microphone" else "camera"
        }
        sink?.success(mapOf(
            "type" to "permission_request",
            "siteId" to session.config.siteId, "pageId" to page.id,
            "host" to hostOf(session.config), "kind" to kind, "requestId" to requestId,
        ))
        return requestId
    }

    override fun download(
        page: Page, url: String, mimeType: String, fileName: String, sizeBytes: Long?, kindLabel: String,
    ): String {
        val requestId = nextRequestId()
        val session = sessionOf(page) ?: return requestId
        session.pendingDownloads[requestId] = PendingDownload(url, mimeType, fileName, sizeBytes, kindLabel)
        session.pageOf[requestId] = page.id
        sink?.success(mapOf(
            "type" to "download",
            "siteId" to session.config.siteId, "pageId" to page.id,
            "fileName" to fileName, "sizeBytes" to sizeBytes,
            "sourceHost" to hostOf(session.config), "kindLabel" to kindLabel, "requestId" to requestId,
        ))
        return requestId
    }

    /** Only a registered page reaches Dart: a reopened site's older pages,
     *  still tearing down, must not speak for the newer session. */
    override fun navigated(page: Page, snapshot: NavigationSnapshot) {
        val session = sessionOf(page) ?: return
        sink?.success(snapshot.toEvent(session.config.siteId, page.id))
    }

    override fun found(page: Page, activeMatch: Int, matchCount: Int) {
        val session = sessionOf(page) ?: return
        sink?.success(findResultEvent(session.config.siteId, page.id, activeMatch, matchCount))
    }

    /**
     * Tabs spec §5.2. Without a user gesture nothing opens. At the cap the
     * link loads in the page it was tapped in. Otherwise a new page in the
     * same session — same profile, route and credential — takes the
     * transport, with its profile set before the transport hands it the
     * first navigation (the [Page] constructor does that).
     */
    override fun newWindow(page: Page, isUserGesture: Boolean, resultMsg: android.os.Message): Boolean {
        val session = sessionOf(page) ?: return false
        val transport = resultMsg.obj as? android.webkit.WebView.WebViewTransport ?: return false
        return when (newWindowAction(isUserGesture, session.pages.size)) {
            NewWindowAction.REFUSE -> false
            NewWindowAction.LOAD_IN_PLACE -> {
                capture(session.config, transport, resultMsg) { url ->
                    // The opener may have closed while the capture ran.
                    inPlaceUrl(url)?.let { target -> if (sessionOf(page) != null) page.load(target) }
                }
                true
            }
            NewWindowAction.NEW_PAGE -> {
                val opened = newPage(session, page.id, firstUrl = null)
                transport.webView = opened.webView
                resultMsg.sendToTarget()
                sink?.success(pageOpenedEvent(session.config.siteId, opened.id, page.id))
                emitSessions()
                true
            }
        }
    }

    /** A page's own `window.close()`. Posted, so the page is not torn down
     *  from inside its own chrome client's callback. */
    override fun closeRequested(page: Page) {
        mainHandler.post { closePage(page.id) }
    }

    /**
     * Tabs spec §5.2: a capped link's URL, read without fetching anything. A
     * short-lived WebView on the same profile takes the new window; it refuses
     * every request, records the first URL it is asked to load, cancels that
     * load, and is destroyed. [onUrl] runs at most once; a window that names
     * no URL within [Teardown.TIMEOUT_MS] is dropped.
     */
    private fun capture(
        config: SiteConfig,
        transport: android.webkit.WebView.WebViewTransport,
        resultMsg: android.os.Message,
        onUrl: (String?) -> Unit,
    ) {
        val capture = android.webkit.WebView(android.content.MutableContextWrapper(context))
        // Never consulted for a load this view cancels, but never asked to
        // ping Google either (see Page's settings).
        capture.settings.setSafeBrowsingEnabled(false)
        androidx.webkit.WebViewCompat.setProfile(capture, config.profileId)
        var done = false
        fun finish(url: String?) {
            if (done) return
            done = true
            mainHandler.post {
                capture.stopLoading()
                capture.destroy()
                onUrl(url)
            }
        }
        capture.webViewClient = object : android.webkit.WebViewClient() {
            override fun shouldInterceptRequest(
                view: android.webkit.WebView, request: android.webkit.WebResourceRequest,
            ): android.webkit.WebResourceResponse? = RequestInterceptor.refuseAll(request)

            override fun shouldOverrideUrlLoading(
                view: android.webkit.WebView, request: android.webkit.WebResourceRequest,
            ): Boolean {
                finish(request.url.toString())
                return true
            }

            override fun onPageStarted(view: android.webkit.WebView, url: String?, favicon: android.graphics.Bitmap?) {
                view.stopLoading()
                finish(url)
            }
        }
        transport.webView = capture
        resultMsg.sendToTarget()
        mainHandler.postDelayed({ finish(null) }, Teardown.TIMEOUT_MS)
    }

    private fun hostOf(config: SiteConfig): String =
        runCatching { java.net.URI(config.url).host }.getOrNull() ?: config.url

    /** Called by [RequestInterceptor] when a *live* session's fetch starts
     * refusing mid-browse — spec §3's `tunnel_dropped`, distinct from an
     * initial-connect [Session.PHASE_REFUSED]. */
    /**
     * Called on the main thread for a refusal the loopback proxy reported on
     * [session]'s binding. A session replaced since, or closed, hears nothing.
     * Refusing an opening session also unbinds it, as a route refused at open
     * never binds: from then on the proxy answers its requests `403`.
     */
    private fun onRouteRefused(session: Session, failure: RouteFailure) {
        val siteId = session.config.siteId
        if (sessions[siteId] !== session) return
        when (refusalActionFor(session.phase)) {
            RefusalAction.REFUSE_SESSION -> {
                session.phase = Session.PHASE_REFUSED
                session.failure = routeFailureToDartName(failure.name)
                credentials.unbind(session.config.profileId)
                emitSessions()
            }
            RefusalAction.TUNNEL_DROPPED -> onTunnelDropped(siteId, failure)
            RefusalAction.IGNORE -> Unit
        }
    }

    private fun onTunnelDropped(siteId: String, failure: RouteFailure) {
        val session = sessions[siteId] ?: return
        if (session.phase != Session.PHASE_LIVE) return
        sink?.success(mapOf(
            "type" to "tunnel_dropped",
            "siteId" to siteId,
            "host" to hostOf(session.config),
            "droppedAtMs" to System.currentTimeMillis(),
        ))
    }

    /** The page the call's `pageId` names. Every in-page control is a silent
     *  no-op on a closed or unknown page, like `reload`. */
    private fun pageFor(call: MethodCall): Page? = call.argument<String>("pageId")?.let(::page)

    // --- Method channel ----------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isolationAvailable" -> result.success(profiles.isAvailable())
                "open" -> open(call, result)
                "close" -> {
                    close(call.argument<String>("siteId")!!, wipe = call.argument<Boolean>("wipe"))
                    result.success(null)
                }
                "closePage" -> {
                    closePage(call.argument<String>("pageId")!!)
                    result.success(null)
                }
                "closeAll" -> {
                    closeAll()
                    result.success(null)
                }
                "reload" -> {
                    pageFor(call)?.reload()
                    result.success(null)
                }
                "goBack" -> {
                    pageFor(call)?.goBack()
                    result.success(null)
                }
                "goForward" -> {
                    pageFor(call)?.goForward()
                    result.success(null)
                }
                "stop" -> {
                    pageFor(call)?.stop()
                    result.success(null)
                }
                "loadUrl" -> {
                    // Page.load refuses every scheme but http(s).
                    pageFor(call)?.load(call.argument<String>("url")!!)
                    result.success(null)
                }
                "find" -> {
                    pageFor(call)?.find(call.argument<String>("query")!!)
                    result.success(null)
                }
                "findNext" -> {
                    pageFor(call)?.findNext(call.argument<Boolean>("forward") ?: true)
                    result.success(null)
                }
                "clearFind" -> {
                    pageFor(call)?.clearFind()
                    result.success(null)
                }
                "navigationState" -> {
                    val page = pageFor(call)
                    val session = page?.let(::sessionOf)
                    result.success(if (page == null || session == null) null
                        else page.snapshot?.toEvent(session.config.siteId, page.id))
                }
                "wipe" -> {
                    wipeProfile(call.argument<String>("profileId")!!)
                    result.success(null)
                }
                "wipeAll" -> {
                    wipeAll()
                    result.success(null)
                }
                "keep" -> {
                    keep(call.argument<String>("siteId")!!)
                    result.success(null)
                }
                "revokeGrant" -> {
                    revokeGrant(call.argument<String>("siteId")!!, call.argument<String>("kind")!!)
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
                "extractArticle" -> extractArticle(pageFor(call), result)
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
        val throwaway = call.argument<Boolean>("throwaway") ?: false
        val initialUrl = call.argument<String>("initialUrl")
        // A throwaway always wipes on exit, whatever else the call says.
        val config = configFrom(call).let { if (throwaway) it.copy(wipeOnExit = true) else it }
        // Listed before its profile can exist (register() creates it), so a
        // crash from here on still leaves it for the next start's sweep.
        if (throwaway) throwaways.add(config.profileId)
        if (!profiles.isAvailable()) {
            result.success(register(config, route = null, initialUrl = initialUrl))
            return
        }
        val ticket = pendingOpens.begin(config.siteId)
        networkExecutor.execute {
            val route = runCatching { routeAtOpen(config, proxyOverride, awaitOverride) { config.currentRoute() } }
            mainHandler.post {
                if (!pendingOpens.finish(config.siteId, ticket)) {
                    result.success(Session(config).toMap())
                    return@post
                }
                // Off onMethodCall's try/catch now, so a throw here would
                // crash the main thread rather than reach Dart as an error.
                route.mapCatching { register(config, it, initialUrl) }.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { result.error("engine", it.message, null) },
                )
            }
        }
    }

    /**
     * [route] is null only when isolation itself is unavailable. A route that
     * binds also gets the container's first page, loading
     * [firstLoadUrl]; the returned map lists it, and that page id is the only
     * thing a view for this open may bind to.
     *
     * A site that still has a session (`8b`'s reopen, a route change) has that
     * session's pages torn down first, without a wipe (Plan 15 deviation 4):
     * pages no longer die with their view, so nothing else would end them.
     */
    private fun register(config: SiteConfig, route: Route?, initialUrl: String?): Map<String, Any?> {
        val session = Session(config, initialUrl)
        session.onTunnelDropped = { failure -> onTunnelDropped(config.siteId, failure) }
        val previous = sessions.remove(config.siteId)
        previous?.let { closePages(it, wipe = false) }
        sessions[config.siteId] = session

        val binding = when (route) {
            null -> {
                // Global Constraints: refuse rather than share the default profile.
                session.phase = Session.PHASE_REFUSED
                session.failure = null // no route was even attempted; isolation itself is unavailable
                null
            }
            is Route.Refused -> {
                session.phase = Session.PHASE_REFUSED
                session.failure = route.failure.name.let(::routeFailureToDartName)
                null
            }
            else -> {
                // Creates the profile now so the view can attach it before its
                // first load, and so a wipe has something to delete.
                profiles.profileFor(config.profileId)
                session.lastActiveAtMs = System.currentTimeMillis()
                // From here until close, the loopback proxy routes this
                // profile's requests on this config. Its reports arrive on the
                // proxy's threads; the session map and the event sink are the
                // main thread's.
                ProxyBinding(config) { failure ->
                    mainHandler.post { onRouteRefused(session, failure) }
                }
            }
        }
        credentials.openSession(previous?.config?.profileId, config.profileId, binding)

        if (binding != null) {
            try {
                newPage(session, openerId = null, firstUrl = firstLoadUrl(config.url, initialUrl))
            } catch (e: Exception) {
                // No session without its page: the open reaches Dart as an
                // error, and nothing stays bound or registered for it.
                sessions.remove(config.siteId)
                credentials.unbind(config.profileId)
                closePages(session, wipe = false)
                emitSessions()
                throw e
            }
        }

        emitSessions()
        return session.toMap()
    }

    private fun resolvePermission(requestId: String, decisionName: String) {
        for (session in sessions.values) {
            val pending = session.pendingPermissions.remove(requestId) ?: continue
            session.pageOf.remove(requestId)
            if (decisionName == "keepBlocked") {
                answerKeepBlocked(pending)
                return
            }
            when (pending) {
                is PendingPermission.Hardware -> grantCapture(pending.request, pending.granted + pending.toAsk) { granted ->
                    // Only what Android let through: a grant the app cannot use
                    // would pre-grant the next ask into the same refusal.
                    if (decisionName == "allowWhileOpen") {
                        session.sessionGrants.addAll(pending.toAsk.filter { it in granted })
                        // `6c` lists the session's grants (privacy-controls spec §3).
                        emitSessions()
                    }
                }
                is PendingPermission.Geolocation -> {
                    if (decisionName == "allowWhileOpen") session.sessionGrants.add(SessionGrants.GEOLOCATION)
                    pending.callback.invoke(pending.origin, true, false)
                    if (decisionName == "allowWhileOpen") emitSessions()
                }
            }
            return
        }
        // The request already timed out or its site closed — a silent no-op,
        // per this plan's Known Gaps on backgrounded events.
    }

    /** `6c`'s Revoke (privacy-controls spec §3): one "allow while open" grant
     *  goes, and every page of the container reloads, so no page, viewed or
     *  paused, keeps a stream (user's ruling, 2026-10-02). A no-op on an
     *  unknown session or a kind not granted. */
    private fun revokeGrant(siteId: String, kind: String) {
        val session = sessions[siteId] ?: return
        if (!SessionGrants.revoke(session.sessionGrants, kind)) return
        for (page in session.pages.values) page.reload()
        emitSessions()
    }

    private fun resolveDownload(requestId: String, decisionName: String) {
        for (session in sessions.values) {
            val pending = session.pendingDownloads.remove(requestId) ?: continue
            session.pageOf.remove(requestId)
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

    private fun extractArticle(page: Page?, result: MethodChannel.Result) {
        if (page == null) {
            result.success(null)
            return
        }
        page.extractArticle { article -> result.success(article) }
    }

    // --- Closing -------------------------------------------------------------

    /** Every pending ask and held download of [pageId] — of every page when
     *  null — answered, never left hanging (tabs spec §5.6): an ask is denied
     *  as "keep blocked", a held download discarded. */
    private fun answerPendingOf(session: Session, pageId: String?) {
        val requestIds = session.pageOf.filterValues { pageId == null || it == pageId }.keys.toList()
        for (requestId in requestIds) {
            session.pageOf.remove(requestId)
            session.pendingPermissions.remove(requestId)?.let(::answerKeepBlocked)
            session.pendingDownloads.remove(requestId)
        }
    }

    /** A profile whose pages are still tearing down, and what waits for them. */
    private class Draining {
        /** [closePages] calls on this profile not yet finished. */
        var closes = 0
        val then = mutableListOf<() -> Unit>()
    }

    /** By profile id. Main thread only. */
    private val tearingDown = HashMap<String, Draining>()

    /**
     * Tears down every page of [session], each through its own Teardown, and
     * — when [wipe] — wipes the profile once, after the last page on that
     * profile is destroyed (tabs spec §5.8a): a profile with a live WebView
     * on it cannot be deleted, only cleared in place. "Last" counts every
     * close still draining on the profile, not only this one: a reopened
     * site's previous pages may still be tearing down on it.
     */
    private fun closePages(session: Session, wipe: Boolean) {
        answerPendingOf(session, null)
        val pages = session.pages.values.toList()
        session.pages.clear()
        val profileId = session.config.profileId
        val draining = tearingDown.getOrPut(profileId) { Draining() }
        draining.closes++
        if (wipe) {
            draining.then += {
                // Off the throwaway journal only once the wipe has run: a
                // wipe that throws leaves it for the next start's sweep.
                wipeThenForget(profileId, throwaways) {
                    deleteDownloadsDir(context, profileId)
                    profiles.wipe(profileId)
                }
            }
        }
        val countdown = CloseCountdown(pages.map(Page::id)) { closeDrained(profileId, draining) }
        for (page in pages) page.close(clearCache = wipe) { countdown.destroyed(page.id) }
    }

    private fun closeDrained(profileId: String, draining: Draining) {
        draining.closes--
        if (draining.closes > 0) return
        if (tearingDown[profileId] === draining) tearingDown.remove(profileId)
        for (next in draining.then) {
            // One failing wipe must not stop the others, nor reach WebView's
            // callback that destroyed the page.
            runCatching(next)
        }
    }

    /**
     * The `wipe` method (tabs spec §5.8a): never while a page of [profileId]
     * is alive. A live session on it is closed with a wipe; pages still
     * tearing down make it wait for them; otherwise it runs now.
     */
    private fun wipeProfile(profileId: String) {
        val live = sessions.values.firstOrNull { it.config.profileId == profileId }
        if (live != null) return close(live.config.siteId, wipe = true)
        val wipe = {
            deleteDownloadsDir(context, profileId)
            profiles.wipe(profileId)
        }
        val draining = tearingDown[profileId]
        if (draining != null) draining.then += wipe else wipe()
    }

    /**
     * Closes a container: every page torn down, then — when it is to be
     * wiped — its profile wiped once (see [closePages]). [wipe] overrides the
     * session's own wipe-on-exit for this close only (tabs spec §5.7).
     */
    private fun close(siteId: String, wipe: Boolean? = null) {
        pendingOpens.cancel(siteId)
        val session = sessions.remove(siteId) ?: return
        // Chromium keeps sending this profile's credential; the proxy now
        // answers 403, and closes every tunnel it opened on this session's
        // route, which Chromium would otherwise reuse on the next open.
        credentials.unbind(session.config.profileId)
        // The session's flag, not the config's: `keep` turns it off for a
        // throwaway saved as a site while its page is still open.
        closePages(session, wipe ?: session.wipeOnExit)
        emitSessions()
    }

    /** One page. A container's last page closes the container. */
    private fun closePage(pageId: String) {
        val session = sessions.values.firstOrNull { it.pages.containsKey(pageId) } ?: return
        if (session.pages.size <= 1) return close(session.config.siteId)
        answerPendingOf(session, pageId)
        val page = session.pages.remove(pageId) ?: return
        // Counted with the profile's other closes, so a wipe that arrives
        // while this page is still tearing down waits for it too (§5.8a).
        val profileId = session.config.profileId
        val draining = tearingDown.getOrPut(profileId) { Draining() }
        draining.closes++
        page.close(clearCache = false) { closeDrained(profileId, draining) }
        emitSessions()
    }

    /** Tabs spec §5.8: every lock, and panic's first step. */
    private fun closeAll() {
        pendingOpens.cancelAll()
        for (siteId in sessions.keys.toList()) close(siteId)
    }

    /**
     * Panic's first step. `deleteProfile` throws while a profile is attached to
     * a live WebView, so every session closes before the store is emptied;
     * panic does not wait for the pages' Teardown, and
     * [ProfileManager.wipeAll] journals whatever is still in use.
     */
    private fun wipeAll() {
        closeAll()
        java.io.File(context.filesDir, "downloads").deleteRecursively()
        profiles.wipeAll()
        // Every profile is gone, throwaways included: nothing left to sweep.
        throwaways.clear()
    }

    /** `keep` (spec §5.3–5.4): a throwaway saved as a site. A no-op on an
     *  unknown session, like every in-page control. */
    private fun keep(siteId: String) {
        val session = sessions[siteId] ?: return
        keepThrowaway(session.config.profileId, throwaways) { session.wipeOnExit = false }
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
        proxyLogin = proxyLoginFrom(call.argument<String>("proxyUser"), call.argument<String>("proxyPassword")),
        proxyLoginPerSite = call.argument<Boolean>("proxyLoginPerSite") ?: false,
        securityLevel = SecurityLevel.fromChannel(call.argument<String>("securityLevel")),
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
    "UNSUPPORTED" -> "unsupported"
    "PROXY_LOGIN_REJECTED" -> "proxyLoginRejected"
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

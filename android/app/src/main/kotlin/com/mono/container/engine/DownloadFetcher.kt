package com.mono.container.engine

sealed class DownloadOutcome {
    object Saved : DownloadOutcome()
    object Kept : DownloadOutcome()
    data class Failed(val reason: RouteFailure?) : DownloadOutcome()
}

/** Everything [ProxyHttpClient.fetch] needs to issue a download's GET. */
data class DownloadRequest(
    val host: String,
    val port: Int,
    val secure: Boolean,
    val path: String,
    val headers: Map<String, String>,
)

/**
 * Splits a download URL and decides what its GET says.
 *
 * The headers are the reason this is a function rather than four lines
 * inside [DownloadFetcher.fetchTo]: the manual fetch used to send none at
 * all, while the system `DownloadManager` path has always sent a User-Agent
 * and a Cookie, so a cookie-gated download succeeded when saved to the
 * device and came back as an HTML login page when kept in the container.
 * Both paths now build their headers here, which is what keeps them the
 * same client rather than two clients that happen to agree.
 *
 * [userAgent] and [cookie] are passed in because their sources —
 * [userAgentFor] and `CookieManager` — are Android-only; keeping them out
 * lets the decision itself be tested on the JVM.
 */
fun downloadRequest(url: String, userAgent: String, cookie: String?): DownloadRequest {
    val parsed = java.net.URL(url)
    val secure = parsed.protocol == "https"
    return DownloadRequest(
        host = parsed.host,
        port = if (parsed.port != -1) parsed.port else if (secure) 443 else 80,
        secure = secure,
        path = (parsed.path?.ifEmpty { "/" } ?: "/") + (parsed.query?.let { "?$it" } ?: ""),
        headers = buildMap {
            put("User-Agent", userAgent)
            // An empty jar must not become a bare `Cookie:` line, which some
            // origins reject outright.
            if (!cookie.isNullOrEmpty()) put("Cookie", cookie)
        },
    )
}

/** The origin answered, but not with the file — a login page, a 404. */
class DownloadRejectedException(val status: Int) : java.io.IOException("download answered $status")

/** The connection closed cleanly before [expected] bytes arrived. */
class IncompleteDownloadException(val received: Long, val expected: Long) :
    java.io.IOException("download ended at $received of $expected bytes")

/**
 * Which profiles have been wiped since a download began, so a kept download
 * still running when its site is wiped (or the app panics) never lands in the
 * container afterwards, and is never opened.
 *
 * A download takes a [Ticket] on the platform thread when it is resolved; a
 * wipe is recorded ([wiped], [wipedAll]) on the platform thread *before* the
 * files it deletes. [unlessWiped] runs the final rename under the same lock,
 * so a download either lands before the wipe is recorded (and the deletion
 * that follows removes it) or is refused.
 */
class DownloadWipes {
    data class Ticket(val profileId: String, val everything: Long, val profile: Long)

    private var everything = 0L
    private val profiles = HashMap<String, Long>()

    @Synchronized fun ticket(profileId: String) = Ticket(profileId, everything, profiles[profileId] ?: 0L)

    @Synchronized fun wiped(profileId: String) {
        profiles[profileId] = (profiles[profileId] ?: 0L) + 1
    }

    @Synchronized fun wipedAll() {
        everything++
    }

    @Synchronized fun isWiped(ticket: Ticket): Boolean =
        everything != ticket.everything || (profiles[ticket.profileId] ?: 0L) != ticket.profile

    /** Runs [commit] unless [ticket]'s profile was wiped since it was taken; else throws [DownloadWipedException]. */
    @Synchronized fun <T> unlessWiped(ticket: Ticket, commit: () -> T): T {
        if (isWiped(ticket)) throw DownloadWipedException()
        return commit()
    }
}

/** The site was wiped, or the app panicked, while its download ran. */
class DownloadWipedException : java.io.IOException("the site was wiped while its download ran")

/**
 * Streams [response]'s body into [target], and leaves [target] in place only
 * if the download is whole.
 *
 * Found on a device: a TLS read error partway through left a truncated PDF in
 * the container, and every retry added another beside it, none openable. So
 * the body goes to a `.part` sibling that is renamed only on success and
 * deleted on any failure, a short body is refused against `Content-Length`
 * (a clean early close is otherwise indistinguishable from the end), and a
 * non-2xx answer never becomes the file at all — a 401 login page kept as
 * `report.pdf` would read as a success.
 *
 * A read error is rethrown unchanged so [downloadFailureFor] can still name it.
 *
 * The final rename runs inside [commit], which may refuse it by throwing
 * (a wipe since the download began: [DownloadWipes.unlessWiped]); the `.part`
 * is deleted then too. The body is closed on every path.
 */
fun writeDownload(
    response: ProxyHttpClient.FetchedResponse,
    target: java.io.File,
    commit: (move: () -> Unit) -> Unit = { it() },
) {
    response.body.use { body ->
        if (response.status !in 200..299) throw DownloadRejectedException(response.status)
        val expected = response.headers.entries
            .firstOrNull { it.key.equals("Content-Length", ignoreCase = true) }
            ?.value?.trim()?.toLongOrNull()
        val part = java.io.File(target.parentFile, "${target.name}.part")
        try {
            val received = java.io.FileOutputStream(part).use { out -> body.copyTo(out) }
            if (expected != null && received != expected) throw IncompleteDownloadException(received, expected)
            commit {
                if (!part.renameTo(target)) throw java.io.IOException("could not move ${part.name} into place")
            }
        } catch (e: Throwable) {
            part.delete()
            throw e
        }
    }
}

/**
 * Where a proxied "save to device" holds the body before MediaStore takes it.
 * `File.createTempFile` refuses a prefix under three characters.
 */
fun deviceSaveTempFile(dir: java.io.File): java.io.File = java.io.File.createTempFile("download", null, dir)

/**
 * The failure a download's outcome line names. Mirrors the mapping the
 * interceptor used for proxied page loads before P2 (Plan 13), so a download
 * names the same cause a page load did.
 *
 * [route] is why this is not a verbatim copy of that mapping. The
 * interceptor's fetch only ever ran for a [Route.Proxy], so it could read a
 * [java.net.ConnectException] as "the proxy is down". This function also runs
 * for [Route.Direct], where there is no proxy to be unreachable and the same
 * exception means the destination refused the connection — reporting
 * PROXY_UNREACHABLE there would show "Cannot reach the proxy" for a site that
 * has no proxy configured.
 *
 * A rejected login is named on any route: on a direct one it can only come
 * from the network's own proxy, which really did reject it.
 */
internal fun downloadFailureFor(error: Throwable, route: Route): RouteFailure? = when (error) {
    is ProxyLoginRejectedException -> RouteFailure.PROXY_LOGIN_REJECTED
    is ProxyTunnelException -> RouteFailure.PROXY_REFUSED
    is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
    is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
    is java.net.ConnectException ->
        if (route is Route.Proxy) RouteFailure.PROXY_UNREACHABLE
        else RouteFailure.UPSTREAM_TIMEOUT
    else -> null
}

/** Plan D8: a download from an onion address on a direct route would send the name to DNS. */
internal fun refusesOnionDownload(route: Route, url: String): Boolean =
    route is Route.Direct && isOnionHost(
        runCatching { java.net.URI(url).host }.getOrNull()
            // URI leaves the host null for a name it cannot parse (an underscore): URL does not.
            ?: runCatching { java.net.URL(url).host }.getOrNull()
            ?: ""
    )

class DownloadFetcher(
    private val context: android.content.Context,
    private val profiles: ProfileManager,
    private val wipes: DownloadWipes,
) {
    /**
     * Blocking network and disk work — call off the main thread.
     *
     * [request] comes from [requestFor], which has to run on the main thread
     * first; see there for why the two are split.
     */
    fun run(
        config: SiteConfig,
        pending: PendingDownload,
        request: DownloadRequest,
        decisionName: String,
        ticket: DownloadWipes.Ticket,
    ): DownloadOutcome {
        if (wipes.isWiped(ticket)) return DownloadOutcome.Failed(null)
        val route = config.currentRoute()
        if (route is Route.Refused) return DownloadOutcome.Failed(route.failure)
        if (refusesOnionDownload(route, pending.url)) return DownloadOutcome.Failed(null)
        val fileName = sanitizeFileName(pending.fileName)
        return when (decisionName) {
            "keepInContainer" -> runCatching { keepInContainer(route, config, pending, request, fileName, ticket) }
                .getOrElse { DownloadOutcome.Failed(downloadFailureFor(it, route)) }
            "saveToDevice" -> when (route) {
                is Route.Direct -> runCatching { saveViaDownloadManager(pending, request, fileName) }
                    .getOrElse { DownloadOutcome.Failed(downloadFailureFor(it, route)) }
                is Route.Proxy, is Route.Tor -> runCatching { saveViaMediaStore(route, pending, request, fileName) }
                    .getOrElse { DownloadOutcome.Failed(downloadFailureFor(it, route)) }
                is Route.Refused -> error("handled above")
            }
            else -> error("unsupported download decision")
        }
    }

    private fun keepInContainer(
        route: Route, config: SiteConfig, pending: PendingDownload, request: DownloadRequest, fileName: String,
        ticket: DownloadWipes.Ticket,
    ): DownloadOutcome {
        val dir = java.io.File(context.filesDir, "downloads/${config.profileId}")
        dir.mkdirs()
        val target = uniqueFile(dir, fileName)
        try {
            fetchTo(route, request, target) { move -> wipes.unlessWiped(ticket, move) }
            // A wipe between the rename and here: the file must not be opened.
            if (wipes.isWiped(ticket)) throw DownloadWipedException()
        } catch (e: DownloadWipedException) {
            target.delete()
            // Only if empty: the mkdirs above must not leave a wiped site's directory behind.
            dir.delete()
            return DownloadOutcome.Failed(null)
        }
        val uri = androidx.core.content.FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", target)
        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
            setDataAndType(uri, pending.mimeType)
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
        return DownloadOutcome.Kept
    }

    private fun saveViaMediaStore(route: Route, pending: PendingDownload, request: DownloadRequest, fileName: String): DownloadOutcome {
        val temp = deviceSaveTempFile(context.cacheDir)
        return try {
            fetchTo(route, request, temp)
            // Pending until whole: other apps never see a half-written file,
            // and a failed copy deletes the entry rather than leaving a
            // truncated one in Downloads.
            val resolver = context.contentResolver
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(android.provider.MediaStore.Downloads.MIME_TYPE, pending.mimeType)
                put(android.provider.MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return DownloadOutcome.Failed(null)
            try {
                val output = resolver.openOutputStream(uri) ?: throw java.io.IOException("no output stream for $uri")
                output.use { out -> temp.inputStream().use { input -> input.copyTo(out) } }
                val done = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.Downloads.IS_PENDING, 0)
                }
                resolver.update(uri, done, null, null)
            } catch (e: Throwable) {
                runCatching { resolver.delete(uri, null, null) }
                throw e
            }
            DownloadOutcome.Saved
        } finally { temp.delete() }
    }

    private fun saveViaDownloadManager(pending: PendingDownload, request: DownloadRequest, fileName: String): DownloadOutcome {
        val manager = context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
        val enqueued = android.app.DownloadManager.Request(android.net.Uri.parse(pending.url))
            .setMimeType(pending.mimeType)
            .setDestinationInExternalPublicDir(android.os.Environment.DIRECTORY_DOWNLOADS, fileName)
            .setNotificationVisibility(android.app.DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
        request.headers.forEach { (key, value) -> enqueued.addRequestHeader(key, value) }
        manager.enqueue(enqueued)
        return DownloadOutcome.Saved
    }

    private fun fetchTo(
        route: Route, request: DownloadRequest, target: java.io.File,
        commit: (move: () -> Unit) -> Unit = { it() },
    ) {
        val response = ProxyHttpClient.fetch(
            route, request.host, request.port, request.secure, "GET", request.path, request.headers,
        )
        writeDownload(response, target, commit)
    }

    /**
     * The one place either download path learns what to send.
     *
     * The cookies come from **this site's** profile, not from
     * `CookieManager.getInstance()`, which is the default profile's jar and
     * holds nothing this site ever set — every [Page] puts its site on
     * its own profile via `WebViewCompat.setProfile`. Reading the global jar
     * is both wrong (the session cookie is not in it) and the exact
     * degrade-to-default that [ProfileManager.profileFor] exists to refuse, so
     * a device that cannot isolate fails the download here rather than
     * fetching it as some other container.
     *
     * **Main thread only.** androidx.webkit's `ProfileStore` is a UI-thread
     * API, and [run] executes on a worker, so this is called by
     * `EngineChannel.resolveDownload` before it hands off — never from inside
     * [run].
     */
    fun requestFor(config: SiteConfig, pending: PendingDownload) = downloadRequest(
        pending.url,
        userAgentFor(config.userAgentMode, context),
        profiles.profileFor(config.profileId).cookieManager.getCookie(pending.url),
    )

    private fun uniqueFile(dir: java.io.File, fileName: String): java.io.File {
        val dot = fileName.lastIndexOf('.')
        val base = if (dot > 0) fileName.substring(0, dot) else fileName
        val ext = if (dot > 0) fileName.substring(dot) else ""
        var candidate = java.io.File(dir, fileName)
        var suffix = 1
        while (candidate.exists()) { candidate = java.io.File(dir, "$base ($suffix)$ext"); suffix++ }
        return candidate
    }
}

fun sanitizeFileName(name: String): String {
    val stripped = name.replace(Regex("[/\\\\]"), "_").replace("..", "_").trimStart('.')
    return stripped.ifEmpty { "download" }
}

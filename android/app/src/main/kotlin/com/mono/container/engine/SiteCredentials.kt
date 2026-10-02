package com.mono.container.engine

import java.io.Closeable
import java.security.MessageDigest
import java.security.SecureRandom

/**
 * The loopback proxy's host as Chromium names it in a proxy challenge. The
 * proxy refuses any destination with this name (see [decide]), so only the
 * proxy itself can challenge as it.
 */
internal const val LOOPBACK_HOST = "127.0.0.1"

/** The realm of the loopback proxy's `407`. Not a secret: [proxyAuthAnswer] also requires [LOOPBACK_HOST]. */
internal const val PROXY_REALM = "container"

/**
 * One profile's answer to the loopback proxy's challenge (P2 spec §2). Never
 * sent to Dart, written to disk or logged, so [toString] prints neither half.
 */
class ProxyCredential internal constructor(val user: String, val password: String) {
    override fun toString() = "ProxyCredential(redacted)"
}

/**
 * What an authenticated connection is routed by: the open session's site, and
 * whom to tell when its route is refused. [onRefused] is called on the proxy's
 * own threads.
 *
 * It also holds every socket the loopback proxy opened under it, on either
 * side, until [revoke] closes them all. A connection's route is resolved once,
 * when it opens, and Chromium pools its tunnels per profile, which outlives the
 * view: without this, a site reopened on a new route went on using a tunnel on
 * the old one (open problem 1, seen on the emulator going direct for a site set
 * to SOCKS5).
 */
class ProxyBinding(val config: SiteConfig, val onRefused: (RouteFailure) -> Unit) {
    private val held = HashSet<Closeable>()
    private var revoked = false

    /**
     * Keeps [socket] until [revoke] or [release]. False, with [socket] already
     * closed, once this binding is revoked: a connection authenticated just
     * before its session closed must not start relaying after it.
     */
    internal fun hold(socket: Closeable): Boolean {
        val kept = synchronized(this) {
            if (!revoked) held += socket
            !revoked
        }
        if (!kept) runCatching { socket.close() }
        return kept
    }

    /** Whether the session this binding belonged to has closed or been rebound. */
    internal val isRevoked: Boolean @Synchronized get() = revoked

    /** [socket] has closed on its own; nothing to close later. */
    @Synchronized internal fun release(socket: Closeable) {
        held.remove(socket)
    }

    /**
     * Closes every socket held and every one held from now on. Called on the
     * main thread; a plain socket's close sends a FIN and does not block
     * (nothing here sets `SO_LINGER`).
     */
    internal fun revoke() {
        val sockets = synchronized(this) {
            revoked = true
            held.toList().also { held.clear() }
        }
        for (socket in sockets) runCatching { socket.close() }
    }
}

/**
 * Which credential belongs to which profile, and which profiles have an open
 * session. A profile's credential is made the first time it is asked for and
 * then kept for the process: Chromium caches it in memory and neither a lock
 * nor a wipe clears that cache (findings, "Is the auth cache cleared"). A
 * wiped saved site gets a fresh profile id, and so a fresh credential.
 *
 * Main thread: [credentialFor], [bind], [unbind]. Proxy threads: [lookup].
 * A binding is revoked outside this table's lock, so closing its sockets never
 * holds up a lookup.
 */
class SiteCredentials(private val random: SecureRandom = SecureRandom()) {
    private val byProfile = HashMap<String, ProxyCredential>()
    private val bindings = HashMap<String, ProxyBinding>()

    @Synchronized fun credentialFor(profileId: String): ProxyCredential =
        byProfile.getOrPut(profileId) { ProxyCredential(randomHex(), randomHex()) }

    /**
     * The site's session is open: its credential now routes by [binding]. A
     * later bind replaces it and closes every connection opened under the one
     * it replaces, whether or not the route changed (user's ruling,
     * 2026-09-30): a tunnel never outlives the binding it was opened under.
     * The cost is one new tunnel per host when a still-open site is opened
     * again; Chromium opens it on its next request.
     */
    fun bind(profileId: String, binding: ProxyBinding) {
        val replaced = synchronized(this) {
            credentialFor(profileId)
            bindings.put(profileId, binding)
        }
        if (replaced !== binding) replaced?.revoke()
    }

    /**
     * The site's session is closed: its credential finds nothing until the
     * next [bind], and every connection opened under it is closed.
     */
    fun unbind(profileId: String) {
        synchronized(this) { bindings.remove(profileId) }?.revoke()
    }

    /**
     * A site's session opens on [profileId], replacing the session it had on
     * [previousProfileId], if any. [binding] is null when the new route is
     * refused, so nothing is bound for it.
     */
    fun openSession(previousProfileId: String?, profileId: String, binding: ProxyBinding?) {
        // A reopen normally follows a close. If one arrives without it, the
        // last session's binding ends first, on the same profile too: when the
        // new route is refused, nothing replaces it, and left alone it would
        // go on routing the profile, and holding its tunnels, on the old
        // settings until the next close.
        previousProfileId?.let(::unbind)
        if (binding != null) bind(profileId, binding)
    }

    /**
     * The open session [user] and [password] belong to, or null. Every open
     * session is compared, in constant time, and the loop never stops early, so
     * how long a lookup takes says nothing about which bytes matched.
     */
    @Synchronized fun lookup(user: String, password: String): ProxyBinding? {
        val offered = "$user:$password".toByteArray(Charsets.UTF_8)
        var found: ProxyBinding? = null
        for ((profileId, binding) in bindings) {
            val credential = byProfile.getValue(profileId)
            val expected = "${credential.user}:${credential.password}".toByteArray(Charsets.UTF_8)
            if (MessageDigest.isEqual(offered, expected)) found = binding
        }
        return found
    }

    /** 128 bits, as 32 lowercase hex digits: never a colon, so `user:password` is unambiguous. */
    private fun randomHex(): String =
        ByteArray(16).also(random::nextBytes).joinToString("") { "%02x".format(it) }
}

/**
 * The answer a view gives an HTTP auth challenge, or null to leave it to
 * WebView's default, which cancels it. Only the loopback proxy's own challenge
 * is answered, and every time it arrives: the spike saw five parallel requests
 * make five separate calls, and an unanswered one waits for ever. A site's own
 * HTTP auth is left alone, as today.
 */
internal fun proxyAuthAnswer(host: String?, realm: String?, credential: () -> ProxyCredential): ProxyCredential? =
    if (host == LOOPBACK_HOST && realm == PROXY_REALM) credential() else null

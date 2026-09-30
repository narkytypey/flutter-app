package com.mono.container.engine

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
 */
class ProxyBinding(val config: SiteConfig, val onRefused: (RouteFailure) -> Unit)

/**
 * Which credential belongs to which profile, and which profiles have an open
 * session. A profile's credential is made the first time it is asked for and
 * then kept for the process: Chromium caches it in memory and neither a lock
 * nor a wipe clears that cache (findings, "Is the auth cache cleared"). A
 * wiped saved site gets a fresh profile id, and so a fresh credential.
 *
 * Main thread: [credentialFor], [bind], [unbind]. Proxy threads: [lookup].
 */
class SiteCredentials(private val random: SecureRandom = SecureRandom()) {
    private val byProfile = HashMap<String, ProxyCredential>()
    private val bindings = HashMap<String, ProxyBinding>()

    @Synchronized fun credentialFor(profileId: String): ProxyCredential =
        byProfile.getOrPut(profileId) { ProxyCredential(randomHex(), randomHex()) }

    /** The site's session is open: its credential now routes by [binding]. A later bind replaces it. */
    @Synchronized fun bind(profileId: String, binding: ProxyBinding) {
        credentialFor(profileId)
        bindings[profileId] = binding
    }

    /** The site's session is closed: its credential finds nothing until the next [bind]. */
    @Synchronized fun unbind(profileId: String) {
        bindings.remove(profileId)
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

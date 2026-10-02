package com.mono.container.engine

import java.io.IOException
import java.security.MessageDigest

/**
 * A login for a site's own upstream proxy (proxy-auth spec §2). Not the
 * loopback proxy's [ProxyCredential]: that one only ever answers our own
 * `407`. [toString] prints neither half, so a logged [SiteConfig] or [Route]
 * names no password (spec §2.5).
 */
data class ProxyLogin(val user: String, val password: String) {
    override fun toString() = "ProxyLogin(redacted)"
}

/**
 * The upstream proxy turned this site's login down, or wanted one it does not
 * have (spec §3). Its message names no credential and no host.
 */
class ProxyLoginRejectedException(message: String) : IOException(message)

/**
 * Spec §2.3: the automatic per-site login. SHA-256 of
 * `"container-proxy-login:" + profileId` (UTF-8); the user is the first 16
 * bytes and the password the last 16, each as 32 lowercase hex digits. Tor
 * gives each distinct login its own circuit, and a wipe rotates the profile
 * id, so a wiped site gets a fresh login and a fresh circuit. Nothing about
 * the profile id can be read back from it.
 */
fun perSiteLogin(profileId: String): ProxyLogin {
    val digest = MessageDigest.getInstance("SHA-256")
        .digest("container-proxy-login:$profileId".toByteArray(Charsets.UTF_8))
    fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
    return ProxyLogin(hex(digest.copyOfRange(0, 16)), hex(digest.copyOfRange(16, 32)))
}

/** The typed login the channel sent: none without a user; a missing password is empty. */
fun proxyLoginFrom(user: String?, password: String?): ProxyLogin? =
    if (user.isNullOrEmpty()) null else ProxyLogin(user, password ?: "")

/** Spec §2.1: the per-site login when the site asks for one, whatever is typed; else the typed one. */
fun loginFor(config: SiteConfig): ProxyLogin? =
    if (config.proxyLoginPerSite) perSiteLogin(config.profileId) else config.proxyLogin

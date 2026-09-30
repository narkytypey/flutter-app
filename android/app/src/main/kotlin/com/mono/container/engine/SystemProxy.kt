package com.mono.container.engine

import android.content.Context
import android.net.ConnectivityManager
import android.net.ProxyInfo

/**
 * The network's own HTTP proxy, as Android reports it: set in the Wi-Fi
 * settings, served from a PAC file, or set for the whole device by whoever
 * manages it. [exclusions] are the hosts it is bypassed for.
 *
 * A direct site goes out through it (user's ruling, 2026-09-30). Until
 * `198cdda` WebView itself honoured it for direct sites; the process-wide
 * override replaced it, and the loopback proxy then opened a direct site's
 * connections with a plain socket, so on a network that only works through a
 * proxy no direct site loaded. A proxied site still reaches its own proxy as
 * before, and never falls back to anything.
 */
class SystemProxy(val host: String, val port: Int, val exclusions: List<String> = emptyList())

/**
 * The system proxy a direct connection to [targetHost] goes through, or null
 * to connect straight: when there is none, when it has no usable host and port
 * (a PAC setup whose local proxy is not up yet reports none), for a loopback
 * destination, and for a host its exclusion list names.
 */
internal fun systemProxyFor(proxy: SystemProxy?, targetHost: String): SystemProxy? {
    if (proxy == null || proxy.host.isEmpty() || proxy.port !in 1..65535) return null
    val host = targetHost.removeSurrounding("[", "]").trimEnd('.').lowercase()
    if (isLoopbackHost(host)) return null
    if (proxy.exclusions.any { excludes(it, host) }) return null
    return proxy
}

private val IPV4_LOOPBACK = Regex("127(\\.\\d{1,3}){3}")

private fun isLoopbackHost(host: String): Boolean =
    host == "localhost" || host.endsWith(".localhost") || host == "::1" || IPV4_LOOPBACK.matches(host)

/**
 * Whether exclusion [pattern] names [host] (lower case already). A pattern is a
 * glob: `*` matches anything, and a leading `.` means any subdomain, as
 * `*.` does. Everything else is literal, case ignored.
 */
private fun excludes(pattern: String, host: String): Boolean {
    var glob = pattern.trim().trimEnd('.').lowercase()
    if (glob.isEmpty()) return false
    if (glob.startsWith(".")) glob = "*$glob"
    return Regex(glob.split('*').joinToString(".*") { Regex.escape(it) }).matches(host)
}

/**
 * Where [Router.connect] reads the system proxy from, on every direct
 * connection, so a change in the Wi-Fi settings applies to the next one. The
 * JVM tests never [install] it, so it reads none there.
 */
object SystemProxies {
    @Volatile var current: () -> SystemProxy? = { null }
        private set

    fun install(context: Context) {
        val connectivity = context.getSystemService(ConnectivityManager::class.java) ?: return
        current = { runCatching { connectivity.defaultProxy?.let(::fromProxyInfo) }.getOrNull() }
    }

    /** A PAC setup is served by a local proxy the system runs; its host and port are that proxy's. */
    private fun fromProxyInfo(info: ProxyInfo): SystemProxy? {
        val host = info.host ?: return null
        return SystemProxy(host, info.port, info.exclusionList?.toList().orEmpty())
    }
}

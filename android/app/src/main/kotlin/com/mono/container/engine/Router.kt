package com.mono.container.engine

enum class RouteFailure {
    PROXY_UNREACHABLE, PROXY_REFUSED, UPSTREAM_TIMEOUT, TLS_FAILURE, MISCONFIGURED,
    /** This WebView cannot override its proxy, so a proxied site cannot be routed (P2 spec §3.3). */
    UNSUPPORTED,
    /** The site's proxy turned its login down, or wanted one it does not have (proxy-auth spec §3). */
    PROXY_LOGIN_REJECTED,
}

sealed class Route {
    object Direct : Route()
    /** [login] is what the tunnel offers the proxy, or null for none (proxy-auth spec §2.1). */
    data class Proxy(val host: String, val port: Int, val socks: Boolean, val login: ProxyLogin? = null) : Route()
    data class Refused(val failure: RouteFailure) : Route()
}

/**
 * Turn 8: "never fall back to a direct connection on its own."
 * There is deliberately no branch returning [Route.Direct] for a proxied site.
 */
object Router {
    fun resolve(config: SiteConfig, proxyReachable: Boolean): Route {
        if (config.proxyMode == "direct") return Route.Direct

        // Only these two proxy modes exist. Anything else is a mode this
        // build does not understand, and is refused rather than allowed to
        // fall through to connect() — http reaches HttpConnectTunnel, socks5
        // is delegated to the platform.
        if (config.proxyMode != "socks5" && config.proxyMode != "http") {
            return Route.Refused(RouteFailure.MISCONFIGURED)
        }

        val host = config.proxyHost
        val port = config.proxyPort
        if (host.isNullOrEmpty() || port == null) {
            return Route.Refused(RouteFailure.MISCONFIGURED)
        }
        if (!proxyReachable) return Route.Refused(RouteFailure.PROXY_UNREACHABLE)

        return Route.Proxy(host, port, socks = config.proxyMode == "socks5", login = loginFor(config))
    }

    /**
     * Opens a socket for [route]. Never called for [Route.Refused].
     *
     * A direct route goes through the network's own proxy when it has one and
     * the host is not excluded ([systemProxyFor]), tunnelled like an http
     * route, so the proxy does the lookup; otherwise it connects straight.
     * [systemProxy] is read on every call, so a Wi-Fi change applies to the
     * next connection. A proxied route never uses it.
     *
     * SOCKS is delegated to the platform, which still supports it. HTTP proxies
     * go through [HttpConnectTunnel] because Android removed `Proxy.Type.HTTP`
     * from [java.net.Socket]; passing it here throws `IllegalArgumentException`.
     *
     * The SOCKS target is deliberately unresolved: the platform then sends the
     * proxy the hostname (address type 3) and the proxy does the lookup. A
     * resolved address would make the device look the name up itself first,
     * telling its DNS resolver every host a proxied site visits. The cost is
     * that a SOCKS4-only proxy cannot be used — SOCKS4 carries no hostnames —
     * which the user accepted: the mode is SOCKS5.
     */
    fun connect(
        route: Route,
        targetHost: String,
        targetPort: Int,
        systemProxy: () -> SystemProxy? = SystemProxies.current,
    ): java.net.Socket =
        when (route) {
            is Route.Direct -> systemProxyFor(systemProxy(), targetHost)
                ?.let { HttpConnectTunnel.open(it.host, it.port, targetHost, targetPort) }
                ?: java.net.Socket(targetHost, targetPort)
            is Route.Proxy ->
                if (route.socks) {
                    java.net.Socket(
                        java.net.Proxy(
                            java.net.Proxy.Type.SOCKS,
                            java.net.InetSocketAddress(route.host, route.port),
                        )
                    ).apply { connect(java.net.InetSocketAddress.createUnresolved(targetHost, targetPort), 15_000) }
                } else {
                    HttpConnectTunnel.open(route.host, route.port, targetHost, targetPort)
                }
            is Route.Refused -> error("connect() called for a refused route")
        }
}

/** Resolves a site's live route consistently for pages and downloads. */
fun SiteConfig.currentRoute(): Route =
    Router.resolve(this, ProxyProbe.reachable(proxyHost ?: "", proxyPort ?: -1))

/**
 * The route `open` decides (P2 spec §1.4). Every site's traffic reaches its
 * route through the loopback proxy, which needs WebView's proxy override.
 * Without it a proxied site is refused, never sent direct, and [resolve] —
 * which probes — is not called. A direct site opens as it always has.
 *
 * With it, every site first waits in [awaitOverride] until WebView has applied
 * the override, which it does asynchronously: until then a request goes
 * direct (user's ruling, 2026-09-30). Direct sites wait too, since Autofill's
 * query is blocked only by the override. There is no timeout and no new copy:
 * if the override never applies, the site stays on its opening checklist.
 * Called off the main thread, like [resolve].
 */
fun routeAtOpen(config: SiteConfig, proxyOverride: Boolean, awaitOverride: () -> Unit, resolve: () -> Route): Route {
    if (!proxyOverride) {
        return if (config.proxyMode != "direct") Route.Refused(RouteFailure.UNSUPPORTED) else resolve()
    }
    awaitOverride()
    return resolve()
}

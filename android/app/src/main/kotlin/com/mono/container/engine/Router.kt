package com.mono.container.engine

enum class RouteFailure {
    PROXY_UNREACHABLE, PROXY_REFUSED, UPSTREAM_TIMEOUT, TLS_FAILURE, MISCONFIGURED
}

sealed class Route {
    object Direct : Route()
    data class Proxy(val host: String, val port: Int, val socks: Boolean) : Route()
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

        return Route.Proxy(host, port, socks = config.proxyMode == "socks5")
    }

    /**
     * Opens a socket for [route]. Never called for [Route.Refused].
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
    fun connect(route: Route, targetHost: String, targetPort: Int): java.net.Socket =
        when (route) {
            is Route.Direct -> java.net.Socket(targetHost, targetPort)
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

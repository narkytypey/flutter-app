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

        val host = config.proxyHost
        val port = config.proxyPort
        if (host.isNullOrEmpty() || port == null) {
            return Route.Refused(RouteFailure.MISCONFIGURED)
        }
        if (!proxyReachable) return Route.Refused(RouteFailure.PROXY_UNREACHABLE)

        return Route.Proxy(host, port, socks = config.proxyMode == "socks5")
    }

    /** Opens a socket for [route]. Never called for [Route.Refused]. */
    fun connect(route: Route, targetHost: String, targetPort: Int): java.net.Socket =
        when (route) {
            is Route.Direct -> java.net.Socket(targetHost, targetPort)
            is Route.Proxy -> {
                val type = if (route.socks) java.net.Proxy.Type.SOCKS
                           else java.net.Proxy.Type.HTTP
                java.net.Socket(
                    java.net.Proxy(type, java.net.InetSocketAddress(route.host, route.port))
                ).apply { connect(java.net.InetSocketAddress(targetHost, targetPort), 15_000) }
            }
            is Route.Refused -> error("connect() called for a refused route")
        }
}

/**
 * The one place a [SiteConfig] is turned into a [Route] — wraps
 * [Router.resolve] with the live [ProxyProbe.reachable] check so every call
 * site (page loads, downloads) asks the same question the same way.
 */
fun SiteConfig.currentRoute(): Route =
    Router.resolve(this, proxyReachable = ProxyProbe.reachable(proxyHost ?: "", proxyPort ?: -1))

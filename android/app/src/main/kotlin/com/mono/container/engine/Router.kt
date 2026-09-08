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

        // Android removed HTTP-proxy support from java.net.Socket (AOSP
        // deleted HttpConnectSocketImpl), so connect() below would throw
        // IllegalArgumentException("Invalid Proxy") at construction for
        // Proxy.Type.HTTP. Refusing here means the user is told the site is
        // misconfigured immediately, instead of seeing "The destination did
        // not respond" after ProxyProbe made the proxy look reachable.
        // Everything that is not socks5 is refused, so an unrecognised mode
        // cannot silently fall into the same broken path.
        if (config.proxyMode != "socks5") {
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

/** Resolves a site's live route consistently for pages and downloads. */
fun SiteConfig.currentRoute(): Route =
    Router.resolve(this, ProxyProbe.reachable(proxyHost ?: "", proxyPort ?: -1))

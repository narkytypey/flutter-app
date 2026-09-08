import 'site.dart';

/// Why a request was refused. These are distinguished because the user's
/// remedy differs: an unreachable proxy is a local problem, a refused one is a
/// policy problem at the far end. Spec `8b` currently says only "Proxy
/// unreachable"; the copy is Plan 4's to settle.
enum RouteFailure {
  proxyUnreachable,
  proxyRefused,
  upstreamTimeout,
  tlsFailure,
  misconfigured,
}

sealed class RouteDecision {
  const RouteDecision();
}

class RouteDirect extends RouteDecision {
  const RouteDirect();
}

class RouteProxy extends RouteDecision {
  const RouteProxy({required this.host, required this.port, required this.mode});

  final String host;
  final int port;
  final ProxyMode mode;
}

class RouteRefused extends RouteDecision {
  const RouteRefused(this.failure);

  final RouteFailure failure;
}

/// Turn 8: "never fall back to a direct connection on its own." A site that
/// asked for a proxy and cannot have one gets [RouteRefused]. There is
/// deliberately no branch that returns [RouteDirect] for such a site — if you
/// add one, you have removed the product's central guarantee.
RouteDecision resolveRoute(Site site, {required bool proxyReachable}) {
  if (site.proxyMode == ProxyMode.direct) return const RouteDirect();

  // Android removed HTTP-proxy support from `java.net.Socket` (AOSP deleted
  // `HttpConnectSocketImpl`), so the native Router cannot open one on any
  // device — `Socket(Proxy(Type.HTTP, ...))` throws at construction. Refuse
  // here rather than let the request fail late and be reported as a timeout.
  // Anything that is not socks5 is caught, not just http, so a future mode
  // cannot silently inherit the broken path.
  if (site.proxyMode != ProxyMode.socks5) {
    return const RouteRefused(RouteFailure.misconfigured);
  }

  final host = site.proxyHost;
  final port = site.proxyPort;
  if (host == null || host.isEmpty || port == null) {
    return const RouteRefused(RouteFailure.misconfigured);
  }
  if (!proxyReachable) return const RouteRefused(RouteFailure.proxyUnreachable);

  return RouteProxy(host: host, port: port, mode: site.proxyMode);
}

String refusalMessage(RouteFailure failure) => switch (failure) {
      RouteFailure.proxyUnreachable => 'Cannot reach the proxy',
      RouteFailure.proxyRefused => 'The proxy refused the destination',
      RouteFailure.upstreamTimeout => 'The destination did not respond',
      RouteFailure.tlsFailure => 'The secure connection failed',
      RouteFailure.misconfigured => 'This site has no proxy configured',
    };

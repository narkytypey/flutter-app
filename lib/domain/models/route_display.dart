import '../onion.dart';
import 'site.dart';

// How a route is named on screen, and the two rules Tor adds to it. Tor is a
// name, so it reads `Tor` wherever a route is named (built-in Tor spec §7,
// plan D6); only the all-capitals throwaway tag says `TOR`.

/// The container's top bar. There is no DIRECT label (browser-chrome spec §4.4).
String topBarRouteLabel(ProxyMode mode) => switch (mode) {
      ProxyMode.direct => '',
      ProxyMode.tor => 'Tor',
      ProxyMode.socks5 || ProxyMode.http => mode.name.toUpperCase(),
    };

/// `2c`'s viewed container: `viewing now · socks5`, `viewing now · Tor`.
String switcherRouteName(ProxyMode mode) => mode == ProxyMode.tor ? 'Tor' : mode.name;

/// Spec `6c`'s proxy row: `SOCKS5 · 127.0.0.1:9050`, or `Tor`.
String proxyDescriptor(Site site) => switch (site.proxyMode) {
      ProxyMode.direct => 'Direct',
      ProxyMode.socks5 => 'SOCKS5 · ${site.proxyHost}:${site.proxyPort}',
      ProxyMode.http => 'HTTP · ${site.proxyHost}:${site.proxyPort}',
      ProxyMode.tor => 'Tor',
    };

/// `8b`'s Tunnel row, which its sentence names too.
String tunnelDescriptor(Site site) {
  if (site.proxyMode == ProxyMode.tor) return 'Tor';
  return site.proxyHost == null
      ? 'no proxy'
      : '${site.proxyMode.name} · ${site.proxyHost}:${site.proxyPort}';
}

/// Whether `8b` offers "Open without the tunnel" (spec §5.6): never for an
/// onion address, which cannot go direct and would leak its name.
bool canOpenWithoutTunnel(Site site) => !isOnionHost(site.host);

/// Spec §5.4: on Tor, Block WebRTC is always on, and its switch inert.
bool webRtcLocked(ProxyMode mode) => mode == ProxyMode.tor;

import '../onion.dart';
import 'site.dart';

// How a route is named on screen, and the two rules Tor adds to it. Tor is a
// name, so it reads `Tor` wherever a route is named (built-in Tor spec §7,
// plan D6); only the all-capitals throwaway tag says `TOR`.

/// What the pill's case says about the container's storage (restyle v2 §8
/// `2b`): a saved site that keeps its storage, one that wipes on exit, or a
/// throwaway (which is wiped when it closes).
enum CaseKind { keep, wipe, throwaway }

/// The container's top bar. There is no DIRECT label (browser-chrome spec §4.4).
///
/// A container that does not keep its storage also says so in words, beside
/// the case mark's shape (user's ruling 2026-10-08, restyle v2 spec §12 Q4).
/// No word is invented: `THROWAWAY` is the tag `address_suggestion.dart`
/// already draws, and `Wipe on exit` is `2a`'s and `6c`'s own copy. The tag
/// is all capitals, so the route beside it is too — which is why a throwaway
/// on Tor reads `TOR` here while a keep site's bare badge still reads `Tor`.
String topBarRouteLabel(ProxyMode mode, CaseKind caseKind) {
  final route = switch (mode) {
    ProxyMode.direct => '',
    ProxyMode.tor => 'Tor',
    ProxyMode.socks5 || ProxyMode.http => mode.name.toUpperCase(),
  };
  final tag = switch (caseKind) {
    CaseKind.keep => '',
    CaseKind.wipe => 'WIPE ON EXIT',
    CaseKind.throwaway => 'THROWAWAY',
  };
  if (tag.isEmpty) return route;
  if (route.isEmpty) return tag;
  return '$tag · ${route.toUpperCase()}';
}

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
/// onion address, which cannot go direct and would leak its name, and never
/// for a direct site, which has no tunnel to leave (a failed open).
bool canOpenWithoutTunnel(Site site) =>
    site.proxyMode != ProxyMode.direct && !isOnionHost(site.host);

/// Spec §5.4: on Tor, Block WebRTC is always on, and its switch inert.
bool webRtcLocked(ProxyMode mode) => mode == ProxyMode.tor;

import '../onion.dart';
import 'address_input.dart';
import 'proxy_route.dart';
import 'search_engine.dart';
import 'site.dart';

/// Where a typed address or search opens (spec §4.3).
sealed class Destination {
  const Destination();

  Uri get url;
}

/// Loads in place, in the container it was typed in.
class ThisContainer extends Destination {
  const ThisContainer(this.url);

  @override
  final Uri url;
}

/// Opens [site]'s own container — pushed over this one — at [url].
class SavedSiteContainer extends Destination {
  const SavedSiteContainer(this.site, this.url);

  final Site site;

  @override
  final Uri url;
}

/// Opens a new throwaway container at [url], on the route it is given: the
/// route of the container it was typed in, or the vault's default route from
/// the dashboard. [mode], [proxyHost], [proxyPort] and its proxy login exactly
/// as they are (proxy-auth spec §4).
class Throwaway extends Destination {
  const Throwaway(this.url, this.mode, this.proxyHost, this.proxyPort,
      {this.proxyUser, this.proxyPassword, this.proxyLoginPerSite = false});

  @override
  final Uri url;
  final ProxyMode mode;
  final String? proxyHost;
  final int? proxyPort;
  final String? proxyUser;
  final String? proxyPassword;
  final bool proxyLoginPerSite;
}

/// Hosts compare lowercase with one leading `www.` removed. Subdomains stay
/// distinct: `mail.example.com` is not `example.com`.
String normalizeHost(String host) {
  final lower = host.toLowerCase();
  return lower.startsWith('www.') ? lower.substring(4) : lower;
}

/// [current] is the site this container was opened for, not the page it is
/// showing now. The dashboard has none (dashboard spec §5). [route] is what a
/// throwaway runs on: [current]'s own route when it is not given. [saved] is
/// every site in the open vault. A search becomes [engine]'s results address
/// first, then follows the same rules, so a suggestion's tag is always where
/// it really opens.
Destination resolveDestination({
  required AddressInput input,
  Site? current,
  ProxyRoute? route,
  required List<Site> saved,
  required SearchEngine engine,
}) {
  final url = switch (input) {
    AddressUrl(:final url) => url,
    AddressSearch(:final query) => engine.resultsFor(query),
    AddressEmpty() => throw ArgumentError.value(input, 'input', 'Nothing to open'),
  };
  return destinationFor(url, current: current, route: route, saved: saved);
}

/// §4.3's rules for an address already decided. With no [current] there is
/// no "this container": a saved site's host opens its own, anything else a
/// throwaway on [route].
Destination destinationFor(
  Uri url, {
  Site? current,
  ProxyRoute? route,
  required List<Site> saved,
}) {
  final via = route ?? (current == null ? null : ProxyRoute.of(current));
  if (via == null) {
    throw ArgumentError('A throwaway needs a route: give current or route');
  }
  final host = normalizeHost(url.host);
  if (current != null && host == normalizeHost(current.host)) return ThisContainer(url);

  final matches = [
    for (final site in saved)
      if (normalizeHost(site.host) == host) site,
  ];
  if (matches.isNotEmpty) {
    matches.sort((a, b) => _preference(a, b, current?.workspaceId));
    return SavedSiteContainer(matches.first, url);
  }

  // Built-in Tor spec §5.3: an onion address never goes direct. Typed on a
  // direct route it opens on Tor, whatever the opener's route.
  if (via.mode == ProxyMode.direct && isOnionHost(url.host)) {
    return Throwaway(url, ProxyMode.tor, null, null);
  }

  return Throwaway(url, via.mode, via.host, via.port,
      proxyUser: via.user,
      proxyPassword: via.password,
      proxyLoginPerSite: via.loginPerSite);
}

/// Sites in [workspaceId] first, when there is one, then the most recently
/// visited; never visited last.
int _preference(Site a, Site b, String? workspaceId) {
  final aHere = a.workspaceId == workspaceId;
  final bHere = b.workspaceId == workspaceId;
  if (aHere != bHere) return aHere ? -1 : 1;
  final at = a.lastVisitedAt;
  final bt = b.lastVisitedAt;
  if (at == null && bt == null) return 0;
  if (at == null) return 1;
  if (bt == null) return -1;
  return bt.compareTo(at);
}

import 'address_input.dart';
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

/// Opens a new throwaway container at [url], on the route of the container
/// it was typed in: [mode], [proxyHost], [proxyPort] and its proxy login
/// exactly as they are (proxy-auth spec §4).
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
/// showing now; [saved] is every site in the open vault. A search becomes
/// [engine]'s results address first, then follows the same rules, so a
/// suggestion's tag is always where it really opens.
Destination resolveDestination({
  required AddressInput input,
  required Site current,
  required List<Site> saved,
  required SearchEngine engine,
}) {
  final url = switch (input) {
    AddressUrl(:final url) => url,
    AddressSearch(:final query) => engine.resultsFor(query),
    AddressEmpty() => throw ArgumentError.value(input, 'input', 'Nothing to open'),
  };
  return destinationFor(url, current: current, saved: saved);
}

/// §4.3's rules for an address already decided.
Destination destinationFor(
  Uri url, {
  required Site current,
  required List<Site> saved,
}) {
  final host = normalizeHost(url.host);
  if (host == normalizeHost(current.host)) return ThisContainer(url);

  final matches = [
    for (final site in saved)
      if (normalizeHost(site.host) == host) site,
  ];
  if (matches.isNotEmpty) {
    matches.sort((a, b) => _preference(a, b, current.workspaceId));
    return SavedSiteContainer(matches.first, url);
  }

  return Throwaway(url, current.proxyMode, current.proxyHost, current.proxyPort,
      proxyUser: current.proxyUser,
      proxyPassword: current.proxyPassword,
      proxyLoginPerSite: current.proxyLoginPerSite);
}

/// Sites in [workspaceId] first, then the most recently visited; never
/// visited last.
int _preference(Site a, Site b, String workspaceId) {
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

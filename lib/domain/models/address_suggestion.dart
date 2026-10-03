import '../site_search.dart';
import 'address_input.dart';
import 'destination.dart';
import 'proxy_route.dart';
import 'search_engine.dart';
import 'site.dart';
import 'workspace.dart';

enum SuggestionKind { savedSite, address, search }

/// One row under the address field (spec §4.4, §6.2), already reduced to
/// strings. [tag] says where the row opens before it is tapped.
class AddressSuggestion {
  const AddressSuggestion({
    required this.kind,
    required this.primary,
    required this.secondary,
    required this.tag,
    required this.destination,
    this.monogram,
  });

  final SuggestionKind kind;
  final String primary;

  /// Shown in mono under [primary].
  final String secondary;
  final String tag;
  final Destination destination;

  /// Set for a saved site only; the other rows draw an icon.
  final String? monogram;
}

const maxSavedSuggestions = 5;

/// Spec §7's destination tags. The route part follows the existing rule
/// that there is no DIRECT label.
String destinationTag(Destination destination) => switch (destination) {
      ThisContainer() => 'THIS CONTAINER',
      SavedSiteContainer() => 'ITS OWN CONTAINER',
      Throwaway(mode: ProxyMode.direct) => 'THROWAWAY',
      Throwaway(:final mode) => 'THROWAWAY · ${mode.name.toUpperCase()}',
    };

/// In order: up to [maxSavedSuggestions] saved sites matching [text] (each
/// opening at its own saved address), the address row when [text] parses as
/// an address, and the search row whenever [text] is not empty. Reads only
/// what it is given (the open vault's sites) and fetches nothing. [current]
/// and [route] are `destinationFor`'s: the dashboard gives a route and no
/// opener.
List<AddressSuggestion> suggestionsFor({
  required String text,
  Site? current,
  ProxyRoute? route,
  required List<Site> saved,
  required List<Workspace> workspaces,
  required SearchEngine engine,
}) {
  final input = parseAddressInput(text);
  if (input is AddressEmpty) return const [];
  final typed = text.trim();
  final workspaceNames = {for (final w in workspaces) w.id: w.name};
  final rows = <AddressSuggestion>[];

  for (final site in sitesMatching(saved, typed).take(maxSavedSuggestions)) {
    final url = Uri.tryParse(site.url);
    if (url == null) continue;
    final destination =
        site.id == current?.id ? ThisContainer(url) : SavedSiteContainer(site, url);
    final workspace = workspaceNames[site.workspaceId];
    rows.add(AddressSuggestion(
      kind: SuggestionKind.savedSite,
      primary: site.name,
      secondary: workspace == null ? site.host : '${site.host} · $workspace',
      tag: destinationTag(destination),
      destination: destination,
      monogram: site.monogram,
    ));
  }

  if (input is AddressUrl) {
    final destination =
        destinationFor(input.url, current: current, route: route, saved: saved);
    rows.add(AddressSuggestion(
      kind: SuggestionKind.address,
      primary: typed,
      secondary: 'not saved',
      tag: destinationTag(destination),
      destination: destination,
    ));
  }

  final search = destinationFor(engine.resultsFor(typed),
      current: current, route: route, saved: saved);
  rows.add(AddressSuggestion(
    kind: SuggestionKind.search,
    primary: 'Search ${engine.label} for “$typed”',
    secondary: engine.host,
    tag: destinationTag(search),
    destination: search,
  ));
  return rows;
}

/// What the keyboard's action opens (browser-chrome spec §6.2): the address
/// row if there is one, otherwise the search row. Null with nothing typed.
/// The container's address bar and the dashboard's field both use it.
AddressSuggestion? submittedSuggestion(List<AddressSuggestion> rows) {
  AddressSuggestion? search;
  for (final row in rows) {
    if (row.kind == SuggestionKind.address) return row;
    if (row.kind == SuggestionKind.search) search ??= row;
  }
  return search;
}

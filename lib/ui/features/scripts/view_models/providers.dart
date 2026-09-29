import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/repositories/filter_list_repository_sqlite.dart';
import '../../../../data/repositories/script_repository_sqlite.dart';
import '../../../../domain/models/filter_list.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/user_script.dart';
import '../../../../domain/repositories/filter_list_repository.dart';
import '../../../../domain/repositories/script_repository.dart';
import '../../dashboard/view_models/providers.dart'
    show databaseProvider, siteRepositoryProvider;

final filterListRepositoryProvider = Provider<FilterListRepository>(
  (ref) => SqliteFilterListRepository(ref.watch(databaseProvider)),
);

final scriptRepositoryProvider = Provider<ScriptRepository>(
  (ref) => SqliteScriptRepository(ref.watch(databaseProvider)),
);

/// Everything spec `10d` shows, read from the open vault.
class ScriptsView {
  const ScriptsView({
    required this.filterLists,
    required this.scripts,
    required this.sites,
  });

  final List<FilterList> filterLists;
  final List<UserScript> scripts;

  /// Every site in the open vault, in dashboard order: what a script can be
  /// applied to, and where its site ids get their names.
  final List<Site> sites;

  Map<String, String> get siteNamesById => {for (final site in sites) site.id: site.name};
}

final scriptsViewProvider = FutureProvider<ScriptsView>((ref) async {
  final sites = await ref.watch(siteRepositoryProvider).all();
  return ScriptsView(
    filterLists: await ref.watch(filterListRepositoryProvider).all(),
    scripts: await ref.watch(scriptRepositoryProvider).all(),
    sites: sites,
  );
});

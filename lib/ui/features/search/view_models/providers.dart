import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/site.dart';
import '../../dashboard/view_models/providers.dart'
    show siteRepositoryProvider, workspacesProvider, openSiteIdsProvider;
import 'search_view.dart';

final allSitesProvider = FutureProvider<List<Site>>(
  (ref) => ref.watch(siteRepositoryProvider).all(),
);

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = Provider<AsyncValue<List<SearchResultEntry>>>((ref) {
  final sitesAsync = ref.watch(allSitesProvider);
  final workspacesAsync = ref.watch(workspacesProvider);
  final query = ref.watch(searchQueryProvider);
  final openIds = ref.watch(openSiteIdsProvider);

  return sitesAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (sites) => workspacesAsync.when(
      loading: () => const AsyncValue.loading(),
      error: AsyncValue.error,
      data: (workspaces) => AsyncValue.data(searchResults(
        sites: sites,
        workspaces: workspaces,
        openSiteIds: openIds,
        query: query,
      )),
    ),
  );
});

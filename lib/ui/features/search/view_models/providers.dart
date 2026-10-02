import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/site.dart';
import '../../dashboard/view_models/providers.dart'
    show dashboardProvider, siteRepositoryProvider, workspacesProvider, openSiteIdsProvider;
import 'search_view.dart';

/// Every site in the open vault: what search and the address bar match
/// against. A copy, read once and kept, so [sitesChanged] must follow every
/// write to a site row.
final allSitesProvider = FutureProvider<List<Site>>(
  (ref) => ref.watch(siteRepositoryProvider).all(),
);

/// Called after any site row is added, changed, wiped or removed: the
/// dashboard and [allSitesProvider] read the vault again.
void sitesChanged(WidgetRef ref) {
  ref.invalidate(allSitesProvider);
  ref.invalidate(dashboardProvider);
}

/// [sitesChanged] for a caller that can outlive its widget: the container
/// host, which a close removes while the wipe is still writing the row. Keep
/// the two in step.
void sitesChangedIn(ProviderContainer container) {
  container.invalidate(allSitesProvider);
  container.invalidate(dashboardProvider);
}

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

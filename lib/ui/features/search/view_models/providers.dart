import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/site.dart';
import '../../dashboard/view_models/providers.dart'
    show dashboardProvider, siteRepositoryProvider;
import '../../settings/view_models/providers.dart' show decoySiteCountProvider;

/// Every site in the open vault: what the container's address bar and the
/// dashboard's search field match against. A copy, read once and kept, so
/// [sitesChanged] must follow every write to a site row.
final allSitesProvider = FutureProvider<List<Site>>(
  (ref) => ref.watch(siteRepositoryProvider).all(),
);

/// Called after any site row is added, changed, wiped or removed: the
/// dashboard, [allSitesProvider] and Settings' "Sites shown in decoy" count
/// read the vault again.
void sitesChanged(WidgetRef ref) {
  ref.invalidate(allSitesProvider);
  ref.invalidate(dashboardProvider);
  ref.invalidate(decoySiteCountProvider);
}

/// [sitesChanged] for a caller that can outlive its widget: the container
/// host, which a close removes while the wipe is still writing the row. Keep
/// the two in step.
void sitesChangedIn(ProviderContainer container) {
  container.invalidate(allSitesProvider);
  container.invalidate(dashboardProvider);
  container.invalidate(decoySiteCountProvider);
}

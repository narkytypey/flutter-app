import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/services/workspace_storage_service.dart';
import '../../container/view_models/providers.dart' show containerEngineProvider;
import '../../dashboard/view_models/providers.dart'
    show
        activeWorkspaceIdProvider,
        siteRepositoryProvider,
        workspaceRepositoryProvider,
        workspacesProvider;
import '../../search/view_models/providers.dart' show allSitesProvider;
import '../../settings/view_models/providers.dart' show decoySiteCountProvider;
import '../views/workspaces_screen.dart';
import 'workspace_actions.dart';

/// No real byte count exists yet — see Plan 5's Known gaps. Until one does,
/// every workspace reads as storing nothing.
final workspaceStorageServiceProvider =
    Provider<WorkspaceStorageService>((ref) => FakeWorkspaceStorageService());

final workspaceActionsProvider = Provider<WorkspaceActions>((ref) => WorkspaceActions(
      workspaces: ref.watch(workspaceRepositoryProvider),
      sites: ref.watch(siteRepositoryProvider),
      engine: ref.watch(containerEngineProvider),
      storage: ref.watch(workspaceStorageServiceProvider),
    ));

final workspaceListItemsProvider = FutureProvider<List<WorkspaceListItem>>((ref) async {
  await ref.watch(workspacesProvider.future);
  return ref.watch(workspaceActionsProvider).listItems();
});

/// After any workspace change: everything that lists workspaces or counts
/// their sites reads again. A deleted active workspace falls back to the
/// first one.
void workspacesChanged(WidgetRef ref, {String? deletedId}) {
  if (deletedId != null && ref.read(activeWorkspaceIdProvider) == deletedId) {
    ref.read(activeWorkspaceIdProvider.notifier).state = null;
  }
  ref.invalidate(workspacesProvider);
  ref.invalidate(allSitesProvider);
  ref.invalidate(decoySiteCountProvider);
}

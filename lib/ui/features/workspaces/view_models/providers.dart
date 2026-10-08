import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show ensureWorkspace;
import '../../container/view_models/providers.dart' show containerEngineProvider;
import '../../dashboard/view_models/providers.dart'
    show
        activeWorkspaceIdProvider,
        databaseProvider,
        siteRepositoryProvider,
        workspaceRepositoryProvider,
        workspacesProvider;
import '../../search/view_models/providers.dart' show allSitesProvider;
import '../../settings/view_models/providers.dart' show decoySiteCountProvider;
import '../views/workspaces_screen.dart';
import 'workspace_actions.dart';

/// No real byte count exists yet — see Plan 5's Known gaps. Until one does,
/// every workspace reads as storing nothing.

final workspaceActionsProvider = Provider<WorkspaceActions>((ref) {
  final database = ref.watch(databaseProvider);
  return WorkspaceActions(
    workspaces: ref.watch(workspaceRepositoryProvider),
    sites: ref.watch(siteRepositoryProvider),
    engine: ref.watch(containerEngineProvider),
    ensureOneWorkspace: () => ensureWorkspace(database),
  );
});

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

/// [workspacesChanged] for a caller that can outlive its widget (a delete
/// that closes live containers first). Keep the two in step.
void workspacesChangedIn(ProviderContainer container, {String? deletedId}) {
  if (deletedId != null && container.read(activeWorkspaceIdProvider) == deletedId) {
    container.read(activeWorkspaceIdProvider.notifier).state = null;
  }
  container.invalidate(workspacesProvider);
  container.invalidate(allSitesProvider);
  container.invalidate(decoySiteCountProvider);
}

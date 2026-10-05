import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/workspace.dart';
import '../../dashboard/view_models/providers.dart' show siteRepositoryProvider, workspacesProvider;
import '../view_models/providers.dart';
import 'delete_workspace_sheet.dart';
import 'workspace_form_screen.dart';
import 'workspaces_screen.dart';

/// Spec `10a`–`10c` against the open vault. Reached from Settings' MANAGE
/// section.
class WorkspacesRoute extends ConsumerWidget {
  const WorkspacesRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(workspaceListItemsProvider);
    return WorkspacesScreen(
      items: items.value ?? const [],
      onOpen: (id) => editWorkspace(context, ref, id),
      onDelete: (id) => _delete(context, ref, id),
      onNewWorkspace: () => createWorkspace(context, ref),
      onBack: () => Navigator.pop(context),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String id) async {
    // The delete closes live WebViews first, which can outlast this route:
    // `ref` would be disposed by then, the container is not.
    final scope = ProviderScope.containerOf(context, listen: false);
    final workspace = await _workspaceById(ref, id);
    if (workspace == null) return;
    final sites = await scope.read(siteRepositoryProvider).inWorkspace(id);
    final bytes = await scope.read(workspaceStorageServiceProvider).bytesFor(id);
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: DeleteWorkspaceSheet(
          workspaceName: workspace.name,
          sitesRemoved: sites.length,
          storageBytesWiped: bytes,
          onCancel: () => Navigator.pop(sheetContext),
          onDelete: () async {
            Navigator.pop(sheetContext);
            await scope.read(workspaceActionsProvider).delete(workspace);
            workspacesChangedIn(scope, deletedId: workspace.id);
          },
        ),
      ),
    );
  }
}

Future<Workspace?> _workspaceById(WidgetRef ref, String id) async {
  for (final workspace in await ref.read(workspacesProvider.future)) {
    if (workspace.id == id) return workspace;
  }
  return null;
}

/// `10b` for a new workspace: Settings ▸ Workspaces' "+ New workspace", and
/// the dashboard's `+` chip (dashboard spec §4.2).
void createWorkspace(BuildContext context, WidgetRef ref) {
  Navigator.push(context, MaterialPageRoute(
    builder: (formContext) => WorkspaceFormScreen(
      title: 'New workspace',
      initialName: '',
      initialMarkerIndex: 0,
      initialStorageRule: StorageRule.keep,
      initialRequirePin: false,
      initialShowInDecoy: false,
      onSave: (result) async {
        await ref.read(workspaceActionsProvider).create(result);
        workspacesChanged(ref);
        if (formContext.mounted) Navigator.pop(formContext);
      },
      onClose: () => Navigator.pop(context),
    ),
  ));
}

/// `10b` for workspace [id]: a tap on its row in Settings ▸ Workspaces, or a
/// long-press on its dashboard chip (dashboard spec §4.2). The spec draws only
/// the create form. Editing reuses it, titled with the workspace's own name
/// rather than copy the spec never wrote.
Future<void> editWorkspace(BuildContext context, WidgetRef ref, String id) async {
  final workspace = await _workspaceById(ref, id);
  if (workspace == null || !context.mounted) return;
  Navigator.push(context, MaterialPageRoute(
    builder: (formContext) => WorkspaceFormScreen(
      title: workspace.name,
      initialName: workspace.name,
      initialMarkerIndex: workspace.markerIndex,
      initialStorageRule: workspace.storageRule,
      initialRequirePin: workspace.requirePin,
      initialShowInDecoy: workspace.showInDecoy,
      onSave: (result) async {
        await ref.read(workspaceActionsProvider).update(workspace, result);
        workspacesChanged(ref);
        if (formContext.mounted) Navigator.pop(formContext);
      },
      onClose: () => Navigator.pop(context),
    ),
  ));
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/site_wipe.dart';
import '../../add_site/views/add_site_screen.dart';
import '../../container/view_models/open_containers.dart' show openContainersProvider;
import '../../container/view_models/providers.dart' show containerEngineProvider;
import '../../search/view_models/providers.dart' show sitesChangedIn;
import '../view_models/providers.dart';
import 'site_row_menu.dart';
import 'wipe_site_sheet.dart';

/// A dashboard row's long-press: the row menu (`7b`) for [siteId], and what
/// its actions do.
Future<void> showSiteRowMenu(BuildContext context, WidgetRef ref, String siteId) async {
  // The slow awaits below (closing a live WebView) can outlast the tab: `ref`
  // would be disposed by then, the container is not.
  final scope = ProviderScope.containerOf(context, listen: false);
  final site = await scope.read(siteRepositoryProvider).byId(siteId);
  if (site == null || !context.mounted) return;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SiteRowMenu(
      monogram: site.monogram,
      name: site.name,
      subtitle: site.url,
      ephemeralWorkspaceName: 'Ephemeral',
      duplicateTargetName: 'Work',
      onCancel: () => Navigator.pop(context),
      onAction: (action) async {
        Navigator.pop(context);
        if (action == SiteRowAction.editSettings) {
          final workspaces = await scope.read(workspacesProvider.future);
          if (!context.mounted) return;
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => AddSiteScreen(
              initial: site,
              workspaces: workspaces,
              // A change of route or cookie policy closes the site's open
              // container (tabs spec §5.7). From here it is in the
              // background, so it stays closed until it is next opened.
              onSave: (updated) async {
                await scope.read(siteRepositoryProvider).upsert(updated);
                await scope.read(openContainersProvider.notifier).siteSaved(updated);
                sitesChangedIn(scope);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
            ),
          ));
        } else if (action == SiteRowAction.removeSite) {
          // Closed and wiped first: deleting the row alone left the site's
          // profile and downloads on disk. The close reaches the registry
          // through the sessions event.
          await removeSavedSite(
            engine: scope.read(containerEngineProvider),
            sites: scope.read(siteRepositoryProvider),
            site: site,
          );
          sitesChangedIn(scope);
        } else if (action == SiteRowAction.wipeData) {
          // Asked first (user's ruling, 2026-09-30). The site stays, under a
          // fresh profile (wipeSavedSite).
          if (!await confirmWipeSite(context) || !context.mounted) return;
          await wipeSavedSite(
            engine: scope.read(containerEngineProvider),
            sites: scope.read(siteRepositoryProvider),
            site: site,
          );
          sitesChangedIn(scope);
        }
        // openEphemeral, duplicate, requirePin: Known Gap, see Plan 6's
        // Known gaps. None has a target workspace or PIN flow built yet.
      },
    ),
  );
}

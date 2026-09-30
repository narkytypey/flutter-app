import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../domain/models/filter_list.dart';
import '../../../../domain/models/site.dart';
import '../../../../domain/models/user_script.dart';
import '../view_models/providers.dart';
import 'script_editor_screen.dart';
import 'script_site_picker.dart';
import 'scripts_and_filters_screen.dart';

/// Spec `10d`/`10e` against the open vault. Reached from Settings' MANAGE
/// section.
///
/// A site reads its enabled lists and scripts when it is next opened (Plan
/// 11), not while it is live. The lists are bundled and update with the app:
/// 10d's "Update over the proxy" block is left out (user's ruling,
/// 2026-09-30), since the app makes no network requests of its own.
class ScriptsRoute extends ConsumerWidget {
  const ScriptsRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(scriptsViewProvider).value;
    final filterLists = view?.filterLists ?? const <FilterList>[];
    final scripts = view?.scripts ?? const <UserScript>[];
    final now = DateTime.now();

    return ScriptsAndFiltersScreen(
      filterLists: filterLists,
      now: now,
      scripts: scripts,
      siteNamesById: view?.siteNamesById ?? const {},
      onToggleFilterList: (id) async {
        final list = filterLists.firstWhere((l) => l.id == id);
        await ref.read(filterListRepositoryProvider).setEnabled(id, !list.enabled);
        ref.invalidate(scriptsViewProvider);
      },
      onToggleScript: (id) async {
        final script = scripts.firstWhere((s) => s.id == id);
        await ref.read(scriptRepositoryProvider).upsert(script.copyWith(enabled: !script.enabled));
        ref.invalidate(scriptsViewProvider);
      },
      onOpenScript: (id) => _openEditor(
        context,
        scripts.firstWhere((s) => s.id == id),
        view?.sites ?? const [],
      ),
      onNewScript: () => _openEditor(
        context,
        UserScript(
          id: newProfileId(),
          name: 'New script',
          kind: ScriptKind.css,
          code: '',
          runAtDocumentStart: false,
          enabled: true,
          appliedSiteIds: const [],
        ),
        view?.sites ?? const [],
      ),
      onBack: () => Navigator.pop(context),
    );
  }

  void _openEditor(BuildContext context, UserScript script, List<Site> sites) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ScriptEditorRoute(script: script, sites: sites),
    ));
  }
}

/// Holds the sites a script runs on while it is being edited: adding or
/// removing one takes effect on Save, together with the code, and not before.
class _ScriptEditorRoute extends ConsumerStatefulWidget {
  const _ScriptEditorRoute({required this.script, required this.sites});

  final UserScript script;
  final List<Site> sites;

  @override
  ConsumerState<_ScriptEditorRoute> createState() => _ScriptEditorRouteState();
}

class _ScriptEditorRouteState extends ConsumerState<_ScriptEditorRoute> {
  late final _siteIds = [...widget.script.appliedSiteIds];
  late final _siteNames = {for (final site in widget.sites) site.id: site.name};

  /// Opens on the vault's navigator like every other sheet, never the root
  /// one, so a lock still tears it down.
  Future<void> _pickSite(List<Site> offered) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ScriptSitePicker(
        sites: offered,
        onPick: (id) => Navigator.pop(sheetContext, id),
      ),
    );
    if (picked != null && mounted) setState(() => _siteIds.add(picked));
  }

  @override
  Widget build(BuildContext context) {
    final offered = [
      for (final site in widget.sites)
        if (!_siteIds.contains(site.id)) site,
    ];
    return ScriptEditorScreen(
      title: widget.script.name,
      initialKind: widget.script.kind,
      initialCode: widget.script.code,
      initialRunAtDocumentStart: widget.script.runAtDocumentStart,
      appliedSites: [
        for (final id in _siteIds)
          if (_siteNames[id] case final name?) ScriptSiteChip(id: id, name: name),
      ],
      onSave: (result) async {
        await ref.read(scriptRepositoryProvider).upsert(widget.script.copyWith(
              kind: result.kind,
              code: result.code,
              runAtDocumentStart: result.runAtDocumentStart,
              appliedSiteIds: _siteIds,
            ));
        ref.invalidate(scriptsViewProvider);
        if (context.mounted) Navigator.pop(context);
      },
      onRemoveSite: (id) => setState(() => _siteIds.remove(id)),
      onAddSite: offered.isEmpty ? null : () => _pickSite(offered),
      onClose: () => Navigator.pop(context),
    );
  }
}

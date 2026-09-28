import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/services/app_database.dart' show newProfileId;
import '../../../../domain/models/filter_list.dart';
import '../../../../domain/models/user_script.dart';
import '../view_models/providers.dart';
import 'script_editor_screen.dart';
import 'scripts_and_filters_screen.dart';

/// Spec `10d` pairs "updated 2 days ago" with "Next check in 5 days" — a
/// weekly cadence, counted from the most recently updated list.
const _checkIntervalDays = 7;

int nextFilterCheckInDays(List<FilterList> lists, DateTime now) {
  if (lists.isEmpty) return _checkIntervalDays;
  final newest = lists.map((l) => l.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
  final remaining = _checkIntervalDays - now.difference(newest).inDays;
  return remaining < 0 ? 0 : remaining;
}

/// Spec `10d`/`10e` against the open vault. Reached from Settings' MANAGE
/// section.
///
/// Nothing here changes what a page loads yet: the native filter engine does
/// not read a list's enabled bit, and no script is injected into a WebView —
/// see Plan 5's Known gaps. "Update now" fetches nothing, since the app makes
/// no network requests of its own.
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
      nextUpdateInDays: nextFilterCheckInDays(filterLists, now),
      scripts: scripts,
      siteNamesById: view?.siteNamesById ?? const {},
      onToggleFilterList: (id) async {
        final list = filterLists.firstWhere((l) => l.id == id);
        await ref.read(filterListRepositoryProvider).setEnabled(id, !list.enabled);
        ref.invalidate(scriptsViewProvider);
      },
      onUpdateFilterListsNow: () {},
      onToggleScript: (id) async {
        final script = scripts.firstWhere((s) => s.id == id);
        await ref.read(scriptRepositoryProvider).upsert(script.copyWith(enabled: !script.enabled));
        ref.invalidate(scriptsViewProvider);
      },
      onOpenScript: (id) => _openEditor(
        context,
        scripts.firstWhere((s) => s.id == id),
        view?.siteNamesById ?? const {},
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
        view?.siteNamesById ?? const {},
      ),
      onBack: () => Navigator.pop(context),
    );
  }

  void _openEditor(BuildContext context, UserScript script, Map<String, String> siteNames) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ScriptEditorRoute(script: script, siteNamesById: siteNames),
    ));
  }
}

/// Holds the sites a script runs on while it is being edited: removing one
/// takes effect on Save, together with the code, and not before.
class _ScriptEditorRoute extends ConsumerStatefulWidget {
  const _ScriptEditorRoute({required this.script, required this.siteNamesById});

  final UserScript script;
  final Map<String, String> siteNamesById;

  @override
  ConsumerState<_ScriptEditorRoute> createState() => _ScriptEditorRouteState();
}

class _ScriptEditorRouteState extends ConsumerState<_ScriptEditorRoute> {
  late final _siteIds = [...widget.script.appliedSiteIds];

  @override
  Widget build(BuildContext context) {
    return ScriptEditorScreen(
      title: widget.script.name,
      initialKind: widget.script.kind,
      initialCode: widget.script.code,
      initialRunAtDocumentStart: widget.script.runAtDocumentStart,
      appliedSites: [
        for (final id in _siteIds)
          if (widget.siteNamesById[id] case final name?) ScriptSiteChip(id: id, name: name),
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
      // The site picker is not built — see Plan 5's Known gaps.
      onAddSite: () {},
      onClose: () => Navigator.pop(context),
    );
  }
}

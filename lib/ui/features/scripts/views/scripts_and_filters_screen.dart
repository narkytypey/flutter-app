import 'package:flutter/material.dart';

import '../../../../domain/models/filter_list.dart';
import '../../../../domain/models/user_script.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import 'filter_list_section.dart';

/// The `MY SCRIPTS` row subtitle. Only `ScriptKind.js` rows in spec `10d`
/// show a "runs at ..." clause; the CSS rows never do.
String scriptSubtitle(UserScript script,
    {required Map<String, String> siteNamesById}) {
  final count = script.appliedSiteIds.length;
  final siteWord = count == 1 ? 'site' : 'sites';
  final base = 'Applied to $count $siteWord';
  if (script.kind != ScriptKind.js) return base;
  return script.runAtDocumentStart
      ? '$base · runs at start'
      : '$base · runs at load';
}

/// Spec `10d` — one library, reused across sites.
class ScriptsAndFiltersScreen extends StatelessWidget {
  const ScriptsAndFiltersScreen({
    super.key,
    required this.filterLists,
    required this.now,
    required this.nextUpdateInDays,
    required this.scripts,
    required this.siteNamesById,
    required this.onToggleFilterList,
    required this.onUpdateFilterListsNow,
    required this.onToggleScript,
    required this.onOpenScript,
    required this.onNewScript,
    required this.onBack,
  });

  final List<FilterList> filterLists;
  final DateTime now;
  final int nextUpdateInDays;
  final List<UserScript> scripts;
  final Map<String, String> siteNamesById;
  final ValueChanged<String> onToggleFilterList;
  final VoidCallback onUpdateFilterListsNow;
  final ValueChanged<String> onToggleScript;
  final void Function(String id) onOpenScript;
  final VoidCallback onNewScript;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: const Text('‹',
                        style: TextStyle(fontSize: 16, color: C.icon)),
                  ),
                  const SizedBox(width: 10),
                  Text('Scripts and filters', style: T.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  FilterListSection(
                    lists: filterLists,
                    now: now,
                    nextUpdateInDays: nextUpdateInDays,
                    onToggle: onToggleFilterList,
                    onUpdateNow: onUpdateFilterListsNow,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 4),
                    child: Text('MY SCRIPTS',
                        style: ui(
                            size: 10.5,
                            weight: 600,
                            letterSpacing: 1.05,
                            color: C.textFaint)),
                  ),
                  for (final script in scripts)
                    GestureDetector(
                      onTap: () => onOpenScript(script.id),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: C.line06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: C.raised,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(script.kind.badge,
                                  style: ui(
                                      size: 12, color: script.kind.badgeColor)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(script.name,
                                      style:
                                          ui(size: 14, color: C.textPrimary)),
                                  const SizedBox(height: 3),
                                  Text(
                                    scriptSubtitle(script,
                                        siteNamesById: siteNamesById),
                                    style: ui(size: 11.5, color: C.textFaint),
                                  ),
                                ],
                              ),
                            ),
                            AppToggle(
                              value: script.enabled,
                              onChanged: (_) => onToggleScript(script.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: GestureDetector(
                      onTap: onNewScript,
                      child: Row(
                        children: [
                          Text('+',
                              style: ui(size: 17, weight: 300, color: C.jade)),
                          const SizedBox(width: 11),
                          Text('New script',
                              style:
                                  ui(size: 14.5, weight: 500, color: C.jade)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

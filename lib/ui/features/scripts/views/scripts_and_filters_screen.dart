import 'package:flutter/material.dart';

import '../../../../domain/models/filter_list.dart';
import '../../../../domain/models/user_script.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/group.dart';
import '../../../core/widgets/icon_tap.dart';
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
    required this.scripts,
    required this.siteNamesById,
    required this.onToggleFilterList,
    required this.onToggleScript,
    required this.onOpenScript,
    required this.onNewScript,
    required this.onBack,
  });

  final List<FilterList> filterLists;
  final DateTime now;
  final List<UserScript> scripts;
  final Map<String, String> siteNamesById;
  final ValueChanged<String> onToggleFilterList;
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
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                children: [
                  IconTap(
                    glyph: AppGlyph.back,
                    label: 'Back',
                    onTap: onBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Scripts and filters',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.screenTitle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(S.s4, S.s4, S.s4, S.s6),
                children: [
                  FilterListSection(
                    lists: filterLists,
                    now: now,
                    onToggle: onToggleFilterList,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, S.s6, 4, S.s2),
                    child: Text('MY SCRIPTS', style: T.sectionLabel),
                  ),
                  if (scripts.isNotEmpty)
                    Group(
                      padding: EdgeInsets.zero,
                      children: [
                        for (final script in scripts)
                          _ScriptRow(
                            script: script,
                            subtitle: scriptSubtitle(script,
                                siteNamesById: siteNamesById),
                            onTap: () => onOpenScript(script.id),
                            onToggle: () => onToggleScript(script.id),
                          ),
                      ],
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: S.s2),
                    child: GestureDetector(
                      // The whole row, not only its glyphs.
                      behavior: HitTestBehavior.opaque,
                      onTap: onNewScript,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Row(
                          children: [
                            const SizedBox(width: S.s4),
                            const AppIcon(AppGlyph.plus, size: 18, color: C.jade),
                            const SizedBox(width: S.s3),
                            Flexible(
                              child: Text('New script',
                                  style: T.label.copyWith(color: C.jade)),
                            ),
                          ],
                        ),
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

/// `10d`'s badge colour for a script kind (restyle v2 §2.8): the view's
/// choice, not the domain model's. CSS in the code tone, JS in amber.
Color scriptBadgeColor(ScriptKind kind) => switch (kind) {
      ScriptKind.css => C.code,
      ScriptKind.js => C.warning,
    };

class _ScriptRow extends StatelessWidget {
  const _ScriptRow({
    required this.script,
    required this.subtitle,
    required this.onTap,
    required this.onToggle,
  });

  final UserScript script;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: S.s4, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: C.button,
                borderRadius: BorderRadius.circular(R.monogram),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(script.kind.badge,
                    style: T.barBadge
                        .copyWith(color: scriptBadgeColor(script.kind))),
              ),
            ),
            const SizedBox(width: S.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(script.name, style: T.body),
                  const SizedBox(height: 2),
                  Text(subtitle, style: T.sub),
                ],
              ),
            ),
            const SizedBox(width: S.s3),
            AppToggle(
              value: script.enabled,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}

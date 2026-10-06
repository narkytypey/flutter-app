import 'package:flutter/material.dart';

import '../../../../domain/models/search_engine.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/sheet.dart';

/// Spec §6.7: the sheet the `Search engine` row opens. The current engine is
/// checked the way the workspace menu checks its selected row.
class SearchEnginePicker extends StatelessWidget {
  const SearchEnginePicker({super.key, required this.current, required this.onPick});

  final SearchEngine current;
  final ValueChanged<SearchEngine> onPick;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Search engine', style: T.sheetTitle),
        ),
        for (final engine in SearchEngine.values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(engine),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: C.lineSoft)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(engine.label, style: T.body),
                  ),
                  if (engine == current) const AppIcon(AppGlyph.check, size: 20, color: C.textPrimary),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

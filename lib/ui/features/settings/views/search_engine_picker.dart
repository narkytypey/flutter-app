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
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Text('Search engine', style: T.sheetTitle),
        ),
        for (final engine in SearchEngine.values)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(engine),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: C.line05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(engine.label, style: ui(size: 14.5, color: C.textPrimary)),
                  ),
                  if (engine == current) const AppIcon(AppGlyph.check, size: 15, color: C.jade),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

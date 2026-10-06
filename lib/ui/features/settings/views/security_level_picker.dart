import 'package:flutter/material.dart';

import '../../../../domain/models/security_level.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/sheet.dart';

/// Privacy-controls spec §2.3, built like `SearchEnginePicker`, with the
/// current row checked (in text-1: a check is a position, never jade).
///
/// [SecurityLevelPicker.vault] is Settings' picker for the vault default: the
/// three levels. [SecurityLevelPicker.site] is the ☰ and `6c` picker for one
/// site: a `Default` row first, which reports null, so the site follows the
/// vault default from then on.
class SecurityLevelPicker extends StatelessWidget {
  const SecurityLevelPicker.vault({
    super.key,
    required SecurityLevel this.current,
    required this.onPick,
  }) : vaultDefault = null;

  const SecurityLevelPicker.site({
    super.key,
    required this.current,
    required SecurityLevel this.vaultDefault,
    required this.onPick,
  });

  /// The level chosen now; null while a site follows the default.
  final SecurityLevel? current;

  /// Set for a site's picker only: shown on its `Default` row.
  final SecurityLevel? vaultDefault;

  final ValueChanged<SecurityLevel?> onPick;

  @override
  Widget build(BuildContext context) {
    final vaultDefault = this.vaultDefault;
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Text('Security level', style: T.sheetTitle),
        ),
        if (vaultDefault != null)
          _LevelRow(
            title: 'Default',
            line: '${vaultDefault.label} · set in Settings',
            checked: current == null,
            onTap: () => onPick(null),
          ),
        for (final level in SecurityLevel.values)
          _LevelRow(
            title: level.label,
            line: level.description,
            checked: current == level,
            onTap: () => onPick(level),
          ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.title,
    required this.line,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final String line;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: C.lineSoft)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: T.body),
                  const SizedBox(height: 2),
                  Text(line, style: T.sub),
                ],
              ),
            ),
            if (checked) ...[
              const SizedBox(width: 12),
              AppIcon(AppGlyph.check, size: 20, color: C.textPrimary),
            ],
          ],
        ),
      ),
    );
  }
}

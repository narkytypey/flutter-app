import 'package:flutter/material.dart';

import '../../../../domain/models/security_level.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/sheet.dart';

/// Privacy-controls spec §2.3, built like `SearchEnginePicker`, with the
/// current row checked in its jade.
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
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.line05)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ui(size: 14.5, color: C.textPrimary)),
                  const SizedBox(height: 3),
                  Text(line, style: ui(size: 12, color: C.textFaint)),
                ],
              ),
            ),
            if (checked) const Icon(Icons.check, size: 15, color: C.jade),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../domain/models/lock_state.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/sheet.dart';

/// The sheet the `Auto-lock` row opens (user's ruling, 2026-09-30): 1, 5 or
/// 15 minutes, built like `SearchEnginePicker`, the current one checked.
class AutoLockPicker extends StatelessWidget {
  const AutoLockPicker({super.key, required this.current, required this.onPick});

  final AutoLockPolicy current;
  final ValueChanged<AutoLockPolicy> onPick;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Text('Auto-lock', style: T.sheetTitle),
        ),
        for (final policy in AutoLockPolicy.choices)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(policy),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: C.line05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(policy.label, style: ui(size: 14.5, color: C.textPrimary)),
                  ),
                  if (policy == current) const Icon(Icons.check, size: 15, color: C.jade),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

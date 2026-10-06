import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Asks before "Wipe this site's data" (`7b`) destroys anything. The copy was
/// approved by the user on 2026-09-30; the canvas draws no confirmation for
/// this row. Built from the sheets it sits among: `7c`'s title, `7b`'s
/// destructive row and Cancel pill. No jade: wiping is destructive, not an
/// affirmative action.
class WipeSiteSheet extends StatelessWidget {
  const WipeSiteSheet({super.key, required this.onWipe, required this.onCancel});

  final VoidCallback onWipe;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        Text("Wipe this site's data?", style: T.sheetTitle),
        const SizedBox(height: S.s2),
        Text(
          'Its logins, storage and downloads are destroyed. The site stays in its workspace.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: S.s5),
        SheetGroup(children: [
          SheetRow(label: 'Wipe', labelColor: C.danger, onTap: onWipe),
        ]),
        const SizedBox(height: S.s3),
        PillButton(label: 'Cancel', onTap: onCancel),
      ],
    );
  }
}

/// Shows [WipeSiteSheet] and answers true only when Wipe is tapped; Cancel,
/// a tap outside and system back all answer false.
///
/// No `useRootNavigator`: the sheet goes on the nearest navigator, which
/// inside the open vault is `AppGate`'s own, so a lock or panic tears it down
/// with everything else (`6a5f013`).
Future<bool> confirmWipeSite(BuildContext context) async {
  final wipe = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => WipeSiteSheet(
      onWipe: () => Navigator.pop(sheetContext, true),
      onCancel: () => Navigator.pop(sheetContext, false),
    ),
  );
  return wipe ?? false;
}

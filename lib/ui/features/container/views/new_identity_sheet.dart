import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/pill_button.dart';
import '../../../core/widgets/sheet.dart';

/// Asks before the ☰ menu's "New identity" destroys anything (privacy-controls
/// spec §4.2). The copy was approved by the user on 2026-10-02 (that spec's
/// §5). Styled like `WipeSiteSheet`: a title, a muted body, one destructive
/// row and a Cancel pill. No jade: New identity is destructive, not an
/// affirmative action.
class NewIdentitySheet extends StatelessWidget {
  const NewIdentitySheet({super.key, required this.onNewIdentity, required this.onCancel});

  final VoidCallback onNewIdentity;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      children: [
        Text('New identity for this site?', style: T.sheetTitle),
        const SizedBox(height: 8),
        Text(
          'Its logins, storage and downloads are destroyed, and it starts over at its first page.',
          style: T.bodyMuted,
        ),
        const SizedBox(height: 18),
        SheetGroup(children: [
          SheetRow(label: 'New identity', labelColor: C.danger, onTap: onNewIdentity),
        ]),
        const SizedBox(height: 10),
        PillButton(label: 'Cancel', onTap: onCancel),
      ],
    );
  }
}

/// Shows [NewIdentitySheet] and answers true only when New identity is
/// tapped; Cancel, a tap outside and system back all answer false.
///
/// No `useRootNavigator`: the sheet goes on the nearest navigator, which
/// inside the open vault is `AppGate`'s own, so a lock or panic tears it down
/// with everything else (`6a5f013`).
Future<bool> confirmNewIdentity(BuildContext context) async {
  final answer = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => NewIdentitySheet(
      onNewIdentity: () => Navigator.pop(sheetContext, true),
      onCancel: () => Navigator.pop(sheetContext, false),
    ),
  );
  return answer ?? false;
}

import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import '../../../core/widgets/pill_button.dart';

/// Browser-chrome spec §5.3/§6.3: offered in a throwaway once its first load
/// has finished, directly above the bottom bar. Neutral throughout — jade
/// stays on the live dot; saving is not this screen's affirmative action.
///
/// The hairline below it is the bottom bar's own, not a second one.
class ThrowawaySaveBar extends StatelessWidget {
  const ThrowawaySaveBar({super.key, required this.onSave, required this.onDismiss});

  final VoidCallback onSave;

  /// Hides the bar for this throwaway.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: C.surface,
        border: Border(top: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text('Not saved · wiped when you close it', style: T.body),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: PillButton(
              label: 'Save as a site',
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              onTap: onSave,
            ),
          ),
          const SizedBox(width: 2),
          // Not in spec §7's list; the user's ruling of 2026-10-02.
          IconTap(
            key: const Key('save-bar-dismiss'),
            glyph: AppGlyph.close,
            label: 'Dismiss',
            onTap: onDismiss,
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

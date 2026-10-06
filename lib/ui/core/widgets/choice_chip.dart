import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';

/// A chip (restyle v2 §5): a 48 dp target around a 36 dp chip. Unselected:
/// a line outline. Selected: the raised fill, a 1.5 dp text-1 outline and a
/// leading check — selection never rests on a fill alone (WCAG 1.4.1).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.leading,
    this.semanticsLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Drawn before the label when not selected (a selected chip shows its
  /// check there instead).
  final Widget? leading;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final lead = selected
        ? const AppIcon(AppGlyph.check, size: 16, color: C.textPrimary)
        : leading;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              padding: EdgeInsets.only(left: lead == null ? 14 : 10, right: 14),
              decoration: BoxDecoration(
                color: selected ? C.button : null,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? C.textPrimary : C.line,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lead != null) ...[lead, const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ui(
                        size: 14,
                        weight: selected ? 600 : 500,
                        color: selected ? C.textPrimary : C.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

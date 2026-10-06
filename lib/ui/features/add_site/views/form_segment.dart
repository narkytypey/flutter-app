import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// One of `2a`'s segments (restyle v2 §5): a tab, a route mode, a user agent.
/// Selected: a 2 dp text-1 outline and a leading check, never jade and never
/// a fill alone. [outlined] draws an unselected choice's 1 dp line outline;
/// the form's tabs have none. The check's room is kept when unselected, so
/// choosing does not move the label.
class FormSegment extends StatelessWidget {
  const FormSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.outlined = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(R.input),
            border: selected
                ? Border.all(color: C.textPrimary, width: 2)
                : outlined
                    ? Border.all(color: C.line)
                    : null,
          ),
          // One line, shrunk to fit at a large text scale rather than broken
          // mid-word ("Networ / k").
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected)
                  AppIcon(AppGlyph.check, size: 16, color: C.textPrimary)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 4),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: ui(
                    size: 14,
                    weight: selected ? 600 : 500,
                    color: selected ? C.textPrimary : C.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

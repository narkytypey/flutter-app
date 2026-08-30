import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'hairline.dart';

/// The bottom-sheet chrome shared by specs `6a`, `6c`, `7b` and `7c`.
///
/// Spec values, identical in all four blocks: background `#141719`, a 1px top
/// border at 9% white, a 22px radius on the top corners only, and a soft
/// upward shadow so the sheet reads as lifted off the page behind it.
class BottomSheetSurface extends StatelessWidget {
  const BottomSheetSurface({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 20),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sheet-surface'),
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.09)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, -20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A rounded, bordered group of rows separated by hairlines.
///
/// Groups are how the design keeps destructive actions apart: spec `7b` puts
/// "Wipe this site's data" and "Remove site" in their own [SheetGroup] rather
/// than at the bottom of the first one. Never mix the two.
class SheetGroup extends StatelessWidget {
  const SheetGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Hairline(color: Colors.white.withValues(alpha: 0.05)));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

/// One tappable row inside a [SheetGroup]. Spec `7b`: 15px vertical padding,
/// 16px horizontal, `#15181B` fill, 14.5px label.
class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.label,
    required this.onTap,
    this.labelColor,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: C.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ui(size: 14.5, color: labelColor ?? C.textPrimary),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'hairline.dart';

/// The bottom-sheet chrome shared by specs `6a`, `6c`, `7b` and `7c`.
///
/// Restyle v2 §4: the sheet tone, a 1px top edge in the line tone, a 28px
/// radius on the top corners only, and one soft upward shadow — the only
/// shadow in the app.
class BottomSheetSurface extends StatelessWidget {
  const BottomSheetSurface({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 20),
    this.showHandle = false,
    this.scrolls = true,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  /// Spec `6c` draws a 36x4 handle above its header row; the other three
  /// sheets in this plan do not. Off by default so every existing call site
  /// is unaffected.
  final bool showHandle;

  /// The children scroll when they are taller than the sheet may be (a short
  /// phone, the keyboard up, a large text scale), instead of overflowing. A
  /// sheet that lays out its own scrolling region in a [Flexible] passes
  /// false.
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('sheet-surface'),
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: C.sheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(R.sheet)),
        border: Border(top: BorderSide(color: C.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 40,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHandle)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Container(
                  key: const Key('sheet-handle'),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: C.handle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          if (scrolls)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            )
          else
            ...children,
        ],
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
        rows.add(Hairline(color: C.lineSoft));
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(R.group),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(R.group),
          border: Border.all(color: C.line),
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

/// One tappable row inside a [SheetGroup]: min 56 dp, 16px horizontal, the
/// group tone, a row-title label (restyle v2 §4).
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
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: T.body.copyWith(color: labelColor ?? C.textPrimary),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

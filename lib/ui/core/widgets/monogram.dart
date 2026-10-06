import 'package:flutter/widgets.dart';

import '../tokens.dart';
import '../typography.dart';

/// The rounded two-letter square that stands in for a site. [open] switches it
/// between the live and idle treatments.
class Monogram extends StatelessWidget {
  const Monogram(
    this.text, {
    super.key,
    this.size = 36,
    this.radius = 10,
    this.fontSize = 14,
    this.open = true,
  });

  final String text;
  final double size;
  final double radius;
  final double fontSize;
  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: open ? C.monogramOpen : C.surface,
        borderRadius: BorderRadius.circular(radius),
        // An idle monogram sits on a group of the same tone; the outline
        // keeps its square.
        border: open ? null : Border.all(color: C.line),
      ),
      // Grows with the text scale until it fills the square, then stops:
      // at a large scale two letters would otherwise be clipped to one.
      child: Padding(
        padding: EdgeInsets.all(size * 0.12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: ui(
              size: fontSize,
              weight: 600,
              color: open ? C.monogramText : C.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

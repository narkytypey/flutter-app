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
        color: open ? C.monogramOpen : C.raised,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        text,
        style: ui(
          size: fontSize,
          weight: 600,
          color: open ? C.monogramText : C.textMuted,
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';

/// A tap target drawn as one [AppIcon] — every button in the container's
/// chrome. [label] names it for screen readers, from spec §7's list; it is
/// null only where the spec gives none. A null [onTap] dims the icon and
/// makes it inert: back and forward with no history that way (§3.3).
class IconTap extends StatelessWidget {
  const IconTap({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
    this.size = 48,
    this.iconSize = 20,
    Color? color,
    this.background,
    this.radius,
  // A private field cannot be a named formal; [color] resolves it.
  // ignore: prefer_initializing_formals
  }) : _color = color;

  final AppGlyph glyph;
  final String? label;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? _color;

  /// The colour passed, or [C.icon] in the active palette.
  Color get color => _color ?? C.icon;
  final Color? background;

  /// Corner radius; null draws a circle, a 48 dp round target (restyle v2 §5).
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final corner = radius;
    final target = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: corner == null
            ? BoxDecoration(color: background, shape: BoxShape.circle)
            : BoxDecoration(color: background, borderRadius: BorderRadius.circular(corner)),
        child: AppIcon(glyph, size: iconSize, color: onTap == null ? C.textFaint : color),
      ),
    );
    final name = label;
    if (name == null) return target;
    return Semantics(label: name, button: true, enabled: onTap != null, child: target);
  }
}

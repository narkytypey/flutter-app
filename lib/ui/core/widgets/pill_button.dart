import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

enum PillTone {
  /// Jade fill, dark label. At most one per screen.
  primary,

  /// The `#1C2124` fill used for everything else.
  neutral,

  /// A 28%-alpha danger border with danger text. Danger is never a fill.
  dangerOutline,
}

/// The rounded action button. Heights and radii differ per screen, so both are
/// parameters; the spec value is always passed explicitly at the call site.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.tone = PillTone.neutral,
    this.height = 48,
    this.radius,
  });

  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final PillTone tone;
  final double height;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? height / 2);
    final enabled = onTap != null;

    final (Color? fill, Border? border, Color labelColor, int weight) = switch (tone) {
      PillTone.primary => (C.jade, null, C.bg, 600),
      PillTone.neutral => (C.button, null, enabled ? C.textSecondary : C.textDim, 500),
      PillTone.dangerOutline => (
          null,
          Border.all(color: C.danger.withValues(alpha: 0.28)),
          C.danger,
          500,
        ),
    };

    return Material(
      color: fill ?? const Color(0x00000000),
      borderRadius: r,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: Container(
          height: height,
          decoration: BoxDecoration(borderRadius: r, border: border),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: ui(size: 14.5, weight: weight, color: labelColor)),
              if (sublabel != null) ...[
                const SizedBox(height: 1),
                Text(sublabel!, style: ui(size: 10.5, color: C.dangerMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

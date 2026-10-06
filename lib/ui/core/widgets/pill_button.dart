import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

enum PillTone {
  /// Jade fill, dark label. At most one per screen.
  primary,

  /// The raised fill used for everything else.
  neutral,

  /// A 1.5 dp danger outline with danger text. Danger is never a fill.
  dangerOutline,

  /// Danger text alone, no fill or outline: a risky choice that must not
  /// carry a button's weight (`8b`'s "Open without the tunnel"; restyle v2
  /// §5, §8).
  dangerText,
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
    this.height = 52,
    this.radius,
    this.padding,
  });

  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final PillTone tone;
  final double height;
  final double? radius;

  /// Around the label, inside the pill. Null, the default, changes nothing:
  /// a full-width pill is as wide as its parent makes it. A pill in a row
  /// sizes to its label and needs this to breathe.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // Never under the 48 dp target, whatever a call site passes (v2 §5).
    final minHeight = height < 48 ? 48.0 : height;
    final r = BorderRadius.circular(radius ?? minHeight / 2);
    final enabled = onTap != null;

    final (Color? fill, Border? border, Color labelColor, int weight) = switch (tone) {
      PillTone.primary => (C.jade, null, C.onJade, 600),
      PillTone.neutral => (C.button, null, enabled ? C.textPrimary : C.textMuted, 500),
      PillTone.dangerOutline => (null, Border.all(color: C.danger, width: 1.5), C.danger, 500),
      PillTone.dangerText => (null, null, C.danger, 600),
    };

    return Material(
      color: fill ?? const Color(0x00000000),
      borderRadius: r,
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: Container(
          // A minimum, not a fixed height: a large text scale grows the pill
          // instead of overflowing its label and sublabel.
          constraints: BoxConstraints(minHeight: minHeight),
          padding: padding,
          decoration: BoxDecoration(borderRadius: r, border: border),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  textAlign: TextAlign.center,
                  style: T.label.copyWith(
                      color: labelColor, fontWeight: weight == 600 ? FontWeight.w600 : FontWeight.w500)),
              if (sublabel != null) ...[
                const SizedBox(height: 2),
                Text(sublabel!,
                    textAlign: TextAlign.center,
                    style: T.sub),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

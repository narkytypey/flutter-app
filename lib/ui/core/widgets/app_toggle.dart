import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../tokens.dart';

const _inertOpacity = 0.4;

/// The switch used throughout the settings screens (restyle v2 §5): 52x32.
/// Off is an unfilled track with an edge outline and a small grey knob; on is
/// a light track with a dark knob carrying a check. **Not jade**: jade is
/// live state, never a position. With no [onChanged] it is inert, and drawn
/// dimmed so it does not read as something to tap.
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Opacity(
        opacity: onChanged == null ? _inertOpacity : 1,
        child: Container(
          width: 52,
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: value ? 4 : 6),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? C.textPrimary : null,
            borderRadius: BorderRadius.circular(16),
            border: value ? null : Border.all(color: C.edge, width: 2),
          ),
          child: value
              ? Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: C.bg, shape: BoxShape.circle),
                  child: const AppIcon(AppGlyph.check, size: 14, color: C.textPrimary),
                )
              : Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(color: C.knobOff, shape: BoxShape.circle),
                ),
        ),
      ),
    );
  }
}

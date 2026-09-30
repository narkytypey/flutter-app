import 'package:flutter/widgets.dart';

import '../tokens.dart';

const _inertOpacity = 0.4;

/// The 44x26 switch used throughout the settings screens. With no
/// [onChanged] it is inert, and drawn dimmed so it does not read as
/// something to tap.
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
          width: 44,
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value ? C.jade : C.trackOff,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: value ? C.bg : C.knobOff,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

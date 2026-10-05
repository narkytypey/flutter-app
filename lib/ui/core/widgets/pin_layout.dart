import 'package:flutter/widgets.dart';

import 'centered_scroll.dart';

/// The frame every PIN screen shares: its [message] (headline, dots, notes)
/// above its [keypad] in portrait, as the canvas draws it, and beside it in
/// landscape, where the keypad takes the height and would push the dots out
/// of view (user's ruling 2026-10-05).
///
/// [top] sits above the message (setup's step bar); [bottom] under the
/// keypad (a Continue button, the fingerprint prompt). The message scrolls
/// when it does not fit, and in landscape so does the keypad's column.
class PinLayout extends StatelessWidget {
  const PinLayout({
    super.key,
    this.top,
    required this.message,
    required this.keypad,
    this.bottom,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final Widget? top;
  final Widget message;
  final Widget keypad;
  final Widget? bottom;
  final CrossAxisAlignment crossAxisAlignment;

  /// The keypad's own maximum width.
  static const _keypadWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (!landscape) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          if (top != null) top!,
          Expanded(child: CenteredScroll(child: message)),
          keypad,
          if (bottom != null) bottom!,
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              if (top != null) top!,
              Expanded(child: CenteredScroll(child: message)),
            ],
          ),
        ),
        const SizedBox(width: 28),
        SizedBox(
          width: _keypadWidth,
          child: CenteredScroll(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: crossAxisAlignment,
              children: [keypad, if (bottom != null) bottom!],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/widgets.dart';

import '../../../core/tokens.dart';

/// Browser-chrome spec §6.1: 2px under the top bar's hairline, drawn only
/// while the page loads, filled to its progress. `C.textMuted`, not jade:
/// jade is for live state and the one affirmative action.
///
/// Always 2px tall, drawn or not, and laid over the top edge of the page by
/// `ContainerScreen` rather than above it, so a load starting or ending
/// never moves or resizes the page.
class LoadLine extends StatelessWidget {
  const LoadLine({super.key, required this.loading, required this.progress});

  final bool loading;

  /// 0–100.
  final int progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2,
      child: loading
          ? FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0, 100) / 100,
              child: const ColoredBox(key: Key('load-line'), color: C.textMuted),
            )
          : null,
    );
  }
}

import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The three-segment bar at the top of setup (spec `4a`, `4b`, `5a`). Done
/// and current segments are text-1, the rest the edge tone: a position, so
/// not jade (restyle v2 §5).
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, this.of = 3});

  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        children: [
          for (var i = 0; i < of; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < step ? C.textPrimary : C.edge,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

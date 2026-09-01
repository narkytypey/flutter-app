import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The three-segment bar at the top of setup (spec `4a`, `4b`, `5a`).
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
                height: 3,
                decoration: BoxDecoration(
                  color: i < step ? C.jade : C.trackOff,
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

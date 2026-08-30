import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/dashed_box.dart';

/// Spec `5b`: one sentence and one action. The copy is fixed by the design.
class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DashedBox(size: 40, radius: 12),
            const SizedBox(height: 16),
            Text('Nothing here yet',
                style: ui(size: 15, weight: 500, color: C.textTertiary)),
            const SizedBox(height: 16),
            Text(
              'Sites you open in this workspace leave nothing behind when you '
              'close the app.',
              textAlign: TextAlign.center,
              style: ui(size: 13, color: C.textFaint, height: 1.65),
            ),
          ],
        ),
      ),
    );
  }
}

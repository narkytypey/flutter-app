import 'package:flutter/material.dart';

import '../../../core/typography.dart';
import '../../../core/widgets/dashed_box.dart';

/// Spec `5b`: one sentence and one action. The copy is fixed by the design.
/// The canvas draws it for a wipe-on-exit workspace, the only kind its
/// sentence is true of; a workspace that keeps storage shows only the title
/// (user's ruling 2026-10-05).
class EmptyWorkspace extends StatelessWidget {
  const EmptyWorkspace({super.key, required this.wipesOnExit});

  final bool wipesOnExit;

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
            Text('Nothing here yet', textAlign: TextAlign.center, style: T.body),
            if (wipesOnExit) ...[
              const SizedBox(height: 16),
              Text(
                'Sites you open in this workspace leave nothing behind when you '
                'close the app.',
                textAlign: TextAlign.center,
                style: T.bodyMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

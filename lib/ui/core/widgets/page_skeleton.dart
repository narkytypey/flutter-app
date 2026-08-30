import 'package:flutter/material.dart';

import '../tokens.dart';

/// The dimmed placeholder the spec draws behind every in-page overlay.
///
/// Plan 3 replaces this with the live WebView. It exists so this plan's
/// screens can be built and tested with no WebView present, and so the
/// overlays are reviewed against the same background the spec cards show.
/// Spec `6a` uses opacity .28, spec `7b` uses .3.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.opacity = 0.28});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    Widget bar({required double height, double? widthFactor}) {
      final box = Container(
        height: height,
        decoration: BoxDecoration(
          color: C.skeleton,
          borderRadius: BorderRadius.circular(4),
        ),
      );
      return widthFactor == null
          ? box
          : FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: box,
            );
    }

    return Opacity(
      opacity: opacity,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            bar(height: 14, widthFactor: 0.45),
            const SizedBox(height: 14),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: C.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 14),
            bar(height: 10),
            const SizedBox(height: 14),
            bar(height: 10, widthFactor: 0.7),
          ],
        ),
      ),
    );
  }
}

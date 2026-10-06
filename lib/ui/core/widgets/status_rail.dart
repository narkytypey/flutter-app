import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A site's light (restyle v2 §5): a 10 dp dot. Jade fill while the site is
/// live — one of the few places jade is allowed; amber while it is still
/// opening; otherwise a hollow edge ring, or nothing where [showIdle] is
/// false (the dashboard's rows say idle by the missing light).
class StatusRail extends StatelessWidget {
  const StatusRail({super.key, required this.live, this.opening = false, this.showIdle = true});

  final bool live;
  final bool opening;
  final bool showIdle;

  @override
  Widget build(BuildContext context) {
    final lit = live || opening;
    if (!lit && !showIdle) return const SizedBox(width: 10, height: 10);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: live ? C.jade : (opening ? C.warning : null),
        border: lit ? null : Border.all(color: C.edge, width: 2),
      ),
    );
  }
}

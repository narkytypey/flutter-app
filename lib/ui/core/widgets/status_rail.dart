import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The 3px rail on the left of a session row. Jade means the session is live;
/// this is one of the few places jade is allowed.
class StatusRail extends StatelessWidget {
  const StatusRail({super.key, required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      decoration: BoxDecoration(
        color: live ? C.jade : C.line09,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

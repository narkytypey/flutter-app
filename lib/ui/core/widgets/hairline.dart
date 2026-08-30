import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A 1 logical-pixel divider. The design uses hairlines instead of cards, so
/// this is the main structural element of the whole set.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color = C.line06});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

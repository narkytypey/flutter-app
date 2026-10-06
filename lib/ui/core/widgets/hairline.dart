import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// A 1 logical-pixel divider. The design uses hairlines instead of cards, so
/// this is the main structural element of the whole set.
class Hairline extends StatelessWidget {
  // A private field cannot be a named formal; [color] resolves it.
  // ignore: prefer_initializing_formals
  const Hairline({super.key, Color? color}) : _color = color;

  final Color? _color;

  /// The colour passed, or [C.lineSoft] in the active palette.
  Color get color => _color ?? C.lineSoft;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

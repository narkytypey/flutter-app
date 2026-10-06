import 'package:flutter/widgets.dart';

import '../tokens.dart';
import 'hairline.dart';

/// Rows that belong together (restyle v2 §4): the group tone, a 1px line
/// outline, an 18px radius, and soft hairlines between the rows. Hairlines
/// are structure inside a group; the group is what holds a screen together.
class Group extends StatelessWidget {
  const Group({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.dividers = true,
  });

  final List<Widget> children;

  /// Around each row, inside the group.
  final EdgeInsetsGeometry padding;

  /// Draws a soft hairline between rows. Off for rows that draw their own.
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(Padding(padding: padding, child: children[i]));
      if (dividers && i != children.length - 1) rows.add(const Hairline());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(R.group),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(R.group),
          border: Border.all(color: C.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}

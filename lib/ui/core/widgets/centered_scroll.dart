import 'package:flutter/widgets.dart';

/// Lays [child] out as tall as the space it is given (so a centred column
/// stays centred), and scrolls it when it is taller than that: a short
/// phone, a large text scale or a long message, instead of overflowing.
///
/// [child] must not hold a `Spacer`, `Expanded` or other flex child that
/// needs a bounded height.
class CenteredScroll extends StatelessWidget {
  const CenteredScroll({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: (constraints.maxWidth - padding.horizontal).clamp(0, double.infinity),
            minHeight: (constraints.maxHeight - padding.vertical).clamp(0, double.infinity),
          ),
          child: child,
        ),
      ),
    );
  }
}

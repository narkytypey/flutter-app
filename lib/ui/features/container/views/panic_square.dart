import 'package:flutter/widgets.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/widgets/icon_tap.dart';

/// `2b`'s panic button, drawn with the `panic` line icon: restyle v2 §8, a
/// 48 dp target with a 1.5 dp danger outline — danger is an outline, never a
/// fill. On every bar the container shows — the top bar, the address field,
/// the find bar — so panic is never more than one tap away and never behind
/// a menu.
class PanicSquare extends StatelessWidget {
  const PanicSquare({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(R.input),
        border: Border.all(color: C.danger, width: 1.5),
      ),
      child: IconTap(
        glyph: AppGlyph.panic,
        label: 'Panic',
        onTap: onTap,
        iconSize: 22,
        color: C.danger,
        radius: R.input,
      ),
    );
  }
}

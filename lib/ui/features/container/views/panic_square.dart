import 'package:flutter/widgets.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/widgets/icon_tap.dart';

/// `2b`'s 32px panic square, drawn with the `panic` line icon. On every bar
/// the container shows — the top bar, the address field, the find bar — so
/// panic is never more than one tap away and never behind a menu.
class PanicSquare extends StatelessWidget {
  const PanicSquare({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconTap(
      glyph: AppGlyph.panic,
      label: 'Panic',
      onTap: onTap,
      size: 32,
      iconSize: 16,
      color: C.danger,
      background: C.danger.withValues(alpha: 0.14),
      radius: 9,
    );
  }
}

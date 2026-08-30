import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// The 3x4 keypad. Layout is fixed by the spec: 1-9, a blank cell, 0, and
/// backspace.
class PinKeypad extends StatelessWidget {
  const PinKeypad({super.key, required this.onKey});

  final void Function(String key) onKey;

  static const _keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '', '0', '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 280 / 3 / 64,
          children: [
            for (final key in _keys)
              Material(
                color: key.isEmpty ? const Color(0x00000000) : C.surface,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: key.isEmpty ? null : () => onKey(key),
                  child: Center(
                    child: Text(key, style: ui(size: 22, color: C.textSecondary)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

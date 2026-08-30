import 'package:flutter/widgets.dart';

import '../tokens.dart';

/// The six-dot PIN indicator. In the error state (spec `4c`) every dot is
/// cleared and the borders go red — the count is never partially preserved,
/// because that would tell the user how far a wrong PIN got.
class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 6,
    this.error = false,
  });

  final int filled;
  final int length;
  final bool error;

  static const _errorBorder = Color(0xFF4A3634);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: !error && i < filled ? C.textPrimary : null,
              border: Border.all(
                color: error
                    ? _errorBorder
                    : (i < filled ? C.textPrimary : C.pinEmpty),
                width: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

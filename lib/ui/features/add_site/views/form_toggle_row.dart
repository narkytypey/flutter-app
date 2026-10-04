import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// A form line with a title, an optional subtitle and the add-site form's own
/// switch: `2a`'s Network tab and the Default route screen.
class FormToggleRow extends StatelessWidget {
  const FormToggleRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.switchKey,
  });

  final String title;
  final String? subtitle;
  final bool value;
  /// Null draws the switch inert at 40%, as `AppToggle` does: built-in Tor's
  /// Block WebRTC (spec §5.4).
  final ValueChanged<bool>? onChanged;

  /// On the switch itself, for tests: `proxy-enabled`, `proxy-login-per-site`.
  final Key? switchKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ui(size: 14, color: C.textPrimary)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: ui(size: 11, color: C.textFaint)),
              ],
            ],
          ),
        ),
        GestureDetector(
          key: switchKey,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Opacity(
            opacity: onChanged == null ? 0.4 : 1,
            child: Container(
              width: 44,
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? C.jade : C.trackOff,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? C.bg : C.knobOff,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

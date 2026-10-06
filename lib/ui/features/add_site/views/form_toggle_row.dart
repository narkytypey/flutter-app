import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';

/// A form line with a title, an optional subtitle and a v2 [AppToggle]:
/// `2a`'s tabs and the Default route screen.
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
    // A tap anywhere on the row toggles it, not only on the switch; an inert
    // switch's row does nothing.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: T.body.copyWith(color: C.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: T.sub),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AppToggle(key: switchKey, value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

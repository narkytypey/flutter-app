import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// A settings line: title, optional subtitle, and either a control or a value
/// on the right. Hairline underneath, never a card.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line06)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: T.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: ui(size: 11, color: C.textFaint)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (value != null)
                Text(value!, style: ui(size: 12.5, color: C.textMuted)),
              if (trailing == null && value == null && onTap != null)
                Text('›', style: ui(size: 14, color: C.textFaint)),
            ],
          ),
        ),
      ),
    );
  }
}

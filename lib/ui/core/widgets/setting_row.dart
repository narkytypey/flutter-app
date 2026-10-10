import 'package:flutter/material.dart';

import '../icons.dart';
import '../tokens.dart';
import '../typography.dart';

/// A settings line: title, optional subtitle, and either a control or a value
/// on the right. Hairline underneath; restyle v2 sets it in a group's rows
/// (min 56 dp).
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.onTap,
    this.monoValue = false,
    this.picker = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? value;
  final VoidCallback? onTap;

  /// [value] in mono: an address, as everything technical (spec §8).
  final bool monoValue;

  /// The row opens a picker: [value] shows in a pill ending in a down
  /// chevron, instead of plain text (user's ruling 2026-10-06, re.png).
  final bool picker;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.lineSoft)),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: T.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: T.sub),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (value != null) ...[
                const SizedBox(width: 12),
                // Tight, so the end-aligned value sits at the row's right edge
                // (the canvas's space-between); loose, it began mid-row.
                Flexible(
                  fit: FlexFit.tight,
                  child: picker
                      ? Align(alignment: Alignment.centerRight, child: _pill())
                      : Text(value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: _valueStyle),
                ),
              ],
              if (trailing == null && value == null && onTap != null)
                AppIcon(AppGlyph.forward, size: 18, color: C.chevron),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _valueStyle => monoValue ? T.value : T.sub;

  /// The picker's value on the raised neutral tone, never jade, which stays
  /// for live state.
  Widget _pill() {
    return Container(
      key: const Key('setting-pill'),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: C.button,
        borderRadius: BorderRadius.circular(R.input),
        border: Border.all(color: C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(value!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _valueStyle.copyWith(color: C.textSecondary)),
          ),
          const SizedBox(width: 6),
          AppIcon(AppGlyph.chevronDown, size: 14, color: C.chevron),
        ],
      ),
    );
  }
}

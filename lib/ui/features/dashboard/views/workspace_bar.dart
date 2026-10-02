import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';

/// The top bar: workspace name with a dropdown caret on the left, and either
/// the session counts or the workspace's storage rule on the right.
class WorkspaceBar extends StatelessWidget {
  const WorkspaceBar({
    super.key,
    required this.name,
    required this.trailing,
    required this.trailingIsBadge,
    required this.onTap,
    required this.onOverflow,
  });

  final String name;
  final String trailing;
  final bool trailingIsBadge;
  final VoidCallback onTap;
  final VoidCallback onOverflow;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: T.appBarTitle),
                    const SizedBox(width: 7),
                    const AppIcon(AppGlyph.chevronDown, size: 14, color: C.chevron),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trailing,
                    style: trailingIsBadge ? T.barBadge : T.barSummary,
                  ),
                  const SizedBox(width: 10),
                  IconTap(
                    glyph: AppGlyph.more,
                    label: 'Settings',
                    onTap: onOverflow,
                    size: 24,
                    iconSize: 18,
                    color: C.chevron,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Hairline(),
      ],
    );
  }
}

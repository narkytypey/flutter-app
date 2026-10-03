import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/sheet.dart';

/// Browser-chrome spec §6.4: the ☰ sheet, in `2c`/`6c`'s sheet style. Four
/// quick actions on this page, then screens that are also reachable from the
/// dashboard, here as shortcuts. Project 3's two rows, `Security level` and
/// `New identity`, come first among the rows (privacy-controls spec §4.1).
///
/// Pure: whoever shows it closes it before acting on a tap, so a screen it
/// opens lands above the container rather than above the sheet.
class BrowserMenuSheet extends StatelessWidget {
  const BrowserMenuSheet({
    super.key,
    required this.monogram,
    required this.name,
    required this.subtitle,
    required this.blockedToday,
    required this.securityLevelMeta,
    required this.onSecurityLevel,
    required this.onNewIdentity,
    required this.onReload,
    required this.onFind,
    required this.onReader,
    required this.onCopyLink,
    required this.onToday,
    required this.onScripts,
    required this.onWorkspaces,
    required this.onSettings,
    required this.onAllSites,
  });

  final String monogram;
  final String name;

  /// `host · Workspace` in mono; a throwaway's host alone.
  final String subtitle;

  /// Today's total, shown as `<n> BLOCKED` on the `Today` row.
  final int blockedToday;

  /// The site's effective level in mono on the `Security level` row:
  /// `STANDARD`, `SAFER` or `SAFEST` (privacy-controls spec §4.1, §5).
  final String securityLevelMeta;

  /// The `Security level` row (privacy-controls spec §4.1).
  final VoidCallback onSecurityLevel;

  /// The `New identity` row (privacy-controls spec §4.1).
  final VoidCallback onNewIdentity;

  final VoidCallback onReload;
  final VoidCallback onFind;
  final VoidCallback onReader;
  final VoidCallback onCopyLink;
  final VoidCallback onToday;
  final VoidCallback onScripts;
  final VoidCallback onWorkspaces;
  final VoidCallback onSettings;
  final VoidCallback onAllSites;

  @override
  Widget build(BuildContext context) {
    return BottomSheetSurface(
      showHandle: true,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.line06)),
          ),
          child: Row(
            children: [
              Monogram(monogram),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ui(size: 15, weight: 600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mono(size: 10.5, color: C.textFaint)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: C.line06)),
          ),
          child: Row(
            children: [
              Expanded(child: _Tile(glyph: AppGlyph.reload, label: 'Reload', onTap: onReload)),
              Expanded(child: _Tile(glyph: AppGlyph.find, label: 'Find', onTap: onFind)),
              Expanded(child: _Tile(glyph: AppGlyph.reader, label: 'Reader', onTap: onReader)),
              Expanded(child: _Tile(glyph: AppGlyph.link, label: 'Copy link', onTap: onCopyLink)),
            ],
          ),
        ),
        _MenuRow(label: 'Security level', meta: securityLevelMeta, onTap: onSecurityLevel),
        _MenuRow(label: 'New identity', onTap: onNewIdentity),
        _MenuRow(label: 'Today', meta: '$blockedToday BLOCKED', onTap: onToday),
        _MenuRow(label: 'Scripts and filters', onTap: onScripts),
        _MenuRow(label: 'Workspaces', onTap: onWorkspaces),
        _MenuRow(label: 'Settings', onTap: onSettings),
        _MenuRow(label: 'All sites', onTap: onAllSites, divider: false),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.glyph, required this.label, required this.onTap});

  final AppGlyph glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.button,
              borderRadius: BorderRadius.circular(13),
            ),
            child: AppIcon(glyph),
          ),
          const SizedBox(height: 7),
          Text(label,
              textAlign: TextAlign.center,
              style: ui(size: 11, color: C.textTertiary)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap, this.meta, this.divider = true});

  final String label;
  final VoidCallback onTap;

  /// Mono text in place of the chevron: `Today`'s blocked count, or the
  /// security level.
  final String? meta;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final meta = this.meta;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: divider
            ? const BoxDecoration(border: Border(bottom: BorderSide(color: C.line05)))
            : null,
        child: Row(
          children: [
            Expanded(child: Text(label, style: ui(size: 14, color: C.textPrimary))),
            if (meta != null)
              Text(meta, style: mono(size: 10.5, color: C.textFaint))
            else
              const AppIcon(AppGlyph.forward, size: 14, color: C.textFaint),
          ],
        ),
      ),
    );
  }
}

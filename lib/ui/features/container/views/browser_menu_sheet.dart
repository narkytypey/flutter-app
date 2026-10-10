import 'package:flutter/material.dart';

import '../../../core/host_text.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';
import '../../../core/widgets/sheet.dart';

/// Browser-chrome spec §6.4: the ☰ sheet, in `2c`/`6c`'s sheet style. Six
/// quick actions on this page — Back and Forward first, since the bottom bar
/// is gone (user's ruling, 2026-10-10) — then screens that are also reachable from the
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
    required this.onBack,
    required this.onForward,
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

  /// Null when the page cannot go back: the tile is dimmed and inert.
  final VoidCallback? onBack;

  /// Null when the page cannot go forward: the tile is dimmed and inert.
  final VoidCallback? onForward;

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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.lineSoft)),
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
                        style: T.appBarTitle),
                    const SizedBox(height: 2),
                    // Restyle v2 §1.6: the host is never cut short.
                    Text.rich(hostSpan(subtitle), style: T.metaValue),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Row(
            children: [
              Expanded(child: _Tile(glyph: AppGlyph.back, label: 'Back', onTap: onBack)),
              Expanded(child: _Tile(glyph: AppGlyph.forward, label: 'Forward', onTap: onForward)),
              Expanded(child: _Tile(glyph: AppGlyph.reload, label: 'Reload', onTap: onReload)),
              Expanded(child: _Tile(glyph: AppGlyph.find, label: 'Find', onTap: onFind)),
              Expanded(child: _Tile(glyph: AppGlyph.reader, label: 'Reader', onTap: onReader)),
              Expanded(child: _Tile(glyph: AppGlyph.link, label: 'Copy link', onTap: onCopyLink)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SheetGroup(children: [
            _menuRow('Security level', onSecurityLevel, meta: securityLevelMeta),
            _menuRow('New identity', onNewIdentity),
            _menuRow('Today', onToday, meta: '$blockedToday BLOCKED'),
            _menuRow('Scripts and filters', onScripts),
            _menuRow('Workspaces', onWorkspaces),
            _menuRow('Settings', onSettings),
            _menuRow('All sites', onAllSites),
          ]),
        ),
      ],
    );
  }
}

/// A ☰ row (restyle v2 §4): a [SheetRow] ending in its mono meta — `Today`'s
/// blocked count, or the security level — or else a chevron.
Widget _menuRow(String label, VoidCallback onTap, {String? meta}) => SheetRow(
      label: label,
      onTap: onTap,
      trailing: meta != null
          ? Padding(padding: const EdgeInsets.only(left: 12), child: Text(meta, style: T.value))
          : AppIcon(AppGlyph.forward, size: 18, color: C.chevron),
    );

class _Tile extends StatelessWidget {
  const _Tile({required this.glyph, required this.label, required this.onTap});

  final AppGlyph glyph;
  final String label;

  /// Null draws the tile dimmed and inert.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.button,
              borderRadius: BorderRadius.circular(R.input),
            ),
            child: AppIcon(glyph, size: 22, color: enabled ? null : C.textFaint),
          ),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: T.meta.copyWith(color: enabled ? C.textMuted : C.textFaint)),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../domain/models/address_suggestion.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/monogram.dart';

/// Browser-chrome spec §6.2: under the address field while typing, over the
/// page and the bottom bar. Only what the open vault already holds — nothing
/// is fetched while typing — and every row's tag says where it opens before
/// it is tapped. A tap anywhere but a row leaves editing.
class AddressSuggestions extends StatelessWidget {
  const AddressSuggestions({
    super.key,
    required this.suggestions,
    required this.onPick,
    required this.onDismiss,
  });

  /// In `suggestionsFor`'s order, which is the order the sections show in.
  final List<AddressSuggestion> suggestions;
  final ValueChanged<AddressSuggestion> onPick;
  final VoidCallback onDismiss;

  static String _section(SuggestionKind kind) => switch (kind) {
        SuggestionKind.savedSite => 'SAVED SITES',
        SuggestionKind.address => 'ADDRESS',
        SuggestionKind.search => 'SEARCH',
      };

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    SuggestionKind? section;
    for (final suggestion in suggestions) {
      if (suggestion.kind != section) {
        section = suggestion.kind;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Text(_section(suggestion.kind), style: T.sectionLabel),
        ));
      }
      children.add(_SuggestionRow(suggestion, onTap: () => onPick(suggestion)));
    }
    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Text('Nothing is fetched while you type.',
          style: mono(size: 10, color: C.textDim)),
    ));

    return ColoredBox(
      color: C.bg,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: ListView(padding: EdgeInsets.zero, children: children),
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow(this.suggestion, {required this.onTap});

  final AddressSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final monogram = suggestion.monogram;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: C.line06)),
        ),
        child: Row(
          children: [
            if (monogram != null)
              Monogram(monogram, size: 32, radius: 9, fontSize: 12)
            else
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.button,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: AppIcon(
                  suggestion.kind == SuggestionKind.address ? AppGlyph.globe : AppGlyph.search,
                  size: 15,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    suggestion.primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ui(size: 13.5, color: C.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    suggestion.secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mono(size: 10, color: C.textFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Narrow, so a long tag wraps onto a second line (`THROWAWAY` /
            // `· SOCKS5`) instead of squeezing the row.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: Text(
                suggestion.tag,
                textAlign: TextAlign.right,
                style: mono(size: 9.5, color: C.textMuted, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

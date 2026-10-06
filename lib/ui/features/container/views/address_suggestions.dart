import 'package:flutter/material.dart';

import '../../../../domain/models/address_suggestion.dart';
import '../../../core/host_text.dart';
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
      child: Text('Nothing is fetched while you type.', style: T.metaValue),
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
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.lineSoft)),
        ),
        child: Row(
          children: [
            if (monogram != null)
              Monogram(monogram, size: 40, radius: R.monogram, fontSize: 15)
            else
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: C.button,
                  borderRadius: BorderRadius.circular(R.monogram),
                ),
                child: AppIcon(
                  suggestion.kind == SuggestionKind.address ? AppGlyph.globe : AppGlyph.search,
                  size: 20,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Restyle v2 §1.6: an address, and the host under every
                  // row, wrap after their dots and are never cut short.
                  if (suggestion.kind == SuggestionKind.address)
                    Text.rich(hostSpan(suggestion.primary), style: T.rowTitle)
                  else
                    Text(suggestion.primary, style: T.rowTitle),
                  const SizedBox(height: 2),
                  Text.rich(hostSpan(suggestion.secondary), style: T.metaValue),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Narrow, so a long tag wraps onto a second line (`THROWAWAY` /
            // `· SOCKS5`) instead of squeezing the row.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                suggestion.tag,
                textAlign: TextAlign.right,
                style: T.barBadge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

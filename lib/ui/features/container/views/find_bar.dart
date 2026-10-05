import 'package:flutter/material.dart';

import '../../../../domain/models/find_result.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.5: stands in for the top bar while finding in the
/// page. Panic keeps its place on the right, as on every bar.
class FindBar extends StatelessWidget {
  const FindBar({
    super.key,
    required this.controller,
    required this.result,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    required this.onPanic,
  });

  final TextEditingController controller;

  /// The page's count for what is typed, or null until it arrives.
  final FindResult? result;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final VoidCallback onPanic;

  /// `<active>/<total>`, counting from one (WebView counts from zero), or
  /// `No matches`.
  static String? _count(FindResult? found) {
    if (found == null) return null;
    if (found.matchCount == 0) return 'No matches';
    return '${found.activeMatch + 1}/${found.matchCount}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line07)),
      ),
      // Follows the field itself, so the count and the arrows are right on
      // the keystroke, before anything above rebuilds.
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final found = value.text.isEmpty ? null : result;
          final count = _count(found);
          final canStep = (found?.matchCount ?? 0) > 0;
          return Row(
            children: [
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: C.raised,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: C.line16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          onChanged: onChanged,
                          cursorColor: C.textPrimary,
                          style: ui(size: 13, color: C.textPrimary),
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          enableIMEPersonalizedLearning: false,
                          decoration: InputDecoration.collapsed(
                            hintText: 'Find in page',
                            hintStyle: ui(size: 13, color: C.textFaint),
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(count,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mono(size: 10.5, color: C.textMuted)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconTap(
                glyph: AppGlyph.chevronUp,
                label: 'Previous match',
                onTap: canStep ? onPrevious : null,
                size: 32,
                iconSize: 18,
              ),
              IconTap(
                glyph: AppGlyph.chevronDown,
                label: 'Next match',
                onTap: canStep ? onNext : null,
                size: 32,
                iconSize: 18,
              ),
              IconTap(
                glyph: AppGlyph.close,
                label: 'Close find',
                onTap: onClose,
                size: 32,
                iconSize: 16,
              ),
              const SizedBox(width: 4),
              PanicSquare(onTap: onPanic),
            ],
          );
        },
      ),
    );
  }
}

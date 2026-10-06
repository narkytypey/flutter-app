import 'package:flutter/material.dart';

import '../../../../domain/models/find_result.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'address_edit_bar.dart' show InputFrame;
import 'panic_square.dart';

/// Browser-chrome spec §6.5: stands in for the top bar while finding in the
/// page. Panic keeps its place on the right, as on every bar. Restyle v2:
/// the field is an [InputFrame], the arrows and × 48 dp targets.
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
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(bottom: BorderSide(color: C.line)),
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
                child: InputFrame(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          onChanged: onChanged,
                          cursorColor: C.textPrimary,
                          style: T.body,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          enableIMEPersonalizedLearning: false,
                          decoration: InputDecoration.collapsed(
                            hintText: 'Find in page',
                            hintStyle: T.body.copyWith(color: C.textFaint),
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(count,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: T.value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconTap(
                glyph: AppGlyph.chevronUp,
                label: 'Previous match',
                onTap: canStep ? onPrevious : null,
                iconSize: 22,
              ),
              IconTap(
                glyph: AppGlyph.chevronDown,
                label: 'Next match',
                onTap: canStep ? onNext : null,
                iconSize: 22,
              ),
              IconTap(
                glyph: AppGlyph.close,
                label: 'Close find',
                onTap: onClose,
                iconSize: 20,
              ),
              const SizedBox(width: 8),
              PanicSquare(onTap: onPanic),
            ],
          );
        },
      ),
    );
  }
}

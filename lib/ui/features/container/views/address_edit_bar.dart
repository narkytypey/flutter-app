import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.2: the top bar's pill as a text field while an
/// address is typed. The same bar — 12/8 padding, a 34px pill, panic on the
/// right — with the pill raised (`C.raised`, a `C.line16` border) and a ×
/// that clears it. The cursor is `C.textPrimary`, not jade.
///
/// Whoever shows it fills and selects [controller] first: the field takes
/// focus as it is built.
class AddressEditBar extends StatelessWidget {
  const AddressEditBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onPanic,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// The keyboard's action.
  final ValueChanged<String> onSubmitted;
  final VoidCallback onPanic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: C.line07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 34,
              padding: const EdgeInsets.only(left: 12, right: 3),
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
                      onSubmitted: onSubmitted,
                      cursorColor: C.textPrimary,
                      style: ui(size: 13, color: C.textPrimary),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      // Typed addresses stay out of the keyboard app's
                      // dictionary and suggestion strip.
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search or type an address',
                        hintStyle: ui(size: 13, color: C.textFaint),
                      ),
                    ),
                  ),
                  IconTap(
                    glyph: AppGlyph.close,
                    label: 'Clear',
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    size: 28,
                    iconSize: 14,
                    color: C.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          PanicSquare(onTap: onPanic),
        ],
      ),
    );
  }
}

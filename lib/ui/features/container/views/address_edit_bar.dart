import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';
import 'panic_square.dart';

/// Browser-chrome spec §6.2: the top bar's pill as a text field while an
/// address is typed. The same bar — at least 64 dp, a 48 dp pill, panic on
/// the right — with the pill drawn as an input (restyle v2 §4: the group
/// tone, a 1.5 dp edge border, 2 dp text-1 while focused) and a × that
/// clears it. The cursor is `C.textPrimary`, not jade.
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
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: C.bg,
        border: Border(bottom: BorderSide(color: C.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InputFrame(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      cursorColor: C.textPrimary,
                      style: T.body,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      // Typed addresses stay out of the keyboard app's
                      // dictionary and suggestion strip.
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search or type an address',
                        hintStyle: T.body.copyWith(color: C.textFaint),
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
                    iconSize: 20,
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

/// An input's frame on the page (restyle v2 §4): at least 48 dp, the group
/// tone, radius 14, a 1.5 dp edge border that turns 2 dp text-1 while the
/// field inside it has focus. Shared by the address field and the find bar.
class InputFrame extends StatelessWidget {
  const InputFrame({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: padding,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(R.input),
            border: Border.all(
              color: focused ? C.textPrimary : C.edge,
              width: focused ? 2 : 1.5,
            ),
          ),
          child: child,
        );
      }),
    );
  }
}

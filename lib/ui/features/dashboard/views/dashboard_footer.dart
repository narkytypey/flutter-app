import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';

/// Dashboard spec §5: the Sites tab's footer, within thumb reach. A search
/// field with the container address bar's own placeholder, then a 48px `+`
/// that opens the add-site form. Restyle v2 §8 `1b`: the field is 48 dp on
/// the group tone with a 1.5 dp edge border.
///
/// [emphasise] turns the `+` jade: on an empty workspace it is the one
/// affirmative action left (spec `5b`, §4.4). The field is never jade.
class DashboardFooter extends StatelessWidget {
  const DashboardFooter({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onAddSite,
    this.emphasise = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  /// The keyboard's action.
  final ValueChanged<String> onSubmitted;
  final VoidCallback onAddSite;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hairline(color: C.line),
        ColoredBox(
          color: C.bg,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(R.input),
                      border: Border.all(color: C.edge, width: 1.5),
                    ),
                    child: TextField(
                      key: const Key('dashboard-search'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      cursorColor: C.textPrimary,
                      style: T.body,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      // Typed addresses stay out of the keyboard app's
                      // dictionary and suggestion strip, as in the address bar.
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search or type an address',
                        hintStyle: T.body.copyWith(color: C.textFaint),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconTap(
                  glyph: AppGlyph.plus,
                  label: 'Add site',
                  onTap: onAddSite,
                  size: 48,
                  iconSize: 22,
                  radius: R.input,
                  background: emphasise ? C.jade : C.button,
                  color: emphasise ? C.onJade : C.icon,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/icon_tap.dart';

/// Dashboard spec §5: the Sites tab's footer, within thumb reach. A search
/// field with the container address bar's own placeholder, then a 46px `+`
/// that opens the add-site form.
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
        const Hairline(),
        ColoredBox(
          color: C.footer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: C.button,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      key: const Key('dashboard-search'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      cursorColor: C.textPrimary,
                      style: ui(size: 13.5, color: C.textPrimary),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      // Typed addresses stay out of the keyboard app's
                      // dictionary and suggestion strip, as in the address bar.
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search or type an address',
                        hintStyle: ui(size: 13.5, color: C.textFaint),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconTap(
                  glyph: AppGlyph.plus,
                  label: 'Add site',
                  onTap: onAddSite,
                  size: 46,
                  iconSize: 20,
                  radius: 14,
                  background: emphasise ? C.jade : C.button,
                  color: emphasise ? C.bg : C.icon,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

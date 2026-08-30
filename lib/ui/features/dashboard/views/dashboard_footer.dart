import 'package:flutter/material.dart';

import '../../../core/tokens.dart';
import '../../../core/widgets/hairline.dart';
import '../../../core/widgets/pill_button.dart';

/// The bottom bar: `+ Add site` plus search, within thumb reach.
///
/// [emphasise] turns the primary button jade — the empty state is the one
/// place the design does that (spec `5b`), because it is the only action left.
class DashboardFooter extends StatelessWidget {
  const DashboardFooter({
    super.key,
    required this.onAddSite,
    required this.onSearch,
    this.emphasise = false,
  });

  final VoidCallback onAddSite;
  final VoidCallback onSearch;
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
                  child: PillButton(
                    label: '+ Add site',
                    tone: emphasise ? PillTone.primary : PillTone.neutral,
                    height: 46,
                    radius: 14,
                    onTap: onAddSite,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Material(
                    color: C.button,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onSearch,
                      borderRadius: BorderRadius.circular(14),
                      child: const Icon(Icons.search, size: 20, color: C.icon),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

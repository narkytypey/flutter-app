import 'package:flutter/material.dart';

import '../../../../domain/models/filter_list.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';

/// Digit-group commas, hand-rolled — no `intl` dependency for one format.
String formatRuleCount(int n) {
  final digits = n.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String updatedAgoLabel(DateTime now, DateTime updatedAt) {
  final days = now.difference(updatedAt).inDays;
  final unit = days == 1 ? 'day' : 'days';
  return 'updated $days $unit ago';
}

/// The `FILTER LISTS` half of spec `10d`. Each row's tap toggles the whole
/// row — there is no separate hit target for the switch, matching how the
/// dashboard treats a session row.
class FilterListSection extends StatelessWidget {
  const FilterListSection({
    super.key,
    required this.lists,
    required this.now,
    required this.nextUpdateInDays,
    required this.onToggle,
    required this.onUpdateNow,
  });

  final List<FilterList> lists;
  final DateTime now;
  final int nextUpdateInDays;
  final ValueChanged<String> onToggle;
  final VoidCallback onUpdateNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('FILTER LISTS',
              style: ui(
                  size: 10.5,
                  weight: 600,
                  letterSpacing: 1.05,
                  color: C.textFaint)),
        ),
        for (final list in lists)
          GestureDetector(
            onTap: () => onToggle(list.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(list.name, style: ui(size: 14, color: C.textPrimary)),
                      const SizedBox(height: 3),
                      Text(
                        list.enabled
                            ? '${formatRuleCount(list.ruleCount)} rules · ${updatedAgoLabel(now, list.updatedAt)}'
                            : '${formatRuleCount(list.ruleCount)} rules · off',
                        style: ui(size: 11.5, color: C.textFaint),
                      ),
                    ],
                  ),
                  AppToggle(
                      value: list.enabled, onChanged: (_) => onToggle(list.id)),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update over the proxy',
                      style: ui(size: 13.5, color: C.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Next check in $nextUpdateInDays days',
                      style: ui(size: 11.5, color: C.textFaint)),
                ],
              ),
              GestureDetector(
                onTap: onUpdateNow,
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: C.button,
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Text('Update now',
                      style:
                          ui(size: 13, weight: 500, color: C.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

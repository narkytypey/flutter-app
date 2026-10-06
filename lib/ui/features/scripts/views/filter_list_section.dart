import 'package:flutter/material.dart';

import '../../../../domain/models/filter_list.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/app_toggle.dart';
import '../../../core/widgets/group.dart';

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
/// dashboard treats a session row. The spec's "Update over the proxy" block
/// is left out (user's ruling, 2026-09-30): the lists are bundled, and the
/// app makes no network requests of its own.
class FilterListSection extends StatelessWidget {
  const FilterListSection({
    super.key,
    required this.lists,
    required this.now,
    required this.onToggle,
  });

  final List<FilterList> lists;
  final DateTime now;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, S.s2),
          child: Text('FILTER LISTS', style: T.sectionLabel),
        ),
        if (lists.isNotEmpty)
          Group(
            padding: EdgeInsets.zero,
            children: [
              for (final list in lists)
                GestureDetector(
                  onTap: () => onToggle(list.id),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 72),
                    padding: const EdgeInsets.symmetric(
                        horizontal: S.s4, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(list.name, style: T.body),
                              const SizedBox(height: 2),
                              Text(
                                list.enabled
                                    ? '${formatRuleCount(list.ruleCount)} rules · ${updatedAgoLabel(now, list.updatedAt)}'
                                    : '${formatRuleCount(list.ruleCount)} rules · off',
                                style: T.sub,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: S.s3),
                        AppToggle(
                            value: list.enabled,
                            onChanged: (_) => onToggle(list.id)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/filter_list.dart';
import 'package:container/ui/features/scripts/views/filter_list_section.dart';

void main() {
  final now = DateTime.utc(2026, 8, 30, 9);
  final updatedTwoDaysAgo = now.subtract(const Duration(days: 2));

  final lists = [
    FilterList(id: 'fl-trackers', name: 'Trackers and ads', ruleCount: 84102, updatedAt: updatedTwoDaysAgo, enabled: true, category: FilterListCategory.trackers),
    FilterList(id: 'fl-cookies', name: 'Cookie notices', ruleCount: 11430, updatedAt: updatedTwoDaysAgo, enabled: true, category: FilterListCategory.trackers),
    FilterList(id: 'fl-social', name: 'Social embeds', ruleCount: 2908, updatedAt: updatedTwoDaysAgo, enabled: false, category: FilterListCategory.ads),
  ];

  Widget host({ValueChanged<String>? onToggle, VoidCallback? onUpdateNow}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FilterListSection(
            lists: lists,
            now: now,
            nextUpdateInDays: 5,
            onToggle: onToggle ?? (_) {},
            onUpdateNow: onUpdateNow ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders every list with the spec\'s exact rule counts', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('FILTER LISTS'), findsOneWidget);
    expect(find.text('Trackers and ads'), findsOneWidget);
    expect(find.text('84,102 rules · updated 2 days ago'), findsOneWidget);
    expect(find.text('Cookie notices'), findsOneWidget);
    expect(find.text('11,430 rules · updated 2 days ago'), findsOneWidget);
    expect(find.text('Social embeds'), findsOneWidget);
    expect(find.text('2,908 rules · off'), findsOneWidget);
    expect(find.text('Update over the proxy'), findsOneWidget);
    expect(find.text('Next check in 5 days'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets('each toggle reports its own id, Update now reports a tap', (tester) async {
    final toggled = <String>[];
    var updates = 0;
    await tester.pumpWidget(host(onToggle: toggled.add, onUpdateNow: () => updates++));

    await tester.tap(find.text('Trackers and ads'));
    await tester.tap(find.text('Update now'));

    expect(toggled, ['fl-trackers']);
    expect(updates, 1);
  });
}

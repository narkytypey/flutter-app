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

  Widget host({ValueChanged<String>? onToggle}) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: FilterListSection(
            lists: lists,
            now: now,
            onToggle: onToggle ?? (_) {},
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
  });

  /// User's ruling, 2026-09-30: the lists are bundled and update with the
  /// app; the app makes no network requests of its own, so 10d offers none.
  testWidgets('offers no list update', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('Update over the proxy'), findsNothing);
    expect(find.textContaining('Next check'), findsNothing);
    expect(find.text('Update now'), findsNothing);
  });

  testWidgets('each toggle reports its own id', (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(host(onToggle: toggled.add));

    await tester.tap(find.text('Trackers and ads'));

    expect(toggled, ['fl-trackers']);
  });
}

import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/dashboard/view_models/blocked_tally_controller.dart';
import 'package:container/ui/features/report/views/today_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Today follows the live tally while it is open', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    final engine = FakeContainerEngine();
    const site = Site(
      id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        containerEngineProvider.overrideWithValue(engine),
        siteLookupProvider.overrideWithValue((id) async => id == 's1' ? site : null),
      ],
      child: const MaterialApp(home: TodayRoute()),
    ));

    await tester.runAsync(() async {
      await engine.open(site);
      engine.addBlocked('s1', BlockedCategory.trackers, 7);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('7'), findsWidgets);
  });
}

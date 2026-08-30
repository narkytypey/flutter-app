import 'package:container/domain/models/open_step.dart';
import 'package:container/ui/features/container/views/opening_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the checklist and the tunnel promise', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: OpeningBody(
        host: 'forum.example.com',
        steps: const [
          OpenStep('Fresh session, no shared cookies', OpenStepState.done),
          OpenStep('Filter lists loaded', OpenStepState.done),
          OpenStep('Fingerprint noise injected', OpenStepState.done),
          OpenStep('Connecting through 127.0.0.1:9050', OpenStepState.running),
        ],
        progress: 0.58,
        onCancel: () {},
      ),
    ));

    expect(find.text('Starting a clean container'), findsOneWidget);
    expect(find.text('Nothing loads until the tunnel is up.'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Connecting through 127.0.0.1:9050'), findsOneWidget);
  });
}

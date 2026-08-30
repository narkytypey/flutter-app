import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/held_download.dart';
import 'package:container/ui/features/in_page/views/held_download_sheet.dart';

void main() {
  const download = HeldDownload(
    fileName: 'statement-june.pdf',
    sizeBytes: 1468006,
    sourceHost: 'forum.example.com',
    kindLabel: 'PDF',
  );

  Widget host(ValueChanged<DownloadDecision> onDecision) {
    return MaterialApp(
      home: Scaffold(
        body: HeldDownloadSheet(download: download, onDecision: onDecision),
      ),
    );
  }

  testWidgets('renders the spec copy verbatim', (tester) async {
    await tester.pumpWidget(host((_) {}));

    expect(find.text('Download held'), findsOneWidget);
    expect(
      find.text(
        'Files leave the container when they are saved. This one would go to '
        'your device storage where other apps can read it.',
      ),
      findsOneWidget,
    );
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('statement-june.pdf'), findsOneWidget);
    expect(find.text('1.4 MB · from forum.example.com'), findsOneWidget);
    expect(find.text('Keep inside this container'), findsOneWidget);
    expect(find.text('Save to device storage'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('each action reports its own decision', (tester) async {
    final seen = <DownloadDecision>[];
    await tester.pumpWidget(host(seen.add));

    await tester.tap(find.text('Keep inside this container'));
    await tester.tap(find.text('Save to device storage'));
    await tester.tap(find.text('Discard'));

    expect(seen, [
      DownloadDecision.keepInContainer,
      DownloadDecision.saveToDevice,
      DownloadDecision.discard,
    ]);
  });
}

import 'package:container/domain/models/site.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/monogram.dart';
import 'package:container/ui/features/scripts/views/script_editor_screen.dart';
import 'package:container/ui/features/scripts/views/script_site_picker.dart';
import 'package:container/domain/models/user_script.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _forum = Site(
    id: 'forum', workspaceId: 'w', name: 'Forum', monogram: 'Fo',
    url: 'https://forum.example.com/latest', profileId: 'p-forum');
const _mail = Site(
    id: 'mail', workspaceId: 'w', name: 'Mail', monogram: 'Ma',
    url: 'https://mail.example.com', profileId: 'p-mail');

void main() {
  testWidgets('lists each site with its monogram and host, and reports the one tapped',
      (tester) async {
    final picked = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScriptSitePicker(sites: const [_forum, _mail], onPick: picked.add),
      ),
    ));

    expect(find.text('Forum'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('mail.example.com'), findsOneWidget);
    expect(find.byType(Monogram), findsNWidgets(2));

    await tester.tap(find.text('mail.example.com'));
    expect(picked, ['mail']);
  });

  Widget editor({required VoidCallback? onAddSite}) => MaterialApp(
        home: ScriptEditorScreen(
          title: 'Hide sticky headers',
          initialKind: ScriptKind.css,
          initialCode: '',
          initialRunAtDocumentStart: false,
          appliedSites: const [],
          onSave: (_) {},
          onRemoveSite: (_) {},
          onAddSite: onAddSite,
          onClose: () {},
        ),
      );

  testWidgets('"+ Add site" reports a tap while there is a site left to add', (tester) async {
    var taps = 0;
    await tester.pumpWidget(editor(onAddSite: () => taps++));

    await tester.tap(find.text('+ Add site'));
    expect(taps, 1);
  });

  testWidgets('"+ Add site" is dimmed and inert once every site is on the script',
      (tester) async {
    await tester.pumpWidget(editor(onAddSite: null));

    final label = tester.widget<Text>(find.text('+ Add site'));
    expect(label.style!.color, C.textFaint);
    await tester.tap(find.text('+ Add site'));
    await tester.pumpAndSettle();
  });
}

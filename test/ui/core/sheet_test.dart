import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/hairline.dart';
import 'package:container/ui/core/widgets/sheet.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('BottomSheetSurface uses the sheet colour and a 22px top radius',
      (tester) async {
    await tester.pumpWidget(host(
      const BottomSheetSurface(children: [Text('body')]),
    ));

    final container = tester.widget<Container>(
      find.byKey(const Key('sheet-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, C.sheet);
    expect(
      decoration.borderRadius,
      const BorderRadius.vertical(top: Radius.circular(22)),
    );
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('SheetRow renders its label and reports taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      SheetRow(label: 'Edit settings', onTap: () => taps++),
    ));

    await tester.tap(find.text('Edit settings'));
    expect(taps, 1);
  });

  testWidgets('SheetRow honours an explicit label colour', (tester) async {
    await tester.pumpWidget(host(
      SheetRow(label: 'Remove site', labelColor: C.danger, onTap: () {}),
    ));

    final text = tester.widget<Text>(find.text('Remove site'));
    expect(text.style!.color, C.danger);
  });

  testWidgets('SheetGroup puts a hairline between rows but not after the last',
      (tester) async {
    await tester.pumpWidget(host(
      SheetGroup(children: [
        SheetRow(label: 'One', onTap: () {}),
        SheetRow(label: 'Two', onTap: () {}),
        SheetRow(label: 'Three', onTap: () {}),
      ]),
    ));

    expect(find.byType(Hairline), findsNWidgets(2));
  });
}

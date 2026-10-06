import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/dashboard/views/dashboard_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

Future<List<String>> _pump(WidgetTester tester, {bool emphasise = false}) async {
  final calls = <String>[];
  final controller = TextEditingController();
  final focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: DashboardFooter(
          controller: controller,
          focusNode: focus,
          onChanged: (text) => calls.add('changed $text'),
          onSubmitted: (text) => calls.add('submitted $text'),
          onAddSite: () => calls.add('add'),
          emphasise: emphasise,
        ),
      ),
    ),
  ));
  return calls;
}

void main() {
  testWidgets("a search field with the address bar's placeholder, then + (spec §5)",
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.text('Search or type an address'), findsOneWidget);
    expect(find.text('+ Add site'), findsNothing);
    expect(tester.getSize(findIconTap('Add site')), const Size(48, 48));
    expect(find.bySemanticsLabel('Add site'), findsOneWidget);
    expect(tester.getCenter(findIconTap('Add site')).dx,
        greaterThan(tester.getCenter(find.byType(TextField)).dx));
    semantics.dispose();
  });

  testWidgets('typing, the keyboard action and + are reported', (tester) async {
    final calls = await _pump(tester);

    await tester.enterText(find.byKey(const Key('dashboard-search')), 'forum');
    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.tap(findIconTap('Add site'));

    expect(calls, ['changed forum', 'submitted forum', 'add']);
  });

  testWidgets('typed addresses stay out of the keyboard dictionary', (tester) async {
    await _pump(tester);
    final field = tester.widget<TextField>(find.byKey(const Key('dashboard-search')));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.keyboardType, TextInputType.url);
  });

  testWidgets('+ is jade only on an empty workspace; the field never is (§4.4)', (tester) async {
    await _pump(tester);
    var plus = tester.widget<IconTap>(findIconTap('Add site'));
    expect(plus.background, C.button);
    expect(plus.color, C.icon);

    await _pump(tester, emphasise: true);
    plus = tester.widget<IconTap>(findIconTap('Add site'));
    expect(plus.background, C.jade);
    expect(plus.color, C.bg);
    expect(tester.widget<AppIcon>(findGlyph(AppGlyph.plus)).color, C.bg);
  });

  // Restyle v2 §8 `1b` (Plan 21 Task 1).
  testWidgets('v2: the search field is 48 dp on the group tone with a 1.5 dp edge border',
      (tester) async {
    await _pump(tester);

    final box = tester.widget<Container>(find
        .ancestor(of: find.byKey(const Key('dashboard-search')), matching: find.byType(Container))
        .first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, C.surface);
    final border = decoration.border! as Border;
    expect(border.top.color, C.edge);
    expect(border.top.width, 1.5);
    expect(tester.getSize(find.byWidget(box)).height, greaterThanOrEqualTo(48));
  });

  // Plan 24: the + on jade takes the label-on-jade colour, which in light is
  // white, not the page colour.
  testWidgets('in light the emphasised + is drawn in onJade', (tester) async {
    C.use(Brightness.light);
    await _pump(tester, emphasise: true);
    final tap = tester.widget<IconTap>(findIconTap('Add site'));
    expect(tap.background, Palette.light.jade);
    expect(tap.color, Palette.light.onJade);
  });
}

import 'package:container/domain/models/find_result.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/core/widgets/pill_button.dart';
import 'package:container/ui/features/container/views/container_top_bar.dart';
import 'package:container/ui/features/container/views/find_bar.dart';
import 'package:container/ui/features/container/views/load_line.dart';
import 'package:container/ui/features/container/views/throwaway_save_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';

Finder _icon(String label) =>
    find.byWidgetPredicate((w) => w is IconTap && w.label == label);

AppIcon _glyph(WidgetTester tester, AppGlyph glyph) => tester.widget<AppIcon>(
    find.byWidgetPredicate((w) => w is AppIcon && w.glyph == glyph));

Future<void> _pump(WidgetTester tester, Widget bar) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Column(children: [bar]))));

FindBar _findBar(
  TextEditingController controller,
  FindResult? result, {
  List<String>? calls,
}) =>
    FindBar(
      controller: controller,
      result: result,
      onChanged: (query) => calls?.add('find $query'),
      onPrevious: () => calls?.add('previous'),
      onNext: () => calls?.add('next'),
      onClose: () => calls?.add('close'),
    );

/// The container's one bar (user's ruling, 2026-10-10): the pill, then the
/// open count and ☰ where panic was.
ContainerTopBar _topBar({
  int openCount = 3,
  List<String>? calls,
  bool next = true,
  bool previous = true,
}) =>
    ContainerTopBar(
      host: 'forum.example.com',
      routeLabel: '',
      live: true,
      loading: false,
      openCount: openCount,
      onEditAddress: () => calls?.add('address'),
      onStop: () => calls?.add('stop'),
      onReload: () => calls?.add('reload'),
      onSiteDetails: () => calls?.add('details'),
      onOpenSwitcher: () => calls?.add('switcher'),
      onMenu: () => calls?.add('menu'),
      onNextContainer: next ? () => calls?.add('next') : null,
      onPreviousContainer: previous ? () => calls?.add('previous') : null,
    );

void main() {
  // User's ruling, 2026-10-10: panic is started only by flipping the phone
  // face down. No bar the container shows has a panic button.
  testWidgets('no bar has a panic button', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, _topBar());
    expect(_icon('Panic'), findsNothing);
    expect(findGlyph(AppGlyph.panic), findsNothing);

    await _pump(tester, _findBar(controller, null));
    expect(_icon('Panic'), findsNothing);
    expect(findGlyph(AppGlyph.panic), findsNothing);
  });

  testWidgets('the load line fills to the progress while loading, and is empty otherwise', (tester) async {
    Widget line({required bool loading, required int progress}) => Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: LoadLine(loading: loading, progress: progress),
            ),
          ),
        );

    await tester.pumpWidget(line(loading: true, progress: 40));
    expect(tester.getSize(find.byKey(const Key('load-line'))), const Size(120, 2));
    // Muted, not jade: jade means live state or the one affirmative action.
    expect(tester.widget<ColoredBox>(find.byKey(const Key('load-line'))).color, C.textMuted);

    await tester.pumpWidget(line(loading: false, progress: 100));
    expect(find.byKey(const Key('load-line')), findsNothing);
    // Still 2px tall, so a load starting or ending never moves the page.
    expect(tester.getSize(find.byType(LoadLine)), const Size(300, 2));
  });

  testWidgets('the open count and ☰ end the top bar, each reporting a tap', (tester) async {
    final calls = <String>[];
    await _pump(tester, _topBar(calls: calls));

    await tester.tap(find.byKey(const Key('open-sessions-target')));
    await tester.tap(_icon('Menu'));

    expect(calls, ['switcher', 'menu']);
    // The count is the number alone, in its own outlined box.
    expect(find.descendant(
        of: find.byKey(const Key('open-sessions-target')), matching: find.text('3')),
        findsOneWidget);
    // Right of the pill, ☰ last.
    final pill = tester.getRect(find.byKey(const Key('address-pill')));
    final count = tester.getRect(find.byKey(const Key('open-sessions-target')));
    final menu = tester.getRect(_icon('Menu'));
    expect(count.left, greaterThanOrEqualTo(pill.right));
    expect(menu.left, greaterThanOrEqualTo(count.right));
    // Back and forward are in ☰ and on Android's own back, not on the bar.
    expect(_icon('Back'), findsNothing);
    expect(_icon('Forward'), findsNothing);
  });

  testWidgets('the open count is named for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _topBar(openCount: 1));

    expect(find.bySemanticsLabel('Open sessions'), findsOneWidget);
    expect(find.bySemanticsLabel('Menu'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the save bar offers saving and dismissing, and is neutral throughout', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      ThrowawaySaveBar(onSave: () => calls.add('save'), onDismiss: () => calls.add('dismiss')),
    );

    expect(find.text('Not saved · wiped when you close it'), findsOneWidget);
    await tester.tap(find.text('Save as a site'));
    await tester.tap(find.byKey(const Key('save-bar-dismiss')));

    expect(calls, ['save', 'dismiss']);
    expect(tester.widget<PillButton>(find.byType(PillButton)).tone, PillTone.neutral);
    final colours = tester
        .widgetList<Text>(find.descendant(of: find.byType(ThrowawaySaveBar), matching: find.byType(Text)))
        .map((text) => text.style?.color);
    expect(colours, isNot(contains(C.jade)));
  });

  // User's ruling, 2026-10-02.
  testWidgets("the save bar's × is announced as Dismiss", (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, ThrowawaySaveBar(onSave: () {}, onDismiss: () {}));

    expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the find count reads from one, says No matches, and waits for the page', (tester) async {
    final controller = TextEditingController(text: 'fox');
    addTearDown(controller.dispose);

    await _pump(tester, _findBar(controller, const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 1, matchCount: 7)));
    expect(find.text('2/7'), findsOneWidget);

    await _pump(tester, _findBar(controller, const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 0, matchCount: 0)));
    expect(find.text('No matches'), findsOneWidget);

    // No count yet for what is typed: nothing, rather than a stale one.
    await _pump(tester, _findBar(controller, null));
    expect(find.text('No matches'), findsNothing);

    // Nothing typed: nothing to count.
    controller.clear();
    await _pump(tester, _findBar(controller, const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 0, matchCount: 0)));
    await tester.pump();
    expect(find.text('No matches'), findsNothing);
    expect(find.text('Find in page'), findsOneWidget);
  });

  testWidgets('typing, stepping and closing each report from the find bar', (tester) async {
    final calls = <String>[];
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(
      tester,
      _findBar(controller, const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 0, matchCount: 3), calls: calls),
    );

    await tester.enterText(find.byType(TextField), 'fox');
    await tester.pump();
    await tester.tap(_icon('Previous match'));
    await tester.tap(_icon('Next match'));
    await tester.tap(_icon('Close find'));

    expect(calls, ['find fox', 'previous', 'next', 'close']);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('with no match to step to, the arrows are dimmed and inert', (tester) async {
    final calls = <String>[];
    final controller = TextEditingController(text: 'zebra');
    addTearDown(controller.dispose);
    await _pump(
      tester,
      _findBar(controller, const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 0, matchCount: 0), calls: calls),
    );

    await tester.tap(_icon('Previous match'), warnIfMissed: false);
    await tester.tap(_icon('Next match'), warnIfMissed: false);

    expect(calls, isEmpty);
    expect(_glyph(tester, AppGlyph.chevronUp).color, C.textFaint);
    expect(_glyph(tester, AppGlyph.chevronDown).color, C.textFaint);
  });

  testWidgets('the find field asks the keyboard not to learn what is typed', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await _pump(tester, _findBar(controller, null));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.cursorColor, C.textPrimary);
  });

  // Review Focus 5.
  testWidgets('every bar fits a 360-wide phone', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'a query longer than the field');
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            _topBar(openCount: 12),
            _findBar(controller, const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 0, matchCount: 0)),
            const Spacer(),
            ThrowawaySaveBar(onSave: () {}, onDismiss: () {}),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  group('the swipe between open containers (dashboard spec §9)', () {
    Future<List<String>> pumpBar(WidgetTester tester,
        {bool next = true, bool previous = true}) async {
      final calls = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: _topBar(calls: calls, next: next, previous: previous),
          ),
        ),
      ));
      return calls;
    }

    testWidgets('a fling to the left views the next, to the right the previous', (tester) async {
      final calls = await pumpBar(tester);

      await tester.fling(find.byType(ContainerTopBar), const Offset(-200, 0), 800);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(ContainerTopBar), const Offset(200, 0), 800);
      await tester.pumpAndSettle();

      expect(calls, ['next', 'previous']);
    });

    testWidgets('with no neighbour a fling does nothing', (tester) async {
      final calls = await pumpBar(tester, next: false, previous: false);

      await tester.fling(find.byType(ContainerTopBar), const Offset(-200, 0), 800);
      await tester.fling(find.byType(ContainerTopBar), const Offset(200, 0), 800);
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('at the last container only a fling to the right works', (tester) async {
      final calls = await pumpBar(tester, next: false);

      await tester.fling(find.byType(ContainerTopBar), const Offset(-200, 0), 800);
      await tester.fling(find.byType(ContainerTopBar), const Offset(200, 0), 800);
      await tester.pumpAndSettle();

      expect(calls, ['previous']);
    });

    testWidgets('a short drag does not switch and a tap still taps', (tester) async {
      final calls = await pumpBar(tester);
      final height = tester.getSize(find.byType(ContainerTopBar)).height;

      // Dragged across ☰, so the pill's own tap cannot answer it.
      await tester.dragFrom(tester.getCenter(findIconTap('Menu')), Offset(-(height - 10), 0));
      await tester.pumpAndSettle();
      expect(calls, isEmpty, reason: 'shorter than the bar is tall');

      // A tap that moves a little, under the touch slop, is still a tap.
      await tester.dragFrom(tester.getCenter(findIconTap('Menu')), const Offset(6, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-sessions-target')));
      expect(calls, ['menu', 'switcher']);
    });
  });

  // Restyle v2 §5, §8 `2b`, moved to the top bar (user's ruling, 2026-10-10).
  testWidgets("v2: the open count and ☰ are 48 dp targets, the count set as N OPEN was",
      (tester) async {
    await _pump(tester, _topBar(openCount: 2));

    expect(tester.getSize(_icon('Menu')), const Size(48, 48));
    final target = tester.getSize(find.byKey(const Key('open-sessions-target')));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    final count = tester.widget<Text>(find.text('2'));
    expect(count.style!.fontSize, 13);
    expect(count.style!.fontWeight, FontWeight.w600);
    expect(count.style!.color, C.textPrimary);
    expect(count.style, ContainerTopBar.openCountStyle);
  });

  testWidgets("v2: the find bar's arrows and × are 48 dp; the field an input",
      (tester) async {
    final controller = TextEditingController(text: 'fox');
    addTearDown(controller.dispose);
    await _pump(tester,
        _findBar(controller, const FindResult(siteId: 's1', pageId: 's1-p1', activeMatch: 0, matchCount: 3)));
    await tester.pump();

    for (final label in ['Previous match', 'Next match', 'Close find']) {
      expect(tester.getSize(_icon(label)), const Size(48, 48), reason: label);
    }
    final frame = tester.widget<Container>(
        find.ancestor(of: find.byType(TextField), matching: find.byType(Container)).first);
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.color, C.surface);
    // Focused (the field takes focus as it is built): 2 dp text-1.
    expect((decoration.border! as Border).top.color, C.textPrimary);
    expect((decoration.border! as Border).top.width, 2);
  });

  testWidgets("v2: the save bar's × is a 48 dp target", (tester) async {
    await _pump(tester, ThrowawaySaveBar(onSave: () {}, onDismiss: () {}));
    expect(tester.getSize(find.byKey(const Key('save-bar-dismiss'))), const Size(48, 48));
  });
}

import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/core/icons.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/app_toggle.dart';
import 'package:container/ui/core/widgets/choice_chip.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:container/ui/features/settings/views/default_route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_finders.dart';
import '../settings/settings_v2_test.dart' show paintedColours;

const _workspaces = [
  Workspace(id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
  Workspace(id: 'ws-work', name: 'Work', markerIndex: 1, storageRule: StorageRule.keep),
  Workspace(id: 'ws-ephemeral', name: 'Ephemeral', markerIndex: 4, storageRule: StorageRule.wipeOnExit),
];

Future<void> _pump(WidgetTester tester) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  return tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(
      workspaces: _workspaces,
      initialWorkspaceId: 'ws-work',
      // The proxy on, so every Network control is drawn.
      defaultRoute: const ProxyRoute(mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050),
      onSave: (_) {},
    ),
  ));
}

/// Every box decoration on [text]'s ancestors.
Iterable<BoxDecoration> _decorationsAbove(WidgetTester tester, Finder text) => tester
    .widgetList<Container>(find.ancestor(of: text, matching: find.byType(Container)))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>();

bool _outlinedInText1(WidgetTester tester, Finder text) => _decorationsAbove(tester, text).any((d) {
      final border = d.border;
      return border is Border && border.top.color == C.textPrimary && border.top.width == 2;
    });

/// Whether a check glyph sits beside [text], in the same segment.
bool _checked(WidgetTester tester, Finder text) {
  final row = find.ancestor(of: text, matching: find.byType(Row)).first;
  return find.descendant(of: row, matching: findGlyph(AppGlyph.check)).evaluate().isNotEmpty;
}

void main() {
  testWidgets('v2: the selected tab is a text-1 outline with a check; no jade underline',
      (tester) async {
    await _pump(tester);
    for (final tab in ['Basics', 'Network', 'Privacy', 'Appearance']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      for (final other in ['Basics', 'Network', 'Privacy', 'Appearance']) {
        final selected = other == tab;
        expect(_outlinedInText1(tester, find.text(other)), selected, reason: '$tab: $other');
        expect(_checked(tester, find.text(other)), selected, reason: '$tab: $other');
        expect(
          _decorationsAbove(tester, find.text(other)).any((d) =>
              d.border is Border && (d.border! as Border).bottom.color == C.jade),
          isFalse,
          reason: other,
        );
      }
    }
  });

  testWidgets('v2: workspace chips are AppChips, the start workspace selected', (tester) async {
    await _pump(tester);
    expect(find.byType(AppChip), findsNWidgets(3));
    final work = tester.widget<AppChip>(find.ancestor(of: find.text('Work'), matching: find.byType(AppChip)));
    expect(work.selected, isTrue);
    await tester.tap(find.text('Ephemeral'));
    await tester.pump();
    expect(
        tester.widget<AppChip>(find.ancestor(of: find.text('Ephemeral'), matching: find.byType(AppChip))).selected,
        isTrue);
  });

  testWidgets('v2: route and user-agent choices are segments: outline and check', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();
    expect(_outlinedInText1(tester, find.text('SOCKS5')), isTrue);
    expect(_checked(tester, find.text('SOCKS5')), isTrue);
    expect(_outlinedInText1(tester, find.text('HTTP')), isFalse);
    expect(_checked(tester, find.text('HTTP')), isFalse);

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(_outlinedInText1(tester, find.text('Android')), isTrue);
    expect(_checked(tester, find.text('Android')), isTrue);
    expect(_checked(tester, find.text('Desktop')), isFalse);
  });

  testWidgets('v2: custom CSS and JS are code, in C.code', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(2));
    for (final field in fields) {
      expect(field.style!.color, C.code);
      expect(field.style!.fontFamily, 'IBMPlexMono');
    }
  });

  testWidgets('v2: switches are AppToggles', (tester) async {
    await _pump(tester);
    for (final (tab, count) in [('Network', 4), ('Privacy', 7), ('Appearance', 2)]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.byType(AppToggle), findsNWidgets(count), reason: tab);
    }
  });

  testWidgets('v2: Save is the one jade on every tab', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byKey(const Key('add-site-address')), 'https://forum.example.com');
    await tester.pump();
    for (final tab in ['Basics', 'Network', 'Privacy', 'Appearance']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      final jade = paintedColours(tester, find.byType(AddSiteScreen)).where((c) => c == C.jade);
      expect(jade, hasLength(1), reason: tab);
      expect(tester.widget<Text>(find.text('Save')).style!.color, C.jade);
    }
    // The zoom slider is not jade either.
    final slider = tester.widget<SliderTheme>(find.byType(SliderTheme));
    expect(slider.data.activeTrackColor, isNot(C.jade));
  });

  testWidgets('v2: the header targets are 48 dp', (tester) async {
    await _pump(tester);
    expect(tester.getSize(findIconTap('Close')), const Size(48, 48));
    expect(tester.getSize(find.ancestor(of: find.text('Save'), matching: find.byType(GestureDetector)).first).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('v2: inputs have a 1.5 dp edge border, radius 14', (tester) async {
    await _pump(tester);
    final box = _decorationsAbove(
            tester, find.byKey(const Key('add-site-name')))
        .firstWhere((d) => d.border != null);
    expect((box.border! as Border).top.color, C.edge);
    expect((box.border! as Border).top.width, 1.5);
    expect(box.borderRadius, BorderRadius.circular(R.input));
  });

  testWidgets('v2: Default route has no jade, its mode a segment', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(428, 1400);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: DefaultRouteScreen(
        initial: const ProxyRoute(mode: ProxyMode.http, host: '127.0.0.1', port: 8080),
        onDone: (_) {},
      ),
    ));
    expect(paintedColours(tester, find.byType(DefaultRouteScreen)), isNot(contains(C.jade)));
    expect(_outlinedInText1(tester, find.text('HTTP')), isTrue);
    expect(find.byType(AppToggle), findsNWidgets(2));
  });
}

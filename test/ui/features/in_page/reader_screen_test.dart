import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/reader_article.dart';
import 'package:container/domain/models/reader_style.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/core/widgets/icon_tap.dart';
import 'package:container/ui/features/in_page/views/reader_screen.dart';
import '../../../support/glyph_finders.dart';

void main() {
  const article = ReaderArticle(
    host: 'forum.example.com',
    title: 'What a container actually isolates, and what it cannot',
    paragraphs: [
      'Separate storage stops one site from reading another\'s cookies. It '
          'does not hide the fact that a request came from this device, '
          'which is what the proxy layer is for.',
      'The two protections are often confused. Keeping them separate in '
          'your head makes it easier to decide which sites need which.',
      'A site that needs a login and a site you want to read anonymously '
          'are different problems, and they belong in different workspaces.',
    ],
    minutesToRead: 6,
  );

  Widget host({VoidCallback? onClose, VoidCallback? onTextSize, VoidCallback? onTheme}) {
    return MaterialApp(
      home: ReaderScreen(
        article: article,
        onClose: onClose ?? () {},
        onTextSize: onTextSize ?? () {},
        onTheme: onTheme ?? () {},
      ),
    );
  }

  testWidgets('renders the spec copy verbatim, on the reader background', (tester) async {
    await tester.pumpWidget(host());

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, C.bgReader);

    expect(find.text('READER · 6 MIN'), findsOneWidget);
    expect(find.text('forum.example.com'), findsOneWidget);
    expect(find.text('What a container actually isolates, and what it cannot'),
        findsOneWidget);
    expect(find.textContaining('The two protections are often confused'),
        findsOneWidget);
  });

  testWidgets('every paragraph in the article renders, in order', (tester) async {
    await tester.pumpWidget(host());
    for (final paragraph in article.paragraphs) {
      expect(find.textContaining(paragraph.substring(0, 20)), findsOneWidget);
    }
  });

  testWidgets('the three header controls report their own callback', (tester) async {
    var closed = 0;
    var textSized = 0;
    var themed = 0;
    await tester.pumpWidget(host(
      onClose: () => closed++,
      onTextSize: () => textSized++,
      onTheme: () => themed++,
    ));

    expect(tester.widget<IconTap>(findIconTap('Back')).color, C.readerMuted);
    expect(tester.widget<IconTap>(findIconTap('Reader theme')).color, C.readerMuted);

    await tester.tap(findIconTap('Back'));
    await tester.tap(find.text('Aa'));
    await tester.tap(findIconTap('Reader theme'));

    expect(closed, 1);
    expect(textSized, 1);
    expect(themed, 1);
  });

  // User's ruling, 2026-09-30.

  TextStyle styleOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!;

  testWidgets('a larger size draws the title and body larger', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderScreen(
        article: article,
        style: const ReaderStyle(size: ReaderTextSize.largest, soft: false),
        onClose: () {},
        onTextSize: () {},
        onTheme: () {},
      ),
    ));
    expect(styleOf(tester, article.title).fontSize, ReaderTextSize.largest.title);
    expect(styleOf(tester, article.paragraphs.first).fontSize, ReaderTextSize.largest.body);
  });

  testWidgets('the soft colours dim the title and body, on the same background', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ReaderScreen(
        article: article,
        style: const ReaderStyle(size: ReaderTextSize.standard, soft: true),
        onClose: () {},
        onTextSize: () {},
        onTheme: () {},
      ),
    ));
    expect(styleOf(tester, article.title).color, C.readerBody);
    expect(styleOf(tester, article.paragraphs.first).color, C.readerMuted);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, C.bgReader);
  });

  testWidgets('by default the spec\'s sizes and colours', (tester) async {
    await tester.pumpWidget(host());
    expect(styleOf(tester, article.title).fontSize, 25);
    expect(styleOf(tester, article.title).color, C.readerTitle);
    expect(styleOf(tester, article.paragraphs.first).fontSize, 15.5);
    expect(styleOf(tester, article.paragraphs.first).color, C.readerBody);
  });

  // Restyle v2 §2.5, §5, §8 (`6b`): reader tones, Plex Sans, sizes as built.
  testWidgets('v2: the host is reader-muted, at least 4.5:1 on the reader page', (tester) async {
    await tester.pumpWidget(host());
    final style = tester.widget<Text>(find.text('forum.example.com')).style!;
    expect(style.color, C.readerMuted);
    expect(_contrast(C.readerMuted, C.bgReader), greaterThanOrEqualTo(4.5));
  });

  testWidgets('v2: the article is set in Plex Sans', (tester) async {
    await tester.pumpWidget(host());
    for (final text in [article.title, article.paragraphs.first, 'forum.example.com']) {
      expect(tester.widget<Text>(find.text(text)).style!.fontFamily, 'IBMPlexSans');
    }
  });

  testWidgets('v2: the header controls are 48 dp targets', (tester) async {
    await tester.pumpWidget(host());
    expect(tester.getSize(findIconTap('Back')), const Size(48, 48));
    expect(tester.getSize(findIconTap('Reader theme')), const Size(48, 48));
    final aa = find.ancestor(of: find.text('Aa'), matching: find.byType(GestureDetector)).first;
    expect(tester.getSize(aa).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(aa).width, greaterThanOrEqualTo(48));
  });
}


/// WCAG 2 contrast ratio.
double _contrast(Color a, Color b) {
  double lin(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

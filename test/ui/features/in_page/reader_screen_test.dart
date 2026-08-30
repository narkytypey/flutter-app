import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/reader_article.dart';
import 'package:container/ui/core/tokens.dart';
import 'package:container/ui/features/in_page/views/reader_screen.dart';

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

    await tester.tap(find.text('‹'));
    await tester.tap(find.text('Aa'));
    await tester.tap(find.text('◑'));

    expect(closed, 1);
    expect(textSized, 1);
    expect(themed, 1);
  });
}

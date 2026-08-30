import 'package:flutter/material.dart';

import '../../../../domain/models/reader_article.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';

/// Spec `6b` — text only, controls out of the way. The header is the only
/// chrome; everything below it is the article, full width, no card.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.article,
    required this.onClose,
    required this.onTextSize,
    required this.onTheme,
  });

  final ReaderArticle article;
  final VoidCallback onClose;
  final VoidCallback onTextSize;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgReader,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: onClose,
                    child: const Text('‹', style: TextStyle(fontSize: 16, color: C.readerMuted)),
                  ),
                  Text(
                    article.readingLabel,
                    style: ui(size: 11.5, weight: 500, letterSpacing: 0.69, color: C.readerMuted),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onTextSize,
                        child: Text('Aa', style: ui(size: 13, color: C.readerMuted)),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: onTheme,
                        child: Text('◑', style: ui(size: 14, color: C.readerMuted)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 40),
                children: [
                  Text(article.host, style: ui(size: 12, color: C.readerHost)),
                  const SizedBox(height: 18),
                  Text(
                    article.title,
                    style: ui(
                      size: 25,
                      weight: 600,
                      height: 1.25,
                      letterSpacing: -0.375,
                      color: C.readerTitle,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < article.paragraphs.length; i++) ...[
                    if (i != 0) const SizedBox(height: 14),
                    Text(
                      article.paragraphs[i],
                      style: ui(size: 15.5, height: 1.75, color: C.readerBody),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

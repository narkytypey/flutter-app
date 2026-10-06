import 'package:flutter/material.dart';

import '../../../../domain/models/reader_article.dart';
import '../../../../domain/models/reader_style.dart';
import '../../../core/icons.dart';
import '../../../core/tokens.dart';
import '../../../core/typography.dart';
import '../../../core/widgets/icon_tap.dart';

/// Spec `6b` — text only, controls out of the way. The header is the only
/// chrome; everything below it is the article, full width, no card. [style]
/// sets the text size (`Aa`) and the colours (`◑`); `ReaderRoute` keeps it.
class ReaderScreen extends StatelessWidget {
  const ReaderScreen({
    super.key,
    required this.article,
    this.style = ReaderStyle.standard,
    required this.onClose,
    required this.onTextSize,
    required this.onTheme,
  });

  final ReaderArticle article;
  final ReaderStyle style;
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
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.line)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTap(
                    glyph: AppGlyph.back,
                    label: 'Back',
                    onTap: onClose,
                    iconSize: 22,
                    color: C.readerMuted,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        article.readingLabel,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ui(size: 13, weight: 500, letterSpacing: 0.52, color: C.readerMuted),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onTextSize,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: Text('Aa', style: ui(size: 15, color: C.readerMuted)),
                          ),
                        ),
                      ),
                      IconTap(
                        glyph: AppGlyph.contrast,
                        label: 'Reader theme',
                        onTap: onTheme,
                        iconSize: 22,
                        color: C.readerMuted,
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
                  Text(article.host, style: ui(size: 14, color: C.readerMuted)),
                  const SizedBox(height: 18),
                  Text(
                    article.title,
                    style: ui(
                      size: style.size.title,
                      weight: 600,
                      height: 1.25,
                      letterSpacing: -0.375,
                      color: style.soft ? C.readerBody : C.readerTitle,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (var i = 0; i < article.paragraphs.length; i++) ...[
                    if (i != 0) const SizedBox(height: 14),
                    Text(
                      article.paragraphs[i],
                      style: ui(
                        size: style.size.body,
                        height: 1.7,
                        color: style.soft ? C.readerMuted : C.readerBody,
                      ),
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

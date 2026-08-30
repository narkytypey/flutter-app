import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/reader_article.dart';

void main() {
  test('the reading label matches the spec\'s "READER · 6 MIN"', () {
    const article = ReaderArticle(
      host: 'forum.example.com',
      title: 'What a container actually isolates, and what it cannot',
      paragraphs: ['One.', 'Two.', 'Three.'],
      minutesToRead: 6,
    );
    expect(article.readingLabel, 'READER · 6 MIN');
  });

  test('the label tracks whatever minute count it is given', () {
    const article = ReaderArticle(
      host: 'reader.example.com',
      title: 'Title',
      paragraphs: ['One.'],
      minutesToRead: 1,
    );
    expect(article.readingLabel, 'READER · 1 MIN');
  });
}

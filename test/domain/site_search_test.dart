import 'package:container/domain/models/site.dart';
import 'package:container/domain/site_search.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(String id, String name, String url, {DateTime? visited}) => Site(
      id: id, workspaceId: 'w', name: name, monogram: 'Xx', url: url,
      profileId: 'p-$id', lastVisitedAt: visited,
    );

void main() {
  test('matches name or host, case-insensitively, most recent first', () {
    final forum = _site('f', 'Forum', 'https://forum.example.com',
        visited: DateTime(2026, 9, 1));
    final mail = _site('m', 'Webmail', 'https://mail.example.org',
        visited: DateTime(2026, 9, 20));
    final notes = _site('n', 'Notes', 'https://notes.example.net');

    expect(sitesMatching([forum, mail, notes], 'EXAMPLE').map((s) => s.id),
        ['m', 'f', 'n']);
    expect(sitesMatching([forum, mail, notes], 'mail').map((s) => s.id), ['m']);
  });

  test('an empty query matches every site', () {
    final a = _site('a', 'A', 'https://a.example.com');
    final b = _site('b', 'B', 'https://b.example.com');
    expect(sitesMatching([a, b], '  '), hasLength(2));
  });
}

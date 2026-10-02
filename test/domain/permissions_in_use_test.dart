import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/permissions_in_use.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

const _site = Site(id: 's', workspaceId: 'w', name: 'Meet', monogram: 'Mt',
    url: 'https://meet.example.com', profileId: 'p');

void main() {
  test('nothing granted, no rows', () {
    expect(permissionsInUse(_site, const {}), isEmpty);
  });

  test("stored grants and while-open grants, in 2a's order", () {
    final site = _site.copyWith(allowClipboard: true, allowCamera: true);
    final rows = permissionsInUse(site, {PermissionKind.location, PermissionKind.microphone});
    expect(rows.map((r) => (r.kind, r.whileOpen)), [
      (PermissionKind.camera, false),
      (PermissionKind.microphone, true),
      (PermissionKind.location, true),
      (PermissionKind.clipboard, false),
    ]);
  });

  test('a stored grant wins over a session grant of the same kind', () {
    final rows = permissionsInUse(_site.copyWith(allowCamera: true), {PermissionKind.camera});
    expect(rows.single.whileOpen, isFalse);
  });
}

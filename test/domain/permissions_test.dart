import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/permissions.dart';

void main() {
  test('microphone phrase completes the spec sentence exactly', () {
    expect(
      'meet.example.com wants ${PermissionKind.microphone.phrase}',
      'meet.example.com wants your microphone',
    );
  });

  test('every kind has a possessive phrase', () {
    expect(PermissionKind.camera.phrase, 'your camera');
    expect(PermissionKind.microphone.phrase, 'your microphone');
    expect(PermissionKind.location.phrase, 'your location');
    expect(PermissionKind.clipboard.phrase, 'your clipboard');
  });

  test('there are exactly three decisions and none of them persists', () {
    expect(PermissionDecision.values, [
      PermissionDecision.allowOnce,
      PermissionDecision.allowWhileOpen,
      PermissionDecision.keepBlocked,
    ]);
  });
}

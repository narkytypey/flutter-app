import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:container/data/services/app_database.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('vault-store'));
  tearDown(() => dir.delete(recursive: true));

  test('removes the store and every SQLite sidecar beside it', () async {
    final path = '${dir.path}/store-1.db';
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      File('$path$suffix').writeAsStringSync('x');
    }
    final unrelated = File('${dir.path}/store-2.db')..writeAsStringSync('keep');

    await deleteVaultStore(path);

    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      expect(File('$path$suffix').existsSync(), isFalse, reason: 'store$suffix');
    }
    expect(unrelated.existsSync(), isTrue);
  });

  test('is a no-op when nothing is there', () async {
    await deleteVaultStore('${dir.path}/store-1.db');
  });
}

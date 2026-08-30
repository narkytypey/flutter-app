import 'dart:convert';
import 'dart:typed_data';

import 'app_database.dart';

/// Opens a vault's store under its data key. The key is passed as base64
/// because SQLCipher takes a passphrase string; it is never derived from
/// anything the user typed, only unwrapped.
Future<AppDatabase> openEncrypted({
  required String path,
  required Uint8List dataKey,
}) {
  return AppDatabase.open(path: path, password: base64Encode(dataKey));
}

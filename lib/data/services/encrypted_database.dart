import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite_sqlcipher/sqflite.dart' show DatabaseFactory;

import '../repositories/filter_list_repository_sqlite.dart' show syncBundledFilterLists;
import 'app_database.dart';
import 'bundled_filter_lists.dart';

/// Opens a vault's store under its data key. The key is passed as base64
/// because SQLCipher takes a passphrase string; it is never derived from
/// anything the user typed, only unwrapped.
///
/// Then brings the vault's filter lists into line with the bundle. A failure
/// there is logged and the vault still opens: a packaging defect must not
/// lock the owner out. Nothing loads unfiltered because of it — opening a
/// site reads the bundle itself and fails if it cannot.
Future<AppDatabase> openEncrypted({
  required String path,
  required Uint8List dataKey,
  BundledFilterRules? filterRules,
  DatabaseFactory? factory,
}) async {
  final database = await AppDatabase.open(
    path: path,
    password: base64Encode(dataKey),
    factory: factory,
  );
  try {
    await syncBundledFilterLists(database, filterRules ?? defaultBundledFilterRules);
  } catch (error) {
    debugPrint('Filter lists not synced: $error');
  }
  return database;
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/services/android_crypto_service.dart';
import 'data/services/secure_window.dart';
import 'data/services/vault_store.dart';
import 'ui/features/lock/views/lock_body.dart' show LockMood;
import 'ui/features/shell/view_models/session_controller.dart';
import 'ui/features/shell/views/app_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await const SecureWindow().neutraliseRecents();

  const crypto = AndroidCryptoService();
  final documents = await getApplicationDocumentsDirectory();
  final store = VaultStore(crypto, File(p.join(documents.path, 'meta.bin')));

  // A vault already exists but nothing is open: this is a cold start, not a
  // return from backgrounding, so the mood is `normal` — never
  // `afterTimeout`, which would falsely claim sessions were just wiped.
  final initial = await store.exists
      ? SessionLocked(mood: LockMood.normal, gate: await store.gate())
      : const SessionUnconfigured();

  runApp(ProviderScope(
    overrides: [
      cryptoServiceProvider.overrideWithValue(crypto),
      documentsDirectoryProvider.overrideWithValue(documents),
      vaultStoreProvider.overrideWithValue(store),
      initialSessionProvider.overrideWithValue(initial),
    ],
    child: const ContainerApp(home: AppGate()),
  ));
}

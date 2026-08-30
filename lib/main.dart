import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/services/app_database.dart';
import 'domain/models/vault.dart';
import 'ui/features/dashboard/views/dashboard_screen.dart';
import 'ui/features/dashboard/view_models/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final directory = await getApplicationDocumentsDirectory();
  // Plan 1 always opens VaultId.a. Plan 2 picks the vault from which PIN
  // unwrapped, and opens it with that vault's key.
  final database = await AppDatabase.open(
    path: p.join(directory.path, vaultFileName(VaultId.a)),
  );
  await seedIfEmpty(database);

  runApp(ProviderScope(
    overrides: [databaseProvider.overrideWithValue(database)],
    child: const ContainerApp(home: DashboardScreen()),
  ));
}

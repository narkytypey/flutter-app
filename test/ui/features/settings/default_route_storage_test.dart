import 'package:container/data/repositories/decoy_provisioner.dart' show resyncDecoy;
import 'package:container/data/repositories/settings_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/proxy_route.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/dashboard/view_models/providers.dart' show databaseProvider;
import 'package:container/ui/features/settings/view_models/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppDatabase> _vault() =>
    AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);

ProviderContainer _over(AppDatabase database) {
  final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(database)]);
  addTearDown(container.dispose);
  return container;
}

const _socks = ProxyRoute(
    mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050, user: 'alice', password: 'pw');

void main() {
  setUpAll(sqfliteFfiInit);

  test('the default route is Direct until one is chosen', () async {
    final database = await _vault();
    addTearDown(database.close);
    expect(await _over(database).read(defaultRouteProvider.future), ProxyRoute.direct);
  });

  test('a chosen route is stored in the open vault and read back', () async {
    final database = await _vault();
    addTearDown(database.close);
    final container = _over(database);

    await container.read(settingsControllerProvider).setDefaultRoute(_socks);

    expect(await container.read(defaultRouteProvider.future), _socks);
    expect(await SqliteSettingsRepository(database).getString(defaultRouteSettingKey),
        _socks.toStored());
  });

  test('each vault has its own', () async {
    final real = await _vault();
    final decoy = await _vault();
    addTearDown(real.close);
    addTearDown(decoy.close);

    await _over(real).read(settingsControllerProvider).setDefaultRoute(_socks);

    expect(await _over(decoy).read(defaultRouteProvider.future), ProxyRoute.direct);
  });

  test('decoy re-sync does not copy it: it is a setting, not a site', () async {
    final real = await _vault();
    final decoy = await _vault();
    addTearDown(real.close);
    addTearDown(decoy.close);
    await _over(real).read(settingsControllerProvider).setDefaultRoute(_socks);

    await resyncDecoy(from: real, into: decoy);

    expect(await SqliteSettingsRepository(decoy).getString(defaultRouteSettingKey), isNull);
  });
}

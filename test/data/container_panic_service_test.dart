import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/data/services/container_panic_service.dart';
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/site.dart';

Site _site(String id) => Site(
      id: id,
      workspaceId: 'w1',
      name: id,
      monogram: 'X',
      url: 'https://example.com/$id',
      profileId: newProfileId(),
    );

void main() {
  test('every container is destroyed before anything else is', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));

    final order = <String>[];
    final service = ContainerPanicService(
      engine: engine,
      closeDatabase: () async => order.add('close:${engine.wipedAll}'),
      destroyVaults: () async => order.add('destroy:${engine.wipedAll}'),
      destroyBiometricKey: () async => order.add('biometric:${engine.wipedAll}'),
    );

    await service.trigger();

    expect(engine.wipedAll, isTrue);
    // All three later steps observed the profiles as already gone.
    expect(order, ['close:true', 'destroy:true', 'biometric:true']);
  });

  test('live sessions are closed before the profiles are wiped', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));

    await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async {},
      destroyBiometricKey: () async {},
    ).trigger();

    expect(engine.closed, ['a', 'b']);
  });

  test('the report counts what was destroyed', () async {
    final engine = FakeContainerEngine();
    await engine.open(_site('a'));
    await engine.open(_site('b'));
    await engine.open(_site('c'));

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async {},
      destroyBiometricKey: () async {},
    ).trigger();

    expect(report.sessionsDestroyed, 3);
  });

  // What the device actually did (2026-09-28): WebView refuses to delete a
  // profile the process has loaded, `wipeAll` threw, and panic stopped
  // before a single key was destroyed — failing open, with the vault intact.
  test('a wipe that throws still destroys the database, vaults and key', () async {
    final engine = _WipeAllThrows();
    await engine.open(_site('a'));
    final destroyed = <String>[];

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async => destroyed.add('database'),
      destroyVaults: () async => destroyed.add('vaults'),
      destroyBiometricKey: () async => destroyed.add('biometric'),
    ).trigger();

    expect(destroyed, ['database', 'vaults', 'biometric']);
    expect(report.sessionsDestroyed, 1);
  });

  test('a close that throws still wipes, and still destroys the keys', () async {
    final engine = _CloseThrows();
    await engine.open(_site('a'));
    await engine.open(_site('b'));
    var vaultsDestroyed = false;

    await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async => vaultsDestroyed = true,
      destroyBiometricKey: () async {},
    ).trigger();

    expect(engine.wipedAll, isTrue);
    expect(vaultsDestroyed, isTrue);
  });

  test('panic on a cold app with nothing open still completes', () async {
    final engine = FakeContainerEngine();
    var destroyed = false;

    final report = await ContainerPanicService(
      engine: engine,
      closeDatabase: () async {},
      destroyVaults: () async => destroyed = true,
      destroyBiometricKey: () async {},
    ).trigger();

    expect(report.sessionsDestroyed, 0);
    expect(destroyed, isTrue);
  });
}

class _WipeAllThrows extends FakeContainerEngine {
  @override
  Future<void> wipeAll() async => throw PlatformException(
      code: 'engine', message: 'Cannot delete in-use profile 0a396e81');
}

class _CloseThrows extends FakeContainerEngine {
  @override
  Future<void> close(String siteId) async =>
      throw PlatformException(code: 'engine', message: 'close failed');
}

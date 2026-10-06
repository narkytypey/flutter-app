import 'dart:async';

import 'package:container/ui/core/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every test starts dark (Plan 24): the palette, and for a widget test the
/// phone's system setting, so `ContainerApp` follows it into dark too. A test
/// that wants light sets it itself.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    C.use(Brightness.dark);
    final binding = _testBinding();
    binding?.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
  });
  await testMain();
}

/// The test binding if one is already up. Pure `test()` files never start
/// one, and this must not start one for them.
TestWidgetsFlutterBinding? _testBinding() {
  try {
    final binding = WidgetsBinding.instance;
    return binding is TestWidgetsFlutterBinding ? binding : null;
  } catch (_) {
    return null;
  }
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:container/ui/features/lock/view_models/lock_controller.dart';

void main() {
  test('digits accumulate and notify on every key', () {
    var notifications = 0;
    final controller = LockController(onSubmit: (_) {});
    controller.addListener(() => notifications++);

    controller.onKey('1');
    controller.onKey('2');

    expect(controller.value.filled, 2);
    expect(notifications, 2);
  });

  test('backspace removes the last digit', () {
    final controller = LockController(onSubmit: (_) {});
    controller.onKey('1');
    controller.onKey('2');
    controller.onKey('⌫');

    expect(controller.value.filled, 1);
  });

  test('backspace on an empty buffer does nothing', () {
    final controller = LockController(onSubmit: (_) {});
    controller.onKey('⌫');

    expect(controller.value.filled, 0);
  });

  test('a sixth digit submits the PIN and clears the buffer', () {
    final submitted = <String>[];
    final controller = LockController(onSubmit: submitted.add);

    for (final key in ['1', '2', '3', '4', '5', '6']) {
      controller.onKey(key);
    }

    expect(submitted, ['123456']);
    expect(controller.value.filled, 0);
  });

  test('a seventh key after a submit starts a fresh PIN', () {
    final submitted = <String>[];
    final controller = LockController(onSubmit: submitted.add);
    for (final key in ['1', '2', '3', '4', '5', '6']) {
      controller.onKey(key);
    }
    controller.onKey('9');

    expect(controller.value.filled, 1);
    expect(submitted, ['123456']);
  });

  test('keys are ignored while a submitted PIN is still being checked',
      () async {
    final submitted = <String>[];
    final pending = Completer<void>();
    final controller = LockController(onSubmit: (pin) {
      submitted.add(pin);
      return pending.future;
    });
    for (final key in ['1', '2', '3', '4', '5', '6']) {
      controller.onKey(key);
    }
    expect(controller.busy, isTrue);

    // A second six digits typed during the check would be a second attempt.
    for (final key in ['9', '9', '9', '9', '9', '9']) {
      controller.onKey(key);
    }
    expect(submitted, ['123456']);
    expect(controller.value.filled, 0);

    pending.complete();
    await Future<void>.delayed(Duration.zero);
    expect(controller.busy, isFalse);
    controller.onKey('7');
    expect(controller.value.filled, 1);
  });
}

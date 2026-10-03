import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:container/domain/models/lock_state.dart';
import 'package:container/ui/features/shell/view_models/lifecycle_controller.dart';

void main() {
  late List<ReturnDestination> returns;
  late List<bool> masks;
  late LifecycleController lifecycle;

  setUp(() {
    returns = [];
    masks = [];
    lifecycle = LifecycleController(
      policy: AutoLockPolicy.oneMinute,
      onMaskChanged: masks.add,
      onReturn: returns.add,
      clock: () => DateTime(2026, 10, 3),
    );
  });

  test('losing focus masks at once and a return goes through the lock', () {
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(masks, [true, false]);
    expect(returns, [ReturnDestination.board]);
  });

  test("the app's own permission dialog is not leaving the app", () {
    // Android's runtime permission dialog pauses the Activity: without this,
    // allowing a site's camera locked the vault and closed the site.
    lifecycle.systemDialogShowing = true;
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    lifecycle.systemDialogShowing = false;
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(returns, isEmpty);
    expect(masks.where((m) => m), isEmpty);
  });

  test('the dialog may be answered after the app resumes', () {
    lifecycle.systemDialogShowing = true;
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    lifecycle.systemDialogShowing = false;
    expect(returns, isEmpty);
  });

  test('going home with the dialog up still locks', () {
    lifecycle.systemDialogShowing = true;
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.hidden);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.inactive);
    lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(masks.first, isTrue);
    expect(returns, [ReturnDestination.board]);
  });
}

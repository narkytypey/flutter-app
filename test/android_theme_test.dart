import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app is dark only, and WebView darkens a page ("Force dark mode", 6c)
/// only under a dark Android theme. A light theme in `values/` made Force
/// dark do nothing on any phone in light mode (seen 2026-10-05).
void main() {
  test('the Android themes are dark whatever the OS mode', () {
    final styles = File('android/app/src/main/res/values/styles.xml').readAsStringSync();
    expect(styles, isNot(contains('Theme.Light')));
    expect(styles, contains('name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar"'));
  });

  test("the application's own context has the dark theme", () {
    // Every page's WebView is made on the application's context.
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final application = RegExp(r'<application[^>]*>').firstMatch(manifest)!.group(0)!;
    expect(application, contains('android:theme="@style/NormalTheme"'));
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A release build is shrunk by R8, which renamed `TorService`'s fields.
/// Tor's native code looks them up by name, so on a phone every Tor start
/// died with `NoSuchFieldError: no "J" field "torConfiguration"` (seen
/// 2026-10-09). tor-android ships no keep rules of its own; Flutter's Gradle
/// plugin hands R8 `android/app/proguard-rules.pro` when it exists.
void main() {
  test("R8 keeps tor-android's JNI class whole", () {
    final rules = File('android/app/proguard-rules.pro').readAsStringSync();
    expect(rules, contains('-keep class org.torproject.jni.** { *; }'));
  });
}

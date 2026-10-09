# Release builds are shrunk by R8; Flutter's Gradle plugin adds this file.

# Tor's native code reads TorService's fields and calls its methods by name
# (JNI), and tor-android ships no keep rules. Renamed, every Tor start died
# with NoSuchFieldError "torConfiguration" (seen on a phone, 2026-10-09).
-keep class org.torproject.jni.** { *; }

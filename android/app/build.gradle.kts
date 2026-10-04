plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mono.container"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mono.container"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 29          // was 26; multi-profile WebView needs it
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")
    implementation("androidx.webkit:webkit:1.12.0")
    implementation("androidx.biometric:biometric:1.1.0")
    // Built-in Tor (spec §4): Tor itself, in process, and the broadcasts its service sends.
    implementation("info.guardianproject:tor-android:0.4.9.13")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// tor-android 0.4.9.13 declares minCompileSdk 37; this project compiles against 36
// (AGP 9.1.0's maximum; SDK 37 is not installed). tor-android's own code references no
// API 37 symbol (the debug build links). This disables the AAR metadata check for every
// library, so it applies only while compileSdk is below 37: at 37 it switches itself off
// and the check runs again. Delete the block then.
if ((android.compileSdk ?: 0) < 37) {
    tasks.configureEach {
        if (name.startsWith("check") && name.endsWith("AarMetadata")) enabled = false
    }
}

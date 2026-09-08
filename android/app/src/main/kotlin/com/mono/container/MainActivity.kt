package com.mono.container

import android.os.Bundle
import android.view.WindowManager
import com.mono.container.engine.ContainerViewFactory
import com.mono.container.engine.EngineChannel
import com.mono.container.engine.ProfileManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Set before the Flutter view exists. A flag toggled per screen has a
        // window in which it is off.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CryptoPlugin.CHANNEL)
            .setMethodCallHandler(CryptoPlugin())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SecureWindowPlugin.CHANNEL)
            .setMethodCallHandler(SecureWindowPlugin(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BiometricPlugin.CHANNEL)
            .setMethodCallHandler(BiometricPlugin(this))

        val profiles = ProfileManager()
        val engine = EngineChannel(applicationContext, profiles)
        engine.attach(flutterEngine.dartExecutor.binaryMessenger)

        flutterEngine.platformViewsController.registry.registerViewFactory(
            EngineChannel.VIEW_TYPE,
            ContainerViewFactory(engine, profiles),
        )
    }
}

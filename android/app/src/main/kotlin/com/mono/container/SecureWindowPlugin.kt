package com.mono.container

import android.app.Activity
import android.app.ActivityManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps the recents entry neutral (spec `9a`: "neutral name, blank card, no
 * page title").
 *
 * FLAG_SECURE, set in MainActivity for the process lifetime, already blanks
 * the preview and blocks screenshots. This only stops the task description
 * from ever carrying a page title.
 */
class SecureWindowPlugin(private val activity: Activity) :
    MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "neutraliseRecents" -> {
                activity.setTaskDescription(
                    ActivityManager.TaskDescription.Builder()
                        .setLabel("Container")
                        .build()
                )
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "com.mono.container/window"
    }
}

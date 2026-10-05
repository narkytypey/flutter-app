package com.mono.container

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Listens to the accelerometer only between `start` and `stop`, which Dart
 * calls while a vault is open and its "Trigger by flipping face down" is on,
 * and tells Dart `flipped` when [FlipDetector] fires. Dart then runs the same
 * panic as the button. `start` replies false on a phone with no
 * accelerometer. Android stops delivering it to an app in the background, so
 * this only ever fires while the app is on screen.
 */
class FlipPanicPlugin(context: Context, private val channel: MethodChannel) :
    MethodChannel.MethodCallHandler, SensorEventListener {

    private val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
    private var detector: FlipDetector? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> result.success(start())
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun start(): Boolean {
        if (detector != null) return true
        val accelerometer = sensors?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return false
        detector = FlipDetector()
        // Events arrive on the main thread, where the channel must be called.
        return sensors.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI).also {
            if (!it) detector = null
        }
    }

    /** Also called when the Flutter engine is cleaned up (`MainActivity`). */
    fun stop() {
        sensors?.unregisterListener(this)
        detector = null
    }

    override fun onSensorChanged(event: SensorEvent) {
        val detector = detector ?: return
        val (x, y, z) = Triple(event.values[0], event.values[1], event.values[2])
        if (detector.onSample(event.timestamp / 1_000_000, x, y, z)) {
            channel.invokeMethod("flipped", null)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    companion object {
        const val CHANNEL = "com.mono.container/flip"
    }
}

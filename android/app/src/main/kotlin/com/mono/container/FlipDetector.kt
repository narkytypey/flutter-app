package com.mono.container

/**
 * Settings' "Trigger by flipping face down" (user's ruling, 2026-09-30):
 * fires once when the phone has lain face down for [holdMs] without a break,
 * then stays silent until it has come back up, so one flip is one panic.
 *
 * Face down means gravity pulls along the screen's back: the accelerometer's
 * z reads [FACE_DOWN_Z] or less (flat is about -9.8 m/s²; the threshold allows
 * about 35 degrees of tilt). Pure, so the JVM tests drive it with readings.
 */
class FlipDetector(private val holdMs: Long = 2_000) {
    private var downSince: Long? = null
    private var armed = true

    /** One accelerometer reading, in m/s². True exactly when it fires. */
    fun onSample(timeMs: Long, x: Float, y: Float, z: Float): Boolean {
        if (!armed) {
            if (z > REARM_Z) armed = true
            return false
        }
        if (z > FACE_DOWN_Z) {
            downSince = null
            return false
        }
        val since = downSince ?: timeMs.also { downSince = it }
        if (timeMs - since < holdMs) return false
        armed = false
        downSince = null
        return true
    }

    companion object {
        const val FACE_DOWN_Z = -8.0f

        /** Back up: screen up, or on its edge. */
        const val REARM_Z = 0f
    }
}

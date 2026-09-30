package com.mono.container

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/** Settings' "Trigger by flipping face down" (user's ruling, 2026-09-30). */
class FlipDetectorTest {

    private val faceDown = floatArrayOf(0.2f, -0.1f, -9.8f)
    private val faceUp = floatArrayOf(0.1f, 0.3f, 9.8f)
    private val onEdge = floatArrayOf(9.8f, 0f, 0.1f)

    /** Feeds [reading] every 200 ms from [fromMs] to [toMs] inclusive; returns the times it fired. */
    private fun FlipDetector.feed(reading: FloatArray, fromMs: Long, toMs: Long): List<Long> =
        (fromMs..toMs step 200).filter { onSample(it, reading[0], reading[1], reading[2]) }

    @Test fun `face down for two seconds fires once`() {
        val detector = FlipDetector()
        assertEquals(listOf(2_000L), detector.feed(faceDown, 0, 6_000))
    }

    @Test fun `face down for less than two seconds does not fire`() {
        val detector = FlipDetector()
        assertEquals(emptyList<Long>(), detector.feed(faceDown, 0, 1_800))
        assertEquals(emptyList<Long>(), detector.feed(faceUp, 2_000, 4_000))
    }

    @Test fun `turning up in between starts the two seconds again`() {
        val detector = FlipDetector()
        assertEquals(emptyList<Long>(), detector.feed(faceDown, 0, 1_600))
        assertFalse(detector.onSample(1_800, faceUp[0], faceUp[1], faceUp[2]))
        assertEquals(listOf(4_000L), detector.feed(faceDown, 2_000, 4_400))
    }

    @Test fun `after firing it waits for the phone to come back up before firing again`() {
        val detector = FlipDetector()
        assertEquals(listOf(2_000L), detector.feed(faceDown, 0, 2_000))
        assertEquals(emptyList<Long>(), detector.feed(faceDown, 2_200, 10_000))
        assertEquals(emptyList<Long>(), detector.feed(faceUp, 10_200, 10_400))
        assertEquals(listOf(12_600L), detector.feed(faceDown, 10_600, 13_000))
    }

    @Test fun `on its edge, face up, or tilted less than face down, it never fires`() {
        val detector = FlipDetector()
        assertEquals(emptyList<Long>(), detector.feed(onEdge, 0, 10_000))
        assertEquals(emptyList<Long>(), detector.feed(faceUp, 10_200, 20_000))
        // Tilted about 45 degrees past vertical: z is about -7 m/s², not face down.
        assertEquals(emptyList<Long>(), detector.feed(floatArrayOf(0f, 7f, -7f), 20_200, 30_000))
    }
}

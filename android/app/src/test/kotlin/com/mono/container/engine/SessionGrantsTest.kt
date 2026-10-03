package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SessionGrantsTest {
    // WebView's names, as literals: the main code uses the constants.
    private val video = "android.webkit.resource.VIDEO_CAPTURE"
    private val audio = "android.webkit.resource.AUDIO_CAPTURE"

    @Test fun `each grant has Dart's PermissionKind name`() {
        assertEquals("camera", SessionGrants.kindOf(video))
        assertEquals("microphone", SessionGrants.kindOf(audio))
        assertEquals("location", SessionGrants.kindOf("geolocation"))
        assertNull(SessionGrants.kindOf("android.webkit.resource.MIDI_SYSEX"))
    }

    @Test fun `a kind names its resource, and nothing else names one`() {
        assertEquals(video, SessionGrants.resourceFor("camera"))
        assertEquals(audio, SessionGrants.resourceFor("microphone"))
        assertEquals("geolocation", SessionGrants.resourceFor("location"))
        assertNull("clipboard is never a session grant", SessionGrants.resourceFor("clipboard"))
        assertNull(SessionGrants.resourceFor("anything"))
    }

    @Test fun `the session map lists kinds in 2a's order`() {
        assertEquals(listOf("camera", "microphone", "location"),
            SessionGrants.kindsOf(setOf("geolocation", audio, video)))
        assertEquals(emptyList<String>(), SessionGrants.kindsOf(emptySet()))
    }

    @Test fun `revoking takes away only the kind named`() {
        val grants = mutableSetOf(video, audio, "geolocation")
        assertEquals(true, SessionGrants.revoke(grants, "microphone"))
        assertEquals(setOf(video, "geolocation"), grants)
        assertEquals("already gone", false, SessionGrants.revoke(grants, "microphone"))
        assertEquals(false, SessionGrants.revoke(grants, "clipboard"))
    }
}

package com.mono.container.engine

import android.Manifest
import android.webkit.PermissionRequest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A camera or microphone grant reaches the page only if Android lets the app
 * use the device: without `CAMERA` the camera service refuses (`Permission
 * Denial: can't use the camera`) and the page sees `NotReadableError`.
 */
class CapturePermissionsTest {

    private val camera = PermissionRequest.RESOURCE_VIDEO_CAPTURE
    private val mic = PermissionRequest.RESOURCE_AUDIO_CAPTURE

    @Test fun `each capture resource needs its own Android permission`() {
        assertEquals(listOf(Manifest.permission.CAMERA), androidPermissionsFor(listOf(camera)))
        assertEquals(
            listOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO),
            androidPermissionsFor(listOf(camera, mic)),
        )
        assertEquals(emptyList<String>(), androidPermissionsFor(listOf(PermissionRequest.RESOURCE_MIDI_SYSEX)))
    }

    @Test fun `only resources whose permission Android holds are granted`() {
        val held = setOf(Manifest.permission.RECORD_AUDIO)
        assertEquals(listOf(mic), grantableResources(listOf(camera, mic)) { it in held })
        assertEquals(emptyList<String>(), grantableResources(listOf(camera)) { it in held })
    }

    @Test fun `a resource that needs no Android permission passes through`() {
        assertEquals(
            listOf(PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID),
            grantableResources(listOf(PermissionRequest.RESOURCE_PROTECTED_MEDIA_ID)) { false },
        )
    }

    @Test fun `block WebRTC removes peer connections but leaves capture to the ask`() {
        assertTrue(WEB_RTC_BLOCK_JS.contains("delete window.RTCPeerConnection"))
        assertTrue(WEB_RTC_BLOCK_JS.contains("delete window.webkitRTCPeerConnection"))
        assertFalse(WEB_RTC_BLOCK_JS.contains("getUserMedia"))
    }

    @Test fun `block WebRTC also strips a child frame's window as the page reaches it`() {
        assertTrue(WEB_RTC_BLOCK_JS.contains("HTMLIFrameElement"))
        assertTrue(WEB_RTC_BLOCK_JS.contains("'contentWindow','contentDocument'"))
        // The hook keeps the platform's own getter: it never replaces a frame.
        assertTrue(WEB_RTC_BLOCK_JS.contains("d.get.call(this)"))
    }
}

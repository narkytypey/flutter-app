package com.mono.container.engine

import android.webkit.PermissionRequest

/**
 * A session's "allow while this site is open" grants (`6a`), named the way
 * Dart's `PermissionKind` names them, for `6c`'s permissions (privacy-controls
 * spec §3). Clipboard is never one: it is only ever a stored grant.
 */
object SessionGrants {
    const val GEOLOCATION = "geolocation"

    private val order = listOf("camera", "microphone", "location")

    fun kindOf(resource: String): String? = when (resource) {
        PermissionRequest.RESOURCE_VIDEO_CAPTURE -> "camera"
        PermissionRequest.RESOURCE_AUDIO_CAPTURE -> "microphone"
        GEOLOCATION -> "location"
        else -> null
    }

    fun resourceFor(kind: String): String? = when (kind) {
        "camera" -> PermissionRequest.RESOURCE_VIDEO_CAPTURE
        "microphone" -> PermissionRequest.RESOURCE_AUDIO_CAPTURE
        "location" -> GEOLOCATION
        else -> null
    }

    fun kindsOf(grants: Set<String>): List<String> =
        order.filter { kind -> resourceFor(kind) in grants }

    /** Removes [kind]'s grant; true when there was one to remove. */
    fun revoke(grants: MutableSet<String>, kind: String): Boolean {
        val resource = resourceFor(kind) ?: return false
        return grants.remove(resource)
    }
}

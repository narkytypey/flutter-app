package com.mono.container.engine

import android.Manifest
import android.webkit.PermissionRequest

/**
 * The Android runtime permissions [resources] need before a grant is any use.
 * WebView passes a granted capture resource to the camera or audio service,
 * which refuses an app that does not hold the permission (the page then sees
 * `NotReadableError`).
 */
internal fun androidPermissionsFor(resources: List<String>): List<String> =
    resources.mapNotNull(::androidPermissionFor).distinct()

private fun androidPermissionFor(resource: String): String? = when (resource) {
    PermissionRequest.RESOURCE_VIDEO_CAPTURE -> Manifest.permission.CAMERA
    PermissionRequest.RESOURCE_AUDIO_CAPTURE -> Manifest.permission.RECORD_AUDIO
    else -> null
}

/** Of [resources], those the app can actually hand the page: a capture
 *  resource only while Android holds its permission. */
internal fun grantableResources(resources: List<String>, held: (String) -> Boolean): List<String> =
    resources.filter { resource -> androidPermissionFor(resource)?.let(held) ?: true }

/**
 * Android's runtime permission dialog, for a site the person has just
 * allowed (`6a`) or pre-allowed (a stored `allow*` flag). Only what the app
 * does not hold yet is asked, one dialog at a time. A waiter is answered once
 * its permissions have been asked, whatever the person chose: it reads what
 * is held, through [held], itself. Main thread only.
 */
class PermissionAsks(
    private val held: (String) -> Boolean,
    /** Shows the dialog; [onResult] must follow, once, when it is answered. */
    private val launch: (Array<String>) -> Unit,
) {
    private class Waiter(val permissions: List<String>, val then: () -> Unit)

    private val waiting = mutableListOf<Waiter>()
    /** Asked since the queue was last empty. */
    private val asked = mutableSetOf<String>()
    private var inFlight = false

    fun ask(permissions: List<String>, then: () -> Unit) {
        if (permissions.all(held)) return then()
        waiting += Waiter(permissions, then)
        launchMissing()
    }

    fun onResult() {
        inFlight = false
        val done = waiting.filter { waiter -> waiter.permissions.all { held(it) || it in asked } }
        waiting.removeAll(done)
        for (waiter in done) waiter.then()
        if (waiting.isEmpty()) asked.clear() else launchMissing()
    }

    /** The engine is going away: no one is left to answer. */
    fun cancelAll() {
        waiting.clear()
        asked.clear()
    }

    private fun launchMissing() {
        if (inFlight) return
        val missing = waiting.flatMap { it.permissions }.filter { !held(it) && it !in asked }.distinct()
        if (missing.isEmpty()) return
        asked += missing
        inFlight = true
        launch(missing.toTypedArray())
    }
}

package com.mono.container.engine

import android.webkit.WebView

object Shields {
    fun apply(webView: WebView, config: SiteConfig, onFingerprintNoiseApplied: () -> Unit = {}) {
        val js = buildString {
            if (config.blockWebRtc) {
                // WebRTC never reaches the interceptor — it leaks over UDP past
                // any proxy. Removing the constructors is the only fix.
                append(
                    "delete window.RTCPeerConnection;" +
                    "delete window.webkitRTCPeerConnection;" +
                    "navigator.mediaDevices && (navigator.mediaDevices.getUserMedia=" +
                    "()=>Promise.reject(new DOMException('Blocked','NotAllowedError')));"
                )
            }
            // WebSocket does not reach shouldInterceptRequest either.
            append("window.WebSocket=function(){throw new Error('Blocked');};")
            if (config.antiFingerprinting) {
                append(webView.context.assets.open("shields/fingerprint.js")
                    .bufferedReader().readText())
                onFingerprintNoiseApplied()
            }
            if (config.customCss.isNotEmpty()) {
                append("document.addEventListener('DOMContentLoaded',()=>{" +
                    "const s=document.createElement('style');" +
                    "s.textContent=${config.customCss.asJsString()};" +
                    "document.head.appendChild(s);});")
            }
            append(config.customJs)
        }
        androidx.webkit.WebViewCompat.addDocumentStartJavaScript(
            webView, js, setOf("*")
        )
    }

    /**
     * A stored `allow*` flag is a pre-declaration made in the Add Site form
     * (`2a`); it silently grants with no live prompt. A site whose stored
     * flag is off but which asks anyway gets [onAsk] instead of an
     * unconditional deny — Plan 6 hands the decision to `PermissionRequestSheet`
     * (`6a`) rather than the platform refusing on the user's behalf.
     */
    fun chromeClientFor(
        config: SiteConfig,
        session: Session,
        onAsk: (PendingPermission) -> String,
    ) = object : android.webkit.WebChromeClient() {
        override fun onPermissionRequest(request: android.webkit.PermissionRequest) {
            val granted = mutableListOf<String>()
            val toAsk = mutableListOf<String>()
            for (resource in request.resources) {
                val storedAllow = when (resource) {
                    android.webkit.PermissionRequest.RESOURCE_VIDEO_CAPTURE -> config.allowCamera
                    android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE -> config.allowMicrophone
                    else -> false
                }
                val alreadyGrantedThisSession = session.sessionGrants.contains(resource)
                if (storedAllow || alreadyGrantedThisSession) granted.add(resource) else toAsk.add(resource)
            }
            if (toAsk.isEmpty()) {
                if (granted.isEmpty()) request.deny() else request.grant(granted.toTypedArray())
                return
            }
            val requestId = onAsk(PendingPermission.Hardware(
                requestId = "", request = request, resources = request.resources.toList(),
            ))
            session.pendingPermissions[requestId] =
                PendingPermission.Hardware(requestId, request, request.resources.toList())
        }

        override fun onGeolocationPermissionsShowPrompt(
            origin: String, callback: android.webkit.GeolocationPermissions.Callback,
        ) {
            if (config.allowLocation || session.sessionGrants.contains("geolocation")) {
                callback.invoke(origin, true, false)
                return
            }
            val requestId = onAsk(PendingPermission.Geolocation(requestId = "", origin = origin, callback = callback))
            session.pendingPermissions[requestId] =
                PendingPermission.Geolocation(requestId, origin, callback)
        }
    }
}

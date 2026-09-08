package com.mono.container.engine

import android.webkit.WebView

object Shields {
    fun apply(webView: WebView, config: SiteConfig) {
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

    /** Denies every hardware permission the site was not granted. */
    fun chromeClientFor(config: SiteConfig) = object : android.webkit.WebChromeClient() {
        override fun onPermissionRequest(request: android.webkit.PermissionRequest) {
            val allowed = request.resources.filter { resource ->
                when (resource) {
                    android.webkit.PermissionRequest.RESOURCE_VIDEO_CAPTURE -> config.allowCamera
                    android.webkit.PermissionRequest.RESOURCE_AUDIO_CAPTURE -> config.allowMicrophone
                    else -> false
                }
            }
            if (allowed.isEmpty()) request.deny() else request.grant(allowed.toTypedArray())
        }

        override fun onGeolocationPermissionsShowPrompt(
            origin: String, callback: android.webkit.GeolocationPermissions.Callback,
        ) = callback.invoke(origin, config.allowLocation, false)
    }
}

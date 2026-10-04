package com.mono.container.engine

import android.webkit.WebView

/**
 * WebRTC never reaches the interceptor — it leaks over UDP past any proxy.
 * Removing the constructors is the only fix. Camera and microphone are left
 * to the site's `allow*` flags and `6a`: a capture stream sends nothing by
 * itself, and stubbing `getUserMedia` here refused every ask before it
 * reached the app.
 */
internal const val WEB_RTC_BLOCK_JS =
    "delete window.RTCPeerConnection;" +
    "delete window.webkitRTCPeerConnection;"

/**
 * Built-in Tor spec §10 (accepted leak a2): a Tor page's dns-prefetch hints
 * are looked up through the phone's own DNS. This turns the page's DNS
 * prefetching off before it parses, and removes each hint as it appears. The
 * HTML preload scanner and `Link:` headers act before any script, so it
 * narrows the gap at most; Step 8 of the plan measures by how much.
 */
internal const val TOR_DNS_HINTS_JS =
    "(function(){try{" +
    "var m=document.createElement('meta');m.httpEquiv='x-dns-prefetch-control';m.content='off';" +
    "var p=document.head||document.documentElement;if(p){p.appendChild(m);}" +
    "var q='link[rel~=\"dns-prefetch\" i]';" +
    "var drop=function(n){if(n.matches&&n.matches(q)){n.remove();}else if(n.querySelectorAll){n.querySelectorAll(q).forEach(function(e){e.remove();});}};" +
    "new MutationObserver(function(ms){ms.forEach(function(r){r.addedNodes.forEach(drop);});})" +
    ".observe(document,{childList:true,subtree:true});" +
    "}catch(e){}})();"

/** The Tor-only part of a page's document-start script. */
fun torDocumentStartJs(config: SiteConfig): String = if (config.proxyMode == "tor") TOR_DNS_HINTS_JS else ""

object Shields {
    fun apply(
        webView: WebView,
        config: SiteConfig,
        policy: SecurityPolicy = securityPolicyFor(config.securityLevel),
        onFingerprintNoiseApplied: () -> Unit = {},
    ) {
        // Safest: JavaScript is off, so no document-start script could run.
        if (!policy.documentStartScripts) return
        val js = buildString {
            if (policy.saferScript) {
                append(webView.context.assets.open("shields/safer.js").bufferedReader().readText())
            }
            if (config.blockWebRtc) append(WEB_RTC_BLOCK_JS)
            append(torDocumentStartJs(config))
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
        // Library scripts: one injection each, confined to the site's own
        // origin (Shields above runs everywhere). No origin, no scripts.
        val origin = originRuleFor(config.url) ?: return
        for (script in config.userScripts) {
            val source = UserScriptJs.wrap(script.kind, script.code, script.atDocumentStart) ?: continue
            androidx.webkit.WebViewCompat.addDocumentStartJavaScript(webView, source, setOf(origin))
        }
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
        onProgress: (Int) -> Unit = {},
        onTitle: (String?) -> Unit = {},
        /** `onCreateWindow` (tabs spec §3.1). True when the message was handled. */
        onNewWindow: (isUserGesture: Boolean, resultMsg: android.os.Message) -> Boolean = { _, _ -> false },
        /** The page's own `window.close()`. */
        onCloseWindow: () -> Unit = {},
        /** Grants hardware [resources] a stored `allow*` flag or a session
         *  grant pre-authorizes; the engine checks Android's permissions first. */
        onPreGranted: (request: android.webkit.PermissionRequest, resources: List<String>) -> Unit =
            { request, resources -> request.grant(resources.toTypedArray()) },
    ) = object : android.webkit.WebChromeClient() {
        override fun onProgressChanged(view: android.webkit.WebView, newProgress: Int) = onProgress(newProgress)

        override fun onReceivedTitle(view: android.webkit.WebView, title: String?) = onTitle(title)

        override fun onCreateWindow(
            view: android.webkit.WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: android.os.Message,
        ): Boolean = onNewWindow(isUserGesture, resultMsg)

        // `.invoke()`: a bare call would resolve to this override itself.
        override fun onCloseWindow(window: android.webkit.WebView) = onCloseWindow.invoke()

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
                if (granted.isEmpty()) request.deny() else onPreGranted(request, granted)
                return
            }
            val requestId = onAsk(PendingPermission.Hardware(
                requestId = "", request = request, toAsk = toAsk, granted = granted,
            ))
            session.pendingPermissions[requestId] =
                PendingPermission.Hardware(requestId, request, toAsk, granted)
        }

        override fun onGeolocationPermissionsShowPrompt(
            origin: String, callback: android.webkit.GeolocationPermissions.Callback,
        ) {
            if (config.allowLocation || session.sessionGrants.contains(SessionGrants.GEOLOCATION)) {
                callback.invoke(origin, true, false)
                return
            }
            val requestId = onAsk(PendingPermission.Geolocation(requestId = "", origin = origin, callback = callback))
            session.pendingPermissions[requestId] =
                PendingPermission.Geolocation(requestId, origin, callback)
        }
    }
}

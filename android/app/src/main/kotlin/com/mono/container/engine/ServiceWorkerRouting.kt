package com.mono.container.engine

import android.webkit.ServiceWorkerClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import androidx.webkit.ServiceWorkerClientCompat
import androidx.webkit.ServiceWorkerControllerCompat

/**
 * The places a service worker's requests can be intercepted: one controller
 * per WebView profile, plus the default profile's. [C] is the client type,
 * so the routing below is testable without Android.
 */
internal interface ServiceWorkerControllers<C> {
    fun setOnProfile(profileId: String, client: C)
    fun setOnDefaultProfile(client: C)
}

/**
 * Every site runs in its own profile, and a service worker's requests are
 * intercepted only by its profile's own controller. So the site's client goes
 * on the site's profile — [ServiceWorkerControllerCompat.getInstance] is the
 * *default* profile's controller, and setting a site's client there left
 * every site's service worker unintercepted, fetching straight past its
 * route. The default profile hosts no site, so it refuses everything.
 */
internal fun <C> routeServiceWorkers(controllers: ServiceWorkerControllers<C>, profileId: String, site: C, refuseAll: C) {
    controllers.setOnProfile(profileId, site)
    controllers.setOnDefaultProfile(refuseAll)
}

/** The Android side of [ServiceWorkerControllers]. UI thread only: it reads [ProfileManager]. */
internal class WebViewServiceWorkerControllers(
    private val profiles: ProfileManager,
) : ServiceWorkerControllers<(WebResourceRequest) -> WebResourceResponse?> {

    override fun setOnProfile(profileId: String, client: (WebResourceRequest) -> WebResourceResponse?) {
        profiles.profileFor(profileId).serviceWorkerController.setServiceWorkerClient(
            object : ServiceWorkerClient() {
                override fun shouldInterceptRequest(request: WebResourceRequest): WebResourceResponse? = client(request)
            }
        )
    }

    override fun setOnDefaultProfile(client: (WebResourceRequest) -> WebResourceResponse?) {
        ServiceWorkerControllerCompat.getInstance().setServiceWorkerClient(
            object : ServiceWorkerClientCompat() {
                override fun shouldInterceptRequest(request: WebResourceRequest): WebResourceResponse? = client(request)
            }
        )
    }
}

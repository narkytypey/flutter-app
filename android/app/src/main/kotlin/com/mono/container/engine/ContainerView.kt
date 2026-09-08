package com.mono.container.engine

import android.content.Context
import android.view.View
import android.webkit.WebView
import android.webkit.WebSettings
import androidx.webkit.ServiceWorkerControllerCompat
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.platform.PlatformView

class ContainerView(
    context: Context,
    private val config: SiteConfig,
    private val profiles: ProfileManager,
    private val interceptor: RequestInterceptor,
) : PlatformView {

    private val webView = WebView(context).apply {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.userAgentString = userAgentFor(config.userAgentMode)
        settings.setSupportMultipleWindows(false)
        settings.mediaPlaybackRequiresUserGesture = true
        setSafeBrowsingEnabled(false)   // pings Google directly; see Constraints

        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(this, config.forceDark)
        }
        setInitialScale(config.pageZoom)
    }

    init {
        // Must precede the first load, or the request goes to the default store.
        androidx.webkit.WebViewCompat.setProfile(webView, config.profileId)
        webView.webViewClient = interceptor.clientFor(config)
        webView.webChromeClient = Shields.chromeClientFor(config)
        Shields.apply(webView, config)

        if (WebViewFeature.isFeatureSupported(WebViewFeature.SERVICE_WORKER_BASIC_USAGE)) {
            ServiceWorkerControllerCompat.getInstance()
                .setServiceWorkerClient(interceptor.serviceWorkerClient(config))
        }

        webView.loadUrl(config.url)
    }

    override fun getView(): View = webView

    override fun dispose() {
        webView.stopLoading()
        webView.destroy()
        if (config.wipeOnExit) profiles.wipe(config.profileId)
    }

    private fun userAgentFor(mode: String): String = when (mode) {
        "desktop" -> "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
        "minimal" -> "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
            "(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
        else -> WebSettings.getDefaultUserAgent(webView.context)
    }
}

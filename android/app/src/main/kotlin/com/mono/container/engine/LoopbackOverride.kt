package com.mono.container.engine

import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature
import java.util.concurrent.CountDownLatch

/**
 * P2 spec §1.3: every scheme to the loopback proxy, implicit rules removed so
 * `localhost` and loopback addresses go through it too, and no `DIRECT` rule,
 * so if the proxy is down every request fails. Nothing falls back to direct.
 */
internal fun loopbackProxyConfig(port: Int): ProxyConfig =
    ProxyConfig.Builder()
        .addProxyRule("http://$LOOPBACK_HOST:$port")
        .removeImplicitRules()
        .build()

/**
 * Released once WebView has applied the override: `setProxyOverride` takes
 * effect asynchronously, and until then a request goes direct. [routeAtOpen]
 * waits on it before any site's view can exist.
 */
internal class OverrideApplied {
    private val latch = CountDownLatch(1)

    val isApplied: Boolean get() = latch.count == 0L

    /** The override's listener: WebView has applied it. */
    fun markApplied() = latch.countDown()

    /** Blocks until [markApplied]. Never on the main thread, which the listener may need. */
    fun await() = latch.await()
}

/**
 * The process's one loopback proxy and credential table. There must never be
 * two: Chromium caches each profile's proxy credential for the life of the
 * process, so a second table would issue credentials that cache never sends,
 * and there is one proxy override per process anyway.
 */
internal object Loopback {
    val credentials = SiteCredentials()

    /** Released by the override's listener; only waited on when [start] returned true. */
    val applied = OverrideApplied()

    private var installed: Boolean? = null

    /**
     * Starts the proxy and installs the override, once. True when WebView's
     * traffic goes through it once [applied] is released: WebView applies the
     * override asynchronously. When it cannot, proxied sites are refused
     * at open (`UNSUPPORTED`) and direct sites load as before. Autofill's
     * query then cannot be blocked either, and that is logged rather than
     * hidden.
     */
    @Synchronized fun start(): Boolean {
        installed?.let { return it }
        return install().also { installed = it }
    }

    private fun install(): Boolean {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            android.util.Log.w("ContainerEngine", "WebView cannot override its proxy: proxied sites are refused, and Autofill queries are not blocked")
            return false
        }
        // No `log`: its lines name hosts. A device run may pass one here locally, never committed.
        val proxy = runCatching { LoopbackProxy(credentials).start() }.getOrElse {
            android.util.Log.w("ContainerEngine", "The loopback proxy could not start: proxied sites are refused", it)
            return false
        }
        ProxyController.getInstance().setProxyOverride(loopbackProxyConfig(proxy.port), { it.run() }, applied::markApplied)
        return true
    }
}

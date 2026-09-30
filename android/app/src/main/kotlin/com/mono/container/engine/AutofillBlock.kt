package com.mono.container.engine

import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature

/** Chromium's Autofill server-prediction host (`kDefaultAutofillServerURL`). */
private const val AUTOFILL_HOST = "content-autofill.googleapis.com"

/**
 * A port no app can listen on: Android refuses a port below 1024 to an
 * unprivileged process, so a connection here can only ever be refused.
 */
private const val NOWHERE = "127.0.0.1:1"

/**
 * WebView's own Autofill sends every form it sees to [AUTOFILL_HOST] — a hash
 * of the form's site and fields, from the device's own address — out of the
 * browser process, where no site's `shouldInterceptRequest` can see it, and
 * no WebView setting turns it off. So the process-wide proxy override sends
 * that one host, and nothing else, to [NOWHERE]:
 *
 * - reverse bypass makes the bypass list the list of hosts that *use* the
 *   proxy, so every other request is untouched — a proxied site's pages are
 *   fetched by [ProxyHttpClient], which WebView's proxy never sees;
 * - the implicit rules are removed, so localhost is not added to that list;
 * - there is no DIRECT rule, so Chromium cannot fall back to going direct when
 *   the proxy refuses. The query fails, and Autofill does without it.
 *
 * Blocking, not routing: a browser-initiated request belongs to no site, so
 * there is no route to send it on (user's ruling, 2026-09-30).
 */
internal fun autofillBlockConfig(): ProxyConfig =
    ProxyConfig.Builder()
        .addProxyRule(NOWHERE)
        .addBypassRule(AUTOFILL_HOST)
        .setReverseBypassEnabled(true)
        .removeImplicitRules()
        .build()

/**
 * Installs [autofillBlockConfig] before any page can load. When this WebView
 * cannot override its proxy, the Autofill query is left as it was, and that
 * is logged rather than hidden.
 */
internal fun blockAutofillQueries() {
    if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE) ||
        !WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE_REVERSE_BYPASS)
    ) {
        android.util.Log.w("ContainerEngine", "WebView cannot override its proxy; Autofill queries are not blocked")
        return
    }
    ProxyController.getInstance().setProxyOverride(autofillBlockConfig(), { it.run() }, {})
}

package com.mono.container.engine

import java.net.URI

/**
 * The injected source for one library script (spec
 * `2026-09-28-filter-lists-and-scripts-design.md`, "Timing"). Each script is
 * injected on its own, so an error in one cannot stop another, and code is
 * placed as written — never through `eval`, which a page's
 * Content-Security-Policy would block.
 */
object UserScriptJs {
    fun wrap(kind: String, code: String, atDocumentStart: Boolean): String? = when (kind) {
        "css" -> css(code, atDocumentStart)
        "js" -> js(code, atDocumentStart)
        else -> null
    }

    private fun css(code: String, atDocumentStart: Boolean): String {
        val add = "function(){var s=document.createElement('style');" +
            "s.textContent=${code.asJsString()};" +
            "(document.head||document.documentElement).appendChild(s);}"
        return if (atDocumentStart) {
            "(function(){var add=$add;" +
                "if(document.documentElement){add();}else{document.addEventListener('DOMContentLoaded',add);}})();"
        } else {
            "document.addEventListener('DOMContentLoaded',$add);"
        }
    }

    // The closer goes on its own line so a trailing `//` comment in [code]
    // cannot comment it out.
    private fun js(code: String, atDocumentStart: Boolean): String =
        if (atDocumentStart) "$code\n"
        else "document.addEventListener('DOMContentLoaded',function(){\n$code\n});"
}

/**
 * The `allowedOriginRules` entry that confines a library script to its
 * site: `scheme://host`, with the port only when it is not the default.
 * Null — and so no injection — for anything that is not an http(s) URL.
 */
fun originRuleFor(url: String): String? {
    val uri = runCatching { URI(url) }.getOrNull() ?: return null
    val scheme = uri.scheme?.lowercase() ?: return null
    if (scheme != "http" && scheme != "https") return null
    val host = uri.host?.lowercase() ?: return null
    val defaultPort = if (scheme == "https") 443 else 80
    return if (uri.port == -1 || uri.port == defaultPort) "$scheme://$host" else "$scheme://$host:${uri.port}"
}

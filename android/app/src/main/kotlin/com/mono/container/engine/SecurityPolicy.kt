package com.mono.container.engine

/**
 * What a site may run (privacy-controls spec §1). Dart resolves the
 * effective level and sends its name; this never sees "follow the default".
 */
enum class SecurityLevel {
    STANDARD, SAFER, SAFEST;

    companion object {
        /** A name Dart did not send, or none, is [SAFEST] (spec §1.5). */
        fun fromChannel(name: String?): SecurityLevel = when (name) {
            "standard" -> STANDARD
            "safer" -> SAFER
            "safest" -> SAFEST
            else -> SAFEST
        }
    }
}

/** How a [SecurityLevel] is applied to one WebView. Pure, so the JVM tests reach it. */
data class SecurityPolicy(
    val javaScriptEnabled: Boolean,
    val blockNetworkImage: Boolean,
    /** [Shields.apply]'s document-start scripts. None can run with JavaScript
     *  off, so Safest adds none. */
    val documentStartScripts: Boolean,
    /** `shields/safer.js`: no page script on `http:`, no WebAssembly, no WebGL. */
    val saferScript: Boolean,
)

fun securityPolicyFor(level: SecurityLevel): SecurityPolicy = when (level) {
    SecurityLevel.STANDARD -> SecurityPolicy(
        javaScriptEnabled = true, blockNetworkImage = false,
        documentStartScripts = true, saferScript = false,
    )
    SecurityLevel.SAFER -> SecurityPolicy(
        javaScriptEnabled = true, blockNetworkImage = false,
        documentStartScripts = true, saferScript = true,
    )
    SecurityLevel.SAFEST -> SecurityPolicy(
        javaScriptEnabled = false, blockNetworkImage = true,
        documentStartScripts = false, saferScript = false,
    )
}

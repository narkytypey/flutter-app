package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

class SecurityPolicyTest {
    @Test fun `each name Dart sends is its level`() {
        assertEquals(SecurityLevel.STANDARD, SecurityLevel.fromChannel("standard"))
        assertEquals(SecurityLevel.SAFER, SecurityLevel.fromChannel("safer"))
        assertEquals(SecurityLevel.SAFEST, SecurityLevel.fromChannel("safest"))
    }

    @Test fun `missing, unknown or misspelt fails closed to Safest`() {
        for (name in listOf(null, "", "Standard", "SAFER", "medium")) {
            assertEquals(name.toString(), SecurityLevel.SAFEST, SecurityLevel.fromChannel(name))
        }
    }

    @Test fun `Standard is today's behaviour`() {
        val p = securityPolicyFor(SecurityLevel.STANDARD)
        assertTrue(p.javaScriptEnabled); assertFalse(p.blockNetworkImage)
        assertTrue(p.documentStartScripts); assertFalse(p.saferScript)
    }

    @Test fun `Safer adds safer js and keeps JavaScript on`() {
        val p = securityPolicyFor(SecurityLevel.SAFER)
        assertTrue(p.javaScriptEnabled); assertFalse(p.blockNetworkImage)
        assertTrue(p.documentStartScripts); assertTrue(p.saferScript)
    }

    @Test fun `Safest turns JavaScript and network images off and adds no script`() {
        val p = securityPolicyFor(SecurityLevel.SAFEST)
        assertFalse(p.javaScriptEnabled); assertTrue(p.blockNetworkImage)
        assertFalse(p.documentStartScripts); assertFalse(p.saferScript)
    }

    @Test fun `a SiteConfig with no level is Safest`() {
        assertEquals(SecurityLevel.SAFEST, SecurityLevel.fromChannel(null))
    }

    @Test fun `safer js carries the three measures`() {
        // Unit tests run from android/app.
        val js = File("src/main/assets/shields/safer.js").readText()
        assertTrue(js.contains("location.protocol === 'http:'"))
        assertTrue(js.contains("Content-Security-Policy"))
        assertTrue(js.contains("script-src 'none'"))
        assertTrue(js.contains("WebAssembly"))
        for (context in listOf("'webgl'", "'webgl2'", "'experimental-webgl'")) {
            assertTrue(context, js.contains(context))
        }
        assertTrue(js.contains("OffscreenCanvas"))
    }
}

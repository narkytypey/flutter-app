package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UserScriptJsTest {

    @Test fun `css at document start adds the style before paint`() {
        val js = UserScriptJs.wrap("css", "header{display:none}", atDocumentStart = true)!!
        assertTrue(js.startsWith("(function(){var add=function(){"))
        assertTrue(js.contains("s.textContent='header{display:none}'"))
        assertTrue(js.contains("if(document.documentElement){add();}else{document.addEventListener('DOMContentLoaded',add);}"))
    }

    @Test fun `css at load adds the style on DOMContentLoaded`() {
        val js = UserScriptJs.wrap("css", "a{}", atDocumentStart = false)!!
        assertTrue(js.startsWith("document.addEventListener('DOMContentLoaded',function(){"))
        assertTrue(js.contains("s.textContent='a{}'"))
    }

    // Review Focus 2.
    @Test fun `css quotes, backslashes and newlines are escaped`() {
        val js = UserScriptJs.wrap("css", "a::after{content:'\\\\'}\nb{}", atDocumentStart = false)!!
        assertTrue(js.contains("s.textContent='a::after{content:\\'\\\\\\\\\\'}\\nb{}'"))
    }

    @Test fun `js at document start is the code as written`() {
        assertEquals("window.x=1;\n", UserScriptJs.wrap("js", "window.x=1;", atDocumentStart = true))
    }

    // Review Focus 3: a trailing line comment must not swallow the closer.
    @Test fun `js at load puts the closer on its own line`() {
        assertEquals(
            "document.addEventListener('DOMContentLoaded',function(){\nrun() // go\n});",
            UserScriptJs.wrap("js", "run() // go", atDocumentStart = false),
        )
    }

    @Test fun `an unknown kind yields nothing`() {
        assertNull(UserScriptJs.wrap("wasm", "x", atDocumentStart = true))
    }

    @Test fun `origin rule is scheme and host`() {
        assertEquals("https://forum.example.com", originRuleFor("https://forum.example.com/thread/1?x=2"))
        assertEquals("http://forum.example.com", originRuleFor("http://forum.example.com"))
    }

    // Review Focus 4.
    @Test fun `origin rule normalizes default ports and case`() {
        assertEquals("https://forum.example.com", originRuleFor("https://Forum.Example.com:443/"))
        assertEquals("http://forum.example.com", originRuleFor("HTTP://forum.example.com:80"))
        assertEquals("https://forum.example.com:8443", originRuleFor("https://forum.example.com:8443/a"))
    }

    @Test fun `origin rule refuses what is not an http page`() {
        assertNull(originRuleFor("file:///sdcard/a.html"))
        assertNull(originRuleFor("not a url"))
        assertNull(originRuleFor("https:///no-host"))
    }
}

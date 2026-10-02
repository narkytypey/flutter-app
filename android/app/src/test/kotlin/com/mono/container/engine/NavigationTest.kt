package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The chrome (browser-chrome spec §3) is built from these: what the page is
 * doing, folded from WebView's callbacks, and the one guard on what
 * `loadUrl` may load.
 */
class NavigationTest {

    @Test fun `a new container starts loading its own address`() {
        assertEquals(
            NavigationSnapshot("https://forum.example.com", "", false, false, true, 0),
            NavigationTracker("https://forum.example.com").snapshot(canGoBack = false, canGoForward = false),
        )
    }

    @Test fun `a page starts, reports progress and a title, then finishes`() {
        val tracker = NavigationTracker("https://forum.example.com")
        tracker.started("https://forum.example.com/")
        tracker.progressed(40)
        tracker.titled("Forum")
        assertEquals(
            NavigationSnapshot("https://forum.example.com/", "Forum", false, false, true, 40),
            tracker.snapshot(canGoBack = false, canGoForward = false),
        )

        tracker.finished("https://forum.example.com/")
        val done = tracker.snapshot(canGoBack = true, canGoForward = false)
        assertFalse(done.loading)
        assertEquals(100, done.progress)
        assertTrue(done.canGoBack)
    }

    @Test fun `the next load starts the line from zero`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.finished("https://a.example/")
        tracker.started("https://a.example/next")
        val snapshot = tracker.snapshot(false, false)
        assertTrue(snapshot.loading)
        assertEquals(0, snapshot.progress)
    }

    @Test fun `progress reported before the start is kept`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.finished("https://a.example/")
        tracker.progressed(10)
        tracker.started("https://a.example/next")
        assertEquals(10, tracker.snapshot(false, false).progress)
    }

    @Test fun `stopping ends the load where it stood`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.progressed(60)
        tracker.stopped()
        val snapshot = tracker.snapshot(false, false)
        assertFalse(snapshot.loading)
        assertEquals(60, snapshot.progress)
    }

    @Test fun `a history update moves the address without ending the load`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.started("https://a.example/")
        tracker.visited("https://a.example/#section")
        val snapshot = tracker.snapshot(false, false)
        assertEquals("https://a.example/#section", snapshot.url)
        assertTrue(snapshot.loading)
    }

    @Test fun `progress outside 0 to 100 is clamped`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.progressed(140)
        assertEquals(100, tracker.snapshot(false, false).progress)
        tracker.progressed(-5)
        assertEquals(0, tracker.snapshot(false, false).progress)
    }

    @Test fun `a missing title reads as empty`() {
        val tracker = NavigationTracker("https://a.example")
        tracker.titled("Before")
        tracker.titled(null)
        assertEquals("", tracker.snapshot(false, false).title)
    }

    @Test fun `the navigation event carries every key Dart reads`() {
        assertEquals(
            mapOf(
                "type" to "navigation", "siteId" to "s1", "pageId" to "p1", "url" to "https://a.example/x",
                "title" to "X", "canGoBack" to true, "canGoForward" to false,
                "loading" to false, "progress" to 100,
            ),
            NavigationSnapshot("https://a.example/x", "X", true, false, false, 100).toEvent("s1", "p1"),
        )
    }

    @Test fun `the find result event carries every key Dart reads`() {
        assertEquals(
            mapOf("type" to "find_result", "siteId" to "s1", "pageId" to "p1", "activeMatch" to 2, "matchCount" to 7),
            findResultEvent("s1", "p1", 2, 7),
        )
    }

    @Test fun `loadUrl accepts http and https addresses`() {
        for (url in listOf(
            "https://example.com",
            "http://example.com:8080/a?b=1#c",
            "HTTPS://Example.com/",
            "https://10.0.2.2:8888/x",
        )) {
            assertTrue(url, isLoadableUrl(url))
        }
    }

    // Review Focus 3: Dart never sends these; the platform refuses them anyway.
    @Test fun `loadUrl refuses every other scheme`() {
        for (url in listOf(
            "javascript:alert(1)",
            "JAVASCRIPT:alert(1)",
            " https://example.com",
            "file:///sdcard/a.html",
            "intent://scan/#Intent;end",
            "content://media/external/images/1",
            "data:text/html,hi",
            "about:blank",
            "ftp://example.com",
            "httpx://example.com",
            "https:///no-host",
            "https://",
            "",
        )) {
            assertFalse(url, isLoadableUrl(url))
        }
    }
}

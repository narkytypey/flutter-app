package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Tabs spec §5.2 and §5.8a: the cap on pages per container, what a request
 * for a new window does, what a capped link may load in place, and a
 * container's wipe waiting for every one of its pages.
 */
class PagesTest {

    @Test fun `a new window without a user gesture is refused at any page count`() {
        for (pages in listOf(0, 5, 6)) {
            assertEquals("$pages pages", NewWindowAction.REFUSE, newWindowAction(isUserGesture = false, livePages = pages))
        }
    }

    @Test fun `a new window with a user gesture under the cap opens a new page`() {
        for (pages in listOf(0, 5)) {
            assertEquals("$pages pages", NewWindowAction.NEW_PAGE, newWindowAction(isUserGesture = true, livePages = pages))
        }
    }

    @Test fun `a new window with a user gesture at or over the cap loads in place`() {
        for (pages in listOf(6, 7)) {
            assertEquals("$pages pages", NewWindowAction.LOAD_IN_PLACE, newWindowAction(isUserGesture = true, livePages = pages))
        }
    }

    @Test fun `an https address is loaded in place`() {
        assertEquals("https://a.example/x", inPlaceUrl("https://a.example/x"))
    }

    @Test fun `an http address is loaded in place`() {
        assertEquals("http://a.example", inPlaceUrl("http://a.example"))
    }

    @Test fun `nothing else is loaded in place`() {
        for (url in listOf(null, "", "javascript:alert(1)", "file:///etc/hosts", "about:blank", "JAVASCRIPT:x")) {
            assertNull("$url", inPlaceUrl(url))
        }
    }

    @Test fun `an upper-case https address is loaded in place, as isLoadableUrl allows`() {
        assertEquals("HTTPS://A.EXAMPLE/", inPlaceUrl("HTTPS://A.EXAMPLE/"))
    }

    @Test fun `the countdown runs once, after the third page in any order`() {
        var runs = 0
        val countdown = CloseCountdown(listOf("a", "b", "c")) { runs++ }
        countdown.destroyed("c")
        assertEquals(0, runs)
        countdown.destroyed("a")
        assertEquals(0, runs)
        countdown.destroyed("b")
        assertEquals(1, runs)
    }

    @Test fun `the same page reported twice counts once`() {
        var runs = 0
        val countdown = CloseCountdown(listOf("a", "b", "c")) { runs++ }
        countdown.destroyed("a")
        countdown.destroyed("a")
        countdown.destroyed("b")
        assertEquals(0, runs)
        countdown.destroyed("c")
        assertEquals(1, runs)
    }

    @Test fun `an unknown page id is ignored`() {
        var runs = 0
        val countdown = CloseCountdown(listOf("a")) { runs++ }
        countdown.destroyed("zzz")
        assertEquals(0, runs)
        countdown.destroyed("a")
        assertEquals(1, runs)
    }

    @Test fun `an empty set of pages runs at construction`() {
        var runs = 0
        CloseCountdown(emptyList()) { runs++ }
        assertEquals(1, runs)
    }

    @Test fun `a report after finishing runs nothing`() {
        var runs = 0
        val countdown = CloseCountdown(listOf("a", "b", "c")) { runs++ }
        countdown.destroyed("a")
        countdown.destroyed("b")
        countdown.destroyed("c")
        countdown.destroyed("d")
        countdown.destroyed("a")
        assertEquals(1, runs)
    }

    @Test fun `page ids are distinct and start p-`() {
        val ids = List(1000) { newPageId() }
        assertEquals(1000, ids.toSet().size)
        for (id in ids) assertTrue(id, id.startsWith("p-"))
    }

    @Test fun `the pages list carries each page's id and opener in order`() {
        assertEquals(
            listOf(
                mapOf("pageId" to "p-1", "openerPageId" to null),
                mapOf("pageId" to "p-2", "openerPageId" to "p-1"),
            ),
            pagesToEvent(listOf("p-1" to null, "p-2" to "p-1")),
        )
    }

    @Test fun `the page opened event carries every key Dart reads`() {
        assertEquals(
            mapOf("type" to "page_opened", "siteId" to "s1", "pageId" to "p-2", "openerPageId" to "p-1"),
            pageOpenedEvent("s1", "p-2", "p-1"),
        )
    }
}

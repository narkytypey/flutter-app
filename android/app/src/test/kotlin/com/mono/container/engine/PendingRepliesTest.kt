package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** Reader mode's `extractArticle` must answer once, even for a page destroyed mid-script. */
class PendingRepliesTest {

    @Test fun `a reply answers its caller once`() {
        val replies = PendingReplies<String>()
        val got = mutableListOf<String?>()
        val reply = replies.add { got += it }
        reply.answer("a")
        reply.answer("b")
        assertEquals(listOf<String?>("a"), got)
        assertEquals(0, replies.size)
    }

    @Test fun `cancelAll answers every owed reply with null, and a late answer is dropped`() {
        val replies = PendingReplies<String>()
        val got = mutableListOf<String?>()
        val first = replies.add { got += "1:$it" }
        replies.add { got += "2:$it" }
        replies.cancelAll()
        first.answer("late")
        assertEquals(listOf("1:null", "2:null"), got)
        assertEquals(0, replies.size)
    }

    @Test fun `cancelAll leaves already answered replies alone`() {
        val replies = PendingReplies<String>()
        val got = mutableListOf<String?>()
        replies.add { got += it }.answer("done")
        replies.cancelAll()
        assertEquals(listOf<String?>("done"), got)
    }
}

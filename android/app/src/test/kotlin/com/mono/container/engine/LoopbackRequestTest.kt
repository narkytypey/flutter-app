package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Base64

/** P2 spec §1.1: what the loopback proxy does with one request head, before any socket. */
class LoopbackRequestTest {

    private val site = ProxyBinding(
        SiteConfig(
            siteId = "s", profileId = "p1", url = "https://forum.example.com",
            proxyMode = "direct", proxyHost = null, proxyPort = null,
            blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
            allowCamera = false, allowMicrophone = false, allowLocation = false,
            allowClipboard = false, userAgentMode = "android", forceDark = true,
            pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
        )
    ) {}

    private val lookup: (String, String) -> ProxyBinding? = { user, password ->
        if (user == "user" && password == "pass") site else null
    }

    private fun auth(user: String = "user", password: String = "pass") =
        "Proxy-Authorization: Basic " + Base64.getEncoder().encodeToString("$user:$password".toByteArray()) + "\r\n"

    private fun request(text: String) =
        readHead(text.byteInputStream(Charsets.ISO_8859_1))?.let(::parseRequest)

    // --- readHead ---------------------------------------------------------

    @Test fun `a head is read line by line and the stream is left at the body`() {
        val input = "POST http://a.example/ HTTP/1.1\r\nContent-Length: 3\r\n\r\nabc".byteInputStream(Charsets.ISO_8859_1)
        assertEquals(listOf("POST http://a.example/ HTTP/1.1", "Content-Length: 3"), readHead(input))
        assertEquals("abc", input.readBytes().toString(Charsets.ISO_8859_1))
    }

    @Test fun `a head cut off before its blank line is nothing`() {
        assertNull(readHead("CONNECT a.example:443 HTTP/1.1\r\nHost: a".byteInputStream()))
    }

    /** Review Focus 3: a hostile local app cannot make the proxy buffer without end. */
    @Test fun `a head over the limit is nothing`() {
        val text = "GET http://a.example/ HTTP/1.1\r\nX-Pad: " + "a".repeat(100) + "\r\n\r\n"
        assertNull(readHead(text.byteInputStream(), limit = 50))
    }

    // --- parseRequest -----------------------------------------------------

    @Test fun `a CONNECT names its host and port`() {
        val parsed = request("CONNECT forum.example.com:443 HTTP/1.1\r\nHost: forum.example.com:443\r\n\r\n")!!
        assertEquals("forum.example.com", parsed.host)
        assertEquals(443, parsed.port)
        assertNull(parsed.path)
    }

    @Test fun `a CONNECT to an IPv6 literal is read without its brackets`() {
        assertEquals("2001:db8::1" to 443, parseAuthority("[2001:db8::1]:443"))
    }

    @Test fun `an authority without a usable port is refused`() {
        assertNull(parseAuthority("forum.example.com"))
        assertNull(parseAuthority("forum.example.com:0"))
        assertNull(parseAuthority("forum.example.com:70000"))
        assertNull(parseAuthority("a:b:443"))
        assertNull(parseAuthority(":443"))
        assertNull(parseAuthority("[2001:db8::1]443"))
    }

    @Test fun `an absolute-form request names its host, port and origin-form path`() {
        val parsed = request("GET http://forum.example.com:8080/a/b?c=1 HTTP/1.1\r\n\r\n")!!
        assertEquals("forum.example.com", parsed.host)
        assertEquals(8080, parsed.port)
        assertEquals("/a/b?c=1", parsed.path)
    }

    @Test fun `an absolute-form request without a port or path goes to port 80 at slash`() {
        val parsed = request("GET http://forum.example.com HTTP/1.1\r\n\r\n")!!
        assertEquals(80, parsed.port)
        assertEquals("/", parsed.path)
    }

    @Test fun `anything but CONNECT or an http absolute-form request is refused`() {
        assertNull(request("GET https://forum.example.com/ HTTP/1.1\r\n\r\n"))
        assertNull(request("GET / HTTP/1.1\r\nHost: forum.example.com\r\n\r\n"))
        assertNull(request("CONNECT forum.example.com:443 HTTP/2\r\n\r\n"))
        assertNull(request("CONNECT forum.example.com:443\r\n\r\n"))
        assertNull(request("CONNECT forum.example.com:443 HTTP/1.1\r\nno colon here\r\n\r\n"))
    }

    // --- basicCredentials -------------------------------------------------

    @Test fun `Basic credentials are decoded, and anything else is not`() {
        val encoded = Base64.getEncoder().encodeToString("user:pa:ss".toByteArray())
        assertEquals("user" to "pa:ss", basicCredentials("Basic $encoded"))
        assertEquals("user" to "pa:ss", basicCredentials("basic  $encoded"))
        assertNull(basicCredentials("Bearer $encoded"))
        assertNull(basicCredentials("Basic !!!"))
        assertNull(basicCredentials("Basic " + Base64.getEncoder().encodeToString("nocolon".toByteArray())))
    }

    // --- decide -----------------------------------------------------------

    @Test fun `an unreadable request gets 400`() {
        assertEquals(ProxyDecision.Reply(400), decide(null, lookup))
    }

    @Test fun `no credentials get a 407`() {
        assertEquals(ProxyDecision.Reply(407), decide(request("CONNECT forum.example.com:443 HTTP/1.1\r\n\r\n"), lookup))
    }

    /** Never a second 407: Chromium's behaviour on a re-challenge is unknown (spec §1.1). */
    @Test fun `wrong or malformed credentials get a 403, never another 407`() {
        assertEquals(ProxyDecision.Reply(403), decide(request("CONNECT forum.example.com:443 HTTP/1.1\r\n${auth(password = "nope")}\r\n"), lookup))
        assertEquals(ProxyDecision.Reply(403), decide(request("CONNECT forum.example.com:443 HTTP/1.1\r\nProxy-Authorization: Digest x\r\n\r\n"), lookup))
    }

    @Test fun `the Autofill host is refused whatever the credentials`() {
        for (host in listOf("content-autofill.googleapis.com", "Content-Autofill.GoogleAPIs.com", "content-autofill.googleapis.com.")) {
            assertEquals(ProxyDecision.Reply(403), decide(request("CONNECT $host:443 HTTP/1.1\r\n${auth()}\r\n"), lookup))
        }
        assertEquals(ProxyDecision.Reply(403), decide(request("GET http://content-autofill.googleapis.com/ HTTP/1.1\r\n${auth()}\r\n"), lookup))
    }

    /** Review Focus 5 (plan deviation 2): only the proxy may challenge as 127.0.0.1. */
    /** Built-in Tor spec §5.3, Review Focus 4: an onion name on a direct route goes nowhere. */
    @Test fun `an onion host on a direct route is refused, in any case and with a trailing dot`() {
        assertEquals(ProxyDecision.Reply(403), decide(request("CONNECT abc.onion:443 HTTP/1.1\r\n${auth()}\r\n"), lookup))
        assertEquals(ProxyDecision.Reply(403), decide(request("CONNECT ABC.ONION.:443 HTTP/1.1\r\n${auth()}\r\n"), lookup))
        assertEquals(ProxyDecision.Reply(403), decide(request("GET http://abc.onion/ HTTP/1.1\r\n${auth()}\r\n"), lookup))
    }

    @Test fun `an onion host on a proxied route goes to the proxy by name`() {
        val socks = ProxyBinding(site.config.copy(proxyMode = "socks5", proxyHost = "127.0.0.1", proxyPort = 9050)) {}
        val decision = decide(request("CONNECT abc.onion:443 HTTP/1.1\r\n${auth()}\r\n")) { _, _ -> socks }
        // `Tunnel` is not a data class: compare what it carries.
        decision as ProxyDecision.Tunnel
        assertEquals("abc.onion", decision.host)
        assertEquals(443, decision.port)
        assertSame(socks, decision.binding)
    }

    @Test fun `a destination named 127_0_0_1 is refused whatever the credentials`() {
        assertEquals(ProxyDecision.Reply(403), decide(request("CONNECT 127.0.0.1:8443 HTTP/1.1\r\n${auth()}\r\n"), lookup))
        assertEquals(ProxyDecision.Reply(403), decide(request("GET http://127.0.0.1:8080/ HTTP/1.1\r\n${auth()}\r\n"), lookup))
    }

    @Test fun `an authenticated CONNECT is tunnelled for its site`() {
        val decision = decide(request("CONNECT forum.example.com:443 HTTP/1.1\r\n${auth()}\r\n"), lookup) as ProxyDecision.Tunnel
        assertEquals("forum.example.com", decision.host)
        assertEquals(443, decision.port)
        assertSame(site, decision.binding)
    }

    @Test fun `an authenticated http request is forwarded with its body length`() {
        val get = decide(request("GET http://forum.example.com/a HTTP/1.1\r\n${auth()}\r\n"), lookup) as ProxyDecision.Forward
        assertEquals(0L, get.bodyLength)
        assertEquals(80, get.port)
        val post = decide(request("POST http://forum.example.com/a HTTP/1.1\r\n${auth()}Content-Length: 3\r\n\r\n"), lookup) as ProxyDecision.Forward
        assertEquals(3L, post.bodyLength)
        assertSame(site, post.binding)
    }

    @Test fun `an http body without a length is refused`() {
        assertEquals(ProxyDecision.Reply(411), decide(request("POST http://forum.example.com/a HTTP/1.1\r\n${auth()}Transfer-Encoding: chunked\r\n\r\n"), lookup))
        assertEquals(ProxyDecision.Reply(400), decide(request("POST http://forum.example.com/a HTTP/1.1\r\n${auth()}Content-Length: lots\r\n\r\n"), lookup))
    }

    // --- heads ------------------------------------------------------------

    /** Review Focus 5: the credential is for the proxy and is never sent on to a site. */
    @Test fun `origin form drops the proxy's headers and asks for one request per connection`() {
        val parsed = request(
            "GET http://forum.example.com/a?b=1 HTTP/1.1\r\nHost: forum.example.com\r\n${auth()}" +
                "Proxy-Connection: keep-alive\r\nConnection: keep-alive\r\nKeep-Alive: 300\r\nCookie: sid=1\r\n\r\n"
        )!!
        assertEquals(
            "GET /a?b=1 HTTP/1.1\r\nHost: forum.example.com\r\nCookie: sid=1\r\nConnection: close\r\n\r\n",
            originFormHead(parsed),
        )
    }

    @Test fun `a relayed response is marked to close and loses any proxy challenge`() {
        val head = listOf("HTTP/1.1 200 OK", "Content-Length: 2", "Connection: keep-alive", "Keep-Alive: 5", "Proxy-Authenticate: Basic realm=\"container\"")
        assertEquals("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n", closingResponseHead(head))
    }

    @Test fun `only the 407 carries the challenge, and every reply closes`() {
        val challenge = String(statusResponse(407), Charsets.ISO_8859_1)
        assertTrue(challenge.startsWith("HTTP/1.1 407 Proxy Authentication Required\r\n"))
        assertTrue(challenge.contains("Proxy-Authenticate: Basic realm=\"container\"\r\n"))
        for (status in listOf(400, 403, 411, 502, 504)) {
            val reply = String(statusResponse(status), Charsets.ISO_8859_1)
            assertTrue(reply.startsWith("HTTP/1.1 $status "))
            assertFalse(reply.contains("Proxy-Authenticate"))
            assertTrue(reply.endsWith("Content-Length: 0\r\nConnection: close\r\n\r\n"))
        }
    }

    @Test fun `an upstream timeout is 504 and every other upstream failure 502`() {
        assertEquals(504, upstreamFailureStatus(java.net.SocketTimeoutException("slow")))
        assertEquals(502, upstreamFailureStatus(ProxyTunnelException(403, "refused")))
        assertEquals(502, upstreamFailureStatus(java.net.ConnectException("refused")))
        assertEquals(502, upstreamFailureStatus(java.net.SocketException("SOCKS : General SOCKS server failure")))
        assertEquals(502, upstreamFailureStatus(java.net.UnknownHostException("forum.example.com")))
    }
}

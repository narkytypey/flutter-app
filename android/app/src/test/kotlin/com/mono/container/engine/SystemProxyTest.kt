package com.mono.container.engine

import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

/** Design question 2 (user's ruling, 2026-09-30): which direct connections go through the system proxy. */
class SystemProxyTest {

    private val proxy = SystemProxy("proxy.corp.example", 3128)

    private fun excluding(vararg patterns: String) = SystemProxy("proxy.corp.example", 3128, patterns.toList())

    @Test fun `no system proxy means straight`() {
        assertNull(systemProxyFor(null, "example.com"))
    }

    @Test fun `any other host goes through it`() {
        assertSame(proxy, systemProxyFor(proxy, "example.com"))
        assertSame(proxy, systemProxyFor(proxy, "93.184.215.14"))
    }

    /** A PAC setup whose local proxy is not up yet reports no port. */
    @Test fun `a proxy with no host or no port is none`() {
        assertNull(systemProxyFor(SystemProxy("", 3128), "example.com"))
        assertNull(systemProxyFor(SystemProxy("proxy.corp.example", -1), "example.com"))
        assertNull(systemProxyFor(SystemProxy("proxy.corp.example", 0), "example.com"))
    }

    @Test fun `loopback destinations never go through it`() {
        for (host in listOf("localhost", "LOCALHOST", "app.localhost", "127.0.0.1", "127.8.9.10", "::1", "[::1]")) {
            assertNull(host, systemProxyFor(proxy, host))
        }
    }

    @Test fun `an exclusion without a wildcard matches that host only`() {
        val excluded = excluding("intranet.corp.example")
        assertNull(systemProxyFor(excluded, "intranet.corp.example"))
        assertNull(systemProxyFor(excluded, "Intranet.Corp.Example."))
        assertSame(excluded, systemProxyFor(excluded, "wiki.intranet.corp.example"))
    }

    @Test fun `a wildcard, or a leading dot, matches subdomains`() {
        for (pattern in listOf("*.corp.example", ".corp.example")) {
            val excluded = excluding(pattern)
            assertNull(pattern, systemProxyFor(excluded, "wiki.corp.example"))
            assertSame(pattern, excluded, systemProxyFor(excluded, "corp.example"))
            assertSame(pattern, excluded, systemProxyFor(excluded, "corp.example.evil.test"))
        }
    }

    @Test fun `a wildcard matches addresses too`() {
        val excluded = excluding("192.168.*", " 10.0.0.1 ")
        assertNull(systemProxyFor(excluded, "192.168.1.20"))
        assertNull(systemProxyFor(excluded, "10.0.0.1"))
        assertSame(excluded, systemProxyFor(excluded, "10.0.0.12"))
    }

    /** A pattern is not a regular expression: its dots are literal. */
    @Test fun `pattern characters other than the wildcard are literal`() {
        val excluded = excluding("a.b")
        assertSame(excluded, systemProxyFor(excluded, "axb"))
    }

    @Test fun `an empty pattern excludes nothing`() {
        val excluded = excluding("", "  ")
        assertSame(excluded, systemProxyFor(excluded, "example.com"))
    }
}

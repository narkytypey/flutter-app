package com.mono.container.engine

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.DataInputStream
import java.io.IOException
import java.net.ServerSocket
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Proxy-auth spec §2.2 and §5, against a scripted SOCKS5 server on localhost. */
class Socks5TunnelTest {

    /**
     * Records what the client sends and answers as told. [method] is the
     * method byte it chooses; [authStatus] its RFC 1929 status; [reply] its
     * CONNECT reply code, followed (on success only) by a bound address of
     * [boundType]. After success it echoes one byte. [script], when set,
     * replaces everything after accept.
     */
    private class FakeSocks5(
        val method: Int = 0,
        val authStatus: Int = 0,
        val reply: Int = 0,
        val boundType: Int = 1,
        val script: ((java.net.Socket) -> Unit)? = null,
    ) : AutoCloseable {
        val server = ServerSocket(0)
        val accepted = AtomicInteger()
        val greetings = ArrayBlockingQueue<ByteArray>(1)
        val auths = ArrayBlockingQueue<ByteArray>(1)
        val connects = ArrayBlockingQueue<String>(1)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    server.accept().use { client ->
                        accepted.incrementAndGet()
                        script?.let { it(client); return@use }
                        val input = DataInputStream(client.getInputStream())
                        val out = client.getOutputStream()
                        val version = input.readUnsignedByte()
                        val count = input.readUnsignedByte()
                        greetings.offer(byteArrayOf(version.toByte(), count.toByte()) + ByteArray(count).also { input.readFully(it) })
                        out.write(byteArrayOf(5, method.toByte())); out.flush()
                        if (method == 0xFF) return@use
                        if (method == 2) {
                            val subVersion = input.readUnsignedByte()
                            val user = ByteArray(input.readUnsignedByte()).also { input.readFully(it) }
                            val password = ByteArray(input.readUnsignedByte()).also { input.readFully(it) }
                            auths.offer(byteArrayOf(subVersion.toByte(), user.size.toByte()) + user + byteArrayOf(password.size.toByte()) + password)
                            out.write(byteArrayOf(1, authStatus.toByte())); out.flush()
                            if (authStatus != 0) return@use
                        }
                        input.readUnsignedByte(); input.readUnsignedByte(); input.readUnsignedByte()
                        val type = input.readUnsignedByte()
                        val host = String(ByteArray(input.readUnsignedByte()).also { input.readFully(it) }, Charsets.UTF_8)
                        connects.offer("$type $host:${input.readUnsignedShort()}")
                        if (reply != 0) {
                            // No bound address after a failure: some proxies send none.
                            out.write(byteArrayOf(5, reply.toByte())); out.flush()
                            return@use
                        }
                        val bound = when (boundType) {
                            1 -> byteArrayOf(1, 10, 0, 0, 1)
                            3 -> byteArrayOf(3, 9) + "proxy.lan".toByteArray(Charsets.US_ASCII)
                            else -> byteArrayOf(4) + ByteArray(16)
                        }
                        out.write(byteArrayOf(5, 0, 0) + bound + byteArrayOf(0x1F, 0x90.toByte())); out.flush()
                        val byte = input.read()
                        if (byte != -1) { out.write(byte); out.flush() }
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    private fun <T> FakeSocks5.poll(queue: ArrayBlockingQueue<T>): T? = queue.poll(5, TimeUnit.SECONDS)

    private fun expectRejected(block: () -> Unit): ProxyLoginRejectedException {
        try {
            block()
        } catch (error: ProxyLoginRejectedException) {
            return error
        }
        fail("expected ProxyLoginRejectedException")
        error("unreachable")
    }

    @Test fun `without a login it offers only no-authentication`() {
        FakeSocks5().use { proxy ->
            Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443).close()
            assertArrayEquals(byteArrayOf(5, 1, 0), proxy.poll(proxy.greetings))
        }
    }

    @Test fun `with a login it offers only username and password, and sends RFC 1929 bytes`() {
        FakeSocks5(method = 2).use { proxy ->
            Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443, ProxyLogin("alice", "s3cret")).close()
            assertArrayEquals(byteArrayOf(5, 1, 2), proxy.poll(proxy.greetings))
            assertArrayEquals(
                byteArrayOf(1, 5) + "alice".toByteArray() + byteArrayOf(6) + "s3cret".toByteArray(),
                proxy.poll(proxy.auths),
            )
        }
    }

    /** UTF-8 bytes, and their byte count, not the character count. */
    @Test fun `a non-ASCII login is sent as UTF-8`() {
        FakeSocks5(method = 2).use { proxy ->
            Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443, ProxyLogin("ünï", "p:w")).close()
            val user = "ünï".toByteArray(Charsets.UTF_8)
            assertArrayEquals(
                byteArrayOf(1, user.size.toByte()) + user + byteArrayOf(3) + "p:w".toByteArray(),
                proxy.poll(proxy.auths),
            )
        }
    }

    /** Ruling 2: always address type 3, so the proxy does every lookup. */
    @Test fun `CONNECT names the target by hostname, and an IPv6 literal without brackets`() {
        for ((target, expected) in listOf("example.com" to "3 example.com:443", "[2001:db8::1]" to "3 2001:db8::1:443")) {
            FakeSocks5().use { proxy ->
                Socks5Tunnel.open("127.0.0.1", proxy.port, target, 443).close()
                assertEquals(expected, proxy.poll(proxy.connects))
            }
        }
    }

    @Test fun `a non-zero RFC 1929 status is a rejected login, and the socket is closed`() {
        FakeSocks5(method = 2, authStatus = 1).use { proxy ->
            val error = expectRejected { Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443, ProxyLogin("alice", "s3cret")) }
            assertFalse("alice" in error.message.orEmpty())
            assertFalse("s3cret" in error.message.orEmpty())
        }
    }

    /** Ruling 3: no acceptable method means the proxy wants a login we do not have, or will not take ours. */
    @Test fun `no acceptable method is a rejected login, with or without one`() {
        for (login in listOf(null, ProxyLogin("alice", "s3cret"))) {
            FakeSocks5(method = 0xFF).use { proxy ->
                expectRejected { Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443, login) }
            }
        }
    }

    /** Review Focus 1: refused before any byte reaches the proxy. */
    @Test fun `a login that cannot be sent is rejected without connecting`() {
        val unsendable = listOf(
            ProxyLogin("", "pw"),
            ProxyLogin("u".repeat(256), "pw"),
            ProxyLogin("alice", "p".repeat(256)),
            ProxyLogin("é".repeat(128), "pw"), // 128 characters, 256 UTF-8 bytes
        )
        for (login in unsendable) {
            FakeSocks5(method = 2).use { proxy ->
                expectRejected { Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443, login) }
                Thread.sleep(100)
                assertEquals(0, proxy.accepted.get())
            }
        }
    }

    @Test fun `a 255-byte user and password are sent`() {
        FakeSocks5(method = 2).use { proxy ->
            Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443, ProxyLogin("u".repeat(255), "p".repeat(255))).close()
            assertEquals(1 + 1 + 255 + 1 + 255, proxy.poll(proxy.auths)!!.size)
        }
    }

    /** Review Focus 3: the reply code is read before any bound address. */
    @Test fun `a non-zero reply is a ProxyTunnelException with its code`() {
        FakeSocks5(reply = 5).use { proxy ->
            try {
                Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443)
                fail("expected ProxyTunnelException")
            } catch (error: ProxyTunnelException) {
                assertEquals(5, error.statusCode)
            }
        }
    }

    @Test fun `after success the stream is at the first payload byte, whatever the bound address type`() {
        for (type in listOf(1, 3, 4)) {
            FakeSocks5(boundType = type).use { proxy ->
                Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443).use { socket ->
                    assertTrue(socket.isConnected)
                    socket.getOutputStream().write('x'.code)
                    socket.getOutputStream().flush()
                    assertEquals('x'.code, socket.getInputStream().read())
                }
            }
        }
    }

    /** Review Focus 2: neither hangs nor reads as a rejected login. */
    @Test fun `a proxy that closes mid-handshake, or is not SOCKS5, fails with an IOException`() {
        val scripts = listOf<(java.net.Socket) -> Unit>(
            { it.getInputStream().read(); it.close() },
            { client -> client.getInputStream().read(ByteArray(3)); client.getOutputStream().write(byteArrayOf(4, 0)); client.getOutputStream().flush() },
        )
        for (script in scripts) {
            FakeSocks5(script = script).use { proxy ->
                try {
                    Socks5Tunnel.open("127.0.0.1", proxy.port, "example.com", 443)
                    fail("expected IOException")
                } catch (error: IOException) {
                    assertFalse(error is ProxyLoginRejectedException)
                }
            }
        }
    }

    /**
     * Plan 19 final review, Minor 4: Tor answers a CONNECT only once a circuit
     * is built, so its handshake waits as long as Tor's own `SocksTimeout`
     * (120 s); a SOCKS5 proxy keeps 15 s. The returned socket still carries
     * the handshake's read timeout, so it shows which one was used.
     */
    @Test fun `a Tor route waits 120 s for the SOCKS handshake, a SOCKS5 route 15 s`() {
        FakeSocks5(method = 2).use { proxy ->
            Router.connect(
                Route.Tor("/data/files/tor/socks:0", ProxyLogin("u", "p")), "example.com", 443,
                local = { java.net.Socket("127.0.0.1", proxy.port) },
            ).use { assertEquals(120_000, it.soTimeout) }
        }
        FakeSocks5().use { proxy ->
            Router.connect(Route.Proxy("127.0.0.1", proxy.port, socks = true), "example.com", 443)
                .use { assertEquals(15_000, it.soTimeout) }
        }
    }

    @Test fun `the router sends a SOCKS route's login`() {
        FakeSocks5(method = 2).use { proxy ->
            Router.connect(Route.Proxy("127.0.0.1", proxy.port, socks = true, login = ProxyLogin("alice", "s3cret")), "example.com", 443).close()
            assertArrayEquals(byteArrayOf(5, 1, 2), proxy.poll(proxy.greetings))
        }
    }
}

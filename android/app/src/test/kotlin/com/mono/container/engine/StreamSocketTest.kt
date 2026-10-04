package com.mono.container.engine

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLSocketFactory

/** Built-in Tor spec §4.4: a Unix socket handed around as a `java.net.Socket`. */
class StreamSocketTest {

    @Test fun `its streams, timeout and close are the channel's`() {
        val out = ByteArrayOutputStream()
        val timeouts = mutableListOf<Int>()
        var closes = 0
        val socket = StreamSocket(ByteArrayInputStream(byteArrayOf(7)), out, { closes++ }, setTimeout = { timeouts += it })

        assertEquals(7, socket.getInputStream().read())
        socket.getOutputStream().write(9)
        socket.soTimeout = 1234

        assertArrayEquals(byteArrayOf(9), out.toByteArray())
        assertEquals(listOf(1234), timeouts)
        assertEquals(1234, socket.soTimeout)
        assertTrue(socket.isConnected)

        socket.close()
        socket.close()
        assertEquals(1, closes)
        assertTrue(socket.isClosed)
    }

    @Test fun `shutdowns go to the channel`() {
        var ins = 0
        var outs = 0
        val socket = StreamSocket(ByteArrayInputStream(ByteArray(0)), ByteArrayOutputStream(), {}, shutdownIn = { ins++ }, shutdownOut = { outs++ })

        socket.shutdownInput()
        socket.shutdownOutput()

        assertEquals(1, ins)
        assertEquals(1, outs)
        assertTrue(socket.isInputShutdown)
        assertTrue(socket.isOutputShutdown)
    }

    /** Downloads layer TLS on whatever `Router.connect` returns (`ProxyHttpClient.startTls`). */
    @Test fun `TLS can be layered on it, and closing that closes the channel`() {
        var closes = 0
        val socket = StreamSocket(ByteArrayInputStream(ByteArray(0)), ByteArrayOutputStream(), { closes++ })

        val tls = (SSLSocketFactory.getDefault() as SSLSocketFactory).createSocket(socket, "example.com", 443, true)
        tls.close()

        assertEquals(1, closes)
    }

    /** What Tor's SOCKS port sees: a login, and the target by name. */
    @Test fun `a SOCKS5 handshake runs over it`() {
        val server = ServerSocket(0)
        val seen = ArrayBlockingQueue<String>(2)
        Thread {
            runCatching {
                server.accept().use { client ->
                    val input = DataInputStream(client.getInputStream())
                    val out = client.getOutputStream()
                    input.readFully(ByteArray(3)) // 5, 1, method 2
                    out.write(byteArrayOf(5, 2))
                    input.readUnsignedByte() // sub-negotiation version
                    val user = ByteArray(input.readUnsignedByte()).also(input::readFully)
                    val password = ByteArray(input.readUnsignedByte()).also(input::readFully)
                    seen += "${String(user)}:${String(password)}"
                    out.write(byteArrayOf(1, 0))
                    input.readFully(ByteArray(4)) // 5, 1, 0, 3
                    val host = ByteArray(input.readUnsignedByte()).also(input::readFully)
                    input.readFully(ByteArray(2))
                    seen += String(host)
                    out.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0))
                    out.write(input.readUnsignedByte())
                    out.flush()
                }
            }
        }.start()
        val tcp = Socket("127.0.0.1", server.localPort)
        val wrapped = StreamSocket(tcp.getInputStream(), tcp.getOutputStream(), tcp::close, setTimeout = { tcp.soTimeout = it })

        val tunnel = Socks5Tunnel.over(wrapped, "abc.onion", 80, ProxyLogin("u", "p"))
        tunnel.getOutputStream().write(42)

        assertEquals(42, tunnel.getInputStream().read())
        assertEquals("u:p", seen.poll(5, TimeUnit.SECONDS))
        assertEquals("abc.onion", seen.poll(5, TimeUnit.SECONDS))
        tunnel.close()
        server.close()
    }
}

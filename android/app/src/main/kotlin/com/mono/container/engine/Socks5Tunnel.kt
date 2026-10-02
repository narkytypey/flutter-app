package com.mono.container.engine

import java.io.DataInputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket

/**
 * A SOCKS5 client by hand (RFC 1928, with RFC 1929 username/password),
 * replacing the platform's: `java.net.Socket`'s only login hook is the
 * process-wide `Authenticator`, one login per proxy host:port, so two sites on
 * one Tor port could never have two logins (proxy-auth spec §2.2). Every SOCKS
 * route uses it, logged in or not (ruling 1).
 *
 * Exactly one method is offered (ruling 3). The target always goes as a
 * hostname, address type 3 (ruling 2), as the platform sent an unresolved
 * address, so the proxy does every lookup and the device none.
 *
 * The returned socket is at the first byte of tunnel payload, with the
 * handshake's read timeout still set, like [HttpConnectTunnel]'s. Its
 * exceptions name no credential and no host.
 */
object Socks5Tunnel {
    private const val TIMEOUT_MS = 15_000
    private const val NO_AUTH = 0x00
    private const val USER_PASSWORD = 0x02
    private const val NO_ACCEPTABLE_METHOD = 0xFF

    fun open(proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int, login: ProxyLogin? = null): Socket {
        // Checked before connecting: a login that cannot be sent never reaches the proxy (ruling 9).
        val user = login?.user?.toByteArray(Charsets.UTF_8)
        val password = login?.password?.toByteArray(Charsets.UTF_8)
        if (user != null && password != null && (user.isEmpty() || user.size > 255 || password.size > 255)) {
            throw ProxyLoginRejectedException("the login cannot be sent to a SOCKS5 proxy")
        }
        val host = targetHost.removeSurrounding("[", "]").toByteArray(Charsets.UTF_8)
        if (host.isEmpty() || host.size > 255) throw IOException("the target cannot be named to a SOCKS5 proxy")

        val socket = Socket()
        try {
            socket.connect(InetSocketAddress(proxyHost, proxyPort), TIMEOUT_MS)
            socket.soTimeout = TIMEOUT_MS
            val input = DataInputStream(socket.getInputStream())
            val out = socket.getOutputStream()

            val method = if (user != null) USER_PASSWORD else NO_AUTH
            out.write(byteArrayOf(5, 1, method.toByte()))
            out.flush()
            if (input.readUnsignedByte() != 5) throw IOException("not a SOCKS5 proxy")
            when (input.readUnsignedByte()) {
                method -> Unit
                NO_ACCEPTABLE_METHOD -> throw ProxyLoginRejectedException("the SOCKS5 proxy accepted no offered method")
                else -> throw IOException("the SOCKS5 proxy chose a method it was not offered")
            }

            if (user != null && password != null) {
                out.write(byteArrayOf(1, user.size.toByte()) + user + byteArrayOf(password.size.toByte()) + password)
                out.flush()
                input.readUnsignedByte() // sub-negotiation version
                if (input.readUnsignedByte() != 0) throw ProxyLoginRejectedException("the SOCKS5 proxy rejected the login")
            }

            out.write(
                byteArrayOf(5, 1, 0, 3, host.size.toByte()) + host +
                    byteArrayOf((targetPort shr 8).toByte(), targetPort.toByte())
            )
            out.flush()
            if (input.readUnsignedByte() != 5) throw IOException("not a SOCKS5 proxy")
            // The reply code comes before the bound address, which a failing proxy may not send.
            val reply = input.readUnsignedByte()
            if (reply != 0) throw ProxyTunnelException(reply, "the SOCKS5 proxy refused the destination (reply $reply)")
            input.readUnsignedByte() // reserved
            val addressLength = when (val type = input.readUnsignedByte()) {
                1 -> 4
                3 -> input.readUnsignedByte()
                4 -> 16
                else -> throw IOException("the SOCKS5 proxy replied with address type $type")
            }
            input.readFully(ByteArray(addressLength + 2)) // bound address and port, unused
            return socket
        } catch (error: Throwable) {
            // As HttpConnectTunnel: never leak a half-open socket to the proxy.
            runCatching { socket.close() }
            throw error
        }
    }
}

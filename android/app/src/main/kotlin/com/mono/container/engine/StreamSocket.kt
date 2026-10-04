package com.mono.container.engine

import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.Socket

/**
 * A [Socket] over another stream connection (built-in Tor spec §4.4). The
 * engine hands `java.net.Socket`s around: the loopback proxy relays them and
 * downloads layer TLS on them. Tor's SOCKS port is a Unix socket, which
 * Android opens as a `LocalSocket`, not a `Socket`; this carries its streams.
 *
 * It is never connected the `Socket` way: it reports connected from birth,
 * and every stream, timeout and close goes to the channel.
 *
 * Close must wake a thread blocked reading: the loopback proxy ends a tunnel
 * by closing the socket under its relay thread. A Unix channel's `close()` is
 * a plain `close(fd)`, which does not wake it; `shutdown` does. So the Unix
 * channel shuts down both directions before closing ([localSocket]).
 */
class StreamSocket(
    private val input: InputStream,
    private val output: OutputStream,
    private val closeChannel: () -> Unit,
    private val setTimeout: (Int) -> Unit = {},
    private val shutdownIn: () -> Unit = {},
    private val shutdownOut: () -> Unit = {},
) : Socket() {
    @Volatile private var closed = false
    @Volatile private var inputShutdown = false
    @Volatile private var outputShutdown = false
    @Volatile private var timeout = 0

    override fun getInputStream(): InputStream = input
    override fun getOutputStream(): OutputStream = output
    override fun isConnected() = true
    override fun isBound() = true
    override fun isClosed() = closed
    override fun getSoTimeout() = timeout

    override fun setSoTimeout(timeout: Int) {
        this.timeout = timeout
        setTimeout(timeout)
    }

    override fun shutdownInput() {
        inputShutdown = true
        runCatching(shutdownIn)
    }

    override fun shutdownOutput() {
        outputShutdown = true
        runCatching(shutdownOut)
    }

    override fun isInputShutdown() = inputShutdown
    override fun isOutputShutdown() = outputShutdown

    override fun getInetAddress(): InetAddress? = null
    override fun getPort() = 0

    @Synchronized override fun close() {
        if (closed) return
        closed = true
        runCatching(closeChannel)
    }

    override fun toString() = "StreamSocket"
}

/** Connects to Tor's Unix socket at [path]. Android only: the JVM tests pass their own to [Router.connect]. */
fun localSocket(path: String): Socket {
    val local = android.net.LocalSocket()
    try {
        local.connect(android.net.LocalSocketAddress(path, android.net.LocalSocketAddress.Namespace.FILESYSTEM))
    } catch (error: Throwable) {
        runCatching { local.close() }
        throw error
    }
    return StreamSocket(
        local.inputStream, local.outputStream,
        closeChannel = {
            // shutdown first: a bare close does not wake a thread blocked in read.
            runCatching { local.shutdownInput() }
            runCatching { local.shutdownOutput() }
            local.close()
        },
        setTimeout = { local.soTimeout = it },
        shutdownIn = local::shutdownInput,
        shutdownOut = local::shutdownOutput,
    )
}

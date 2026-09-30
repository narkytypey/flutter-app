package com.mono.container.engine

import java.io.EOFException
import java.io.InputStream
import java.io.OutputStream
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * P2's loopback proxy (spec §1.1). WebView's process-wide override sends every
 * request of every site here. Each connection is authenticated by the
 * credential its site's view answered the `407` with ([SiteCredentials]),
 * routed on that site's own route by [Router], and relayed. Since TLS runs end
 * to end between Chromium and the destination, the proxy never sees inside it.
 *
 * Nothing here runs on the main thread: [resolve] probes the upstream proxy
 * (`a42896d`). Nothing here logs a host or a credential.
 *
 * [resolve] and [connect] are parameters so the JVM tests can refuse a route
 * or fail a connection. The app uses the defaults.
 */
class LoopbackProxy(
    private val credentials: SiteCredentials,
    private val resolve: (SiteConfig) -> Route = { it.currentRoute() },
    private val connect: (Route, String, Int) -> Socket = Router::connect,
) : AutoCloseable {

    /** `127.0.0.1` only, never any other interface; the OS picks the port. */
    private val server = ServerSocket(0, BACKLOG, InetAddress.getByAddress(byteArrayOf(127, 0, 0, 1)))

    private val workers: ExecutorService = Executors.newCachedThreadPool { task ->
        Thread(task, "loopback-proxy").apply { isDaemon = true }
    }

    val port: Int get() = server.localPort
    val address: InetAddress get() = server.inetAddress

    fun start(): LoopbackProxy {
        Thread({
            while (!server.isClosed) {
                val client = runCatching { server.accept() }.getOrNull() ?: continue
                runCatching { workers.execute { handle(client) } }.onFailure { runCatching { client.close() } }
            }
        }, "loopback-proxy-accept").apply { isDaemon = true }.start()
        return this
    }

    override fun close() {
        runCatching { server.close() }
        workers.shutdownNow()
    }

    private fun handle(client: Socket) {
        client.use {
            runCatching {
                // A head that never finishes must not hold a thread for ever.
                client.soTimeout = HEAD_TIMEOUT_MS
                val input = client.getInputStream().buffered()
                val output = client.getOutputStream()
                when (val decision = decide(readHead(input)?.let(::parseRequest), credentials::lookup)) {
                    is ProxyDecision.Reply -> output.write(statusResponse(decision.status))
                    is ProxyDecision.Tunnel -> tunnel(client, input, output, decision)
                    is ProxyDecision.Forward -> forward(client, input, output, decision)
                }
                output.flush()
            }
        }
    }

    /**
     * A socket to [host]:[port] on [binding]'s route, or null once [output]
     * has been answered. A refused route is reported to the site, as the
     * interceptor reported it before P2. A failed connection is answered and
     * reported to no one (plan deviation 1).
     */
    private fun upstream(binding: ProxyBinding, host: String, port: Int, output: OutputStream): Socket? {
        val route = resolve(binding.config)
        if (route is Route.Refused) {
            binding.onRefused(route.failure)
            output.write(statusResponse(502))
            return null
        }
        return try {
            // HttpConnectTunnel leaves its handshake timeout set; a relay has none.
            connect(route, host, port).apply { soTimeout = 0 }
        } catch (error: Exception) {
            output.write(statusResponse(upstreamFailureStatus(error)))
            null
        }
    }

    private fun tunnel(client: Socket, input: InputStream, output: OutputStream, tunnel: ProxyDecision.Tunnel) {
        val upstream = upstream(tunnel.binding, tunnel.host, tunnel.port, output) ?: return
        upstream.use {
            client.soTimeout = 0
            output.write(CONNECTION_ESTABLISHED)
            output.flush()
            val back = workers.submit(Runnable {
                pump(upstream.getInputStream(), output)
                closeBoth(client, upstream)
            })
            pump(input, upstream.getOutputStream())
            // Either side closing ends both (spec §7).
            closeBoth(client, upstream)
            runCatching { back.get() }
        }
    }

    /**
     * An absolute-form `http` request (spec §3.2): one request per connection,
     * so requests to different hosts never share one. Only the declared body
     * is sent on; anything the client sends after it ends the connection.
     */
    private fun forward(client: Socket, input: InputStream, output: OutputStream, forward: ProxyDecision.Forward) {
        val upstream = upstream(forward.binding, forward.host, forward.port, output) ?: return
        upstream.use {
            client.soTimeout = 0
            val toUpstream = upstream.getOutputStream()
            toUpstream.write(forward.head.toByteArray(Charsets.ISO_8859_1))
            copyExactly(input, toUpstream, forward.bodyLength)
            toUpstream.flush()
            val back = workers.submit(Runnable {
                runCatching {
                    val fromUpstream = upstream.getInputStream().buffered()
                    val head = readHead(fromUpstream) ?: return@runCatching
                    output.write(closingResponseHead(head).toByteArray(Charsets.ISO_8859_1))
                    pump(fromUpstream, output)
                }
                closeBoth(client, upstream)
            })
            runCatching { input.read() }
            closeBoth(client, upstream)
            runCatching { back.get() }
        }
    }

    companion object {
        private const val BACKLOG = 64
        private const val HEAD_TIMEOUT_MS = 30_000
        private const val BUFFER_BYTES = 16 * 1024

        private fun pump(from: InputStream, to: OutputStream) {
            val buffer = ByteArray(BUFFER_BYTES)
            runCatching {
                while (true) {
                    val read = from.read(buffer)
                    if (read < 0) break
                    to.write(buffer, 0, read)
                    to.flush()
                }
            }
        }

        private fun copyExactly(from: InputStream, to: OutputStream, length: Long) {
            val buffer = ByteArray(BUFFER_BYTES)
            var left = length
            while (left > 0) {
                val read = from.read(buffer, 0, minOf(buffer.size.toLong(), left).toInt())
                if (read < 0) throw EOFException("the request body ended early")
                to.write(buffer, 0, read)
                left -= read
            }
        }

        private fun closeBoth(a: Socket, b: Socket) {
            runCatching { a.close() }
            runCatching { b.close() }
        }
    }
}

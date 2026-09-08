# HTTP CONNECT Tunnel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `ProxyMode.http` actually work by writing the HTTP CONNECT tunnel that Android removed from `java.net.Socket`, so a site configured with an HTTP proxy reaches its destination instead of throwing at socket construction.

**Architecture:** Add one new file, `HttpConnectTunnel.kt`, that opens a plain socket to the proxy, writes a `CONNECT host:port HTTP/1.1` request, requires a 2xx status, and hands back the still-open socket now tunnelled to the target. `Router.connect` calls it for `Route.Proxy(socks = false)` instead of constructing `java.net.Socket(java.net.Proxy(Type.HTTP, …))`. Everything downstream is unchanged: `ProxyHttpClient.startTls` already wraps whatever socket `Router.connect` returns, so TLS-over-CONNECT works the moment the tunnel exists.

**Tech Stack:** Kotlin, `java.net.Socket`/`ServerSocket`, JUnit 4 (`junit:junit:4.13.2`, already declared in `android/app/build.gradle.kts:47`). JVM unit tests under `android/app/src/test/kotlin/`, run with `./gradlew :app:testDebugUnitTest` from `android/`. No new dependencies.

**Spec:** None. **This plan has no approved design spec and must not be executed until it gets one or the user approves the design decisions inline.** Every other plan in this directory implements a spec under `docs/superpowers/specs/` that was brainstormed and approved first; this one was written directly from a defect record. The source material is defect 5 in `docs/superpowers/plans/2026-09-08-download-manager-integration.md`, which documents the breakage but deliberately does not choose a fix. The design decisions this plan makes on its own — hand-rolled CONNECT rather than a dependency, no proxy authentication, `PROXY_REFUSED` as the failure mapping — are called out at each point and are exactly what needs approval.

## Global Constraints

- **Android only, dark theme only.** No light theme, no toggle.
- **No network requests of the app's own.** No account, sync, analytics, or telemetry, ever. (The tunnel carries only requests a site already made.)
- **The interceptor never falls back to direct.** A site set to a proxy that becomes unreachable is refused, never silently sent unproxied. **This is the constraint most at risk in this plan**: a failed CONNECT must refuse, never retry without the proxy.
- **`minSdk` is 29** (`android/app/build.gradle.kts:22`).
- **No code generation anywhere** (no `build_runner`, `freezed`, `drift`) — hand-written mappers only.
- **IBM Plex Mono for anything technical**, Figtree for everything else. (No UI in this plan.)
- **Never paraphrase, re-capitalise, or "improve" user-facing copy.** The one user-visible string this plan reaches, `'The proxy refused the destination'`, already exists in `lib/domain/models/route_decision.dart:56` and must not be reworded.

## Background: why this is needed

`android/app/src/main/kotlin/com/mono/container/engine/Router.kt:36` builds an HTTP-proxied socket as:

```kotlin
val type = if (route.socks) java.net.Proxy.Type.SOCKS
           else java.net.Proxy.Type.HTTP
java.net.Socket(java.net.Proxy(type, java.net.InetSocketAddress(route.host, route.port)))
```

AOSP removed `Proxy.Type.HTTP` support from `java.net.Socket`. From the platform source on this machine, `$LOCALAPPDATA/Android/Sdk/sources/android-36/java/net/Socket.java`:

```java
Proxy.Type type = p.type();
// Android-changed: Removed HTTP proxy support.
// if (type == Proxy.Type.SOCKS || type == Proxy.Type.HTTP) {
if (type == Proxy.Type.SOCKS) {
    ...
    // Android-changed: Removed HTTP proxy support.
    // impl = type == Proxy.Type.SOCKS ? new SocksSocketImpl(p)
    //                                : new HttpConnectSocketImpl(p);
    impl = new SocksSocketImpl(p);
} else {
    if (p == Proxy.NO_PROXY) { ... }
    else throw new IllegalArgumentException("Invalid Proxy");
}
```

`Type.HTTP` falls to the `else`, is not `NO_PROXY`, and throws `IllegalArgumentException("Invalid Proxy")`. OpenJDK's `HttpConnectSocketImpl` — which would have issued the CONNECT — does not exist on Android. So the tunnel has to be written by hand, which is all this plan does.

The path is user-reachable: `ProxyMode.http` is an option in `lib/domain/models/site.dart:6`, serialized as `'http'` by `lib/domain/models/site_descriptor.dart:15`, which makes `socks = false` at `Router.kt:28`.

**Two facts that shape the design:**

1. **`RouteFailure.PROXY_REFUSED` already exists end to end with no producer.** The enum value is at `Router.kt:4`, `routeFailureToDartName` already maps `"PROXY_REFUSED" -> "proxyRefused"` at `EngineChannel.kt:398`, the Dart decoder already accepts `'proxyRefused'` at `container_engine_channel.dart:27`, and the user-facing copy already reads `'The proxy refused the destination'` at `route_decision.dart:56`. Nothing anywhere ever produces it. A proxy that refuses CONNECT is exactly what that failure mode was reserved for, so this plan wires up an existing path rather than inventing one — the same shape as `TLS_FAILURE`, which sat unreachable until TLS was implemented at `9c598a1`.

2. **An interim fix at `ca9552c` already guards the broken path, and this plan must undo it.** Before that commit, `IllegalArgumentException` hit the `else -> RouteFailure.UPSTREAM_TIMEOUT` branch, so a permanent platform incompatibility showed the user a transient, retry-shaped timeout — late, after `ProxyProbe` had made the proxy look reachable. `ca9552c` fixed the symptom by refusing early instead: **both** `Router.resolve` (Kotlin) and `routeFor` in `lib/domain/models/route_decision.dart` (Dart) now return a `MISCONFIGURED` refusal for any mode that is not `socks5`. That was the right interim call, but it means implementing the tunnel is not enough on its own — an HTTP-proxied site would still be refused before `connect` is ever reached. **Task 2 re-admits `http` on both sides**, and doing so is what turns the tunnel from dead code into a working feature.

3. **`ca9552c` also left a deliberate defensive branch.** `RequestInterceptor` now maps `IllegalArgumentException -> RouteFailure.MISCONFIGURED`, commented as unreachable while `resolve` guards. Keep it. Once Task 2 re-admits `http` it stops being belt-and-braces and becomes the thing that catches any future unsupported `Proxy.Type` — do not delete it as dead code.

---

### Task 1: `HttpConnectTunnel` — the tunnel itself

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/HttpConnectTunnel.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/HttpConnectTunnelTest.kt`

**Interfaces:**
- Consumes: nothing from other tasks. This task is self-contained and can land alone.
- Produces:
  - `class ProxyTunnelException(val statusCode: Int, message: String) : java.io.IOException(message)`
  - `object HttpConnectTunnel` with `fun open(proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int): java.net.Socket`

  Task 2 calls `HttpConnectTunnel.open`; Task 3 catches `ProxyTunnelException`.

**Design note requiring approval:** this hand-rolls CONNECT rather than adding OkHttp, which supports HTTP proxies natively. Hand-rolling matches the existing code — `ProxyHttpClient` already speaks raw HTTP over a socket rather than using a library — and adds no dependency to a privacy-first app. The cost is that redirects, chunked transfer, proxy authentication and keep-alive stay unimplemented here, exactly as they already are in `ProxyHttpClient`.

- [ ] **Step 1: Write the failing test**

Create `android/app/src/test/kotlin/com/mono/container/engine/HttpConnectTunnelTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.net.ServerSocket
import java.util.concurrent.ArrayBlockingQueue

class HttpConnectTunnelTest {

    /**
     * A fake HTTP proxy on an ephemeral port. Accepts one connection, records
     * the request line it was sent, replies with [response], then (for a 200)
     * echoes whatever the client writes next so the test can prove the socket
     * is still usable as a tunnel afterwards.
     */
    private class FakeProxy(private val response: String, private val echo: Boolean) : AutoCloseable {
        val server = ServerSocket(0)
        val requestLines = ArrayBlockingQueue<String>(1)

        init {
            Thread {
                runCatching {
                    server.accept().use { client ->
                        val input = client.getInputStream()
                        val requestLine = readLine(input)
                        while (readLine(input).isNotEmpty()) { /* drain headers */ }
                        requestLines.offer(requestLine)
                        val out = client.getOutputStream()
                        out.write(response.toByteArray(Charsets.US_ASCII))
                        out.flush()
                        if (echo) {
                            val byte = input.read()
                            if (byte != -1) { out.write(byte); out.flush() }
                        }
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        private fun readLine(input: java.io.InputStream): String {
            val line = StringBuilder()
            while (true) {
                val byte = input.read()
                if (byte == -1 || byte == '\n'.code) break
                if (byte != '\r'.code) line.append(byte.toChar())
            }
            return line.toString()
        }

        override fun close() = server.close()
    }

    @Test fun `sends CONNECT with the target authority, not the proxy's`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
            HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443).close()
            assertEquals("CONNECT example.com:443 HTTP/1.1", proxy.requestLines.take())
        }
    }

    @Test fun `returns a still-open socket on 200`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = true).use { proxy ->
            HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443).use { socket ->
                assertTrue(socket.isConnected)
                assertTrue(!socket.isClosed)
                // The header block must have been consumed: the next byte the
                // client reads is tunnel payload, not a leftover header line.
                socket.getOutputStream().write('x'.code)
                socket.getOutputStream().flush()
                assertEquals('x'.code, socket.getInputStream().read())
            }
        }
    }

    @Test fun `throws ProxyTunnelException when the proxy refuses`() {
        FakeProxy("HTTP/1.1 407 Proxy Authentication Required\r\n\r\n", echo = false).use { proxy ->
            try {
                HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443)
                fail("expected ProxyTunnelException")
            } catch (error: ProxyTunnelException) {
                assertEquals(407, error.statusCode)
            }
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run from the `android/` directory: `./gradlew :app:testDebugUnitTest --tests '*HttpConnectTunnelTest*'`

Expected: FAIL to compile, with unresolved references to `HttpConnectTunnel` and `ProxyTunnelException`.

- [ ] **Step 3: Write the implementation**

Create `android/app/src/main/kotlin/com/mono/container/engine/HttpConnectTunnel.kt`:

```kotlin
package com.mono.container.engine

import java.io.IOException
import java.io.InputStream
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Raised when a proxy answers CONNECT with anything other than 2xx — a 407
 * wanting credentials, a 403 refusing the destination, a 502 failing to reach
 * it. Carries [statusCode] so callers can tell those apart if they ever need
 * to; today they all map to one failure.
 */
class ProxyTunnelException(val statusCode: Int, message: String) : IOException(message)

/**
 * Opens an HTTP CONNECT tunnel by hand.
 *
 * Android removed `Proxy.Type.HTTP` from [java.net.Socket] — see the
 * `// Android-changed: Removed HTTP proxy support.` marker in libcore's
 * `Socket.java` — so OpenJDK's `HttpConnectSocketImpl`, which would have
 * issued this CONNECT, does not exist here. Constructing a socket with a
 * `Type.HTTP` proxy throws `IllegalArgumentException("Invalid Proxy")`
 * instead. This object is that missing implementation.
 *
 * The returned socket is connected to the proxy but addressed to the target:
 * everything written after CONNECT succeeds is relayed end to end, which is
 * what makes it safe for [ProxyHttpClient] to negotiate TLS over it.
 */
object HttpConnectTunnel {
    private const val CONNECT_TIMEOUT_MS = 15_000

    fun open(proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int): Socket {
        val socket = Socket()
        try {
            socket.connect(InetSocketAddress(proxyHost, proxyPort), CONNECT_TIMEOUT_MS)
            socket.soTimeout = CONNECT_TIMEOUT_MS
            val authority = "$targetHost:$targetPort"
            val out = socket.getOutputStream()
            out.write("CONNECT $authority HTTP/1.1\r\n".toByteArray(Charsets.US_ASCII))
            out.write("Host: $authority\r\n".toByteArray(Charsets.US_ASCII))
            out.write("\r\n".toByteArray(Charsets.US_ASCII))
            out.flush()

            val status = readStatus(socket.getInputStream())
            if (status !in 200..299) {
                throw ProxyTunnelException(status, "Proxy refused CONNECT to $authority (HTTP $status)")
            }
            return socket
        } catch (error: Throwable) {
            // Never leak a half-open socket to the proxy. Closing here also
            // means a caller that catches the exception has nothing to clean up.
            runCatching { socket.close() }
            throw error
        }
    }

    /**
     * Reads the status line and drains the header block, leaving the stream
     * positioned at the first byte of tunnel payload. The body of a CONNECT
     * response is empty by definition, so there is nothing else to consume.
     */
    private fun readStatus(input: InputStream): Int {
        val statusLine = readLine(input)
        while (readLine(input).isNotEmpty()) { /* drain headers */ }
        return statusLine.split(' ', limit = 3).getOrNull(1)?.toIntOrNull() ?: 502
    }

    private fun readLine(input: InputStream): String {
        val line = StringBuilder()
        while (true) {
            val byte = input.read()
            if (byte == -1 || byte == '\n'.code) break
            if (byte != '\r'.code) line.append(byte.toChar())
        }
        return line.toString()
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run from `android/`: `./gradlew :app:testDebugUnitTest --tests '*HttpConnectTunnelTest*'`

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/HttpConnectTunnel.kt android/app/src/test/kotlin/com/mono/container/engine/HttpConnectTunnelTest.kt
git commit -m "feat: hand-rolled HTTP CONNECT tunnel for Android"
```

---

### Task 2: Route HTTP-proxied sites through the tunnel, and re-admit `http` mode

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Router.kt` — both `resolve` (drop the `ca9552c` guard) and `connect` (use the tunnel)
- Modify: `lib/domain/models/route_decision.dart` — drop the mirrored Dart guard from `ca9552c`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt` (append; the file exists with 4 tests)
- Test: `test/domain/route_decision_test.dart` (modify the test `ca9552c` added)

**Interfaces:**
- Consumes: `HttpConnectTunnel.open(proxyHost, proxyPort, targetHost, targetPort)` from Task 1.
- Produces: no signature change. `Router.connect(route, targetHost, targetPort): java.net.Socket` keeps its exact shape, so `ProxyHttpClient.fetch` needs no edit at all — it already wraps whatever socket comes back.

**Read this before starting.** `ca9552c` deliberately refuses non-`socks5` modes in two places. Removing only the Kotlin guard leaves the Dart layer still refusing, and vice versa; the feature works only when both go. Do not widen either guard to "anything that is not direct" — the property `ca9552c` was protecting, that an *unrecognised* mode can never silently inherit a broken path, must survive. Re-admit `http` by name, keep refusing everything else.

- [ ] **Step 1: Write the failing test**

Append to `android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt`, inside the existing `RouterTest` class (keep the existing `config` helper and 4 tests as they are):

```kotlin
    @Test fun `an http-proxied route opens a CONNECT tunnel instead of throwing`() {
        val proxy = java.net.ServerSocket(0)
        Thread {
            runCatching {
                proxy.accept().use { client ->
                    val input = client.getInputStream()
                    val builder = StringBuilder()
                    while (true) {
                        val byte = input.read()
                        if (byte == -1 || byte == '\n'.code) break
                        if (byte != '\r'.code) builder.append(byte.toChar())
                    }
                    while (true) {
                        val line = StringBuilder()
                        while (true) {
                            val byte = input.read()
                            if (byte == -1 || byte == '\n'.code) break
                            if (byte != '\r'.code) line.append(byte.toChar())
                        }
                        if (line.isEmpty()) break
                    }
                    client.getOutputStream().write(
                        "HTTP/1.1 200 Connection established\r\n\r\n".toByteArray(Charsets.US_ASCII)
                    )
                    client.getOutputStream().flush()
                }
            }
        }.apply { isDaemon = true }.start()

        val route = Route.Proxy("127.0.0.1", proxy.localPort, socks = false)
        Router.connect(route, "example.com", 443).use { socket ->
            assertTrue(socket.isConnected)
        }
        proxy.close()
    }
```

Add `import org.junit.Assert.assertTrue` only if it is not already imported — it is, at the top of the existing file.

- [ ] **Step 2: Run the test to verify it fails**

Run from `android/`: `./gradlew :app:testDebugUnitTest --tests '*RouterTest*'`

Expected: FAIL with `java.lang.IllegalArgumentException: Invalid Proxy`. This is the defect reproducing as a test — confirm you see that exact message before fixing it, because it is the proof the test exercises the real bug rather than passing for an unrelated reason.

- [ ] **Step 3: Replace the `Type.HTTP` branch with the tunnel**

In `android/app/src/main/kotlin/com/mono/container/engine/Router.kt`, replace the whole `connect` function:

```kotlin
    /**
     * Opens a socket for [route]. Never called for [Route.Refused].
     *
     * SOCKS is delegated to the platform, which still supports it. HTTP proxies
     * go through [HttpConnectTunnel] because Android removed `Proxy.Type.HTTP`
     * from [java.net.Socket]; passing it here throws `IllegalArgumentException`.
     */
    fun connect(route: Route, targetHost: String, targetPort: Int): java.net.Socket =
        when (route) {
            is Route.Direct -> java.net.Socket(targetHost, targetPort)
            is Route.Proxy ->
                if (route.socks) {
                    java.net.Socket(
                        java.net.Proxy(
                            java.net.Proxy.Type.SOCKS,
                            java.net.InetSocketAddress(route.host, route.port),
                        )
                    ).apply { connect(java.net.InetSocketAddress(targetHost, targetPort), 15_000) }
                } else {
                    HttpConnectTunnel.open(route.host, route.port, targetHost, targetPort)
                }
            is Route.Refused -> error("connect() called for a refused route")
        }
```

Note that `java.net.Proxy.Type.HTTP` no longer appears anywhere in the file. That is the point of the change.

- [ ] **Step 4: Run the test to verify it passes**

Run from `android/`: `./gradlew :app:testDebugUnitTest --tests '*RouterTest*'`

Expected: PASS, 5 tests (the 4 existing plus the new one).

- [ ] **Step 5: Re-admit `http` in the Kotlin resolver**

In `Router.resolve`, replace the `ca9552c` guard. It currently reads:

```kotlin
        if (config.proxyMode != "socks5") {
            return Route.Refused(RouteFailure.MISCONFIGURED)
        }
```

Replace it with a guard that still rejects unknown modes but lets `http` through, and update the comment so it no longer claims the mode cannot work:

```kotlin
        // Only these two proxy modes exist. Anything else is a mode this
        // build does not understand, and is refused rather than allowed to
        // fall through to connect() — http reaches HttpConnectTunnel, socks5
        // is delegated to the platform.
        if (config.proxyMode != "socks5" && config.proxyMode != "http") {
            return Route.Refused(RouteFailure.MISCONFIGURED)
        }
```

The `return Route.Proxy(host, port, socks = config.proxyMode == "socks5")` line at the end of `resolve` already does the right thing for `http` — it yields `socks = false`, which Step 3 routed to the tunnel. Leave it exactly as it is.

- [ ] **Step 6: Re-admit `http` in the Dart resolver**

`lib/domain/models/route_decision.dart` carries a mirror of the same guard from `ca9552c`:

```dart
  if (site.proxyMode != ProxyMode.socks5) {
    return const RouteRefused(RouteFailure.misconfigured);
  }
```

Delete those three lines, and the comment block above them that begins `// Android removed HTTP-proxy support`. Unlike the Kotlin side there is no unknown-mode case to guard: `ProxyMode` is a closed Dart enum of exactly `direct`, `socks5` and `http`, `direct` is already handled by the line above, and both survivors are now supported. Removing the guard restores the function to what it was before `ca9552c`.

- [ ] **Step 7: Update the Dart test `ca9552c` added**

`test/domain/route_decision_test.dart` gained a test asserting that an http-proxied site resolves to `RouteRefused(RouteFailure.misconfigured)`. That assertion is now wrong. Invert it: an http-proxied site with a host and port must resolve to a `RouteProxy` carrying that host, that port, and `ProxyMode.http`. Keep every other test in the file unchanged.

- [ ] **Step 8: Run both suites**

```bash
cd android && ./gradlew :app:testDebugUnitTest --tests '*RouterTest*' && cd ..
flutter test test/domain/route_decision_test.dart
```

Expected: both PASS.

- [ ] **Step 9: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/Router.kt android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt lib/domain/models/route_decision.dart test/domain/route_decision_test.dart
git commit -m "fix: route http-proxied sites through a CONNECT tunnel"
```

---

### Task 3: Report a refused tunnel honestly

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt:46-53`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt:14-25`

**Interfaces:**
- Consumes: `ProxyTunnelException` from Task 1.
- Produces: no new symbols. Wires `RouteFailure.PROXY_REFUSED` to its first producer.

**Why this task exists:** Task 2 re-admits `http`, which means a real proxy can now refuse a real CONNECT — a failure that did not exist before, because nothing ever got that far. Without this task it lands in `else -> RouteFailure.UPSTREAM_TIMEOUT` and reads as "The destination did not respond", which is wrong (the destination was never contacted) and misleading (it reads as transient). Note that `ca9552c` already fixed the *old* misreporting by refusing up front; this task covers the *new* failure mode that Task 2 makes reachable. `PROXY_REFUSED` and its copy `'The proxy refused the destination'` already exist unused (see Background), so this is wiring, not new design.

- [ ] **Step 1: Map `ProxyTunnelException` in the interceptor**

In `android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt`, in `fetchThrough`'s `getOrElse` block, add one branch **above** the existing `else`:

```kotlin
        }.getOrElse { error ->
            refused(when (error) {
                is ProxyTunnelException -> RouteFailure.PROXY_REFUSED
                is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
                is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
                is java.net.ConnectException -> RouteFailure.PROXY_UNREACHABLE
                else -> RouteFailure.UPSTREAM_TIMEOUT
            })
        }
```

Order matters: `ProxyTunnelException` extends `IOException`, and so does `java.net.ConnectException`, but neither is a supertype of the other — still, put the most specific first so the intent survives future edits.

- [ ] **Step 2: Surface the reason on the download path**

In `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt`, the three `runCatching { … }.getOrElse { DownloadOutcome.Failed(null) }` calls discard why a download failed. Replace each `getOrElse` lambda so the reason survives:

```kotlin
        return when (decisionName) {
            "keepInContainer" -> runCatching { keepInContainer(route, config, pending, fileName) }
                .getOrElse { DownloadOutcome.Failed(failureFor(it)) }
            "saveToDevice" -> when (route) {
                is Route.Direct -> runCatching { saveViaDownloadManager(config, pending, fileName) }
                    .getOrElse { DownloadOutcome.Failed(failureFor(it)) }
                is Route.Proxy -> runCatching { saveViaMediaStore(route, pending, fileName) }
                    .getOrElse { DownloadOutcome.Failed(failureFor(it)) }
                is Route.Refused -> error("handled above")
            }
            else -> error("unsupported download decision")
        }
    }

    /** Mirrors [RequestInterceptor]'s mapping so a download names the same cause a page load would. */
    private fun failureFor(error: Throwable): RouteFailure? = when (error) {
        is ProxyTunnelException -> RouteFailure.PROXY_REFUSED
        is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
        is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
        is java.net.ConnectException -> RouteFailure.PROXY_UNREACHABLE
        else -> null
    }
```

`null` stays the fallback for genuinely unknown causes: `EngineChannel.kt:309` already handles a null reason, and the Dart side already renders a `DownloadResult` with no reason.

- [ ] **Step 3: Verify the whole engine still compiles and every suite passes**

Run all three, in this order, from the repository root:

```bash
cd android && ./gradlew :app:testDebugUnitTest && cd ..
flutter analyze
flutter test
flutter build apk --debug
```

Expected: Kotlin unit tests PASS; `No issues found!`; `All tests passed!` at 299 or more; `✓ Built build\app\outputs\flutter-apk\app-debug.apk` with zero `e:` lines.

**Do not skip the APK build.** `flutter analyze` and `flutter test` are Dart-only and compile none of this task's Kotlin. Tasks 1–6 of the download-manager plan were committed at `5a27dbf` having passed both while containing a Kotlin compile error, and that is the mistake this step exists to prevent.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt
git commit -m "fix: report a refused CONNECT as PROXY_REFUSED, not a timeout"
```

---

### Task 4: Record what shipped and what did not

**Files:**
- Modify: `docs/superpowers/plans/2026-09-08-download-manager-integration.md` (defect 5's entry)
- Modify: `CLAUDE.md` (the plan table and the defect list)

**Interfaces:**
- Consumes: nothing.
- Produces: nothing executable.

- [ ] **Step 1: Close defect 5 in the download-manager plan**

Edit defect 5's entry to say it is fixed, name the three commits from Tasks 1–3, and keep — do not delete — the original description of the breakage. The record should show what was wrong and how it was found, not just that it is gone. State plainly that the fix is verified by JVM unit tests against a fake proxy and by a clean APK build, and that **it has never run against a real HTTP proxy on a real device**.

- [ ] **Step 2: Add a row to the CLAUDE.md plan table**

Add this plan as a row, following the format of the existing rows, marked **Done** with the date it was executed and a one-line summary naming `HttpConnectTunnel.kt`.

- [ ] **Step 3: Record the known gaps**

Add, verbatim, to whichever gaps section the executing session judges correct:

- **No proxy authentication.** A proxy answering `407 Proxy Authentication Required` is reported as `PROXY_REFUSED` and the request fails. There is no credential storage, no `Proxy-Authorization` header, and no UI for either. Authenticated HTTP proxies do not work.
- **No CONNECT for SOCKS.** Unchanged and correct — SOCKS is still delegated to the platform, which supports it.
- **Untested against a real proxy.** Every test in Tasks 1 and 2 talks to a `ServerSocket` on localhost that replies with a canned status line. Real proxies vary in header handling, keep-alive behaviour and error bodies. This shares the limitation of the whole engine: **Task 7 Step 4 of the download-manager plan is recorded UNREACHABLE because no Android device is available here.**
- **`ProxyProbe` still probes the proxy, not the tunnel.** `ProxyProbe.reachable` opens a plain socket to `host:port`, so a proxy that is up but refuses CONNECT to a given destination still reports reachable, and the site reads as correctly configured until the request fails. Narrower than before this plan — the failure is now named correctly rather than reported as a timeout — but the ordering is unchanged.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-09-08-download-manager-integration.md CLAUDE.md
git commit -m "docs: close defect 5 and record the CONNECT tunnel's gaps"
```

---

## Handoff

**Produces for later work:**
- `HttpConnectTunnel.open(proxyHost, proxyPort, targetHost, targetPort): Socket` — the one place a CONNECT is issued. Proxy authentication, if it is ever added, belongs here and nowhere else.
- `ProxyTunnelException(statusCode, message)` — carries the proxy's status code, so a future task can distinguish 407 (needs credentials) from 403 (destination refused) without re-parsing anything.
- `RouteFailure.PROXY_REFUSED` gains its first producer, completing a path that ran unused from the Kotlin enum through `routeFailureToDartName` to user-facing copy.

**Does not produce:**
- Any change to `ProxyHttpClient`. Its `startTls` already wraps whatever `Router.connect` returns, so TLS-over-CONNECT works without touching it — but note that TLS itself is still unverified against a live server (see the download-manager plan's Task 7).
- Any UI. The HTTP chip in the network tab is left exactly as it is, now backed by something that works.

## Known gaps this plan accepts

- **No proxy authentication**, as above. This is the largest gap and the most likely next request.
- **No `Proxy-Connection`/keep-alive handling.** Each fetch opens its own tunnel, matching `ProxyHttpClient`'s existing `Connection: close`.
- **The 15-second connect timeout is hardcoded**, matching the existing constant in `ProxyHttpClient` and `Router`. Not made configurable.
- **No IPv6-literal bracket handling in the CONNECT authority.** `"$targetHost:$targetPort"` is wrong for a bare IPv6 literal, which needs `[::1]:443`. Not fixed because no path in this app ever produces one: hosts arrive from `WebResourceRequest.url.host` and `java.net.URL.getHost`, both of which already bracket IPv6 literals. Worth knowing if that ever changes.

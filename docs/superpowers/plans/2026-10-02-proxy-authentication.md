# Proxy Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a site's upstream proxy (SOCKS5 or HTTP) be given a login — typed per site, or derived automatically per site for Tor circuit isolation — and report a rejected login as its own failure.

**Architecture:** Kotlin decides which login a `Route.Proxy` carries (`Router.resolve`), and two hand-written tunnels send it: a new `Socks5Tunnel` (RFC 1928/1929) replaces the platform's SOCKS for every SOCKS route, and `HttpConnectTunnel` gains `Proxy-Authorization`. A rejected login is `ProxyLoginRejectedException`, reported route-wide by the loopback proxy, refusing a session that is still opening. Dart stores the three new `Site` fields (schema 7), sends them over the channel, inherits them into throwaways and the decoy, and edits them on `2a`'s Network tab.

**Tech Stack:** Kotlin (JVM unit tests, JUnit 4), Flutter/Dart 3, `sqflite_sqlcipher` (+ `sqflite_common_ffi` in tests), Riverpod.

**Spec:** `docs/superpowers/specs/2026-10-02-proxy-authentication-design.md`. Read it before any task; its "Rulings" list is binding.

## Global Constraints

- **Copy is verbatim.** The only new strings are `Separate login per site`, `Tor gives this site its own circuit`, `USERNAME`, `PASSWORD`, `The proxy rejected the login`. Nothing else user-visible is added or reworded.
- **The interceptor never falls back to direct.** No change here may turn a refused or failed proxied connection into a direct one.
- **No network requests of the app's own.** The login is checked only when the site's own traffic goes through the proxy; `ProxyProbe` stays a TCP check (ruling 11).
- **Credentials never leak.** `ProxyLogin.toString()` is redacted; no exception message names a user or password; nothing new logs a host. Never call `android.util.Log` in engine code.
- **Two-vault model.** No code asks which vault is open.
- **Hairline/jade rules:** the new toggle uses the Network tab's existing `_switch` (as every toggle on that tab does); add no other jade.
- **Kotlin is only compiled by Gradle.** `flutter analyze`/`flutter test` never compile `engine/`. Kotlin tests: from `android/`, `./gradlew :app:testDebugUnitTest` (run `flutter build apk --debug` once first in a fresh worktree; Flutter and Gradle commands need the Bash sandbox disabled). Read counts from `build/app/test-results/testDebugUnitTest/TEST-*.xml`, never from `BUILD SUCCESSFUL`.
- **Work in the `proxy-auth` worktree** (`C:\Users\Metin\Desktop\flutter-app-proxy-auth`, branch `proxy-auth`), never the main checkout: other sessions switch that one's branch and leave scratch edits in it.
- **Fresh worktree:** copy the main checkout's `.dart_tool/hooks_runner` in before `flutter test` (this machine cannot reach GitHub).

## Review Focus

1. **A login whose UTF-8 form is over 255 bytes but under 255 characters** (e.g. `é` × 128) — must be refused as a rejected login before any byte goes to the SOCKS5 proxy, not truncated or sent with a wrapped length byte. Pinned in Task 2.
2. **A SOCKS5 proxy that closes mid-handshake, or answers with a version other than 5** — must fail promptly with an `IOException` (502, unreported), never hang a loopback worker or be read as a rejected login. Pinned in Task 2.
3. **A failure reply from a SOCKS5 proxy that sends no bound address after it** — must surface as `ProxyTunnelException(code)` without waiting for bytes that never come. Pinned in Task 2 (reply read before the address).
4. **A rejected login reported after the session has moved on** — a report arriving for a session that is live, backgrounded, refused or replaced must not refuse it; a live one gets `tunnel_dropped` as today. Pinned in Task 4.
5. **Switching per-site login on after typing a username, or turning the proxy off** — the saved site must hold no typed username or password (ruling 8), so a password does not linger in the vault unseen. Pinned in Task 7.

---

## File map

| File | Change |
|---|---|
| `android/.../engine/ProxyLogin.kt` | **Create.** `ProxyLogin`, `ProxyLoginRejectedException`, `perSiteLogin`, `proxyLoginFrom`, `loginFor`. |
| `android/.../engine/Socks5Tunnel.kt` | **Create.** RFC 1928/1929 client. |
| `android/.../engine/Router.kt` | `RouteFailure.PROXY_LOGIN_REJECTED`; `Route.Proxy.login`; `resolve` attaches it; `connect` uses both tunnels with it. |
| `android/.../engine/SiteConfig.kt` | `proxyLogin`, `proxyLoginPerSite`. |
| `android/.../engine/HttpConnectTunnel.kt` | Optional login; `407` → rejected login. |
| `android/.../engine/LoopbackRequest.kt` | `reportedUpstreamFailure`. |
| `android/.../engine/LoopbackProxy.kt` | Reports a rejected login through the binding. |
| `android/.../engine/EngineChannel.kt` | Reads the three keys; `RefusalAction`/`refusalActionFor`; refusing an opening session; Dart name. |
| `android/.../engine/DownloadFetcher.kt` | `failureFor` → top-level `downloadFailureFor`, mapping the new exception. |
| `lib/domain/models/site.dart` | `proxyUser`, `proxyPassword`, `proxyLoginPerSite`. |
| `lib/data/services/app_database.dart` | Schema 7, row mapping. |
| `lib/data/services/container_engine_channel.dart` | Sends the three keys; decodes `proxyLoginRejected`. |
| `lib/domain/models/route_decision.dart` | `RouteFailure.proxyLoginRejected` and its copy. |
| `lib/domain/models/destination.dart`, `throwaway.dart` | Throwaways inherit the login. |
| `lib/ui/features/add_site/...` | Network tab login block; `buildSite` ruling 8. |
| `tool/device-check/proxy.py`, `README.md` | Optional login requirement; run sheet. |
| `CLAUDE.md` | Plan 14 row. |

`android/...` is `android/app/src/main/kotlin/com/mono/container`; tests are under `android/app/src/test/kotlin/com/mono/container/engine/`.

---

### Task 1: The login type, the new failure, and which login a route carries

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/ProxyLogin.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Router.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/SiteConfig.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt` (`routeFailureToDartName`, `configFrom`)
- Create: `android/app/src/test/kotlin/com/mono/container/engine/ProxyLoginTest.kt`
- Modify: `android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt`, `RouteFailureNameTest.kt`

**Interfaces:**
- Produces: `data class ProxyLogin(val user: String, val password: String)` (redacted `toString`); `class ProxyLoginRejectedException(message: String) : IOException`; `fun perSiteLogin(profileId: String): ProxyLogin`; `fun proxyLoginFrom(user: String?, password: String?): ProxyLogin?`; `fun loginFor(config: SiteConfig): ProxyLogin?`; `RouteFailure.PROXY_LOGIN_REJECTED` (Dart name `proxyLoginRejected`); `Route.Proxy(host, port, socks, login: ProxyLogin? = null)`; `SiteConfig.proxyLogin: ProxyLogin? = null`, `SiteConfig.proxyLoginPerSite: Boolean = false`; channel keys `proxyUser`, `proxyPassword`, `proxyLoginPerSite`.

- [ ] **Step 1: Write the failing tests**

`ProxyLoginTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ProxyLoginTest {

    private fun config(perSite: Boolean = false, login: ProxyLogin? = null, profileId: String = "a".repeat(32)) = SiteConfig(
        siteId = "s", profileId = profileId, url = "https://forum.example.com",
        proxyMode = "socks5", proxyHost = "127.0.0.1", proxyPort = 9050,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
        proxyLogin = login, proxyLoginPerSite = perSite,
    )

    /** Spec §2.3, pinned to a vector computed outside the app (Python hashlib). */
    @Test fun `the per-site login is the SHA-256 of the profile id, split in two`() {
        assertEquals(
            ProxyLogin("227a50371d9f5a0c087f526719d0233a", "d7185dbae8318e755468638506428456"),
            perSiteLogin("a".repeat(32)),
        )
    }

    @Test fun `the per-site login is stable for a profile and differs across profiles`() {
        assertEquals(perSiteLogin("p1"), perSiteLogin("p1"))
        assertNotEquals(perSiteLogin("p1"), perSiteLogin("p2"))
    }

    @Test fun `the per-site login does not contain the profile id`() {
        val profileId = "0123456789abcdef0123456789abcdef"
        val login = perSiteLogin(profileId)
        assertFalse(profileId in login.user)
        assertFalse(profileId in login.password)
    }

    @Test fun `a login prints neither half`() {
        val login = ProxyLogin("alice", "s3cret")
        assertEquals("ProxyLogin(redacted)", login.toString())
        val printed = config(login = login).toString()
        assertFalse("alice" in printed)
        assertFalse("s3cret" in printed)
    }

    @Test fun `a typed login needs a non-empty user, and a missing password is empty`() {
        assertNull(proxyLoginFrom(null, "pw"))
        assertNull(proxyLoginFrom("", "pw"))
        assertEquals(ProxyLogin("alice", ""), proxyLoginFrom("alice", null))
        assertEquals(ProxyLogin("alice", " pw "), proxyLoginFrom("alice", " pw "))
    }

    /** Spec §2.1: per-site wins over a typed login; otherwise the typed one; otherwise none. */
    @Test fun `which login a site uses`() {
        val typed = ProxyLogin("alice", "s3cret")
        assertEquals(perSiteLogin("a".repeat(32)), loginFor(config(perSite = true, login = typed)))
        assertEquals(typed, loginFor(config(login = typed)))
        assertNull(loginFor(config()))
    }
}
```

Append to `RouterTest.kt` (inside the class; its `config` helper builds a SiteConfig without the new fields, so these tests use `.copy`):

```kotlin
    @Test fun `a proxied route carries the site's login`() {
        val typed = ProxyLogin("alice", "s3cret")
        for (mode in listOf("socks5", "http")) {
            val route = Router.resolve(config(mode = mode).copy(proxyLogin = typed), proxyReachable = true) as Route.Proxy
            assertEquals(typed, route.login)
        }
    }

    /** Ruling 7: the automatic login applies to HTTP proxies as well as SOCKS5. */
    @Test fun `a per-site route carries the login derived from its profile`() {
        for (mode in listOf("socks5", "http")) {
            val route = Router.resolve(config(mode = mode).copy(proxyLoginPerSite = true), proxyReachable = true) as Route.Proxy
            assertEquals(perSiteLogin("a".repeat(32)), route.login)
        }
    }

    @Test fun `a proxied route with no login carries none`() {
        assertNull((Router.resolve(config(), proxyReachable = true) as Route.Proxy).login)
    }

    /** Spec §2.1: a direct route never carries a login. */
    @Test fun `a direct site with a login still routes direct`() {
        val config = config(mode = "direct").copy(proxyLogin = ProxyLogin("alice", "s3cret"), proxyLoginPerSite = true)
        assertEquals(Route.Direct, Router.resolve(config, proxyReachable = true))
    }
```

In `RouteFailureNameTest.kt`, add `"PROXY_LOGIN_REJECTED" to "proxyLoginRejected",` to the expected map, after `"UNSUPPORTED" to "unsupported",`.

- [ ] **Step 2: Run them to see them fail**

Run, from `android/`: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.ProxyLoginTest" --tests "com.mono.container.engine.RouterTest" --tests "com.mono.container.engine.RouteFailureNameTest"`
Expected: compilation fails — `ProxyLogin`, `perSiteLogin`, `proxyLogin` unresolved.

- [ ] **Step 3: Write `ProxyLogin.kt`**

```kotlin
package com.mono.container.engine

import java.io.IOException
import java.security.MessageDigest

/**
 * A login for a site's own upstream proxy (proxy-auth spec §2). Not the
 * loopback proxy's [ProxyCredential]: that one only ever answers our own
 * `407`. [toString] prints neither half, so a logged [SiteConfig] or [Route]
 * names no password (spec §2.5).
 */
data class ProxyLogin(val user: String, val password: String) {
    override fun toString() = "ProxyLogin(redacted)"
}

/**
 * The upstream proxy turned this site's login down, or wanted one it does not
 * have (spec §3). Its message names no credential and no host.
 */
class ProxyLoginRejectedException(message: String) : IOException(message)

/**
 * Spec §2.3: the automatic per-site login. SHA-256 of
 * `"container-proxy-login:" + profileId` (UTF-8); the user is the first 16
 * bytes and the password the last 16, each as 32 lowercase hex digits. Tor
 * gives each distinct login its own circuit, and a wipe rotates the profile
 * id, so a wiped site gets a fresh login and a fresh circuit. Nothing about
 * the profile id can be read back from it.
 */
fun perSiteLogin(profileId: String): ProxyLogin {
    val digest = MessageDigest.getInstance("SHA-256")
        .digest("container-proxy-login:$profileId".toByteArray(Charsets.UTF_8))
    fun hex(bytes: ByteArray) = bytes.joinToString("") { "%02x".format(it) }
    return ProxyLogin(hex(digest.copyOfRange(0, 16)), hex(digest.copyOfRange(16, 32)))
}

/** The typed login the channel sent: none without a user; a missing password is empty. */
fun proxyLoginFrom(user: String?, password: String?): ProxyLogin? =
    if (user.isNullOrEmpty()) null else ProxyLogin(user, password ?: "")

/** Spec §2.1: the per-site login when the site asks for one, whatever is typed; else the typed one. */
fun loginFor(config: SiteConfig): ProxyLogin? =
    if (config.proxyLoginPerSite) perSiteLogin(config.profileId) else config.proxyLogin
```

- [ ] **Step 4: Add the fields, the failure and the route's login**

In `SiteConfig.kt`, after `val userScripts: List<InjectedScript> = emptyList(),` add:

```kotlin
    /** The login typed for this site's proxy, or null. Redacted when printed. */
    val proxyLogin: ProxyLogin? = null,
    /** Use [perSiteLogin] instead of [proxyLogin] (spec §2.1). */
    val proxyLoginPerSite: Boolean = false,
```

In `Router.kt`, extend the enum and the route:

```kotlin
enum class RouteFailure {
    PROXY_UNREACHABLE, PROXY_REFUSED, UPSTREAM_TIMEOUT, TLS_FAILURE, MISCONFIGURED,
    /** This WebView cannot override its proxy, so a proxied site cannot be routed (P2 spec §3.3). */
    UNSUPPORTED,
    /** The site's proxy turned its login down, or wanted one it does not have (proxy-auth spec §3). */
    PROXY_LOGIN_REJECTED,
}

sealed class Route {
    object Direct : Route()
    /** [login] is what the tunnel offers the proxy, or null for none (proxy-auth spec §2.1). */
    data class Proxy(val host: String, val port: Int, val socks: Boolean, val login: ProxyLogin? = null) : Route()
    data class Refused(val failure: RouteFailure) : Route()
}
```

and the last line of `resolve`:

```kotlin
        return Route.Proxy(host, port, socks = config.proxyMode == "socks5", login = loginFor(config))
```

In `EngineChannel.kt`, `routeFailureToDartName` gains `"PROXY_LOGIN_REJECTED" -> "proxyLoginRejected"` before `else`, and `configFrom` gains, after `userScripts = ...`:

```kotlin
        proxyLogin = proxyLoginFrom(call.argument<String>("proxyUser"), call.argument<String>("proxyPassword")),
        proxyLoginPerSite = call.argument<Boolean>("proxyLoginPerSite") ?: false,
```

- [ ] **Step 5: Run the tests**

Run the Step 2 command. Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/{ProxyLogin,Router,SiteConfig,EngineChannel}.kt android/app/src/test/kotlin/com/mono/container/engine/{ProxyLoginTest,RouterTest,RouteFailureNameTest}.kt
git commit -m "feat(engine): choose a proxy login per route"
```

---

### Task 2: `Socks5Tunnel`, for every SOCKS route

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/Socks5Tunnel.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Router.kt` (`connect`'s SOCKS branch and doc comment)
- Create: `android/app/src/test/kotlin/com/mono/container/engine/Socks5TunnelTest.kt`

**Interfaces:**
- Consumes: `ProxyLogin`, `ProxyLoginRejectedException` (Task 1); `ProxyTunnelException(statusCode, message)` (existing, `HttpConnectTunnel.kt`).
- Produces: `object Socks5Tunnel { fun open(proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int, login: ProxyLogin? = null): java.net.Socket }`.

- [ ] **Step 1: Write the failing tests**

```kotlin
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
                        out.write(byteArrayOf(5, 0, 0) + bound + byteArrayOf(0x1F, 0x90)); out.flush()
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

    @Test fun `the router sends a SOCKS route's login`() {
        FakeSocks5(method = 2).use { proxy ->
            Router.connect(Route.Proxy("127.0.0.1", proxy.port, socks = true, login = ProxyLogin("alice", "s3cret")), "example.com", 443).close()
            assertArrayEquals(byteArrayOf(5, 1, 2), proxy.poll(proxy.greetings))
        }
    }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.Socks5TunnelTest"`
Expected: compilation fails — `Socks5Tunnel` unresolved.

- [ ] **Step 3: Write `Socks5Tunnel.kt`**

```kotlin
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
```

- [ ] **Step 4: Route SOCKS through it**

In `Router.connect`, replace the `is Route.Proxy ->` branch with:

```kotlin
            is Route.Proxy ->
                if (route.socks) Socks5Tunnel.open(route.host, route.port, targetHost, targetPort, route.login)
                else HttpConnectTunnel.open(route.host, route.port, targetHost, targetPort)
```

(Task 3 passes the login to `HttpConnectTunnel`.) In `connect`'s doc comment, replace the paragraph starting "SOCKS is delegated to the platform" and the one starting "The SOCKS target is deliberately unresolved" with:

```kotlin
     * SOCKS goes through [Socks5Tunnel], HTTP proxies through
     * [HttpConnectTunnel] (Android removed `Proxy.Type.HTTP` from
     * [java.net.Socket]). Both send [Route.Proxy.login] when there is one.
     *
     * Both name the target by hostname, so the proxy does the lookup. A
     * resolved address would make the device look the name up itself first,
     * telling its DNS resolver every host a proxied site visits. The cost is
     * that a SOCKS4-only proxy cannot be used, which the user accepted: the
     * mode is SOCKS5.
```

- [ ] **Step 5: Run the SOCKS tests and the existing routing tests**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.Socks5TunnelTest" --tests "com.mono.container.engine.RouterTest" --tests "com.mono.container.engine.LoopbackProxyTest"`
Expected: all pass. `RouterTest`'s "a socks5 route sends the target hostname to the proxy unresolved" and `LoopbackProxyTest`'s `FakeSocks` now talk to `Socks5Tunnel`; both accept a one-method greeting.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/{Socks5Tunnel,Router}.kt android/app/src/test/kotlin/com/mono/container/engine/Socks5TunnelTest.kt
git commit -m "feat(engine): hand-written SOCKS5 client with RFC 1929 login"
```

---

### Task 3: A login on HTTP CONNECT, and `407` as a rejected login

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/HttpConnectTunnel.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Router.kt` (pass the login)
- Modify: `android/app/src/test/kotlin/com/mono/container/engine/HttpConnectTunnelTest.kt`

**Interfaces:**
- Consumes: `ProxyLogin`, `ProxyLoginRejectedException` (Task 1).
- Produces: `HttpConnectTunnel.open(proxyHost, proxyPort, targetHost, targetPort, login: ProxyLogin? = null)`.

- [ ] **Step 1: Write the failing tests**

In `HttpConnectTunnelTest.kt`, make `FakeProxy` keep the whole head. Replace its `requestLines` field and the reading lines in `init`:

```kotlin
        val heads = ArrayBlockingQueue<List<String>>(1)
```

```kotlin
                    server.accept().use { client ->
                        val input = client.getInputStream()
                        heads.offer(readHead(input)!!)
```

(delete the old `requestLine`/drain lines and the `readLine` helper; `readHead` is the engine's own, in `LoopbackRequest.kt`). In the three existing tests that read `proxy.requestLines.take()`, read `proxy.heads.take().first()` instead. Change the existing test "throws ProxyTunnelException when the proxy refuses" to reply `HTTP/1.1 403 Forbidden\r\n\r\n` and assert `403`. Then add:

```kotlin
    @Test fun `with a login it sends Proxy-Authorization Basic`() {
        for ((login, encoded) in listOf(ProxyLogin("user", "pass") to "dXNlcjpwYXNz", ProxyLogin("ünï", "p:w") to "w7xuw686cDp3")) {
            FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
                HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443, login).close()
                assertTrue("Proxy-Authorization: Basic $encoded" in proxy.heads.take())
            }
        }
    }

    @Test fun `without a login it sends no Proxy-Authorization`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
            HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443).close()
            assertTrue(proxy.heads.take().none { it.startsWith("Proxy-Authorization", ignoreCase = true) })
        }
    }

    /** Ruling 4: any 407 is a rejected login, whether one was sent or not. */
    @Test fun `a 407 is a rejected login, with or without one`() {
        for (login in listOf(null, ProxyLogin("alice", "s3cret"))) {
            FakeProxy("HTTP/1.1 407 Proxy Authentication Required\r\n\r\n", echo = false).use { proxy ->
                try {
                    HttpConnectTunnel.open("127.0.0.1", proxy.server.localPort, "example.com", 443, login)
                    fail("expected ProxyLoginRejectedException")
                } catch (error: ProxyLoginRejectedException) {
                    assertFalse("s3cret" in error.message.orEmpty())
                    assertFalse("example.com" in error.message.orEmpty())
                }
            }
        }
    }

    @Test fun `the router sends an http route's login`() {
        FakeProxy("HTTP/1.1 200 Connection established\r\n\r\n", echo = false).use { proxy ->
            Router.connect(Route.Proxy("127.0.0.1", proxy.server.localPort, socks = false, login = ProxyLogin("user", "pass")), "example.com", 443).close()
            assertTrue("Proxy-Authorization: Basic dXNlcjpwYXNz" in proxy.heads.take())
        }
    }
```

Add `import org.junit.Assert.assertFalse` to the file's imports.

- [ ] **Step 2: Run them to see them fail**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.HttpConnectTunnelTest"`
Expected: compilation fails — `open` takes no login.

- [ ] **Step 3: Implement**

In `HttpConnectTunnel.kt`, add `import java.util.Base64`, change the signature to

```kotlin
    fun open(proxyHost: String, proxyPort: Int, targetHost: String, targetPort: Int, login: ProxyLogin? = null): Socket {
```

write the header after the `Host:` line:

```kotlin
            if (login != null) {
                val basic = Base64.getEncoder().encodeToString("${login.user}:${login.password}".toByteArray(Charsets.UTF_8))
                out.write("Proxy-Authorization: Basic $basic\r\n".toByteArray(Charsets.US_ASCII))
            }
```

and check `407` before the general refusal:

```kotlin
            val status = readStatus(socket.getInputStream())
            // Ruling 4: a 407 is a rejected login, whether or not one was sent.
            if (status == 407) throw ProxyLoginRejectedException("the HTTP proxy rejected the login")
            if (status !in 200..299) {
```

Update `ProxyTunnelException`'s doc comment: drop "a 407 wanting credentials," (that is now `ProxyLoginRejectedException`). Update the class doc of `HttpConnectTunnel` with one sentence: "With a [ProxyLogin] it sends `Proxy-Authorization: Basic` (UTF-8); a colon in the user is not refused (ruling 10)."

In `Router.connect`, the HTTP branch becomes `else HttpConnectTunnel.open(route.host, route.port, targetHost, targetPort, route.login)`. The `Route.Direct` system-proxy call stays without a login.

- [ ] **Step 4: Run the tests**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.HttpConnectTunnelTest" --tests "com.mono.container.engine.RouterTest"`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/{HttpConnectTunnel,Router}.kt android/app/src/test/kotlin/com/mono/container/engine/HttpConnectTunnelTest.kt
git commit -m "feat(engine): send a login on HTTP CONNECT; 407 is a rejected login"
```

---

### Task 4: Report a rejected login — loopback proxy, opening sessions, downloads

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/LoopbackRequest.kt`, `LoopbackProxy.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt`
- Modify: `android/app/src/test/kotlin/com/mono/container/engine/LoopbackProxyTest.kt`
- Create: `android/app/src/test/kotlin/com/mono/container/engine/RouteRefusalTest.kt`, `DownloadFailureTest.kt`

**Interfaces:**
- Consumes: `ProxyLoginRejectedException`, `RouteFailure.PROXY_LOGIN_REJECTED` (Task 1).
- Produces: `internal fun reportedUpstreamFailure(error: Throwable, route: Route): RouteFailure?`; `internal enum class RefusalAction { REFUSE_SESSION, TUNNEL_DROPPED, IGNORE }`; `internal fun refusalActionFor(phase: String): RefusalAction`; `internal fun downloadFailureFor(error: Throwable, route: Route): RouteFailure?`.

- [ ] **Step 1: Write the failing tests**

`RouteRefusalTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** Proxy-auth spec §3, ruling 6: what a route refusal does, by the phase of the session it reached. */
class RouteRefusalTest {
    @Test fun `an opening session is refused, a live one hears tunnel_dropped, any other ignores it`() {
        assertEquals(RefusalAction.REFUSE_SESSION, refusalActionFor(Session.PHASE_OPENING))
        assertEquals(RefusalAction.TUNNEL_DROPPED, refusalActionFor(Session.PHASE_LIVE))
        assertEquals(RefusalAction.IGNORE, refusalActionFor(Session.PHASE_BACKGROUND))
        assertEquals(RefusalAction.IGNORE, refusalActionFor(Session.PHASE_REFUSED))
    }

    /** Spec §3: route-wide for a proxied route only; every other upstream failure stays unreported (P2 plan deviation 1). */
    @Test fun `only a rejected login on a proxied route is reported`() {
        val proxied = Route.Proxy("127.0.0.1", 9050, socks = true)
        assertEquals(RouteFailure.PROXY_LOGIN_REJECTED, reportedUpstreamFailure(ProxyLoginRejectedException("x"), proxied))
        assertEquals(null, reportedUpstreamFailure(ProxyLoginRejectedException("x"), Route.Direct))
        assertEquals(null, reportedUpstreamFailure(ProxyTunnelException(5, "x"), proxied))
        assertEquals(null, reportedUpstreamFailure(java.net.SocketTimeoutException("x"), proxied))
    }
}
```

`DownloadFailureTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DownloadFailureTest {
    private val proxied = Route.Proxy("127.0.0.1", 9050, socks = true)

    @Test fun `a rejected login names itself`() {
        assertEquals(RouteFailure.PROXY_LOGIN_REJECTED, downloadFailureFor(ProxyLoginRejectedException("x"), proxied))
    }

    @Test fun `the existing mapping is unchanged`() {
        assertEquals(RouteFailure.PROXY_REFUSED, downloadFailureFor(ProxyTunnelException(403, "x"), proxied))
        assertEquals(RouteFailure.UPSTREAM_TIMEOUT, downloadFailureFor(java.net.SocketTimeoutException("x"), proxied))
        assertEquals(RouteFailure.TLS_FAILURE, downloadFailureFor(javax.net.ssl.SSLException("x"), proxied))
        assertEquals(RouteFailure.PROXY_UNREACHABLE, downloadFailureFor(java.net.ConnectException("x"), proxied))
        assertEquals(RouteFailure.UPSTREAM_TIMEOUT, downloadFailureFor(java.net.ConnectException("x"), Route.Direct))
        assertNull(downloadFailureFor(IllegalStateException("x"), proxied))
    }
}
```

In `LoopbackProxyTest.kt`, after "an upstream that refuses the destination answers 502 and reports nothing", add:

```kotlin
    /** Proxy-auth spec §3: a rejected login is the route's fault, so it is reported like a refused route. */
    @Test fun `a rejected login answers 502 and tells the site`() {
        val reported = CopyOnWriteArrayList<RouteFailure>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1", mode = "socks5", host = "127.0.0.1", port = 1)) { reported += it })
        LoopbackProxy(credentials, bySettings, connect = { _, _, _ -> throw ProxyLoginRejectedException("rejected") }).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(502, statusOf(socket))
            }
        }
        assertEquals(listOf(RouteFailure.PROXY_LOGIN_REJECTED), reported)
    }

    /** A direct site behind a Wi-Fi proxy that wants a login: answered, never reported (spec §3, "only for a Route.Proxy"). */
    @Test fun `a rejected login on a direct route is not reported`() {
        val reported = CopyOnWriteArrayList<RouteFailure>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) { reported += it })
        LoopbackProxy(credentials, bySettings, connect = { _, _, _ -> throw ProxyLoginRejectedException("rejected") }).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(502, statusOf(socket))
            }
        }
        assertTrue(reported.isEmpty())
    }
```

- [ ] **Step 2: Run them to see them fail**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.RouteRefusalTest" --tests "com.mono.container.engine.DownloadFailureTest" --tests "com.mono.container.engine.LoopbackProxyTest"`
Expected: compilation fails — `refusalActionFor`, `reportedUpstreamFailure`, `downloadFailureFor` unresolved.

- [ ] **Step 3: The loopback proxy reports it**

In `LoopbackRequest.kt`, after `upstreamFailureStatus`:

```kotlin
/**
 * The failure a failed upstream connection reports to its site, or null.
 * Only a rejected login on a proxied route: it is the route's fault, not one
 * destination's, so every request on it would fail the same way (proxy-auth
 * spec §3). Every other failure stays unreported (plan deviation 1).
 */
internal fun reportedUpstreamFailure(error: Throwable, route: Route): RouteFailure? =
    if (error is ProxyLoginRejectedException && route is Route.Proxy) RouteFailure.PROXY_LOGIN_REJECTED else null
```

In `LoopbackProxy.upstream`, the catch becomes:

```kotlin
        } catch (error: Exception) {
            reportedUpstreamFailure(error, route)?.let { if (!binding.isRevoked) binding.onRefused(it) }
            val status = upstreamFailureStatus(error)
            note("$label -> $status upstream failed (${error.javaClass.simpleName})")
            output.write(statusResponse(status))
            null
        }
```

and the function's doc comment's last sentence becomes: "A failed connection is answered and, unless it is a rejected login on a proxied route ([reportedUpstreamFailure]), reported to no one (plan deviation 1)."

- [ ] **Step 4: A refusal while opening refuses the session**

In `EngineChannel.kt`, after `class PendingOpens { ... }`:

```kotlin
/** What a route refusal reported by the loopback proxy does to the session it reached. */
internal enum class RefusalAction { REFUSE_SESSION, TUNNEL_DROPPED, IGNORE }

/**
 * Proxy-auth spec §3, ruling 6. A session still opening is refused, so `8b`
 * names the failure instead of the first load ending on WebView's own error
 * page. A live one hears `tunnel_dropped` (`8c`), as before. A backgrounded or
 * refused one ignores it, as before.
 */
internal fun refusalActionFor(phase: String): RefusalAction = when (phase) {
    Session.PHASE_OPENING -> RefusalAction.REFUSE_SESSION
    Session.PHASE_LIVE -> RefusalAction.TUNNEL_DROPPED
    else -> RefusalAction.IGNORE
}
```

In `register`, the binding's callback reports to the session it was made for:

```kotlin
                credentials.bind(config.profileId, ProxyBinding(config) { failure ->
                    mainHandler.post { onRouteRefused(session, failure) }
                })
```

and add, beside `onTunnelDropped`:

```kotlin
    /**
     * Called on the main thread for a refusal the loopback proxy reported on
     * [session]'s binding. A session replaced since, or closed, hears nothing.
     * Refusing an opening session also unbinds it, as a route refused at open
     * never binds: from then on the proxy answers its requests `403`.
     */
    private fun onRouteRefused(session: Session, failure: RouteFailure) {
        val siteId = session.config.siteId
        if (sessions[siteId] !== session) return
        when (refusalActionFor(session.phase)) {
            RefusalAction.REFUSE_SESSION -> {
                session.phase = Session.PHASE_REFUSED
                session.failure = routeFailureToDartName(failure.name)
                credentials.unbind(session.config.profileId)
                emitSessions()
            }
            RefusalAction.TUNNEL_DROPPED -> onTunnelDropped(siteId, failure)
            RefusalAction.IGNORE -> Unit
        }
    }
```

`Session.onTunnelDropped` (the interceptor's main-frame TLS report) keeps calling `onTunnelDropped` directly: it is not a route refusal, and refusing a direct site's opening session on it would show `8b` naming a tunnel the site does not have. `markLive` already returns early for a refused session, so a first load finishing after the refusal does not revive it; `ContainerRoute` already moves to `8b` whenever its session turns `refused`.

- [ ] **Step 5: Downloads name it**

In `DownloadFetcher.kt`, delete the private `failureFor` and its doc comment from the class, replace its three call sites with `downloadFailureFor(it, route)`, and add at file level (after `writeDownload`):

```kotlin
/**
 * The failure a download's outcome line names. Mirrors the mapping the
 * interceptor used for proxied page loads before P2 (Plan 13), so a download
 * names the same cause a page load did.
 *
 * [route] is why this is not a verbatim copy of that mapping. The
 * interceptor's fetch only ever ran for a [Route.Proxy], so it could read a
 * [java.net.ConnectException] as "the proxy is down". This function also runs
 * for [Route.Direct], where there is no proxy to be unreachable and the same
 * exception means the destination refused the connection — reporting
 * PROXY_UNREACHABLE there would show "Cannot reach the proxy" for a site that
 * has no proxy configured.
 *
 * A rejected login is named on any route: on a direct one it can only come
 * from the network's own proxy, which really did reject it.
 */
internal fun downloadFailureFor(error: Throwable, route: Route): RouteFailure? = when (error) {
    is ProxyLoginRejectedException -> RouteFailure.PROXY_LOGIN_REJECTED
    is ProxyTunnelException -> RouteFailure.PROXY_REFUSED
    is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
    is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
    is java.net.ConnectException ->
        if (route is Route.Proxy) RouteFailure.PROXY_UNREACHABLE
        else RouteFailure.UPSTREAM_TIMEOUT
    else -> null
}
```

- [ ] **Step 6: Run the tests, then every Kotlin test and the APK build**

Run the Step 2 command; expected: all pass. Then `./gradlew :app:testDebugUnitTest` and, from the repo root, `flutter build apk --debug`. Expected: no failures in the JUnit XML (`grep -h 'failures="[1-9]\|errors="[1-9]' build/app/test-results/testDebugUnitTest/TEST-*.xml` prints nothing) and zero `e:` lines in the build.

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/{LoopbackRequest,LoopbackProxy,EngineChannel,DownloadFetcher}.kt android/app/src/test/kotlin/com/mono/container/engine/{LoopbackProxyTest,RouteRefusalTest,DownloadFailureTest}.kt
git commit -m "feat(engine): report a rejected proxy login, refusing an opening session"
```

---

### Task 5: Dart — the three fields, schema 7, the channel, the failure

**Files:**
- Modify: `lib/domain/models/site.dart`
- Modify: `lib/data/services/app_database.dart`
- Modify: `lib/data/services/container_engine_channel.dart`
- Modify: `lib/domain/models/route_decision.dart`
- Create: `test/data/proxy_login_storage_test.dart`
- Modify: `test/data/container_engine_channel_test.dart`, `test/domain/route_failure_copy_test.dart`

**Interfaces:**
- Consumes: channel keys and Dart failure name from Task 1.
- Produces: `Site.proxyUser` (`String?`), `Site.proxyPassword` (`String?`), `Site.proxyLoginPerSite` (`bool`, default false), all three in the constructor and `copyWith`; `AppDatabase.schemaVersion == 7`; `RouteFailure.proxyLoginRejected`.

- [ ] **Step 1: Write the failing tests**

`test/data/proxy_login_storage_test.dart`:

```dart
import 'dart:io';

import 'package:container/data/repositories/site_repository_sqlite.dart';
import 'package:container/data/repositories/workspace_repository_sqlite.dart';
import 'package:container/data/services/app_database.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('a site keeps its typed login and per-site choice', () async {
    final database =
        await AppDatabase.open(path: inMemoryDatabasePath, factory: databaseFactoryFfi);
    await SqliteWorkspaceRepository(database).upsert(const Workspace(
        id: 'ws', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep));
    final sites = SqliteSiteRepository(database);
    await sites.upsert(const Site(
      id: 's1', workspaceId: 'ws', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      proxyUser: 'alice', proxyPassword: ' s3cret ',
    ));
    await sites.upsert(const Site(
      id: 's2', workspaceId: 'ws', name: 'Mail', monogram: 'Ml',
      url: 'https://mail.example.com', profileId: 'p2',
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      proxyLoginPerSite: true,
    ));

    final typed = (await sites.byId('s1'))!;
    expect(typed.proxyUser, 'alice');
    expect(typed.proxyPassword, ' s3cret ', reason: 'stored exactly as typed (ruling 8)');
    expect(typed.proxyLoginPerSite, isFalse);
    final perSite = (await sites.byId('s2'))!;
    expect(perSite.proxyUser, isNull);
    expect(perSite.proxyPassword, isNull);
    expect(perSite.proxyLoginPerSite, isTrue);
    await database.close();
  });

  test('a v6 vault upgrades its sites to no login', () async {
    final dir = await Directory.systemTemp.createTemp('v6-upgrade');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/store.db';

    final v6 = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(version: 6, onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE workspaces (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, marker_index INTEGER NOT NULL,
          storage_rule TEXT NOT NULL, require_pin INTEGER NOT NULL DEFAULT 0,
          show_in_decoy INTEGER NOT NULL DEFAULT 0, sort_index INTEGER NOT NULL DEFAULT 0)
      ''');
      await db.execute('''
        CREATE TABLE sites (
          id TEXT PRIMARY KEY, workspace_id TEXT NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
          name TEXT NOT NULL, monogram TEXT NOT NULL, url TEXT NOT NULL,
          cookie_policy TEXT NOT NULL, proxy_mode TEXT NOT NULL, proxy_host TEXT, proxy_port INTEGER,
          require_pin INTEGER NOT NULL DEFAULT 0, show_in_decoy INTEGER NOT NULL DEFAULT 0,
          last_visited_at INTEGER, sort_index INTEGER NOT NULL DEFAULT 0,
          profile_id TEXT NOT NULL, block_webrtc INTEGER NOT NULL DEFAULT 1,
          block_trackers INTEGER NOT NULL DEFAULT 1, anti_fingerprinting INTEGER NOT NULL DEFAULT 1,
          allow_camera INTEGER NOT NULL DEFAULT 0, allow_microphone INTEGER NOT NULL DEFAULT 0,
          allow_location INTEGER NOT NULL DEFAULT 0, allow_clipboard INTEGER NOT NULL DEFAULT 0,
          user_agent_mode TEXT NOT NULL DEFAULT 'android', force_dark INTEGER NOT NULL DEFAULT 1,
          open_in_reader INTEGER NOT NULL DEFAULT 0, page_zoom INTEGER NOT NULL DEFAULT 100,
          custom_css TEXT NOT NULL DEFAULT '', custom_js TEXT NOT NULL DEFAULT '')
      ''');
    }));
    await v6.insert('workspaces',
        {'id': 'ws', 'name': 'Personal', 'marker_index': 0, 'storage_rule': 'keep'});
    await v6.insert('sites', {
      'id': 's1', 'workspace_id': 'ws', 'name': 'Forum', 'monogram': 'Fr',
      'url': 'https://forum.example.com', 'cookie_policy': 'keep',
      'proxy_mode': 'socks5', 'proxy_host': '127.0.0.1', 'proxy_port': 9050,
      'profile_id': 'p1',
    });
    await v6.close();

    final upgraded = await AppDatabase.open(path: path, factory: databaseFactoryFfi);
    final site = siteFromRow((await upgraded.db.query('sites')).single);
    expect(site.proxyUser, isNull);
    expect(site.proxyPassword, isNull);
    expect(site.proxyLoginPerSite, isFalse);
    expect(site.proxyHost, '127.0.0.1', reason: 'nothing else changes');
    await upgraded.close();
  });

  test('copyWith carries the login fields', () {
    const site = Site(
      id: 's', workspaceId: 'w', name: 'n', monogram: 'N', url: 'https://a.example',
      profileId: 'p', proxyUser: 'alice', proxyPassword: 'pw', proxyLoginPerSite: true,
    );
    final copy = site.copyWith(profileId: 'q');
    expect(copy.proxyUser, 'alice');
    expect(copy.proxyPassword, 'pw');
    expect(copy.proxyLoginPerSite, isTrue);
  });
}
```

In `test/data/container_engine_channel_test.dart`, inside the group with the two `open` tests, add (same setup as "open sends the typed address apart from the stored url"):

```dart
    test('open sends the proxy login and the per-site choice', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return <String, Object?>{
          'siteId': 's1', 'phase': 'opening', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
        };
      });
      const typed = Site(
        id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p',
        proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
        proxyUser: 'alice', proxyPassword: 's3cret',
      );

      await ChannelContainerEngine().open(typed);
      await ChannelContainerEngine().open(typed.copyWith(proxyLoginPerSite: true));

      final args = [for (final c in calls) c.arguments as Map<Object?, Object?>];
      expect(args.first['proxyUser'], 'alice');
      expect(args.first['proxyPassword'], 's3cret');
      expect(args.map((a) => a['proxyLoginPerSite']), [false, true]);
    });
```

and at top level, beside "a refused session decodes its failure reason":

```dart
  test('a rejected login decodes on a session and on a download result', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <Object?, Object?>{},
          'failure': 'proxyLoginRejected',
        },
      ],
    };
    expect(sessionsFromEvent(event).single.failure, RouteFailure.proxyLoginRejected);
    final download = downloadResultFromEvent(<Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-9',
      'outcome': 'failed', 'reason': 'proxyLoginRejected',
    });
    expect(download.reason, RouteFailure.proxyLoginRejected);
  });
```

In `test/domain/route_failure_copy_test.dart`, add:

```dart
  test('a rejected login has its own headline and the generic sentence', () {
    expect(proxyFailureHeadline(RouteFailure.proxyLoginRejected), 'The proxy rejected the login');
    expect(
      proxyFailureDetail(RouteFailure.proxyLoginRejected,
          siteName: 'Forum', tunnelDescriptor: 'socks5 · 127.0.0.1:9050'),
      'Forum is set to go through socks5 · 127.0.0.1:9050, which did not complete '
      'the connection. The page was not loaded, so no request left your device.',
    );
  });
```

(Add `import 'package:container/domain/models/route_failure_copy.dart';` if the file does not already import it.)

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/data/proxy_login_storage_test.dart test/data/container_engine_channel_test.dart test/domain/route_failure_copy_test.dart`
Expected: compile errors — `proxyUser`, `proxyLoginRejected` undefined.

- [ ] **Step 3: `Site`**

In `lib/domain/models/site.dart`, add to the constructor after `this.proxyPort,`:

```dart
    this.proxyUser,
    this.proxyPassword,
    this.proxyLoginPerSite = false,
```

the fields after `final int? proxyPort;`:

```dart
  /// The login typed for this site's proxy (proxy-auth spec §1). Both are null
  /// unless the proxy is on, [proxyLoginPerSite] is off and a user was typed
  /// (ruling 8). The password is kept exactly as typed, in the encrypted vault.
  final String? proxyUser;
  final String? proxyPassword;

  /// Use a login derived from [profileId] instead (spec §2.3): Tor then gives
  /// this site its own circuit, and a wipe gives it a new one.
  final bool proxyLoginPerSite;
```

and to `copyWith` — parameters `String? proxyUser, String? proxyPassword, bool? proxyLoginPerSite,` after `int? proxyPort,`, and in the body after `proxyPort: ...`:

```dart
      proxyUser: proxyUser ?? this.proxyUser,
      proxyPassword: proxyPassword ?? this.proxyPassword,
      proxyLoginPerSite: proxyLoginPerSite ?? this.proxyLoginPerSite,
```

(`copyWith` cannot clear them to null; the form builds a fresh `Site` through `buildSite`, which can.)

- [ ] **Step 4: Schema 7**

In `app_database.dart`: `static const schemaVersion = 7;`. In `onCreate`'s `CREATE TABLE sites`, after `proxy_port      INTEGER,` add:

```sql
              proxy_user      TEXT,
              proxy_password  TEXT,
              proxy_login_per_site INTEGER NOT NULL DEFAULT 0,
```

In `onUpgrade`, after the `from < 6` step:

```dart
          if (from < 7) {
            // Proxy authentication: existing sites have no login.
            await db.execute('ALTER TABLE sites ADD COLUMN proxy_user TEXT');
            await db.execute('ALTER TABLE sites ADD COLUMN proxy_password TEXT');
            await db.execute(
                'ALTER TABLE sites ADD COLUMN proxy_login_per_site INTEGER NOT NULL DEFAULT 0');
          }
```

In `siteToRow`, after `'proxy_port': s.proxyPort,`:

```dart
      'proxy_user': s.proxyUser,
      'proxy_password': s.proxyPassword,
      'proxy_login_per_site': s.proxyLoginPerSite ? 1 : 0,
```

In `siteFromRow`, after `proxyPort: ...`:

```dart
    proxyUser: r['proxy_user'] as String?,
    proxyPassword: r['proxy_password'] as String?,
    proxyLoginPerSite: (r['proxy_login_per_site'] as int? ?? 0) == 1,
```

- [ ] **Step 5: Channel and failure**

In `container_engine_channel.dart`'s `open` map, after `'proxyPort': site.proxyPort,`:

```dart
      'proxyUser': site.proxyUser,
      'proxyPassword': site.proxyPassword,
      'proxyLoginPerSite': site.proxyLoginPerSite,
```

and in `_failure`, before `_ => null`: `'proxyLoginRejected' => RouteFailure.proxyLoginRejected,`.

In `route_decision.dart`, add to the enum after `unsupported,`:

```dart

  /// The site's proxy turned its login down, or wanted one it does not have
  /// (proxy-auth spec §3).
  proxyLoginRejected,
```

and to `refusalMessage`: `RouteFailure.proxyLoginRejected => 'The proxy rejected the login',`.

- [ ] **Step 6: Run the tests, then the whole suite**

Run the Step 2 command, then `flutter analyze` and `flutter test`. Expected: all pass, analyze clean. Any other exhaustive `switch` over `RouteFailure` the analyzer flags gets the case with `refusalMessage`'s copy.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/models/site.dart lib/data/services/app_database.dart lib/data/services/container_engine_channel.dart lib/domain/models/route_decision.dart test/data/proxy_login_storage_test.dart test/data/container_engine_channel_test.dart test/domain/route_failure_copy_test.dart
git commit -m "feat: store a site's proxy login (schema 7) and send it to the engine"
```

---

### Task 6: Throwaways and the decoy carry the login

**Files:**
- Modify: `lib/domain/models/destination.dart`, `lib/domain/models/throwaway.dart`
- Modify: `test/domain/throwaway_test.dart`, `test/data/decoy_provisioner_test.dart`

**Interfaces:**
- Consumes: `Site.proxyUser`/`proxyPassword`/`proxyLoginPerSite` (Task 5).
- Produces: `Throwaway(url, mode, proxyHost, proxyPort, {String? proxyUser, String? proxyPassword, bool proxyLoginPerSite = false})`.

- [ ] **Step 1: Write the failing tests**

In `test/domain/throwaway_test.dart`, give `_current` a login — add `proxyUser: 'alice', proxyPassword: 's3cret',` after `proxyPort: 9050,` — and add, in the first test after `expect(throwaway.proxyPort, 9050);`:

```dart
    expect(throwaway.proxyUser, 'alice');
    expect(throwaway.proxyPassword, 's3cret');
    expect(throwaway.proxyLoginPerSite, isFalse);
```

and a new test:

```dart
  test('a throwaway from a per-site container is per-site, on its own profile', () {
    final destination = destinationFor(
      Uri.parse('https://news.example.org/today'),
      current: _current.copyWith(proxyLoginPerSite: true),
      saved: const [],
    ) as Throwaway;
    var next = 0;
    final throwaway = buildThrowaway(
        destination: destination, current: _current, newId: () => 'id${next++}');

    expect(throwaway.proxyLoginPerSite, isTrue);
    expect(throwaway.profileId, isNot(_current.profileId),
        reason: 'its own profile id gives it its own login (spec §4)');
  });
```

In `test/data/decoy_provisioner_test.dart`, inside `group('resyncDecoy', ...)`:

```dart
    test('copies a site\'s proxy login, and the per-site choice on its own profile',
        () async {
      final sites = SqliteSiteRepository(real);
      final news = (await sites.byId('s1'))!;
      await sites.upsert(news.copyWith(
          proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
          proxyUser: 'alice', proxyPassword: 's3cret', proxyLoginPerSite: true));

      await resyncDecoy(from: real, into: decoy);

      final copy = (await SqliteSiteRepository(decoy).byId('s1'))!;
      expect(copy.proxyUser, 'alice');
      expect(copy.proxyPassword, 's3cret');
      expect(copy.proxyLoginPerSite, isTrue);
      expect(copy.profileId, isNot(news.profileId),
          reason: 'so its derived login differs from the real vault\'s');
    });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/domain/throwaway_test.dart test/data/decoy_provisioner_test.dart`
Expected: the throwaway tests fail (`proxyUser` is null on the throwaway). The decoy test may already pass, because `resyncDecoy` copies with `copyWith` (Task 5 made it carry the fields); it stays as the pin for spec §4.

- [ ] **Step 3: Implement**

In `destination.dart`, `Throwaway` becomes:

```dart
/// Opens a new throwaway container at [url], on the route of the container
/// it was typed in: [mode], [proxyHost], [proxyPort] and its proxy login
/// exactly as they are (proxy-auth spec §4).
class Throwaway extends Destination {
  const Throwaway(this.url, this.mode, this.proxyHost, this.proxyPort,
      {this.proxyUser, this.proxyPassword, this.proxyLoginPerSite = false});

  @override
  final Uri url;
  final ProxyMode mode;
  final String? proxyHost;
  final int? proxyPort;
  final String? proxyUser;
  final String? proxyPassword;
  final bool proxyLoginPerSite;
}
```

and the last line of `destinationFor`:

```dart
  return Throwaway(url, current.proxyMode, current.proxyHost, current.proxyPort,
      proxyUser: current.proxyUser,
      proxyPassword: current.proxyPassword,
      proxyLoginPerSite: current.proxyLoginPerSite);
```

In `throwaway.dart`, after `proxyPort: destination.proxyPort,`:

```dart
    proxyUser: destination.proxyUser,
    proxyPassword: destination.proxyPassword,
    proxyLoginPerSite: destination.proxyLoginPerSite,
```

and in its doc comment, "Only the route is inherited" becomes "Only the route — its proxy login included — is inherited", plus one sentence at the end: "With per-site login on, the fresh profile id gives the throwaway its own login."

- [ ] **Step 4: Run the tests and the suite**

Run the Step 2 command, then `flutter test`. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models/destination.dart lib/domain/models/throwaway.dart test/domain/throwaway_test.dart test/data/decoy_provisioner_test.dart
git commit -m "feat: throwaways and the decoy inherit a site's proxy login"
```

---

### Task 7: The login block on `2a`'s Network tab

**Files:**
- Modify: `lib/ui/features/add_site/view_models/add_site_view.dart`
- Modify: `lib/ui/features/add_site/views/network_tab.dart`
- Modify: `lib/ui/features/add_site/views/add_site_screen.dart`
- Create: `test/ui/features/add_site_login_test.dart`

**Interfaces:**
- Consumes: the three `Site` fields (Task 5).
- Produces: `buildSite(..., String proxyUser = '', String proxyPassword = '', bool proxyLoginPerSite = false)`; widget keys `proxy-enabled`, `proxy-login-per-site`, `proxy-user`, `proxy-password`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:container/domain/models/site.dart';
import 'package:container/domain/models/workspace.dart';
import 'package:container/ui/features/add_site/view_models/add_site_view.dart';
import 'package:container/ui/features/add_site/views/add_site_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _workspaces = [
  Workspace(id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
];

Future<void> _pump(WidgetTester tester, {Site? initial, ValueChanged<Site>? onSave}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(initial: initial, workspaces: _workspaces, onSave: onSave ?? (_) {}),
  ));
  await tester.tap(find.text('Network'));
  await tester.pumpAndSettle();
}

TextField _textField(WidgetTester tester, String key) => tester.widget<TextField>(
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField)));

Site _build({
  ProxyMode proxyMode = ProxyMode.socks5,
  String proxyUser = 'alice',
  String proxyPassword = 's3cret',
  bool proxyLoginPerSite = false,
}) =>
    buildSite(
      initial: null, url: 'https://forum.example.com', name: 'Forum', monogram: 'Fr',
      workspaceId: 'ws-personal', cookiePolicy: CookiePolicy.keep,
      proxyMode: proxyMode,
      proxyHost: proxyMode == ProxyMode.direct ? null : '127.0.0.1',
      proxyPort: proxyMode == ProxyMode.direct ? null : 9050,
      proxyUser: proxyUser, proxyPassword: proxyPassword, proxyLoginPerSite: proxyLoginPerSite,
      blockWebRtc: true, blockTrackers: true, antiFingerprinting: true,
      allowCamera: false, allowMicrophone: false, allowLocation: false, allowClipboard: false,
      requirePin: false, showInDecoy: false, userAgentMode: UserAgentMode.android,
      forceDark: true, openInReader: false, pageZoom: 100, customCss: '', customJs: '',
    );

void main() {
  group('buildSite keeps a typed login only when it can be used (ruling 8)', () {
    test('a typed login on a proxied site is kept, the password exactly as typed', () {
      final site = _build(proxyPassword: ' s3cret ');
      expect(site.proxyUser, 'alice');
      expect(site.proxyPassword, ' s3cret ');
      expect(site.proxyLoginPerSite, isFalse);
    });

    // Review Focus 5.
    test('per-site login drops a typed one', () {
      final site = _build(proxyLoginPerSite: true);
      expect(site.proxyUser, isNull);
      expect(site.proxyPassword, isNull);
      expect(site.proxyLoginPerSite, isTrue);
    });

    test('a direct site keeps no login and no per-site choice', () {
      final site = _build(proxyMode: ProxyMode.direct, proxyLoginPerSite: true);
      expect(site.proxyUser, isNull);
      expect(site.proxyPassword, isNull);
      expect(site.proxyLoginPerSite, isFalse);
    });

    test('a password without a user is not kept', () {
      final site = _build(proxyUser: '');
      expect(site.proxyUser, isNull);
      expect(site.proxyPassword, isNull);
    });
  });

  testWidgets('the login block shows only while the proxy is on', (tester) async {
    await _pump(tester);
    expect(find.text('Separate login per site'), findsNothing);
    expect(find.text('USERNAME'), findsNothing);

    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();

    expect(find.text('Separate login per site'), findsOneWidget);
    expect(find.text('Tor gives this site its own circuit'), findsOneWidget);
    expect(find.text('USERNAME'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
  });

  testWidgets('per-site login hides the two fields', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('proxy-login-per-site')));
    await tester.pumpAndSettle();

    expect(find.text('USERNAME'), findsNothing);
    expect(find.text('PASSWORD'), findsNothing);
  });

  testWidgets('the password is masked and each field takes 255 characters', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();

    expect(_textField(tester, 'proxy-password').obscureText, isTrue);
    expect(_textField(tester, 'proxy-user').obscureText, isFalse);

    await tester.enterText(find.byKey(const Key('proxy-user')), 'u' * 300);
    await tester.enterText(find.byKey(const Key('proxy-password')), 'p' * 300);
    expect(_textField(tester, 'proxy-user').controller!.text, hasLength(255));
    expect(_textField(tester, 'proxy-password').controller!.text, hasLength(255));
  });

  testWidgets('saving keeps the typed login', (tester) async {
    Site? saved;
    await _pump(tester, onSave: (s) => saved = s);
    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('proxy-user')), 'alice');
    await tester.enterText(find.byKey(const Key('proxy-password')), 's3cret');

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(saved!.proxyUser, 'alice');
    expect(saved!.proxyPassword, 's3cret');
    expect(saved!.proxyLoginPerSite, isFalse);
  });

  testWidgets('editing a site, or saving a throwaway, starts from its login', (tester) async {
    const existing = Site(
      id: 's1', workspaceId: 'ws-personal', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
      proxyMode: ProxyMode.http, proxyHost: '10.0.2.2', proxyPort: 8888,
      proxyUser: 'alice', proxyPassword: 's3cret',
    );
    Site? saved;
    await _pump(tester, initial: existing, onSave: (s) => saved = s);

    expect(_textField(tester, 'proxy-user').controller!.text, 'alice');
    expect(_textField(tester, 'proxy-password').controller!.text, 's3cret');

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.proxyUser, 'alice');
    expect(saved!.proxyPassword, 's3cret');
  });

  testWidgets('a per-site site opens with the toggle on and no fields', (tester) async {
    const existing = Site(
      id: 's1', workspaceId: 'ws-personal', name: 'Forum', monogram: 'Fr',
      url: 'https://forum.example.com', profileId: 'p1',
      proxyMode: ProxyMode.socks5, proxyHost: '127.0.0.1', proxyPort: 9050,
      proxyLoginPerSite: true,
    );
    await _pump(tester, initial: existing);
    expect(find.text('Separate login per site'), findsOneWidget);
    expect(find.text('USERNAME'), findsNothing);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/ui/features/add_site_login_test.dart`
Expected: compile error — `buildSite` has no `proxyUser`.

- [ ] **Step 3: `buildSite` applies ruling 8**

In `add_site_view.dart`, add parameters after `int? proxyPort,`:

```dart
  String proxyUser = '',
  String proxyPassword = '',
  bool proxyLoginPerSite = false,
```

before `return Site(`:

```dart
  // Ruling 8: a typed login is kept only while the proxy is on, per-site login
  // is off and a user was typed; otherwise neither half is. Nothing is trimmed.
  final proxied = proxyMode != ProxyMode.direct;
  final perSite = proxied && proxyLoginPerSite;
  final typed = proxied && !perSite && proxyUser.isNotEmpty;
```

and in the `Site(...)`, after `proxyPort: proxyPort,`:

```dart
    proxyUser: typed ? proxyUser : null,
    proxyPassword: typed ? proxyPassword : null,
    proxyLoginPerSite: perSite,
```

- [ ] **Step 4: The Network tab draws the block**

In `network_tab.dart`, add `import 'package:flutter/services.dart';`, the constructor parameters after `required this.portController,`:

```dart
    required this.loginPerSite,
    required this.onLoginPerSiteChanged,
    required this.userController,
    required this.passwordController,
```

and fields:

```dart
  final bool loginPerSite;
  final ValueChanged<bool> onLoginPerSiteChanged;
  final TextEditingController userController;
  final TextEditingController passwordController;
```

Give the proxy toggle its key: in the first `_toggleRow(...)` call add `switchKey: const Key('proxy-enabled'),`. Between the HOST/PORT `Row` and the `SizedBox(height: 18)` before "Block WebRTC", insert (ruling 12: toggle, then the two fields):

```dart
        // Proxy-auth spec §1: only while the proxy is on.
        if (proxyEnabled) ...[
          const SizedBox(height: 18),
          _toggleRow(
            title: 'Separate login per site',
            subtitle: 'Tor gives this site its own circuit',
            value: loginPerSite,
            onChanged: onLoginPerSiteChanged,
            switchKey: const Key('proxy-login-per-site'),
          ),
          if (!loginPerSite) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('USERNAME', style: _label),
                      const SizedBox(height: 7),
                      _field(userController, key: const Key('proxy-user'), loginField: true),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PASSWORD', style: _label),
                      const SizedBox(height: 7),
                      _field(passwordController,
                          key: const Key('proxy-password'), loginField: true, obscure: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
```

The labels use the tab's existing `_label`, the same as HOST and PORT. `_field` becomes:

```dart
  /// [loginField]: at most 255 characters (ruling 9), no autocorrect or
  /// suggestions. [obscure] masks it, with no reveal control (spec §1).
  Widget _field(TextEditingController controller,
          {Key? key, bool loginField = false, bool obscure = false}) =>
      Container(
        key: key,
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line09),
        ),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: !loginField,
          enableSuggestions: !loginField,
          inputFormatters: loginField ? [LengthLimitingTextInputFormatter(255)] : null,
          style: mono(size: 13, color: C.textSecondary),
          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
        ),
      );
```

`_toggleRow` gains `Key? switchKey` and passes it on: `_switch(key: switchKey, value: value, onChanged: onChanged)`, with `_switch({Key? key, required bool value, ...})` putting `key: key` on its `GestureDetector`.

- [ ] **Step 5: The screen holds the state**

In `add_site_screen.dart`, add controllers beside `_portController`:

```dart
  late final _userController = TextEditingController(text: widget.initial?.proxyUser ?? '');
  late final _passwordController =
      TextEditingController(text: widget.initial?.proxyPassword ?? '');
```

state beside `_proxyMode`: `late bool _loginPerSite = widget.initial?.proxyLoginPerSite ?? false;`; dispose both controllers in `dispose`; in `_save` after `proxyPort: ...`:

```dart
      proxyUser: _userController.text,
      proxyPassword: _passwordController.text,
      proxyLoginPerSite: _loginPerSite,
```

and in `NetworkTab(...)` after `portController: _portController,`:

```dart
          loginPerSite: _loginPerSite,
          onLoginPerSiteChanged: (v) => setState(() => _loginPerSite = v),
          userController: _userController,
          passwordController: _passwordController,
```

A throwaway's save form already opens on `_site.copyWith(...)` (`ContainerRoute._saveAsSite`), which now carries the login, so spec §4's pre-fill needs no change there.

- [ ] **Step 6: Run the tests and the suite**

Run: `flutter test test/ui/features/add_site_login_test.dart test/ui/features/add_site_test.dart`, then `flutter analyze` and `flutter test`. Expected: all pass, analyze clean.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/features/add_site test/ui/features/add_site_login_test.dart
git commit -m "feat(add-site): proxy login and per-site login on the Network tab"
```

---

### Task 8: Harness login, run sheet, docs, full verification

**Files:**
- Modify: `tool/device-check/proxy.py`, `tool/device-check/README.md`
- Modify: `CLAUDE.md` (plan table)

- [ ] **Step 1: The harness proxy can require a login**

In `proxy.py`, add arguments in `main()`:

```python
    parser.add_argument("--user", help="require this username (SOCKS5 RFC 1929 and HTTP Basic); off by default")
    parser.add_argument("--password", default="", help="the password that goes with --user")
    parser.add_argument("--any-login", action="store_true",
                        help="require a login but accept any, logging its username (for per-site logins)")
```

and before starting threads:

```python
    global LOGIN, ANY_LOGIN
    LOGIN = (args.user, args.password) if args.user is not None else None
    ANY_LOGIN = args.any_login
```

with module-level `LOGIN = None` and `ANY_LOGIN = False`. A login is required when `LOGIN is not None or ANY_LOGIN`; it is accepted when `ANY_LOGIN` or it equals `LOGIN`.

In `handle_socks`, replace `client.sendall(b"\x05\x00")` with:

```python
        offered = read_exactly(client, methods)  # replaces the bare read_exactly(client, methods) above
        if LOGIN is None and not ANY_LOGIN:
            client.sendall(b"\x05\x00")
        elif 2 not in offered:
            log(f"{label} rejected: no login offered")
            client.sendall(b"\x05\xff")
            return client.close()
        else:
            client.sendall(b"\x05\x02")
            _, ulen = read_exactly(client, 2)
            user = read_exactly(client, ulen).decode("utf-8", "replace")
            password = read_exactly(client, read_exactly(client, 1)[0]).decode("utf-8", "replace")
            ok = ANY_LOGIN or (user, password) == LOGIN
            log(f"{label} login {'accepted' if ok else 'rejected'} for user {user!r}")
            client.sendall(b"\x01\x00" if ok else b"\x01\x01")
            if not ok:
                return client.close()
```

(the existing `read_exactly(client, methods)` line becomes the `offered = ...` line). In `handle_http`, after parsing `target`, before connecting:

```python
    if LOGIN is not None or ANY_LOGIN:
        headers = head.split(b"\r\n\r\n", 1)[0].decode("latin-1").split("\r\n")[1:]
        sent = next((h.split(":", 1)[1].strip() for h in headers if h.lower().startswith("proxy-authorization:")), None)
        user = None
        if sent is not None and sent.lower().startswith("basic "):
            user = base64.b64decode(sent[6:]).decode("utf-8", "replace").split(":", 1)[0]
        expected = None if LOGIN is None else \
            "Basic " + base64.b64encode(f"{LOGIN[0]}:{LOGIN[1]}".encode("utf-8")).decode("ascii")
        ok = sent is not None and (ANY_LOGIN or sent == expected)
        log(f"{label} login {'missing' if sent is None else 'accepted' if ok else 'rejected'} for user {user!r}")
        if not ok:
            client.sendall(b"HTTP/1.1 407 Proxy Authentication Required\r\nProxy-Authenticate: Basic realm=\"device-check\"\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
            return client.close()
```

Add `import base64`. The harness logs the username it was sent — it is a test login on the host, never a real one; the app itself logs nothing. Check: `python tool/device-check/proxy.py --help` prints the two new options.

- [ ] **Step 2: Run sheet**

Append to `tool/device-check/README.md` a section `## Run sheet: proxy authentication (Plan 14)` with these checks, each naming what to look for in `proxy.py`'s log and the UI dump:

1. `python proxy.py --user alice --password s3cret`. A SOCKS5 site at `https://example.com` via `10.0.2.2:1080` with USERNAME `alice`, PASSWORD `s3cret` loads; the log shows `login accepted for user 'alice'` and `SOCKS5 NAME example.com:443`.
2. Same site, PASSWORD `wrong`: `8b` reads "The proxy rejected the login"; the log shows `login rejected`; no `SOCKS5 NAME` line follows it.
3. Same with no login typed: `8b` reads "The proxy rejected the login"; the log shows `rejected: no login offered`.
4. Repeat 1–3 for an HTTP site via `10.0.2.2:8888` (`login missing`/`rejected` lines).
5. `python proxy.py --any-login`. Turn "Separate login per site" on for two SOCKS5 sites and open both: each logs `login accepted for user '<32 hex digits>'`, and the two users differ. "Wipe this site's data" on one and reopen it: its user changes; the other's does not. Repeat with one HTTP site (its user is logged the same way).
6. A throwaway typed from a logged-in site loads through the same login (its log line shows `alice`).
7. With the login set and the site live, restart `proxy.py` with a different `--password`, then reload: `8c` (tunnel dropped) appears, not `8b`.

- [ ] **Step 3: CLAUDE.md**

Add a row to the plan table after Plan 12's:

```markdown
| 14 — Proxy authentication | `2026-10-02-proxy-authentication.md` | **Built** (2026-10-02, branch `proxy-auth`) | A site's upstream proxy can take a login: typed per site (USERNAME/PASSWORD on `2a`'s Network tab), or derived from the site's `profileId` ("Separate login per site", for Tor circuit isolation; a wipe rotates it). Every SOCKS route now goes through the hand-written `Socks5Tunnel` (RFC 1928/1929) instead of the platform's; `HttpConnectTunnel` sends `Proxy-Authorization: Basic`. A rejected login (`407`, a SOCKS5 auth failure, `0xFF`) is `PROXY_LOGIN_REJECTED`, "The proxy rejected the login", reported route-wide by the loopback proxy; a refusal while a session is still opening now refuses it (`8b`). Schema 7. Implements `docs/superpowers/specs/2026-10-02-proxy-authentication-design.md`. Verified: <fill in the counts from Step 4>. **Not verified on a device** — run sheet in `tool/device-check/README.md`. |
```

- [ ] **Step 4: Full verification**

From the repo root: `flutter analyze`; `flutter test`; `flutter build apk --debug` (zero `e:` lines); from `android/`: `./gradlew :app:testDebugUnitTest`, then

```bash
grep -ho 'tests="[0-9]*"' ../build/app/test-results/testDebugUnitTest/TEST-*.xml | grep -o '[0-9]*' | paste -sd+ | bc
grep -h 'failures="[1-9]\|errors="[1-9]' ../build/app/test-results/testDebugUnitTest/TEST-*.xml   # expect nothing
```

Write the real counts into the CLAUDE.md row in place of the placeholder, exactly as read.

- [ ] **Step 5: Commit**

```bash
git add tool/device-check/proxy.py tool/device-check/README.md CLAUDE.md docs/superpowers/plans/2026-10-02-proxy-authentication.md
git commit -m "docs: proxy authentication run sheet and plan record"
```

---

## Device checks

Run 2026-10-02 by session flutter-app-21 on the `Pixel_9` emulator (API 36, not a physical phone), with a debug build of `efd69c4` (the branch tip, so without `main`'s `0069a7b`, `e6ccd7a` and `bf32358`; none touches the proxy path) installed fresh, and `tool/device-check/proxy.py` on the host. The run sheet in `tool/device-check/README.md`, each check:

1. **Seen.** SOCKS5 `https://example.com` via `10.0.2.2:1080` with `alice`/`s3cret`: `login accepted for user 'alice'`, then `SOCKS5 NAME example.com:443`, and the page rendered. The regression half, with `proxy.py` taking no login and none typed: `SOCKS5 NAME example.com:443` and the page rendered.
2. **Seen.** Password `wrong`: `login rejected for user 'alice'`, no `NAME` line after it, and `8b` read "The proxy rejected the login". The first try showed `8c` instead, and that is correct: the reopened site's page came from WebView's HTTP cache with no request at all, so the session was already live when ⟳ reached the proxy. A close and wipe (a fresh profile, so an empty cache) then gave `8b`.
3. **Seen.** No login typed: `rejected: no login offered`, and `8b`.
4. **Seen** over HTTP CONNECT via `10.0.2.2:8888`: `CONNECT example.com:443 login accepted for user 'alice'` and the page; `login rejected for user 'alice'` and `8b`; `login missing for user None` and `8b`.
5. **Seen** with `--any-login`: two SOCKS5 sites logged `ab7bc607…` and `5985688b…`. After "Wipe this site's data" on the first, it logged `6fff2c18…`, and the second, reloaded, still `5985688b…`. An HTTP site logged `CONNECT example.com:443 login accepted for user 'b80ee44a…'`. All 32 hex digits.
6. **Seen.** `example.org` typed in a logged-in SOCKS5 site's pill opened `THROWAWAY · SOCKS5`, which logged `login accepted for user 'alice'` and `SOCKS5 NAME example.org:443`.
7. **Seen.** With the site live, `proxy.py` restarted with `--password other` and ⟳: `login rejected for user 'alice'`, and `8c` "Tunnel dropped".

Found along the way, none from this plan:

- **`8b`'s three buttons do nothing.** "Try again", "Change proxy settings" and "Open without the tunnel" each call `Navigator.pop(context)` with the `ContainerRoute`'s context, captured before `_handleRefusal`'s `pushReplacement` replaced that route (`container_route.dart`, `_handleRefusal`). Taps changed nothing and logged nothing. System back works.
- **A refused site stays under OPEN NOW** and in `N SESSIONS`, and `2c`'s "Close all and wipe" leaves it there. Reopening it opens a fresh session normally.
- **`8b` always reads "Last worked · never on this device"**: `_handleRefusal` passes the literal, even for a site that loaded minutes before.

**✅ All three fixed 2026-10-02 (branch `fix-8b`), by the user's rulings of that day:**

- `8b` is shown inside `ContainerRoute` instead of replacing it, so the route and its context outlive the refusal, and a throwaway stays one (its pusher forgets it once its route is gone). The buttons reopen the site in place (`_reopen`):
  - **Try again** opens the site again as saved.
  - **Change proxy settings** opens the site's form on its Network tab (`AddSiteScreen.initialTab`). Saving writes the site and opens it again as saved. For a throwaway, saving saves it as a site, from the same starting point as "Save as a site". × returns to `8b`.
  - **Open without the tunnel** opens this visit only on the direct route, in the site's own profile (`Site.withoutProxy`). The saved site keeps its proxy. The pill has no route label, and a throwaway typed during the visit still inherits the site's saved route.
- A refused saved site is taken off OPEN NOW (`closeSite`), and its dead native session is closed. A refused throwaway's session stays until its route goes.
- **Last worked** is a `sites.last_worked_at` column (schema 8). It is not a `Site` field, so an edit never overwrites it and a decoy sync never copies it. It is set when an open goes live on the site's own route (a direct visit does not count), cleared by `wipeSavedSite`, and shown as "2 hours ago", "1 minute ago" or "just now" (`lastWorkedLabel`). A throwaway's is remembered by its route only.
- Tests: `last_worked_test.dart` 4, `site_without_proxy_test.dart` 1, `relative_age_test.dart` +3, `site_wipe_test.dart` +1, and `container_route_test.dart` +16 (the `8b` group, and when a site records that it worked). Gates: `flutter analyze` clean, `flutter test` 662/662, `flutter build apk --debug` succeeding (no Kotlin changed).
- **Seen on the emulator** (fresh install, so the v7→v8 migration ran only in the unit test):
  - "never on this device" for a site that never loaded, and Try again with the proxy up went live.
  - A later refusal read "Last worked · 1 minute ago", and the dashboard showed the site under IDLE with `0 SESSIONS`.
  - Change proxy settings opened on Network: × returned to `8b`, and saving port 1080 went live through the proxy.
  - Open without the tunnel loaded `example.com` with no route label and nothing at the proxy, and the row still read `socks5`. The next tunnelled refusal still read "1 minute ago", not "just now".

## Known gaps

- **Device-verified on an emulator only** (see Device checks), not a physical phone, and never against a real-world proxy or Tor: every check talked to `tool/device-check/proxy.py`.
- **`ProxyProbe` checks no login** (ruling 11): a site with a wrong password reads as reachable until its first request.
- **A rejected login on a main-frame TLS path is not a route refusal:** `Session.onTunnelDropped` (the interceptor's TLS report) still only reaches live sessions. Ruling 6 is applied to the loopback proxy's reports, which are the only route refusals.
- **The derived login is not shown anywhere.** A user who wants to see which Tor circuit a site uses has no UI for it; the spec draws none.
- **SOCKS5 GSSAPI and other methods are not offered.** Only `0x00` and `0x02`.

## Handoff

- `Route.Proxy.login` is the single place a tunnel learns its login; any future proxy kind reads it there.
- `refusalActionFor` decides what a route refusal does by phase; extend it rather than adding phase checks at call sites.
- `downloadFailureFor` is now top-level and tested.

# Isolated Web Container — Plan 13: Loopback Authenticating Proxy (P2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Work in a git worktree on branch `p2-loopback-proxy`, off `main` at `c06e075` or later.

**Goal:** Every site's WebView traffic goes through one in-app proxy on `127.0.0.1`. The proxy tells sites apart by the credentials each site's WebView answers its `407` with, and routes each connection on that site's own route (direct, SOCKS5 or HTTP CONNECT). Chromium does the HTTP work again, so proxied sites keep cookies, follow redirects and send POST bodies. A page's preconnect can no longer leave the device directly.

**Architecture:** Three new pure-ish Kotlin units:
- `SiteCredentials`: one random credential per WebView profile, and a table from credential to the open session's `SiteConfig`.
- `LoopbackRequest.kt`: parses a proxy request head and decides what to do with it, with no sockets involved.
- `LoopbackProxy`: the socket server that authenticates, routes with the existing `Router`, and relays.

`MainActivity` starts the proxy once per process and points WebView's process-wide `ProxyController` override at it. That replaces `AutofillBlock.kt`, since there can be only one override. `RequestInterceptor` keeps only the closing-view gate and filter-list blocks, answers the proxy's challenge in `onReceivedHttpAuthRequest`, and reports a main-frame TLS failure. `ProxyHttpClient` stays, for downloads only. The Dart side gains one failure kind, `unsupported`, for a WebView that cannot override its proxy.

**Tech Stack:** Kotlin, `androidx.webkit` 1.12 (`ProxyController`, `ProxyConfig`, multi-profile), `java.net` sockets, JUnit 4 on the JVM; Flutter/Dart 3 for the one new failure kind. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-30-loopback-proxy-design.md`. Its evidence is `docs/superpowers/specs/2026-09-30-p2-loopback-proxy-findings.md`. Read both alongside this plan. The fix record this project follows is `docs/superpowers/plans/2026-09-30-proxy-leak-fixes.md`, where leaks a1–a4, b, c, f and g are named.

## Global Constraints

These come from `CLAUDE.md` and the spec. Every task's requirements include them.

- **The interceptor never falls back to direct.**
  - The override has no `DIRECT` rule, so a dead loopback proxy fails every request.
  - A proxied site on a WebView without `PROXY_OVERRIDE` is refused at open with `RouteFailure.UNSUPPORTED`. It is never sent direct.
  - A refused route is answered `502`, never connected.
- **No network requests of the app's own.** The proxy only relays what a site's WebView asks for. It never fetches anything itself, and it never logs a host in the committed code.
- **Copy is verbatim.** The only new strings are spec §3.3's, approved by the user on 2026-09-30:
  - headline `This phone cannot route sites through a proxy`;
  - detail `Update Android System WebView to open proxied sites.`

  Nothing else is reworded.
- **Credentials.**
  - 128 bits from `SecureRandom` each for user and password.
  - One per profile, fixed for the life of the process.
  - Compared with `MessageDigest.isEqual`.
  - Never sent to Dart, written to disk, logged, or printed by `toString`.
- **One credential table and one proxy per process** (`Loopback` object). Chromium caches a profile's proxy credential in memory for the whole process (findings: "Is the auth cache cleared"). A second table would issue credentials that the cache never sends.
- **The listener binds `127.0.0.1` only**, on a port the OS chooses.
- **A credential is valid only while its site has an open session.** `EngineChannel` binds it in `register` and unbinds it in `close`. Panic's `wipeAll` closes every session first, so after a panic the proxy refuses everything.
- **One `ProxyController` override per process, and the last call wins.** `blockAutofillQueries` is removed in the same task that installs the loopback override. Never ship both. The Autofill host is refused by the loopback proxy instead.
- **Threading.**
  - Proxy work never runs on the main thread (`a42896d`). The accept loop and every connection run on the proxy's own daemon threads.
  - `androidx.webkit`'s `ProfileStore`, the session map and Flutter's event sink are main-thread only. So a report from a proxy thread is posted to the main handler.
- **The closing-view gate stays, and is checked first** (`Disposition.Closed`, `8c82e90`). Nothing from a closing page reaches even the loopback proxy.
- **`ProfileManager.wipe` journals an in-use profile** (`PendingDeletions.kt`). Don't simplify it back to a bare `deleteProfile`. Don't move pushes onto the root navigator.
- **Two vaults.** The proxy never asks which vault is open. Credentials belong to profiles.
- **Kotlin tests.**
  - `android/gradlew*` and the wrapper jar are git-ignored. `flutter build apk --debug` writes them, so run it once in a fresh worktree before the first Kotlin test run.
  - Then, from `android/`: `./gradlew :app:testDebugUnitTest`.
  - Read counts from `build/app/test-results/testDebugUnitTest/TEST-*.xml`, never from `BUILD SUCCESSFUL`.
  - Flutter and Gradle commands need the Bash sandbox disabled.
- **`flutter analyze` and `flutter test` never compile Kotlin.** Every task that touches Kotlin also runs `flutter build apk --debug` and requires zero lines starting `e:`.
- **Every task ends green.** That means:
  - `flutter analyze` prints "No issues found!";
  - `flutter test` passes in full;
  - a Kotlin task also passes the JVM tests and the APK build.

  Make one commit per task, in the repo's `feat:`/`fix:`/`test:`/`docs:` style, ending with the `Co-Authored-By` line the session gives.

## Where this plan narrows or adds to the spec (deliberate)

The user should confirm item 2 in particular. Each item is also recorded in the Known gaps.

1. **Only a refused route is reported through `onRefused`.**
   - Spec §3.3's table names `PROXY_REFUSED` (502) and `UPSTREAM_TIMEOUT` (504) as the loopback proxy's. The same section says "a subresource's failure never takes over the screen". The proxy sees only a `CONNECT`, so it cannot tell a main frame from a subresource.
   - So per-connection upstream failures are answered with their status code, `502` or `504`, and reported to no one. That is also what today's `fetchThrough` does: it answers `523` and calls nothing.
   - A refused route (proxy unreachable or misconfigured) is reported, as today, because it applies to the whole site.
2. **The proxy refuses any destination named `127.0.0.1` with `403`. The spec does not say this.**
   - WebView names a challenge by host and realm only, and has no flag that says "this is a proxy". A server at `http://127.0.0.1:<port>`, which any app on the device can open, could answer `401` with realm `container`. The view could not tell that from the proxy's own `407`, and would hand that server the site's credential.
   - Refusing that one host name closes the hole. `localhost` and every other name still work.
   - The cost: a site whose address is literally `127.0.0.1` cannot be opened.
3. **Absolute-form (`http://`) requests.**
   - The body is relayed only by `Content-Length`. A request with `Transfer-Encoding` gets `411`.
   - Nothing the client sends after the body is forwarded.
   - The response head is rewritten to `Connection: close`, and a `Proxy-Authenticate` from the origin is dropped.
   - This path cannot be reached in the shipped app: `targetSdk` is 36 and there is no network security config, so WebView refuses `http://` loads before they get anywhere. (The spike had to allow cleartext to test it.) It is built and tested because the spec requires it.
4. **`TLS_FAILURE` comes only from `onReceivedError`'s `ERROR_FAILED_SSL_HANDSHAKE` on the main frame.** Certificate errors go to `onReceivedSslError` instead. That keeps WebView's default, which is to cancel, and is not reported.
5. **`declaredLength` goes with `DeclaredLengths`.** Once `DeclaredLengths` is gone, nothing calls it.
6. **The proxy's route reports are posted to the main thread.** This matters because `EngineChannel.onTunnelDropped` writes to Flutter's event sink.
7. **`register` unbinds a previous session's profile when a reopen of the same site arrives with a different profile.** Today every wipe closes first, so this never happens. It is defence in depth.

## Review Focus

These are inputs the spec implies but no test in its own list pins, ordered by how likely they are to bite. Each is pinned in the named task.

1. **A site opened again after a lock or a close.** Chromium keeps sending the credential it cached. The reopened session must be found by that same credential. (Task 1: "a site opened again is found by the credential Chromium already holds".)
2. **A site reopened with changed settings while its old session was never closed.** Routing follows the newest config. (Task 1: "a reopened site is routed by its newest settings".)
3. **A hostile local app sends garbage, an oversized head, or no head at all.**
   - Garbage and oversized heads get `400`, and nothing is forwarded.
   - A head that never finishes times out.

   (Task 2: `readHead` limit tests and `decide(null)`. Task 3: "garbage gets 400 and nothing is forwarded".)
4. **A page opens many connections at once.** Each tunnel relays only its own bytes. (Task 3: "many tunnels at once each relay their own bytes".)
5. **A local server tries to phish the credential by challenging as `127.0.0.1`.**
   - `127.0.0.1` destinations are refused.
   - The view answers only a challenge from host `127.0.0.1` with realm `container`.
   - The credential is never forwarded to an origin.

   (Task 1: "a site's own challenge gets no credential". Task 2: "a destination named 127.0.0.1 is refused" and "origin form drops the proxy's headers". Task 3: the absolute-form test.)

---

## Before Task 1: baseline

- [x] Create the worktree and bring over the native-assets cache (this machine's `sqlite3` hook cannot download it):

```bash
cd /c/Users/Metin/Desktop/flutter-app
git worktree add .claude/worktrees/p2-loopback-proxy -b p2-loopback-proxy main
mkdir -p .claude/worktrees/p2-loopback-proxy/.dart_tool
cp -r .dart_tool/hooks_runner .claude/worktrees/p2-loopback-proxy/.dart_tool/
cd .claude/worktrees/p2-loopback-proxy
```

- [x] Run every gate once and record the counts. On `c06e075` they were `flutter test` 540/540 and JVM 128/128. If yours differ, record what you actually see:

```bash
flutter analyze
flutter test
flutter build apk --debug 2>&1 | grep -c '^e:'     # expect 0
cd android && ./gradlew :app:testDebugUnitTest && cd ..
grep -ho 'tests="[0-9]*"' build/app/test-results/testDebugUnitTest/TEST-*.xml | grep -o '[0-9]*' | paste -sd+ | bc
grep -h 'failures="[1-9]\|errors="[1-9]' build/app/test-results/testDebugUnitTest/TEST-*.xml   # expect nothing
```

## File Structure

All Kotlin paths are under `android/app/src/main/kotlin/com/mono/container/`, and their tests under `android/app/src/test/kotlin/com/mono/container/engine/`.

| File | Change | Responsibility |
|---|---|---|
| `engine/SiteCredentials.kt` | create (T1) | `ProxyCredential`, `ProxyBinding`, `SiteCredentials`, `proxyAuthAnswer`, `LOOPBACK_HOST`, `PROXY_REALM` |
| `engine/LoopbackRequest.kt` | create (T2) | `readHead`, `parseRequest`, `parseAuthority`, `basicCredentials`, `decide` → `ProxyDecision`, `originFormHead`, `closingResponseHead`, `statusResponse`, `upstreamFailureStatus`, `AUTOFILL_QUERY_HOST` |
| `engine/LoopbackProxy.kt` | create (T3) | the listener, per-connection handling, `CONNECT` relay, absolute-form forward |
| `lib/domain/models/route_decision.dart` | modify (T4) | `RouteFailure.unsupported` and its `refusalMessage` |
| `lib/domain/models/route_failure_copy.dart` | modify (T4) | `unsupported`'s detail line |
| `lib/data/services/container_engine_channel.dart` | modify (T4) | decode `unsupported` |
| `engine/LoopbackOverride.kt` | create (T5) | `loopbackProxyConfig(port)`, the `Loopback` process singleton |
| `engine/AutofillBlock.kt` + its test | delete (T5) | replaced by the loopback override and `AUTOFILL_QUERY_HOST` |
| `engine/Router.kt` | modify (T5) | `RouteFailure.UNSUPPORTED`, `routeAtOpen` |
| `engine/EngineChannel.kt` | modify (T5) | binds and unbinds credentials, `routeAtOpen`, the `UNSUPPORTED` name |
| `engine/RequestInterceptor.kt` | modify (T5, T6) | T5: answers the proxy's `407`. T6: loses `fetchThrough`, gains `mainFrameFailure` |
| `engine/ContainerView.kt`, `engine/ContainerViewFactory.kt`, `MainActivity.kt` | modify (T5, T6) | wiring |
| `engine/Teardown.kt` | modify (T6) | `Disposition` down to `Closed` / `Blocked` / `ByWebView` |
| `engine/DownloadSize.kt` | modify (T6) | `heldDownloadSize(listenerLength)` only |
| `engine/ProxyHttpClient.kt` | modify (T6) | one comment clause |
| `RequestInterceptorMediaTypeTest.kt` | delete (T6) | `mediaTypeOf` is gone with `fetchThrough` |

---

### Task 1: Per-profile credentials

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/SiteCredentials.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/SiteCredentialsTest.kt`

**Interfaces:**
- Consumes: `SiteConfig`, `RouteFailure` (both existing).
- Produces:
  - `internal const val LOOPBACK_HOST = "127.0.0.1"`
  - `internal const val PROXY_REALM = "container"`
  - `class ProxyCredential(val user: String, val password: String)`, whose constructor is internal
  - `class ProxyBinding(val config: SiteConfig, val onRefused: (RouteFailure) -> Unit)`
  - `class SiteCredentials`, with these methods:
    - `credentialFor(profileId: String): ProxyCredential`
    - `bind(profileId: String, binding: ProxyBinding)`
    - `unbind(profileId: String)`
    - `lookup(user: String, password: String): ProxyBinding?`
  - `internal fun proxyAuthAnswer(host: String?, realm: String?, credential: () -> ProxyCredential): ProxyCredential?`

- [x] **Step 1: Write the failing test**

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P2 spec §2: another app on the device can connect to a loopback port, so
 * the loopback proxy's credentials are what stop it being an open relay into
 * the user's proxy. Chromium caches a profile's credential for the whole
 * process, through locks and wipes, so a credential is fixed per profile and
 * is valid only while that profile's site has an open session.
 */
class SiteCredentialsTest {

    private fun config(profileId: String, mode: String = "direct") = SiteConfig(
        siteId = "site-$profileId", profileId = profileId, url = "https://forum.example.com",
        proxyMode = mode, proxyHost = null, proxyPort = null,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    private fun binding(profileId: String, mode: String = "direct") = ProxyBinding(config(profileId, mode)) {}

    @Test fun `a credential is 128 random bits each for user and password`() {
        val credential = SiteCredentials().credentialFor("p1")
        assertTrue(credential.user.matches(Regex("[0-9a-f]{32}")))
        assertTrue(credential.password.matches(Regex("[0-9a-f]{32}")))
        assertNotEquals(credential.user, credential.password)
    }

    @Test fun `each profile gets its own credential`() {
        val credentials = SiteCredentials()
        val a = credentials.credentialFor("p1")
        val b = credentials.credentialFor("p2")
        assertNotEquals(a.user, b.user)
        assertNotEquals(a.password, b.password)
    }

    @Test fun `a profile's credential is the same for the whole run`() {
        val credentials = SiteCredentials()
        assertSame(credentials.credentialFor("p1"), credentials.credentialFor("p1"))
    }

    @Test fun `a credential finds its site only while the site's session is open`() {
        val credentials = SiteCredentials()
        val credential = credentials.credentialFor("p1")
        assertNull(credentials.lookup(credential.user, credential.password))

        val open = binding("p1")
        credentials.bind("p1", open)
        assertSame(open, credentials.lookup(credential.user, credential.password))

        credentials.unbind("p1")
        assertNull(credentials.lookup(credential.user, credential.password))
    }

    /** Review Focus 1: after a lock Chromium still sends the credential it cached. */
    @Test fun `a site opened again is found by the credential Chromium already holds`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1"))
        val cached = credentials.credentialFor("p1")
        credentials.unbind("p1")

        val reopened = binding("p1")
        credentials.bind("p1", reopened)
        assertSame(reopened, credentials.lookup(cached.user, cached.password))
    }

    /** Review Focus 2: a reopen replaces the binding, so routing follows the newest settings. */
    @Test fun `a reopened site is routed by its newest settings`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1", mode = "direct"))
        credentials.bind("p1", binding("p1", mode = "socks5"))
        val credential = credentials.credentialFor("p1")
        assertEquals("socks5", credentials.lookup(credential.user, credential.password)!!.config.proxyMode)
    }

    @Test fun `a credential never finds another profile's site`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1"))
        credentials.bind("p2", binding("p2"))
        val credential = credentials.credentialFor("p2")
        assertEquals("site-p2", credentials.lookup(credential.user, credential.password)!!.config.siteId)
    }

    @Test fun `a wrong password or a rearranged pair finds nothing`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", binding("p1"))
        val credential = credentials.credentialFor("p1")
        assertNull(credentials.lookup(credential.user, "0".repeat(32)))
        assertNull(credentials.lookup(credential.password, credential.user))
        assertNull(credentials.lookup("${credential.user}:${credential.password}", ""))
    }

    @Test fun `a credential never prints itself`() {
        val credential = SiteCredentials().credentialFor("p1")
        assertFalse(credential.toString().contains(credential.user))
        assertFalse(credential.toString().contains(credential.password))
    }

    @Test fun `the proxy's own challenge is answered with the profile's credential`() {
        val credential = SiteCredentials().credentialFor("p1")
        assertSame(credential, proxyAuthAnswer("127.0.0.1", "container") { credential })
    }

    /** Review Focus 5: a site's own HTTP auth never gets the proxy credential. */
    @Test fun `a site's own challenge gets no credential`() {
        val never: () -> ProxyCredential = { throw AssertionError("a site's challenge must not read the credential") }
        assertNull(proxyAuthAnswer("forum.example.com", "container", never))
        assertNull(proxyAuthAnswer("127.0.0.1", "Members only", never))
        assertNull(proxyAuthAnswer(null, null, never))
    }
}
```

- [x] **Step 2: Run the test and confirm it fails**

Run, from `android/`: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.SiteCredentialsTest"`
Expected: a compilation failure, with `Unresolved reference: ProxyBinding` / `SiteCredentials`.

- [x] **Step 3: Write the implementation**

```kotlin
package com.mono.container.engine

import java.security.MessageDigest
import java.security.SecureRandom

/**
 * The loopback proxy's host as Chromium names it in a proxy challenge. The
 * proxy refuses any destination with this name (see [decide]), so only the
 * proxy itself can challenge as it.
 */
internal const val LOOPBACK_HOST = "127.0.0.1"

/** The realm of the loopback proxy's `407`. Not a secret: [proxyAuthAnswer] also requires [LOOPBACK_HOST]. */
internal const val PROXY_REALM = "container"

/**
 * One profile's answer to the loopback proxy's challenge (P2 spec §2). Never
 * sent to Dart, written to disk or logged, so [toString] prints neither half.
 */
class ProxyCredential internal constructor(val user: String, val password: String) {
    override fun toString() = "ProxyCredential(redacted)"
}

/**
 * What an authenticated connection is routed by: the open session's site, and
 * whom to tell when its route is refused. [onRefused] is called on the proxy's
 * own threads.
 */
class ProxyBinding(val config: SiteConfig, val onRefused: (RouteFailure) -> Unit)

/**
 * Which credential belongs to which profile, and which profiles have an open
 * session. A profile's credential is made the first time it is asked for and
 * then kept for the process: Chromium caches it in memory and neither a lock
 * nor a wipe clears that cache (findings, "Is the auth cache cleared"). A
 * wiped saved site gets a fresh profile id, and so a fresh credential.
 *
 * Main thread: [credentialFor], [bind], [unbind]. Proxy threads: [lookup].
 */
class SiteCredentials(private val random: SecureRandom = SecureRandom()) {
    private val byProfile = HashMap<String, ProxyCredential>()
    private val bindings = HashMap<String, ProxyBinding>()

    @Synchronized fun credentialFor(profileId: String): ProxyCredential =
        byProfile.getOrPut(profileId) { ProxyCredential(randomHex(), randomHex()) }

    /** The site's session is open: its credential now routes by [binding]. A later bind replaces it. */
    @Synchronized fun bind(profileId: String, binding: ProxyBinding) {
        credentialFor(profileId)
        bindings[profileId] = binding
    }

    /** The site's session is closed: its credential finds nothing until the next [bind]. */
    @Synchronized fun unbind(profileId: String) {
        bindings.remove(profileId)
    }

    /**
     * The open session [user] and [password] belong to, or null. Every open
     * session is compared, in constant time, and the loop never stops early, so
     * how long a lookup takes says nothing about which bytes matched.
     */
    @Synchronized fun lookup(user: String, password: String): ProxyBinding? {
        val offered = "$user:$password".toByteArray(Charsets.UTF_8)
        var found: ProxyBinding? = null
        for ((profileId, binding) in bindings) {
            val credential = byProfile.getValue(profileId)
            val expected = "${credential.user}:${credential.password}".toByteArray(Charsets.UTF_8)
            if (MessageDigest.isEqual(offered, expected)) found = binding
        }
        return found
    }

    /** 128 bits, as 32 lowercase hex digits: never a colon, so `user:password` is unambiguous. */
    private fun randomHex(): String =
        ByteArray(16).also(random::nextBytes).joinToString("") { "%02x".format(it) }
}

/**
 * The answer a view gives an HTTP auth challenge, or null to leave it to
 * WebView's default, which cancels it. Only the loopback proxy's own challenge
 * is answered, and every time it arrives: the spike saw five parallel requests
 * make five separate calls, and an unanswered one waits for ever. A site's own
 * HTTP auth is left alone, as today.
 */
internal fun proxyAuthAnswer(host: String?, realm: String?, credential: () -> ProxyCredential): ProxyCredential? =
    if (host == LOOPBACK_HOST && realm == PROXY_REALM) credential() else null
```

- [x] **Step 4: Run the test and confirm it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.SiteCredentialsTest"`
Expected: PASS, 11 tests.

- [x] **Step 5: Run the full gates**

Run every command in "Before Task 1: baseline". Expected:
- JVM tests: baseline + 11, with no failures in the XML;
- zero `e:` lines;
- analyze clean;
- `flutter test` unchanged.

- [x] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/SiteCredentials.kt android/app/src/test/kotlin/com/mono/container/engine/SiteCredentialsTest.kt
git commit -m "feat: per-profile loopback proxy credentials, valid while the site is open"
```

---

### Task 2: Reading and deciding a proxy request

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/LoopbackRequest.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/LoopbackRequestTest.kt`

**Interfaces:**
- Consumes (Task 1): `ProxyBinding`, `LOOPBACK_HOST`, `PROXY_REALM`. Also the existing `ProxyTunnelException`.
- Produces:
  - `internal const val AUTOFILL_QUERY_HOST = "content-autofill.googleapis.com"`
  - `internal const val MAX_HEAD_BYTES = 64 * 1024`
  - `internal fun readHead(input: InputStream, limit: Int = MAX_HEAD_BYTES): List<String>?`
  - `internal data class ProxyRequest(method, host, port, path: String?, version, headers: List<Pair<String, String>>)`, with `header(name)`
  - `internal fun parseRequest(lines: List<String>): ProxyRequest?`
  - `internal fun parseAuthority(authority: String): Pair<String, Int>?`
  - `internal fun basicCredentials(value: String): Pair<String, String>?`
  - `internal sealed class ProxyDecision`, with three cases:
    - `Reply(status: Int)`
    - `Tunnel(host, port, binding)`
    - `Forward(host, port, head: String, bodyLength: Long, binding)`
  - `internal fun decide(request: ProxyRequest?, lookup: (String, String) -> ProxyBinding?): ProxyDecision`
  - `internal fun originFormHead(request: ProxyRequest): String`
  - `internal fun closingResponseHead(lines: List<String>): String`
  - `internal fun statusResponse(status: Int): ByteArray`
  - `internal val CONNECTION_ESTABLISHED: ByteArray`
  - `internal fun upstreamFailureStatus(error: Throwable): Int`

- [x] **Step 1: Write the failing test**

```kotlin
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
```

- [x] **Step 2: Run the test and confirm it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.LoopbackRequestTest"`
Expected: a compilation failure, with `Unresolved reference: readHead` / `decide`.

- [x] **Step 3: Write the implementation**

```kotlin
package com.mono.container.engine

import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.net.SocketTimeoutException
import java.net.URI
import java.util.Base64

/**
 * Chromium's Autofill server-prediction host (`kDefaultAutofillServerURL`).
 * WebView queries it for every form, from the browser process, carrying the
 * profile's credential once the site has authenticated (findings, table
 * (B)). There can be only one proxy override per process, so the loopback
 * proxy refuses this host itself. It replaces `AutofillBlock.kt`.
 */
internal const val AUTOFILL_QUERY_HOST = "content-autofill.googleapis.com"

/** A request head larger than this is refused. Chromium's own are a few KB. */
internal const val MAX_HEAD_BYTES = 64 * 1024

/**
 * The lines of one HTTP head, up to its blank line, or null when the stream
 * ends first or the head passes [limit]. [input] is left at the first byte
 * after the head, so a body or tunnel payload can be read from it next. Bytes
 * are read as ISO-8859-1, so writing a line back reproduces it exactly.
 */
internal fun readHead(input: InputStream, limit: Int = MAX_HEAD_BYTES): List<String>? {
    val lines = mutableListOf<String>()
    val line = ByteArrayOutputStream()
    var total = 0
    while (true) {
        val byte = input.read()
        if (byte == -1 || ++total > limit) return null
        if (byte != '\n'.code) {
            line.write(byte)
            continue
        }
        val text = String(line.toByteArray(), Charsets.ISO_8859_1).removeSuffix("\r")
        line.reset()
        if (text.isNotEmpty()) lines += text
        else if (lines.isNotEmpty()) return lines
        // A blank line before the request line is ignored (RFC 9112 §2.2).
    }
}

/** One request to the loopback proxy. [path] is the origin-form path and query, or null for `CONNECT`. */
internal data class ProxyRequest(
    val method: String,
    val host: String,
    val port: Int,
    val path: String?,
    val version: String,
    val headers: List<Pair<String, String>>,
) {
    fun header(name: String): String? = headers.firstOrNull { it.first.equals(name, ignoreCase = true) }?.second
}

/**
 * Parses the two request shapes Chromium sends to an http proxy: `CONNECT
 * host:port` and an absolute-form `http://` request. Anything else is null.
 */
internal fun parseRequest(lines: List<String>): ProxyRequest? {
    val parts = lines.firstOrNull()?.split(' ') ?: return null
    if (parts.size != 3) return null
    val (method, target, version) = parts
    if (version != "HTTP/1.1" && version != "HTTP/1.0") return null
    val headers = lines.drop(1).map { line ->
        val colon = line.indexOf(':')
        if (colon <= 0) return null
        line.substring(0, colon).trim() to line.substring(colon + 1).trim()
    }
    if (method == "CONNECT") {
        val (host, port) = parseAuthority(target) ?: return null
        return ProxyRequest(method, host, port, null, version, headers)
    }
    val uri = runCatching { URI(target) }.getOrNull() ?: return null
    if (!uri.scheme.equals("http", ignoreCase = true)) return null
    val host = uri.host?.removeSurrounding("[", "]")?.ifEmpty { null } ?: return null
    val port = if (uri.port == -1) 80 else uri.port
    val path = (uri.rawPath?.ifEmpty { null } ?: "/") + (uri.rawQuery?.let { "?$it" } ?: "")
    return ProxyRequest(method, host, port, path, version, headers)
}

/** `host:port` or `[v6]:port`, with the port in 1..65535; otherwise null. */
internal fun parseAuthority(authority: String): Pair<String, Int>? {
    val host: String
    val portText: String
    if (authority.startsWith("[")) {
        val close = authority.indexOf(']')
        if (close < 0 || authority.getOrNull(close + 1) != ':') return null
        host = authority.substring(1, close)
        portText = authority.substring(close + 2)
    } else {
        val colon = authority.indexOf(':')
        if (colon <= 0 || authority.lastIndexOf(':') != colon) return null
        host = authority.substring(0, colon)
        portText = authority.substring(colon + 1)
    }
    if (host.isEmpty()) return null
    val port = portText.toIntOrNull()?.takeIf { it in 1..65535 } ?: return null
    return host to port
}

/** A `Proxy-Authorization: Basic` value's user and password, or null for anything else. */
internal fun basicCredentials(value: String): Pair<String, String>? {
    val parts = value.trim().split(Regex("\\s+"), limit = 2)
    if (parts.size != 2 || !parts[0].equals("Basic", ignoreCase = true)) return null
    val decoded = runCatching { String(Base64.getDecoder().decode(parts[1]), Charsets.UTF_8) }.getOrNull() ?: return null
    val colon = decoded.indexOf(':')
    if (colon < 0) return null
    return decoded.substring(0, colon) to decoded.substring(colon + 1)
}

/** What the loopback proxy does with one request. */
internal sealed class ProxyDecision {
    /** Answer [status] and close; nothing is forwarded. */
    data class Reply(val status: Int) : ProxyDecision()

    /** `200`, then relay bytes both ways to [host]:[port] on [binding]'s route. */
    class Tunnel(val host: String, val port: Int, val binding: ProxyBinding) : ProxyDecision()

    /** Send [head] and [bodyLength] body bytes to [host]:[port], relay the response, close. */
    class Forward(val host: String, val port: Int, val head: String, val bodyLength: Long, val binding: ProxyBinding) : ProxyDecision()
}

/**
 * P2 spec §1.1 and §2. The order matters:
 * 1. what the proxy never forwards, whatever the credentials — the Autofill
 *    host, and a destination named [LOOPBACK_HOST], which only the proxy
 *    itself may challenge as;
 * 2. no credentials: `407`, so the site's view answers with its own;
 * 3. credentials that find no open session: `403`, never a second `407`.
 */
internal fun decide(request: ProxyRequest?, lookup: (String, String) -> ProxyBinding?): ProxyDecision {
    if (request == null) return ProxyDecision.Reply(400)
    val host = request.host.trimEnd('.')
    if (host.equals(AUTOFILL_QUERY_HOST, ignoreCase = true) || host == LOOPBACK_HOST) return ProxyDecision.Reply(403)

    val authorization = request.header("Proxy-Authorization") ?: return ProxyDecision.Reply(407)
    val (user, password) = basicCredentials(authorization) ?: return ProxyDecision.Reply(403)
    val binding = lookup(user, password) ?: return ProxyDecision.Reply(403)

    if (request.path == null) return ProxyDecision.Tunnel(request.host, request.port, binding)

    if (request.header("Transfer-Encoding") != null) return ProxyDecision.Reply(411)
    val lengthHeader = request.header("Content-Length")
    val length = if (lengthHeader == null) 0L else lengthHeader.toLongOrNull()?.takeIf { it >= 0 } ?: return ProxyDecision.Reply(400)
    return ProxyDecision.Forward(request.host, request.port, originFormHead(request), length, binding)
}

/** Headers that belong to one hop, or to the loopback proxy alone. */
private val HOP_BY_HOP = setOf("proxy-authorization", "proxy-authenticate", "proxy-connection", "connection", "keep-alive")

/**
 * [request] as its origin server receives it: an origin-form request line,
 * none of [HOP_BY_HOP] — so the site's credential never leaves the device —
 * and `Connection: close`, so the connection carries this one request.
 */
internal fun originFormHead(request: ProxyRequest): String = buildString {
    append("${request.method} ${request.path} ${request.version}\r\n")
    for ((name, value) in request.headers) {
        if (name.lowercase() !in HOP_BY_HOP) append("$name: $value\r\n")
    }
    append("Connection: close\r\n\r\n")
}

/**
 * A relayed response head, with `Connection: close` in place of whatever
 * [HOP_BY_HOP] headers it had, so Chromium never reuses this connection for
 * another host. An origin's `Proxy-Authenticate` is dropped: only the proxy
 * challenges for the proxy.
 */
internal fun closingResponseHead(lines: List<String>): String = buildString {
    append(lines.first()).append("\r\n")
    for (line in lines.drop(1)) {
        if (line.substringBefore(':').trim().lowercase() !in HOP_BY_HOP) append(line).append("\r\n")
    }
    append("Connection: close\r\n\r\n")
}

/** The loopback proxy's own replies: empty, always closing, and only a `407` carries the challenge. */
internal fun statusResponse(status: Int): ByteArray {
    val reason = when (status) {
        400 -> "Bad Request"
        403 -> "Forbidden"
        407 -> "Proxy Authentication Required"
        411 -> "Length Required"
        502 -> "Bad Gateway"
        504 -> "Gateway Timeout"
        else -> "Error"
    }
    val challenge = if (status == 407) "Proxy-Authenticate: Basic realm=\"$PROXY_REALM\"\r\n" else ""
    return "HTTP/1.1 $status $reason\r\n${challenge}Content-Length: 0\r\nConnection: close\r\n\r\n"
        .toByteArray(Charsets.ISO_8859_1)
}

internal val CONNECTION_ESTABLISHED: ByteArray =
    "HTTP/1.1 200 Connection Established\r\n\r\n".toByteArray(Charsets.ISO_8859_1)

/**
 * The status a failed upstream connection is answered with (spec §3.3): `504`
 * for a timeout (`UPSTREAM_TIMEOUT`), and `502` for everything else — an
 * upstream proxy refusing the destination (`PROXY_REFUSED`), a destination
 * that cannot be reached. Not reported to the site: the proxy cannot tell a
 * main frame from a subresource (plan deviation 1).
 */
internal fun upstreamFailureStatus(error: Throwable): Int = if (error is SocketTimeoutException) 504 else 502
```

- [x] **Step 4: Run the test and confirm it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.LoopbackRequestTest"`
Expected: PASS, 22 tests.

- [x] **Step 5: Run the full gates**, as in the baseline. Expected: JVM tests = Task 1's total + 22; zero `e:` lines.

- [x] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/LoopbackRequest.kt android/app/src/test/kotlin/com/mono/container/engine/LoopbackRequestTest.kt
git commit -m "feat: parse and decide loopback proxy requests"
```

---

### Task 3: The loopback proxy

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/LoopbackProxy.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/LoopbackProxyTest.kt`

**Interfaces:**
- Consumes:
  - Task 1: `SiteCredentials.lookup`, `SiteCredentials.credentialFor`, `ProxyBinding`.
  - Task 2: everything under "Produces".
  - Existing: `Router.connect(route, host, port)`, `Router.resolve`, `SiteConfig.currentRoute()`, `ProxyTunnelException`.
- Produces: `class LoopbackProxy(credentials: SiteCredentials, resolve: (SiteConfig) -> Route = { it.currentRoute() }, connect: (Route, String, Int) -> Socket = Router::connect) : AutoCloseable`, with these members:
  - `start(): LoopbackProxy`
  - `val port: Int`
  - `val address: InetAddress`
  - `close()`

- [ ] **Step 1: Write the failing test**

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.DataInputStream
import java.net.ServerSocket
import java.net.Socket
import java.util.Base64
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Callable
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/**
 * P2 spec §7: the loopback proxy against fake upstream servers on localhost.
 * Destinations are `localhost`, not `127.0.0.1`, which the proxy refuses (plan
 * deviation 2).
 */
class LoopbackProxyTest {

    private fun config(profileId: String, mode: String = "direct", host: String? = null, port: Int? = null) = SiteConfig(
        siteId = "site-$profileId", profileId = profileId, url = "https://forum.example.com",
        proxyMode = mode, proxyHost = host, proxyPort = port,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    /** Routes every config as its own settings say, with the proxy taken as reachable. */
    private val bySettings: (SiteConfig) -> Route = { Router.resolve(it, proxyReachable = true) }

    private fun auth(credential: ProxyCredential) =
        "Proxy-Authorization: Basic " +
            Base64.getEncoder().encodeToString("${credential.user}:${credential.password}".toByteArray()) + "\r\n"

    private fun send(proxy: LoopbackProxy, head: String): Socket =
        Socket("127.0.0.1", proxy.port).apply {
            soTimeout = 5_000
            getOutputStream().write(head.toByteArray(Charsets.ISO_8859_1))
            getOutputStream().flush()
        }

    private fun responseHead(socket: Socket): List<String> = readHead(socket.getInputStream())!!

    private fun statusOf(socket: Socket): Int = responseHead(socket).first().split(' ')[1].toInt()

    private fun ping(socket: Socket, byte: Int = 'p'.code) {
        socket.getOutputStream().write(byte)
        socket.getOutputStream().flush()
        assertEquals(byte, socket.getInputStream().read())
    }

    /** Echoes every byte of every connection, counting connections and ends. */
    private class EchoServer : AutoCloseable {
        val server = ServerSocket(0)
        val accepted = AtomicInteger()
        val ended = CountDownLatch(1)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    while (true) {
                        val socket = server.accept()
                        accepted.incrementAndGet()
                        Thread {
                            runCatching {
                                socket.use {
                                    while (true) {
                                        val byte = socket.getInputStream().read()
                                        if (byte == -1) break
                                        socket.getOutputStream().write(byte)
                                        socket.getOutputStream().flush()
                                    }
                                }
                            }
                            ended.countDown()
                        }.apply { isDaemon = true }.start()
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    /** A SOCKS5 server that records `<address type> <host>:<port>` and reports success. */
    private class FakeSocks : AutoCloseable {
        val server = ServerSocket(0)
        val requests = ArrayBlockingQueue<String>(4)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    while (true) {
                        val client = server.accept()
                        runCatching {
                            val input = DataInputStream(client.getInputStream())
                            val out = client.getOutputStream()
                            input.readUnsignedByte()
                            repeat(input.readUnsignedByte()) { input.readUnsignedByte() }
                            out.write(byteArrayOf(5, 0)); out.flush()
                            input.readUnsignedByte(); input.readUnsignedByte(); input.readUnsignedByte()
                            val type = input.readUnsignedByte()
                            val host = when (type) {
                                3 -> String(ByteArray(input.readUnsignedByte()).also { input.readFully(it) }, Charsets.US_ASCII)
                                1 -> ByteArray(4).also { input.readFully(it) }.joinToString(".") { (it.toInt() and 0xff).toString() }
                                else -> "v6"
                            }
                            requests.offer("$type $host:${input.readUnsignedShort()}")
                            out.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0)); out.flush()
                            input.read()
                        }
                        runCatching { client.close() }
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    /** An HTTP proxy that records its request line, answers 200, and holds the tunnel. */
    private class FakeHttpProxy : AutoCloseable {
        val server = ServerSocket(0)
        val requestLines = ArrayBlockingQueue<String>(1)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    server.accept().use { client ->
                        requestLines.offer(readHead(client.getInputStream())!!.first())
                        client.getOutputStream().write("HTTP/1.1 200 Connection established\r\n\r\n".toByteArray())
                        client.getOutputStream().flush()
                        client.getInputStream().read()
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    /**
     * An origin server that records one request's head and body, answers
     * [response], then keeps its side open, as a server that ignores
     * `Connection: close` would, until the client goes.
     */
    private class FakeOrigin(private val response: String) : AutoCloseable {
        val server = ServerSocket(0)
        val heads = ArrayBlockingQueue<List<String>>(1)
        val bodies = ArrayBlockingQueue<String>(1)
        val port get() = server.localPort

        init {
            Thread {
                runCatching {
                    server.accept().use { socket ->
                        val input = socket.getInputStream()
                        val head = readHead(input)!!
                        val length = head.firstOrNull { it.startsWith("Content-Length:", ignoreCase = true) }
                            ?.substringAfter(':')?.trim()?.toInt() ?: 0
                        val body = ByteArray(length).also { DataInputStream(input).readFully(it) }
                        heads.offer(head)
                        bodies.offer(String(body, Charsets.ISO_8859_1))
                        socket.getOutputStream().write(response.toByteArray(Charsets.ISO_8859_1))
                        socket.getOutputStream().flush()
                        input.read()
                    }
                }
            }.apply { isDaemon = true }.start()
        }

        override fun close() = server.close()
    }

    @Test fun `the listener is bound to 127_0_0_1 only`() {
        LoopbackProxy(SiteCredentials(), bySettings).start().use { proxy ->
            assertEquals("127.0.0.1", proxy.address.hostAddress)
            assertTrue(proxy.port > 0)
        }
    }

    @Test fun `no credentials get a 407 with the app's realm, and nothing is forwarded`() {
        EchoServer().use { echo ->
            LoopbackProxy(SiteCredentials(), bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n\r\n").use { socket ->
                    val head = responseHead(socket)
                    assertEquals("HTTP/1.1 407 Proxy Authentication Required", head.first())
                    assertTrue("Proxy-Authenticate: Basic realm=\"container\"" in head)
                }
                assertEquals(0, echo.accepted.get())
            }
        }
    }

    @Test fun `a wrong credential gets 403 and the connection is closed`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        LoopbackProxy(credentials, bySettings).start().use { proxy ->
            val fake = Base64.getEncoder().encodeToString("${"0".repeat(32)}:${"0".repeat(32)}".toByteArray())
            send(proxy, "CONNECT localhost:443 HTTP/1.1\r\nProxy-Authorization: Basic $fake\r\n\r\n").use { socket ->
                assertEquals(403, statusOf(socket))
                assertEquals(-1, socket.getInputStream().read())
            }
        }
    }

    @Test fun `a closed session's credential gets 403`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        val credential = credentials.credentialFor("p1")
        credentials.unbind("p1")
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credential)}\r\n").use { socket ->
                    assertEquals(403, statusOf(socket))
                }
                assertEquals(0, echo.accepted.get())
            }
        }
    }

    @Test fun `the Autofill host is refused with valid credentials, and no route is asked for`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        var asked = false
        LoopbackProxy(credentials, resolve = { asked = true; Route.Direct }).start().use { proxy ->
            send(proxy, "CONNECT content-autofill.googleapis.com:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(403, statusOf(socket))
            }
        }
        assertFalse(asked)
    }

    /** Review Focus 3. */
    @Test fun `garbage gets 400 and nothing is forwarded`() {
        EchoServer().use { echo ->
            LoopbackProxy(SiteCredentials(), bySettings).start().use { proxy ->
                send(proxy, "HELLO\r\n\r\n").use { socket -> assertEquals(400, statusOf(socket)) }
                assertEquals(0, echo.accepted.get())
            }
        }
    }

    @Test fun `a direct site's CONNECT answers 200 and relays both ways`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals("HTTP/1.1 200 Connection Established", responseHead(socket).first())
                    ping(socket)
                }
            }
        }
    }

    @Test fun `closing the page's side ends the upstream side`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                val socket = send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n")
                assertEquals(200, statusOf(socket))
                ping(socket)
                socket.close()
                assertTrue(echo.ended.await(5, TimeUnit.SECONDS))
            }
        }
    }

    @Test fun `the upstream closing ends the page's side`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        ServerSocket(0).use { upstream ->
            Thread { runCatching { upstream.accept().close() } }.apply { isDaemon = true }.start()
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT localhost:${upstream.localPort} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                    assertEquals(-1, socket.getInputStream().read())
                }
            }
        }
    }

    @Test fun `each credential is routed by its own site`() {
        FakeSocks().use { socks ->
            EchoServer().use { echo ->
                val credentials = SiteCredentials()
                credentials.bind("direct", ProxyBinding(config("direct")) {})
                credentials.bind("socks", ProxyBinding(config("socks", mode = "socks5", host = "127.0.0.1", port = socks.port)) {})
                LoopbackProxy(credentials, bySettings).start().use { proxy ->
                    send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("socks"))}\r\n").use { socket ->
                        assertEquals(200, statusOf(socket))
                    }
                    // Address type 3: the SOCKS proxy got the hostname, and the device looked nothing up.
                    assertEquals("3 example.test:443", socks.requests.poll(5, TimeUnit.SECONDS))

                    send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("direct"))}\r\n").use { socket ->
                        assertEquals(200, statusOf(socket))
                        ping(socket)
                    }
                    assertEquals(1, echo.accepted.get())
                    assertNull(socks.requests.poll(200, TimeUnit.MILLISECONDS))
                }
            }
        }
    }

    @Test fun `an http proxy site is tunnelled with CONNECT to the target authority`() {
        FakeHttpProxy().use { upstream ->
            val credentials = SiteCredentials()
            credentials.bind("p1", ProxyBinding(config("p1", mode = "http", host = "127.0.0.1", port = upstream.port)) {})
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                    assertEquals(200, statusOf(socket))
                }
                assertEquals("CONNECT example.test:443 HTTP/1.1", upstream.requestLines.poll(5, TimeUnit.SECONDS))
            }
        }
    }

    @Test fun `a refused route answers 502 and tells the site`() {
        val reported = CopyOnWriteArrayList<RouteFailure>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1", mode = "socks5")) { reported += it })
        var connected = false
        LoopbackProxy(
            credentials,
            resolve = { Route.Refused(RouteFailure.PROXY_UNREACHABLE) },
            connect = { _, _, _ -> connected = true; Socket() },
        ).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(502, statusOf(socket))
            }
        }
        assertEquals(listOf(RouteFailure.PROXY_UNREACHABLE), reported)
        assertFalse(connected)
    }

    /** Plan deviation 1: a single connection's failure is answered, never reported. */
    @Test fun `an upstream that refuses the destination answers 502 and reports nothing`() {
        val reported = CopyOnWriteArrayList<RouteFailure>()
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1", mode = "http", host = "127.0.0.1", port = 1)) { reported += it })
        LoopbackProxy(credentials, bySettings, connect = { _, _, _ -> throw ProxyTunnelException(403, "refused") }).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(502, statusOf(socket))
            }
        }
        assertTrue(reported.isEmpty())
    }

    @Test fun `an upstream timeout answers 504`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        LoopbackProxy(credentials, bySettings, connect = { _, _, _ -> throw java.net.SocketTimeoutException("slow") }).start().use { proxy ->
            send(proxy, "CONNECT example.test:443 HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                assertEquals(504, statusOf(socket))
            }
        }
    }

    /** Review Focus 5: the credential never reaches the origin. */
    @Test fun `an http request is sent on in origin form, without the credential, and its response relayed`() {
        FakeOrigin("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: keep-alive\r\n\r\nok").use { origin ->
            val credentials = SiteCredentials()
            credentials.bind("p1", ProxyBinding(config("p1")) {})
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                send(
                    proxy,
                    "POST http://localhost:${origin.port}/form?x=1 HTTP/1.1\r\nHost: localhost:${origin.port}\r\n" +
                        auth(credentials.credentialFor("p1")) +
                        "Proxy-Connection: keep-alive\r\nContent-Length: 3\r\n\r\na=1",
                ).use { socket ->
                    val head = responseHead(socket)
                    assertEquals("HTTP/1.1 200 OK", head.first())
                    assertTrue("Connection: close" in head)
                    assertFalse("Connection: keep-alive" in head)
                    assertEquals("ok", String(ByteArray(2).also { DataInputStream(socket.getInputStream()).readFully(it) }))
                }
                val sent = origin.heads.poll(5, TimeUnit.SECONDS)!!
                assertEquals("POST /form?x=1 HTTP/1.1", sent.first())
                assertTrue("Connection: close" in sent)
                assertTrue(sent.none { it.startsWith("Proxy-", ignoreCase = true) })
                assertEquals("a=1", origin.bodies.poll(5, TimeUnit.SECONDS))
            }
        }
    }

    /** Review Focus 4. */
    @Test fun `many tunnels at once each relay their own bytes`() {
        val credentials = SiteCredentials()
        credentials.bind("p1", ProxyBinding(config("p1")) {})
        EchoServer().use { echo ->
            LoopbackProxy(credentials, bySettings).start().use { proxy ->
                val pool = Executors.newFixedThreadPool(20)
                val results = (1..20).map { byte ->
                    pool.submit(Callable {
                        send(proxy, "CONNECT localhost:${echo.port} HTTP/1.1\r\n${auth(credentials.credentialFor("p1"))}\r\n").use { socket ->
                            assertEquals(200, statusOf(socket))
                            socket.getOutputStream().write(byte)
                            socket.getOutputStream().flush()
                            socket.getInputStream().read()
                        }
                    })
                }
                results.forEachIndexed { index, result -> assertEquals(index + 1, result.get(10, TimeUnit.SECONDS)) }
                pool.shutdownNow()
            }
        }
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.LoopbackProxyTest"`
Expected: a compilation failure, with `Unresolved reference: LoopbackProxy`.

- [ ] **Step 3: Write the implementation**

```kotlin
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
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.LoopbackProxyTest"`
Expected: PASS, 16 tests. Then run the class twice more; it must pass all three times. A flaky relay test is a bug in the relay, not in the test.

- [ ] **Step 5: Run the full gates**, as in the baseline. Expected: JVM tests = Task 2's total + 16; zero `e:` lines. Nothing starts the proxy in the app yet.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/LoopbackProxy.kt android/app/src/test/kotlin/com/mono/container/engine/LoopbackProxyTest.kt
git commit -m "feat: loopback proxy that authenticates, routes by site and relays"
```

---

### Task 4: The `unsupported` failure in Dart

This task comes before the Kotlin side produces the new name, so that Dart can decode it on the first build where it can arrive.

**Files:**
- Modify: `lib/domain/models/route_decision.dart:7-13, 54-60`
- Modify: `lib/domain/models/route_failure_copy.dart:5-106`
- Modify: `lib/data/services/container_engine_channel.dart:28-35`
- Test: `test/domain/route_failure_copy_test.dart`, `test/data/container_engine_channel_test.dart`, `test/ui/features/in_page/proxy_unreachable_screen_test.dart`

**Interfaces:**
- Produces:
  - `RouteFailure.unsupported`;
  - the channel name `'unsupported'`, decoded to `RouteFailure.unsupported`. Task 5's Kotlin sends it.
  - `refusalMessage(RouteFailure.unsupported) == 'This phone cannot route sites through a proxy'`;
  - `proxyFailureDetail(RouteFailure.unsupported, …) == 'Update Android System WebView to open proxied sites.'`.

- [ ] **Step 1: Write the failing tests**

In `test/domain/route_failure_copy_test.dart`, change the loop test so it skips `unsupported` as well as `misconfigured`, and add a test:

```dart
  test('every failure with a tunnel names the site and ends on the same reassurance', () {
    for (final failure in RouteFailure.values) {
      if (failure == RouteFailure.misconfigured || failure == RouteFailure.unsupported) continue;
      final detail = proxyFailureDetail(failure, siteName: 'Forum', tunnelDescriptor: 'the tunnel');
      expect(detail, contains('Forum'));
      expect(detail, endsWith('The page was not loaded, so no request left your device.'));
    }
  });

  test('unsupported says what is wrong and what to do, in the approved words', () {
    // P2 spec §3.3, approved by the user on 2026-09-30.
    expect(proxyFailureHeadline(RouteFailure.unsupported), 'This phone cannot route sites through a proxy');
    expect(
      proxyFailureDetail(RouteFailure.unsupported, siteName: 'Forum', tunnelDescriptor: 'the tunnel'),
      'Update Android System WebView to open proxied sites.',
    );
  });
```

In `test/data/container_engine_channel_test.dart`, after "a refused session decodes its failure reason":

```dart
  test('a session refused for want of a proxy override decodes as unsupported', () {
    final event = <Object?, Object?>{
      'type': 'sessions',
      'sessions': [
        {
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{},
          'failure': 'unsupported',
        },
      ],
    };
    expect(sessionsFromEvent(event).single.failure, RouteFailure.unsupported);
  });
```

In `test/ui/features/in_page/proxy_unreachable_screen_test.dart`, after "a different failure headlines with its own refusal message":

```dart
  testWidgets('an unsupported WebView shows the approved headline and hint', (tester) async {
    await tester.pumpWidget(host(failure: RouteFailure.unsupported));
    expect(find.text('This phone cannot route sites through a proxy'), findsOneWidget);
    expect(find.text('Update Android System WebView to open proxied sites.'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/domain/route_failure_copy_test.dart test/data/container_engine_channel_test.dart test/ui/features/in_page/proxy_unreachable_screen_test.dart`
Expected: a compilation error: `Member not found: 'unsupported'`.

- [ ] **Step 3: Implement**

`lib/domain/models/route_decision.dart`: add the kind, and its message:

```dart
enum RouteFailure {
  proxyUnreachable,
  proxyRefused,
  upstreamTimeout,
  tlsFailure,
  misconfigured,

  /// This WebView cannot override its proxy, so a proxied site cannot be
  /// routed and is refused at open (P2 spec §3.3). Direct sites still open.
  unsupported,
}
```

```dart
String refusalMessage(RouteFailure failure) => switch (failure) {
      RouteFailure.proxyUnreachable => 'Cannot reach the proxy',
      RouteFailure.proxyRefused => 'The proxy refused the destination',
      RouteFailure.upstreamTimeout => 'The destination did not respond',
      RouteFailure.tlsFailure => 'The secure connection failed',
      RouteFailure.misconfigured => 'This site has no proxy configured',
      RouteFailure.unsupported => 'This phone cannot route sites through a proxy',
    };
```

`lib/domain/models/route_failure_copy.dart`:
- In `proxyFailureHeadline`'s doc comment, change "The other four kinds reuse Plan 3's `refusalMessage()`" to "The other kinds reuse Plan 3's `refusalMessage()`".
- In `proxyFailureDetail`, add a paragraph to the doc comment after the `misconfigured` paragraph, and the new branch:

```dart
/// [RouteFailure.unsupported] has its own sentence, approved with its headline
/// in the P2 spec (§3.3): nothing is wrong with the tunnel, so the generic
/// sentence would mislead, and the remedy is on the phone.
```

```dart
  if (failure == RouteFailure.misconfigured) return null;
  if (failure == RouteFailure.unsupported) {
    return 'Update Android System WebView to open proxied sites.';
  }
```

`lib/data/services/container_engine_channel.dart`, in `_failure`:

```dart
      'misconfigured' => RouteFailure.misconfigured,
      'unsupported' => RouteFailure.unsupported,
      _ => null,
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run the same `flutter test` command. Expected: PASS.

- [ ] **Step 5: Run the full gates**
  - `flutter analyze`: No issues found!
  - `flutter test`: baseline + 3.
  - The APK build: zero `e:` lines. No Kotlin changed, but the build is a gate every task keeps.

- [ ] **Step 6: Commit**

```bash
git add lib/domain/models/route_decision.dart lib/domain/models/route_failure_copy.dart lib/data/services/container_engine_channel.dart test/domain/route_failure_copy_test.dart test/data/container_engine_channel_test.dart test/ui/features/in_page/proxy_unreachable_screen_test.dart
git commit -m "feat: an unsupported failure for a WebView that cannot override its proxy"
```

---

### Task 5: Start the proxy and route every site through it

After this task all WebView traffic goes through the loopback proxy. A proxied site's page loads are still fetched by `RequestInterceptor.fetchThrough` until Task 6. Its preconnects, service workers and the Autofill query already go through the loopback proxy with the site's credential. That is a working intermediate state, and the first device check happens here.

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/LoopbackOverride.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/LoopbackOverrideTest.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/RouteFailureNameTest.kt`
- Delete: `android/app/src/main/kotlin/com/mono/container/engine/AutofillBlock.kt`, `android/app/src/test/kotlin/com/mono/container/engine/AutofillBlockTest.kt`
- Modify: `engine/Router.kt:3-5` and the end of the file, `engine/EngineChannel.kt` (constructor, `open`, `register`, `close`, `routeFailureToDartName`), `engine/RequestInterceptor.kt:27-49`, `engine/ContainerView.kt:12-28, 62`, `engine/ContainerViewFactory.kt:239-244`, `MainActivity.kt:10, 47-50`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt` (3 tests added)

**Interfaces:**
- Consumes: Tasks 1–3. Task 4's Dart name `unsupported`.
- Produces:
  - `RouteFailure.UNSUPPORTED`
  - `fun routeAtOpen(config: SiteConfig, proxyOverride: Boolean, resolve: () -> Route): Route`
  - `internal fun loopbackProxyConfig(port: Int): ProxyConfig`
  - `internal object Loopback`, with `val credentials: SiteCredentials` and `fun start(): Boolean`
  - `EngineChannel(context, profiles, throwaways, credentials: SiteCredentials, proxyOverride: Boolean)`, with `val credentials`
  - `RequestInterceptor.clientFor(config, proxyCredential: () -> ProxyCredential, onLoaded, lengths, page, closing)`
  - `ContainerView(…, credentials: SiteCredentials, …)`

- [ ] **Step 1: Write the failing tests**

`LoopbackOverrideTest.kt`:

```kotlin
package com.mono.container.engine

import androidx.webkit.ProxyConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P2 spec §1.3: one process-wide override sends every scheme of every site to
 * the loopback proxy, localhost included, with nothing to fall back to.
 */
class LoopbackOverrideTest {

    private val config = loopbackProxyConfig(4321)

    @Test fun `every scheme goes to the loopback proxy`() {
        assertEquals(listOf("http://127.0.0.1:4321"), config.proxyRules.map { it.url })
        assertEquals(listOf(ProxyConfig.MATCH_ALL_SCHEMES), config.proxyRules.map { it.schemeFilter })
    }

    /** `<-loopback>` is how Chromium spells "no implicit rules": localhost is not bypassed. */
    @Test fun `localhost and loopback addresses go through it too`() {
        assertEquals(listOf("<-loopback>"), config.bypassRules)
        assertFalse(config.isReverseBypassEnabled)
    }

    /** A DIRECT rule would let Chromium go direct once the loopback proxy fails. */
    @Test fun `there is no direct fallback`() {
        assertTrue(config.proxyRules.none { it.url.startsWith("direct", ignoreCase = true) })
    }
}
```

`RouteFailureNameTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/** `routeFailureToDartName` falls back to `misconfigured`, so a kind it forgets is silently mislabelled. */
class RouteFailureNameTest {
    @Test fun `every failure crosses the channel under its own Dart name`() {
        assertEquals(
            mapOf(
                "PROXY_UNREACHABLE" to "proxyUnreachable",
                "PROXY_REFUSED" to "proxyRefused",
                "UPSTREAM_TIMEOUT" to "upstreamTimeout",
                "TLS_FAILURE" to "tlsFailure",
                "MISCONFIGURED" to "misconfigured",
                "UNSUPPORTED" to "unsupported",
            ),
            RouteFailure.values().associate { it.name to routeFailureToDartName(it.name) },
        )
    }
}
```

Add to `RouterTest.kt`, which needs `import org.junit.Assert.assertFalse`:

```kotlin
    @Test fun `a direct site opens without a proxy override`() {
        assertEquals(Route.Direct, routeAtOpen(config(mode = "direct"), proxyOverride = false) { Route.Direct })
    }

    /** P2 spec §1.4: refused, never sent direct, and not even probed. */
    @Test fun `a proxied site is refused when WebView cannot override its proxy`() {
        for (mode in listOf("socks5", "http")) {
            var probed = false
            val route = routeAtOpen(config(mode = mode), proxyOverride = false) { probed = true; Route.Direct }
            assertEquals(Route.Refused(RouteFailure.UNSUPPORTED), route)
            assertFalse(probed)
        }
    }

    @Test fun `with the override a proxied site is resolved as before`() {
        val proxied = Route.Proxy("127.0.0.1", 9050, socks = true)
        assertEquals(proxied, routeAtOpen(config(), proxyOverride = true) { proxied })
    }
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.LoopbackOverrideTest" --tests "com.mono.container.engine.RouteFailureNameTest" --tests "com.mono.container.engine.RouterTest"`
Expected: a compilation failure, with `Unresolved reference: loopbackProxyConfig` / `UNSUPPORTED` / `routeAtOpen`.

- [ ] **Step 3: Router**

In `Router.kt`:

```kotlin
enum class RouteFailure {
    PROXY_UNREACHABLE, PROXY_REFUSED, UPSTREAM_TIMEOUT, TLS_FAILURE, MISCONFIGURED,
    /** This WebView cannot override its proxy, so a proxied site cannot be routed (P2 spec §3.3). */
    UNSUPPORTED,
}
```

Append at the end of the file:

```kotlin
/**
 * The route `open` decides (P2 spec §1.4). Every site's traffic reaches its
 * route through the loopback proxy, which needs WebView's proxy override.
 * Without it a proxied site is refused, never sent direct, and [resolve] —
 * which probes — is not called. A direct site opens as it always has.
 */
fun routeAtOpen(config: SiteConfig, proxyOverride: Boolean, resolve: () -> Route): Route =
    if (config.proxyMode != "direct" && !proxyOverride) Route.Refused(RouteFailure.UNSUPPORTED) else resolve()
```

- [ ] **Step 4: The override and the process singleton**

Create `LoopbackOverride.kt`:

```kotlin
package com.mono.container.engine

import androidx.webkit.ProxyConfig
import androidx.webkit.ProxyController
import androidx.webkit.WebViewFeature

/**
 * P2 spec §1.3: every scheme to the loopback proxy, implicit rules removed so
 * `localhost` and loopback addresses go through it too, and no `DIRECT` rule,
 * so if the proxy is down every request fails. Nothing falls back to direct.
 */
internal fun loopbackProxyConfig(port: Int): ProxyConfig =
    ProxyConfig.Builder()
        .addProxyRule("http://$LOOPBACK_HOST:$port")
        .removeImplicitRules()
        .build()

/**
 * The process's one loopback proxy and credential table. There must never be
 * two: Chromium caches each profile's proxy credential for the life of the
 * process, so a second table would issue credentials that cache never sends,
 * and there is one proxy override per process anyway.
 */
internal object Loopback {
    val credentials = SiteCredentials()

    private var installed: Boolean? = null

    /**
     * Starts the proxy and installs the override, once. True when WebView's
     * traffic now goes through it. When it cannot, proxied sites are refused
     * at open (`UNSUPPORTED`) and direct sites load as before. Autofill's
     * query then cannot be blocked either, and that is logged rather than
     * hidden.
     */
    @Synchronized fun start(): Boolean {
        installed?.let { return it }
        return install().also { installed = it }
    }

    private fun install(): Boolean {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.PROXY_OVERRIDE)) {
            android.util.Log.w("ContainerEngine", "WebView cannot override its proxy: proxied sites are refused, and Autofill queries are not blocked")
            return false
        }
        val proxy = runCatching { LoopbackProxy(credentials).start() }.getOrElse {
            android.util.Log.w("ContainerEngine", "The loopback proxy could not start: proxied sites are refused", it)
            return false
        }
        ProxyController.getInstance().setProxyOverride(loopbackProxyConfig(proxy.port), { it.run() }, {})
        return true
    }
}
```

Delete `AutofillBlock.kt` and `AutofillBlockTest.kt`: `git rm android/app/src/main/kotlin/com/mono/container/engine/AutofillBlock.kt android/app/src/test/kotlin/com/mono/container/engine/AutofillBlockTest.kt`.

- [ ] **Step 5: Answer the proxy's challenge**

In `RequestInterceptor.kt`, add `import android.webkit.HttpAuthHandler`. Then give `clientFor` a `proxyCredential` parameter and override `onReceivedHttpAuthRequest`:

```kotlin
    /** [proxyCredential] answers the loopback proxy's `407` (P2 spec §1.4): every
     *  call, at once, from memory. [lengths] records each proxied response's
     *  declared length, for the view's held-download sheet. [page] hears the
     *  page starting, finishing and moving through history (browser-chrome spec
     *  §3.1). [closing] is this one view's: once it is true, every request is
     *  refused (see [dispositionFor]). It is per view, not per interceptor,
     *  because a session — and its interceptor — outlives the views that show it. */
    fun clientFor(
        config: SiteConfig,
        proxyCredential: () -> ProxyCredential,
        onLoaded: () -> Unit = {},
        lengths: DeclaredLengths? = null,
        page: PageCallbacks = PageCallbacks.NONE,
        closing: () -> Boolean = { false },
    ): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
            intercept(config, request, lengths, closing())

        override fun onReceivedHttpAuthRequest(view: WebView, handler: HttpAuthHandler, host: String?, realm: String?) {
            val answer = proxyAuthAnswer(host, realm, proxyCredential)
            if (answer != null) handler.proceed(answer.user, answer.password)
            else super.onReceivedHttpAuthRequest(view, handler, host, realm)
        }
```

The rest of the object (`onPageStarted`, `onPageFinished`, `doUpdateVisitedHistory`) is unchanged.

In `ContainerView.kt`, add a constructor parameter after `throwaways`:

```kotlin
    /** Answers the loopback proxy's challenge with this profile's credential (P2 spec §2). */
    private val credentials: SiteCredentials,
```

Then change the `clientFor` call in `init` to:

```kotlin
        webView.webViewClient = interceptor.clientFor(config, { credentials.credentialFor(config.profileId) }, live, declaredLengths, closing = { closing.get() }, page = object : PageCallbacks {
```

The `PageCallbacks` body that follows is unchanged.

In `ContainerViewFactory.kt`, pass the table. Also split the line that has two arguments on it:

```kotlin
        val view = ContainerView(
            context = context,
            config = session.config,
            profiles = profiles,
            interceptor = session.interceptor,
            session = session,
            throwaways = engine.throwaways,
            credentials = engine.credentials,
```

- [ ] **Step 6: Bind credentials to open sessions**

In `EngineChannel.kt`:

Constructor:

```kotlin
class EngineChannel(
    private val context: Context,
    private val profiles: ProfileManager,
    /** Throwaways whose profile may still be on disk; see [ThrowawayJournal]. */
    val throwaways: ThrowawayJournal,
    /** Which credential routes which open site through the loopback proxy (P2 spec §2). */
    val credentials: SiteCredentials,
    /** Whether WebView's traffic goes through the loopback proxy at all (P2 spec §1.3). */
    private val proxyOverride: Boolean,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
```

In `open`, the probe line becomes:

```kotlin
            val route = runCatching { routeAtOpen(config, proxyOverride) { config.currentRoute() } }
```

In `register`, replace the start of the function and the `else` branch:

```kotlin
    private fun register(config: SiteConfig, route: Route?, initialUrl: String?): Map<String, Any?> {
        val session = Session(config, initialUrl)
        session.onTunnelDropped = { failure -> onTunnelDropped(config.siteId, failure) }
        // A reopen normally follows a close. If one arrives on a different
        // profile without it, the old profile's credential must stop routing.
        sessions[config.siteId]?.config?.profileId
            ?.takeIf { it != config.profileId }
            ?.let(credentials::unbind)
        sessions[config.siteId] = session
```

```kotlin
            else -> {
                // Creates the profile now so the view can attach it before its
                // first load, and so a wipe has something to delete.
                profiles.profileFor(config.profileId)
                // From here until close, the loopback proxy routes this
                // profile's requests on this config. Its reports arrive on the
                // proxy's threads; the session map and the event sink are the
                // main thread's.
                credentials.bind(config.profileId, ProxyBinding(config) { failure ->
                    mainHandler.post { onTunnelDropped(config.siteId, failure) }
                })
                session.lastActiveAtMs = System.currentTimeMillis()
            }
```

In `close`:

```kotlin
    private fun close(siteId: String) {
        pendingOpens.cancel(siteId)
        val session = sessions.remove(siteId) ?: return
        // Chromium keeps sending this profile's credential; the proxy now answers 403.
        credentials.unbind(session.config.profileId)
        // Flutter disposes the platform view when its AndroidView leaves the
        // tree, but `close` can also arrive from `2c` while the view is
        // detached — ContainerView.dispose is idempotent for that reason.
        session.view?.dispose()
        emitSessions()
    }
```

In `routeFailureToDartName`:

```kotlin
    "TLS_FAILURE" -> "tlsFailure"
    "UNSUPPORTED" -> "unsupported"
    else -> "misconfigured"
```

- [ ] **Step 7: Start it in `MainActivity`**

Replace the `blockAutofillQueries` import with `import com.mono.container.engine.Loopback`. Then replace:

```kotlin
        // Before any page can load, like the sweeps above.
        blockAutofillQueries()
        val engine = EngineChannel(applicationContext, profiles, throwaways)
```

with:

```kotlin
        // Before any page can load, like the sweeps above: from here every
        // site's traffic goes through the loopback proxy (P2 spec §1).
        val proxyOverride = Loopback.start()
        val engine = EngineChannel(applicationContext, profiles, throwaways, Loopback.credentials, proxyOverride)
```

- [ ] **Step 8: Run the tests and confirm they pass**

Run: `./gradlew :app:testDebugUnitTest`
Expected, all read from the XML:
- the total is Task 3's total + 3 (`LoopbackOverrideTest`) + 1 (`RouteFailureNameTest`) + 3 (`RouterTest`) − 3 (`AutofillBlockTest` deleted);
- no failures.

- [ ] **Step 9: Run the full gates**
  - `flutter build apk --debug` with zero `e:` lines;
  - `flutter analyze` clean;
  - `flutter test` unchanged since Task 4.

- [ ] **Step 10: Early device check (spec §7). The first build that has a running proxy.**

  **Scratch logging patch.** Never commit it. In `LoopbackProxy.handle`, after `decide`, add:

  ```kotlin
  android.util.Log.d("P2", "${request?.method} ${request?.host}:${request?.port} -> ${decision::class.simpleName} ${(decision as? ProxyDecision.Reply)?.status}")
  ```

  This needs the parsed request held in a local `request` variable. It logs no credential. Also add a scratch `mainHandler.postDelayed({ credentials.unbind(config.profileId) }, 10_000)` at the end of `register`'s success branch.

  **Build and open a site.** Install on the Pixel_9 AVD (device PIN 1111, vault PIN 135790), then run `adb logcat -s P2`. Open a saved **direct** site, `https://example.com`.

  **What must be seen:**
  1. The first `CONNECT example.com:443` gets `Reply 407`. The next one is a `Tunnel`, and the page loads.
  2. Reload after the scratch unbind has run (10 s):
     - the request gets `Reply 403`;
     - the page shows WebView's error page;
     - the log shows **no stream of repeated 407s or 403s**, only a small bounded number. Chromium may retry a few times.

     Record the count. A loop here stops the plan: report it to the coordinating session before going on.
  3. Open a form page, for example `https://httpbin.org/forms/post`, in a direct site. Any `CONNECT content-autofill.googleapis.com:443` gets `Reply 403`, a bounded number of times.
  4. A saved **SOCKS5** site (local proxy at `10.0.2.2:1080`) still loads. Its page loads are still fetched by the interceptor, and its preconnects now reach the SOCKS5 proxy by hostname.

  Then **revert the scratch patch.** `git diff` must show none of it.

- [ ] **Step 11: Commit**

```bash
git add -A android/app/src/main/kotlin android/app/src/test/kotlin
git status --short   # only the files this task names
git commit -m "feat: route every site through the loopback proxy, refusing proxied sites without an override"
```

---

### Task 6: Chromium fetches every page; the interceptor keeps two jobs

**Files:**
- Modify: `engine/Teardown.kt:3-30`
- Modify: `engine/RequestInterceptor.kt` (whole file below)
- Modify: `engine/DownloadSize.kt` (whole file below)
- Modify: `engine/ContainerView.kt:39, 62, 87-90`
- Modify: `engine/ProxyHttpClient.kt:50-51`
- Delete: `android/app/src/test/kotlin/com/mono/container/engine/RequestInterceptorMediaTypeTest.kt`
- Test: `DispositionTest.kt` (rewritten), `DownloadSizeTest.kt` (rewritten), `MainFrameFailureTest.kt` (new), `ProxyHttpClientTest.kt` (one assertion removed)

**Interfaces:**
- Consumes: Task 5's `clientFor(config, proxyCredential, …)`. Existing: `FilterEngine.matches`, `Session.onTunnelDropped`.
- Produces:
  - `internal fun dispositionFor(closing: Boolean, blockedByFilter: () -> Boolean): Disposition`, with the cases `Closed`, `Blocked` and `ByWebView`
  - `internal fun mainFrameFailure(errorCode: Int): RouteFailure?`
  - `internal fun heldDownloadSize(listenerLength: Long): Long?`
  - `RequestInterceptor.clientFor(config, proxyCredential, onLoaded, page, closing)`, whose `lengths` parameter is gone

- [ ] **Step 1: Write the failing tests**

Replace `DispositionTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * What the interceptor does with one request, decided before any Android type
 * is built. Since P2 (spec §1.4) Chromium fetches everything else itself,
 * through the loopback proxy, which routes it by site.
 */
class DispositionTest {

    /**
     * Found on a device: a page's pagehide `sendBeacon` and keepalive `fetch`
     * went direct when its WebView was destroyed. A closing view refuses
     * everything, so nothing from a closing page reaches even the loopback
     * proxy, and decides that without consulting the filter list.
     */
    @Test fun `a closing view refuses every request without consulting the filter list`() {
        var asked = false
        assertEquals(Disposition.Closed, dispositionFor(closing = true, blockedByFilter = { asked = true; true }))
        assertEquals(false, asked)
    }

    @Test fun `an open view blocks what a filter list matches`() {
        assertEquals(Disposition.Blocked, dispositionFor(closing = false, blockedByFilter = { true }))
    }

    @Test fun `everything else is Chromium's to fetch, through the loopback proxy`() {
        assertEquals(Disposition.ByWebView, dispositionFor(closing = false, blockedByFilter = { false }))
    }
}
```

Replace `DownloadSizeTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The held-download sheet showed "0 B" for a 190 KB PDF on the emulator.
 * Chromium reports an unknown length as 0. Since P2 Chromium fetches every
 * site's pages itself, so that is the only rule, on every route.
 */
class DownloadSizeTest {

    @Test fun `zero is unknown, not empty`() {
        assertNull(heldDownloadSize(0))
    }

    @Test fun `a real length is shown`() {
        assertEquals(194_560L, heldDownloadSize(194_560))
    }
}
```

Create `MainFrameFailureTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** P2 spec §3.3: Chromium does the TLS now, so a failed handshake reaches us as a WebView error code. */
class MainFrameFailureTest {

    @Test fun `a failed TLS handshake is a TLS failure`() {
        assertEquals(RouteFailure.TLS_FAILURE, mainFrameFailure(-11)) // WebViewClient.ERROR_FAILED_SSL_HANDSHAKE
    }

    @Test fun `every other error is left to WebView's own error page`() {
        for (code in listOf(-1, -2, -5, -6, -8, -12)) { // UNKNOWN, HOST_LOOKUP, PROXY_AUTHENTICATION, CONNECT, TIMEOUT, BAD_URL
            assertNull(mainFrameFailure(code))
        }
    }
}
```

In `ProxyHttpClientTest.kt`, in "a chunked body is handed on decoded, with no declared length":
- delete the line `assertEquals(null, declaredLength(response.headers))`;
- in its doc comment, change "so it is dropped; `declaredLength` still reads no length, as before." to "so it is dropped."

Delete `RequestInterceptorMediaTypeTest.kt`: `git rm android/app/src/test/kotlin/com/mono/container/engine/RequestInterceptorMediaTypeTest.kt`.

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.DispositionTest" --tests "com.mono.container.engine.DownloadSizeTest" --tests "com.mono.container.engine.MainFrameFailureTest"`
Expected: a compilation failure. `dispositionFor` has no overload without `route`, `heldDownloadSize` wants three arguments, and `mainFrameFailure` is unresolved.

- [ ] **Step 3: `Teardown.kt`**

Replace lines 3–30 (the `Disposition` class and `dispositionFor`):

```kotlin
/** What [RequestInterceptor] does with one request, decided before any Android type is built. */
internal sealed class Disposition {
    /** The view is closing: refused, and reported to no one. */
    object Closed : Disposition()
    /** A filter list matched: an empty 204. */
    object Blocked : Disposition()
    /** Chromium fetches it, through the loopback proxy, on the site's route (P2 spec §1.4). */
    object ByWebView : Disposition()
}

/**
 * [closing] is checked first and alone. A view is closing from the moment it
 * is disposed until WebView is destroyed, and what a page sends then — its
 * pagehide beacons, keepalive fetches — is refused outright: never routed,
 * never direct, and never even handed to the loopback proxy (user's ruling,
 * 2026-09-30).
 */
internal fun dispositionFor(closing: Boolean, blockedByFilter: () -> Boolean): Disposition {
    if (closing) return Disposition.Closed
    if (blockedByFilter()) return Disposition.Blocked
    return Disposition.ByWebView
}
```

- [ ] **Step 4: `RequestInterceptor.kt`: the whole file**

```kotlin
package com.mono.container.engine

import android.webkit.HttpAuthHandler
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.ByteArrayInputStream

/** The page events [ContainerView] builds its navigation state from. */
interface PageCallbacks {
    fun started(url: String) {}
    fun finished(url: String) {}
    fun visited(url: String) {}

    companion object {
        val NONE = object : PageCallbacks {}
    }
}

/**
 * A site's WebView hooks. Since P2 (spec §1.4) Chromium does every fetch
 * itself, through the loopback proxy, which routes it by the site's credential
 * — so proxied sites keep cookies, follow redirects and send POST bodies. What
 * is left here happens before a request reaches Chromium's network stack: a
 * closing view refuses everything, and a filter-list match is blocked.
 * [onRefused] hears a main frame's failure ([mainFrameFailure]).
 */
class RequestInterceptor(private val filters: FilterEngine, private val onRefused: (RouteFailure) -> Unit = {}) {
    /** [proxyCredential] answers the loopback proxy's `407` (P2 spec §1.4): every
     *  call, at once, from memory. [page] hears the page starting, finishing and
     *  moving through history (browser-chrome spec §3.1). [closing] is this one
     *  view's: once it is true, every request is refused (see [dispositionFor]).
     *  It is per view, not per interceptor, because a session — and its
     *  interceptor — outlives the views that show it. */
    fun clientFor(
        config: SiteConfig,
        proxyCredential: () -> ProxyCredential,
        onLoaded: () -> Unit = {},
        page: PageCallbacks = PageCallbacks.NONE,
        closing: () -> Boolean = { false },
    ): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(view: WebView, request: WebResourceRequest): WebResourceResponse? =
            intercept(config, request, closing())

        override fun onReceivedHttpAuthRequest(view: WebView, handler: HttpAuthHandler, host: String?, realm: String?) {
            val answer = proxyAuthAnswer(host, realm, proxyCredential)
            if (answer != null) handler.proceed(answer.user, answer.password)
            else super.onReceivedHttpAuthRequest(view, handler, host, realm)
        }

        /** A subresource's failure never takes over the screen (P2 spec §3.3). */
        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
            if (request.isForMainFrame && !closing()) mainFrameFailure(error.errorCode)?.let(onRefused)
        }

        override fun onPageStarted(view: WebView, url: String?, favicon: android.graphics.Bitmap?) {
            if (url != null) page.started(url)
        }

        override fun onPageFinished(view: WebView, url: String?) {
            onLoaded()
            if (url != null) page.finished(url)
        }

        override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
            if (url != null) page.visited(url)
        }
    }

    /** A service worker's requests for [config]'s site, gated like its pages. */
    fun serviceWorkerClient(config: SiteConfig): (WebResourceRequest) -> WebResourceResponse? = { request -> intercept(config, request) }

    private fun intercept(config: SiteConfig, request: WebResourceRequest, closing: Boolean = false): WebResourceResponse? =
        when (dispositionFor(closing, blockedByFilter = { config.blockTrackers && filters.matches(request.url.toString()) != null })) {
            Disposition.Closed -> closed()
            Disposition.Blocked -> blocked()
            Disposition.ByWebView -> null
        }

    companion object {
        /** For requests that belong to no site: refused, and reported to no one. */
        val refuseAll: (WebResourceRequest) -> WebResourceResponse? = { closed() }

        private fun closed() = WebResourceResponse(
            "text/plain", "utf-8", 523, "Refused", emptyMap(), ByteArrayInputStream(ByteArray(0))
        )
    }

    private fun blocked() = WebResourceResponse("text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0)))
}

/**
 * The failure a main frame's WebView error reports, or null. Chromium does the
 * TLS since P2 (spec §3.3), so a handshake that fails arrives as
 * `ERROR_FAILED_SSL_HANDSHAKE`. Every other code — the loopback proxy's `502`
 * and `504` included — is left to WebView's own error page. Certificate errors
 * never come here: they go to `onReceivedSslError`, whose default cancels.
 */
internal fun mainFrameFailure(errorCode: Int): RouteFailure? =
    if (errorCode == WebViewClient.ERROR_FAILED_SSL_HANDSHAKE) RouteFailure.TLS_FAILURE else null
```

- [ ] **Step 5: `DownloadSize.kt`: the whole file**

```kotlin
package com.mono.container.engine

/**
 * The size a held download's sheet shows, or null when nothing honest is
 * known, in which case the sheet leaves the size out.
 *
 * Chromium sets WebView's `contentLength` to `content_length > 0 ?
 * content_length : 0`, so 0 means unknown rather than empty. Since P2 Chromium
 * fetches every site's pages itself, proxied ones included (spec §1.4), so
 * this is the rule on every route.
 */
internal fun heldDownloadSize(listenerLength: Long): Long? = listenerLength.takeIf { it > 0 }
```

- [ ] **Step 6: `ContainerView.kt` and `ProxyHttpClient.kt`**

In `ContainerView.kt`:
- delete `private val declaredLengths = DeclaredLengths()` and the blank line after it;
- the `clientFor` call becomes `interceptor.clientFor(config, { credentials.credentialFor(config.profileId) }, live, closing = { closing.get() }, page = object : PageCallbacks {`;
- in the `DownloadListener`, replace the comment and the size line with:

```kotlin
            // Chromium fetched this on every route since P2, so its
            // contentLength means the same everywhere: 0 is unknown.
            val size = heldDownloadSize(contentLength)
```

In `ProxyHttpClient.kt`'s `bodyOf` doc comment, change:

```kotlin
     * `Transfer-Encoding` itself is kept whenever it was sent, so
     * [declaredLength] still reads no declared length for such a response.
```

to:

```kotlin
     * `Transfer-Encoding` itself is kept whenever it was sent.
```

- [ ] **Step 7: Confirm nothing else used the removed names**

Run: `grep -rn "fetchThrough\|DeclaredLengths\|declaredLength\|mediaTypeOf\|Disposition.Through\|Disposition.Refused\|blockAutofillQueries" android/app/src`
Expected: no output.

- [ ] **Step 8: Run the tests and confirm they pass**

Run: `./gradlew :app:testDebugUnitTest`
Expected, from the XML:
- the total is Task 5's total − 3 (`DispositionTest` 6→3) − 9 (`DownloadSizeTest` 11→2) − 4 (`RequestInterceptorMediaTypeTest` deleted) + 2 (`MainFrameFailureTest`);
- no failures. Recount if the old classes had other counts, and record what you see.

- [ ] **Step 9: Run the full gates**: zero `e:` lines, `flutter analyze` clean, `flutter test` unchanged.

- [ ] **Step 10: Quick device check.** Install and check these three:
  1. A saved SOCKS5 site loads `https://httpbin.org/cookies/set?p2=1`, which redirects to `/cookies` and shows `p2`. Before this task that failed with `net::ERR_HTTP_RESPONSE_CODE_FAILURE`.
  2. A direct site still loads.
  3. A held download on the SOCKS5 site (`https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf` as the site's URL) reads `13.0 KB · from www.w3.org`.

- [ ] **Step 11: Commit**

```bash
git add -A android/app/src/main/kotlin android/app/src/test/kotlin
git status --short
git commit -m "feat: Chromium fetches every page through the loopback proxy; the interceptor gates and blocks"
```

---

### Task 7: Verify on the emulator, and record it

**Files:**
- Modify: `docs/superpowers/plans/2026-09-30-loopback-proxy.md` (this file: Verification, Device checks, Known gaps, Handoff)
- Modify: `CLAUDE.md`. If the executing session's harness does not let it edit `CLAUDE.md`, the coordinating session makes this edit instead.

- [ ] **Step 1: Set up the harness**, as in the proxy leak fixes plan ("How the leaks were found"):
  - the emulator started with `-dns-server` pointed at a logging DNS forwarder on the host;
  - a local Python proxy on the host, serving SOCKS5 on `:1080` and HTTP CONNECT on `:8888`, that logs every target;
  - `adb shell ss -tnpe` sampled every 0.2 s for the app's uid;
  - `MSYS_NO_PATHCONV=1` for `adb` from Git Bash;
  - the UI read through `uiautomator dump`, since the app sets `FLAG_SECURE` and screenshots come out black.

- [ ] **Step 2: Run each spec §7 device check.** For each, record what was seen, or that it was not seen:
  1. A SOCKS5 site on `https://duckduckgo.com`: the page, its preconnect (`links.duckduckgo.com`), a service-worker site (`https://squoosh.app`) and a pagehide beacon probe. The app's uid makes **zero sockets to anything but `127.0.0.1:<loopback port>`**, and the SOCKS5 proxy's log shows each host by name. This closes a1.
  2. The SOCKS5 proxy receives hostnames, never addresses.
  3. **Login survives a reopen** on SOCKS5:
     - load `https://httpbin.org/cookies/set?p2=1`;
     - back out to the dashboard;
     - close the site from the switcher's ×;
     - reopen it at `https://httpbin.org/cookies`. It shows `"p2": "1"`.
  4. A redirect works, as in item 3. A form POST works too: `https://httpbin.org/forms/post` submits and shows the posted fields.
  5. Find the listening port with `adb shell cat /proc/net/tcp`. Look for local `0100007F:<hex port>` in state `0A` owned by the app's uid. Then:
     - `printf 'CONNECT example.com:443 HTTP/1.1\r\n\r\n' | adb shell toybox nc 127.0.0.1 <port>` prints `407` with `realm="container"`;
     - the same with `Proxy-Authorization: Basic MDA6MDA=` prints `403`;
     - the local proxy logs nothing, and `ss` shows no socket to example.com.
  6. A form page (`https://httpbin.org/forms/post`): no `content-autofill.googleapis.com` lookup in the DNS log, and no socket to Google's `2001:4860:…` ranges.
  7. Lock (`9c`), unlock and reopen the SOCKS5 site. It loads with no visible prompt: Chromium's cached credential is accepted again once the session is bound. That the old credential gets `403` while the site is closed is pinned by the JVM test "a closed session's credential gets 403". Say so in the record rather than claiming it was seen.
  8. Panic: `3c` shows, the app stays up, and `meta.bin` and `store-1.db` are gone.
  9. Direct sites still work: `https://example.com` and a Plan 12 throwaway search from it.
  10. The DNS log over the whole run: the only names the device looked up for proxied sites are the pages' own `dns-prefetch` hints (the accepted gap a2).
  11. An http-mode site through `:8888` loads, and the proxy logs `CONNECT host:443`.

- [ ] **Step 3: Record the results in this file.**
  - Fill in "Verification" with the gate outputs at the final commit: analyze, test count, JVM count read from the XML, and the `e:` count.
  - Fill in "Device checks" with Step 2's results, one line each, marking each "seen" or "not seen, because …".
  - Keep "Known gaps" as below, adding anything the device run found.

- [ ] **Step 4: Update `CLAUDE.md`.**
  - Add a Plan 13 row to the plans table: file `2026-09-30-loopback-proxy.md`, status **Done** with the date, and what it covers. Mark it device-verified or not exactly as Step 2 found.
  - Under "Unassigned work", strike through the P2 bullet and point it to Plan 13.
  - Under "Device verification", in the Plan 12 leak list, mark the preconnect (a1) bullet **✅ closed by Plan 13**, and note that dns-prefetch (a2) remains the accepted gap. Mark "A proxied site keeps no HTTP cookies" **✅ fixed by Plan 13** if Step 2's item 3 was seen.
  - Record plan deviation 2 (`127.0.0.1` refused) where a future reader will look for it.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/plans/2026-09-30-loopback-proxy.md CLAUDE.md
git commit -m "docs: record Plan 13's verification, device checks and gaps"
```

---

## Execution record, Tasks 1–6 (2026-09-30)

Tasks 1–6 were executed in a cloud session with no Android emulator, so no
device check in Tasks 5 and 6 was run, and Task 7 is left for the user's
machine. Nothing here is device-verified.

**Where.** Branch `second/compassionate-tesla-aa52zz` off `main` at `98c5b81`,
in the session's own checkout: that was the session's designated branch, so
no `p2-loopback-proxy` worktree was made. This machine reaches GitHub, so the
native-assets cache did not need copying.

**Toolchain.** Flutter 3.47.2 (Dart 3.13.2), Android SDK platform 36 and
build-tools 36.0.0, OpenJDK 21. Maven Central answered this container's Gradle
with HTTP 429, so a Gradle init script outside the repo
(`~/.gradle/init.d`) pointed Maven Central at Google's mirror of it. Nothing
in the repo's build files changed.

**Baseline at `98c5b81`:** `flutter analyze` clean; `flutter test` 540/540;
Kotlin JVM 128 tests, 0 failures, 0 errors (23 JUnit XML files);
`flutter build apk --debug` built, zero `e:` lines.

**Per task** (JVM counts read from the JUnit XML):

- Task 1: JVM 139 (128 + 11), 0 failures; `flutter test` 540/540; analyze
  clean; APK zero `e:` lines.
- Task 2: JVM 161 (139 + 22), 0 failures; `flutter test` 540/540; analyze
  clean; APK zero `e:` lines. The test and implementation are the plan's,
  unchanged.

**Deviations from the plan's text:**

- The plan's line references for `ContainerViewFactory.kt` (`239-244`) are
  stale: the file is 63 lines, and the `ContainerView(` call is at line 30.
  The change it describes was made there.

## Verification

*(Filled in by Task 7.)*

## Device checks

*(Filled in by Task 7.)*

## Known gaps

These come from spec §6 and this plan's deviations. They are recorded, not fixed.

- **dns-prefetch still leaks (a2).** `<link rel=dns-prefetch>` makes the device look the hostname up, on proxied sites too. `NetworkContext::ResolveHost` ignores proxies, and WebView ignores the document's prefetch control (findings, "dns-prefetch control"). It is a lookup only.
- **A profile's first request decides what can go before it.** Until the profile has answered one `407`, its service-worker fetches and preconnects fail closed.
- **WebRTC** is UDP and passes through no proxy. The "Block WebRTC" shield governs it, as today.
- **Downloads still use `ProxyHttpClient`.** They carry the profile's cookies and still follow no redirects.
- **No authentication to the user's own upstream proxy**, as in Plan 10.
- **A single connection's upstream failure is not reported** (deviation 1).
  - A main frame whose `CONNECT` is refused or times out upstream shows WebView's own error page, not `8b`.
  - Only a refused route (proxy unreachable, misconfigured) and a main-frame TLS handshake failure are reported.
- **Certificate errors are not reported** (deviation 4). WebView's default cancels them.
- **A site at `127.0.0.1` cannot be opened** (deviation 2). `localhost` can.
- **Absolute-form `http://` requests** carry only `Content-Length` bodies (deviation 3). The shipped app refuses cleartext before they are made anyway.
- **Not verified:**
  - WebView versions other than 154, and a physical phone;
  - a WebView without `PROXY_OVERRIDE`, which is the `UNSUPPORTED` path;
  - HTTP/2 or QUIC to the loopback proxy;
  - non-Basic schemes;
  - the auth cache across a renderer crash.
- **Wipe-on-exit's automatic wipe does not rotate the profile id** (the `fix-site-wipe` ruling).

## Handoff

- `Loopback.credentials` and `Loopback.start()` are the process's only proxy and credential table. Never make a second.
- `EngineChannel` binds a profile in `register` and unbinds it in `close`. Any new path that opens or closes a session must do the same.
- The loopback proxy is the only place a site's route is applied to page traffic. `ProxyHttpClient` remains for downloads.
- There is one `ProxyController` override per process. Anything else that needs one must be expressed inside the loopback proxy, as the Autofill refusal is.

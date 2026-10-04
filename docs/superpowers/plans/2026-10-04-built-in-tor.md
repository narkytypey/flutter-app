# Built-in Tor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A site can be routed through a Tor client embedded in the app, a third proxy mode beside SOCKS5 and HTTP, with nothing else installed.

**Architecture:** Guardian Project's `tor-android` runs Tor inside the app process as a bound `TorService`. A new `TorRuntime` (pure Kotlin, JVM-tested over a fake) starts it when a container on the Tor route opens and stops it when the last one closes, at lock and at panic. Tor's SOCKS port is a Unix socket in the app's private directory; `Router` reaches it through an Android `LocalSocket` wrapped as a `java.net.Socket` (`StreamSocket`), so the loopback proxy and downloads use it unchanged. Dart gains `ProxyMode.tor`, the onion rules, the copy, and Tor's bootstrap percentage on `8a`.

**Tech Stack:** Kotlin (engine), `info.guardianproject:tor-android:0.4.9.13` (Maven Central) with its `jtorctl` and `androidx.localbroadcastmanager`, Flutter/Dart with Riverpod.

**Spec:** `docs/superpowers/specs/2026-10-04-built-in-tor-design.md` (approved section by section by the user on 2026-10-04; every string in its §7 approved word for word).

**Plan number:** 19.

## Global Constraints

- Android only, dark theme only.
- **No network requests of the app's own, except connecting to the Tor network when the user has chosen Tor** (spec ruling 1; this plan writes the amendment into `CLAUDE.md` in Task 8). Tor starts only when a container on the Tor route opens (§4.2). Nothing else starts it: not the Default route being Tor, not an onion link on a page.
- **Never direct.** A Tor site whose Tor is off, starting, failed or stalled is refused (`8b`, or `8c` once live). There is no branch that sends a Tor site direct except `8b`'s explicit "Open without the tunnel".
- **Copy, verbatim, and no other new strings** (spec §7): chip `Tor`; line `Through the Tor network. Each site gets its own circuit.`; route label `Tor`; `8a` step `Connecting to Tor` and `Connecting to Tor · 45%` (Tor's own percentage); `8b` headline `Tor did not connect`; `8b` sentence `<Site> is set to go through Tor, which could not reach the Tor network. The page was not loaded, so no request left your device.`; `8b` Tunnel row `Tor`. The throwaway tag `THROWAWAY · TOR` comes from the existing code.
- Jade only for live state or the one affirmative action; this plan adds none.
- IBM Plex Mono for anything technical, Figtree otherwise.
- Two-vault model: no code asks which vault is open. Tor is shared by both vaults.
- No leak count anywhere.
- No code generation.
- `test/no_glyphs_test.dart` keeps passing: no Unicode glyphs or Material `Icons.` in `lib/`.
- Kotlin code the JVM tests run never calls `android.util.Log` (it throws on the stub `android.jar`).
- `flutter analyze` and `flutter test` never compile Kotlin. A task that touches Kotlin also runs `(cd android && ./gradlew :app:testDebugUnitTest)`, with counts read from `build/app/test-results/testDebugUnitTest/TEST-*.xml`, and `flutter build apk --debug` with zero lines starting `e:`. Flutter and Gradle commands need the Bash sandbox disabled.
- One new runtime dependency, `info.guardianproject:tor-android:0.4.9.13`, plus `androidx.localbroadcastmanager:localbroadcastmanager:1.1.0`, which it already pulls in and which `TorServiceDaemon` uses directly. Nothing else.

## Review Focus

1. **A lock while a Tor open is still waiting.** The waiting open must end refused and unregistered, and Tor must stop: no holder left behind. Pinned in Task 1 (`stopAll lets go of every holder and every waiter`) and Task 4 (`routeForOpen` refusing when its hold is released).
2. **Two Tor containers opening at once, one cancelled.** The other keeps waiting and Tor keeps running. Pinned in Task 1 (`releasing one of two holders keeps Tor running for the other`).
3. **Tor failing after it was ready** (a live site). Tor must read as not ready, so the loopback proxy refuses and `8c` shows, never direct. Pinned in Task 1 (`Tor failing after it was ready leaves it not ready`) and Task 2 (`a tor site with Tor not ready is refused`).
4. **An onion host in another case or with a trailing dot** (`ABC.ONION.`) on a Direct route. Still refused before any lookup. Pinned in Task 1 (Kotlin `isOnionHost`), Task 2 (`decide`), Task 5 (Dart `isOnionHost`).
5. **A Tor percentage left over from an earlier run.** `8a` must not show `· 100%` for a start that has not begun. Pinned in Task 5 (`torStepLabel`).

## Decisions this plan makes (for the user's review)

- **D1. Tor's data lives where `tor-android` puts it.** Spec §4.1/§4.5 said `filesDir/tor`. The library sets `--DataDirectory` and `--CacheDirectory` on Tor's command line, which overrides any torrc: data in `app_TorService/data` (with its torrc beside it) and cache in `cache/TorService`. Only the SOCKS socket is ours, in `files/tor/`. Panic deletes all three.
- **D2. The socket file is named `socks:0`.** Once Tor is up, `TorService` reads `net/listeners/socks` and parses the text after the last `:` as a port, in a thread whose `catch` does not cover `NumberFormatException`. A plain Unix path would crash the app; `…/socks:0` parses as port 0. Task 3's device spike proves it.
- **D3. Our torrc also sets `HTTPTunnelPort 0` and `ControlPort 0`.** The library's defaults file opens TCP 9050 (SOCKS) and 8118 (HTTP tunnel); our torrc's `SocksPort` replaces the first, and these replace the rest. Its control connection is a Unix socket it sets itself.
- **D4. Panic deletes Tor's state twice and again at the next start.** Tor writes its `state` file as it shuts down, which can land after panic's delete. Panic deletes, deletes again 5 s later, and leaves a marker that the next start honours before anything runs.
- **D5. Progress is polled.** `TorService` broadcasts only on and off, so `TorServiceDaemon` reads `status/bootstrap-phase` every 500 ms. Ready is `PROGRESS=100`.
- **D6. `Tor` in title case wherever a route is named**: the container's top bar, `2c`'s `viewing now · Tor`, `6c`'s proxy row, `8b`'s Tunnel row, the Default route row. The throwaway tag is all capitals (`THROWAWAY · TOR`). The dashboard row's meta, a lowercase list (`direct`, `socks5`, `ephemeral`), reads `tor`.
- **D7. The onion rule in the form is applied twice**: live, as the address is typed (the switch turns on, on Tor), and in `buildSite`, so a save can never write an onion site on Direct.
- **D8. A held download whose address is an onion host is refused on a Direct route** (not in the spec; the same rule as §5.3's links: the name would go to DNS).
- **D9. A Tor hold is per site id, taken when the open starts**, so a lock (`closeAll` → `stopAll`) ends an open still waiting for Tor.
- **D10. Version 0.4.9.13 from Maven Central.** The library's README names 0.4.9.13.1 on Guardian's own repository; Central's newest is 0.4.9.13 (published 2026-09-28), and it needs no extra repository.

## File structure

**Kotlin, `android/app/src/main/kotlin/com/mono/container/engine/`:**
- Create `TorConfig.kt`: `TorFiles` (paths), `torrc()`, `bootstrapPercent()`, `isOnionHost()`, `TorWipe`.
- Create `TorRuntime.kt`: `TorDaemon`, `TorEvents`, `TorRuntime`, `routeForOpen()`.
- Create `TorServiceDaemon.kt`: the real `TorDaemon` over `TorService`, and the `Tor` process singleton.
- Create `StreamSocket.kt`: `StreamSocket`, `localSocket()`.
- Modify `Router.kt`: `Route.Tor`, `RouteFailure.TOR_FAILED`, the `tor` branch of `resolve`, `connect`'s local socket, `currentRoute()`.
- Modify `Socks5Tunnel.kt`: the handshake split out so `over()` runs it on a given socket.
- Modify `LoopbackRequest.kt`: `decide()` refuses an onion host on a Direct route.
- Modify `DownloadFetcher.kt`: `Route.Tor` saves like a proxy; an onion download on Direct is refused.
- Modify `SiteConfig.kt`: `withTorShields()`.
- Modify `EngineChannel.kt`: hold and release Tor, `tor_progress` events, `TOR_FAILED`'s name, panic's wipe.
- Modify `Shields.kt` (Task 8): the dns-prefetch experiment.
- Modify `MainActivity.kt`: sweep and install Tor at start.
- Modify `android/app/build.gradle.kts`: the two dependencies.

**Kotlin tests, `android/app/src/test/kotlin/com/mono/container/engine/`:** create `TorConfigTest.kt`, `TorRuntimeTest.kt`, `StreamSocketTest.kt`, `TorShieldsTest.kt`; extend `RouterTest.kt`, `LoopbackRequestTest.kt`, `DownloadFailureTest.kt`, `RouteFailureNameTest.kt`.

**Device spike:** create `android/app/src/androidTest/kotlin/com/mono/container/engine/TorSpikeTest.kt`.

**Dart, `lib/`:**
- Create `domain/onion.dart`: `isOnionHost()`.
- Create `domain/models/route_display.dart`: every on-screen route name and the two Tor rules (`canOpenWithoutTunnel`, `webRtcLocked`).
- Modify `domain/models/site.dart` (`ProxyMode.tor`), `proxy_route.dart`, `route_decision.dart`, `route_failure_copy.dart`, `site_descriptor.dart`, `open_step.dart`, `destination.dart`, `domain/tabs.dart`, `ui/features/add_site/view_models/add_site_view.dart`.
- Modify `data/services/container_engine.dart`, `container_engine_channel.dart`, `fake_container_engine.dart`; `ui/features/container/view_models/providers.dart` (`torProgressProvider`); `ui/features/container/views/container_route.dart`; `ui/features/in_page/views/proxy_unreachable_screen.dart`, `site_sheet.dart`.
- Modify `ui/features/add_site/views/form_toggle_row.dart`, `route_fields.dart`, `network_tab.dart`, `add_site_screen.dart`; `ui/features/settings/views/default_route_screen.dart`.

**Dart tests:** create `test/domain/onion_test.dart`, `test/domain/route_display_test.dart`, `test/ui/features/add_site_tor_test.dart`; extend the tests named in each task.

---

### Task 1: The Tor library, its configuration, and `TorRuntime`

**Files:**
- Modify: `android/app/build.gradle.kts`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/TorConfig.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/TorRuntime.kt`
- Create: `android/app/src/main/kotlin/com/mono/container/engine/TorServiceDaemon.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/TorConfigTest.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/TorRuntimeTest.kt`

**Interfaces:**
- Produces: `TorFiles.socketDir(filesDir: File): File`, `TorFiles.socket(filesDir: File): File`, `TorFiles.all(filesDir: File, dataDir: File, cacheDir: File): List<File>`, `TorFiles.wipeMarker(filesDir: File): File`; `torrc(socket: File): String`; `bootstrapPercent(phase: String?): Int?`; `isOnionHost(host: String): Boolean`; `TorWipe.wipe(dirs: List<File>, marker: File)`, `TorWipe.sweep(dirs: List<File>, marker: File)`; `interface TorDaemon { fun start(events: TorEvents); fun stop() }`; `interface TorEvents { fun progress(percent: Int); fun failed() }`; `class TorRuntime(daemon: TorDaemon, now: () -> Long = System::currentTimeMillis, stallMs: Long = TorRuntime.STALL_MS, pollMs: Long = TorRuntime.POLL_MS)` with `state: TorRuntime.State`, `isReady: Boolean`, `hold(holder: String)`, `release(holder: String)`, `stopAll()`, `awaitReady(holder: String, onProgress: (Int) -> Unit = {}): Boolean`; `TorRuntime.State` = `Off | Starting(percent: Int) | Ready | Failed`; `class TorServiceDaemon(context: Context) : TorDaemon`; `internal object Tor { val runtime: TorRuntime?; val socketPath: String?; fun install(context: Context) }`.

- [ ] **Step 0: Record the baselines**

Run, with the Bash sandbox disabled:

```bash
flutter test 2>&1 | tail -1
(cd android && ./gradlew :app:testDebugUnitTest)
flutter build apk --debug && ls -l build/app/outputs/flutter-apk/app-debug.apk
```

Write down the Dart count (F0), the Kotlin count summed from `build/app/test-results/testDebugUnitTest/TEST-*.xml` (K0), and the APK's size (S0) in the task report. Task 8 checks the totals and the size against them.

- [ ] **Step 1: Add the dependencies**

In `android/app/build.gradle.kts`, in `dependencies { … }`, after `implementation("androidx.biometric:biometric:1.1.0")`, add:

```kotlin
    // Built-in Tor (spec §4): Tor itself, in process, and the broadcasts its service sends.
    implementation("info.guardianproject:tor-android:0.4.9.13")
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
```

- [ ] **Step 2: Confirm the library's API**

The code below was written against `tor-android`'s `TorService` source on GitHub. Check that 0.4.9.13 has the same names before relying on them:

```bash
(cd android && ./gradlew :app:dependencies --configuration debugRuntimeClasspath | grep -i "tor-android\|jtorctl\|localbroadcast")
```

Expected: `info.guardianproject:tor-android:0.4.9.13`, `info.guardianproject:jtorctl:0.4.5.7`, `androidx.localbroadcastmanager:localbroadcastmanager:1.1.0`. Then find the AAR in the Gradle cache (`find ~/.gradle/caches -name "tor-android-0.4.9.13.aar"`), unzip its `classes.jar` to a temp directory under `$CLAUDE_JOB_DIR/tmp` (or any scratch directory), and run `javap -classpath classes.jar org.torproject.jni.TorService`. It must list: `ACTION_STATUS`, `ACTION_ERROR`, `EXTRA_STATUS`, `STATUS_OFF`, `STATUS_STOPPING`, `public static java.io.File getTorrc(android.content.Context)`, `public java.lang.String getInfo(java.lang.String)`, and the nested `TorService$LocalBinder` with `getService()`. If any differs, stop and report BLOCKED with the `javap` output.

- [ ] **Step 3: Write the failing configuration tests**

Create `android/app/src/test/kotlin/com/mono/container/engine/TorConfigTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.file.Files

/** Built-in Tor spec §4.1, §4.5, §5.3 and plan D1–D4: what Tor is told, and where it keeps things. */
class TorConfigTest {

    private val files = File("data", "files")

    @Test fun `the SOCKS socket is ours, in files tor`() {
        assertEquals(File(File(files, "tor"), "socks:0"), TorFiles.socket(files))
        assertEquals(File(files, "tor"), TorFiles.socketDir(files))
    }

    /** Plan D2: tor-android parses the text after the last colon of the listener as a port. */
    @Test fun `the socket's listener parses as port 0, the way TorService reads it`() {
        val value = "\"unix:${TorFiles.socket(files).absolutePath}\""
        assertEquals(0, Integer.parseInt(value.substring(value.lastIndexOf(':') + 1, value.length - 1)))
    }

    @Test fun `torrc names the Unix socket with circuit isolation by login`() {
        val socket = TorFiles.socket(files)
        assertTrue(torrc(socket).contains("SocksPort unix:\"${socket.absolutePath}\" IsolateSOCKSAuth\n"))
    }

    /** Plan D3: the library's defaults open TCP 9050 and 8118; nothing of ours may. */
    @Test fun `torrc opens no TCP port`() {
        val text = torrc(TorFiles.socket(files))
        assertTrue(text.contains("HTTPTunnelPort 0\n"))
        assertTrue(text.contains("ControlPort 0\n"))
        assertFalse(text.contains("9050"))
        assertFalse(text.contains("8118"))
    }

    @Test fun `panic's list is our socket directory and the two tor-android picks`() {
        val data = File("data")
        val cache = File("cache")
        assertEquals(
            listOf(File(files, "tor"), File(data, "app_TorService"), File(cache, "TorService")),
            TorFiles.all(files, data, cache),
        )
    }

    @Test fun `a bootstrap phase gives its percentage`() {
        assertEquals(45, bootstrapPercent("NOTICE BOOTSTRAP PROGRESS=45 TAG=loading_descriptors SUMMARY=\"Loading relay descriptors\""))
        assertEquals(100, bootstrapPercent("NOTICE BOOTSTRAP PROGRESS=100 TAG=done SUMMARY=\"Done\""))
        assertEquals(0, bootstrapPercent("NOTICE BOOTSTRAP PROGRESS=0 TAG=starting SUMMARY=\"Starting\""))
    }

    @Test fun `no phase, or no percentage in it, is none`() {
        assertNull(bootstrapPercent(null))
        assertNull(bootstrapPercent(""))
        assertNull(bootstrapPercent("NOTICE BOOTSTRAP TAG=starting"))
    }

    /** Review Focus 4. */
    @Test fun `an onion host is one in any case, with or without a trailing dot`() {
        assertTrue(isOnionHost("duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion"))
        assertTrue(isOnionHost("ABC.ONION."))
        assertTrue(isOnionHost("www.abc.onion"))
        assertTrue(isOnionHost("onion"))
        assertFalse(isOnionHost("onion.example.com"))
        assertFalse(isOnionHost("example.com"))
        assertFalse(isOnionHost("notonion"))
    }

    @Test fun `a wipe deletes every directory and leaves the marker`() {
        val root = Files.createTempDirectory("tor-wipe").toFile()
        val dirs = listOf(File(root, "a"), File(root, "b"))
        dirs.forEach { File(it, "state").apply { parentFile.mkdirs(); writeText("guards") } }
        val marker = File(root, "tor-wipe-pending")

        TorWipe.wipe(dirs, marker)

        assertTrue(dirs.none { it.exists() })
        assertTrue(marker.exists())
        root.deleteRecursively()
    }

    /** Plan D4: Tor's own shutdown may write its state again after panic's delete. */
    @Test fun `a sweep with the marker deletes them again and removes the marker`() {
        val root = Files.createTempDirectory("tor-sweep").toFile()
        val dirs = listOf(File(root, "a"))
        val marker = File(root, "tor-wipe-pending").apply { writeText("") }
        File(dirs[0], "state").apply { parentFile.mkdirs(); writeText("written after the wipe") }

        TorWipe.sweep(dirs, marker)

        assertFalse(dirs[0].exists())
        assertFalse(marker.exists())
        root.deleteRecursively()
    }

    @Test fun `a sweep without the marker deletes nothing`() {
        val root = Files.createTempDirectory("tor-keep").toFile()
        val dirs = listOf(File(root, "a"))
        File(dirs[0], "state").apply { parentFile.mkdirs(); writeText("guards") }

        TorWipe.sweep(dirs, File(root, "tor-wipe-pending"))

        assertTrue(File(dirs[0], "state").exists())
        root.deleteRecursively()
    }
}
```

- [ ] **Step 4: Write the failing runtime tests**

Create `android/app/src/test/kotlin/com/mono/container/engine/TorRuntimeTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Built-in Tor spec §4.2–§4.3: when Tor runs, and what a waiting open hears. */
class TorRuntimeTest {

    /** Counts starts and stops; the test speaks for Tor through [events]. */
    private class FakeTor : TorDaemon {
        var starts = 0
        var stops = 0
        @Volatile var events: TorEvents? = null
        override fun start(events: TorEvents) {
            starts++
            this.events = events
        }
        override fun stop() {
            stops++
        }
    }

    private fun runtime(tor: FakeTor, stallMs: Long = 60_000) = TorRuntime(tor, stallMs = stallMs, pollMs = 10)

    /** [TorRuntime.awaitReady] on another thread, as an open runs it; the returned
     *  function gives its answer, or null if it had none within 5 s. */
    private fun waitOn(runtime: TorRuntime, holder: String, heard: MutableList<Int> = mutableListOf()): () -> Boolean? {
        val answer = AtomicReference<Boolean?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(runtime.awaitReady(holder) { synchronized(heard) { heard += it } })
            done.countDown()
        }.start()
        return { if (done.await(5, TimeUnit.SECONDS)) answer.get() else null }
    }

    private fun eventually(condition: () -> Boolean) {
        val until = System.currentTimeMillis() + 5_000
        while (!condition()) {
            check(System.currentTimeMillis() < until) { "condition never held" }
            Thread.sleep(5)
        }
    }

    @Test fun `nothing starts Tor until a site holds it`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        assertEquals(0, tor.starts)
        assertEquals(TorRuntime.State.Off, runtime.state)
        assertFalse(runtime.isReady)
    }

    @Test fun `the first hold starts Tor and a second joins the same start`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        assertEquals(1, tor.starts)
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }

    @Test fun `a waiting open hears the percentage and is let through at 100`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val heard = mutableListOf<Int>()
        val answer = waitOn(runtime, "a", heard)

        tor.events!!.progress(45)
        eventually { synchronized(heard) { 45 in heard } }
        tor.events!!.progress(100)

        assertEquals(true, answer())
        assertTrue(runtime.isReady)
        assertEquals(1, tor.starts)
    }

    @Test fun `a hold while Tor is ready waits for nothing`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.progress(100)
        runtime.hold("b")
        assertTrue(runtime.awaitReady("b"))
        assertEquals(1, tor.starts)
    }

    @Test fun `the last release stops Tor and lets a waiting open go`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val answer = waitOn(runtime, "a")

        runtime.release("a")

        assertEquals(false, answer())
        assertEquals(1, tor.stops)
        assertEquals(TorRuntime.State.Off, runtime.state)
    }

    /** Review Focus 2. */
    @Test fun `releasing one of two holders keeps Tor running for the other`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        val first = waitOn(runtime, "a")
        val second = waitOn(runtime, "b")

        runtime.release("a")
        assertEquals(false, first())
        assertEquals(0, tor.stops)

        tor.events!!.progress(100)
        assertEquals(true, second())
    }

    @Test fun `a failure refuses every waiting open and stops Tor`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        val first = waitOn(runtime, "a")
        val second = waitOn(runtime, "b")

        tor.events!!.failed()

        assertEquals(false, first())
        assertEquals(false, second())
        assertEquals(1, tor.stops)
        assertEquals(TorRuntime.State.Failed, runtime.state)
    }

    /** Spec §4.3: no new percentage for the stall time is a failure. */
    @Test fun `progress that stops moving for the stall time fails Tor`() {
        val tor = FakeTor()
        val runtime = runtime(tor, stallMs = 100)
        runtime.hold("a")
        tor.events!!.progress(30)

        assertEquals(false, waitOn(runtime, "a")())
        assertEquals(TorRuntime.State.Failed, runtime.state)
        assertEquals(1, tor.stops)
    }

    @Test fun `the same percentage again does not count as moving`() {
        val tor = FakeTor()
        val runtime = runtime(tor, stallMs = 150)
        runtime.hold("a")
        tor.events!!.progress(30)
        val answer = waitOn(runtime, "a")
        repeat(10) {
            tor.events!!.progress(30)
            Thread.sleep(20)
        }
        assertEquals(false, answer())
    }

    @Test fun `a hold after a failure starts Tor again`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.failed()

        runtime.hold("a")

        assertEquals(2, tor.starts)
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }

    @Test fun `a stopped run's late events count for nothing`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val old = tor.events!!
        runtime.release("a")
        runtime.hold("a")

        old.progress(100)
        assertFalse(runtime.isReady)
        old.failed()
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }

    /** Review Focus 3: a live site's Tor dying must read as not ready. */
    @Test fun `Tor failing after it was ready leaves it not ready`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.progress(100)
        assertTrue(runtime.isReady)

        tor.events!!.failed()

        assertFalse(runtime.isReady)
        assertEquals(TorRuntime.State.Failed, runtime.state)
        assertEquals(1, tor.stops)
    }

    /** Review Focus 1: a lock ends every wait and stops Tor. */
    @Test fun `stopAll lets go of every holder and every waiter`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.hold("b")
        val first = waitOn(runtime, "a")
        val second = waitOn(runtime, "b")

        runtime.stopAll()

        assertEquals(false, first())
        assertEquals(false, second())
        assertEquals(1, tor.stops)
        runtime.hold("c")
        assertEquals(2, tor.starts)
    }

    @Test fun `stopAll after a failure does not stop Tor twice`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        tor.events!!.failed()
        runtime.stopAll()
        assertEquals(1, tor.stops)
        assertEquals(TorRuntime.State.Off, runtime.state)
    }

    @Test fun `releasing a site that never held Tor changes nothing`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        runtime.release("z")
        assertEquals(0, tor.stops)
        assertEquals(TorRuntime.State.Starting(0), runtime.state)
    }
}
```

- [ ] **Step 5: Run them and see them fail**

Run: `(cd android && ./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.TorConfigTest" --tests "com.mono.container.engine.TorRuntimeTest")`
Expected: FAIL, compilation errors (`Unresolved reference: TorFiles`, `TorRuntime`, …).

- [ ] **Step 6: Write `TorConfig.kt`**

Create `android/app/src/main/kotlin/com/mono/container/engine/TorConfig.kt`:

```kotlin
package com.mono.container.engine

import java.io.File

/**
 * Where built-in Tor keeps things (spec §4.1, §4.5, plan D1). Pure, so the
 * JVM tests read it; [TorServiceDaemon] and panic use it on the device.
 */
object TorFiles {
    /** Ours, owner-only: Tor will not make a SOCKS socket where others can enter. */
    fun socketDir(filesDir: File) = File(filesDir, "tor")

    /**
     * Tor's SOCKS port (spec §4.4). The name ends `:0` on purpose (plan D2):
     * once Tor is up, tor-android's `TorService` reads `net/listeners/socks`
     * and parses the text after the last `:` as a port, in a thread whose
     * catch does not cover a `NumberFormatException`. A plain path would crash
     * the app; this one parses as port 0.
     */
    fun socket(filesDir: File) = File(socketDir(filesDir), "socks:0")

    /**
     * Everything Tor keeps: our socket directory, and the data (with its torrc)
     * and cache directories tor-android sets on Tor's command line, which no
     * torrc can move (plan D1).
     */
    fun all(filesDir: File, dataDir: File, cacheDir: File): List<File> = listOf(
        socketDir(filesDir),
        File(dataDir, "app_TorService"),
        File(cacheDir, "TorService"),
    )

    /** Left by panic until the next start has deleted Tor's state again (plan D4). */
    fun wipeMarker(filesDir: File) = File(filesDir, "tor-wipe-pending")
}

/**
 * The torrc `TorService` reads with `-f` (spec §4.1). Its lines replace the
 * same options in tor-android's defaults file, which opens TCP 9050 and 8118
 * (plan D3). `IsolateSOCKSAuth` gives each SOCKS login its own circuit (§5.2).
 */
fun torrc(socket: File): String = buildString {
    append("SocksPort unix:\"${socket.absolutePath}\" IsolateSOCKSAuth\n")
    append("HTTPTunnelPort 0\n")
    append("ControlPort 0\n")
}

private val BOOTSTRAP_PROGRESS = Regex("""\bPROGRESS=(\d{1,3})\b""")

/** The percentage in Tor's `status/bootstrap-phase` (plan D5), or null without one. */
fun bootstrapPercent(phase: String?): Int? =
    phase?.let { BOOTSTRAP_PROGRESS.find(it) }?.groupValues?.get(1)?.toIntOrNull()?.coerceIn(0, 100)

/**
 * An onion service's name (spec §5.3): reachable only through Tor, so never
 * looked up or sent direct. Letter case and one trailing dot change nothing.
 */
fun isOnionHost(host: String): Boolean {
    val name = host.trimEnd('.').lowercase()
    return name == "onion" || name.endsWith(".onion")
}

/** Panic's part for Tor (spec §4.5, plan D4). */
object TorWipe {
    /** Deletes [dirs]. The marker is written first, so a crash midway still leaves work for [sweep]. */
    fun wipe(dirs: List<File>, marker: File) {
        marker.parentFile?.mkdirs()
        marker.writeText("")
        for (dir in dirs) dir.deleteRecursively()
    }

    /** At start, before Tor can run: finishes a wipe that Tor's own shutdown may have undone. */
    fun sweep(dirs: List<File>, marker: File) {
        if (!marker.exists()) return
        for (dir in dirs) dir.deleteRecursively()
        marker.delete()
    }
}
```

- [ ] **Step 7: Write `TorRuntime.kt`**

Create `android/app/src/main/kotlin/com/mono/container/engine/TorRuntime.kt`:

```kotlin
package com.mono.container.engine

import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

/** What [TorRuntime] drives: tor-android's service on a device ([TorServiceDaemon]), a fake in the JVM tests. */
interface TorDaemon {
    /** Starts Tor. [events] hears it, on any thread, until [stop]. */
    fun start(events: TorEvents)

    /** Stops Tor. Nothing the stopped run says afterwards counts. */
    fun stop()
}

interface TorEvents {
    /** Tor's bootstrap percentage; 100 is ready. */
    fun progress(percent: Int)

    /** Tor reported an error, or stopped by itself. */
    fun failed()
}

/**
 * The process's one Tor (built-in Tor spec §4.2, ruling 1): off until a site
 * on the Tor route holds it, stopped when the last one lets go.
 *
 * [hold], [release] and [stopAll] run on the main thread, as the engine's
 * open and close do. [awaitReady] blocks, so never there. Each run has a
 * generation; whatever a stopped or failed run says afterwards is ignored.
 */
class TorRuntime(
    private val daemon: TorDaemon,
    private val now: () -> Long = System::currentTimeMillis,
    private val stallMs: Long = STALL_MS,
    private val pollMs: Long = POLL_MS,
) {
    sealed class State {
        data object Off : State()
        data class Starting(val percent: Int) : State()
        data object Ready : State()
        data object Failed : State()
    }

    private val lock = ReentrantLock()
    private val changed = lock.newCondition()
    private val holders = HashSet<String>()
    private var generation = 0
    private var lastMovedAt = 0L
    private var current: State = State.Off

    val state: State get() = lock.withLock { current }

    val isReady: Boolean get() = state == State.Ready

    /** [holder] (a site id) needs Tor: it starts if it is off or has failed. */
    fun hold(holder: String) {
        lock.withLock {
            holders += holder
            if (current == State.Off || current == State.Failed) begin()
        }
    }

    /** [holder] no longer needs Tor; its wait, if any, ends false. The last one stops Tor. */
    fun release(holder: String) {
        lock.withLock {
            if (!holders.remove(holder)) return
            changed.signalAll()
            if (holders.isEmpty()) halt(State.Off)
        }
    }

    /** Every lock and panic: nothing holds Tor, every wait ends, and it stops. */
    fun stopAll() {
        lock.withLock {
            holders.clear()
            halt(State.Off)
        }
    }

    /**
     * Blocks until Tor is ready (true), or until it fails, stalls ([stallMs]
     * with no new percentage, spec §4.3) or [holder] lets go of it (false).
     * [onProgress] hears each new percentage while it waits.
     */
    fun awaitReady(holder: String, onProgress: (Int) -> Unit = {}): Boolean {
        var heard = -1
        lock.withLock {
            while (true) {
                if (holder !in holders) return false
                when (val seen = current) {
                    State.Ready -> return true
                    State.Off, State.Failed -> return false
                    is State.Starting -> {
                        if (seen.percent != heard) {
                            heard = seen.percent
                            onProgress(heard)
                        }
                        val idle = now() - lastMovedAt
                        if (idle >= stallMs) {
                            halt(State.Failed)
                            return false
                        }
                        changed.await(minOf(pollMs, stallMs - idle), TimeUnit.MILLISECONDS)
                    }
                }
            }
        }
    }

    /** Called holding [lock]. */
    private fun begin() {
        val run = ++generation
        current = State.Starting(0)
        lastMovedAt = now()
        changed.signalAll()
        daemon.start(object : TorEvents {
            override fun progress(percent: Int) = onProgress(run, percent)
            override fun failed() = onFailed(run)
        })
    }

    private fun onProgress(run: Int, percent: Int) {
        lock.withLock {
            if (run != generation) return
            val starting = current as? State.Starting ?: return
            when {
                percent >= 100 -> current = State.Ready
                percent > starting.percent -> {
                    current = State.Starting(percent)
                    lastMovedAt = now()
                }
                else -> return
            }
            changed.signalAll()
        }
    }

    private fun onFailed(run: Int) {
        lock.withLock {
            if (run != generation) return
            halt(State.Failed)
        }
    }

    /** Ends the current run, if one is going, and forgets it. Called holding [lock]. */
    private fun halt(next: State) {
        val running = current is State.Starting || current == State.Ready
        generation++
        current = next
        changed.signalAll()
        if (running) daemon.stop()
    }

    companion object {
        /** Spec §4.3: two minutes with no new percentage is a failure. */
        const val STALL_MS = 120_000L
        const val POLL_MS = 500L
    }
}
```

- [ ] **Step 8: Write `TorServiceDaemon.kt`**

Create `android/app/src/main/kotlin/com/mono/container/engine/TorServiceDaemon.kt`:

```kotlin
package com.mono.container.engine

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ServiceConnection
import android.os.IBinder
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import org.torproject.jni.TorService
import java.io.File

/**
 * The real [TorDaemon]: tor-android's [TorService], bound while Tor is needed
 * (spec §4.2). Unbinding destroys the service, which shuts Tor down.
 *
 * The service broadcasts only on and off, so progress is read by polling its
 * control connection's `status/bootstrap-phase` (plan D5). An error
 * broadcast, the service stopping or the binding dying is a failure;
 * [TorRuntime] ignores whatever a stopped run still says. Main thread only,
 * like [TorRuntime.hold].
 */
class TorServiceDaemon(private val context: Context) : TorDaemon {

    private var run: Run? = null

    private class Run(val events: TorEvents) : ServiceConnection {
        @Volatile var service: TorService? = null

        val poller = Thread({ poll() }, "tor-bootstrap").apply { isDaemon = true }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val status = intent.getStringExtra(TorService.EXTRA_STATUS)
                if (intent.action == TorService.ACTION_ERROR ||
                    status == TorService.STATUS_STOPPING || status == TorService.STATUS_OFF
                ) {
                    events.failed()
                }
            }
        }

        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            service = (binder as TorService.LocalBinder).service
            poller.start()
        }

        override fun onServiceDisconnected(name: ComponentName) = events.failed()

        private fun poll() {
            try {
                while (!Thread.currentThread().isInterrupted) {
                    runCatching { service?.getInfo("status/bootstrap-phase") }.getOrNull()
                        ?.let(::bootstrapPercent)
                        ?.let(events::progress)
                    Thread.sleep(TorRuntime.POLL_MS)
                }
            } catch (_: InterruptedException) {
                // Stopped.
            }
        }
    }

    override fun start(events: TorEvents) {
        val socket = TorFiles.socket(context.filesDir)
        prepareSocketDir(socket)
        TorService.getTorrc(context).apply { parentFile?.mkdirs() }.writeText(torrc(socket))

        val next = Run(events)
        LocalBroadcastManager.getInstance(context).registerReceiver(
            next.receiver,
            IntentFilter().apply {
                addAction(TorService.ACTION_STATUS)
                addAction(TorService.ACTION_ERROR)
            },
        )
        run = next
        if (!context.bindService(Intent(context, TorService::class.java), next, Context.BIND_AUTO_CREATE)) {
            events.failed()
        }
    }

    override fun stop() {
        val current = run ?: return
        run = null
        current.poller.interrupt()
        LocalBroadcastManager.getInstance(context).unregisterReceiver(current.receiver)
        runCatching { context.unbindService(current) }
    }

    /** Owner-only (0700), and no stale socket from a run that was killed. */
    private fun prepareSocketDir(socket: File) {
        val dir = socket.parentFile!!
        dir.mkdirs()
        dir.setReadable(false, false)
        dir.setWritable(false, false)
        dir.setExecutable(false, false)
        dir.setReadable(true, true)
        dir.setWritable(true, true)
        dir.setExecutable(true, true)
        socket.delete()
    }
}

/** The process's one Tor (spec §4.1), installed by [com.mono.container.MainActivity] before any open. */
internal object Tor {
    @Volatile var runtime: TorRuntime? = null
        private set

    @Volatile var socketPath: String? = null
        private set

    @Synchronized fun install(context: Context) {
        if (runtime != null) return
        socketPath = TorFiles.socket(context.filesDir).absolutePath
        runtime = TorRuntime(TorServiceDaemon(context.applicationContext))
    }
}
```

- [ ] **Step 9: Run the tests and see them pass**

Run: `(cd android && ./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.TorConfigTest" --tests "com.mono.container.engine.TorRuntimeTest")`
Expected: PASS, 11 + 15 tests, read from `TEST-com.mono.container.engine.TorConfigTest.xml` and `TEST-com.mono.container.engine.TorRuntimeTest.xml`.

- [ ] **Step 10: Build and commit**

Run `flutter build apk --debug` (sandbox disabled). Expected: zero lines starting `e:`. Then:

```bash
git add android/app/build.gradle.kts android/app/src/main/kotlin/com/mono/container/engine/TorConfig.kt android/app/src/main/kotlin/com/mono/container/engine/TorRuntime.kt android/app/src/main/kotlin/com/mono/container/engine/TorServiceDaemon.kt android/app/src/test/kotlin/com/mono/container/engine/TorConfigTest.kt android/app/src/test/kotlin/com/mono/container/engine/TorRuntimeTest.kt
git commit -m "feat(tor): tor-android, its configuration, and TorRuntime"
```

---

### Task 2: `StreamSocket`, `Route.Tor`, and the onion refusals

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/StreamSocket.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Socks5Tunnel.kt` (whole file below)
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Router.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/LoopbackRequest.kt:134-149`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt:111-149`
- Test: `StreamSocketTest.kt` (create), `RouterTest.kt`, `LoopbackRequestTest.kt`, `DownloadFailureTest.kt` (extend)

**Interfaces:**
- Consumes: `isOnionHost`, `perSiteLogin(profileId)` (existing, `ProxyLogin.kt`).
- Produces: `class StreamSocket(input: InputStream, output: OutputStream, closeChannel: () -> Unit, setTimeout: (Int) -> Unit = {}) : java.net.Socket`; `fun localSocket(path: String): java.net.Socket`; `Socks5Tunnel.over(socket: Socket, targetHost: String, targetPort: Int, login: ProxyLogin? = null): Socket`; `Route.Tor(socketPath: String, login: ProxyLogin)`; `RouteFailure.TOR_FAILED`; `Router.resolve(config: SiteConfig, proxyReachable: Boolean, torSocket: String? = null): Route`; `Router.connect(route, targetHost, targetPort, systemProxy = …, local: (String) -> Socket = ::localSocket)`; `SiteConfig.currentRoute()` handling `tor`; `refusesOnionDownload(route: Route, url: String): Boolean`.

- [ ] **Step 1: Write the failing `StreamSocket` tests**

Create `android/app/src/test/kotlin/com/mono/container/engine/StreamSocketTest.kt`:

```kotlin
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
        val socket = StreamSocket(ByteArrayInputStream(byteArrayOf(7)), out, { closes++ }) { timeouts += it }

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
        val wrapped = StreamSocket(tcp.getInputStream(), tcp.getOutputStream(), tcp::close) { tcp.soTimeout = it }

        val tunnel = Socks5Tunnel.over(wrapped, "abc.onion", 80, ProxyLogin("u", "p"))
        tunnel.getOutputStream().write(42)

        assertEquals(42, tunnel.getInputStream().read())
        assertEquals("u:p", seen.poll(5, TimeUnit.SECONDS))
        assertEquals("abc.onion", seen.poll(5, TimeUnit.SECONDS))
        tunnel.close()
        server.close()
    }
}
```

- [ ] **Step 2: Write the failing route tests**

In `RouterTest.kt`, add these tests inside `class RouterTest` (after `proxied site with no host is misconfigured`):

```kotlin
    @Test fun `a tor site routes to Tor's socket with its own login, whatever was typed`() {
        val site = config(mode = "tor", host = null, port = null)
            .copy(proxyLogin = ProxyLogin("typed", "pw"), proxyLoginPerSite = false)
        val route = Router.resolve(site, proxyReachable = true, torSocket = "/data/files/tor/socks:0")
        assertEquals(Route.Tor("/data/files/tor/socks:0", perSiteLogin(site.profileId)), route)
    }

    /** Review Focus 3. */
    @Test fun `a tor site with Tor not ready is refused, never direct`() {
        val route = Router.resolve(config(mode = "tor", host = null, port = null), proxyReachable = false, torSocket = "/s")
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), route)
    }

    @Test fun `a tor site with no socket is refused`() {
        val route = Router.resolve(config(mode = "tor", host = null, port = null), proxyReachable = true, torSocket = null)
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), route)
    }

    @Test fun `a tor route connects through the local socket and names the target to Tor`() {
        val server = java.net.ServerSocket(0)
        val hosts = java.util.concurrent.ArrayBlockingQueue<String>(1)
        Thread {
            runCatching {
                server.accept().use { client ->
                    val input = java.io.DataInputStream(client.getInputStream())
                    val out = client.getOutputStream()
                    input.readFully(ByteArray(3))
                    out.write(byteArrayOf(5, 2))
                    input.readUnsignedByte()
                    input.readFully(ByteArray(input.readUnsignedByte()))
                    input.readFully(ByteArray(input.readUnsignedByte()))
                    out.write(byteArrayOf(1, 0))
                    input.readFully(ByteArray(4))
                    hosts += String(ByteArray(input.readUnsignedByte()).also(input::readFully))
                    input.readFully(ByteArray(2))
                    out.write(byteArrayOf(5, 0, 0, 1, 0, 0, 0, 0, 0, 0))
                    out.flush()
                }
            }
        }.start()
        val paths = mutableListOf<String>()

        val socket = Router.connect(
            Route.Tor("/data/files/tor/socks:0", ProxyLogin("u", "p")), "abc.onion", 443,
            local = { path ->
                paths += path
                java.net.Socket("127.0.0.1", server.localPort)
            },
        )

        assertEquals(listOf("/data/files/tor/socks:0"), paths)
        assertEquals("abc.onion", hosts.poll(5, java.util.concurrent.TimeUnit.SECONDS))
        socket.close()
        server.close()
    }
```

In `LoopbackRequestTest.kt`, add after the test `a destination named 127_0_0_1 is refused whatever the credentials`:

```kotlin
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
```

In `RouteFailureNameTest.kt`, the one test maps every `RouteFailure` value, so it fails as soon as `TOR_FAILED` exists. Add `"TOR_FAILED" to "torFailed",` after `"PROXY_LOGIN_REJECTED" to "proxyLoginRejected",` in its expected map (Step 6 adds the mapping).

In `DownloadFailureTest.kt`, add inside its class:

```kotlin
    /** Plan D8: an onion download on a direct route would send the name to DNS. */
    @Test fun `an onion download is refused on a direct route only`() {
        assertTrue(refusesOnionDownload(Route.Direct, "http://abc.onion/file.pdf"))
        assertTrue(refusesOnionDownload(Route.Direct, "https://ABC.ONION./file.pdf"))
        assertFalse(refusesOnionDownload(Route.Direct, "https://example.com/file.pdf"))
        assertFalse(refusesOnionDownload(Route.Tor("/s", ProxyLogin("u", "p")), "http://abc.onion/file.pdf"))
        assertFalse(refusesOnionDownload(Route.Proxy("127.0.0.1", 9050, socks = true), "http://abc.onion/file.pdf"))
    }
```

Add `import org.junit.Assert.assertFalse` and `import org.junit.Assert.assertTrue` to `DownloadFailureTest.kt` if it lacks them.

- [ ] **Step 3: Run them and see them fail**

Run: `(cd android && ./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.StreamSocketTest" --tests "com.mono.container.engine.RouterTest" --tests "com.mono.container.engine.LoopbackRequestTest" --tests "com.mono.container.engine.DownloadFailureTest")`
Expected: FAIL, compilation errors (`StreamSocket`, `Route.Tor`, `over`, `refusesOnionDownload`, `TOR_FAILED` unresolved).

- [ ] **Step 4: Write `StreamSocket.kt`**

Create `android/app/src/main/kotlin/com/mono/container/engine/StreamSocket.kt`:

```kotlin
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
 */
class StreamSocket(
    private val input: InputStream,
    private val output: OutputStream,
    private val closeChannel: () -> Unit,
    private val setTimeout: (Int) -> Unit = {},
) : Socket() {
    @Volatile private var closed = false
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
    return StreamSocket(local.inputStream, local.outputStream, local::close) { local.soTimeout = it }
}
```

- [ ] **Step 5: Split the SOCKS5 handshake out**

Replace the whole of `Socks5Tunnel.kt` with:

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
 * route uses it, logged in or not (ruling 1), and so does built-in Tor, over
 * its Unix socket ([over], built-in Tor spec §4.4).
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
        val request = request(targetHost, targetPort, login)
        val socket = Socket()
        try {
            socket.connect(InetSocketAddress(proxyHost, proxyPort), TIMEOUT_MS)
            handshake(socket, request)
            return socket
        } catch (error: Throwable) {
            // As HttpConnectTunnel: never leak a half-open socket to the proxy.
            runCatching { socket.close() }
            throw error
        }
    }

    /** The same handshake on [socket], already connected to a SOCKS5 proxy. Closes it on any failure. */
    fun over(socket: Socket, targetHost: String, targetPort: Int, login: ProxyLogin? = null): Socket {
        try {
            handshake(socket, request(targetHost, targetPort, login))
            return socket
        } catch (error: Throwable) {
            runCatching { socket.close() }
            throw error
        }
    }

    private class Request(val user: ByteArray?, val password: ByteArray?, val host: ByteArray, val port: Int)

    private fun request(targetHost: String, targetPort: Int, login: ProxyLogin?): Request {
        val user = login?.user?.toByteArray(Charsets.UTF_8)
        val password = login?.password?.toByteArray(Charsets.UTF_8)
        if (user != null && password != null && (user.isEmpty() || user.size > 255 || password.size > 255)) {
            throw ProxyLoginRejectedException("the login cannot be sent to a SOCKS5 proxy")
        }
        val host = targetHost.removeSurrounding("[", "]").toByteArray(Charsets.UTF_8)
        if (host.isEmpty() || host.size > 255) throw IOException("the target cannot be named to a SOCKS5 proxy")
        return Request(user, password, host, targetPort)
    }

    private fun handshake(socket: Socket, request: Request) {
        socket.soTimeout = TIMEOUT_MS
        val input = DataInputStream(socket.getInputStream())
        val out = socket.getOutputStream()
        val user = request.user
        val password = request.password

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

        val host = request.host
        val port = request.port
        out.write(
            byteArrayOf(5, 1, 0, 3, host.size.toByte()) + host +
                byteArrayOf((port shr 8).toByte(), port.toByte())
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
    }
}
```

- [ ] **Step 6: `Route.Tor` and the router**

In `Router.kt`:

1. In `enum class RouteFailure`, after `PROXY_LOGIN_REJECTED,` add:

```kotlin
    /** Built-in Tor is off, failed, stalled or was let go of (built-in Tor spec §4.3). Never direct. */
    TOR_FAILED,
```

and in `EngineChannel.kt`'s `routeFailureToDartName`, after `"PROXY_LOGIN_REJECTED" -> "proxyLoginRejected"`, add `"TOR_FAILED" -> "torFailed"`.

2. In `sealed class Route`, after `data class Proxy(…)`, add:

```kotlin
    /** Built-in Tor (spec §4.4): its Unix SOCKS socket, and the site's own login, so its own circuit (§5.2). */
    data class Tor(val socketPath: String, val login: ProxyLogin) : Route()
```

3. Replace `fun resolve(config: SiteConfig, proxyReachable: Boolean): Route {` and its first line with:

```kotlin
    /**
     * [proxyReachable] is, for a Tor site, whether built-in Tor is ready; and
     * [torSocket] its socket. A Tor site always sends its per-site login,
     * whatever login was typed (spec §5.2).
     */
    fun resolve(config: SiteConfig, proxyReachable: Boolean, torSocket: String? = null): Route {
        if (config.proxyMode == "direct") return Route.Direct

        if (config.proxyMode == "tor") {
            if (!proxyReachable || torSocket == null) return Route.Refused(RouteFailure.TOR_FAILED)
            return Route.Tor(torSocket, perSiteLogin(config.profileId))
        }
```

(The rest of `resolve` — the `socks5`/`http` check onwards — stays as it is. Change its comment's first sentence "Only these two proxy modes exist." to "Only these two upstream proxy modes exist besides Tor.")

4. Replace `connect`'s signature and its `when` with:

```kotlin
    fun connect(
        route: Route,
        targetHost: String,
        targetPort: Int,
        systemProxy: () -> SystemProxy? = SystemProxies.current,
        local: (String) -> java.net.Socket = ::localSocket,
    ): java.net.Socket =
        when (route) {
            is Route.Direct -> systemProxyFor(systemProxy(), targetHost)
                ?.let { HttpConnectTunnel.open(it.host, it.port, targetHost, targetPort) }
                ?: java.net.Socket(targetHost, targetPort)
            is Route.Proxy ->
                if (route.socks) Socks5Tunnel.open(route.host, route.port, targetHost, targetPort, route.login)
                else HttpConnectTunnel.open(route.host, route.port, targetHost, targetPort, route.login)
            is Route.Tor -> Socks5Tunnel.over(local(route.socketPath), targetHost, targetPort, route.login)
            is Route.Refused -> error("connect() called for a refused route")
        }
```

and add to `connect`'s doc comment, after the SOCKS/HTTP paragraph: `A Tor route goes through [Socks5Tunnel] too, over Tor's Unix socket ([local]).`

5. Replace `SiteConfig.currentRoute()` with:

```kotlin
/**
 * Resolves a site's live route consistently for pages and downloads. A Tor
 * site's is Tor's state now, read without waiting (spec §4.3): ready, or
 * refused.
 */
fun SiteConfig.currentRoute(): Route =
    if (proxyMode == "tor") Router.resolve(this, Tor.runtime?.isReady == true, Tor.socketPath)
    else Router.resolve(this, ProxyProbe.reachable(proxyHost ?: "", proxyPort ?: -1))
```

- [ ] **Step 7: The loopback proxy refuses an onion host on Direct**

In `LoopbackRequest.kt`'s `decide`, after `val binding = lookup(user, password) ?: return ProxyDecision.Reply(403)`, add:

```kotlin
    // Built-in Tor spec §5.3: an onion name on a direct route is never looked
    // up nor sent anywhere, and does not start Tor.
    if (binding.config.proxyMode == "direct" && isOnionHost(host)) return ProxyDecision.Reply(403)
```

- [ ] **Step 8: Downloads**

In `DownloadFetcher.kt`:

1. After `downloadFailureFor`, add:

```kotlin
/** Plan D8: a download from an onion address on a direct route would send the name to DNS. */
internal fun refusesOnionDownload(route: Route, url: String): Boolean =
    route is Route.Direct && isOnionHost(runCatching { java.net.URI(url).host }.getOrNull() ?: "")
```

2. In `run`, after `if (route is Route.Refused) return DownloadOutcome.Failed(route.failure)`, add:

```kotlin
        if (refusesOnionDownload(route, pending.url)) return DownloadOutcome.Failed(null)
```

3. In `run`'s `"saveToDevice" -> when (route)`, replace `is Route.Proxy -> runCatching { saveViaMediaStore(route, pending, request, fileName) }` with `is Route.Proxy, is Route.Tor -> runCatching { saveViaMediaStore(route, pending, request, fileName) }` (the `.getOrElse` line under it stays).

- [ ] **Step 9: Run the tests and see them pass**

Run: `(cd android && ./gradlew :app:testDebugUnitTest)`
Expected: PASS, every test (K0 + Task 1's 26 + this task's 3 + 4 + 2 + 1 = K0 + 36), 0 failures, read from the XML. `Socks5TunnelTest` still passes unchanged; `RouteFailureNameTest`'s one test passes with its new entry.

- [ ] **Step 10: Build and commit**

Run `flutter build apk --debug`. Expected: zero `e:` lines.

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/StreamSocket.kt android/app/src/main/kotlin/com/mono/container/engine/Socks5Tunnel.kt android/app/src/main/kotlin/com/mono/container/engine/Router.kt android/app/src/main/kotlin/com/mono/container/engine/LoopbackRequest.kt android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt android/app/src/test/kotlin/com/mono/container/engine/StreamSocketTest.kt android/app/src/test/kotlin/com/mono/container/engine/RouterTest.kt android/app/src/test/kotlin/com/mono/container/engine/LoopbackRequestTest.kt android/app/src/test/kotlin/com/mono/container/engine/DownloadFailureTest.kt android/app/src/test/kotlin/com/mono/container/engine/RouteFailureNameTest.kt
git commit -m "feat(tor): Route.Tor over a Unix socket; onion hosts never go direct"
```

---

### Task 3: Device spike — Tor over the Unix socket, with TLS

The spec's §4.4 risk: does the library run with a Unix SOCKS port (plan D2), does the `StreamSocket` carry TLS on Android's provider, and does Tor start again after a stop? Nothing later is worth building if not. This test stays in the tree as the plan's device check of the engine path.

**Files:**
- Create: `android/app/src/androidTest/kotlin/com/mono/container/engine/TorSpikeTest.kt`

**Interfaces:**
- Consumes: `TorRuntime`, `TorServiceDaemon`, `TorFiles`, `Router.resolve`, `ProxyHttpClient.fetch` (existing: `fetch(route, host, port, secure, method, path, requestHeaders): FetchedResponse`).

- [ ] **Step 1: Write the instrumented test**

Create `android/app/src/androidTest/kotlin/com/mono/container/engine/TorSpikeTest.kt`:

```kotlin
package com.mono.container.engine

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.net.InetSocketAddress
import java.net.Socket

/**
 * Built-in Tor spec §4.4's spike, on a device against the real Tor network:
 * tor-android with a Unix SOCKS port, TLS over [StreamSocket] on Android's
 * provider, no TCP listener of ours, and a second start after a stop.
 */
@RunWith(AndroidJUnit4::class)
class TorSpikeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    private fun onMain(block: () -> Unit) = instrumentation.runOnMainSync(block)

    private fun site() = SiteConfig(
        siteId = "spike", profileId = "spike-profile", url = "https://check.torproject.org",
        proxyMode = "tor", proxyHost = null, proxyPort = null,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    private fun listening(port: Int) = runCatching {
        Socket().use { it.connect(InetSocketAddress("127.0.0.1", port), 500) }
        true
    }.getOrDefault(false)

    private fun isTorBody(): String {
        val route = Router.resolve(site(), proxyReachable = true, torSocket = TorFiles.socket(context.filesDir).absolutePath)
        val response = ProxyHttpClient.fetch(route, "check.torproject.org", 443, true, "GET", "/api/ip", emptyMap())
        return response.body.readBytes().toString(Charsets.UTF_8)
    }

    @Test(timeout = 600_000)
    fun torRunsOverItsUnixSocketCarriesTlsAndStartsAgain() {
        val runtime = TorRuntime(TorServiceDaemon(context))
        onMain { runtime.hold("spike") }
        assertTrue("Tor did not bootstrap", runtime.awaitReady("spike"))

        // Plan D3: neither of the library's default TCP ports is open.
        assertFalse("9050 is listening", listening(9050))
        assertFalse("8118 is listening", listening(8118))

        val body = isTorBody()
        assertTrue(body, body.contains("\"IsTor\":true"))

        onMain { runtime.release("spike") }
        Thread.sleep(5_000)

        onMain { runtime.hold("spike") }
        assertTrue("Tor did not bootstrap a second time", runtime.awaitReady("spike"))
        val again = isTorBody()
        assertTrue(again, again.contains("\"IsTor\":true"))
        onMain { runtime.release("spike") }
    }
}
```

- [ ] **Step 2: Build the app and the test APK**

Run (sandbox disabled):

```bash
flutter build apk --debug
(cd android && ./gradlew :app:assembleDebugAndroidTest)
```

Expected: both succeed; zero `e:` lines.

- [ ] **Step 3: Run it on the emulator, keeping the app's data**

An emulator must be running (`adb devices` lists it; start the `Pixel_9` AVD if not). Do **not** use `connectedDebugAndroidTest`: it uninstalls the app afterwards, which deletes the emulator's test vault. Install both APKs with data kept and run the one test:

```bash
adb install -r -t build/app/outputs/flutter-apk/app-debug.apk
adb install -r -t build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb shell am instrument -w -e class com.mono.container.engine.TorSpikeTest com.mono.container.test/androidx.test.runner.AndroidJUnitRunner
```

If `adb install` cannot find the test APK at that path, list `build/app/outputs/apk/androidTest/` and use the file there.

Expected: `OK (1 test)`. Record the time it took and paste the output in the report.

- [ ] **Step 4: If it fails, stop**

If the output shows a crash (`FATAL EXCEPTION` in `adb logcat -d | grep -A20 "FATAL EXCEPTION"`), a `NumberFormatException` from `TorService`, a TLS error, or a failed second start, do **not** change the design to make it pass. Report **BLOCKED** with the instrument output and the relevant `logcat` lines; the controller rules on the spec's fallback (§4.4: a random localhost TCP port with a random SOCKS password).

- [ ] **Step 5: Commit**

```bash
git add android/app/src/androidTest/kotlin/com/mono/container/engine/TorSpikeTest.kt
git commit -m "test(tor): device spike, Tor over its Unix socket with TLS"
```

---

### Task 4: The engine holds Tor, reports its progress, and panic wipes it

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/TorRuntime.kt` (add `routeForOpen`)
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/SiteConfig.kt` (add `withTorShields`)
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/MainActivity.kt`
- Test: `TorRuntimeTest.kt` (extend); `TorShieldsTest.kt` (create)

**Interfaces:**
- Consumes: Task 1's `TorRuntime`, `Tor`, `TorFiles`, `TorWipe`; Task 2's `Router.resolve(…, torSocket)`, `RouteFailure.TOR_FAILED`.
- Produces: `fun routeForOpen(config: SiteConfig, tor: TorRuntime?, socketPath: String?, onProgress: (Int) -> Unit, resolve: () -> Route = { config.currentRoute() }): Route`; `fun SiteConfig.withTorShields(): SiteConfig`; the event `{"type": "tor_progress", "percent": Int}` on `com.mono.container/sessions`. (The failure name `torFailed` comes from Task 2.)

- [ ] **Step 1: Write the failing tests**

Append to `TorRuntimeTest.kt`, inside the class:

```kotlin
    private fun torSite(siteId: String = "a") = SiteConfig(
        siteId = siteId, profileId = "p-$siteId", url = "https://check.torproject.org",
        proxyMode = "tor", proxyHost = null, proxyPort = null,
        blockWebRtc = true, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    @Test fun `an open of another route resolves as it always has`() {
        val direct = torSite().copy(proxyMode = "direct")
        assertEquals(Route.Direct, routeForOpen(direct, null, null, {}) { Route.Direct })
    }

    @Test fun `a Tor open waits, hears the percentage, and gets Tor's route`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val heard = mutableListOf<Int>()
        val answer = AtomicReference<Route?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(routeForOpen(torSite(), runtime, "/s", { synchronized(heard) { heard += it } }))
            done.countDown()
        }.start()

        tor.events!!.progress(60)
        eventually { synchronized(heard) { 60 in heard } }
        tor.events!!.progress(100)

        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertEquals(Route.Tor("/s", perSiteLogin("p-a")), answer.get())
    }

    @Test fun `a Tor open whose Tor fails is refused, never direct`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val answer = AtomicReference<Route?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(routeForOpen(torSite(), runtime, "/s", {}))
            done.countDown()
        }.start()

        tor.events!!.failed()

        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), answer.get())
    }

    /** Review Focus 1: a lock (stopAll) while the open waits. */
    @Test fun `a Tor open let go of while it waits is refused`() {
        val tor = FakeTor()
        val runtime = runtime(tor)
        runtime.hold("a")
        val answer = AtomicReference<Route?>(null)
        val done = CountDownLatch(1)
        Thread {
            answer.set(routeForOpen(torSite(), runtime, "/s", {}))
            done.countDown()
        }.start()

        runtime.stopAll()

        assertTrue(done.await(5, TimeUnit.SECONDS))
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), answer.get())
    }

    @Test fun `a Tor open with no Tor installed is refused`() {
        assertEquals(Route.Refused(RouteFailure.TOR_FAILED), routeForOpen(torSite(), null, null, {}))
    }
```

Create `android/app/src/test/kotlin/com/mono/container/engine/TorShieldsTest.kt`:

```kotlin
package com.mono.container.engine

import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test

/** Built-in Tor spec §5.4: on Tor, WebRTC is always blocked. */
class TorShieldsTest {
    private fun site(mode: String, blockWebRtc: Boolean) = SiteConfig(
        siteId = "s", profileId = "p", url = "https://example.com",
        proxyMode = mode, proxyHost = null, proxyPort = null,
        blockWebRtc = blockWebRtc, blockTrackers = true, antiFingerprinting = true,
        allowCamera = false, allowMicrophone = false, allowLocation = false,
        allowClipboard = false, userAgentMode = "android", forceDark = true,
        pageZoom = 100, customCss = "", customJs = "", wipeOnExit = false,
    )

    @Test fun `a Tor site blocks WebRTC whatever was stored`() {
        assertTrue(site("tor", blockWebRtc = false).withTorShields().blockWebRtc)
    }

    @Test fun `any other site keeps its own choice`() {
        val direct = site("direct", blockWebRtc = false)
        assertSame(direct, direct.withTorShields())
        assertFalse(direct.withTorShields().blockWebRtc)
    }
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `(cd android && ./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.TorRuntimeTest" --tests "com.mono.container.engine.TorShieldsTest")`
Expected: FAIL to compile (`routeForOpen`, `withTorShields` unresolved).

- [ ] **Step 3: `routeForOpen` and `withTorShields`**

Append to `TorRuntime.kt`:

```kotlin
/**
 * The route an open decides (built-in Tor spec §4.3). A Tor site first waits
 * for Tor, hearing its percentage; Tor that fails, stalls or is let go of is
 * refused, never direct. Any other site resolves as before. Blocks: never on
 * the main thread.
 */
fun routeForOpen(
    config: SiteConfig,
    tor: TorRuntime?,
    socketPath: String?,
    onProgress: (Int) -> Unit,
    resolve: () -> Route = { config.currentRoute() },
): Route {
    if (config.proxyMode != "tor") return resolve()
    if (tor == null || socketPath == null || !tor.awaitReady(config.siteId, onProgress)) {
        return Route.Refused(RouteFailure.TOR_FAILED)
    }
    return Router.resolve(config, proxyReachable = true, torSocket = socketPath)
}
```

Append to `SiteConfig.kt`, after `data class SiteConfig(…)`:

```kotlin
/** Built-in Tor spec §5.4: on Tor, WebRTC is always blocked, whatever the site stored. */
fun SiteConfig.withTorShields(): SiteConfig =
    if (proxyMode == "tor" && !blockWebRtc) copy(blockWebRtc = true) else this
```

- [ ] **Step 4: Wire the engine channel**

In `EngineChannel.kt`:

1. In `open`, replace `val config = configFrom(call).let { if (throwaway) it.copy(wipeOnExit = true) else it }` with:

```kotlin
        val config = configFrom(call).withTorShields().let { if (throwaway) it.copy(wipeOnExit = true) else it }
```

2. In `open`, after the `if (!profiles.isAvailable()) { … return }` block and before `val ticket = pendingOpens.begin(config.siteId)`, add:

```kotlin
        // Built-in Tor spec §4.2: this site needs Tor from now until it
        // closes; on any other route it lets go. Without the proxy override a
        // Tor site is refused anyway (routeAtOpen), so Tor is not started.
        if (config.proxyMode == "tor" && proxyOverride) Tor.runtime?.hold(config.siteId)
        else Tor.runtime?.release(config.siteId)
```

3. In `open`, replace

```kotlin
            val route = runCatching { routeAtOpen(config, proxyOverride, awaitOverride) { config.currentRoute() } }
```

with

```kotlin
            val route = runCatching {
                routeAtOpen(config, proxyOverride, awaitOverride) {
                    routeForOpen(config, Tor.runtime, Tor.socketPath, ::emitTorProgress)
                }
            }
```

4. In `close`, after `pendingOpens.cancel(siteId)`, add:

```kotlin
        // An open still waiting for Tor stops waiting; the last Tor site stops Tor.
        Tor.runtime?.release(siteId)
```

5. Replace `closeAll` with:

```kotlin
    /** Tabs spec §5.8: every lock, and panic's first step. Tor stops too, opens still waiting for it included (spec §4.2). */
    private fun closeAll() {
        pendingOpens.cancelAll()
        for (siteId in sessions.keys.toList()) close(siteId)
        Tor.runtime?.stopAll()
    }
```

6. In `wipeAll`, after `throwaways.clear()`, add `wipeTorState()`, and add these after `wipeAll`:

```kotlin
    /**
     * Panic's part for Tor (spec §4.5, plan D4): Tor stopped by [closeAll],
     * its state deleted, and deleted again once its own shutdown has had time
     * to write it. The marker makes the next start delete it once more.
     */
    private fun wipeTorState() {
        val wipe = {
            TorWipe.wipe(
                TorFiles.all(context.filesDir, context.dataDir, context.cacheDir),
                TorFiles.wipeMarker(context.filesDir),
            )
        }
        runCatching(wipe)
        mainHandler.postDelayed({ networkExecutor.execute { runCatching(wipe) } }, TOR_REWIPE_DELAY_MS)
    }

    /** Built-in Tor spec §7: `8a` shows Tor's own percentage while it starts. */
    private fun emitTorProgress(percent: Int) {
        mainHandler.post { sink?.success(mapOf("type" to "tor_progress", "percent" to percent)) }
    }
```

7. In `companion object`, add `const val TOR_REWIPE_DELAY_MS = 5_000L`.

(`routeFailureToDartName` already names `TOR_FAILED`: Task 2 Step 6.)

- [ ] **Step 5: Install Tor at start**

In `MainActivity.configureFlutterEngine`, after `profiles.sweepThrowaways(throwaways) { deleteDownloadsDir(applicationContext, it) }`, add:

```kotlin
        // Before Tor can run: a panic's wipe that Tor's own shutdown may have
        // undone is finished (built-in Tor plan D4). Then the process's one Tor.
        TorWipe.sweep(
            TorFiles.all(applicationContext.filesDir, applicationContext.dataDir, applicationContext.cacheDir),
            TorFiles.wipeMarker(applicationContext.filesDir),
        )
        Tor.install(applicationContext)
```

and add the imports `com.mono.container.engine.Tor`, `com.mono.container.engine.TorFiles`, `com.mono.container.engine.TorWipe`. `Tor` is `internal` in the same module, so it is visible here.

- [ ] **Step 6: Run the tests and see them pass**

Run: `(cd android && ./gradlew :app:testDebugUnitTest)`
Expected: PASS, K0 + 36 + 5 + 2 = K0 + 43, 0 failures, read from the XML.

- [ ] **Step 7: Build and commit**

Run `flutter build apk --debug`. Expected: zero `e:` lines.

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/TorRuntime.kt android/app/src/main/kotlin/com/mono/container/engine/SiteConfig.kt android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt android/app/src/main/kotlin/com/mono/container/MainActivity.kt android/app/src/test/kotlin/com/mono/container/engine/TorRuntimeTest.kt android/app/src/test/kotlin/com/mono/container/engine/TorShieldsTest.kt
git commit -m "feat(tor): the engine holds Tor per site, reports its progress, and panic wipes it"
```

---

### Task 5: Dart — `ProxyMode.tor`, the onion rules, the copy, the route names

**Files:**
- Create: `lib/domain/onion.dart`, `lib/domain/models/route_display.dart`
- Modify: `lib/domain/models/site.dart:8`, `proxy_route.dart`, `route_decision.dart`, `route_failure_copy.dart`, `site_descriptor.dart`, `open_step.dart`, `destination.dart`, `lib/domain/tabs.dart:116`, `lib/ui/features/add_site/view_models/add_site_view.dart`, `lib/ui/features/container/views/container_route.dart` (three label call sites and `_proxyDescriptor`)
- Test: create `test/domain/onion_test.dart`, `test/domain/route_display_test.dart`, `test/ui/features/add_site_tor_test.dart`; extend `test/domain/proxy_route_test.dart`, `route_decision_test.dart`, `route_failure_copy_test.dart`, `site_descriptor_test.dart`, `open_step_test.dart`, `destination_test.dart`, `address_suggestion_test.dart`

**Interfaces:**
- Produces: `ProxyMode.tor`; `bool isOnionHost(String host)`; `ProxyRoute.tor`; `RouteFailure.torFailed`; `class RouteTor extends RouteDecision`; `String torStepLabel(int? percent)`; `List<OpenStep> openStepsFor(Site site, {int? torPercent})`; in `route_display.dart`: `String topBarRouteLabel(ProxyMode mode)`, `String switcherRouteName(ProxyMode mode)`, `String proxyDescriptor(Site site)`, `String tunnelDescriptor(Site site)`, `bool canOpenWithoutTunnel(Site site)`, `bool webRtcLocked(ProxyMode mode)`.

- [ ] **Step 1: Write the failing tests**

Create `test/domain/onion_test.dart`:

```dart
import 'package:container/domain/onion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Review Focus 4.
  test('an onion host is one in any case, with or without a trailing dot', () {
    expect(isOnionHost('duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion'), isTrue);
    expect(isOnionHost('ABC.ONION.'), isTrue);
    expect(isOnionHost('www.abc.onion'), isTrue);
    expect(isOnionHost('onion'), isTrue);
  });

  test('other hosts are not', () {
    expect(isOnionHost('onion.example.com'), isFalse);
    expect(isOnionHost('example.com'), isFalse);
    expect(isOnionHost('notonion'), isFalse);
    expect(isOnionHost(''), isFalse);
  });
}
```

Create `test/domain/route_display_test.dart`:

```dart
import 'package:container/domain/models/route_display.dart';
import 'package:container/domain/models/site.dart';
import 'package:flutter_test/flutter_test.dart';

Site _site(ProxyMode mode, {String url = 'https://forum.example.com', String? host, int? port}) => Site(
      id: 's', workspaceId: 'w', name: 'Forum', monogram: 'Fr', url: url,
      profileId: 'p', proxyMode: mode, proxyHost: host, proxyPort: port,
    );

void main() {
  // Plan D6: Tor is a name, so it reads `Tor` wherever a route is named.
  test('the top bar names no direct route, Tor as Tor, and proxies in capitals', () {
    expect(topBarRouteLabel(ProxyMode.direct), '');
    expect(topBarRouteLabel(ProxyMode.socks5), 'SOCKS5');
    expect(topBarRouteLabel(ProxyMode.http), 'HTTP');
    expect(topBarRouteLabel(ProxyMode.tor), 'Tor');
  });

  test("2c's line names Tor as Tor and the rest as before", () {
    expect(switcherRouteName(ProxyMode.socks5), 'socks5');
    expect(switcherRouteName(ProxyMode.direct), 'direct');
    expect(switcherRouteName(ProxyMode.tor), 'Tor');
  });

  test("6c's proxy row", () {
    expect(proxyDescriptor(_site(ProxyMode.direct)), 'Direct');
    expect(proxyDescriptor(_site(ProxyMode.socks5, host: '127.0.0.1', port: 9050)), 'SOCKS5 · 127.0.0.1:9050');
    expect(proxyDescriptor(_site(ProxyMode.http, host: 'proxy.lan', port: 3128)), 'HTTP · proxy.lan:3128');
    expect(proxyDescriptor(_site(ProxyMode.tor)), 'Tor');
  });

  test("8b's Tunnel row", () {
    expect(tunnelDescriptor(_site(ProxyMode.tor)), 'Tor');
    expect(tunnelDescriptor(_site(ProxyMode.socks5, host: '127.0.0.1', port: 9050)), 'socks5 · 127.0.0.1:9050');
    expect(tunnelDescriptor(_site(ProxyMode.socks5)), 'no proxy');
  });

  // Spec §5.6.
  test('an onion address is never offered without the tunnel; any other is', () {
    expect(canOpenWithoutTunnel(_site(ProxyMode.tor, url: 'http://abc.onion/')), isFalse);
    expect(canOpenWithoutTunnel(_site(ProxyMode.tor)), isTrue);
    expect(canOpenWithoutTunnel(_site(ProxyMode.socks5, host: 'h', port: 1)), isTrue);
  });

  // Spec §5.4.
  test('WebRTC is locked on Tor only', () {
    expect(webRtcLocked(ProxyMode.tor), isTrue);
    for (final mode in [ProxyMode.direct, ProxyMode.socks5, ProxyMode.http]) {
      expect(webRtcLocked(mode), isFalse);
    }
  });
}
```

Create `test/ui/features/add_site_tor_test.dart`:

```dart
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/add_site/view_models/add_site_view.dart';
import 'package:flutter_test/flutter_test.dart';

Site _build({required String url, ProxyMode mode = ProxyMode.direct, String? host, int? port}) => buildSite(
      initial: null, url: url, name: 'Hidden', monogram: 'Hd', workspaceId: 'w',
      cookiePolicy: CookiePolicy.keep, proxyMode: mode, proxyHost: host, proxyPort: port,
      blockWebRtc: true, blockTrackers: true, antiFingerprinting: true,
      allowCamera: false, allowMicrophone: false, allowLocation: false, allowClipboard: false,
      requirePin: false, showInDecoy: false, userAgentMode: UserAgentMode.android,
      forceDark: true, openInReader: false, pageZoom: 100, customCss: '', customJs: '',
    );

void main() {
  group('buildSite', () {
    test('a Tor site keeps no address and no typed login', () {
      final site = _build(url: 'https://example.com', mode: ProxyMode.tor, host: '127.0.0.1', port: 9050);
      expect(site.proxyMode, ProxyMode.tor);
      expect(site.proxyHost, isNull);
      expect(site.proxyPort, isNull);
      expect(site.proxyUser, isNull);
    });

    // Spec §5.3, plan D7.
    test('an onion address is never saved on Direct', () {
      final site = _build(url: 'http://abc.onion/');
      expect(site.proxyMode, ProxyMode.tor);
      expect(site.proxyHost, isNull);
    });

    test('an onion address on a proxy keeps that proxy', () {
      final site = _build(url: 'http://abc.onion/', mode: ProxyMode.socks5, host: '127.0.0.1', port: 9050);
      expect(site.proxyMode, ProxyMode.socks5);
      expect(site.proxyPort, 9050);
    });
  });
}
```

Add to `test/domain/proxy_route_test.dart`, inside `main()` (add `import 'package:container/domain/models/proxy_route.dart';` and `site.dart` if missing):

```dart
  group('Tor', () {
    test('a Tor form keeps no address and no login', () {
      expect(
        ProxyRoute.fromForm(mode: ProxyMode.tor, host: '127.0.0.1', port: 9050, user: 'u', password: 'p'),
        ProxyRoute.tor,
      );
    });

    test('it reads as Tor', () => expect(ProxyRoute.tor.label, 'Tor'));

    test('it is stored and read back', () {
      expect(ProxyRoute.fromStored(ProxyRoute.tor.toStored()), ProxyRoute.tor);
    });
  });
```

Add to `test/domain/route_decision_test.dart`, inside `main()` (it builds sites with its own helper; build a Tor site with `Site(id: 's', workspaceId: 'w', name: 'n', monogram: 'Nn', url: 'https://a.example', profileId: 'p', proxyMode: ProxyMode.tor)`):

```dart
  group('Tor', () {
    const site = Site(
      id: 's', workspaceId: 'w', name: 'n', monogram: 'Nn',
      url: 'https://a.example', profileId: 'p', proxyMode: ProxyMode.tor,
    );

    test('Tor up routes through Tor', () {
      expect(resolveRoute(site, proxyReachable: true), isA<RouteTor>());
    });

    test('Tor down is refused as torFailed, never direct', () {
      final decision = resolveRoute(site, proxyReachable: false);
      expect((decision as RouteRefused).failure, RouteFailure.torFailed);
    });

    test('its refusal reads Tor did not connect', () {
      expect(refusalMessage(RouteFailure.torFailed), 'Tor did not connect');
    });
  });
```

Add to `test/domain/route_failure_copy_test.dart`, inside `main()`:

```dart
  test("Tor's failure has the approved headline and sentence", () {
    // Built-in Tor spec §7, approved word for word on 2026-10-04.
    expect(proxyFailureHeadline(RouteFailure.torFailed), 'Tor did not connect');
    expect(
      proxyFailureDetail(RouteFailure.torFailed, siteName: 'Forum', tunnelDescriptor: 'Tor'),
      'Forum is set to go through Tor, which could not reach the Tor network. '
      'The page was not loaded, so no request left your device.',
    );
  });
```

Add to `test/domain/site_descriptor_test.dart`, inside `main()` (it has a site helper; if its helper cannot set the mode, build a `Site` inline with `proxyMode: ProxyMode.tor`):

```dart
  test('a Tor site reads tor, like its lowercase siblings', () {
    const site = Site(
      id: 's', workspaceId: 'w', name: 'n', monogram: 'Nn',
      url: 'https://a.example', profileId: 'p', proxyMode: ProxyMode.tor,
    );
    expect(siteDescriptor(site), 'tor');
  });
```

Add to `test/domain/open_step_test.dart`, inside `main()`:

```dart
  group('Tor', () {
    test('a Tor site connects to Tor, not to an address', () {
      final steps = openStepsFor(_site(mode: ProxyMode.tor));
      expect(steps.last.label, 'Connecting to Tor');
      expect(steps.any((s) => s.label.startsWith('Connecting through')), isFalse);
    });

    test("it shows Tor's own percentage while Tor starts", () {
      expect(openStepsFor(_site(mode: ProxyMode.tor), torPercent: 45).last.label, 'Connecting to Tor · 45%');
    });

    // Review Focus 5: 0 has nothing to say, and 100 is a start already over.
    test('no percentage before a report, at 0 or at 100', () {
      expect(torStepLabel(null), 'Connecting to Tor');
      expect(torStepLabel(0), 'Connecting to Tor');
      expect(torStepLabel(100), 'Connecting to Tor');
      expect(torStepLabel(99), 'Connecting to Tor · 99%');
    });

    test('a percentage is ignored for any other route', () {
      expect(openStepsFor(_site(), torPercent: 45).last.label, 'Connecting through 127.0.0.1:9050');
    });
  });
```

Add to `test/domain/destination_test.dart`, inside `main()`:

```dart
  group('onion addresses (built-in Tor spec §5.3)', () {
    const onion = 'http://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/';

    test('typed on a direct route, one opens as a throwaway on Tor', () {
      final direct = _site('home', 'https://home.example.com');
      final destination = _resolve(onion, current: direct);
      expect(destination, isA<Throwaway>());
      destination as Throwaway;
      expect(destination.mode, ProxyMode.tor);
      expect(destination.proxyHost, isNull);
    });

    test('from the dashboard on a direct default route, too', () {
      final destination =
          destinationFor(Uri.parse(onion), route: ProxyRoute.direct, saved: const []);
      expect((destination as Throwaway).mode, ProxyMode.tor);
    });

    test('on a proxy route it goes to that proxy by name', () {
      final destination = _resolve(onion);
      destination as Throwaway;
      expect(destination.mode, ProxyMode.socks5);
      expect(destination.proxyPort, 9050);
    });

    test('a saved onion site still opens its own container', () {
      final saved = _site('hidden', onion, mode: ProxyMode.tor);
      expect(_resolve(onion, saved: [saved]), isA<SavedSiteContainer>());
    });
  });
```

Add to `test/domain/address_suggestion_test.dart`, inside `main()` (it already imports `address_suggestion.dart` and `destination.dart`; add `site.dart` if needed):

```dart
  test('a throwaway on Tor is tagged THROWAWAY · TOR', () {
    expect(destinationTag(Throwaway(Uri.parse('http://abc.onion/'), ProxyMode.tor, null, null)),
        'THROWAWAY · TOR');
  });
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/domain/onion_test.dart test/domain/route_display_test.dart test/ui/features/add_site_tor_test.dart test/domain/proxy_route_test.dart test/domain/route_decision_test.dart test/domain/route_failure_copy_test.dart test/domain/site_descriptor_test.dart test/domain/open_step_test.dart test/domain/destination_test.dart test/domain/address_suggestion_test.dart`
Expected: FAIL (missing `ProxyMode.tor`, `onion.dart`, `route_display.dart`, …).

- [ ] **Step 3: `ProxyMode.tor` and `isOnionHost`**

In `lib/domain/models/site.dart`, replace `enum ProxyMode { direct, socks5, http }` with:

```dart
/// [tor] is the app's own Tor client (built-in Tor spec §5.1): no address,
/// no typed login.
enum ProxyMode { direct, socks5, http, tor }
```

Create `lib/domain/onion.dart`:

```dart
/// Whether [host] is an onion service's name (built-in Tor spec §5.3): it can
/// be reached only through Tor, so it never goes direct or to DNS. Letter
/// case and one trailing dot change nothing.
bool isOnionHost(String host) {
  final lower = host.toLowerCase();
  final name = lower.endsWith('.') ? lower.substring(0, lower.length - 1) : lower;
  return name == 'onion' || name.endsWith('.onion');
}
```

- [ ] **Step 4: `ProxyRoute`**

In `lib/domain/models/proxy_route.dart`:

1. After `static const unreadable = …;` add:

```dart
  /// Built-in Tor (built-in Tor spec §5.1): no address and no typed login.
  /// The engine gives each site its own login, so its own circuit (§5.2).
  static const tor = ProxyRoute(mode: ProxyMode.tor);
```

2. In `fromForm`, after `if (mode == ProxyMode.direct) return direct;` add `if (mode == ProxyMode.tor) return tor;`.

3. In `label`, after `if (mode == ProxyMode.direct) return 'Direct';` add `if (mode == ProxyMode.tor) return 'Tor';`.

- [ ] **Step 5: The decision and the copy**

In `lib/domain/models/route_decision.dart`:

1. In `enum RouteFailure`, after `proxyLoginRejected,` add:

```dart

  /// Built-in Tor is off, failed, stalled or was let go of (built-in Tor
  /// spec §4.3). Never direct.
  torFailed,
```

2. After `class RouteProxy … {}`, add:

```dart
/// Through built-in Tor (built-in Tor spec §5).
class RouteTor extends RouteDecision {
  const RouteTor();
}
```

3. In `resolveRoute`, after `if (site.proxyMode == ProxyMode.direct) return const RouteDirect();` add:

```dart
  // For a Tor site, [proxyReachable] is whether Tor is up.
  if (site.proxyMode == ProxyMode.tor) {
    return proxyReachable ? const RouteTor() : const RouteRefused(RouteFailure.torFailed);
  }
```

4. In `refusalMessage`, add the arm `RouteFailure.torFailed => 'Tor did not connect',`.

In `lib/domain/models/route_failure_copy.dart`, in `proxyFailureDetail`, after `if (failure == RouteFailure.misconfigured) return null;` add:

```dart
  // Built-in Tor spec §7, approved word for word: Tor is not a tunnel that
  // "did not complete the connection"; it never reached its network.
  if (failure == RouteFailure.torFailed) {
    return '$siteName is set to go through Tor, which could not reach the Tor network. '
        'The page was not loaded, so no request left your device.';
  }
```

- [ ] **Step 6: The descriptor, the checklist and the route names**

In `lib/domain/models/site_descriptor.dart`, add the arm `ProxyMode.tor => 'tor',` to the switch (plan D6).

In `lib/domain/models/open_step.dart`, replace `openStepsFor` with:

```dart
/// The checklist `8a` shows, built from what this site actually applies. Copy
/// is verbatim from the spec; the tunnel line interpolates the real endpoint.
/// [torPercent] is Tor's last reported percentage (built-in Tor spec §7).
List<OpenStep> openStepsFor(Site site, {int? torPercent}) {
  return <OpenStep>[
    const OpenStep('Fresh session, no shared cookies', OpenStepState.pending),
    if (site.blockTrackers)
      const OpenStep('Filter lists loaded', OpenStepState.pending),
    if (site.antiFingerprinting)
      const OpenStep('Fingerprint noise injected', OpenStepState.pending),
    if (site.proxyMode == ProxyMode.tor)
      OpenStep(torStepLabel(torPercent), OpenStepState.pending)
    else if (site.proxyMode != ProxyMode.direct)
      OpenStep('Connecting through ${site.proxyHost}:${site.proxyPort}',
          OpenStepState.pending),
  ];
}

/// Built-in Tor spec §7: Tor's own percentage while it starts. None before
/// its first report, at 0, or at 100, which is a start already over (perhaps
/// an earlier one).
String torStepLabel(int? percent) => percent == null || percent <= 0 || percent >= 100
    ? 'Connecting to Tor'
    : 'Connecting to Tor · $percent%';
```

Create `lib/domain/models/route_display.dart`:

```dart
import '../onion.dart';
import 'site.dart';

// How a route is named on screen, and the two rules Tor adds to it. Tor is a
// name, so it reads `Tor` wherever a route is named (built-in Tor spec §7,
// plan D6); only the all-capitals throwaway tag says `TOR`.

/// The container's top bar. There is no DIRECT label (browser-chrome spec §4.4).
String topBarRouteLabel(ProxyMode mode) => switch (mode) {
      ProxyMode.direct => '',
      ProxyMode.tor => 'Tor',
      ProxyMode.socks5 || ProxyMode.http => mode.name.toUpperCase(),
    };

/// `2c`'s viewed container: `viewing now · socks5`, `viewing now · Tor`.
String switcherRouteName(ProxyMode mode) => mode == ProxyMode.tor ? 'Tor' : mode.name;

/// Spec `6c`'s proxy row: `SOCKS5 · 127.0.0.1:9050`, or `Tor`.
String proxyDescriptor(Site site) => switch (site.proxyMode) {
      ProxyMode.direct => 'Direct',
      ProxyMode.socks5 => 'SOCKS5 · ${site.proxyHost}:${site.proxyPort}',
      ProxyMode.http => 'HTTP · ${site.proxyHost}:${site.proxyPort}',
      ProxyMode.tor => 'Tor',
    };

/// `8b`'s Tunnel row, which its sentence names too.
String tunnelDescriptor(Site site) {
  if (site.proxyMode == ProxyMode.tor) return 'Tor';
  return site.proxyHost == null
      ? 'no proxy'
      : '${site.proxyMode.name} · ${site.proxyHost}:${site.proxyPort}';
}

/// Whether `8b` offers "Open without the tunnel" (spec §5.6): never for an
/// onion address, which cannot go direct and would leak its name.
bool canOpenWithoutTunnel(Site site) => !isOnionHost(site.host);

/// Spec §5.4: on Tor, Block WebRTC is always on, and its switch inert.
bool webRtcLocked(ProxyMode mode) => mode == ProxyMode.tor;
```

In `lib/domain/tabs.dart`, replace `'viewing now · ${c.opened.proxyMode.name}'` with `'viewing now · ${switcherRouteName(c.opened.proxyMode)}'` and add `import 'models/route_display.dart';`.

In `lib/ui/features/container/views/container_route.dart`:

1. Add `import '../../../../domain/models/route_display.dart';`.
2. In `_refusalScreen`, replace the `tunnelDescriptor: opened.proxyHost == null ? 'no proxy' : '${…}',` expression with `tunnelDescriptor: tunnelDescriptor(opened),`.
3. Replace

```dart
        routeLabel: opened.proxyMode == ProxyMode.direct
            ? ''
            : opened.proxyMode.name.toUpperCase(),
```

with `routeLabel: topBarRouteLabel(opened.proxyMode),`.
4. Replace `proxyDescriptor: _proxyDescriptor(site),` with `proxyDescriptor: proxyDescriptor(site),` and delete the private `_proxyDescriptor` function and its doc comment at the end of the file.

- [ ] **Step 7: The onion rules**

In `lib/domain/models/destination.dart`, add `import '../onion.dart';`, and in `destinationFor`, before the final `return Throwaway(url, via.mode, …)`, add:

```dart
  // Built-in Tor spec §5.3: an onion address never goes direct. Typed on a
  // direct route it opens on Tor, whatever the opener's route.
  if (via.mode == ProxyMode.direct && isOnionHost(url.host)) {
    return Throwaway(url, ProxyMode.tor, null, null);
  }
```

In `lib/ui/features/add_site/view_models/add_site_view.dart`, add `import '../../../../domain/onion.dart';`, and in `buildSite` replace

```dart
  final route = ProxyRoute.fromForm(
```

with `final formRoute = ProxyRoute.fromForm(` (the arguments stay), then replace the lines

```dart
  final blank = name.trim().isEmpty;
  final host = Uri.parse(url).host;
```

with

```dart
  final blank = name.trim().isEmpty;
  final host = Uri.parse(url).host;
  // Built-in Tor spec §5.3, plan D7: an onion address is never saved on Direct.
  final route =
      formRoute.mode == ProxyMode.direct && isOnionHost(host) ? ProxyRoute.tor : formRoute;
```

- [ ] **Step 8: Run the tests and see them pass**

Run the command from Step 2. Expected: PASS. Then `flutter analyze`. Expected: `No issues found!` (every `switch` over `ProxyMode` is exhaustive; the analyzer names any it finds).

- [ ] **Step 9: Run the whole suite**

Run: `flutter test`. Expected: all pass, F0 + this task's new tests (2 + 6 + 3 + 3 + 3 + 1 + 1 + 4 + 4 + 1 = 28).

- [ ] **Step 10: Commit**

```bash
git add lib/domain test/domain lib/ui/features/add_site/view_models/add_site_view.dart lib/ui/features/container/views/container_route.dart test/ui/features/add_site_tor_test.dart
git commit -m "feat(tor): ProxyMode.tor, onion rules, Tor's copy and route names"
```

---

### Task 6: Dart — Tor's progress on `8a`, `8b` without the way direct for an onion, `6c`'s locked WebRTC

**Files:**
- Modify: `lib/data/services/container_engine.dart`, `container_engine_channel.dart`, `fake_container_engine.dart`
- Modify: `lib/ui/features/container/view_models/providers.dart`
- Modify: `lib/ui/features/container/views/container_route.dart`
- Modify: `lib/ui/features/in_page/views/proxy_unreachable_screen.dart`, `site_sheet.dart`
- Test: `test/data/container_engine_channel_test.dart`, `test/ui/features/in_page/proxy_unreachable_screen_test.dart`, `test/ui/features/in_page/site_sheet_test.dart`, `test/ui/features/container_route_test.dart`

**Interfaces:**
- Consumes: Task 4's `tor_progress` event and `torFailed` name; Task 5's `torStepLabel`, `openStepsFor(site, torPercent:)`, `canOpenWithoutTunnel`, `webRtcLocked`, `RouteFailure.torFailed`.
- Produces: `Stream<int> ContainerEngine.torProgress()`; `int torProgressFromEvent(Map<Object?, Object?> event)`; `FakeContainerEngine.emitTorProgress(int percent)`; `torProgressProvider` (`StreamProvider<int>`); `ProxyUnreachableScreen.onOpenWithoutTunnel` and `SiteSheet.onBlockWebRtcChanged` nullable.

- [ ] **Step 1: Write the failing tests**

In `test/data/container_engine_channel_test.dart`, add inside `main()` before `group('over the channels'`:

```dart
  test('a tor_progress event decodes its percentage', () {
    expect(torProgressFromEvent(<String, Object?>{'type': 'tor_progress', 'percent': 45}), 45);
  });

  test("a session refused for Tor decodes as torFailed", () {
    final sessions = sessionsFromEvent(<String, Object?>{
      'sessions': [
        <String, Object?>{
          'siteId': 's1', 'phase': 'refused', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': 'torFailed',
        },
      ],
    });
    expect(sessions.single.failure, RouteFailure.torFailed);
  });
```

and inside `group('over the channels', …)`, after `a page_opened event reaches its own stream`:

```dart
    test('a tor_progress event reaches its own stream', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, sink) {
        sink.success(<String, Object?>{'type': 'tor_progress', 'percent': 60});
      }));
      final engine = ChannelContainerEngine();

      expect(await engine.torProgress().first, 60);
    });

    // Built-in Tor spec §5.4: Dart sends WebRTC blocked for a Tor site, whatever is stored.
    test('open sends WebRTC blocked for a Tor site', () async {
      messenger.setMockStreamHandler(events, MockStreamHandler.inline(onListen: (_, __) {}));
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        return <String, Object?>{
          'siteId': 's1', 'phase': 'opening', 'lastActiveAt': null,
          'blockedCount': 0, 'categoryCounts': <String, Object?>{}, 'failure': null,
        };
      });
      const site = Site(
        id: 's1', workspaceId: 'w', name: 'Forum', monogram: 'Fr',
        url: 'https://forum.example.com', profileId: 'p',
        proxyMode: ProxyMode.tor, blockWebRtc: false,
      );

      await ChannelContainerEngine().open(site);

      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['proxyMode'], 'tor');
      expect(args['blockWebRtc'], isTrue);
    });
```

In `test/ui/features/in_page/proxy_unreachable_screen_test.dart`, change `host`'s parameter to `bool canGoDirect = true` beside the others, pass `onOpenWithoutTunnel: canGoDirect ? (onOpenWithoutTunnel ?? () {}) : null,` (replacing the existing `onOpenWithoutTunnel:` line), and add inside `main()`:

```dart
  testWidgets("Tor's failure shows its own headline and sentence", (tester) async {
    await tester.pumpWidget(host(failure: RouteFailure.torFailed));

    expect(find.text('Tor did not connect'), findsOneWidget);
    expect(
      find.text('Forum is set to go through Tor, which could not reach the Tor network. '
          'The page was not loaded, so no request left your device.'),
      findsOneWidget,
    );
  });

  // Built-in Tor spec §5.6: an onion address cannot go direct.
  testWidgets('with no way direct, Open without the tunnel is not offered', (tester) async {
    await tester.pumpWidget(host(canGoDirect: false));

    expect(find.text('Open without the tunnel'), findsNothing);
    expect(find.text('This site will see your real IP'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Change proxy settings'), findsOneWidget);
  });
```

Note: the `host` helper passes `tunnelDescriptor: 'socks5 · 127.0.0.1:9050'`; the Tor sentence names Tor itself, not the descriptor, so the expectation above holds.

In `test/ui/features/in_page/site_sheet_test.dart`, add a `bool lockWebRtc = false` parameter to its `host` helper and pass `onBlockWebRtcChanged: lockWebRtc ? null : (onBlockWebRtcChanged ?? (_) {}),` (replacing the existing line). Add inside `main()`:

```dart
  // Built-in Tor spec §5.4.
  testWidgets('a locked Block WebRTC is drawn on and inert', (tester) async {
    await tester.pumpWidget(host(blockWebRtc: true, lockWebRtc: true));

    final toggle = tester.widget<AppToggle>(find.descendant(
      of: find.ancestor(of: find.text('Block WebRTC'), matching: find.byType(Row)).first,
      matching: find.byType(AppToggle),
    ));
    expect(toggle.value, isTrue);
    expect(toggle.onChanged, isNull);
  });
```

(If `host` has no `blockWebRtc` parameter, add one defaulting to the value it passes today.)

In `test/ui/features/container_route_test.dart`, add after `opening a site shows the checklist, then the container`:

```dart
  // Built-in Tor spec §7.
  testWidgets("a Tor site's checklist shows Tor's own percentage", (tester) async {
    final engine = _GatedEngine();
    final gate = engine.holdNextOpen();
    await _pump(tester, engine, _site().copyWith(proxyMode: ProxyMode.tor));
    await tester.pumpAndSettle();
    expect(find.text('Connecting to Tor'), findsOneWidget);

    engine.emitTorProgress(45);
    await tester.pump();
    expect(find.text('Connecting to Tor · 45%'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
  });
```

and inside `group('8b, a refused open', …)`, at its end:

```dart
    testWidgets("a Tor site's 8b names Tor and keeps the way direct", (tester) async {
      final engine = FakeContainerEngine(proxyReachable: false);
      await _pump(tester, engine, _site().copyWith(proxyMode: ProxyMode.tor));
      await tester.pumpAndSettle();

      expect(find.text('Tor did not connect'), findsOneWidget);
      expect(find.text('Tor'), findsOneWidget); // the Tunnel row
      expect(find.text('Open without the tunnel'), findsOneWidget);
    });

    // Built-in Tor spec §5.6.
    testWidgets("an onion site's 8b offers no way direct", (tester) async {
      final engine = FakeContainerEngine(proxyReachable: false);
      await _pump(tester, engine, _site().copyWith(
        proxyMode: ProxyMode.tor,
        url: 'http://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Tor did not connect'), findsOneWidget);
      expect(find.text('Open without the tunnel'), findsNothing);
    });
```

and inside the group that defines `pumpOpen` and `openSiteSheet` (the privacy-controls group, around the test `a throwaway's switch writes no row and reopens it as a throwaway, unwiped`), after that test:

```dart
    // Built-in Tor spec §5.4.
    testWidgets("on Tor, 6c's Block WebRTC is on and inert", (tester) async {
      final engine = FakeContainerEngine();
      await pumpOpen(tester, engine, _site().copyWith(proxyMode: ProxyMode.tor, blockWebRtc: false));

      await openSiteSheet(tester);
      await tester.ensureVisible(_sheetToggle('Block WebRTC'));
      await tester.pumpAndSettle();

      final toggle = tester.widget<AppToggle>(_sheetToggle('Block WebRTC'));
      expect(toggle.value, isTrue);
      expect(toggle.onChanged, isNull);
    });
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/data/container_engine_channel_test.dart test/ui/features/in_page/proxy_unreachable_screen_test.dart test/ui/features/in_page/site_sheet_test.dart test/ui/features/container_route_test.dart`
Expected: FAIL (no `torProgress`, `torProgressFromEvent`, `emitTorProgress`; nullable parameters).

- [ ] **Step 3: The engine interface, channel and fake**

In `lib/data/services/container_engine.dart`, add to the interface, after `Stream<TunnelDroppedEvent> tunnelDropped();`:

```dart
  /// Built-in Tor's bootstrap percentage while it starts (built-in Tor spec
  /// §7), for `8a`. There is one Tor, so this is not per site. Broadcast,
  /// with no replay.
  Stream<int> torProgress();
```

In `lib/data/services/container_engine_channel.dart`:

1. In `_failure`, add `'torFailed' => RouteFailure.torFailed,` before `_ => null`.
2. After `pageOpenedFromEvent`, add:

```dart
/// Exposed for testing — decodes a `type: "tor_progress"` event.
int torProgressFromEvent(Map<Object?, Object?> event) => event['percent']! as int;
```

3. In the listener's `switch (map['type'])`, before `default:`, add:

```dart
        case 'tor_progress':
          _torProgressController.add(torProgressFromEvent(map));
```

4. Add the field `final _torProgressController = StreamController<int>.broadcast();` beside the other controllers, and the method:

```dart
  @override
  Stream<int> torProgress() => _torProgressController.stream;
```

5. In `open`, replace `'blockWebRtc': site.blockWebRtc,` with:

```dart
      // Built-in Tor spec §5.4: always blocked on Tor, whatever is stored.
      'blockWebRtc': site.blockWebRtc || webRtcLocked(site.proxyMode),
```

and add `import '../../domain/models/route_display.dart';`.

In `lib/data/services/fake_container_engine.dart`:

1. Add the field `final _torProgressController = StreamController<int>.broadcast();` beside the other controllers.
2. Add:

```dart
  /// Reports Tor's percentage, as the platform does while Tor starts.
  void emitTorProgress(int percent) => _torProgressController.add(percent);

  @override
  Stream<int> torProgress() => _torProgressController.stream;
```

3. In `open`, give the session its failure: in the `ContainerSession(` it builds, add `failure: decision is RouteRefused ? decision.failure : null,` so a refused Tor site reaches `8b` as `torFailed` (a SOCKS5 site with no host still reaches it as `misconfigured`, as `open_containers_test.dart` expects).

- [ ] **Step 4: The provider**

In `lib/ui/features/container/view_models/providers.dart`, after `containerEngineProvider`, add:

```dart
/// Built-in Tor's last reported percentage (built-in Tor spec §7), for `8a`.
final torProgressProvider =
    StreamProvider<int>((ref) => ref.watch(containerEngineProvider).torProgress());
```

- [ ] **Step 5: `8b` and `6c`'s widgets**

In `lib/ui/features/in_page/views/proxy_unreachable_screen.dart`:

1. Change the field to `final VoidCallback? onOpenWithoutTunnel;` with the doc comment `/// Null when the site cannot go direct (built-in Tor spec §5.6): the button is not shown.` and the constructor's `required this.onOpenWithoutTunnel,` to `this.onOpenWithoutTunnel,`.
2. Replace

```dart
                    const SizedBox(height: 9),
                    PillButton(
                      label: 'Open without the tunnel',
                      sublabel: 'This site will see your real IP',
                      tone: PillTone.dangerOutline,
                      onTap: onOpenWithoutTunnel,
                    ),
```

with

```dart
                    if (onOpenWithoutTunnel case final openDirect?) ...[
                      const SizedBox(height: 9),
                      PillButton(
                        label: 'Open without the tunnel',
                        sublabel: 'This site will see your real IP',
                        tone: PillTone.dangerOutline,
                        onTap: openDirect,
                      ),
                    ],
```

In `lib/ui/features/in_page/views/site_sheet.dart`, change `final ValueChanged<bool> onBlockWebRtcChanged;` to `final ValueChanged<bool>? onBlockWebRtcChanged;`, its doc comment to `/// `Block WebRTC`'s new value (spec §3); null draws it inert (built-in Tor spec §5.4).`, and `required this.onBlockWebRtcChanged,` to `this.onBlockWebRtcChanged,`. `AppToggle` already takes a nullable `onChanged`.

- [ ] **Step 6: The container route**

In `lib/ui/features/container/views/container_route.dart`:

1. In `build`, after `final searchEngine = …;`, add:

```dart
    // Built-in Tor spec §7: `8a` shows Tor's own percentage while it starts.
    final torPercent = ref.watch(torProgressProvider).valueOrNull;
```

2. In both `OpeningBody(` calls, replace `steps: openStepsFor(opened),` with `steps: openStepsFor(opened, torPercent: torPercent),`.
3. In `_refusalScreen`, replace the `onOpenWithoutTunnel: () => _reopen(…)` argument with:

```dart
      // Built-in Tor spec §5.6: an onion address cannot go direct.
      onOpenWithoutTunnel: canOpenWithoutTunnel(opened)
          ? () => _reopen(viewed, viewed.site.withoutProxy(), withoutTunnel: true)
          : null,
```

4. In the `SiteSheet(` call, replace `blockWebRtc: site.blockWebRtc,` with `blockWebRtc: site.blockWebRtc || webRtcLocked(site.proxyMode),` and `onBlockWebRtcChanged: (v) => save(site.copyWith(blockWebRtc: v)),` with:

```dart
            // Built-in Tor spec §5.4: always on for Tor, and inert.
            onBlockWebRtcChanged: webRtcLocked(site.proxyMode)
                ? null
                : (v) => save(site.copyWith(blockWebRtc: v)),
```

5. Add `torProgressProvider` to whatever import already brings `containerEngineProvider` from `../view_models/providers.dart` (if it uses `show`, add the name).

- [ ] **Step 7: Run the tests and see them pass**

Run the command from Step 2. Expected: PASS. Then `flutter analyze` (expected `No issues found!`) and `flutter test` (expected all pass: Task 5's total + 2 + 2 + 2 + 1 + 4 = + 11).

- [ ] **Step 8: Commit**

```bash
git add lib/data/services lib/ui/features/container lib/ui/features/in_page test/data/container_engine_channel_test.dart test/ui/features/in_page test/ui/features/container_route_test.dart
git commit -m "feat(tor): Tor's percentage on 8a, no way direct for an onion, 6c's WebRTC locked"
```

---

### Task 7: Dart — the Tor chip and its line, and the forms that start on Tor

**Files:**
- Modify: `lib/ui/features/add_site/views/form_toggle_row.dart`, `route_fields.dart`, `network_tab.dart`, `add_site_screen.dart`
- Modify: `lib/ui/features/settings/views/default_route_screen.dart`
- Test: `test/ui/features/add_site_tor_test.dart` (extend), `test/ui/features/settings/default_route_screen_test.dart` (extend)

**Interfaces:**
- Consumes: Task 5's `ProxyMode.tor`, `ProxyRoute.tor`, `isOnionHost`, `webRtcLocked`.
- Produces: `FormToggleRow.onChanged` nullable (null draws the switch inert at 40%); `RouteFields` with a third chip.

- [ ] **Step 1: Write the failing tests**

Append to `test/ui/features/add_site_tor_test.dart` (add the imports `package:container/domain/models/proxy_route.dart`, `package:container/domain/models/workspace.dart`, `package:container/ui/features/add_site/views/add_site_screen.dart`, `package:container/ui/features/add_site/views/form_toggle_row.dart`, `package:flutter/material.dart`):

```dart
const _workspaces = [
  Workspace(id: 'ws-personal', name: 'Personal', markerIndex: 0, storageRule: StorageRule.keep),
];

Future<void> _pumpForm(WidgetTester tester,
    {ValueChanged<Site>? onSave, ProxyRoute defaultRoute = ProxyRoute.direct}) {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(428, 1400);
  tester.view.devicePixelRatio = 1;
  return tester.pumpWidget(MaterialApp(
    home: AddSiteScreen(
      initial: null,
      workspaces: _workspaces,
      initialWorkspaceId: null,
      defaultRoute: defaultRoute,
      onSave: onSave ?? (_) {},
    ),
  ));
}

FormToggleRow _row(WidgetTester tester, String title) => tester.widget<FormToggleRow>(
    find.ancestor(of: find.text(title), matching: find.byType(FormToggleRow)));
```

and, at the end of `main()`:

```dart
  group('the form', () {
    testWidgets('the Network tab has a Tor chip; choosing it shows the line in place of the fields',
        (tester) async {
      Site? saved;
      await _pumpForm(tester, onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')), 'example.com');
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('proxy-enabled')));
      await tester.pump();

      await tester.tap(find.text('Tor'));
      await tester.pump();

      expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);
      expect(find.text('HOST'), findsNothing);
      expect(find.text('PORT'), findsNothing);
      expect(find.text('Separate login per site'), findsNothing);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.proxyMode, ProxyMode.tor);
      expect(saved!.proxyHost, isNull);
    });

    // Spec §5.4.
    testWidgets('with Tor on, Block WebRTC is on and inert', (tester) async {
      await _pumpForm(tester, defaultRoute: ProxyRoute.tor);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      final row = _row(tester, 'Block WebRTC');
      expect(row.value, isTrue);
      expect(row.onChanged, isNull);
    });

    // Spec §5.3, plan D7.
    testWidgets('typing an onion address turns the proxy on, on Tor', (tester) async {
      Site? saved;
      await _pumpForm(tester, onSave: (s) => saved = s);
      await tester.enterText(find.byKey(const Key('add-site-address')),
          'http://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion');
      await tester.pump();

      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();
      expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved!.proxyMode, ProxyMode.tor);
    });

    testWidgets('a default route of Tor starts the form on Tor', (tester) async {
      await _pumpForm(tester, defaultRoute: ProxyRoute.tor);
      await tester.tap(find.text('Network'));
      await tester.pumpAndSettle();

      expect(_row(tester, 'Route through proxy').value, isTrue);
      expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);
    });
  });
```

In `test/ui/features/settings/default_route_screen_test.dart`, add inside `main()`:

```dart
  testWidgets('Tor can be the default route, and it starts there', (tester) async {
    final done = await _pump(tester, ProxyRoute.direct);

    await tester.tap(find.byKey(const Key('proxy-enabled')));
    await tester.pump();
    await tester.tap(find.text('Tor'));
    await tester.pump();

    expect(done.last, ProxyRoute.tor);
    expect(find.text('HOST'), findsNothing);
    expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);
  });

  testWidgets('a stored Tor route opens on Tor', (tester) async {
    await _pump(tester, ProxyRoute.tor);

    expect(find.text('Through the Tor network. Each site gets its own circuit.'), findsOneWidget);
    expect(find.text('HOST'), findsNothing);
  });
```

- [ ] **Step 2: Run them and see them fail**

Run: `flutter test test/ui/features/add_site_tor_test.dart test/ui/features/settings/default_route_screen_test.dart`
Expected: FAIL (no `Tor` chip; `FormToggleRow.onChanged` not nullable).

- [ ] **Step 3: `FormToggleRow` can be inert**

In `lib/ui/features/add_site/views/form_toggle_row.dart`:

1. Change `required this.onChanged,` to `this.onChanged,` and the field to:

```dart
  /// Null draws the switch inert at 40%, as `AppToggle` does: built-in Tor's
  /// Block WebRTC (spec §5.4).
  final ValueChanged<bool>? onChanged;
```

2. Replace the `GestureDetector(` block with:

```dart
        GestureDetector(
          key: switchKey,
          onTap: onChanged == null ? null : () => onChanged!(!value),
          child: Opacity(
            opacity: onChanged == null ? 0.4 : 1,
            child: Container(
              width: 44,
              height: 26,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(
                color: value ? C.jade : C.trackOff,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value ? C.bg : C.knobOff,
                ),
              ),
            ),
          ),
        ),
```

- [ ] **Step 4: The Tor chip and its line**

In `lib/ui/features/add_site/views/route_fields.dart`:

1. Update the class doc's first sentence to: `/// A route's fields (dashboard spec §7): the proxy switch, SOCKS5/HTTP/Tor, HOST, PORT, and Plan 14's login; with Tor, one line in their place (built-in Tor spec §6).`
2. Replace the chip `Row(` with:

```dart
        Row(
          children: [
            Expanded(child: _modeChip('SOCKS5', ProxyMode.socks5)),
            const SizedBox(width: 8),
            Expanded(child: _modeChip('HTTP', ProxyMode.http)),
            const SizedBox(width: 8),
            Expanded(child: _modeChip('Tor', ProxyMode.tor)),
          ],
        ),
```

3. Replace everything after the `const SizedBox(height: 18),` that follows the chip row — the HOST/PORT `Row(` and the `if (proxyEnabled) ...[ … ]` login block — with:

```dart
        // Built-in Tor spec §6: Tor has no address and no typed login.
        if (proxyMode == ProxyMode.tor)
          Text(
            'Through the Tor network. Each site gets its own circuit.',
            style: ui(size: 12.5, height: 1.5, color: C.textMuted),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('HOST', style: _label),
                    const SizedBox(height: 7),
                    _field(hostController),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PORT', style: _label),
                    const SizedBox(height: 7),
                    _field(portController),
                  ],
                ),
              ),
            ],
          ),
          // Proxy-auth spec §1: only while the proxy is on.
          if (proxyEnabled) ...[
            const SizedBox(height: 18),
            FormToggleRow(
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
                        Text('USERNAME', style: _label),
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
                        Text('PASSWORD', style: _label),
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
        ],
```

- [ ] **Step 5: The Network tab's WebRTC row**

In `lib/ui/features/add_site/views/network_tab.dart`, add `import '../../../../domain/models/route_display.dart';`, and replace the `Block WebRTC` `FormToggleRow(` with:

```dart
        FormToggleRow(
          title: 'Block WebRTC',
          subtitle: 'Prevents real IP leaking past the proxy',
          // Built-in Tor spec §5.4: always on for Tor, and inert.
          value: blockWebRtc || (proxyEnabled && webRtcLocked(proxyMode)),
          onChanged: proxyEnabled && webRtcLocked(proxyMode) ? null : onBlockWebRtcChanged,
        ),
```

- [ ] **Step 6: The forms start on Tor, and an onion address turns it on**

In `lib/ui/features/add_site/views/add_site_screen.dart`:

1. Replace

```dart
  late ProxyMode _proxyMode =
      _startRoute.mode == ProxyMode.http ? ProxyMode.http : ProxyMode.socks5;
```

with

```dart
  late ProxyMode _proxyMode =
      _startRoute.mode == ProxyMode.direct ? ProxyMode.socks5 : _startRoute.mode;
```

2. In `initState`, after `_updateMonogram();`, add `_urlController.addListener(_onionNeedsTor);`.
3. After `_updateMonogram()`'s method, add:

```dart
  /// Built-in Tor spec §5.3, plan D7: an onion address cannot be saved on
  /// Direct, so typing one turns the proxy on, on Tor.
  void _onionNeedsTor() {
    final host = Uri.tryParse(_address ?? '')?.host ?? '';
    if (_proxyEnabled || !isOnionHost(host)) return;
    setState(() {
      _proxyEnabled = true;
      _proxyMode = ProxyMode.tor;
    });
  }
```

4. Add `import '../../../../domain/onion.dart';`.

In `lib/ui/features/settings/views/default_route_screen.dart`, replace

```dart
  late ProxyMode _mode =
      widget.initial.mode == ProxyMode.http ? ProxyMode.http : ProxyMode.socks5;
```

with

```dart
  late ProxyMode _mode =
      widget.initial.mode == ProxyMode.direct ? ProxyMode.socks5 : widget.initial.mode;
```

- [ ] **Step 7: Run the tests and see them pass**

Run the command from Step 2. Expected: PASS. Then `flutter analyze` (`No issues found!`) and `flutter test` (all pass; Task 6's total + 4 + 2 = + 6). `test/ui/features/add_site_test.dart`, `add_site_login_test.dart` and `default_route_screen_test.dart`'s older tests pass unchanged.

- [ ] **Step 8: Commit**

```bash
git add lib/ui/features/add_site lib/ui/features/settings/views/default_route_screen.dart test/ui/features/add_site_tor_test.dart test/ui/features/settings/default_route_screen_test.dart
git commit -m "feat(tor): the Tor chip and its line; forms start on Tor and onion addresses turn it on"
```

---

### Task 8: The dns-prefetch experiment, the gates, the documentation and the device checks

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Shields.kt`
- Test: `android/app/src/test/kotlin/com/mono/container/engine/TorShieldsTest.kt` (extend)
- Modify: `CLAUDE.md`, this plan (Verification, Device checks)

**Interfaces:**
- Produces: `internal const val TOR_DNS_HINTS_JS`; `fun torDocumentStartJs(config: SiteConfig): String`.

- [ ] **Step 1: Write the failing test**

Append to `TorShieldsTest.kt`, inside the class:

```kotlin
    /** Spec §10: an experiment, measured on the device in Step 8; it does not close the gap. */
    @Test fun `a Tor page turns dns-prefetch off and drops its hints`() {
        val js = torDocumentStartJs(site("tor", blockWebRtc = true))
        assertTrue(js.contains("x-dns-prefetch-control"))
        assertTrue(js.contains("dns-prefetch"))
        assertTrue(torDocumentStartJs(site("socks5", blockWebRtc = true)).isEmpty())
        assertTrue(torDocumentStartJs(site("direct", blockWebRtc = true)).isEmpty())
    }
```

Run: `(cd android && ./gradlew :app:testDebugUnitTest --tests "com.mono.container.engine.TorShieldsTest")`. Expected: FAIL (`torDocumentStartJs` unresolved).

- [ ] **Step 2: The script**

In `Shields.kt`, after `WEB_RTC_BLOCK_JS`, add:

```kotlin
/**
 * Built-in Tor spec §10 (accepted leak a2): a Tor page's dns-prefetch hints
 * are looked up through the phone's own DNS. This turns the page's DNS
 * prefetching off before it parses, and removes each hint as it appears. The
 * HTML preload scanner and `Link:` headers act before any script, so it
 * narrows the gap at most; Step 8 of the plan measures by how much.
 */
internal const val TOR_DNS_HINTS_JS =
    "(function(){" +
    "var m=document.createElement('meta');m.httpEquiv='x-dns-prefetch-control';m.content='off';" +
    "(document.head||document.documentElement).appendChild(m);" +
    "var q='link[rel~=\"dns-prefetch\" i]';" +
    "var drop=function(n){if(n.matches&&n.matches(q)){n.remove();}else if(n.querySelectorAll){n.querySelectorAll(q).forEach(function(e){e.remove();});}};" +
    "new MutationObserver(function(ms){ms.forEach(function(r){r.addedNodes.forEach(drop);});})" +
    ".observe(document,{childList:true,subtree:true});" +
    "})();"

/** The Tor-only part of a page's document-start script. */
fun torDocumentStartJs(config: SiteConfig): String = if (config.proxyMode == "tor") TOR_DNS_HINTS_JS else ""
```

In `Shields.apply`'s `buildString`, after `if (config.blockWebRtc) append(WEB_RTC_BLOCK_JS)`, add `append(torDocumentStartJs(config))`.

- [ ] **Step 3: The whole suite and the build**

Run each, with the Bash sandbox disabled:

```bash
flutter analyze
flutter test
(cd android && ./gradlew :app:testDebugUnitTest)
flutter build apk --debug
```

Expected: `No issues found!`; Dart F0 + 28 + 11 + 6 = F0 + 45, all passing; Kotlin K0 + 44 (Task 4's K0 + 43, plus this task's 1), 0 failures, read from the XML; zero `e:` lines. Record the APK's size (`ls -l build/app/outputs/flutter-apk/app-debug.apk`) beside S0 from Task 1 Step 0. If anything fails, fix it in the task that owns the code, then rerun all four.

- [ ] **Step 4: Record the plan in `CLAUDE.md`**

1. Under "Global constraints", replace the bullet

```markdown
- **No network requests of the app's own.** No account, sync, analytics, or
  telemetry, ever.
```

with

```markdown
- **No network requests of the app's own, except connecting to the Tor
  network when the user has chosen Tor** (user's ruling, 2026-10-04, Plan
  19). No account, sync, analytics, or telemetry, ever. Tor runs only while a
  container on the Tor route is open, and stops at every lock and at panic.
```

2. Under "Tech stack", append to the paragraph: `Plan 19 adds \`info.guardianproject:tor-android\` (Tor in process, Maven Central) and \`androidx.localbroadcastmanager\`.`

3. Add a row to the plans table after Plan 18's:

```markdown
| 19 — Built-in Tor | `2026-10-04-built-in-tor.md` | **Done** (<date>) | Implements `docs/superpowers/specs/2026-10-04-built-in-tor-design.md` (the user's five rulings of 2026-10-04, approved section by section; §7's copy word for word). `ProxyMode.tor` is a third proxy mode beside SOCKS5 and HTTP, per site and as the Default route: Guardian Project's `tor-android` 0.4.9.13 runs Tor in process (`TorService`), started by `TorRuntime` when a Tor container opens and stopped when the last one closes, at every lock (`closeAll` → `stopAll`) and at panic. Tor's SOCKS port is a Unix socket, `files/tor/socks:0` (plan D2: the `:0` keeps tor-android's port parser from crashing the app), reached through `LocalSocket` wrapped as `StreamSocket`; each site sends its per-site login, so its own circuit. `8a` shows `Connecting to Tor · N%`; a Tor that fails or stalls (2 minutes with no new percentage) is `8b`'s `Tor did not connect`, never direct. An onion address never goes direct: typed on a Direct route it opens as `THROWAWAY · TOR`, a link to one from a direct page is refused by the loopback proxy before any lookup, and the form saves one on Tor. Block WebRTC is always on for Tor. Panic deletes `files/tor`, `app_TorService` and `cache/TorService`, again 5 s later, and once more at the next start (plan D4). Decisions D1–D10 are in the plan's header. Verified <date>: `flutter analyze` clean, `flutter test` <n>/<n>, Kotlin JVM <k>/<k> (JUnit XML), `flutter build apk --debug` with zero `e:` lines; APK <before> → <after>. Device: see the plan's "Device checks". |
```

Fill `<date>`, `<n>`, `<k>`, `<before>`, `<after>` from Step 3.

- [ ] **Step 5: Commit the code and docs so far**

```bash
git add android/app/src/main/kotlin/com/mono/container/engine/Shields.kt android/app/src/test/kotlin/com/mono/container/engine/TorShieldsTest.kt CLAUDE.md
git commit -m "feat(tor): the dns-prefetch experiment; docs for Plan 19"
```

- [ ] **Step 6: Install on the emulator**

The emulator is the `Pixel_9` AVD (API 36), driven as in `tool/device-check/README.md`: `FLAG_SECURE` blanks screenshots, so read the UI with `adb shell uiautomator dump` or `adb emu screenrecord screenshot`. The test vault's PIN is in the session memory (`emulator-test-setup`). For DNS, start the emulator with `-dns-server` pointed at `tool/device-check/dns_log.py`, as that README describes. Install with data kept:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

- [ ] **Step 7: Run the device checks**

Run spec §9's checks, in order, and note what was seen for each:

1. A cold start, unlocked, with no Tor site open: `python tool/device-check/app_sockets.py watch` shows no connection from the app's uid but its own sites' traffic, and `adb shell run-as com.mono.container ls files/tor` shows no socket.
2. Add a site `https://check.torproject.org` on Tor (Network tab ▸ Route through proxy ▸ Tor). `8a` reads `Connecting to Tor`, then `Connecting to Tor · N%`. The page says it is using Tor.
3. Save `https://api.ipify.org` twice, as two sites on Tor with different names, and open both: they show different IP addresses. Then ☰ ▸ New identity on one: its address changes, the other's does not.
4. On a Direct site, type `duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion` in the address pill: the suggestion reads `THROWAWAY · TOR` and the page opens. On a Direct site's page, follow a link to an onion address (any page linking to one, e.g. `https://www.torproject.org/` ▸ its onion link if present, or a local page from `tool/device-check/pages.py` with `<a href="http://abc.onion/">`): the page shows WebView's error, and `dns_log.py` shows no lookup of the `.onion` name.
5. With a Tor site open: `adb shell ss -ltnp` (or `app_sockets.py`) shows no TCP listener of the app's on 9050, 8118 or any port besides the loopback proxy's; `adb shell run-as com.mono.container ls -l files/tor` shows the socket `socks:0`.
6. Lock (`9c`, or background past Auto-lock): the Tor connections from the app's uid are gone within a few seconds.
7. Panic: `adb shell run-as com.mono.container ls files/tor app_TorService cache/TorService` show none of them, and after 10 s still none.
8. Network cut (`adb shell svc wifi disable` and `adb shell svc data disable`, or the emulator's airplane mode), then open a Tor site: `8a` stays at its percentage, and after about 2 minutes `8b` shows `Tor did not connect`, with Try again, Change proxy settings and Open without the tunnel; nothing loads direct. Turn the network back on; Try again loads it.

- [ ] **Step 8: Measure the dns-prefetch experiment**

On a Tor site, open a public page that carries `<link rel="dns-prefetch">` hints (check its source with `curl -s <url> | grep -o 'rel="dns-prefetch"[^>]*'` on the host first; most large news sites carry several). Count the hinted hosts that `dns_log.py` shows looked up. Then build once with `append(torDocumentStartJs(config))` commented out locally (never committed), reinstall, load the same page, and count again. Record both counts. Whatever the numbers, the script stays (spec §10 asks only that it be tried and measured); the Known gaps line below says what it achieved.

- [ ] **Step 9: Record what was seen**

Replace this plan's "Device checks" section with what Steps 7–8 saw, check by check, including anything not seen and why. Update Plan 19's row in `CLAUDE.md` with a one-line device verdict. Commit:

```bash
git add CLAUDE.md docs/superpowers/plans/2026-10-04-built-in-tor.md
git commit -m "docs: Plan 19, built-in Tor, device-checked"
```

---

## Verification

Not yet run. Task 8 Step 3 fills this in: the four gates' output, the test counts against F0 and K0, and the APK size before and after.

## Device checks

Not yet run. Task 3 runs the engine spike (`TorSpikeTest`) on the emulator; Task 8 Steps 7–8 run spec §9's eight checks and the dns-prefetch measurement, and record what was seen here.

## Known gaps

- **This is not Tor Browser** (spec §10). WebView has its own fingerprint, so sites can link a phone's Tor visits more easily than Tor Browser's. No copy says "anonymous".
- **dns-prefetch on Tor** (accepted leak a2). A Tor page's hints can still be looked up through the phone's DNS. `TOR_DNS_HINTS_JS` turns prefetching off and removes hints as they appear, but the preload scanner and `Link:` headers act first; Task 8 Step 8 records how much it reduced.
- **No bridges** (ruling 2): Tor sites do not work where Tor is blocked; they show `8b` after the stall.
- **One Tor data directory for both vaults** (spec §4.5), where tor-android puts it (plan D1).
- **"Open without the tunnel" stays on a Tor site** (spec §5.6), hidden only for an onion address.
- **Tor's own shutdown can write its state after panic's delete** (plan D4). Panic deletes again after 5 s and at the next start, so at worst Tor's guard list is on disk until one of those runs.
- **A site saved on Direct with an onion address before this plan** opens on Direct and is refused by the loopback proxy (WebView's error page). Editing and saving it moves it to Tor.
- **The release build is not checked.** Tor's JNI classes must survive R8; only `flutter build apk --debug` is run.
- **The Tor percentage is process-wide**, not per site: two Tor sites opening at once show the same number, which is true, since they share one Tor.
- **Tor lingers 10 s** after the last Tor container closes (`TorRuntime.LINGER_MS`), a deviation from spec §4.2's "stops when the last one closes": a reopen in place (a `6c` switch, a security level, New identity) would otherwise stop and restart Tor, and the previous `TorService` instance's late OFF/STOPPING broadcasts failed the new run. Every lock and panic (`stopAll`) still stops it at once. `postDelayed` counts uptime, so a sleeping device can stretch the 10 s.
- **A Tor start within about a second of a stop** (a lock, then an immediate unlock and open; or "Try again" right after a failure) can still hear the old instance's late broadcast and show `8b`; Try again recovers. The broadcasts carry no instance id.
- **The AAR metadata check is off**: tor-android 0.4.9.13 declares minCompileSdk 37; this project compiles against 36 (AGP 9.1.0's maximum here), so `android/app/build.gradle.kts` disables `check*AarMetadata` for every library. Remove the block once compileSdk reaches 37.
- **A `LocalSocket` read timeout reads as a plain `IOException`**, so a Tor handshake timeout shows as a 502 / "Download failed", not 504 / `UPSTREAM_TIMEOUT`.
- **TLS over `StreamSocket` is verified only on API 36** (Conscrypt's engine-socket path); not on API 29, the minSdk.

## Handoff

- `Route.Tor` is a fourth `Route`; any new `when (route)` must handle it. `Router.connect`'s `local` parameter is how the JVM tests reach it.
- `TorRuntime` is the only thing that starts or stops Tor; hold it by site id in `EngineChannel.open`, release it in `close`. `Tor.runtime` and `Tor.socketPath` are the process's one instance.
- `StreamSocket` wraps any stream connection as a `java.net.Socket`; reuse it for any later Unix-socket upstream.
- `isOnionHost` exists in both Kotlin (`TorConfig.kt`) and Dart (`lib/domain/onion.dart`); keep them in step.
- `route_display.dart` is where every on-screen route name lives; a new mode adds its arm there.
- Bridges (spec ruling 2) would add `UseBridges`/`ClientTransportPlugin` lines to `torrc()` and a pluggable-transport library; nothing else here needs to change.

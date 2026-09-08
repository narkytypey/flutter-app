# DownloadManager Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the held-download sheet's three actions (keep in container, save to device, discard) to a real fetch, so a download is no longer just closed on tap — it is actually fetched, placed, and reported back.

**Architecture:** Every download is resolved through the same `Router.resolve`/`ProxyProbe` decision `RequestInterceptor` already uses for page loads — extracted into a shared `SiteConfig.currentRoute()` and `ProxyHttpClient` so a proxied site's download can never quietly go direct. A new `DownloadFetcher` (Kotlin) dispatches on the resolved route and the user's decision: "keep in container" always writes to a private per-profile directory and opens the result via a new `FileProvider`; "save to device" uses the real system `DownloadManager` for a Direct-routed site (OS notification, resumable) and a manual fetch + `MediaStore` insert for a Proxy-routed site (since `DownloadManager` cannot honor a per-site proxy). `EngineChannel` gains a `resolveDownload` method-channel entry and a `download_result` event; `ContainerRoute` shows a snackbar for the outcome. Every existing wipe path also deletes a profile's kept-in-container downloads.

**Tech Stack:** Flutter/Dart 3, `flutter_riverpod`, Kotlin, `androidx.webkit` (existing multi-profile WebView), Android `DownloadManager`/`MediaStore`/`FileProvider` (all platform APIs, no new Gradle dependency).

**Spec:** `docs/superpowers/specs/2026-09-08-download-manager-integration-design.md`

## Global Constraints

- **Android only, dark theme only.** No light theme, no toggle.
- **No network requests of the app's own.** This plan only ever fetches what a site's own page already asked for (a download it initiated) — no telemetry, no account, no sync.
- **The interceptor never falls back to direct.** A site set to a proxy that becomes unreachable is refused, never silently sent unproxied — this plan extends that exact guarantee to downloads: every download is resolved through the same `Router.resolve` decision page loads use, and a refused route fails the download immediately rather than ever touching a socket.
- **Two-vault decoy model.** Kept-in-container downloads live under a per-profile directory (`context.filesDir/downloads/<profileId>/`) and are destroyed by every existing per-profile or full wipe path — no query or aggregate in this plan ever compares across profiles/vaults.

---


---

### Task 1: Extract shared routing + ProxyHttpClient (pure refactor, Kotlin only)

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/ProxyHttpClient.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/Router.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`

**Interfaces:**
- Consumes: existing `Router.resolve(config, proxyReachable)`, `Router.connect(route, host, port)`, `ProxyProbe.reachable(host, port)`, `SiteConfig` (all pre-existing, unchanged).
- Produces: `fun SiteConfig.currentRoute(): Route` (Router.kt) — consumed directly by this task's own `RequestInterceptor`/`EngineChannel` call sites, and by Task 4's `DownloadFetcher.run`. `object ProxyHttpClient` with `fun fetch(route: Route, host: String, port: Int, method: String, path: String, requestHeaders: Map<String,String>): ProxyHttpClient.FetchedResponse` and `data class FetchedResponse(val status: Int, val reason: String, val headers: Map<String,String>, val body: java.io.InputStream)` (ProxyHttpClient.kt) — consumed by this task's own `RequestInterceptor.fetchThrough`, and by Task 4's `DownloadFetcher.fetchTo`.

- [ ] **Step 1: Create `ProxyHttpClient.kt`, extracting the socket/HTTP plumbing out of `RequestInterceptor.fetchThrough`**

No automated test exists for this file — Kotlin JVM/Robolectric tests are out of scope for this repo's current test setup (established precedent for the whole `engine/` package). Verification is `flutter analyze` + `flutter build apk --debug` succeeding, confirming the extraction compiles and the app's existing behavior (page loads, proxy routing) is unaffected — write the code directly, then verify in Step 4.

Create `android/app/src/main/kotlin/com/mono/container/engine/ProxyHttpClient.kt`:

```kotlin
package com.mono.container.engine

import java.io.InputStream

/**
 * Shared HTTP/1.1-over-socket client used by [RequestInterceptor] (page
 * loads) and, in a later plan step, downloads — one place that knows how to
 * open a [Route] and speak bare HTTP over it, instead of two copies of the
 * same byte-at-a-time header parser.
 */
object ProxyHttpClient {

    data class FetchedResponse(
        val status: Int,
        val reason: String,
        val headers: Map<String, String>,
        val body: InputStream,
    )

    /**
     * Opens a socket for [route] (via [Router.connect]), writes a bare
     * HTTP/1.1 request line, Host header, [requestHeaders] and a blank line,
     * then reads back the status line and headers. [FetchedResponse.body] is
     * the still-open response [InputStream], positioned at byte zero of the
     * body. Never called for [Route.Refused] — see [Router.connect].
     */
    fun fetch(
        route: Route,
        host: String,
        port: Int,
        method: String,
        path: String,
        requestHeaders: Map<String, String>,
    ): FetchedResponse {
        val socket = Router.connect(route, host, port)
        socket.soTimeout = 15_000
        val out = socket.getOutputStream()
        out.write("$method $path HTTP/1.1\r\n".toByteArray(Charsets.US_ASCII))
        out.write("Host: $host\r\n".toByteArray(Charsets.US_ASCII))
        requestHeaders.forEach { (k, v) ->
            out.write("$k: $v\r\n".toByteArray(Charsets.US_ASCII))
        }
        out.write("Connection: close\r\n\r\n".toByteArray(Charsets.US_ASCII))
        out.flush()

        val input = socket.getInputStream()
        val (status, reason, headers) = readStatusAndHeaders(input)
        return FetchedResponse(status, reason, headers, input)
    }

    /**
     * Reads one CRLF-terminated line a byte at a time. A [java.io.BufferedReader]
     * would over-read into its own buffer and swallow the first bytes of the
     * response body along with the headers; this stops exactly at the blank
     * line so the input stream is positioned at byte zero of the body for the
     * caller.
     */
    private fun readLine(input: InputStream): String {
        val line = StringBuilder()
        while (true) {
            val b = input.read()
            if (b == -1 || b == '\n'.code) break
            if (b != '\r'.code) line.append(b.toChar())
        }
        return line.toString()
    }

    private fun readStatusAndHeaders(
        input: InputStream,
    ): Triple<Int, String, Map<String, String>> {
        val statusLine = readLine(input)
        val parts = statusLine.split(' ', limit = 3)
        val status = parts.getOrNull(1)?.toIntOrNull() ?: 502
        val reason = parts.getOrNull(2) ?: "OK"

        val headers = mutableMapOf<String, String>()
        while (true) {
            val line = readLine(input)
            if (line.isEmpty()) break
            val idx = line.indexOf(':')
            if (idx > 0) headers[line.substring(0, idx).trim()] = line.substring(idx + 1).trim()
        }
        return Triple(status, reason, headers)
    }
}
```

- [ ] **Step 2: Add `SiteConfig.currentRoute()` to `Router.kt`**

Append to the end of `android/app/src/main/kotlin/com/mono/container/engine/Router.kt` (the file currently ends at line 44 with the closing brace of `object Router`):

```kotlin

/**
 * The one place a [SiteConfig] is turned into a [Route] — wraps
 * [Router.resolve] with the live [ProxyProbe.reachable] check so every call
 * site (page loads, downloads) asks the same question the same way.
 */
fun SiteConfig.currentRoute(): Route =
    Router.resolve(this, proxyReachable = ProxyProbe.reachable(proxyHost ?: "", proxyPort ?: -1))
```

- [ ] **Step 3: Rewrite `RequestInterceptor.kt` to call `ProxyHttpClient.fetch` and `config.currentRoute()`**

Replace the full contents of `android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt`:

```kotlin
package com.mono.container.engine

import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.webkit.ServiceWorkerClientCompat
import java.io.ByteArrayInputStream

class RequestInterceptor(
    private val filters: FilterEngine,
    private val onRefused: (RouteFailure) -> Unit = {},
) {

    /** One client per site. This is what `ProxyController` could never do. */
    fun clientFor(
        config: SiteConfig,
        onLoaded: () -> Unit = {},
    ): WebViewClient = object : WebViewClient() {
        override fun shouldInterceptRequest(
            view: WebView,
            request: WebResourceRequest,
        ): WebResourceResponse? = intercept(config, request)

        override fun onPageFinished(view: WebView, url: String) {
            onLoaded()
        }
    }

    /**
     * Service-worker-issued requests bypass [WebViewClient] entirely, so the
     * same filter-and-route logic has to be registered again here — see
     * "What the interceptor cannot see" in Global Constraints. Without this, a
     * site with a service worker routes around every guarantee in this plan.
     */
    fun serviceWorkerClient(config: SiteConfig): ServiceWorkerClientCompat =
        object : ServiceWorkerClientCompat() {
            override fun shouldInterceptRequest(
                request: WebResourceRequest,
            ): WebResourceResponse? = intercept(config, request)
        }

    private fun intercept(config: SiteConfig, request: WebResourceRequest): WebResourceResponse? {
        val url = request.url.toString()

        if (config.blockTrackers && filters.matches(url) != null) return blocked()

        return when (val route = config.currentRoute()) {
            is Route.Direct -> null   // let WebView fetch it itself
            is Route.Proxy -> fetchThrough(route, request)
            is Route.Refused -> { onRefused(route.failure); refused(route.failure) }
        }
    }

    /** A 204 with no body. The request is simply not made. */
    private fun blocked() = WebResourceResponse(
        "text/plain", "utf-8", 204, "Blocked", emptyMap(), ByteArrayInputStream(ByteArray(0))
    )

    /**
     * Turn 8's rule at the only layer that can enforce it. Returning a response
     * here means WebView never opens its own socket — which is precisely why
     * there is no silent direct fallback anywhere in this app.
     */
    private fun refused(failure: RouteFailure) = WebResourceResponse(
        "text/plain", "utf-8", 523, "Route refused",
        mapOf("X-Container-Refusal" to failure.name), ByteArrayInputStream(ByteArray(0))
    )

    /**
     * Fetches via [ProxyHttpClient] and streams the response straight back to
     * WebView. Never returns null on failure — see the class doc — every exit
     * is either a real response or [refused].
     */
    private fun fetchThrough(
        route: Route.Proxy,
        request: WebResourceRequest,
    ): WebResourceResponse {
        val url = request.url
        val host = url.host ?: return refused(RouteFailure.MISCONFIGURED)
        val targetPort = if (url.port != -1) url.port else if (url.scheme == "https") 443 else 80

        return runCatching {
            val path = (url.path?.ifEmpty { "/" } ?: "/") + (url.query?.let { "?$it" } ?: "")
            val response = ProxyHttpClient.fetch(
                route, host, targetPort, request.method, path, request.requestHeaders,
            )
            val contentType = response.headers["Content-Type"]
            val mimeType = contentType?.substringBefore(';')?.trim()
                ?: "application/octet-stream"
            val charset = contentType?.substringAfter("charset=", "")?.trim()
                ?.ifEmpty { null } ?: "utf-8"
            WebResourceResponse(
                mimeType, charset, response.status, response.reason, response.headers, response.body,
            )
        }.getOrElse { error ->
            refused(
                when (error) {
                    is java.net.SocketTimeoutException -> RouteFailure.UPSTREAM_TIMEOUT
                    is javax.net.ssl.SSLException -> RouteFailure.TLS_FAILURE
                    is java.net.ConnectException -> RouteFailure.PROXY_UNREACHABLE
                    else -> RouteFailure.UPSTREAM_TIMEOUT
                }
            )
        }
    }
}
```

This deletes `readLine`, `readStatusAndHeaders`, and `proxyReachable(config)` from this file (moved into `ProxyHttpClient` / replaced by `currentRoute()`), and swaps `Router.resolve(config, proxyReachable(config))` for `config.currentRoute()`. Observable behavior (mimeType/charset parsing, error-to-`RouteFailure` mapping, the 204/523 shapes) is unchanged.

- [ ] **Step 4: Point `EngineChannel.open()` at `config.currentRoute()`**

In `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`, line 227:

```kotlin
            val route = Router.resolve(config, ProxyProbe.reachable(config.proxyHost ?: "", config.proxyPort ?: -1))
```

becomes:

```kotlin
            val route = config.currentRoute()
```

No other line in this file changes for this task.

- [ ] **Step 5: Verify**

Run:

```
flutter analyze
flutter build apk --debug
```

Expect `flutter analyze` to report no new issues and the debug APK build to succeed. This is the verification for this task in place of an automated Kotlin test — no JVM/Robolectric test harness exists for the `engine/` package (established precedent), so there is nothing to TDD here; a clean analyze + successful build is the evidence that the extraction preserved `RequestInterceptor`'s and `EngineChannel.open()`'s observable behavior (page loads and proxy routing unaffected).

- [ ] **Step 6: Commit**

```
git add android/app/src/main/kotlin/com/mono/container/engine/ProxyHttpClient.kt android/app/src/main/kotlin/com/mono/container/engine/Router.kt android/app/src/main/kotlin/com/mono/container/engine/RequestInterceptor.kt android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt
git commit -m "refactor: extract shared proxy-fetch client and route resolution"
```
---

### Task 2: Thread url/mimeType/requestId through the download event pipeline

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/ContainerViewFactory.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`
- Modify: `lib/domain/models/engine_events.dart`
- Modify: `lib/data/services/container_engine_channel.dart`
- Test: `test/data/container_engine_channel_test.dart`

**Interfaces:**
- Consumes: nothing new from Task 1 — this task's own note in the plan's shared contract says it lands after Task 1 in file history only because both touch files in the `engine/` package, not because it calls anything Task 1 produces. Consumes the pre-existing `EngineChannel.nextRequestId()` and `Session` class (both already in the tree).
- Produces: `ContainerView`'s `onDownload` callback field with signature `(url: String, mimeType: String, fileName: String, sizeBytes: Long, kindLabel: String) -> String`. `EngineChannel.PendingDownload` data class and `Session.pendingDownloads: LinkedHashMap<String, PendingDownload>`. `EngineChannel.onDownload(siteId, requestId, url, mimeType, fileName, sizeBytes, kindLabel)`. Dart `HeldDownloadEvent.requestId` (required `String` field) and `downloadFromEvent` decoding it. Task 3 depends on `HeldDownloadEvent.requestId` existing. Task 4 depends on `Session.pendingDownloads` and the `"download"` event carrying `"requestId"`.

- [ ] **Step 1: Write the failing Dart decode test first**

There is currently no test in `test/data/container_engine_channel_test.dart` that decodes a `"download"` event at all (only `sessions` and `permission_request` events are covered today). Add one, following the file's existing style exactly (see `'a permission_request event decodes the pending ask'`):

```dart
  test('a download event decodes its requestId', () {
    final event = <Object?, Object?>{
      'type': 'download',
      'siteId': 's1', 'fileName': 'report.pdf', 'sizeBytes': 1024,
      'sourceHost': 'forum.example.com', 'kindLabel': 'PDF',
      'requestId': 'r1',
    };
    final download = downloadFromEvent(event);
    expect(download.requestId, 'r1');
    expect(download.download.fileName, 'report.pdf');
  });
```

Add this as a new `test(...)` block inside the existing `main()` in `test/data/container_engine_channel_test.dart`, after the `'a permission_request event decodes the pending ask'` test.

Run `flutter test test/data/container_engine_channel_test.dart` and confirm it fails to compile — `HeldDownloadEvent` has no `requestId` constructor parameter yet, so `download.requestId` doesn't resolve.

- [ ] **Step 2: Add `requestId` to `HeldDownloadEvent` (Dart)**

In `lib/domain/models/engine_events.dart`, replace:

```dart
class HeldDownloadEvent {
  const HeldDownloadEvent({required this.siteId, required this.download});

  final String siteId;
  final HeldDownload download;
}
```

with:

```dart
class HeldDownloadEvent {
  const HeldDownloadEvent({
    required this.siteId,
    required this.requestId,
    required this.download,
  });

  final String siteId;
  final String requestId;
  final HeldDownload download;
}
```

(Confirmed by grep before drafting this task: the only two places in the whole repo that construct `HeldDownloadEvent(...)` are this definition and `downloadFromEvent` below — no other call site needs updating.)

- [ ] **Step 3: Decode `requestId` in `downloadFromEvent` (Dart)**

In `lib/data/services/container_engine_channel.dart`, replace:

```dart
/// Exposed for testing — decodes a `type: "download"` event.
HeldDownloadEvent downloadFromEvent(Map<Object?, Object?> event) => HeldDownloadEvent(
      siteId: event['siteId']! as String,
      download: HeldDownload(
        fileName: event['fileName']! as String,
        sizeBytes: event['sizeBytes']! as int,
        sourceHost: event['sourceHost']! as String,
        kindLabel: event['kindLabel']! as String,
      ),
    );
```

with:

```dart
/// Exposed for testing — decodes a `type: "download"` event.
HeldDownloadEvent downloadFromEvent(Map<Object?, Object?> event) => HeldDownloadEvent(
      siteId: event['siteId']! as String,
      requestId: event['requestId']! as String,
      download: HeldDownload(
        fileName: event['fileName']! as String,
        sizeBytes: event['sizeBytes']! as int,
        sourceHost: event['sourceHost']! as String,
        kindLabel: event['kindLabel']! as String,
      ),
    );
```

Run `flutter test test/data/container_engine_channel_test.dart` and confirm all tests, including the new one, now pass.

- [ ] **Step 4: Widen `ContainerView`'s `onDownload` callback and its `DownloadListener` (Kotlin)**

In `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`, replace the constructor field (line 21):

```kotlin
    private val onDownload: (fileName: String, sizeBytes: Long, kindLabel: String) -> Unit = { _, _, _ -> },
```

with:

```kotlin
    private val onDownload: (url: String, mimeType: String, fileName: String, sizeBytes: Long, kindLabel: String) -> String = { _, _, _, _, _ -> "" },
```

And replace the `setDownloadListener` block (lines 47–53):

```kotlin
        webView.setDownloadListener { url, _, contentDisposition, mimeType, contentLength ->
            val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val extension = MimeTypeMap.getFileExtensionFromUrl(url).ifEmpty {
                mimeType?.substringAfter('/') ?: ""
            }
            onDownload(fileName, contentLength, extension.uppercase().ifEmpty { "FILE" })
        }
```

with:

```kotlin
        webView.setDownloadListener { url, _, contentDisposition, mimeType, contentLength ->
            val fileName = android.webkit.URLUtil.guessFileName(url, contentDisposition, mimeType)
            val extension = MimeTypeMap.getFileExtensionFromUrl(url).ifEmpty {
                mimeType?.substringAfter('/') ?: ""
            }
            val resolvedMimeType = mimeType?.ifEmpty { null } ?: "application/octet-stream"
            onDownload(url, resolvedMimeType, fileName, contentLength, extension.uppercase().ifEmpty { "FILE" })
        }
```

(`onDownload(...)` now returns a `String`, discarded here as a statement — `DownloadListener.onDownloadStart` itself returns `Unit`. The returned request id is only meaningful to `ContainerViewFactory`'s own wiring, which supplies the real lambda in Step 5.)

- [ ] **Step 5: Update `ContainerViewFactory`'s `onDownload` wiring (Kotlin)**

In `android/app/src/main/kotlin/com/mono/container/engine/ContainerViewFactory.kt`, replace (lines 49–51):

```kotlin
            onDownload = { fileName, sizeBytes, kindLabel ->
                engine.onDownload(siteId, fileName, sizeBytes, kindLabel)
            },
```

with:

```kotlin
            onDownload = { url, mimeType, fileName, sizeBytes, kindLabel ->
                val requestId = engine.nextRequestId()
                engine.onDownload(siteId, requestId, url, mimeType, fileName, sizeBytes, kindLabel)
                requestId
            },
```

- [ ] **Step 6: Add `PendingDownload` and `Session.pendingDownloads` (Kotlin)**

In `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`, add a new data class right after the `PendingPermission` sealed class (after its closing brace, before the `Session` class doc comment):

```kotlin
/** A download the WebView's `DownloadListener` handed off, waiting for the
 * user's decision from `HeldDownloadSheet` (`6c`). Parallels
 * [PendingPermission]: [EngineChannel.resolveDownload] (Task 4) looks a
 * pending entry up by [EngineChannel.onDownload]'s generated request id, the
 * same way [EngineChannel.resolvePermission] already does for permissions. */
data class PendingDownload(
    val url: String,
    val mimeType: String,
    val fileName: String,
    val sizeBytes: Long,
    val kindLabel: String,
)
```

Then, in the `Session` class body, add a field immediately after the existing `pendingPermissions` field:

```kotlin
    val pendingPermissions = LinkedHashMap<String, PendingPermission>()
    val pendingDownloads = LinkedHashMap<String, PendingDownload>()
```

- [ ] **Step 7: Widen `EngineChannel.onDownload` (Kotlin)**

Replace the existing method:

```kotlin
    /** Called by [ContainerView]'s `DownloadListener`. */
    fun onDownload(siteId: String, fileName: String, sizeBytes: Long, kindLabel: String) {
        val session = sessions[siteId] ?: return
        val host = runCatching { java.net.URI(session.config.url).host }.getOrNull()
            ?: session.config.url
        sink?.success(mapOf(
            "type" to "download",
            "siteId" to siteId, "fileName" to fileName, "sizeBytes" to sizeBytes,
            "sourceHost" to host, "kindLabel" to kindLabel,
        ))
    }
```

with:

```kotlin
    /** Called by [ContainerViewFactory]'s `onDownload` callback. Only native
     * needs [url]/[mimeType] to actually fetch the file later (Task 4) — the
     * Dart event carries everything it did before, plus [requestId]. */
    fun onDownload(
        siteId: String,
        requestId: String,
        url: String,
        mimeType: String,
        fileName: String,
        sizeBytes: Long,
        kindLabel: String,
    ) {
        val session = sessions[siteId] ?: return
        session.pendingDownloads[requestId] = PendingDownload(url, mimeType, fileName, sizeBytes, kindLabel)
        val host = runCatching { java.net.URI(session.config.url).host }.getOrNull()
            ?: session.config.url
        sink?.success(mapOf(
            "type" to "download",
            "siteId" to siteId, "fileName" to fileName, "sizeBytes" to sizeBytes,
            "sourceHost" to host, "kindLabel" to kindLabel, "requestId" to requestId,
        ))
    }
```

- [ ] **Step 8: Verify**

No Kotlin JVM test exists for this file — established precedent for this whole `engine/` package (Robolectric/instrumentation is out of scope for this repo's current test setup). Verify the Kotlin changes with:

```
flutter analyze
flutter build apk --debug
```

Both must succeed, confirming `ContainerView.kt`, `ContainerViewFactory.kt`, and `EngineChannel.kt` compile together with their new signatures. Also re-run the full Dart suite to confirm nothing else broke:

```
flutter test
```

- [ ] **Step 9: Commit**

```
git add android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt android/app/src/main/kotlin/com/mono/container/engine/ContainerViewFactory.kt android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt lib/domain/models/engine_events.dart lib/data/services/container_engine_channel.dart test/data/container_engine_channel_test.dart
git commit -m "feat: thread download URL and requestId through the event pipeline"
```
---

### Task 3: Dart download-result plumbing + ContainerRoute wiring

**Files:**
- Modify: `lib/domain/models/engine_events.dart`
- Modify: `lib/data/services/container_engine.dart`
- Modify: `lib/data/services/container_engine_channel.dart`
- Modify: `lib/data/services/fake_container_engine.dart`
- Modify: `lib/ui/features/container/views/container_route.dart`
- Test: `test/data/container_engine_channel_test.dart`
- Test: `test/ui/features/container_route_test.dart`

**Interfaces:**
- Consumes: `HeldDownloadEvent.requestId` (Task 2, `lib/domain/models/engine_events.dart`) — `const HeldDownloadEvent({required this.siteId, required this.requestId, required this.download})`. `RouteFailure` enum and `refusalMessage(RouteFailure)` (`lib/domain/models/route_decision.dart`, pre-existing). `DownloadDecision` enum (`lib/domain/models/held_download.dart`, pre-existing: `keepInContainer`, `saveToDevice`, `discard`). `HeldDownloadSheet` (`lib/ui/features/in_page/views/held_download_sheet.dart`, pre-existing) whose three `PillButton` labels are exactly `'Keep inside this container'`, `'Save to device storage'`, `'Discard'`.
- Produces: `enum DownloadOutcome { saved, kept, failed }` and `class DownloadResult` (`lib/domain/models/engine_events.dart`) — consumed by Task 4 only insofar as Task 4's native `"download_result"` event payload shape (`requestId`/`outcome`/`reason`) must match what `downloadResultFromEvent` below decodes. `ContainerEngine.resolveDownload(String, DownloadDecision)` and `ContainerEngine.downloadResults()` (`lib/data/services/container_engine.dart`) — the method channel call name `'resolveDownload'` and argument shape `{'requestId': ..., 'decision': ...}` that Task 4's native `"resolveDownload"` case must match.

Two discrepancies from the shared contract, corrected against the real files below (noted here per Rule 1, not silently diverged):
1. `container_engine_channel.dart` already imports `held_download.dart` as a bare import (no `show` clause) — `DownloadDecision` is already visible, so that import line needs no edit at all.
2. The contract writes `_downloadOutcome` and `downloadResultFromEvent` as if `_downloadOutcome` were a method on `ChannelContainerEngine`. The file's actual established convention is top-level private decode helpers (`_phase`, `_failure`, `_category`, `_kind` are all top-level functions above the class, and `downloadFromEvent`/`permissionRequestFromEvent`/`tunnelDroppedFromEvent` are top-level "Exposed for testing" functions that call them). `_downloadOutcome` and `downloadResultFromEvent` are written top-level below to match that convention exactly, not as class members.

- [ ] **Step 1: Write the failing decode tests in `container_engine_channel_test.dart`**

Add an import for `engine_events.dart` (for `DownloadOutcome`/`DownloadResult`) and three tests for `downloadResultFromEvent`, following the file's exact existing style (see `'a refused session decodes its failure reason'` for how `RouteFailure` string decode is asserted):

```dart
import 'package:container/data/services/container_engine_channel.dart';
import 'package:container/domain/models/blocked_tally.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/permissions.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ... existing three tests unchanged ...

  test('a download_result event decodes a saved outcome', () {
    final event = <Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-1',
      'outcome': 'saved', 'reason': null,
    };
    final result = downloadResultFromEvent(event);
    expect(result.requestId, 'req-1');
    expect(result.outcome, DownloadOutcome.saved);
    expect(result.reason, isNull);
  });

  test('a download_result event decodes a kept outcome', () {
    final event = <Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-2',
      'outcome': 'kept', 'reason': null,
    };
    expect(downloadResultFromEvent(event).outcome, DownloadOutcome.kept);
  });

  test('a download_result event decodes a failed outcome with its reason', () {
    final event = <Object?, Object?>{
      'type': 'download_result', 'requestId': 'req-3',
      'outcome': 'failed', 'reason': 'proxyUnreachable',
    };
    final result = downloadResultFromEvent(event);
    expect(result.outcome, DownloadOutcome.failed);
    expect(result.reason, RouteFailure.proxyUnreachable);
  });
}
```

- [ ] **Step 2: Write the failing widget tests in `container_route_test.dart`**

Add imports for `held_download.dart` (`DownloadDecision`, `HeldDownload`) and `route_decision.dart` (`RouteFailure`, `refusalMessage`), then two new `testWidgets`:

```dart
import 'package:container/data/services/fake_container_engine.dart';
import 'package:container/domain/models/engine_events.dart';
import 'package:container/domain/models/held_download.dart';
import 'package:container/domain/models/reader_article.dart';
import 'package:container/domain/models/route_decision.dart';
import 'package:container/domain/models/site.dart';
import 'package:container/ui/features/container/view_models/providers.dart';
import 'package:container/ui/features/container/views/container_route.dart';
import 'package:container/ui/features/in_page/views/proxy_unreachable_screen.dart';
import 'package:container/ui/features/in_page/views/reader_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ... _site(), _pump() unchanged ...

void main() {
  // ... existing five tests unchanged ...

  testWidgets('tapping a held-download sheet action resolves the download with its requestId', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitDownload(const HeldDownloadEvent(
      siteId: 's1', requestId: 'req-1',
      download: HeldDownload(
        fileName: 'notes.pdf', sizeBytes: 1024,
        sourceHost: 'forum.example.com', kindLabel: 'PDF',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Keep inside this container'));
    await tester.pumpAndSettle();

    expect(engine.resolvedDownloads.single.requestId, 'req-1');
    expect(engine.resolvedDownloads.single.decision, DownloadDecision.keepInContainer);
  });

  testWidgets('a download_result event shows the matching snackbar for each outcome', (tester) async {
    final engine = FakeContainerEngine();
    await _pump(tester, engine, _site());
    await tester.pumpAndSettle();

    engine.emitDownload(const HeldDownloadEvent(
      siteId: 's1', requestId: 'req-1',
      download: HeldDownload(
        fileName: 'a.pdf', sizeBytes: 100,
        sourceHost: 'forum.example.com', kindLabel: 'PDF',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep inside this container'));
    await tester.pumpAndSettle();

    engine.emitDownloadResult(const DownloadResult(requestId: 'req-1', outcome: DownloadOutcome.saved));
    await tester.pump();
    expect(find.text('Saved to Downloads'), findsOneWidget);

    // A SnackBar shown via ScaffoldMessenger queues rather than overlapping —
    // advance past its default ~4s display so the next emit's SnackBar can
    // actually show. A single pump() per emit (not pumpAndSettle, which
    // would run straight past the display window) matches how the earlier
    // tunnel_dropped test in this file times its own pumps.
    await tester.pump(const Duration(seconds: 5));
    engine.emitDownloadResult(const DownloadResult(requestId: 'req-1', outcome: DownloadOutcome.kept));
    await tester.pump();
    expect(find.text('Kept in this container'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    engine.emitDownloadResult(const DownloadResult(
      requestId: 'req-1', outcome: DownloadOutcome.failed, reason: RouteFailure.proxyUnreachable,
    ));
    await tester.pump();
    expect(find.text(refusalMessage(RouteFailure.proxyUnreachable)), findsOneWidget);
  });
}
```

- [ ] **Step 3: Verify both test files fail to compile**

Run `flutter test test/data/container_engine_channel_test.dart test/ui/features/container_route_test.dart` and confirm the failure is a compile error (`downloadResultFromEvent` undefined, `DownloadOutcome`/`DownloadResult` undefined, `engine.resolvedDownloads`/`engine.emitDownloadResult`/`ContainerEngine.resolveDownload` undefined) — not a runtime assertion failure. This confirms the tests actually exercise code that doesn't exist yet.

- [ ] **Step 4: Add `DownloadOutcome` and `DownloadResult` to `engine_events.dart`**

Current file has no `route_decision.dart` import. Add it, and append the new types after `TunnelDroppedEvent`:

```dart
import 'held_download.dart';
import 'permissions.dart';
import 'route_decision.dart' show RouteFailure;

// ... PendingPermissionRequest and HeldDownloadEvent (with requestId, from
// Task 2) unchanged ...

class TunnelDroppedEvent {
  const TunnelDroppedEvent({
    required this.siteId,
    required this.host,
    required this.droppedAt,
  });

  final String siteId;
  final String host;
  final DateTime droppedAt;
}

/// What became of a resolved [HeldDownload] — the platform's answer to
/// [ContainerEngine.resolveDownload]. Spec `7c`'s three sheet actions each
/// resolve to exactly one of these (`discard` never reaches this far; the
/// platform never reports back on a decision that threw the file away).
enum DownloadOutcome { saved, kept, failed }

/// Round-trips a `download_result` native event back to the [HeldDownload]
/// it answers, keyed by the same [requestId] the original
/// [HeldDownloadEvent] carried.
class DownloadResult {
  const DownloadResult({required this.requestId, required this.outcome, this.reason});

  final String requestId;
  final DownloadOutcome outcome;

  /// Only set when [outcome] is [DownloadOutcome.failed] — the same
  /// [RouteFailure] vocabulary a refused session already uses, since a
  /// download fails for exactly the same routing reasons a page load does.
  final RouteFailure? reason;
}
```

- [ ] **Step 5: Add `resolveDownload`/`downloadResults` to the `ContainerEngine` interface**

`container_engine.dart` currently has no import of `held_download.dart` (only `engine_events.dart`, which does not re-export it). Add the import and the two methods, placed right after the existing `downloads()` method:

```dart
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/site.dart';

// ... interface unchanged up through ...

  Stream<HeldDownloadEvent> downloads();

  /// Tells the platform what the user picked for a held download's
  /// [requestId] (see [HeldDownloadEvent.requestId]). Fetching, writing to
  /// device storage or into the container, and reporting the result all
  /// happen natively — this call only starts that; the answer arrives later
  /// on [downloadResults].
  Future<void> resolveDownload(String requestId, DownloadDecision decision);

  /// What became of each [resolveDownload] call, keyed by `requestId`.
  Stream<DownloadResult> downloadResults();

  /// A *live* session's tunnel failing mid-browse. Distinct from
  /// [SessionPhase.refused], which only ever happens before a session goes
  /// live — see Plan 6's design spec §3.
  Stream<TunnelDroppedEvent> tunnelDropped();

  Future<ReaderArticle?> extractArticle(String siteId);
}
```

- [ ] **Step 6: Implement the channel side in `container_engine_channel.dart`**

Add a top-level `_downloadOutcome` helper next to the file's other top-level decode helpers (`_phase`/`_failure`/`_category`/`_kind`), a top-level `downloadResultFromEvent` next to `downloadFromEvent`/`tunnelDroppedFromEvent`, a new switch case in the constructor, a new controller field, and the two new interface methods:

```dart
PermissionKind _kind(String name) => switch (name) {
      'microphone' => PermissionKind.microphone,
      'location' => PermissionKind.location,
      'clipboard' => PermissionKind.clipboard,
      _ => PermissionKind.camera,
    };

DownloadOutcome _downloadOutcome(String name) => switch (name) {
      'saved' => DownloadOutcome.saved,
      'kept' => DownloadOutcome.kept,
      _ => DownloadOutcome.failed,
    };

// ... _categoryCountsFrom, _sessionFrom, sessionsFromEvent,
// permissionRequestFromEvent unchanged ...

/// Exposed for testing — decodes a `type: "download"` event.
HeldDownloadEvent downloadFromEvent(Map<Object?, Object?> event) => HeldDownloadEvent(
      siteId: event['siteId']! as String,
      requestId: event['requestId']! as String,
      download: HeldDownload(
        fileName: event['fileName']! as String,
        sizeBytes: event['sizeBytes']! as int,
        sourceHost: event['sourceHost']! as String,
        kindLabel: event['kindLabel']! as String,
      ),
    );

/// Exposed for testing — decodes a `type: "download_result"` event.
DownloadResult downloadResultFromEvent(Map<Object?, Object?> event) => DownloadResult(
      requestId: event['requestId']! as String,
      outcome: _downloadOutcome(event['outcome']! as String),
      reason: _failure(event['reason'] as String?),
    );

/// Exposed for testing — decodes a `type: "tunnel_dropped"` event.
TunnelDroppedEvent tunnelDroppedFromEvent(Map<Object?, Object?> event) => TunnelDroppedEvent(
      siteId: event['siteId']! as String,
      host: event['host']! as String,
      droppedAt: DateTime.fromMillisecondsSinceEpoch(event['droppedAtMs']! as int),
    );

class ChannelContainerEngine implements ContainerEngine {
  ChannelContainerEngine() {
    _events.receiveBroadcastStream().listen((event) {
      final map = event as Map<Object?, Object?>;
      switch (map['type']) {
        case 'permission_request':
          _permissionController.add(permissionRequestFromEvent(map));
        case 'download':
          _downloadController.add(downloadFromEvent(map));
        case 'download_result':
          _downloadResultController.add(downloadResultFromEvent(map));
        case 'tunnel_dropped':
          _tunnelDroppedController.add(tunnelDroppedFromEvent(map));
        default:
          _sessionsController.add(sessionsFromEvent(map));
      }
    });
  }

  final _sessionsController = StreamController<List<ContainerSession>>.broadcast();
  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _downloadResultController = StreamController<DownloadResult>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();

  // ... isolationAvailable, open, wipe, wipeAll, close, reload, sessions,
  // liveSessions, permissionRequests, resolvePermission unchanged ...

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;

  @override
  Future<void> resolveDownload(String requestId, DownloadDecision decision) =>
      _method.invokeMethod('resolveDownload', {
        'requestId': requestId,
        'decision': decision.name,
      });

  @override
  Stream<DownloadResult> downloadResults() => _downloadResultController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  // ... extractArticle unchanged ...
}
```

(No import edit needed on `held_download.dart` — see the discrepancy note above; `DownloadDecision` is already in scope via the existing bare `import '../../domain/models/held_download.dart';`.)

- [ ] **Step 7: Implement the fake side in `fake_container_engine.dart`**

Add the `held_download.dart` import (not currently present in this file — `DownloadDecision` is needed for `resolveDownload`'s parameter type), a recording list, a new controller, the two new overrides, and a test helper:

```dart
import 'dart:async';

import '../../domain/models/blocked_tally.dart';
import '../../domain/models/container_session.dart';
import '../../domain/models/engine_events.dart';
import '../../domain/models/held_download.dart' show DownloadDecision;
import '../../domain/models/permissions.dart';
import '../../domain/models/reader_article.dart';
import '../../domain/models/route_decision.dart';
import '../../domain/models/site.dart';
import 'container_engine.dart';

/// Drives every widget test in this plan. Deterministic: no timers, no delays.
class FakeContainerEngine implements ContainerEngine {
  // ... constructor, isolation, proxyReachable, _sessions, _controller,
  // wiped, closed unchanged ...

  final _permissionController = StreamController<PendingPermissionRequest>.broadcast();
  final _downloadController = StreamController<HeldDownloadEvent>.broadcast();
  final _downloadResultController = StreamController<DownloadResult>.broadcast();
  final _tunnelDroppedController = StreamController<TunnelDroppedEvent>.broadcast();
  final resolvedPermissions = <String, PermissionDecision>{};

  /// What [resolveDownload] was called with, in call order — the fake's
  /// equivalent of [resolvedPermissions], recorded as a list rather than a
  /// map because the same `requestId` is never resolved twice in practice
  /// but nothing here needs to enforce that.
  final resolvedDownloads = <({String requestId, DownloadDecision decision})>[];
  ReaderArticle? articleToReturn;

  // ... _emit, isolationAvailable, open, wipe, wipedAll, wipeAll, close,
  // sessions, liveSessions, reload, permissionRequests, resolvePermission
  // unchanged ...

  @override
  Stream<HeldDownloadEvent> downloads() => _downloadController.stream;

  @override
  Future<void> resolveDownload(String requestId, DownloadDecision decision) async {
    resolvedDownloads.add((requestId: requestId, decision: decision));
  }

  @override
  Stream<DownloadResult> downloadResults() => _downloadResultController.stream;

  @override
  Stream<TunnelDroppedEvent> tunnelDropped() => _tunnelDroppedController.stream;

  @override
  Future<ReaderArticle?> extractArticle(String siteId) async => articleToReturn;

  /// Test helpers: push one event of each new kind.
  void emitPermissionRequest(PendingPermissionRequest request) =>
      _permissionController.add(request);
  void emitDownload(HeldDownloadEvent event) => _downloadController.add(event);
  void emitDownloadResult(DownloadResult result) => _downloadResultController.add(result);
  void emitTunnelDropped(TunnelDroppedEvent event) => _tunnelDroppedController.add(event);

  // ... addBlocked, seedBackground unchanged ...

  void dispose() {
    _controller.close();
    _permissionController.close();
    _downloadController.close();
    _downloadResultController.close();
    _tunnelDroppedController.close();
  }
}
```

- [ ] **Step 8: Wire `ContainerRoute` to resolve downloads and show the result**

`container_route.dart` currently has no `route_decision.dart` import (only `route_failure_copy.dart`, which re-exports `RouteFailure` but not `refusalMessage`). Add it, add the subscription/tracking fields, subscribe/cancel alongside the existing three, and rewrite `_showDownloadSheet` plus add `_showDownloadResult`:

```dart
import '../../../../domain/models/container_session.dart';
import '../../../../domain/models/engine_events.dart';
import '../../../../domain/models/open_step.dart';
import '../../../../domain/models/route_decision.dart' show refusalMessage;
import '../../../../domain/models/route_failure_copy.dart';
import '../../../../domain/models/site.dart';
import '../../in_page/views/held_download_sheet.dart';
import '../../in_page/views/permission_request_sheet.dart';
import '../../in_page/views/proxy_unreachable_screen.dart';
import '../../in_page/views/reader_screen.dart';
import '../../in_page/views/tunnel_dropped_screen.dart';
import '../view_models/providers.dart';
import 'container_screen.dart';
import 'container_web_view.dart';
import 'opening_screen.dart';
import 'switcher_sheet.dart';

class _ContainerRouteState extends ConsumerState<ContainerRoute> {
  bool _opened = false;
  bool _refusalHandled = false;
  bool _tunnelDropped = false;
  StreamSubscription<PendingPermissionRequest>? _permissionSub;
  StreamSubscription<HeldDownloadEvent>? _downloadSub;
  StreamSubscription<DownloadResult>? _downloadResultSub;
  StreamSubscription<TunnelDroppedEvent>? _tunnelSub;

  /// [DownloadResult] carries no `siteId` (unlike the other three event
  /// types this widget already filters with `.where((e) => e.siteId ==
  /// widget.site.id)`), so membership in "a download this widget's sheet
  /// started" is tracked locally by `requestId` instead.
  final _myDownloadRequestIds = <String>{};

  String get _host => Uri.tryParse(widget.site.url)?.host ?? widget.site.url;

  @override
  void initState() {
    super.initState();
    final engine = ref.read(containerEngineProvider);
    _permissionSub = engine
        .permissionRequests()
        .where((r) => r.siteId == widget.site.id)
        .listen(_showPermissionSheet);
    _downloadSub = engine
        .downloads()
        .where((d) => d.siteId == widget.site.id)
        .listen(_showDownloadSheet);
    _downloadResultSub = engine
        .downloadResults()
        .where((r) => _myDownloadRequestIds.contains(r.requestId))
        .listen(_showDownloadResult);
    _tunnelSub = engine
        .tunnelDropped()
        .where((t) => t.siteId == widget.site.id)
        .listen((_) => setState(() => _tunnelDropped = true));
    _open();
  }

  Future<void> _open() async {
    if (_opened) return;
    _opened = true;
    await ref.read(containerEngineProvider).open(widget.site);
  }

  @override
  void dispose() {
    _permissionSub?.cancel();
    _downloadSub?.cancel();
    _downloadResultSub?.cancel();
    _tunnelSub?.cancel();
    super.dispose();
  }

  void _showPermissionSheet(PendingPermissionRequest request) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => PermissionRequestSheet(
        host: request.host,
        kind: request.kind,
        onDecision: (decision) {
          Navigator.pop(context);
          ref.read(containerEngineProvider).resolvePermission(request.requestId, decision);
        },
      ),
    );
  }

  void _showDownloadSheet(HeldDownloadEvent event) {
    _myDownloadRequestIds.add(event.requestId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => HeldDownloadSheet(
        download: event.download,
        onDecision: (decision) {
          Navigator.pop(context);
          ref.read(containerEngineProvider).resolveDownload(event.requestId, decision);
        },
      ),
    );
  }

  void _showDownloadResult(DownloadResult result) {
    if (!mounted) return;
    final message = switch (result.outcome) {
      DownloadOutcome.saved => 'Saved to Downloads',
      DownloadOutcome.kept => 'Kept in this container',
      DownloadOutcome.failed =>
        result.reason != null ? refusalMessage(result.reason!) : 'Download failed',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ... _openReader, _handleRefusal, build unchanged ...
}
```

- [ ] **Step 9: Run the full suite and confirm green**

```
flutter test test/data/container_engine_channel_test.dart test/ui/features/container_route_test.dart
flutter test
flutter analyze
```

Expect all decode tests and both new widget tests passing, the full suite green, and `flutter analyze` reporting no issues. This task touches no Kotlin files, so no `flutter build apk` is needed here — Task 4 exercises the native side this plumbing assumes.

- [ ] **Step 10: Commit**

```
git add lib/domain/models/engine_events.dart lib/data/services/container_engine.dart lib/data/services/container_engine_channel.dart lib/data/services/fake_container_engine.dart lib/ui/features/container/views/container_route.dart test/data/container_engine_channel_test.dart test/ui/features/container_route_test.dart
git commit -m "feat: add download-result plumbing and wire ContainerRoute to resolve downloads"
```
---

### Task 4: DownloadFetcher (Kotlin) — keepInContainer + saveToDevice-always-manual + resolveDownload wiring + FileProvider

**Files:**
- Create: `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/main/res/xml/file_paths.xml`

**Interfaces:**
- Consumes:
  - Task 1: `fun SiteConfig.currentRoute(): Route` (extension in `Router.kt`); `object ProxyHttpClient { data class FetchedResponse(val status: Int, val reason: String, val headers: Map<String,String>, val body: java.io.InputStream); fun fetch(route: Route, host: String, port: Int, method: String, path: String, requestHeaders: Map<String,String>): FetchedResponse }`
  - Task 2: `data class PendingDownload(val url: String, val mimeType: String, val fileName: String, val sizeBytes: Long, val kindLabel: String)` on `Session`, and `Session.pendingDownloads: LinkedHashMap<String, PendingDownload>`
  - Pre-existing (unchanged by this plan): `EngineChannel.nextRequestId(): String`; `EngineChannel`'s `private val context: Context` field; `Route` / `RouteFailure` (`Router.kt`); `routeFailureToDartName(kotlinName: String): String` (bottom of `EngineChannel.kt`)
- Produces:
  - `DownloadFetcher.kt`: `sealed class DownloadOutcome { object Saved; object Kept; data class Failed(val reason: RouteFailure?) }`, `class DownloadFetcher(context) { fun run(config: SiteConfig, pending: PendingDownload, decisionName: String): DownloadOutcome }`, top-level `fun sanitizeFileName(name: String): String` — all consumed by Task 5 (which rewrites the `"saveToDevice"` branch inside `run` to be route-dependent) and Task 6 (which relies on the `downloads/<profileId>` directory convention this task establishes in `keepInContainer`)
  - `EngineChannel.kt`: new `"resolveDownload"` method-channel case, new private `resolveDownload(requestId, decisionName)`, new fields `downloadExecutor`, `mainHandler`, `downloadFetcher` — consumed by Dart's `resolveDownload` invoke (Task 3) and by Task 6 (which adds `deleteDownloadsDir` calls alongside the pre-existing `"wipe"` case and `wipeAll()`, both left otherwise untouched by this task)
  - `com.mono.container.fileprovider` `<provider>` authority + `@xml/file_paths` — consumed by `DownloadFetcher.keepInContainer`'s own `FileProvider.getUriForFile` call in this same task; no later task needs to reference the authority string directly

- [ ] **Step 1: Write `DownloadFetcher.kt`**

  Read `android/app/src/main/kotlin/com/mono/container/engine/Router.kt` and `RequestInterceptor.kt` first (already done while drafting this task) — `Route`/`RouteFailure` live in `Router.kt` with no package-qualification needed since `DownloadFetcher` sits in the same `com.mono.container.engine` package, and `RequestInterceptor.fetchThrough`'s existing host/port/path derivation (line 79–87 as of this read) is the pattern `fetchTo` below follows, just sourced from a `java.net.URL` string (`pending.url`) instead of a `WebResourceRequest.url`.

  Create `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt`:

  ```kotlin
  package com.mono.container.engine

  /**
   * The three things `resolveDownload` can end in. Deliberately mirrors
   * Dart's `DownloadOutcome` enum name-for-name (`saved`/`kept`/`failed`) —
   * see [EngineChannel.resolveDownload], which is what actually maps this
   * to the wire strings the event channel sends.
   */
  sealed class DownloadOutcome {
      object Saved : DownloadOutcome()
      object Kept : DownloadOutcome()
      data class Failed(val reason: RouteFailure?) : DownloadOutcome()
  }

  /**
   * Runs a resolved download decision to completion. Two decisions reach
   * here — `"discard"` is filtered out by [EngineChannel.resolveDownload]
   * before this class is ever invoked, so it is a hard error here, not a
   * silent no-op, if that invariant is ever broken.
   *
   * Both branches share the same route check: Turn 8 / Global Constraints
   * — "the interceptor never falls back to direct" — applies to a download
   * exactly as much as it applies to the page's own requests. A refused
   * route fails the download instead of ever touching a socket.
   *
   * `saveToDevice` always goes through [saveViaMediaStore] here, for every
   * route including [Route.Direct]. That's deliberately not the final
   * word — Task 5 makes the `Route.Direct` case use the real system
   * `DownloadManager` instead, which is strictly better (a real progress
   * notification, resumable, doesn't hold this process's memory). This
   * task's version is already correct and shippable on its own; it's just
   * not yet the *best* implementation for the unproxied case.
   */
  class DownloadFetcher(private val context: android.content.Context) {

      fun run(config: SiteConfig, pending: PendingDownload, decisionName: String): DownloadOutcome {
          val route = config.currentRoute()
          if (route is Route.Refused) return DownloadOutcome.Failed(route.failure)
          val fileName = sanitizeFileName(pending.fileName)
          return when (decisionName) {
              "keepInContainer" -> runCatching { keepInContainer(route, config, pending, fileName) }
                  .getOrElse { DownloadOutcome.Failed(null) }
              "saveToDevice" -> runCatching { saveViaMediaStore(route, pending, fileName) }
                  .getOrElse { DownloadOutcome.Failed(null) }
              else -> error("resolveDownload filters \"discard\" before this is ever called")
          }
      }

      /**
       * Fetches the file into this profile's own private downloads
       * directory, then hands it to the OS via a `FileProvider`-backed
       * `ACTION_VIEW` intent so the user can open it with whatever app they
       * choose — "kept in the container" means it never touches the
       * shared `Downloads/` collection at all.
       */
      private fun keepInContainer(
          route: Route,
          config: SiteConfig,
          pending: PendingDownload,
          fileName: String,
      ): DownloadOutcome {
          val dir = java.io.File(context.filesDir, "downloads/${config.profileId}")
          dir.mkdirs()
          val target = uniqueFile(dir, fileName)
          fetchTo(route, pending, target)

          val uri = androidx.core.content.FileProvider.getUriForFile(
              context, "${context.packageName}.fileprovider", target,
          )
          val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
              setDataAndType(uri, pending.mimeType)
              addFlags(
                  android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                      android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION,
              )
          }
          context.startActivity(intent)
          return DownloadOutcome.Kept
      }

      /**
       * The manual, route-aware path used for every proxied download and
       * (until Task 5) every direct one too: fetch to a private temp file,
       * then insert into the shared `MediaStore.Downloads` collection —
       * the only sanctioned way to write into the public Downloads
       * directory from `minSdk 29` (scoped storage) without a permission.
       */
      private fun saveViaMediaStore(
          route: Route,
          pending: PendingDownload,
          fileName: String,
      ): DownloadOutcome {
          val temp = java.io.File.createTempFile("dl", null, context.cacheDir)
          return try {
              fetchTo(route, pending, temp)
              val resolver = context.contentResolver
              val values = android.content.ContentValues().apply {
                  put(android.provider.MediaStore.Downloads.DISPLAY_NAME, fileName)
                  put(android.provider.MediaStore.Downloads.MIME_TYPE, pending.mimeType)
              }
              val uri = resolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                  ?: return DownloadOutcome.Failed(null)
              val opened = resolver.openOutputStream(uri)
                  ?: return DownloadOutcome.Failed(null)
              opened.use { out -> temp.inputStream().use { it.copyTo(out) } }
              DownloadOutcome.Saved
          } finally {
              temp.delete()
          }
      }

      /**
       * Streams [pending]'s body straight to [target]. Host/port/path
       * derivation mirrors `RequestInterceptor.fetchThrough` exactly (port
       * defaults by scheme when the URL omits one) — the only difference is
       * the source is a stored URL string here, not a live `WebResourceRequest`.
       */
      private fun fetchTo(route: Route, pending: PendingDownload, target: java.io.File) {
          val url = java.net.URL(pending.url)
          val host = url.host
          val port = if (url.port != -1) url.port else if (url.protocol == "https") 443 else 80
          val path = (url.path?.ifEmpty { "/" } ?: "/") + (url.query?.let { "?$it" } ?: "")
          val response = ProxyHttpClient.fetch(route, host, port, "GET", path, emptyMap())
          java.io.FileOutputStream(target).use { out ->
              response.body.use { input -> input.copyTo(out) }
          }
      }

      /** Never overwrites — appends " (1)", " (2)", … on a name collision. */
      private fun uniqueFile(dir: java.io.File, fileName: String): java.io.File {
          val dot = fileName.lastIndexOf('.')
          val base = if (dot > 0) fileName.substring(0, dot) else fileName
          val ext = if (dot > 0) fileName.substring(dot) else ""
          var candidate = java.io.File(dir, fileName)
          var suffix = 1
          while (candidate.exists()) {
              candidate = java.io.File(dir, "$base ($suffix)$ext")
              suffix++
          }
          return candidate
      }
  }

  /**
   * Strips path separators and traversal segments — [PendingDownload.fileName]
   * is guessed from a remote URL/Content-Disposition header (see Task 2's
   * `URLUtil.guessFileName` call) and must not be trusted as a safe path
   * segment for either [DownloadFetcher]'s own private directory or the
   * shared `MediaStore` display name.
   */
  fun sanitizeFileName(name: String): String {
      val stripped = name.replace(Regex("[/\\\\]"), "_").replace("..", "_").trimStart('.')
      return stripped.ifEmpty { "download" }
  }
  ```

- [ ] **Step 2: Wire `resolveDownload` into `EngineChannel`**

  `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt` currently declares its mutable state at lines 105–107:
  ```kotlin
      private val sessions = LinkedHashMap<String, Session>()
      private var sink: EventChannel.EventSink? = null
      private var requestCounter = 0
  ```
  Add three fields immediately after `requestCounter`:
  ```kotlin
      private var requestCounter = 0
      private val downloadExecutor = java.util.concurrent.Executors.newCachedThreadPool()
      private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
      private val downloadFetcher = DownloadFetcher(context)
  ```

  The method-channel `when` in `onMethodCall` currently reads (lines 204–208):
  ```kotlin
                  "resolvePermission" -> {
                      resolvePermission(call.argument<String>("requestId")!!, call.argument<String>("decision")!!)
                      result.success(null)
                  }
                  "extractArticle" -> extractArticle(call.argument<String>("siteId")!!, result)
  ```
  Add a `"resolveDownload"` case between them:
  ```kotlin
                  "resolvePermission" -> {
                      resolvePermission(call.argument<String>("requestId")!!, call.argument<String>("decision")!!)
                      result.success(null)
                  }
                  "resolveDownload" -> {
                      resolveDownload(call.argument<String>("requestId")!!, call.argument<String>("decision")!!)
                      result.success(null)
                  }
                  "extractArticle" -> extractArticle(call.argument<String>("siteId")!!, result)
  ```

  `resolvePermission`'s private implementation currently ends at line 279 (the `return`/closing-brace of its `for` loop, followed by the "silent no-op" comment). Add the new private method right after it, before `extractArticle`:
  ```kotlin
      /**
       * `pendingDownloads` is per-[Session] (Task 2), same shape as
       * `pendingPermissions` above — the linear scan across sessions mirrors
       * `resolvePermission`'s own, and for the same reason: a request id is
       * unique but nothing indexes *which* session issued it without
       * walking the map.
       *
       * The actual fetch runs off the platform thread — it can block on a
       * socket for up to the same 15s timeout `ProxyHttpClient`/`Router`
       * already use elsewhere — and posts its result back via [mainHandler]
       * once done, since [EventChannel.EventSink.success] must be called on
       * the platform thread.
       */
      private fun resolveDownload(requestId: String, decisionName: String) {
          for (session in sessions.values) {
              val pending = session.pendingDownloads.remove(requestId) ?: continue
              if (decisionName == "discard") return
              downloadExecutor.execute {
                  val outcome = downloadFetcher.run(session.config, pending, decisionName)
                  val (outcomeName, reasonName) = when (outcome) {
                      is DownloadOutcome.Saved -> "saved" to null
                      is DownloadOutcome.Kept -> "kept" to null
                      is DownloadOutcome.Failed -> "failed" to outcome.reason?.name?.let(::routeFailureToDartName)
                  }
                  mainHandler.post {
                      sink?.success(mapOf(
                          "type" to "download_result",
                          "requestId" to requestId,
                          "outcome" to outcomeName,
                          "reason" to reasonName,
                      ))
                  }
              }
              return
          }
          // Same "already gone" no-op as resolvePermission — the site closed
          // or the request otherwise vanished before a decision arrived.
      }
  ```
  Note: this reads `session.pendingDownloads` and `PendingDownload` (Task 2) and `session.config` (pre-existing `Session.config`) — all already landed by the time this task runs, per this task's `Depends on`.

- [ ] **Step 3: Declare the `FileProvider` in the manifest**

  `android/app/src/main/AndroidManifest.xml` currently has one `<application>` child block ending with the `flutterEmbedding` meta-data (lines 30–32) before the closing `</application>` tag (line 33). Add the `<provider>` block right after that meta-data, still inside `<application>`:
  ```xml
          <meta-data
              android:name="flutterEmbedding"
              android:value="2" />
          <provider
              android:name="androidx.core.content.FileProvider"
              android:authorities="com.mono.container.fileprovider"
              android:exported="false"
              android:grantUriPermissions="true">
              <meta-data
                  android:name="android.support.FILE_PROVIDER_PATHS"
                  android:resource="@xml/file_paths" />
          </provider>
      </application>
  ```
  (`com.mono.container` is the confirmed `applicationId` in `android/app/build.gradle.kts:19`, so `${applicationId}.fileprovider` used in `DownloadFetcher.keepInContainer` resolves to exactly this authority string.)

- [ ] **Step 4: Add the FileProvider path spec**

  `android/app/src/main/res/xml/` does not exist yet in this tree. Create `android/app/src/main/res/xml/file_paths.xml`:
  ```xml
  <?xml version="1.0" encoding="utf-8"?>
  <paths xmlns:android="http://schemas.android.com/apk/res/android">
      <files-path name="downloads" path="downloads/" />
  </paths>
  ```
  `<files-path>` maps to `context.filesDir`, matching `keepInContainer`'s `File(context.filesDir, "downloads/${config.profileId}")` target exactly — anything written under `filesDir/downloads/` is coverable by this provider, and nothing else is exposed.

- [ ] **Step 5: Verify**

  No Kotlin JVM test exists for this file (same precedent as Tasks 1 and 2 — Robolectric/instrumentation is out of scope for this repo's current test setup, and `androidx.core.content.FileProvider`, `MediaStore`, and `Intent`/`startActivity` all require a real Android runtime to exercise). Verification here is:
  ```
  flutter analyze
  flutter build apk --debug
  ```
  Expect `flutter analyze`: "No issues found!" and the debug APK build to succeed — confirming `DownloadFetcher.kt` compiles against `SiteConfig.currentRoute()`/`ProxyHttpClient` (Task 1) and `PendingDownload`/`session.pendingDownloads` (Task 2), that `EngineChannel.kt`'s new method-channel case and imports resolve, and that the manifest's `<provider>` + `@xml/file_paths` are well-formed (a malformed provider entry fails manifest merging at build time, not silently). State this explicitly rather than inventing a test that can't run in this repo.

  Manual verification note (not automated, record as a step for whoever runs this task for real): after building, install the debug APK, open a site with a downloadable file, choose "Keep in this container" from the download sheet, and confirm a chooser/viewer opens for the file; separately choose "Save to device" and confirm the file appears in the system Downloads / Files app under the exact `fileName` guessed from the URL (with a numeric collision suffix if repeated).

- [ ] **Step 6: Commit**

  ```
  git add android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt android/app/src/main/AndroidManifest.xml android/app/src/main/res/xml/file_paths.xml
  git commit -m "feat: fetch, keep-in-container, and save-to-device for held downloads"
  ```
---

### Task 5: Direct-route saveToDevice upgrades to real system DownloadManager

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/SiteConfig.kt`

*(Note: the shared contract's header for this task lists only `DownloadFetcher.kt` under Files, but its own Produces text requires extracting `userAgentFor` into a shared function and updating `ContainerView.kt`'s call site — read literally, that touches two more files. This draft follows the Produces text, which is more specific, and lists all three files it actually requires.)*

**Interfaces:**
- Consumes: `DownloadFetcher.run(config: SiteConfig, pending: PendingDownload, decisionName: String): DownloadOutcome` and its `sealed class DownloadOutcome { Saved, Kept, Failed(reason) }`, `PendingDownload`, `SiteConfig.currentRoute()`, `Route`/`Route.Direct`/`Route.Proxy`/`Route.Refused`/`RouteFailure` (Task 1), `ProxyHttpClient` (Task 1, used internally by Task 4's already-written `saveViaMediaStore`/`fetchTo` — untouched by this task) — all from Task 4.
- Produces: `DownloadFetcher.run`'s `"saveToDevice"` branch becomes route-dependent (`Route.Direct` → real `android.app.DownloadManager`; `Route.Proxy` → unchanged `saveViaMediaStore` manual fetch, since `DownloadManager` cannot be pointed through this app's own SOCKS/HTTP proxy routing); a new top-level `fun userAgentFor(mode: String, context: android.content.Context): String` in `SiteConfig.kt`, consumed by both `ContainerView.kt` (delegates instead of its old private method) and `DownloadFetcher.kt`'s new `saveViaDownloadManager`. No later task in this plan consumes anything new from this task — Task 6 only touches wipe paths.

- [ ] **Step 1: Extract `userAgentFor` into a shared top-level function in `SiteConfig.kt`**

  `ContainerView.kt` currently defines this as a private instance method (lines 99–105) that reads `webView.context` in its `else` branch — a property being read during its own initializer's evaluation (line 29 calls it from inside `WebView(context).apply { ... }`, before the `webView` val has actually been assigned), which is fragile. Making the function take `context` as an explicit parameter, sourced from the constructor parameter already in scope at the call site, sidesteps that as a side effect of the extraction — not something this task set out to fix, but worth calling out since the diff removes the fragile reference.

  Add to the end of `android/app/src/main/kotlin/com/mono/container/engine/SiteConfig.kt` (after the existing `asJsString()` extension, keeping that file's existing top-level-function precedent):

  ```kotlin
  /**
   * Maps a per-site user-agent preference to the actual UA string sent to
   * remote servers. Shared by [ContainerView] (live browsing) and
   * [DownloadFetcher] (system DownloadManager downloads for Direct-routed
   * sites) — one place decides, matching how [Router]/[ProxyHttpClient]
   * already centralize routing and fetch behavior for this engine package.
   * Takes [context] explicitly rather than reading it off a WebView, since
   * DownloadFetcher has no WebView to read it from.
   */
  fun userAgentFor(mode: String, context: android.content.Context): String = when (mode) {
      "desktop" -> "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
      "minimal" -> "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
          "(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
      else -> android.webkit.WebSettings.getDefaultUserAgent(context)
  }
  ```

  No automated test — same precedent as every Kotlin-only task in this plan (Tasks 1/2/4/6): Robolectric/instrumentation is out of scope for this repo's current test setup.

- [ ] **Step 2: Delete `ContainerView`'s private `userAgentFor` and delegate to the shared one**

  In `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`, delete the private method at the current end of the class (lines 99–105):

  ```kotlin
      private fun userAgentFor(mode: String): String = when (mode) {
          "desktop" -> "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 " +
              "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
          "minimal" -> "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
              "(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36"
          else -> WebSettings.getDefaultUserAgent(webView.context)
      }
  ```

  And change the call site at line 29, inside the `webView` initializer:

  ```kotlin
          settings.userAgentString = userAgentFor(config.userAgentMode)
  ```

  to:

  ```kotlin
          settings.userAgentString = userAgentFor(config.userAgentMode, context)
  ```

  (`context` here is the class's own constructor parameter, already in scope at this call site and already used one line earlier at `WebView(context)` — this now resolves the shared top-level `userAgentFor(mode, context)` from `SiteConfig.kt` instead of the deleted private method.)

  The `import android.webkit.WebSettings` at the top of the file is still needed elsewhere (`WebView(context).apply { ... }`'s `settings` block references `WebSettings`-typed APIs only through `settings.*`, not the `WebSettings` class name directly outside the deleted method) — check after deleting: if `flutter analyze`/the Kotlin compiler flags it as an unused import once the private method is gone, remove the `import android.webkit.WebSettings` line; otherwise leave it. State the outcome in the commit.

- [ ] **Step 3: Make `DownloadFetcher.run`'s `"saveToDevice"` branch route-dependent**

  In `android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt` (written by Task 4), replace the `"saveToDevice"` line inside `run`'s `when (decisionName)`:

  ```kotlin
              "saveToDevice" -> runCatching { saveViaMediaStore(route, pending, fileName) }.getOrElse { DownloadOutcome.Failed(null) }
  ```

  with:

  ```kotlin
              "saveToDevice" -> when (route) {
                  is Route.Direct -> runCatching { saveViaDownloadManager(config, pending, fileName) }.getOrElse { DownloadOutcome.Failed(null) }
                  is Route.Proxy -> runCatching { saveViaMediaStore(route, pending, fileName) }.getOrElse { DownloadOutcome.Failed(null) }
                  is Route.Refused -> error("handled above")
              }
  ```

  (`route` is already refused-checked earlier in `run` via `if (route is Route.Refused) return DownloadOutcome.Failed(route.failure)`, so this inner `when` only ever actually dispatches `Direct`/`Proxy` — the `Refused` arm exists solely because `Route` is a sealed class and this `when` must be exhaustive. `Route.Proxy` keeps calling Task 4's manual `saveViaMediaStore`/`fetchTo`/`ProxyHttpClient` path unchanged, since Android's `DownloadManager` has no way to route a request through this app's own proxy — only a Direct-routed site's download can safely be handed to the OS.)

  Add the new private method, placed next to `saveViaMediaStore` in the same class:

  ```kotlin
      private fun saveViaDownloadManager(config: SiteConfig, pending: PendingDownload, fileName: String): DownloadOutcome {
          val downloadManager = context.getSystemService(android.content.Context.DOWNLOAD_SERVICE) as android.app.DownloadManager
          val request = android.app.DownloadManager.Request(android.net.Uri.parse(pending.url))
              .setMimeType(pending.mimeType)
              .addRequestHeader("User-Agent", userAgentFor(config.userAgentMode, context))
              .setDestinationInExternalPublicDir(android.os.Environment.DIRECTORY_DOWNLOADS, fileName)
              .setNotificationVisibility(android.app.DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
          android.webkit.CookieManager.getInstance().getCookie(pending.url)?.let { cookie -> request.addRequestHeader("Cookie", cookie) }
          downloadManager.enqueue(request)
          return DownloadOutcome.Saved
      }
  ```

  This uses the real per-site user-agent via the `userAgentFor(mode, context)` extracted in Step 1 (`DownloadFetcher`'s existing `private val context: android.content.Context` constructor field from Task 4, so no new field is needed here), rather than duplicating `ContainerView`'s mapping — resolving the note the contract left open in favor of option (a). No manifest permission is added for this: `minSdk = 29`/`targetSdk = 36` (`android/app/build.gradle.kts` lines 22–23) means the app targets scoped storage, under which `DownloadManager` writing to `DIRECTORY_DOWNLOADS` via `setDestinationInExternalPublicDir` does not require the `WRITE_EXTERNAL_STORAGE` permission — that requirement only applies below API 29.

  No automated test — same precedent as Tasks 1/2/4/6 (Kotlin `engine/` package has no JVM test harness in this repo). This path specifically cannot be exercised even by instrumentation without a real `DownloadManager` service and notification shade, so it is unusually manual even by this plan's existing standard.

- [ ] **Step 4: Verify**

  Run:

  ```
  flutter analyze
  flutter build apk --debug
  ```

  Expect `flutter analyze`: "No issues found!" and the debug APK to build successfully, confirming `SiteConfig.kt`, `ContainerView.kt`, and `DownloadFetcher.kt` all compile together with the new shared `userAgentFor` and the route-dependent `saveToDevice` branch.

  **Manual verification note** (no automated test can cover this): install the debug APK on a device or emulator, open a site whose proxy mode is `"direct"`, trigger a download (e.g. tap a PDF/image link on a page that serves one), choose "Save to device" on the held-download sheet, then confirm two things by hand: (1) the system notification shade shows a completed download notification for the site's `DownloadManager` request, and (2) the file appears in the device's Downloads app/folder with the correct file name and that it opens correctly (confirming `pending.mimeType` and the `User-Agent`/`Cookie` headers were accepted by the origin server). Separately, repeat with a site whose proxy mode is `"socks5"`/`"http"` and confirm "Save to device" still goes through the Task 4 manual `saveViaMediaStore` path (unchanged), i.e. that only the Direct case's behavior changed.

- [ ] **Step 5: Commit**

  ```
  git add android/app/src/main/kotlin/com/mono/container/engine/DownloadFetcher.kt android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt android/app/src/main/kotlin/com/mono/container/engine/SiteConfig.kt
  git commit -m "feat: use system DownloadManager for saveToDevice on direct-routed sites"
  ```
---

### Task 6: Wipe integration — delete kept-in-container files on every existing wipe path

**Files:**
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/ProfileManager.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt`
- Modify: `android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt`

**Interfaces:**
- Consumes: `DownloadFetcher.keepInContainer`'s on-disk layout from Task 4 — `File(context.filesDir, "downloads/${config.profileId}")` is the directory kept-in-container files land in. This task's code is also safe to land before Task 4 in isolation: `File.deleteRecursively()` on a directory that doesn't exist yet is a documented no-op, it just has nothing to do until Task 4 exists. Sequenced after Task 4 anyway for narrative clarity (build the directory before shipping the code that deletes it).
- Produces: `fun deleteDownloadsDir(context: android.content.Context, profileId: String)` (top-level, in `ProfileManager.kt`) — no later task in this plan calls it, but it's the one place "delete a profile's kept downloads" is decided, matching this plan's own precedent (Task 1's `SiteConfig.currentRoute()`, Task 5's `userAgentFor`) of extracting shared logic into a single top-level function rather than repeating it at each call site.

- [ ] **Step 1: Add `deleteDownloadsDir` to `ProfileManager.kt`**

`ProfileManager` has no `Context` field today (confirmed by reading the file — its constructor takes nothing, and both `profileFor` and `wipe`/`wipeAll` only ever touch `ProfileStore`). Adding a `Context` parameter to the class itself would mean touching every one of its existing call sites' construction (`ContainerView`, `EngineChannel`, wherever `ProfileManager()` is instantiated) for a capability only this one function needs. A standalone top-level function next to the class avoids that entirely, since Kotlin lets a file hold both a class and free functions.

Edit `android/app/src/main/kotlin/com/mono/container/engine/ProfileManager.kt`: add `import java.io.File` alongside the existing imports, and append the function after the class's closing brace.

```kotlin
package com.mono.container.engine

import android.content.Context
import androidx.webkit.Profile
import androidx.webkit.ProfileStore
import androidx.webkit.WebViewFeature
import java.io.File

/**
 * One WebView profile per site. A profile owns its own cookies, localStorage
 * and cache, which is what makes "Each site gets its own storage" true.
 *
 * Profile names are the opaque ids stored in the vault. They are never derived
 * from a host — see Global Constraints.
 */
class ProfileManager {

    fun isAvailable(): Boolean =
        WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)

    /**
     * Returns this site's profile, creating it on first use.
     * @throws IllegalStateException when the device cannot isolate. Callers
     * must surface this, never degrade to the default profile.
     */
    fun profileFor(profileId: String): Profile {
        check(isAvailable()) { "This device cannot isolate containers." }
        return ProfileStore.getInstance().getOrCreateProfile(profileId)
    }

    /** Destroys everything the profile holds. Irreversible. */
    fun wipe(profileId: String) {
        check(isAvailable()) { "This device cannot isolate containers." }
        val store = ProfileStore.getInstance()
        if (store.allProfileNames.contains(profileId)) {
            store.deleteProfile(profileId)
        }
    }

    /**
     * Destroys every profile the store holds, default excluded. Irreversible.
     *
     * Panic's first step. Dart cannot supply the id list: profile ids live in
     * `Site` rows inside the encrypted vaults, and the vault that is not open
     * cannot be read at all. `allProfileNames` is the only enumeration that
     * covers both.
     *
     * `deleteProfile` throws while a profile is attached to a live WebView, so
     * callers close every session first — see `ContainerPanicService`.
     */
    fun wipeAll() {
        check(isAvailable()) { "This device cannot isolate containers." }
        val store = ProfileStore.getInstance()
        for (name in store.allProfileNames.toList()) {
            if (name == Profile.DEFAULT_PROFILE_NAME) continue
            store.deleteProfile(name)
        }
    }
}

/**
 * Deletes every file a profile kept in-container via `DownloadFetcher.keepInContainer`
 * (Plan: DownloadManager integration, Task 4). Not part of [ProfileManager] itself —
 * kept downloads live under `context.filesDir`, not the WebView profile store, so
 * they need their own cleanup call at every site that already wipes a profile.
 * Safe to call for a profile with no kept downloads: [File.deleteRecursively] on a
 * directory that doesn't exist is a no-op.
 */
fun deleteDownloadsDir(context: Context, profileId: String) {
    File(context.filesDir, "downloads/$profileId").deleteRecursively()
}
```

- [ ] **Step 2: Call it from `ContainerView.dispose()`**

Current code (`ContainerView.kt`, read in full — the file has no `import java.io.File` and doesn't need one since it only calls the shared function):

```kotlin
    override fun dispose() {
        if (disposed) return
        disposed = true
        webView.stopLoading()
        webView.destroy()
        if (config.wipeOnExit) profiles.wipe(config.profileId)
    }
```

`ContainerView`'s own `context` constructor parameter isn't stored as a property (it's a plain `context: Context`, not `private val context: Context` — confirmed by reading the constructor), so it isn't reachable from `dispose()`. `webView.context` is already how this same class resolves a `Context` elsewhere (`userAgentFor`'s `WebSettings.getDefaultUserAgent(webView.context)` a few lines below), so use the same source here rather than changing the constructor.

Edit to:

```kotlin
    override fun dispose() {
        if (disposed) return
        disposed = true
        webView.stopLoading()
        webView.destroy()
        if (config.wipeOnExit) {
            profiles.wipe(config.profileId)
            deleteDownloadsDir(webView.context, config.profileId)
        }
    }
```

`deleteDownloadsDir` needs no import — same package (`com.mono.container.engine`) as `ContainerView`.

- [ ] **Step 3: Call it from `EngineChannel`'s `"wipe"` method-channel case**

Current code (`EngineChannel.kt`, read in full):

```kotlin
                "wipe" -> {
                    profiles.wipe(call.argument<String>("profileId")!!)
                    result.success(null)
                }
```

`EngineChannel` already has a `context` field — its constructor is `class EngineChannel(private val context: Context, private val profiles: ProfileManager)` (confirmed by reading the file), so it's reachable directly, unlike `ContainerView`'s. Edit to extract `profileId` into a local so it isn't parsed from the `MethodCall` twice:

```kotlin
                "wipe" -> {
                    val profileId = call.argument<String>("profileId")!!
                    profiles.wipe(profileId)
                    deleteDownloadsDir(context, profileId)
                    result.success(null)
                }
```

- [ ] **Step 4: Call it from `EngineChannel.wipeAll()`, enumerating every profile's downloads directory**

Current code (`EngineChannel.kt`, read in full):

```kotlin
    /**
     * Panic's first step. `deleteProfile` throws while a profile is attached to
     * a live WebView, so every session closes before the store is emptied.
     */
    private fun wipeAll() {
        for (siteId in sessions.keys.toList()) close(siteId)
        profiles.wipeAll()
    }
```

`ProfileManager.wipeAll()` enumerates via `ProfileStore.getInstance().allProfileNames` — a WebView-profile-store concept with no notion of the `downloads/` directory on disk. There's no need to route through it: `downloads/<profileId>` subdirectories are just files under `context.filesDir`, so listing that directory directly is simpler and correct on its own, independent of what `ProfileStore` knows about.

Ordering: delete downloads **after** `profiles.wipeAll()`, matching the order already used at the other two call sites in this task (profile wipe, then downloads wipe) — panic's actual sensitive-data floor is the profile's cookies/storage/cache plus the vault's data keys (`ContainerPanicService`, issue #6 in `CLAUDE.md`), and kept-in-container files are already unreadable once their originating profile and the vault key that named them are gone. Keeping the same order at all three sites also means there's exactly one pattern to audit, not two.

Edit to (add `import java.io.File` to `EngineChannel.kt`'s existing import block):

```kotlin
    /**
     * Panic's first step. `deleteProfile` throws while a profile is attached to
     * a live WebView, so every session closes before the store is emptied.
     */
    private fun wipeAll() {
        for (siteId in sessions.keys.toList()) close(siteId)
        profiles.wipeAll()
        // downloads/<profileId> isn't a WebView-profile concept, so it isn't
        // covered by profiles.wipeAll() — enumerate the filesystem directly.
        File(context.filesDir, "downloads").listFiles()?.forEach { it.deleteRecursively() }
    }
```

- [ ] **Step 5: Verify**

No Kotlin JVM test exists for this file or its neighbors (same precedent as Tasks 1/2/4/5 — Robolectric/instrumentation is out of scope for this repo's current test setup). Verify with:

```
flutter analyze
flutter build apk --debug
```

Both must succeed — this confirms `deleteDownloadsDir`, its three call sites, and the new `java.io.File` imports all compile together with the rest of the engine package.

**Manual verification** (do this by hand once on a device or emulator, since none of the three paths below can be exercised by an automated test in this repo):
1. Open a site, trigger a "Keep in this container" download (Task 4's `keepInContainer` path) so a file lands at the on-device equivalent of `.../app_flutter/downloads/<profileId>/<fileName>`.
2. Trigger a normal per-site wipe (whatever UI path calls the `"wipe"` method channel case for that site's `profileId`) and confirm `.../app_flutter/downloads/<profileId>/` no longer exists.
3. Repeat step 1, then trigger panic / "close all and wipe" (which calls `wipeAll()`) and confirm `.../app_flutter/downloads/` has no subdirectories left for any profile that had kept files.

- [ ] **Step 6: Commit**

```
git add android/app/src/main/kotlin/com/mono/container/engine/ProfileManager.kt android/app/src/main/kotlin/com/mono/container/engine/ContainerView.kt android/app/src/main/kotlin/com/mono/container/engine/EngineChannel.kt
git commit -m "feat: delete kept-in-container downloads on every wipe path"
```

**Known gaps:** none for this task's own scope — all three existing wipe paths (per-site dispose, single-profile `"wipe"`, panic's `wipeAll()`) now delete a profile's kept downloads. What remains out of scope for this whole plan is unchanged from the design spec: a MediaStore-saved or DownloadManager-saved file is intentionally left alone by wipe/panic (it's already outside the container, on the shared device Downloads surface, same as a normal browser's downloads).
---

### Task 7: Full verification pass

**Files:**
- Modify: `CLAUDE.md`

**Interfaces:**
- Consumes: Tasks 1–6 fully landed (`ProxyHttpClient`/`SiteConfig.currentRoute()` from Task 1; `HeldDownloadEvent.requestId`/`EngineChannel.pendingDownloads` from Task 2; `DownloadResult`/`ContainerEngine.resolveDownload`/`downloadResults()`/`ContainerRoute`'s snackbar wiring from Task 3; `DownloadFetcher`/FileProvider/`resolveDownload` method-channel case from Task 4; `saveViaDownloadManager`/shared `userAgentFor` from Task 5; `deleteDownloadsDir` wired into all three wipe sites from Task 6).
- Produces: nothing consumed by any later plan — this task only runs verification and records the outcome in `CLAUDE.md`.

- [ ] **Step 1: Run the full Dart test suite**

```bash
flutter test
```

Expected: every existing test still passes, plus the new tests Task 2 added to `test/data/container_engine_channel_test.dart` (the `HeldDownloadEvent.requestId` decode case) and the new tests Task 3 added to `test/data/container_engine_channel_test.dart` (`downloadResultFromEvent` for `saved`/`kept`/`failed`-with-reason) and `test/ui/features/container_route_test.dart` (the held-download-sheet-decision test and the download-result-snackbar test for all three `DownloadOutcome` values). If anything fails, stop and fix it before proceeding — do not paper over a failure by editing the test's expectation without first confirming the implementation is actually correct per the design spec.

- [ ] **Step 2: Run static analysis**

```bash
flutter analyze
```

Expected output: `No issues found!`. This is the first point some of Task 4/5/6's Kotlin-adjacent Dart glue (if any) and every Dart file touched across Tasks 2–3 get analyzed together as one tree — treat any warning as a real defect to fix, not a pre-existing condition to ignore, since Tasks 1–6 were each verified individually but never as one merged whole until this step.

- [ ] **Step 3: Build the debug APK**

```bash
flutter build apk --debug
```

Expected: build succeeds. This is the *only* point in the whole plan where all six Kotlin files this plan touches or creates — `Router.kt` and the new `ProxyHttpClient.kt` (Task 1), `RequestInterceptor.kt` (Task 1), `ContainerView.kt` (Tasks 2, 5's `userAgentFor` extraction, and 6), `ContainerViewFactory.kt` (Task 2), `EngineChannel.kt` (Tasks 1, 2, 4, and 6), and the new `DownloadFetcher.kt` (Tasks 4 and 5) — get compiled together as one unit, alongside the new `AndroidManifest.xml` `<provider>` entry and `res/xml/file_paths.xml` (Task 4). None of Tasks 1, 2, 4, 5, or 6 has an automated Kotlin test (no Robolectric/instrumentation setup exists in this repo — established precedent, not an oversight of this plan), so a clean build here is the strongest automated signal this plan gets that the six files are mutually consistent. Treat a build failure with the same severity as a failing test: stop and fix it, don't relax the step to "best-effort."

- [ ] **Step 4: Manually re-confirm the two manual-verification notes from Tasks 5 and 6**

These cannot be automated (no emulator/instrumentation harness in this repo — same precedent noted in Tasks 1, 4, and 5's own steps), so record that they were actually exercised by hand, not merely built:
- Task 5's note: trigger a real "save to device" download on a **Direct**-routed site (no proxy configured) on a device/emulator, and confirm it appears in the system Downloads app / notification shade (not just in this app's own container storage) — this is the one path `flutter build apk --debug` cannot exercise, since it depends on the real `DownloadManager` system service actually running a download to completion.
- Task 6's note: keep at least one file in a container via "keep in container," then trigger "Close all and wipe" (or panic) for that profile, and confirm `context.filesDir`'s `downloads/<profileId>/` directory (on a real device: `/data/data/com.mono.container/files/downloads/<profileId>/`) no longer exists afterward.

If either manual check fails, treat it as a blocking defect in the task that produced it (5 or 6 respectively) — fix there, then re-run Steps 1–3 before returning to this step.

- [ ] **Step 5: Update `CLAUDE.md`'s "Unassigned work" section**

Read the file's current "Download interception" bullet first to confirm it still reads as below (it was last touched by Plan 6's own landing) — if the wording has drifted, adapt the `old_string` match accordingly rather than forcing this edit to fail silently.

Replace:

```markdown
- ~~Download interception~~ — Plan 6 Task 3 (`ContainerView`'s
  `DownloadListener` → `download` event). Known gap: downloads are held,
  never actioned — no `DownloadManager` integration, matching the design
  spec's own stated scope.
```

with:

```markdown
- ~~Download interception~~ — Plan 6 Task 3 (`ContainerView`'s
  `DownloadListener` → `download` event). Known gap: downloads are held,
  never actioned — no `DownloadManager` integration, matching the design
  spec's own stated scope. **Update, <TODAY'S DATE — match the YYYY-MM-DD
  format used elsewhere in this file, e.g. the biometric-unlock entry above;
  fill in the actual date this step is run, don't reuse the plan's draft
  date>:** real `DownloadManager`/`MediaStore`/private-directory integration
  now exists behind the held-download sheet's three actions (keep in
  container, save to device, discard), implementing
  `docs/superpowers/specs/2026-09-08-download-manager-integration-design.md`.
  `ProxyHttpClient` (new, `android/app/src/main/kotlin/com/mono/container/engine/ProxyHttpClient.kt`)
  centralizes the same Route-aware fetch `RequestInterceptor` already used for
  page loads, so a download's bytes always travel the site's actual route —
  refused exactly like a page load would be, never silently sent unproxied.
  `DownloadFetcher` (new, same package) resolves each of the three sheet
  decisions: "keep in container" streams into
  `context.filesDir/downloads/<profileId>/` and opens the result via a new
  `FileProvider` (`res/xml/file_paths.xml`); "save to device" always worked —
  on a Proxy-routed site via a manual fetch + `MediaStore` insert (since the
  system `DownloadManager` cannot itself speak through this app's proxy
  routing), and on a Direct-routed site via the real system `DownloadManager`
  (visible in the system Downloads app and notification shade, with the
  site's actual `userAgentFor` mode and cookies attached). `EngineChannel`
  gained a `resolveDownload` method-channel case and a `download_result`
  event carrying the outcome (`saved`/`kept`/`failed`) back to
  `ContainerRoute`, which now shows a snackbar for each. Every existing wipe
  path (`ContainerView.dispose`'s `wipeOnExit`, `EngineChannel`'s `wipe` case,
  and `wipeAll()`) now also deletes that profile's (or, for `wipeAll()`,
  every profile's) `downloads/` directory, so a kept-in-container file never
  survives a wipe. 6 tasks, all executed; verified `<TODAY'S DATE, same value
  as above>`: `flutter test` `<PASS COUNT>/<PASS COUNT>` passing, `flutter
  analyze` clean, `flutter build apk --debug` succeeding with all six touched
  Kotlin files compiling together. Commits: `<TASK 1 COMMIT SHA>` ("refactor:
  extract shared proxy-fetch client and route resolution"), `<TASK 2 COMMIT
  SHA>` ("feat: thread download URL and requestId through the event
  pipeline"), `<TASK 3 COMMIT SHA>` ("feat: add download-result plumbing and
  wire ContainerRoute to resolve downloads"), `<TASK 4 COMMIT SHA>` ("feat:
  fetch, keep-in-container, and save-to-device for held downloads"), `<TASK 5
  COMMIT SHA>` ("feat: use system DownloadManager for saveToDevice on
  direct-routed sites"), `<TASK 6 COMMIT SHA>` ("feat: delete kept-in-container
  downloads on every wipe path") — whoever runs this step for real: fill in
  each task's actual short SHA from `git log --oneline` once it exists, do
  not invent one. (These commit-message quotes are copied verbatim from each
  task's own Commit step above — if a task's implementer deviates from the
  exact message given there, quote what was actually committed instead.)
```

Do not invent a real date or real commit SHAs while drafting this plan — those placeholders are filled in by whoever actually executes this task, from the real `git log` and the real calendar date at that time. Leaving them as bracketed placeholders here is correct; silently making up plausible-looking values would not be.

- [ ] **Step 6: Commit the `CLAUDE.md` update**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: record download manager integration in CLAUDE.md

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Confirm the commit landed**

```bash
git log -1 --stat
```

Expected: the commit's diffstat shows only `CLAUDE.md` changed. This closes out the plan — no further steps.
---

## Known gaps this plan accepts (inherited from the spec)

- **No screen to browse previously-kept-in-container files.** Only the open-once-on-completion `FileProvider` intent exists.
- **No resume for interrupted downloads on the manual-fetch path.** Only the Direct-route/`DownloadManager` case gets real resumability.
- **No notification centre for backgrounded results.** If the user leaves a site's `ContainerRoute` before its download resolves, the snackbar is never shown, though the file still lands — same already-tracked gap as backgrounded permission/tunnel events generally.
- **Range/partial-content requests are not specially handled**, matching this app's already-accepted "range/media interception is lossy" limitation.
- **No virus/content scanning, no file-size cap.**
- **A `MediaStore`-saved or `DownloadManager`-saved file is intentionally left alone by wipe/panic** — it already left the container onto the shared device Downloads surface, same as any other browser's downloads.

---

## Defects found while executing (2026-09-09) — NOT accepted, and NOT fixed by this plan

These are distinct from the accepted gaps above: none of them was a design
decision, and none should be read as signed off. Recorded here by the
session that executed Tasks 1-6 and 7, with the user's explicit decision to
document now and fix under a dedicated plan.

### 1. BLOCKING (feature-level): the engine performs no TLS, so "keep in container" fails for every `https://` download

`Router.connect` returns a plain `java.net.Socket` and `ProxyHttpClient.fetch`
writes a cleartext `GET <path> HTTP/1.1` into it. For an `https://` URL this
opens a raw TCP socket to port 443 and speaks plaintext at a server waiting
for a handshake. `grep -rn "SSLSocket\|SSLContext\|HttpsURLConnection\|createSocket" android/app/src/main/kotlin/`
returns zero hits.

`DownloadFetcher.fetchTo` is on the critical path for two of the three sheet
outcomes:

| Sheet action | Route | Mechanism | `https://` result |
|---|---|---|---|
| Keep in container | **any** | `fetchTo` → `ProxyHttpClient` | **broken** |
| Save to device | Proxy | `saveViaMediaStore` → `fetchTo` | **broken** |
| Save to device | Direct | system `DownloadManager` | works — the OS does its own TLS |

So this plan's headline feature is inoperative for essentially every real
download URL, and the only reliable path is Direct-routed "save to device".
Page loads are largely insulated because `RequestInterceptor.intercept`
returns `null` for `Route.Direct` and lets WebView do its own TLS; **proxied**
`https` page loads have the same flaw, but that is pre-existing Plan 3
behavior, not something this plan introduced.

**Evidence this was intended and forgotten, rather than deliberately scoped
out:** `RouteFailure.TLS_FAILURE` exists in the Kotlin enum (`Router.kt:4`),
is mapped across the channel to Dart `tlsFailure` (`EngineChannel.kt:400`),
and has user-facing copy ready to display — `'The secure connection failed'`
(`route_decision.dart:58`). Its only producer is the `SSLException` catch at
`RequestInterceptor.kt:49`, which can never fire because nothing on the path
ever attempts a handshake; that catch is also the sole `javax.net.ssl`
reference in the entire engine. A failure mode is not given an enum, a
channel mapping, and display copy if it was knowingly skipped.

**Not fixed here, deliberately.** Adding TLS responsibly means certificate
validation, hostname verification, and correct interaction with the CONNECT
tunnel in item 2 below — getting any of those wrong is materially worse than
the current honest breakage, and none of it should be written without a spec
or a device to test against. Needs its own brainstorm → spec → plan, per this
repo's convention. **Owner: unassigned.**

### 2. OPEN QUESTION (not a finding): whether Android supports `Proxy.Type.HTTP` for a raw `Socket`

`Router.connect` builds `java.net.Socket(java.net.Proxy(Type.HTTP, ...))` and
then calls `connect(targetAddress)`. On OpenJDK 8+ that path uses
`HttpConnectSocketImpl` and issues a real CONNECT tunnel, which would make the
origin-form `GET /path` the code sends correct. If Android's libcore does not
support `Proxy.Type.HTTP` for raw sockets, the constructor throws
`IllegalArgumentException` and the HTTP-proxy route is entirely non-functional;
if it instead yielded a plain socket to the proxy, origin-form would be wrong
there too, since HTTP proxies expect absolute-form (`GET http://host/path`).

Deliberately recorded as an open question, not asserted either way — nobody
has run it on a device. Same subsystem and same manual check as item 1, so
whichever plan takes the TLS work should settle this in the same pass.

### 3. FIXED (`5e970f5`): `ContainerView`'s Context was not retained, so Task 6 Step 2 could not compile

Task 6 Step 2's `deleteDownloadsDir(context, config.profileId)` inside
`dispose()` did not compile: `ContainerView`'s constructor declared
`context: Context` with no `val`, making it a plain constructor parameter, in
scope only in property initializers and the `init` block. The two pre-existing
uses (`WebView(context)`, `userAgentFor(..., context)`) are both property
initializers and compiled fine; the new call in a member function did not.
Kotlin's diagnostic is misleading — it parses the bare identifier as the
`context(...)` context-parameters keyword rather than reporting an unresolved
name.

This is a **plan defect, not a transcription slip**: Task 6 Step 1 reasoned
explicitly about `ProfileManager` not having a `Context` and chose a top-level
function to avoid threading one through it — then Step 2 assumed
`ContainerView` had a usable one without checking. Fixed with `private val` on
that parameter, the minimal correct change.

**Why it survived to a commit:** `flutter analyze` and `flutter test` are
Dart-only. Nothing in this repo's normal verification pipeline ever compiles
the `engine/` package, so Tasks 1/2/4/5/6 were committed at `5a27dbf` having
never once been compiled. `flutter build apk --debug` is the only check that
would have caught it, and it is not part of any routine loop. Worth treating
as a standing lesson for any future Kotlin work here, not just this plan.

# DownloadManager integration for held downloads — design

**Status:** Approved by the user 2026-09-08.

## Problem

Spec `7c`'s held-download sheet (`HeldDownloadSheet`) and Plan 6's `download`
event pipeline (`EngineChannel.onDownload` → `ContainerEngine.downloads()` →
`ContainerRoute._showDownloadSheet`) both exist and are wired end to end —
except the very last step. `ContainerRoute._showDownloadSheet`'s `onDecision`
callback is `(_) => Navigator.pop(context)`: whichever of the sheet's three
buttons the user taps, the sheet just closes. Nothing is ever kept, saved, or
even discarded on purpose — it happens to vanish either way. Plan 6's own
Handoff names this as a known gap explicitly.

Two things found while scoping this matter more than that one-line
description suggested, and both are settled below rather than left implicit:

1. **The download URL itself never reaches native code that could act on
   it.** `ContainerView.kt`'s `WebView.setDownloadListener` receives `url`,
   `contentDisposition`, `mimeType`, and `contentLength` from Android, but
   the `onDownload` callback it calls only forwards a guessed file name, the
   size, and a kind label — the URL is read once, to guess a file name, and
   then dropped. There is currently no way to fetch the file at all, by any
   mechanism, because nothing downstream of the WebView ever sees where it
   came from.
2. **Android's system `DownloadManager` cannot honor this app's per-site
   proxy.** This app enforces "the interceptor never falls back to direct"
   (Global Constraints, repeated in every plan) at the `RequestInterceptor`
   layer: a site configured to route through a SOCKS/HTTP proxy gets a
   hand-rolled socket fetch through that proxy (`RequestInterceptor.fetchThrough`),
   never a raw direct connection, and a site whose proxy is unreachable is
   refused outright rather than silently sent unproxied. `DownloadManager`
   has no API to point it at a per-request SOCKS/HTTP proxy. Using it
   unconditionally for "Save to device storage" would mean a proxied site's
   downloads are the one kind of traffic this app quietly sends direct —
   exactly the guarantee Global Constraints exists to prevent.

## Decision: route downloads exactly like page loads, never a third path

Every download — regardless of which of the sheet's three actions the user
picks — is resolved through the same `Router.resolve(config, proxyReachable)`
decision `RequestInterceptor` already uses for page loads, extracted into a
small shared function so there is exactly one place in the codebase that
decides how a site's traffic is routed, not two copies that could drift:

- **Route is `Refused`** (proxy configured but unreachable, or
  misconfigured): the download fails immediately, no attempt made — same
  refusal semantics as browsing, reusing the existing `RouteFailure` enum
  and its `refusalMessage()`/`proxyFailureHeadline()` copy already written
  for `ProxyUnreachableScreen` (`lib/domain/models/route_decision.dart`,
  `route_failure_copy.dart`), so download failure language matches
  page-load failure language app-wide instead of inventing a second
  vocabulary.
- **Route is `Direct`, action is "Save to device storage":** real
  `android.app.DownloadManager.enqueue()` — system notification, resumable,
  shows in the OS Downloads app, for free. Cookie and User-Agent headers are
  attached so authenticated downloads still work.
- **Every other combination** — route is `Proxy` (either action), or route
  is `Direct` and the action is "Keep inside this container" — goes through
  a manual fetch reusing the same socket-level HTTP code
  `RequestInterceptor.fetchThrough` already has, extracted into a small
  shared `ProxyHttpClient` both classes call. "Keep inside this container"
  never uses `DownloadManager` at all, on any route, because its
  destination (an app-private, per-profile directory) isn't something
  `DownloadManager` can target; "Save to device" on a `Proxy` route writes
  the manually-fetched bytes into `MediaStore.Downloads` via
  `ContentResolver` once the fetch completes — the standard scoped-storage
  way to add a file to the public Downloads collection without
  `DownloadManager`, and one that needs no runtime storage permission at
  this app's `minSdk 29`.
- **"Discard"** never fetches anything — the pending entry is simply
  dropped.

This is more code than "just call `DownloadManager` for everything," but a
download is exactly the kind of traffic Global Constraints was written to
cover, and the app already pays this cost once for page loads; reusing that
machinery here is cheaper than inventing a second, inconsistent policy.

## Mechanism

### Carrying the URL forward

`ContainerView.kt`'s `onDownload` callback signature gains the URL and, like
`onAsk`, returns a request id the caller can use to resolve the pending
download later:

```kotlin
private val onDownload: (url: String, mimeType: String, fileName: String, sizeBytes: Long, kindLabel: String) -> String =
    { _, _, _, _, _ -> "" },
```

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

`mimeType` is the same value `setDownloadListener` already receives and
today discards after using it once to help guess an extension —
`DownloadManager.Request.setMimeType()` and the `MediaStore.Downloads`
insert (see "The fetcher" below) both need a real MIME type to associate
with the saved file, not the two/three-letter display badge (`kindLabel`),
so it has to travel alongside `url` from here on, not be reconstructed
later from `kindLabel`.

`ContainerViewFactory` assigns the request id the same way it already does
for permission asks:

```kotlin
onDownload = { url, mimeType, fileName, sizeBytes, kindLabel ->
    val requestId = engine.nextRequestId()
    engine.onDownload(siteId, requestId, url, mimeType, fileName, sizeBytes, kindLabel)
    requestId
},
```

### Holding the pending download

`Session` (`EngineChannel.kt`) gains a second pending-request map, parallel
to `pendingPermissions`:

```kotlin
data class PendingDownload(
    val url: String,
    val mimeType: String,
    val fileName: String,
    val sizeBytes: Long,
    val kindLabel: String,
)

val pendingDownloads = LinkedHashMap<String, PendingDownload>()
```

`EngineChannel.onDownload` stores the entry and emits the same `download`
event shape as today (still no `mimeType`/`url` sent to Dart — Dart never
needed them for the sheet and still doesn't; only native needs them, to
perform the fetch after Dart reports back a decision), plus the new
`requestId`:

```kotlin
fun onDownload(siteId: String, requestId: String, url: String, mimeType: String, fileName: String, sizeBytes: Long, kindLabel: String) {
    val session = sessions[siteId] ?: return
    session.pendingDownloads[requestId] = PendingDownload(url, mimeType, fileName, sizeBytes, kindLabel)
    val host = runCatching { java.net.URI(session.config.url).host }.getOrNull() ?: session.config.url
    sink?.success(mapOf(
        "type" to "download", "siteId" to siteId, "requestId" to requestId,
        "fileName" to fileName, "sizeBytes" to sizeBytes, "sourceHost" to host, "kindLabel" to kindLabel,
    ))
}
```

### Resolving the decision

A new method-channel entry mirrors `resolvePermission` exactly:

```kotlin
"resolveDownload" -> {
    resolveDownload(call.argument<String>("requestId")!!, call.argument<String>("decision")!!)
    result.success(null)
}
```

```kotlin
private fun resolveDownload(requestId: String, decisionName: String) {
    for (session in sessions.values) {
        val pending = session.pendingDownloads.remove(requestId) ?: continue
        if (decisionName == "discard") return  // nothing fetched, nothing reported
        downloadExecutor.execute {
            val outcome = downloadFetcher.run(session.config, pending, decisionName)
            val (outcomeName, reasonName) = when (outcome) {
                is DownloadOutcome.Saved -> "saved" to null
                is DownloadOutcome.Kept -> "kept" to null
                is DownloadOutcome.Failed ->
                    "failed" to outcome.reason?.name?.let(::routeFailureToDartName)
            }
            mainHandler.post {
                sink?.success(mapOf(
                    "type" to "download_result", "requestId" to requestId,
                    "outcome" to outcomeName, "reason" to reasonName,
                ))
            }
        }
        return
    }
    // The request already timed out or its site closed — a silent no-op,
    // same convention `resolvePermission` already uses.
}
```

`downloadExecutor` (`java.util.concurrent.Executors.newCachedThreadPool()`),
`mainHandler` (`Handler(Looper.getMainLooper())`), and `downloadFetcher` are
three new private fields on `EngineChannel` — no new dependency for any of
them. The fetch must not run on the platform thread (it can move several MB
over a socket), and posting the result back through `mainHandler` is
required because `EventChannel.EventSink.success` is platform-thread-only,
same constraint every other event emission in this file already respects
implicitly by running on the platform thread already. `reason` reuses the
exact same Kotlin-enum-name → Dart-enum-name conversion
`EngineChannel.open()` already applies to `Session.failure`
(`route.failure.name.let(::routeFailureToDartName)`) — not a new mapping.

### The fetcher

New `DownloadFetcher.kt`. `discard` is filtered out by the caller above and
never reaches `run()`, so the outcome type only needs three shapes — no
`Discarded` case to keep in sync with a branch that can never produce it:

```kotlin
sealed class DownloadOutcome {
    object Saved : DownloadOutcome()
    object Kept : DownloadOutcome()
    /** [reason] is null for an I/O failure (disk write, enqueue) that has no
     * `RouteFailure` counterpart — [EngineChannel] sends a bare "failed"
     * with no reason for that case, and `ContainerRoute` falls back to a
     * generic "Download failed" snackbar. */
    data class Failed(val reason: RouteFailure?) : DownloadOutcome()
}

class DownloadFetcher(
    private val context: Context,
    private val downloadManager: android.app.DownloadManager,
) {
    fun run(config: SiteConfig, pending: PendingDownload, decisionName: String): DownloadOutcome {
        val route = config.currentRoute()  // extracted, shared with RequestInterceptor
        if (route is Route.Refused) return DownloadOutcome.Failed(route.failure)

        val fileName = sanitizeFileName(pending.fileName)  // strips path separators, "..", leading dots

        return when (decisionName) {
            "keepInContainer" -> keepInContainer(route, config, pending, fileName)
            "saveToDevice" -> when (route) {
                is Route.Direct -> saveViaDownloadManager(config, pending, fileName)
                is Route.Proxy -> saveViaMediaStore(route, config, pending, fileName)
                is Route.Refused -> error("handled above")
            }
            else -> error("resolveDownload filters \"discard\" before this is ever called")
        }
    }
    // keepInContainer / saveViaDownloadManager / saveViaMediaStore bodies below,
    // each returning DownloadOutcome.Saved/Kept on success or
    // DownloadOutcome.Failed(null) on an I/O exception.
}
```

- **`keepInContainer`**: always a manual fetch via the shared
  `ProxyHttpClient` (regardless of `route`), streamed to
  `File(context.filesDir, "downloads/${config.profileId}/$fileName")`
  (directories created as needed; a name collision gets a `(1)`, `(2)`, …
  suffix rather than overwriting). On success, opens the file with a
  `FileProvider`-issued `content://` URI, `setDataAndType(uri, pending.mimeType)`
  (needed so `ACTION_VIEW` can pick a matching viewer app at all), and
  `FLAG_ACTIVITY_NEW_TASK` (required — this call happens off an Activity
  context), and returns `DownloadOutcome.Kept`.
- **`saveViaDownloadManager`** (Direct route only): builds a
  `DownloadManager.Request(Uri.parse(pending.url))`, attaches
  `CookieManager.getInstance().getCookie(pending.url)` as a `Cookie` header
  and the site's configured User-Agent, sets `setMimeType(pending.mimeType)`,
  `setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)`
  and `setNotificationVisibility(VISIBILITY_VISIBLE_NOTIFY_COMPLETED)`, and
  enqueues. Returns `DownloadOutcome.Saved` once enqueued successfully — the
  system's own notification carries real progress/completion from here;
  this app's snackbar is reporting hand-off, not final completion, for this
  one path only (see "Feedback" below).
- **`saveViaMediaStore`** (Proxy route): fetches the full body via
  `ProxyHttpClient` into a temporary app-private file, then inserts it into
  `MediaStore.Downloads.EXTERNAL_CONTENT_URI` via `ContentResolver` with
  `DISPLAY_NAME` and `MIME_TYPE` (`pending.mimeType`) content values and
  copies the bytes across. Returns `DownloadOutcome.Saved` — for this path,
  unlike the `DownloadManager` one, the bytes are already fully on-device by
  the time this returns.

### Extracting the shared pieces

Two small refactors, not new behavior:

- `Router.kt` gains `fun SiteConfig.currentRoute(): Route`, wrapping the
  `Router.resolve(config, ProxyProbe.reachable(...))` pattern that
  `RequestInterceptor.proxyReachable`, `EngineChannel.open`, and now
  `DownloadFetcher` would otherwise each write separately. All three call
  sites switch to the shared extension function.
- `RequestInterceptor.fetchThrough`'s socket-level HTTP code (open via
  `Router.connect`, write the request line/headers, read the status line
  and headers back) moves into a small `ProxyHttpClient` object that returns
  a status/headers/`InputStream` triple; `fetchThrough` wraps that into a
  `WebResourceResponse` exactly as it does today, and `DownloadFetcher`
  streams the same `InputStream` to a file instead. Behavior for existing
  page-load proxying is unchanged — this is a pure extraction.

## Storage and wipe

Kept-in-container files live at `filesDir/downloads/<profileId>/`, an
app-private directory `ProfileManager`'s own multi-profile WebView API has
no reach into (`androidx.webkit.Profile` manages cookies/cache/localStorage,
not an arbitrary filesystem directory) — so nothing currently deletes it.
Three existing wipe call sites each get one added line, deleting that
directory recursively alongside what they already destroy:

- `ContainerView.dispose()`'s `wipeOnExit` branch (deletes on close, same
  moment it calls `profiles.wipe(config.profileId)`).
- `EngineChannel`'s `"wipe"` method-channel case (explicit "Close all and
  wipe," `2c`).
- `EngineChannel.wipeAll()` (panic's first step) — this one iterates every
  profile name the platform can enumerate, the same way `ProfileManager.wipeAll`
  already does, so a decoy vault's kept downloads are destroyed by panic
  even though this process could never have opened that vault to know its
  profile ids by name otherwise.

Without this, "wipe this container" would silently leave a copy of every
file it ever kept sitting on disk — a real gap given this app's whole
premise is that wiping a container actually removes what it held.

`pending.fileName` is attacker-influenced (guessed from a remote URL and
`Content-Disposition` header) and is used as a path segment in both the
private-directory case and the `MediaStore` `DISPLAY_NAME`; it is sanitized
(path separators, `..`, and leading dots stripped) before either use.

## Feedback

The sheet dismisses immediately on any tap, exactly as it does today (no
new progress/spinner state — spec `7c` draws none, and inventing one is a
bigger design footprint than this gap needs). The fetch runs in the
background; `EngineChannel` emits a `download_result` event
(`requestId`, `outcome`, optional `reason`) once it's known.
`ContainerEngine` gains:

```dart
Future<void> resolveDownload(String requestId, DownloadDecision decision);
Stream<DownloadResult> downloadResults();
```

```dart
enum DownloadOutcome { saved, kept, failed }

class DownloadResult {
  const DownloadResult({required this.requestId, required this.outcome, this.reason});
  final String requestId;
  final DownloadOutcome outcome;
  final RouteFailure? reason;  // non-null only when outcome == failed
}
```

`ContainerRoute` subscribes to `downloadResults()` the same way it already
subscribes to `downloads()`/`tunnelDropped()`, and shows a
`ScaffoldMessenger` snackbar this design owns the copy for:

- `saved` → `"Saved to Downloads"`
- `kept` → `"Kept in this container"`
- `failed` → `refusalMessage(reason!)` (reuses Plan 3's existing copy
  verbatim — no new failure vocabulary)

`discarded` never reaches Dart at all — nothing was attempted, so nothing is
reported (see "Resolving the decision" above).

`HeldDownloadEvent` gains the `requestId` field the sheet's `onDecision`
needs to close over:

```dart
class HeldDownloadEvent {
  const HeldDownloadEvent({required this.siteId, required this.requestId, required this.download});
  final String siteId;
  final String requestId;
  final HeldDownload download;
}
```

`ContainerRoute._showDownloadSheet`'s `onDecision` becomes:

```dart
onDecision: (decision) {
  Navigator.pop(context);
  ref.read(containerEngineProvider).resolveDownload(event.requestId, decision);
},
```

## Failure modes

- **Proxy unreachable or misconfigured at resolve time**: `download_result`
  arrives `failed` immediately, no fetch attempted — identical semantics to
  a refused page load.
- **Network error mid-fetch (timeout, TLS failure, connection reset) on the
  manual-fetch path**: caught in `DownloadFetcher`, mapped to the closest
  `RouteFailure` the same way `RequestInterceptor.fetchThrough` already
  maps socket exceptions, reported as `failed`.
- **Disk write failure (rare — out of space, permission denied on the
  private dir)**: caught, reported as `failed` with no `reason`
  (`DownloadOutcome.Failed(null)`, which has no `RouteFailure` counterpart);
  `ContainerRoute` shows a generic `"Download failed"` snackbar when
  `reason` is null.
- **`DownloadManager.enqueue()` itself throwing** (e.g. storage genuinely
  unavailable): same `Failed(null)` path.
- **The site's `ContainerRoute` is no longer on screen when the result
  arrives** (user navigated back to the dashboard before the fetch
  finished): the snackbar has nowhere to show — this app has no
  notification centre for backgrounded events (an explicitly separate,
  already-tracked known gap; see Known Gaps below). The fetch itself still
  completes and the file still lands wherever it was headed; only the
  confirmation is missed.
- **The app process dies mid-fetch**: the fetch dies with it (a plain
  `Executor` task, not a `WorkManager`/foreground-service-backed job).
  Nothing resumes it. Documented as a Known Gap, not fixed here — see below.

## Testing

- **Dart:**
  - `test/data/container_engine_channel_test.dart` (or wherever
    `downloadFromEvent` is currently tested): extend the `download` event
    decode for the new `requestId` field; add a `download_result` decode
    test and `resolveDownload`'s outbound `invokeMethod` shape.
  - `test/ui/features/container_route_test.dart`: extend
    `FakeContainerEngine` with `resolveDownload` call recording and
    `emitDownloadResult`; add cases for each `DownloadDecision` calling
    through with the right `requestId`, and each `DownloadOutcome` showing
    the right snackbar text.
  - `test/domain/held_download_test.dart`: extend for the new
    `HeldDownloadEvent.requestId` field.
- **Kotlin:** no JVM-runnable test exists today for anything in
  `engine/` that touches a real `WebView`/`DownloadManager`/`ContentResolver`
  (consistent with this repo's existing precedent for `ContainerView`,
  `RequestInterceptor`, etc. — Robolectric/instrumentation is out of scope
  for this repo's current test setup). `Router.currentRoute()`'s pure
  routing logic and `sanitizeFileName()` are the two pieces here that
  *could* be unit-tested without Android framework classes; if a plan
  chooses to add a `test/` directory under `android/` this is the natural
  first case, but no such directory exists yet, so this is a plan-time
  decision, not a spec requirement.

## Known gaps this design accepts

- **No screen to browse previously-kept-in-container files.** Only the
  open-once-on-completion `FileProvider` intent exists; there is no list of
  what a container is holding. A future plan's job if wanted.
- **No resume for interrupted downloads on the manual-fetch path.**
  `DownloadManager`'s own resume only covers the Direct-route/save-to-device
  case; a proxied fetch or a kept-in-container fetch that dies (network
  drop, app killed) simply fails, with no partial-download recovery.
- **No notification centre for backgrounded results.** If the user leaves
  a site's `ContainerRoute` before its download resolves, the snackbar is
  never shown, though the file still lands. This is the same gap already
  named separately in `CLAUDE.md`'s unassigned-work list (a notification
  centre for backgrounded WebView events generally) — this design does not
  attempt to solve it, only to not make it worse.
- **Range/partial-content requests are not specially handled** by
  `ProxyHttpClient`, matching this app's already-accepted "range/media
  interception is lossy" limitation (Plan 3's Known Limitations).
- **No virus/content scanning, no file-size cap.** A user can keep or save
  an arbitrarily large file; nothing in this design guards against that.

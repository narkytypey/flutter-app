# Open problems, 2026-09-30

A handoff for a cloud session. It covers what went wrong recently, which is
Plan 13 (the loopback proxy, P2) and its device run on the emulator. It was
written from the local sessions' transcripts and the tree at `85471e5`
(`origin/main`).

Read `CLAUDE.md` first, then
`docs/superpowers/plans/2026-09-30-loopback-proxy.md`, which is Plan 13 and
has its own execution record. **The cloud box has no Android emulator.** So
anything marked "needs the emulator" can be prepared here, but only the
user's machine can confirm it.

## State of `main`

- Plan 13 Tasks 1–6 are on `main` (`427df10`..`85471e5`). A cloud session
  pushed them straight to `main`. At `85471e5`: `flutter analyze` clean,
  `flutter test` 543/543, Kotlin JVM 167/167, APK builds.
- Plan 13 Task 7 (the emulator checks and the write-up) is **only partly
  done**. The session running it hit its usage limit partway through; see
  problem 4.
- `CLAUDE.md` has no Plan 13 row yet. Task 7 Step 4 adds it.

---

## 1. Serious: a proxy tunnel outlives its session and its route

**Seen on the emulator, strongly suggested but not proven byte for byte.**
The code confirms that the mechanism exists.

What happened (flutter-app-77, 20:39–20:40):

1. Site "ExD" (`https://example.com`) was open on the **direct** route. The
   app had an established socket to `104.20.23.154:443` (example.com), and a
   loopback pair `127.0.0.1:43070 ↔ 127.0.0.1:37185`.
2. ExD was closed from the switcher's ×, then edited to **SOCKS5**
   `10.0.2.2:1080`.
3. ExD was reopened and loaded `https://example.com/?b=<random>`, then
   `?c=<random>`. **Both pages rendered.** The loopback proxy logged **no new
   `CONNECT`**, and the SOCKS5 proxy saw nothing but the reachability probe
   (`SOCKS5 error eof`). The direct socket to `104.20.23.154:443` was still
   `ESTAB`.

So a site set to SOCKS5 was very likely served over its old **direct**
connection. That breaks the global constraint "the interceptor never falls
back to direct" in effect. The attempt to prove it by counting bytes on the
direct socket failed: the `ss -tin dst …` filter printed nothing.

**Why, from the code:**

- `SiteCredentials.unbind` (`engine/SiteCredentials.kt`) only removes the
  binding from the map.
- `LoopbackProxy.tunnel` (`engine/LoopbackProxy.kt`) resolves the route once,
  at `CONNECT` time, and then relays until either side closes. Nothing tracks
  live tunnels, so nothing closes them on `unbind`, or on a `bind` that
  replaces the config.
- Chromium keeps its connection pool per **profile**, and the profile lives on
  after the WebView closes. So on reopen it reuses the idle `CONNECT` tunnel
  to the loopback proxy, and that tunnel still goes out on the old route.
- The same applies after a `9c` lock (every session is closed and unbound)
  and after any settings change made while a session exists.

**Direction (not a decided design):**

- Track open tunnels and forward connections per profile.
- `unbind`, and a `bind` whose route differs from the current one, closes
  every socket opened under the old binding.
- Add a JVM test in `LoopbackProxyTest`: open a tunnel, unbind, and assert
  that both sockets are closed and that no further bytes cross.
- Consider whether a rebind to the **same** route should also close them. A
  lock followed by an unlock is the case to think about.

Also check the two other paths that reuse a profile across sessions: the
throwaway container (Plan 12) and "Save as a site", which `keep`s a
throwaway's profile.

**Needs the emulator to confirm:** repeat steps 1–3. After the fix, the
reopen must show a fresh `CONNECT` on SOCKS5 and no direct socket.

## 2. The 15 failing Kotlin tests: local only, not on `origin`

On the user's machine, `LoopbackProxyTest` fails 15 of its tests with
`NullPointerException at LoopbackProxyTest.kt:50`. The cause is an
**uncommitted** debug line added for the device run, at
`LoopbackProxy.kt:65`:

```kotlin
android.util.Log.d("P2", "${request?.method} ${request?.host}:${request?.port} -> ...")
```

`Log.d` throws on the JVM's stub `android.jar`. The handler's `runCatching`
swallows the exception and closes the socket without replying, so the test
reads no response. Stashing the line makes the tests pass.

Nothing to fix on `main`, which doesn't have it. But:

- **Never commit it.** It also logs hostnames, which the file's own contract
  forbids ("Nothing here logs a host or a credential").
- If a later device run needs request logging, inject a logger lambda
  (default no-op) through `LoopbackProxy`'s constructor, as `resolve` and
  `connect` already are. Don't call `android.util.Log` from engine code the
  JVM tests run.

## 3. The vault was wiped twice with no known cause

Both times on the emulator, on 2026-09-30.

- **First:** found wiped before the proxy-leak device run (already recorded
  in `CLAUDE.md` under "Proxy leak fixes"). The stores were gone and the
  profiles swept, which is the shape a panic leaves.
- **Second, 20:45:43:** during flutter-app-77's Task 7 run.
  - The harness had tapped the address pill's **Clear** (`896,207`), then
    typed a long URL with `adb shell input text '…'`.
  - The typing "went astray": the launcher came to the front, and the logs
    show a back gesture (`ShellBackPreview … Finishing gesture`) about 0.4 s
    before the wipe, and a swipe-home at 20:45:55. Neither was sent on
    purpose.
  - Relaunching showed the setup wizard ("Choose a PIN"). `app_flutter/` held
    no stores and `files/` held no journal.
  - The other session on the machine (flutter-app-85) sent no input; it only
    read `logcat`.

What is known:

- `panic(WidgetRef)` (`lib/ui/features/container/view_models/providers.dart`)
  is called from `ContainerRoute`'s `onPanic`. That comes from two places:
  the top bar's **Panic** button (`2b`, at about `1006,208`) and the switcher
  sheet's panic button (`2c`). The top bar's button sits right next to the
  pill's Clear/shield button at `896,207`, which the harness taps often.
- Panic is **one tap, with no confirmation**. The doc comment says that is
  deliberate: "`3c` reports afterwards, it does not ask first."

For the cloud session:

- Check the code for any other way to reach `panic`: a key event, back
  handling, a gesture, or a platform-channel call.
- If the buttons are the only way, the likely cause is a mis-targeted
  synthetic tap, not an app bug.
- **Don't add a confirmation.** One-tap panic is deliberate.

## 4. Plan 13 Task 7 is half done (needs the emulator)

What flutter-app-77 saw before its usage limit hit (Task 7 Step 2's numbering):

| Check | Result |
|---|---|
| Early check: first `CONNECT` gets `407`, the retry tunnels | seen |
| Early check: no re-challenge loop | seen (Autofill got `403` exactly 5 times; no loop) |
| 1. SOCKS5 preconnect goes by name through the proxy; the only device DNS lookup is the dns-prefetch hint | seen |
| 1. pagehide beacon / keepalive fetch on close | **inconclusive**: nothing was sent, but the probe navigation may not have taken |
| 2. SOCKS5 receives hostnames (`duckduckgo.com:443`) | seen |
| 3. cookie survives close and reopen | **inconclusive**: `"p2":"1"` was shown after the reopen, but with no new `CONNECT`, so problem 1 or the cache may explain it |
| 4. redirect (`postman-echo.com/cookies/set`) | seen |
| 4. form POST | not run |
| 5. strangers get `407`/`403` from the loopback port | seen with `nc`; one earlier probe got a `405` that the proxy never logged, probably another `127.0.0.1` listener (the Dart VM service), unresolved |
| 6. Autofill query answered `403` by the loopback proxy, never sent | seen |
| 7. lock, unlock, reopen | not run |
| 8. panic | not run on purpose (but see problem 3) |
| 9. direct site | seen; a throwaway search from it was in progress |
| 10. whole-run DNS log | not done |
| 11. http-mode site through `:8888` | not run |
| Task 6: SOCKS5 held download reads `13.0 KB · from www.w3.org` | seen |
| "Keep inside this container" on SOCKS5 | started, result not recorded |

Steps 3–5 (the write-up in the plan and `CLAUDE.md`) are not done. Fix
problem 1 before running Task 7 again, because it affects checks 3 and 7.

## 5. Open design questions: the user's to decide, don't decide them

From Plan 13's execution record, still open:

1. **The proxy override is applied asynchronously, and nothing waits for
   it.** `ProxyController.setProxyOverride` takes effect "not guaranteed
   immediately", and `Loopback.start()` passes an empty listener. Until the
   override applies, a WebView request goes direct. The vault unlock almost
   certainly covers that window, but nobody has observed that. Closing the
   window for certain needs new behaviour, and maybe new copy.
2. **A system-wide (Wi-Fi) proxy is ignored for direct sites.** The override
   replaces it, and has since `198cdda`. A network that only works through a
   configured proxy cannot load direct sites.

## 6. Environment notes: not app bugs

- This PC's IPv4 route to AWS and Azure hosts (duckduckgo.com, httpbin.org,
  squoosh.app) takes **14–15 s** to connect, even from `curl` on the host.
  Cloudflare hosts connect in 0.1 s. Chromium gives up on some tunnels at
  about 10 s, so pages on those hosts can fail or crawl on the emulator. Use
  Cloudflare-fronted test hosts (`postman-echo.com`, `example.com`) for
  device checks.
- A page with an external `<script>` stalled once. That turned out to be the
  harness: Windows line endings in `adb input text`. Chunked typing loaded it
  through the proxy.
- The stale remote branches `second/compassionate-tesla-aa52zz` and
  `second/kind-cerf-0tso50` were deleted. `main` is the only branch.

## Older gaps still open (context only)

These are recorded in `CLAUDE.md` or the plans, and none is new:

- dns-prefetch still leaks (a2), an accepted gap.
- Keep-in-container over HTTPS fails with `BAD_RECORD_MAC` on the emulator,
  probably the emulator's network. Not tried on a phone.
- A wipe-on-exit site's automatic wipe does not rotate its profile id.
- Nothing is verified on a physical phone.

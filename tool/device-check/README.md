# Device-check harness

Host-side tools for checking on an emulator what the app sends where. Written
for Plan 13 Task 7 (`docs/superpowers/plans/2026-09-30-loopback-proxy.md`),
and usable for any later routing check. Earlier sessions rewrote these for
each run; they live here now so the next run starts from the same tools.

Python 3.8+, standard library only, and `adb` on `PATH`. It runs from
PowerShell or Git Bash alike: the scripts call `adb` themselves, so Git Bash's
path conversion (`MSYS_NO_PATHCONV`) does not apply.

| Script | Shows |
|---|---|
| `proxy.py` | SOCKS5 on `:1080`, HTTP CONNECT on `:8888`, each request's target as the app sent it (`SOCKS5 NAME host:443`, or `IPv4`/`IPv6` for an address) and when it closed. The emulator reaches it at `10.0.2.2`. |
| `dns_log.py` | Every name the device looks up, when the emulator runs with `-dns-server` pointed at it. |
| `app_sockets.py watch` | Every socket of the app's uid, when it opens, changes state and closes. Anything whose remote end is not loopback is marked `** OUTSIDE LOOPBACK **`. |
| `app_sockets.py port` / `probe` | The loopback proxy's port, and check 5's three strangers' probes against it. |

## Setup

Four terminals on the host:

```
python dns_log.py --upstream <your resolver>     # default 1.1.1.1
python proxy.py
emulator -avd <avd> -dns-server 127.0.0.1
python app_sockets.py watch                      # once the app is installed
```

If `127.0.0.1:53` is taken, run `dns_log.py --listen <host LAN IP>` and pass
that address to `-dns-server`.

Then install the build under test:

```
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

**Loopback proxy log (optional, never commit it).** For the proxy's own view
of each request, change the one call in `Loopback.install`
(`android/app/src/main/kotlin/com/mono/container/engine/LoopbackOverride.kt`)
locally to

```kotlin
LoopbackProxy(credentials, log = { android.util.Log.d("P2", it) })
```

and read it with `adb logcat -s P2`. Lines look like
`CONNECT example.com:443 -> 200 tunnel` or `-> 407`. They name hosts, which is
why the committed app passes no logger.

**Reading the UI.** The app sets `FLAG_SECURE`, so screenshots come out
black. Use `adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml`.
Tap controls at the centre of their `bounds` in that dump, never at a fixed
coordinate. The address bar's Clear is about 11 dp left of Panic, and panic
wipes the vault with one tap (open problem 3). `adb shell getevent -lt` in a
spare terminal records every tap actually delivered.

**Test hosts.** On the user's PC, AWS- and Azure-hosted sites (httpbin.org,
duckduckgo.com, squoosh.app) take 14–15 s to connect, and Chromium drops some
tunnels at about 10 s. Prefer Cloudflare-fronted hosts: `example.com`,
`postman-echo.com`.

## Run sheet for Plan 13 Task 7

In this order. Record each item as "seen" or "not seen, because …".

**A. First, or stop** (the plan's "What Task 7 must check first", and Task 5
Step 10's early check):

1. A SOCKS5 site loads at all. That shows the loopback proxy started.
2. Its first `CONNECT` gets `407`, then the retry tunnels (P2 log). Seen last
   run; a quick look is enough.
3. **The re-challenge loop, again.** Task 5 Step 10's scratch patch (never
   commit it): at the end of `EngineChannel.register`'s success branch, add
   `mainHandler.postDelayed({ credentials.unbind(config.profileId) }, 10_000)`.
   Open direct `https://example.com`, wait 10 s, reload. The page shows
   WebView's error page, and the P2 log shows a small, bounded number of `403`s
   and `407`s, **not a stream**. Record the count. A loop stops the plan.
   Re-run this even though last run saw no loop: problem 1's fix makes the
   unbind close every open tunnel, so every request after it now gets a `403`,
   where before Chromium could go on using a pooled tunnel.
4. `watch` during a SOCKS5 site's first load: no `OUTSIDE LOOPBACK` line
   before the first `CONNECT` reaches `proxy.py`. One would be open design
   question 1 (the override applying late) actually happening.

**B. Open problem 1 (fixed on `second/modest-knuth-f83zbx`, not yet seen):**

1. A site at `https://example.com` on the **direct** route. Open it. `watch`
   shows an `OUTSIDE LOOPBACK` socket to example.com's address; that is the
   loopback proxy's direct connection, which is expected here.
2. Close it from the switcher's ×. **That socket closes right away**: `watch`
   shows it as `FIN-WAIT-1`/`FIN-WAIT-2` and then `gone`, within a second or
   so. Before the fix it stayed `ESTAB`.
3. Edit the site to SOCKS5 `10.0.2.2:1080`, reopen it, and load
   `https://example.com/?b=<random>`.
4. Expect: `proxy.py` logs `SOCKS5 NAME example.com:443`, the P2 log shows a
   fresh `CONNECT example.com:443 -> 200 tunnel`, and `watch` shows no new
   socket outside loopback.

**C. The plan's checks** (Task 7 Step 2's numbering):

- **1.** SOCKS5 `https://duckduckgo.com`, its preconnect to `links.duckduckgo.com`,
  `https://squoosh.app` (a service worker) and a pagehide probe: `watch
  --outside` prints nothing, and `proxy.py` shows each host as `NAME`.
- **2.** Every `proxy.py` line for those is `NAME`, never `IPv4`/`IPv6`.
- **3.** Cookie survives close and reopen: `https://postman-echo.com/cookies/set?p2=1`,
  back out, close from ×, reopen at `https://postman-echo.com/cookies`.
  It shows `"p2": "1"`. **Count it only if the reopen shows a fresh
  `CONNECT`** (B above); last time it didn't, and the result was
  inconclusive.
- **4.** The redirect in item 3 works. A form POST: `https://httpbin.org/forms/post`
  submits and shows the posted fields (slow on the user's PC; see Test hosts).
- **5.** `python app_sockets.py probe` prints three `ok` lines (`407` with
  `realm="container"`, `403`, `403`). Then `proxy.py` logged nothing new, and
  `watch` showed no socket to example.com.
- **6.** The form page from item 4: no `content-autofill.googleapis.com` in
  `dns_log.py`, and no `2001:4860:…` socket in `watch`.
- **7.** Lock (`9c`), unlock, reopen the SOCKS5 site: it loads with no prompt, and a
  fresh `CONNECT` shows. The old credential's `403` while closed is pinned by
  the JVM test "a closed session's credential gets 403"; say so rather than
  claiming it was seen.
- **9.** Direct `https://example.com`, and a Plan 12 throwaway search from it.
- **10.** `dns_log.py` over the whole run: for proxied sites, only their pages'
  `dns-prefetch` hints (the accepted gap a2).
- **11.** An HTTP site through `10.0.2.2:8888`: loads, and `proxy.py` logs
  `CONNECT host:443`.
- **8.** **Last, because it wipes the vault** (the plan numbers it 8): Panic. `3c`
  shows, the app stays up, and `adb shell run-as com.mono.container ls
  app_flutter` lists neither `meta.bin` nor `store-1.db`.

Also from Task 6 Step 10: a SOCKS5 site whose URL is
`https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf`
holds a download reading `13.0 KB · from www.w3.org` (seen last run); its
"Keep inside this container" was started and its result never recorded.

Then Task 7 Steps 3–5: fill in the plan's Verification, Device checks and
Known gaps, add the Plan 13 row and the other `CLAUDE.md` edits Step 4 lists,
and commit.

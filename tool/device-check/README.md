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
| `pages.py` | Local test pages on `:8099` for Plan 16's security levels (`/csp.html`, `/probes.html`, `/image.html`, `/mic.html`, `/article.html`), Plan 19's onion links (`/onion.html`), and each request's path and `User-Agent`. The emulator reaches it at `10.0.2.2:8099`. |

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
spare terminal records touches from the emulator window, but **not**
`adb shell input tap`, which is injected above `/dev/input`. Before a scripted
tap, check that the screen is the one you expect: a "Save" tap at `(991,211)`
meant for the add-site form is Panic on a container (it wiped the vault in
the 2026-10-02 run). `uiautomator dump` can fail and leave the previous
`ui.xml` in place, so delete it before each dump.

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

**D. The design rulings of 2026-09-30** (not in the plan's list):

- **The system proxy.** In the emulator's Wi-Fi settings, set a manual proxy
  `10.0.2.2:8888` with `example.org` in its bypass list. A direct
  `https://example.com` site loads and `proxy.py` logs
  `CONNECT example.com:443`; a direct `https://example.org` site loads with no
  `proxy.py` line. A SOCKS5 site still logs `SOCKS5 NAME …`, with no
  `CONNECT` line for it. Clear the Wi-Fi proxy afterwards. Set it through
  Settings › Network › AndroidWifi › Modify › Advanced options: `adb shell
  settings put global global_http_proxy_*` is not applied while the device
  runs (`dumpsys connectivity` shows no `HttpProxy`). Move between the
  dialog's fields with `input keyevent 61` (Tab), because the keyboard
  shifts them.
- **Waiting for the override.** Covered by A.4. It never keeps a site on the
  checklist in practice; if a site ever sits on "Connecting…" with nothing in
  the P2 log, the override's listener never ran.

Also from Task 6 Step 10: a SOCKS5 site whose URL is
`https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf`
holds a download reading `13.0 KB · from www.w3.org` (seen last run); its
"Keep inside this container" was started and its result never recorded.

Then Task 7 Steps 3–5: fill in the plan's Verification, Device checks and
Known gaps, add the Plan 13 row and the other `CLAUDE.md` edits Step 4 lists,
and commit.

## Run sheet: proxy authentication (Plan 14)

Plan `docs/superpowers/plans/2026-10-02-proxy-authentication.md`. Run
`proxy.py` from this folder; each check names what to look for in its log and
in the UI dump.

1. `python proxy.py --user alice --password s3cret`. A SOCKS5 site at
   `https://example.com` via `10.0.2.2:1080`, with USERNAME `alice` and
   PASSWORD `s3cret`, loads. The log shows `login accepted for user 'alice'`,
   then `SOCKS5 NAME example.com:443`. Every SOCKS route now uses the app's own
   SOCKS5 client, so this is also the regression check for every existing
   SOCKS5 site: run it once with no `--user` and no login typed too.
2. The same site with PASSWORD `wrong`: `8b` reads "The proxy rejected the
   login", and the log shows `login rejected`, with no `SOCKS5 NAME` line after
   it.
3. The same site with no login typed: `8b` reads "The proxy rejected the
   login", and the log shows `rejected: no login offered`.
4. Repeat 1–3 for an HTTP site via `10.0.2.2:8888`. The log lines are
   `CONNECT … login accepted`, `login rejected` and `login missing`.
5. `python proxy.py --any-login`. Turn "Separate login per site" on for two
   SOCKS5 sites and open both. Each logs `login accepted for user '<32 hex
   digits>'`, and the two users differ. Use "Wipe this site's data" on one and
   reopen it: its user changes, and the other's does not. Repeat with one HTTP
   site, whose user is logged the same way.
6. A throwaway typed from a logged-in site loads through the same login: its
   log line shows `alice`.
7. With the login set and the site live, restart `proxy.py` with a different
   `--password`, then reload: `8c` (tunnel dropped) appears, not `8b`.

## Plan 15 (tabs)

The run sheet is the "Device checks" section at the end of
`docs/superpowers/plans/2026-10-02-tabs.md`. It uses the tools above
unchanged. None of Plan 15 has run on a device yet.

## Run sheet: privacy controls (Plan 16)

Plan `docs/superpowers/plans/2026-10-02-privacy-controls.md`, spec
`docs/superpowers/specs/2026-10-02-privacy-controls-design.md` (§7 and §1.4).
**All eight were seen on the emulator on 2026-10-03** (`main` at `e572c29`), and
again in a re-run the same day; the results are in the plan's "Device checks
(2026-10-03, emulator)" and "Re-run (2026-10-03, emulator)". Record a re-run
the same way, each as "seen" or "not seen, because …".

**Setup.** Alongside the setup above, in two more terminals:

```
python pages.py                  # test pages on :8099
python proxy.py --any-login      # instead of plain proxy.py, for check 6
```

With `--any-login`, every proxied site needs a login: give a SOCKS5 site
"Separate login per site" or a typed one, or it is refused (`8b`).

Read every result from `adb shell uiautomator dump`: WebView's text is in the
tree, and the screen is `FLAG_SECURE`. `pages.py` sends `no-store`, so a page
or image seen at one level is fetched again at the next, and a missing
`pages.py` line means no request was made.

`pages.py` serves:

- `/csp.html`: reads `NO SCRIPT RAN`, then `INLINE RAN` (inline script),
  ` EXTERNAL RAN` (`/ext.js`); its `tap` button adds ` ONCLICK RAN`, and its
  `jsurl` link sets the title to `JSURL RAN`.
- `/probes.html`: `WASM <typeof WebAssembly> WEBGL <true|false>`. Over `http:`
  it runs only at Standard (Safer stops scripts on `http:` pages), which is
  why check 2 uses an `https` site.
- `/image.html`: one 40×40 `/dot.png`, whose fetch is logged.
- `/mic.html`: `mic` asks for the microphone; `MIC ON` while the track is
  live, `MIC ENDED` when it ends. `getUserMedia` needs a secure context, which
  `http://10.0.2.2` is not (the page then reads `NO MEDIADEVICES`), so open it
  as `http://localhost:8099/mic.html` on a SOCKS5 site: `proxy.py` connects to
  `localhost` on the host. Or, for a direct site, run `adb reverse tcp:8099
  tcp:8099` and open `http://localhost:8099/mic.html` (or `/ask.html`): the
  device's own `localhost:8099` then reaches this server. The first allow
  shows Android's own permission dialog as well as `6a`.
- `/article.html`: an article-shaped page for Reader.

**Checks.** In this order.

1. **First, Safer's `http:` CSP (spec §1.4).** Seen 2026-10-03.
   - A direct site at `http://10.0.2.2:8099/csp.html`: at Standard it reads
     `INLINE RAN EXTERNAL RAN`, and tapping `tap` adds `ONCLICK RAN`.
   - At Safer it reads `NO SCRIPT RAN`, tapping adds nothing, and `pages.py`
     still logs `/ext.js` being fetched (CSP blocks execution, not the fetch).
   - **If Safer still runs scripts, stop: record the failure and take the
     fallback** (per-navigation `javaScriptEnabled`) to the user.
2. **Safer on https.** Seen 2026-10-03.
   - Give a site at `https://example.com` this custom JS:
     `document.addEventListener('DOMContentLoaded',()=>document.body.prepend('WASM '+typeof WebAssembly+' WEBGL '+!!document.createElement('canvas').getContext('webgl')))`.
   - At Standard: `WASM object WEBGL true` (or `false` where the emulator has
     no GL).
   - At Safer: `WASM undefined WEBGL false`, and example.com's own text still
     renders, so JS is on.
3. **Safest.** Seen 2026-10-03 (Reader does not open).
   - `http://10.0.2.2:8099/csp.html` reads `NO SCRIPT RAN`, and so does an
     https page with the custom JS above (no prefix text).
   - `/image.html` logs no `/dot.png` request.
   - Reader on an article page (`http://10.0.2.2:8099/article.html`): record
     whether it opens (spec §1.4).
4. **Default and override.** Seen 2026-10-03.
   - Settings → Security level → Safer: an open site is unchanged until it is
     closed and reopened, then Safer applies.
   - ☰ → Security level → Default returns a site with its own level to the
     default.
5. **Reopen keeps a throwaway's cookie.** Seen 2026-10-03.
   - A throwaway on `https://postman-echo.com/cookies/set?p16=1`, then any
     `6c` switch.
   - The reopened page at `/cookies` still shows `p16`.
6. **New identity.** Seen 2026-10-03.
   - A SOCKS5 site with "Separate login per site", against
     `proxy.py --any-login`.
   - Note its user, then ☰ → New identity → New identity. `proxy.py` logs a
     different 32-hex user, the old `profileId` is in
     `files/pending-profile-deletions`, and the page is the site's stored
     address.
   - Cancel changes nothing.
7. **Revoke.** Seen 2026-10-03.
   - `/mic.html` (as `http://localhost:8099/mic.html` on a SOCKS5 site, see
     above), then "Allow while this site is open", then `MIC ON`.
   - In `6c`, Microphone shows `Revoke`. Tapping it reloads the page
     (`MIC ENDED`, or a fresh page), and the next tap asks with `6a` again.
8. **Two vaults.** Seen 2026-10-03. Settings' Security level row looks the same in
   the decoy, and setting it there leaves the real vault's default unchanged.

## Run sheet: built-in Tor (Plan 19)

Plan `docs/superpowers/plans/2026-10-04-built-in-tor.md`, spec
`docs/superpowers/specs/2026-10-04-built-in-tor-design.md` (§9). **All eight
checks and the controller's A–D were seen on the emulator on 2026-10-04**; the
results, and the one bug found, are in the plan's "Device checks". Record a
re-run the same way, each as "seen" or "not seen, because …".

**Setup.** `dns_log.py` and the emulator with `-dns-server` (see Setup
above), `app_sockets.py watch`, and `pages.py` for the onion links. No
`proxy.py`: Tor is in the app. The emulator must reach the real Tor network;
right after a cold boot its network can take a minute or two, and a Tor open
then stalls into `8b` (`Tor did not connect`), so retry before calling it a
bug. Tor's own lines are in `adb logcat | grep TorService` (`Acquired lock` at
a start, `Releasing lock` at a stop); Tor itself logs nothing there.

`pages.py` serves `/onion.html`: two big links, to DuckDuckGo's onion and to
a made-up one. Open it on a Direct site as `http://10.0.2.2:8099/onion.html`.

**Checks.**

1. Cold start, unlock, no Tor site: `watch` shows only the two loopback
   listeners, `dns_log.py` nothing from the app, and
   `adb shell run-as com.mono.container ls files/tor` fails.
2. A site `https://check.torproject.org` on Tor (Network tab ▸ Route through
   proxy ▸ Tor): `8a` reads `Connecting to Tor · N%`, then the page says
   "Congratulations".
3. Two Tor sites on `https://api.ipify.org`: two addresses. ☰ ▸ New identity
   on one changes only its own.
4. On a Direct site, type DuckDuckGo's onion in the pill: `THROWAWAY · TOR`,
   and it opens. Tap both links on `/onion.html`: WebView's error page, no
   `.onion` in `dns_log.py`, and (with no Tor site open) no `TorService` line.
5. With a Tor site live: no app TCP listener but the loopback ones;
   `ls -l files/tor` shows `socks:0`.
6. Lock (`9c`, or Home and straight back for `9b`): `Releasing lock` as the
   app returns, and Tor's relay connections gone. A lock is decided on
   return, not while the app is away.
7. **Last:** Panic. `ls files/tor app_TorService cache/TorService` finds none
   of them, again 10 s later. Then set the vault up again.
8. `adb shell svc wifi disable; adb shell svc data disable`, open a Tor
   site: `8b` `Tor did not connect` two minutes after Tor's start. Turn both
   back on; Try again loads.

- A. A `6c` switch on a live Tor site reopens it in place with no new
  `Acquired lock`. Mark the page first (DevTools `window.__mark`) to see the
  reopen.
- B. Close the last Tor container: `Releasing lock` about 10 s later.
- C. Lock, unlock and open a Tor site at once: it loads, or `8b` and Try
  again loads.
- D. Lock during a long request (`https://postman-echo.com/delay/10` as a
  Tor throwaway): no relay connection left, no ANR.

**dns-prefetch measurement.** Find a page with hints from the host
(`curl -s <url> | grep -o -i '<link[^>]*dns-prefetch[^>]*>'`; on 2026-10-04
`https://www.theguardian.com/international` had 9 and `https://edition.cnn.com/`
12). Before each run, force-stop the app and toggle the emulator's network off
and on, so neither Chromium's nor the device's resolver cache holds the names.
Load the page on a Tor site and count its hinted hosts in `dns_log.py`. For
the comparison, comment out `append(torDocumentStartJs(config))` in
`Shields.kt` locally (never commit it), build, `adb install -r`, and repeat;
then `git checkout` the file and reinstall.

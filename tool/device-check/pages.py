#!/usr/bin/env python3
"""Local test pages for device checks of tabs (Plan 15) and security levels (Plan 16).

Runs on the host. The emulator reaches it at 10.0.2.2, so a direct site at
http://10.0.2.2:8099/csp.html loads these pages. Every request is logged with
its path and User-Agent (never a body), so a fetch that did not happen is
visible as a missing line.

    python pages.py                    # http on :8099
    python pages.py --port 8100

Pages (each self-contained; nothing loads from anywhere but this server):

    /csp.html      inline script, external /ext.js, an onclick and a
                   javascript: URL; reads NO SCRIPT RAN when none of them runs
    /probes.html   WASM <typeof WebAssembly> WEBGL <whether a webgl context exists>
    /image.html    one 40x40 PNG, /dot.png; its fetch is logged
    /mic.html      a button asking for the microphone; MIC ON while the track
                   is live, MIC ENDED when it ends. getUserMedia needs a secure
                   context, so open it as http://localhost:8099/mic.html (see
                   README), not through 10.0.2.2
    /article.html  an article-shaped page, for Reader

Plan 15 (tabs); each of these shows LOADED <time> so a reload is visible:

    /tabs.html     a target=_blank link to /linked.html, then 60 paragraphs
                   to scroll
    /linked.html   a target=_blank link to /linked2.html
    /popup.html    window.open('/popped.html') one second after load, no tap
    /ask.html      asks for the camera ten seconds after load; open it as
                   http://localhost:8099/ask.html, like /mic.html

Plan 19 (built-in Tor):

    /onion.html    two big links to onion addresses (DuckDuckGo's real one and
                   a made-up abc...onion), for spec section 9 check 4: tapped
                   on a Direct site, each must show WebView's error page and
                   dns_log.py must show no lookup of the .onion name

Every response is sent with Cache-Control: no-store, so a page or image seen
earlier at another level is fetched again rather than taken from the cache.

Standard library only, so it runs unchanged on Windows.
"""
import argparse
import ipaddress
import struct
import threading
import time
import zlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

_print_lock = threading.Lock()


def log(message):
    with _print_lock:
        print(f"{time.strftime('%H:%M:%S')}.{int(time.time() * 1000) % 1000:03d} {message}", flush=True)


def png(width, height, rgb):
    """A solid-colour RGB PNG, built here so the harness ships no binary file."""
    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    row = b"\x00" + bytes(rgb) * width  # filter byte 0, then the pixels
    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(row * height)) + chunk(b"IEND", b""))


def html(title, body):
    return (f"<!doctype html><html><head><meta charset=utf-8>"
            f"<meta name=viewport content='width=device-width'>"
            f"<title>{title}</title></head><body>{body}</body></html>").encode()


CSP = html("csp", """
<p id=r>NO SCRIPT RAN</p>
<script>document.getElementById('r').textContent='INLINE RAN'</script>
<script src="/ext.js"></script>
<button onclick="document.getElementById('r').textContent+=' ONCLICK RAN'">tap</button>
<a href="javascript:void(document.title='JSURL RAN')">jsurl</a>
""")

EXT_JS = b"document.getElementById('r').textContent+=' EXTERNAL RAN';\n"

PROBES = html("probes", """
<p id=r>NO SCRIPT RAN</p>
<script>
window.addEventListener('load', function () {
  document.getElementById('r').textContent =
    'WASM ' + typeof WebAssembly +
    ' WEBGL ' + !!document.createElement('canvas').getContext('webgl');
});
</script>
""")

IMAGE = html("image", """
<p>The square below is /dot.png.</p>
<img src="/dot.png" width=40 height=40 alt="dot">
""")

MIC = html("mic", """
<p id=r>MIC OFF</p>
<button id=b>mic</button>
<script>
var r = document.getElementById('r');
document.getElementById('b').onclick = function () {
  if (!navigator.mediaDevices) {
    r.textContent = 'NO MEDIADEVICES (not a secure context?)';
    return;
  }
  navigator.mediaDevices.getUserMedia({audio: true}).then(function (stream) {
    var track = stream.getAudioTracks()[0];
    r.textContent = 'MIC ON';
    track.onended = function () { r.textContent = 'MIC ENDED'; };
  }, function (error) {
    r.textContent = 'MIC REFUSED ' + error.name;
  });
};
</script>
""")

ARTICLE = html("A test article", "<article><h1>A test article</h1>" + "".join(
    f"<p>Paragraph {n}. This page exists so Reader has an article-shaped page to "
    f"extract, served locally. It has a heading and several paragraphs of plain "
    f"text, and no scripts, images or links of its own.</p>" for n in range(1, 9)
) + "</article>")

# Plan 15 (tabs). Each page shows the time it loaded, so a page reattached
# without a reload is told from a reloaded one in a uiautomator dump.
LOADED = "<p id=loaded></p><script>document.getElementById('loaded').textContent='LOADED '+new Date().toISOString().slice(11,23)</script>"

TABS = html("Tabs opener", LOADED + """
<p><a href="/linked.html" target="_blank">open linked page</a></p>
""" + "".join(f"<p>Opener paragraph {n}.</p>" for n in range(1, 61)))

LINKED = html("Linked page", LOADED + """
<p><a href="/linked2.html" target="_blank">open another linked page</a></p>
""" + "".join(f"<p>Linked paragraph {n}.</p>" for n in range(1, 31)))

LINKED2 = html("Second linked page", LOADED + "<p>A page opened from the linked page.</p>")

POPUP = html("Popup", LOADED + """
<p>In one second this page calls window.open('/popped.html') with no tap.</p>
<script>setTimeout(function () { window.open('/popped.html'); }, 1000)</script>
""")

POPPED = html("Popped", "<p>POPPED: a popup without a tap opened this.</p>")

ASK = html("Camera ask", LOADED + """
<p id=r>CAMERA NOT ASKED YET</p>
<script>
var r = document.getElementById('r');
setTimeout(function () {
  if (!navigator.mediaDevices) { r.textContent = 'NO MEDIADEVICES (not a secure context?)'; return; }
  r.textContent = 'CAMERA ASKED';
  navigator.mediaDevices.getUserMedia({video: true}).then(function () {
    r.textContent = 'CAMERA ON';
  }, function (error) {
    r.textContent = 'CAMERA REFUSED ' + error.name;
  });
}, 10000);
</script>
""")

ONION = html("Onion links", """
<style>a{display:block;font-size:40px;padding:60px 10px;border:2px solid #888;margin:20px 0}</style>
<p><a id=ddg href="http://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/">DDG ONION LINK</a></p>
<p><a id=fake href="http://abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwx.onion/">FAKE ONION LINK</a></p>
""")

PAGES = {
    "/onion.html": ("text/html; charset=utf-8", ONION),
    "/tabs.html": ("text/html; charset=utf-8", TABS),
    "/linked.html": ("text/html; charset=utf-8", LINKED),
    "/linked2.html": ("text/html; charset=utf-8", LINKED2),
    "/popup.html": ("text/html; charset=utf-8", POPUP),
    "/popped.html": ("text/html; charset=utf-8", POPPED),
    "/ask.html": ("text/html; charset=utf-8", ASK),
    "/csp.html": ("text/html; charset=utf-8", CSP),
    "/ext.js": ("text/javascript", EXT_JS),
    "/probes.html": ("text/html; charset=utf-8", PROBES),
    "/image.html": ("text/html; charset=utf-8", IMAGE),
    "/dot.png": ("image/png", png(40, 40, (0x7F, 0xC8, 0xA9))),
    "/mic.html": ("text/html; charset=utf-8", MIC),
    "/article.html": ("text/html; charset=utf-8", ARTICLE),
}


class Handler(BaseHTTPRequestHandler):
    server_version = "pages"
    sys_version = ""

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        page = PAGES.get(path)
        user_agent = self.headers.get("User-Agent", "-")
        log(f"GET {self.path} -> {200 if page else 404}  UA {user_agent}")
        if page is None:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        content_type, body = page
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass  # do_GET logs each request itself, in proxy.py's format


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=8099, help="port to serve on (default 8099)")
    parser.add_argument("--bind", default="0.0.0.0",
                        help="address to listen on (default 0.0.0.0, all interfaces; the emulator reaches it as 10.0.2.2)")
    args = parser.parse_args()
    ipaddress.ip_address(args.bind)
    server = ThreadingHTTPServer((args.bind, args.port), Handler)
    server.daemon_threads = True
    log(f"pages listening on {args.bind}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

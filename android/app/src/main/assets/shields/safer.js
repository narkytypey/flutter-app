(function () {
  // Privacy-controls spec §1.2, Safer. Runs in every document and frame
  // before the page's own scripts; it is injected by the browser, so the CSP
  // below does not stop it or the other shields.

  // No page script on an http: page. A meta CSP only counts as a child of a
  // <head>, and at document start there is none yet: one is made, and the
  // parser's own <head> follows it. Verified on a device first (spec §1.4);
  // the fallback is per-navigation javaScriptEnabled.
  if (location.protocol === 'http:') {
    var meta = document.createElement('meta');
    meta.httpEquiv = 'Content-Security-Policy';
    meta.content = "script-src 'none'";
    var head = document.head;
    if (!head) {
      head = document.createElement('head');
      (document.documentElement || document).appendChild(head);
    }
    head.insertBefore(meta, head.firstChild);
  }

  // No WebAssembly: the nearest thing to Tor's JIT-off that WebView allows.
  try { delete window.WebAssembly; } catch (e) {}
  if (window.WebAssembly) {
    try { Object.defineProperty(window, 'WebAssembly', { value: undefined }); } catch (e) {}
  }

  // No WebGL. 2d and bitmaprenderer are untouched.
  var refused = { 'webgl': 1, 'webgl2': 1, 'experimental-webgl': 1 };
  function guard(proto) {
    if (!proto || !proto.getContext) return;
    var original = proto.getContext;
    proto.getContext = function (type) {
      if (refused[String(type)]) return null;
      return original.apply(this, arguments);
    };
  }
  if (window.HTMLCanvasElement) guard(HTMLCanvasElement.prototype);
  if (window.OffscreenCanvas) guard(OffscreenCanvas.prototype);
})();

(function () {
  // Per-session deterministic noise, seeded once per document. Same page load
  // always reads the same noisy values (a script probing twice learns
  // nothing extra); a new session gets different noise (repeat visits don't
  // stack into a stable fingerprint). Raises the cost of fingerprinting; it
  // does not prevent it — see Known gaps.
  var seed = (Math.random() * 4294967296) >>> 0;

  function next() {
    // splitmix32
    seed = (seed + 0x9e3779b9) >>> 0;
    var z = seed;
    z = Math.imul(z ^ (z >>> 16), 0x85ebca6b) >>> 0;
    z = Math.imul(z ^ (z >>> 13), 0xc2b2ae35) >>> 0;
    return ((z ^ (z >>> 16)) >>> 0) / 4294967296;
  }

  function noiseByte() {
    return Math.floor(next() * 5) - 2; // [-2, 2]
  }

  if (window.HTMLCanvasElement) {
    var origToDataURL = HTMLCanvasElement.prototype.toDataURL;
    HTMLCanvasElement.prototype.toDataURL = function () {
      var ctx = this.getContext('2d');
      if (ctx) noiseCanvas(ctx, this.width, this.height);
      return origToDataURL.apply(this, arguments);
    };
  }

  function noiseCanvas(ctx, width, height) {
    if (!width || !height) return;
    try {
      var data = ctx.getImageData(0, 0, width, height);
      for (var i = 0; i < data.data.length; i += 4) {
        data.data[i] = clampByte(data.data[i] + noiseByte());
        data.data[i + 1] = clampByte(data.data[i + 1] + noiseByte());
        data.data[i + 2] = clampByte(data.data[i + 2] + noiseByte());
      }
      ctx.putImageData(data, 0, 0);
    } catch (e) {
      // Cross-origin canvases throw on read; nothing to noise.
    }
  }

  function clampByte(v) {
    return v < 0 ? 0 : v > 255 ? 255 : v;
  }

  if (window.CanvasRenderingContext2D) {
    var origGetImageData = CanvasRenderingContext2D.prototype.getImageData;
    CanvasRenderingContext2D.prototype.getImageData = function () {
      var data = origGetImageData.apply(this, arguments);
      for (var i = 0; i < data.data.length; i += 4) {
        data.data[i] = clampByte(data.data[i] + noiseByte());
        data.data[i + 1] = clampByte(data.data[i + 1] + noiseByte());
        data.data[i + 2] = clampByte(data.data[i + 2] + noiseByte());
      }
      return data;
    };
  }

  if (window.WebGLRenderingContext) {
    var origGetParameter = WebGLRenderingContext.prototype.getParameter;
    WebGLRenderingContext.prototype.getParameter = function (pname) {
      var value = origGetParameter.call(this, pname);
      if (typeof value === 'number') return value + (noiseByte() * 1e-6);
      return value;
    };
  }

  if (window.AudioBuffer) {
    var origGetChannelData = AudioBuffer.prototype.getChannelData;
    AudioBuffer.prototype.getChannelData = function () {
      var data = origGetChannelData.apply(this, arguments);
      for (var i = 0; i < data.length; i += 100) {
        data[i] = data[i] + noiseByte() * 1e-7;
      }
      return data;
    };
  }
})();

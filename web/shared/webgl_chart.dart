import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Zero-dependency WebGL2 2D curve and area fill renderer paired with a crisp
/// Canvas2D HUD overlay.
///
/// Attaches a transparent `<canvas class="webgl2-underlay">` directly behind a
/// target Canvas2D element so mathematical curves, shaded intervals, and
/// multi-curve overlays are rasterized on the GPU while grid lines, tick
/// labels, and hover tooltips remain crisp on the top Canvas2D layer.
/// Automatically falls back to Canvas2D if WebGL2 is unavailable.
final class WebGL2ChartLayer {
  /// Returns the [WebGL2ChartLayer] attached to [hudCanvas], creating it on
  /// first use, and clears the WebGL2 backing buffer for a new frame.
  static WebGL2ChartLayer? attachAndClear(
    web.HTMLCanvasElement hudCanvas,
    double cssWidth,
    double cssHeight,
    double dpr,
  ) {
    var layer = _layers[hudCanvas];
    if (layer == null) {
      layer = WebGL2ChartLayer._create(hudCanvas);
      _layers[hudCanvas] = layer;
    }
    layer._prepareFrame(cssWidth, cssHeight, dpr);
    return layer.isAvailable ? layer : null;
  }

  /// Returns the existing [WebGL2ChartLayer] for [hudCanvas], if any.
  static WebGL2ChartLayer? of(web.HTMLCanvasElement hudCanvas) =>
      _layers[hudCanvas];

  /// Hides or shows the 2D WebGL underlay canvas (used when switching a canvas
  /// container between 2D and 3D modes).
  static void setVisible(web.HTMLCanvasElement hudCanvas, bool visible) {
    final layer = _layers[hudCanvas];
    if (layer != null) {
      layer._glCanvas.style.display = visible ? 'block' : 'none';
    }
  }

  /// Composites the WebGL2 underlay and the Canvas2D HUD overlay into a single
  /// PNG data URL for image export.
  static String exportPngDataUrl(
    web.HTMLCanvasElement hudCanvas, {
    String backgroundColor = '#0f172a',
  }) {
    final layer = _layers[hudCanvas];
    if (layer == null || !layer.isAvailable) {
      return hudCanvas.toDataURL('image/png');
    }
    final out = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = hudCanvas.width
      ..height = hudCanvas.height;
    final ctx = out.context2D;
    ctx.fillStyle = backgroundColor.toJS;
    ctx.fillRect(0, 0, out.width.toDouble(), out.height.toDouble());
    ctx.drawImage(layer._glCanvas, 0, 0);
    ctx.drawImage(hudCanvas, 0, 0);
    return out.toDataURL('image/png');
  }

  new _(
    this._hudCanvas,
    this._glCanvas,
    this._gl,
    this._lineProgram,
    this._fillProgram,
    this._vbo,
  );

  factory _create(web.HTMLCanvasElement hudCanvas) {
    final glCanvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement
          ..className = 'webgl2-underlay';
    glCanvas.style
      ..position = 'absolute'
      ..top = '0'
      ..left = '0'
      ..pointerEvents = 'none'
      ..zIndex = '0';

    final parent = hudCanvas.parentElement;
    if (parent != null && parent.isA<web.HTMLElement>()) {
      final htmlParent = parent as web.HTMLElement;
      final computedPos = web.window.getComputedStyle(htmlParent).position;
      if (computedPos == 'static' || computedPos.isEmpty) {
        htmlParent.style.position = 'relative';
      }
      hudCanvas.style
        ..position = 'relative'
        ..zIndex = '1';
      htmlParent.insertBefore(glCanvas, hudCanvas);
    }

    web.WebGL2RenderingContext? gl;
    try {
      final ctx = glCanvas.getContext(
        'webgl2',
        {
          'alpha': true,
          'antialias': true,
          'premultipliedAlpha': false,
          'preserveDrawingBuffer': true,
        }.jsify(),
      );
      if (ctx != null && ctx.isA<web.WebGL2RenderingContext>()) {
        gl = ctx as web.WebGL2RenderingContext;
      }
    } catch (_) {
      gl = null;
    }

    if (gl == null) {
      return WebGL2ChartLayer._(hudCanvas, glCanvas, null, null, null, null);
    }

    final lineProg = _compileProgram(gl, _lineVertSrc, _lineFragSrc);
    final fillProg = _compileProgram(gl, _fillVertSrc, _fillFragSrc);
    final vbo = gl.createBuffer();

    return WebGL2ChartLayer._(hudCanvas, glCanvas, gl, lineProg, fillProg, vbo);
  }

  final web.HTMLCanvasElement _hudCanvas;
  final web.HTMLCanvasElement _glCanvas;
  final web.WebGL2RenderingContext? _gl;
  final web.WebGLProgram? _lineProgram;
  final web.WebGLProgram? _fillProgram;
  final web.WebGLBuffer? _vbo;

  double _cssWidth = 0.0;
  double _cssHeight = 0.0;
  double _dpr = 1.0;

  /// Whether WebGL2 context and shader programs initialized cleanly.
  bool get isAvailable =>
      _gl != null &&
      _lineProgram != null &&
      _fillProgram != null &&
      _vbo != null;

  /// Draws an anti-aliased polyline from pixel coordinates `[x0, y0, x1, y1, ...]`
  /// clipped to `[clipLeft, clipTop, clipWidth, clipHeight]`.
  bool drawPolyline(
    Float32List pixelPoints,
    int pointCount, {
    required String strokeColor,
    required double lineWidth,
    List<num>? lineDash,
    required double clipLeft,
    required double clipTop,
    required double clipWidth,
    required double clipHeight,
  }) {
    final gl = _gl;
    final prog = _lineProgram;
    final vbo = _vbo;
    if (gl == null || prog == null || vbo == null || pointCount < 2) {
      return false;
    }

    // Build extruded triangle strip: 2 vertices per polyline point.
    // Attributes per vertex (6 floats): px, py, nx, ny, side (-1 or +1), arcLen.
    final verts = Float32List(pointCount * 12);
    var arcLen = 0.0;
    var outIdx = 0;

    for (var i = 0; i < pointCount; i++) {
      final px = pixelPoints[i * 2];
      final py = pixelPoints[i * 2 + 1];

      if (i > 0) {
        final dx = px - pixelPoints[(i - 1) * 2];
        final dy = py - pixelPoints[(i - 1) * 2 + 1];
        arcLen += math.sqrt(dx * dx + dy * dy);
      }

      double tx;
      double ty;
      if (i == 0) {
        tx = pixelPoints[2] - px;
        ty = pixelPoints[3] - py;
      } else if (i == pointCount - 1) {
        tx = px - pixelPoints[(i - 1) * 2];
        ty = py - pixelPoints[(i - 1) * 2 + 1];
      } else {
        tx = pixelPoints[(i + 1) * 2] - pixelPoints[(i - 1) * 2];
        ty = pixelPoints[(i + 1) * 2 + 1] - pixelPoints[(i - 1) * 2 + 1];
      }
      final len = math.sqrt(tx * tx + ty * ty);
      final nx = len > 1e-6 ? -ty / len : 0.0;
      final ny = len > 1e-6 ? tx / len : 1.0;

      // Left vertex (-1)
      verts[outIdx++] = px;
      verts[outIdx++] = py;
      verts[outIdx++] = nx;
      verts[outIdx++] = ny;
      verts[outIdx++] = -1.0;
      verts[outIdx++] = arcLen;

      // Right vertex (+1)
      verts[outIdx++] = px;
      verts[outIdx++] = py;
      verts[outIdx++] = nx;
      verts[outIdx++] = ny;
      verts[outIdx++] = 1.0;
      verts[outIdx++] = arcLen;
    }

    _applyScissor(gl, clipLeft, clipTop, clipWidth, clipHeight);
    gl.useProgram(prog);
    gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, vbo);
    gl.bufferData(
      web.WebGLRenderingContext.ARRAY_BUFFER,
      verts.toJS,
      web.WebGLRenderingContext.STREAM_DRAW,
    );

    const stride = 6 * 4;
    final posLoc = gl.getAttribLocation(prog, 'a_pos');
    final normLoc = gl.getAttribLocation(prog, 'a_normal');
    final sideLoc = gl.getAttribLocation(prog, 'a_side');
    final arcLoc = gl.getAttribLocation(prog, 'a_arc');

    if (posLoc >= 0) {
      gl.enableVertexAttribArray(posLoc);
      gl.vertexAttribPointer(
        posLoc,
        2,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        0,
      );
    }
    if (normLoc >= 0) {
      gl.enableVertexAttribArray(normLoc);
      gl.vertexAttribPointer(
        normLoc,
        2,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        8,
      );
    }
    if (sideLoc >= 0) {
      gl.enableVertexAttribArray(sideLoc);
      gl.vertexAttribPointer(
        sideLoc,
        1,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        16,
      );
    }
    if (arcLoc >= 0) {
      gl.enableVertexAttribArray(arcLoc);
      gl.vertexAttribPointer(
        arcLoc,
        1,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        20,
      );
    }

    final rgba = _parseCssColor(strokeColor);
    gl.uniform2f(
      gl.getUniformLocation(prog, 'u_resolution'),
      _cssWidth,
      _cssHeight,
    );
    gl.uniform1f(gl.getUniformLocation(prog, 'u_halfWidth'), lineWidth * 0.55);
    gl.uniform4f(
      gl.getUniformLocation(prog, 'u_color'),
      rgba.r,
      rgba.g,
      rgba.b,
      rgba.a,
    );

    final dashOn = (lineDash != null && lineDash.isNotEmpty)
        ? lineDash[0].toDouble()
        : 0.0;
    final dashOff = (lineDash != null && lineDash.length > 1)
        ? lineDash[1].toDouble()
        : dashOn;
    gl.uniform2f(gl.getUniformLocation(prog, 'u_dash'), dashOn, dashOff);

    gl.drawArrays(web.WebGLRenderingContext.TRIANGLE_STRIP, 0, pointCount * 2);
    gl.disable(web.WebGLRenderingContext.SCISSOR_TEST);
    return true;
  }

  /// Draws a vertical area fill between `[x_i, y_i]` and `basePy` using a
  /// GPU triangle strip.
  bool drawAreaFill(
    Float32List pixelPoints,
    int pointCount, {
    required double basePy,
    required String fillColor,
    required double clipLeft,
    required double clipTop,
    required double clipWidth,
    required double clipHeight,
    bool verticalGradient = false,
  }) {
    final gl = _gl;
    final prog = _fillProgram;
    final vbo = _vbo;
    if (gl == null || prog == null || vbo == null || pointCount < 2) {
      return false;
    }

    // 2 vertices per sample point: (px, py, alphaScale=1.0) and (px, basePy, alphaScale)
    final verts = Float32List(pointCount * 6);
    final bottomScale = verticalGradient ? 0.15 : 1.0;
    var outIdx = 0;
    for (var i = 0; i < pointCount; i++) {
      final px = pixelPoints[i * 2];
      final py = pixelPoints[i * 2 + 1];
      verts[outIdx++] = px;
      verts[outIdx++] = py;
      verts[outIdx++] = 1.0;

      verts[outIdx++] = px;
      verts[outIdx++] = basePy;
      verts[outIdx++] = bottomScale;
    }

    _applyScissor(gl, clipLeft, clipTop, clipWidth, clipHeight);
    gl.useProgram(prog);
    gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, vbo);
    gl.bufferData(
      web.WebGLRenderingContext.ARRAY_BUFFER,
      verts.toJS,
      web.WebGLRenderingContext.STREAM_DRAW,
    );

    const stride = 3 * 4;
    final posLoc = gl.getAttribLocation(prog, 'a_pos');
    final alphaLoc = gl.getAttribLocation(prog, 'a_alpha');
    if (posLoc >= 0) {
      gl.enableVertexAttribArray(posLoc);
      gl.vertexAttribPointer(
        posLoc,
        2,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        0,
      );
    }
    if (alphaLoc >= 0) {
      gl.enableVertexAttribArray(alphaLoc);
      gl.vertexAttribPointer(
        alphaLoc,
        1,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        8,
      );
    }

    final rgba = _parseCssColor(fillColor);
    gl.uniform2f(
      gl.getUniformLocation(prog, 'u_resolution'),
      _cssWidth,
      _cssHeight,
    );
    gl.uniform4f(
      gl.getUniformLocation(prog, 'u_color'),
      rgba.r,
      rgba.g,
      rgba.b,
      rgba.a,
    );

    gl.drawArrays(web.WebGLRenderingContext.TRIANGLE_STRIP, 0, pointCount * 2);
    gl.disable(web.WebGLRenderingContext.SCISSOR_TEST);
    return true;
  }

  void _prepareFrame(double cssWidth, double cssHeight, double dpr) {
    _cssWidth = cssWidth;
    _cssHeight = cssHeight;
    _dpr = dpr;

    final targetW = (cssWidth * dpr).toInt();
    final targetH = (cssHeight * dpr).toInt();
    if (_glCanvas.width != targetW) _glCanvas.width = targetW;
    if (_glCanvas.height != targetH) _glCanvas.height = targetH;
    _glCanvas.style
      ..width = '${cssWidth}px'
      ..height = '${cssHeight}px'
      ..display = 'block';
    if (_hudCanvas.parentElement != null &&
        _glCanvas.parentElement != _hudCanvas.parentElement) {
      _hudCanvas.parentElement!.insertBefore(_glCanvas, _hudCanvas);
    }

    final gl = _gl;
    if (gl == null) return;
    gl.viewport(0, 0, targetW, targetH);
    gl.disable(web.WebGLRenderingContext.SCISSOR_TEST);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clear(web.WebGLRenderingContext.COLOR_BUFFER_BIT);
    gl.enable(web.WebGLRenderingContext.BLEND);
    gl.blendFunc(
      web.WebGLRenderingContext.SRC_ALPHA,
      web.WebGLRenderingContext.ONE_MINUS_SRC_ALPHA,
    );
  }

  void _applyScissor(
    web.WebGL2RenderingContext gl,
    double left,
    double top,
    double width,
    double height,
  ) {
    final sx = (left * _dpr).round();
    final sy = ((_cssHeight - top - height) * _dpr).round();
    final sw = math.max(1, (width * _dpr).round());
    final sh = math.max(1, (height * _dpr).round());
    gl.enable(web.WebGLRenderingContext.SCISSOR_TEST);
    gl.scissor(sx, sy, sw, sh);
  }

  static final Expando<WebGL2ChartLayer> _layers = Expando<WebGL2ChartLayer>();

  static const String _lineVertSrc = '''#version 300 es
precision highp float;
in vec2 a_pos;
in vec2 a_normal;
in float a_side;
in float a_arc;

uniform vec2 u_resolution;
uniform float u_halfWidth;

out float v_side;
out float v_arc;

void main() {
  float feather = 1.1;
  vec2 offset = a_normal * a_side * (u_halfWidth + feather);
  vec2 px = a_pos + offset;
  vec2 ndc = (px / u_resolution) * 2.0 - 1.0;
  gl_Position = vec4(ndc.x, -ndc.y, 0.0, 1.0);
  v_side = a_side * (u_halfWidth + feather);
  v_arc = a_arc;
}
''';

  static const String _lineFragSrc = '''#version 300 es
precision highp float;
in float v_side;
in float v_arc;

uniform float u_halfWidth;
uniform vec4 u_color;
uniform vec2 u_dash;

out vec4 outColor;

void main() {
  if (u_dash.x > 0.0) {
    float period = u_dash.x + u_dash.y;
    float phase = mod(v_arc, period);
    if (phase > u_dash.x) {
      discard;
    }
  }
  float dist = abs(v_side);
  float alpha = 1.0 - smoothstep(max(0.0, u_halfWidth - 0.65), u_halfWidth + 0.85, dist);
  outColor = vec4(u_color.rgb, u_color.a * alpha);
}
''';

  static const String _fillVertSrc = '''#version 300 es
precision highp float;
in vec2 a_pos;
in float a_alpha;

uniform vec2 u_resolution;

out float v_alpha;

void main() {
  vec2 ndc = (a_pos / u_resolution) * 2.0 - 1.0;
  gl_Position = vec4(ndc.x, -ndc.y, 0.0, 1.0);
  v_alpha = a_alpha;
}
''';

  static const String _fillFragSrc = '''#version 300 es
precision highp float;
in float v_alpha;

uniform vec4 u_color;

out vec4 outColor;

void main() {
  outColor = vec4(u_color.rgb, u_color.a * v_alpha);
}
''';

  static web.WebGLProgram? _compileProgram(
    web.WebGL2RenderingContext gl,
    String vertSrc,
    String fragSrc,
  ) {
    final vs = _compileShader(
      gl,
      web.WebGLRenderingContext.VERTEX_SHADER,
      vertSrc,
    );
    final fs = _compileShader(
      gl,
      web.WebGLRenderingContext.FRAGMENT_SHADER,
      fragSrc,
    );
    if (vs == null || fs == null) return null;

    final prog = gl.createProgram();
    if (prog == null) return null;
    gl.attachShader(prog, vs);
    gl.attachShader(prog, fs);
    gl.linkProgram(prog);
    final ok =
        (gl.getProgramParameter(
          prog,
          web.WebGLRenderingContext.LINK_STATUS,
        ) as JSBoolean?)?.toDart ??
        false;
    if (!ok) {
      gl.deleteProgram(prog);
      return null;
    }
    return prog;
  }

  static web.WebGLShader? _compileShader(
    web.WebGL2RenderingContext gl,
    int type,
    String src,
  ) {
    final shader = gl.createShader(type);
    if (shader == null) return null;
    gl.shaderSource(shader, src);
    gl.compileShader(shader);
    final ok =
        (gl.getShaderParameter(
          shader,
          web.WebGLRenderingContext.COMPILE_STATUS,
        ) as JSBoolean?)?.toDart ??
        false;
    if (!ok) {
      gl.deleteShader(shader);
      return null;
    }
    return shader;
  }

  static ({double r, double g, double b, double a}) _parseCssColor(String raw) {
    final s = raw.trim();
    if (s.startsWith('#')) {
      final hex = s.substring(1);
      if (hex.length == 6) {
        final r = int.tryParse(hex.substring(0, 2), radix: 16) ?? 59;
        final g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 130;
        final b = int.tryParse(hex.substring(4, 6), radix: 16) ?? 246;
        return (r: r / 255.0, g: g / 255.0, b: b / 255.0, a: 1.0);
      }
      if (hex.length == 8) {
        final r = int.tryParse(hex.substring(0, 2), radix: 16) ?? 59;
        final g = int.tryParse(hex.substring(2, 4), radix: 16) ?? 130;
        final b = int.tryParse(hex.substring(4, 6), radix: 16) ?? 246;
        final a = int.tryParse(hex.substring(6, 8), radix: 16) ?? 255;
        return (r: r / 255.0, g: g / 255.0, b: b / 255.0, a: a / 255.0);
      }
    }
    if (s.startsWith('rgba(') || s.startsWith('rgb(')) {
      final inner = s.substring(s.indexOf('(') + 1, s.lastIndexOf(')'));
      final parts = inner.split(',').map((p) => p.trim()).toList();
      if (parts.length >= 3) {
        final r = (double.tryParse(parts[0]) ?? 255.0) / 255.0;
        final g = (double.tryParse(parts[1]) ?? 255.0) / 255.0;
        final b = (double.tryParse(parts[2]) ?? 255.0) / 255.0;
        final a = parts.length >= 4 ? (double.tryParse(parts[3]) ?? 1.0) : 1.0;
        return (r: r, g: g, b: b, a: a);
      }
    }
    return (r: 0.23, g: 0.51, b: 0.96, a: 1.0);
  }
}

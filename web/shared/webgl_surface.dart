import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'webgl_chart.dart';

/// Interactive WebGL2 3D surface mesh renderer for multivariable functions
/// $z = f(x, y)$ paired with a crisp Canvas2D HUD overlay for axes, bounding
/// box labels, colorbar, and hover coordinate readouts.
final class WebGLSurfaceRenderer {
  /// Returns or creates a [WebGLSurfaceRenderer] bound to [hudCanvas].
  static WebGLSurfaceRenderer forCanvas(
    web.HTMLCanvasElement hudCanvas, {
    required void Function() onUpdate,
    void Function(String text)? onHoverReadout,
  }) {
    var renderer = _renderers[hudCanvas];
    if (renderer == null) {
      renderer = WebGLSurfaceRenderer._create(
        hudCanvas,
        onUpdate: onUpdate,
        onHoverReadout: onHoverReadout,
      );
      _renderers[hudCanvas] = renderer;
    } else {
      renderer._onUpdate = onUpdate;
      renderer._onHoverReadout = onHoverReadout;
    }
    return renderer;
  }

  /// Hides or shows the 3D WebGL underlay and toggles 3D orbit pointer handling.
  static void setActive(web.HTMLCanvasElement hudCanvas, bool active) {
    final renderer = _renderers[hudCanvas];
    if (renderer != null) {
      renderer.isActive = active;
      renderer._glCanvas.style.display = active ? 'block' : 'none';
    }
  }

  /// Composites the 3D WebGL2 surface and Canvas2D HUD into a PNG data URL.
  static String exportPngDataUrl(
    web.HTMLCanvasElement hudCanvas, {
    String backgroundColor = '#0f172a',
  }) {
    final renderer = _renderers[hudCanvas];
    if (renderer == null || !renderer.isAvailable) {
      return hudCanvas.toDataURL('image/png');
    }
    final out = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..width = hudCanvas.width
      ..height = hudCanvas.height;
    final ctx = out.context2D;
    ctx.fillStyle = backgroundColor.toJS;
    ctx.fillRect(0, 0, out.width.toDouble(), out.height.toDouble());
    ctx.drawImage(renderer._glCanvas, 0, 0);
    ctx.drawImage(hudCanvas, 0, 0);
    return out.toDataURL('image/png');
  }

  new _(
    this._hudCanvas,
    this._glCanvas,
    this._gl,
    this._program,
    this._vbo,
    this._ibo, {
    required this._onUpdate,
    this._onHoverReadout,
  }) {
    _attachOrbitListeners();
  }

  factory _create(
    web.HTMLCanvasElement hudCanvas, {
    required void Function() onUpdate,
    void Function(String text)? onHoverReadout,
  }) {
    final glCanvas =
        web.document.createElement('canvas') as web.HTMLCanvasElement
          ..className = 'webgl2-surface-underlay';
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
          'depth': true,
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

    web.WebGLProgram? prog;
    web.WebGLBuffer? vbo;
    web.WebGLBuffer? ibo;
    if (gl != null) {
      prog = _compileProgram(gl, _vertSrc, _fragSrc);
      vbo = gl.createBuffer();
      ibo = gl.createBuffer();
    }

    return WebGLSurfaceRenderer._(
      hudCanvas,
      glCanvas,
      gl,
      prog,
      vbo,
      ibo,
      onUpdate: onUpdate,
      onHoverReadout: onHoverReadout,
    );
  }

  final web.HTMLCanvasElement _hudCanvas;
  final web.HTMLCanvasElement _glCanvas;
  final web.WebGL2RenderingContext? _gl;
  final web.WebGLProgram? _program;
  final web.WebGLBuffer? _vbo;
  final web.WebGLBuffer? _ibo;

  void Function() _onUpdate;
  void Function(String text)? _onHoverReadout;

  /// Whether 3D surface mode is active on [_hudCanvas].
  bool isActive = true;

  /// Horizontal turntable angle in radians.
  double azimuth = -0.68;

  /// Vertical pitch angle in radians.
  double elevation = 0.52;

  /// Camera zoom factor.
  double zoom = 1.0;

  double? _hoverPx;
  double? _hoverPy;
  bool _isDragging = false;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  bool _rafPending = false;

  /// Whether WebGL2 3D rendering is available.
  bool get isAvailable =>
      _gl != null && _program != null && _vbo != null && _ibo != null;

  /// Resets the turntable camera to default orientation and zoom.
  void resetCamera() {
    azimuth = -0.68;
    elevation = 0.52;
    zoom = 1.0;
    _scheduleUpdate();
  }

  /// Renders a 3D surface grid `zValues` of size `gridSize × gridSize` over
  /// `[minX, maxX] × [minY, maxY]` with vertical range `[minZ, maxZ]`.
  void renderSurface({
    required int gridSize,
    required Float64List zValues,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double minZ,
    required double maxZ,
    required String xVar,
    required String yVar,
    String? title,
  }) {
    isActive = true;
    WebGL2ChartLayer.setVisible(_hudCanvas, false);

    final parentRect = _hudCanvas.parentElement?.getBoundingClientRect();
    final selfRect = _hudCanvas.getBoundingClientRect();
    final cssW = (parentRect != null && parentRect.width > 0)
        ? parentRect.width
        : selfRect.width;
    final cssH = (parentRect != null && parentRect.height > 0)
        ? parentRect.height
        : selfRect.height;
    if (cssW <= 0 || cssH <= 0) return;

    final dpr = web.window.devicePixelRatio;
    final targetW = (cssW * dpr).toInt();
    final targetH = (cssH * dpr).toInt();

    if (_hudCanvas.width != targetW) _hudCanvas.width = targetW;
    if (_hudCanvas.height != targetH) _hudCanvas.height = targetH;
    _hudCanvas.style
      ..width = '${cssW}px'
      ..height = '${cssH}px';

    if (_glCanvas.width != targetW) _glCanvas.width = targetW;
    if (_glCanvas.height != targetH) _glCanvas.height = targetH;
    _glCanvas.style
      ..width = '${cssW}px'
      ..height = '${cssH}px'
      ..display = 'block';
    if (_hudCanvas.parentElement != null &&
        _glCanvas.parentElement != _hudCanvas.parentElement) {
      _hudCanvas.parentElement!.insertBefore(_glCanvas, _hudCanvas);
    }

    final hudCtx = _hudCanvas.context2D;
    hudCtx.setTransform(1.0.toJS, 0, 0, 1, 0, 0);
    hudCtx.scale(dpr, dpr);
    hudCtx.clearRect(0, 0, cssW, cssH);

    final spanZ = (maxZ - minZ).abs() < 1e-9 ? 1.0 : (maxZ - minZ);
    final aspect = cssW / math.max(1.0, cssH);
    final mvp = _buildMvpMatrix(aspect);

    if (isAvailable) {
      _renderWebGLSurface(
        gridSize: gridSize,
        zValues: zValues,
        minZ: minZ,
        maxZ: maxZ,
        spanZ: spanZ,
        mvp: mvp,
        targetW: targetW,
        targetH: targetH,
      );
    } else {
      _renderCanvasFallbackSurface(
        hudCtx,
        cssW,
        cssH,
        gridSize: gridSize,
        zValues: zValues,
        minZ: minZ,
        maxZ: maxZ,
        spanZ: spanZ,
        mvp: mvp,
      );
    }

    _drawHudOverlay(
      hudCtx,
      cssW,
      cssH,
      mvp: mvp,
      gridSize: gridSize,
      zValues: zValues,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      minZ: minZ,
      maxZ: maxZ,
      spanZ: spanZ,
      xVar: xVar,
      yVar: yVar,
      title: title,
    );
  }

  void _renderWebGLSurface({
    required int gridSize,
    required Float64List zValues,
    required double minZ,
    required double maxZ,
    required double spanZ,
    required Float32List mvp,
    required int targetW,
    required int targetH,
  }) {
    final gl = _gl!;
    final prog = _program!;
    final vbo = _vbo!;
    final ibo = _ibo!;

    // 9 floats per vertex: nx, ny, nz, normX, normY, normZ, u, v, t
    final n = gridSize;
    final verts = Float32List(n * n * 9);
    final zLimitMin = minZ - spanZ * 0.25;
    final zLimitMax = maxZ + spanZ * 0.25;

    double normZAt(int ix, int iy) {
      final raw = zValues[iy * n + ix];
      if (!raw.isFinite) return double.nan;
      final clamped = raw.clamp(zLimitMin, zLimitMax);
      return ((clamped - minZ) / spanZ) * 1.5 - 0.75;
    }

    final stepNorm = 2.0 / math.max(1, n - 1);
    var vIdx = 0;
    for (var iy = 0; iy < n; iy++) {
      final v = iy / math.max(1, n - 1);
      final ny = v * 2.0 - 1.0;
      for (var ix = 0; ix < n; ix++) {
        final u = ix / math.max(1, n - 1);
        final nx = u * 2.0 - 1.0;
        final nz = normZAt(ix, iy);
        final raw = zValues[iy * n + ix];
        final t = raw.isFinite ? ((raw - minZ) / spanZ).clamp(0.0, 1.0) : 0.5;

        // Central-difference surface normal in normalized space
        final ixL = math.max(0, ix - 1);
        final ixR = math.min(n - 1, ix + 1);
        final iyD = math.max(0, iy - 1);
        final iyU = math.min(n - 1, iy + 1);
        final zL = normZAt(ixL, iy);
        final zR = normZAt(ixR, iy);
        final zD = normZAt(ix, iyD);
        final zU = normZAt(ix, iyU);

        final dzdx = (zL.isFinite && zR.isFinite && ixR > ixL)
            ? (zR - zL) / ((ixR - ixL) * stepNorm)
            : 0.0;
        final dzdy = (zD.isFinite && zU.isFinite && iyU > iyD)
            ? (zU - zD) / ((iyU - iyD) * stepNorm)
            : 0.0;
        var snx = -dzdx;
        var sny = -dzdy;
        var snz = 1.0;
        final nLen = math.sqrt(snx * snx + sny * sny + snz * snz);
        if (nLen > 1e-6) {
          snx /= nLen;
          sny /= nLen;
          snz /= nLen;
        }

        verts[vIdx++] = nx;
        verts[vIdx++] = ny;
        verts[vIdx++] = nz.isFinite ? nz : 0.0;
        verts[vIdx++] = snx;
        verts[vIdx++] = sny;
        verts[vIdx++] = snz;
        verts[vIdx++] = u;
        verts[vIdx++] = v;
        verts[vIdx++] = t;
      }
    }

    // Build triangle indices skipping cells with non-finite or wildly jumping Z
    final maxIndices = (n - 1) * (n - 1) * 6;
    final indices = Uint16List(maxIndices);
    var iIdx = 0;

    bool validVertex(int ix, int iy) {
      final raw = zValues[iy * n + ix];
      return raw.isFinite && raw >= zLimitMin && raw <= zLimitMax;
    }

    for (var iy = 0; iy < n - 1; iy++) {
      for (var ix = 0; ix < n - 1; ix++) {
        if (!validVertex(ix, iy) ||
            !validVertex(ix + 1, iy) ||
            !validVertex(ix, iy + 1) ||
            !validVertex(ix + 1, iy + 1)) {
          continue;
        }
        final i00 = iy * n + ix;
        final i10 = iy * n + ix + 1;
        final i01 = (iy + 1) * n + ix;
        final i11 = (iy + 1) * n + ix + 1;

        indices[iIdx++] = i00;
        indices[iIdx++] = i10;
        indices[iIdx++] = i01;

        indices[iIdx++] = i10;
        indices[iIdx++] = i11;
        indices[iIdx++] = i01;
      }
    }

    gl.viewport(0, 0, targetW, targetH);
    gl.disable(web.WebGLRenderingContext.SCISSOR_TEST);
    gl.clearColor(0.0, 0.0, 0.0, 0.0);
    gl.clearDepth(1.0);
    gl.enable(web.WebGLRenderingContext.DEPTH_TEST);
    gl.depthFunc(web.WebGLRenderingContext.LEQUAL);
    gl.enable(web.WebGLRenderingContext.BLEND);
    gl.blendFunc(
      web.WebGLRenderingContext.SRC_ALPHA,
      web.WebGLRenderingContext.ONE_MINUS_SRC_ALPHA,
    );
    gl.clear(
      web.WebGLRenderingContext.COLOR_BUFFER_BIT |
          web.WebGLRenderingContext.DEPTH_BUFFER_BIT,
    );

    if (iIdx == 0) return;

    gl.useProgram(prog);
    gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, vbo);
    gl.bufferData(
      web.WebGLRenderingContext.ARRAY_BUFFER,
      verts.toJS,
      web.WebGLRenderingContext.STREAM_DRAW,
    );

    gl.bindBuffer(web.WebGLRenderingContext.ELEMENT_ARRAY_BUFFER, ibo);
    final activeIndices = Uint16List.sublistView(indices, 0, iIdx);
    gl.bufferData(
      web.WebGLRenderingContext.ELEMENT_ARRAY_BUFFER,
      activeIndices.toJS,
      web.WebGLRenderingContext.STREAM_DRAW,
    );

    const stride = 9 * 4;
    final posLoc = gl.getAttribLocation(prog, 'a_pos');
    final normLoc = gl.getAttribLocation(prog, 'a_normal');
    final uvLoc = gl.getAttribLocation(prog, 'a_uv');
    final tLoc = gl.getAttribLocation(prog, 'a_t');

    if (posLoc >= 0) {
      gl.enableVertexAttribArray(posLoc);
      gl.vertexAttribPointer(
        posLoc,
        3,
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
        3,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        12,
      );
    }
    if (uvLoc >= 0) {
      gl.enableVertexAttribArray(uvLoc);
      gl.vertexAttribPointer(
        uvLoc,
        2,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        24,
      );
    }
    if (tLoc >= 0) {
      gl.enableVertexAttribArray(tLoc);
      gl.vertexAttribPointer(
        tLoc,
        1,
        web.WebGLRenderingContext.FLOAT,
        false,
        stride,
        32,
      );
    }

    gl.uniformMatrix4fv(gl.getUniformLocation(prog, 'u_mvp'), false, mvp.toJS);

    gl.drawElements(
      web.WebGLRenderingContext.TRIANGLES,
      iIdx,
      web.WebGLRenderingContext.UNSIGNED_SHORT,
      0,
    );
  }

  void _renderCanvasFallbackSurface(
    web.CanvasRenderingContext2D ctx,
    double cssW,
    double cssH, {
    required int gridSize,
    required Float64List zValues,
    required double minZ,
    required double maxZ,
    required double spanZ,
    required Float32List mvp,
  }) {
    final step = math.max(1, gridSize ~/ 28);
    final quads =
        <({double depth, List<({double px, double py})> pts, double t})>[];
    final zLimitMin = minZ - spanZ * 0.25;
    final zLimitMax = maxZ + spanZ * 0.25;

    for (var iy = 0; iy < gridSize - step; iy += step) {
      for (var ix = 0; ix < gridSize - step; ix += step) {
        final corners = [
          (ix: ix, iy: iy),
          (ix: ix + step, iy: iy),
          (ix: ix + step, iy: iy + step),
          (ix: ix, iy: iy + step),
        ];
        final projPts = <({double px, double py})>[];
        var depthSum = 0.0;
        var tSum = 0.0;
        var ok = true;
        for (final c in corners) {
          final raw = zValues[c.iy * gridSize + c.ix];
          if (!raw.isFinite || raw < zLimitMin || raw > zLimitMax) {
            ok = false;
            break;
          }
          final nx = (c.ix / (gridSize - 1)) * 2.0 - 1.0;
          final ny = (c.iy / (gridSize - 1)) * 2.0 - 1.0;
          final nz = ((raw - minZ) / spanZ) * 1.5 - 0.75;
          final p = _projectPoint(mvp, nx, ny, nz, cssW, cssH);
          projPts.add((px: p.px, py: p.py));
          depthSum += p.depth;
          tSum += ((raw - minZ) / spanZ).clamp(0.0, 1.0);
        }
        if (ok) {
          quads.add((depth: depthSum * 0.25, pts: projPts, t: tSum * 0.25));
        }
      }
    }

    quads.sort((a, b) => b.depth.compareTo(a.depth));
    for (final q in quads) {
      ctx.beginPath();
      ctx.moveTo(q.pts[0].px, q.pts[0].py);
      for (var i = 1; i < q.pts.length; i++) {
        ctx.lineTo(q.pts[i].px, q.pts[i].py);
      }
      ctx.closePath();
      ctx.fillStyle = _colormapCss(q.t, alpha: 0.88).toJS;
      ctx.fill();
      ctx.strokeStyle = 'rgba(15, 23, 42, 0.35)'.toJS;
      ctx.lineWidth = 0.6;
      ctx.stroke();
    }
  }

  void _drawHudOverlay(
    web.CanvasRenderingContext2D ctx,
    double cssW,
    double cssH, {
    required Float32List mvp,
    required int gridSize,
    required Float64List zValues,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double minZ,
    required double maxZ,
    required double spanZ,
    required String xVar,
    required String yVar,
    String? title,
  }) {
    ctx.save();

    // 1. 3D Bounding Box Edges in normalized space [-1, 1] × [-1, 1] × [-0.75, 0.75]
    const boxEdges = <({List<double> a, List<double> b})>[
      (a: [-1, -1, -0.75], b: [1, -1, -0.75]),
      (a: [1, -1, -0.75], b: [1, 1, -0.75]),
      (a: [1, 1, -0.75], b: [-1, 1, -0.75]),
      (a: [-1, 1, -0.75], b: [-1, -1, -0.75]),
      (a: [-1, -1, 0.75], b: [1, -1, 0.75]),
      (a: [1, -1, 0.75], b: [1, 1, 0.75]),
      (a: [1, 1, 0.75], b: [-1, 1, 0.75]),
      (a: [-1, 1, 0.75], b: [-1, -1, 0.75]),
      (a: [-1, -1, -0.75], b: [-1, -1, 0.75]),
      (a: [1, -1, -0.75], b: [1, -1, 0.75]),
      (a: [1, 1, -0.75], b: [1, 1, 0.75]),
      (a: [-1, 1, -0.75], b: [-1, 1, 0.75]),
    ];

    ctx.strokeStyle = 'rgba(148, 163, 184, 0.24)'.toJS;
    ctx.lineWidth = 1.0;
    for (final edge in boxEdges) {
      final p0 = _projectPoint(
        mvp,
        edge.a[0],
        edge.a[1],
        edge.a[2],
        cssW,
        cssH,
      );
      final p1 = _projectPoint(
        mvp,
        edge.b[0],
        edge.b[1],
        edge.b[2],
        cssW,
        cssH,
      );
      ctx.beginPath();
      ctx.moveTo(p0.px, p0.py);
      ctx.lineTo(p1.px, p1.py);
      ctx.stroke();
    }

    // 2. Axis Labels at base corners
    ctx.font = 'bold 11px Inter, ui-monospace, sans-serif';
    final pxLabel = _projectPoint(mvp, 0.0, -1.18, -0.78, cssW, cssH);
    ctx.fillStyle = '#60a5fa'.toJS;
    ctx.textAlign = 'center';
    ctx.fillText(
      '$xVar ∈ [${_fmt(minX)}, ${_fmt(maxX)}]',
      pxLabel.px,
      pxLabel.py,
    );

    final pyLabel = _projectPoint(mvp, 1.18, 0.0, -0.78, cssW, cssH);
    ctx.fillStyle = '#34d399'.toJS;
    ctx.fillText(
      '$yVar ∈ [${_fmt(minY)}, ${_fmt(maxY)}]',
      pyLabel.px,
      pyLabel.py,
    );

    final pzTop = _projectPoint(mvp, -1.12, -1.12, 0.75, cssW, cssH);
    final pzBot = _projectPoint(mvp, -1.12, -1.12, -0.75, cssW, cssH);
    ctx.fillStyle = '#fbbf24'.toJS;
    ctx.font = '10px Inter, ui-monospace, sans-serif';
    ctx.fillText(_fmt(maxZ), pzTop.px, pzTop.py);
    ctx.fillText(_fmt(minZ), pzBot.px, pzBot.py);

    // 3. Top-left 3D Badge & Controls Hint
    ctx.fillStyle = 'rgba(15, 23, 42, 0.78)'.toJS;
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)'.toJS;
    var badgeText = title != null
        ? '3D WebGL2 · $title'
        : '3D WebGL2 · Drag to orbit · Scroll to zoom';
    final maxChars = ((cssW - 36.0) / 6.2).floor();
    if (maxChars > 6 && badgeText.length > maxChars) {
      badgeText = '${badgeText.substring(0, maxChars - 1)}…';
    }
    ctx.font = '11px Inter, sans-serif';
    final badgeW = math.min(cssW - 20.0, badgeText.length * 6.2 + 20.0);
    ctx.beginPath();
    ctx.rect(10.0, 10.0, badgeW, 24.0);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#e2e8f0'.toJS;
    ctx.textAlign = 'left';
    ctx.fillText(badgeText, 18.0, 26.0);

    // 4. Hover Vertex Readout & Highlight Dot
    final hx = _hoverPx;
    final hy = _hoverPy;
    if (hx != null && hy != null) {
      var bestDistSq = 400.0; // within 20px radius
      double? bestX;
      double? bestY;
      double? bestZ;
      double? bestPx;
      double? bestPy;

      final probeStep = math.max(1, gridSize ~/ 36);
      for (var iy = 0; iy < gridSize; iy += probeStep) {
        final v = iy / math.max(1, gridSize - 1);
        final ny = v * 2.0 - 1.0;
        final worldY = minY + v * (maxY - minY);
        for (var ix = 0; ix < gridSize; ix += probeStep) {
          final rawZ = zValues[iy * gridSize + ix];
          if (!rawZ.isFinite) continue;
          final u = ix / math.max(1, gridSize - 1);
          final nx = u * 2.0 - 1.0;
          final nz = (((rawZ - minZ) / spanZ).clamp(-0.25, 1.25)) * 1.5 - 0.75;
          final proj = _projectPoint(mvp, nx, ny, nz, cssW, cssH);
          final dx = proj.px - hx;
          final dy = proj.py - hy;
          final dSq = dx * dx + dy * dy;
          if (dSq < bestDistSq) {
            bestDistSq = dSq;
            bestX = minX + u * (maxX - minX);
            bestY = worldY;
            bestZ = rawZ;
            bestPx = proj.px;
            bestPy = proj.py;
          }
        }
      }

      if (bestX != null &&
          bestY != null &&
          bestZ != null &&
          bestPx != null &&
          bestPy != null) {
        ctx.fillStyle = 'rgba(251, 191, 36, 0.35)'.toJS;
        ctx.beginPath();
        ctx.arc(bestPx, bestPy, 7.0, 0.0, 2 * math.pi);
        ctx.fill();

        ctx.fillStyle = '#fbbf24'.toJS;
        ctx.beginPath();
        ctx.arc(bestPx, bestPy, 3.5, 0.0, 2 * math.pi);
        ctx.fill();

        final readoutStr =
            '($xVar: ${_fmt(bestX)}, $yVar: ${_fmt(bestY)}, z: ${_fmt(bestZ)})';
        _onHoverReadout?.call(readoutStr);

        // Tooltip pill near cursor
        const tipW = 195.0;
        const tipH = 26.0;
        final tipX = (bestPx + 12.0 + tipW > cssW)
            ? bestPx - tipW - 12.0
            : bestPx + 12.0;
        final tipY = (bestPy - tipH - 8.0 < 8.0)
            ? bestPy + 10.0
            : bestPy - tipH - 8.0;
        ctx.fillStyle = 'rgba(15, 23, 42, 0.92)'.toJS;
        ctx.strokeStyle = 'rgba(251, 191, 36, 0.45)'.toJS;
        ctx.beginPath();
        ctx.rect(tipX, tipY, tipW, tipH);
        ctx.fill();
        ctx.stroke();

        ctx.fillStyle = '#f8fafc'.toJS;
        ctx.font = 'bold 10.5px Inter, ui-monospace, sans-serif';
        ctx.textAlign = 'left';
        ctx.fillText(readoutStr, tipX + 8.0, tipY + 17.0);
      }
    }

    ctx.restore();
  }

  Float32List _buildMvpMatrix(double aspect) {
    final cosAz = math.cos(azimuth);
    final sinAz = math.sin(azimuth);
    final cosEl = math.cos(elevation);
    final sinEl = math.sin(elevation);

    final aspectScale = aspect < 1.1 ? (1.1 / math.max(0.45, aspect)) : 1.0;
    final dist = (3.75 * aspectScale) / zoom;
    final eyeX = dist * cosEl * cosAz;
    final eyeY = dist * cosEl * sinAz;
    final eyeZ = dist * sinEl;

    final view = _lookAt(eyeX, eyeY, eyeZ, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
    final proj = _perspective(0.72, aspect, 0.2, 20.0);
    return _mulMat4(proj, view);
  }

  ({double px, double py, double depth}) _projectPoint(
    Float32List mvp,
    double x,
    double y,
    double z,
    double cssW,
    double cssH,
  ) {
    final cx = mvp[0] * x + mvp[4] * y + mvp[8] * z + mvp[12];
    final cy = mvp[1] * x + mvp[5] * y + mvp[9] * z + mvp[13];
    final cz = mvp[2] * x + mvp[6] * y + mvp[10] * z + mvp[14];
    final cw = mvp[3] * x + mvp[7] * y + mvp[11] * z + mvp[15];
    final invW = cw.abs() > 1e-6 ? 1.0 / cw : 1.0;
    final ndcX = cx * invW;
    final ndcY = cy * invW;
    final ndcZ = cz * invW;
    return (
      px: (ndcX * 0.5 + 0.5) * cssW,
      py: (0.5 - ndcY * 0.5) * cssH,
      depth: ndcZ,
    );
  }

  void _scheduleUpdate() {
    if (_rafPending) return;
    _rafPending = true;
    web.window.requestAnimationFrame(
      ((num _) {
        _rafPending = false;
        if (isActive) _onUpdate();
      }).toJS,
    );
  }

  void _attachOrbitListeners() {
    _hudCanvas.addEventListener(
      'mousedown',
      ((web.MouseEvent e) {
        if (!isActive || e.button != 0) return;
        _isDragging = true;
        final rect = _hudCanvas.getBoundingClientRect();
        _dragStartX = e.clientX - rect.left;
        _dragStartY = e.clientY - rect.top;
        _hudCanvas.style.cursor = 'grabbing';
      }).toJS,
    );

    _hudCanvas.addEventListener(
      'mousemove',
      ((web.MouseEvent e) {
        if (!isActive) return;
        final rect = _hudCanvas.getBoundingClientRect();
        final curX = e.clientX - rect.left;
        final curY = e.clientY - rect.top;
        if (_isDragging) {
          final dx = curX - _dragStartX;
          final dy = curY - _dragStartY;
          _dragStartX = curX;
          _dragStartY = curY;
          azimuth -= dx * 0.011;
          elevation = (elevation + dy * 0.009).clamp(-1.42, 1.42);
        }
        _hoverPx = curX;
        _hoverPy = curY;
        _scheduleUpdate();
      }).toJS,
    );

    void endDrag() {
      if (_isDragging) {
        _isDragging = false;
        if (isActive) _hudCanvas.style.cursor = 'grab';
      }
    }

    _hudCanvas.addEventListener(
      'mouseup',
      ((web.MouseEvent _) => endDrag()).toJS,
    );

    _hudCanvas.addEventListener(
      'mouseleave',
      ((web.MouseEvent _) {
        if (!isActive) return;
        endDrag();
        _hoverPx = null;
        _hoverPy = null;
        _scheduleUpdate();
      }).toJS,
    );

    _hudCanvas.addEventListener(
      'dblclick',
      ((web.MouseEvent _) {
        if (!isActive) return;
        resetCamera();
      }).toJS,
    );

    _hudCanvas.addEventListener(
      'wheel',
      ((web.WheelEvent e) {
        if (!isActive) return;
        e.preventDefault();
        final factor = e.deltaY < 0 ? 1.12 : 0.89;
        zoom = (zoom * factor).clamp(0.45, 3.2);
        _scheduleUpdate();
      }).toJS,
    );

    _hudCanvas.addEventListener(
      'touchstart',
      ((web.TouchEvent e) {
        if (!isActive || e.touches.length != 1) return;
        final t = e.touches.item(0)!;
        final rect = _hudCanvas.getBoundingClientRect();
        _isDragging = true;
        _dragStartX = t.clientX - rect.left;
        _dragStartY = t.clientY - rect.top;
      }).toJS,
    );

    _hudCanvas.addEventListener(
      'touchmove',
      ((web.TouchEvent e) {
        if (!isActive || !_isDragging || e.touches.length != 1) return;
        e.preventDefault();
        final t = e.touches.item(0)!;
        final rect = _hudCanvas.getBoundingClientRect();
        final curX = t.clientX - rect.left;
        final curY = t.clientY - rect.top;
        final dx = curX - _dragStartX;
        final dy = curY - _dragStartY;
        _dragStartX = curX;
        _dragStartY = curY;
        azimuth -= dx * 0.011;
        elevation = (elevation + dy * 0.009).clamp(-1.42, 1.42);
        _hoverPx = curX;
        _hoverPy = curY;
        _scheduleUpdate();
      }).toJS,
    );

    _hudCanvas.addEventListener(
      'touchend',
      ((web.TouchEvent _) => endDrag()).toJS,
    );
  }

  static final Expando<WebGLSurfaceRenderer> _renderers =
      Expando<WebGLSurfaceRenderer>();

  static const String _vertSrc = '''#version 300 es
precision highp float;
in vec3 a_pos;
in vec3 a_normal;
in vec2 a_uv;
in float a_t;

uniform mat4 u_mvp;

out vec3 v_pos;
out vec3 v_normal;
out vec2 v_uv;
out float v_t;

void main() {
  gl_Position = u_mvp * vec4(a_pos, 1.0);
  v_pos = a_pos;
  v_normal = a_normal;
  v_uv = a_uv;
  v_t = a_t;
}
''';

  static const String _fragSrc = '''#version 300 es
precision highp float;
in vec3 v_pos;
in vec3 v_normal;
in vec2 v_uv;
in float v_t;

out vec4 outColor;

vec3 scientificColormap(float t) {
  float s = clamp(t, 0.0, 1.0);
  vec3 c0 = vec3(0.15, 0.25, 0.68); // Deep Ocean Indigo
  vec3 c1 = vec3(0.08, 0.58, 0.85); // Cerulean Blue
  vec3 c2 = vec3(0.06, 0.73, 0.51); // Emerald Teal
  vec3 c3 = vec3(0.96, 0.62, 0.04); // Warm Amber
  vec3 c4 = vec3(0.99, 0.88, 0.28); // Bright Gold
  if (s < 0.25) return mix(c0, c1, s * 4.0);
  if (s < 0.50) return mix(c1, c2, (s - 0.25) * 4.0);
  if (s < 0.75) return mix(c2, c3, (s - 0.50) * 4.0);
  return mix(c3, c4, (s - 0.75) * 4.0);
}

void main() {
  vec3 N = normalize(v_normal);
  if (!gl_FrontFacing) {
    N = -N;
  }

  vec3 lightDir1 = normalize(vec3(0.55, -0.45, 0.85));
  vec3 lightDir2 = normalize(vec3(-0.6, 0.5, 0.35));
  vec3 viewDir = normalize(vec3(0.0, -1.0, 0.65));
  vec3 halfVec = normalize(lightDir1 + viewDir);

  float diff1 = max(dot(N, lightDir1), 0.0);
  float diff2 = max(dot(N, lightDir2), 0.0) * 0.35;
  float spec = pow(max(dot(N, halfVec), 0.0), 28.0) * 0.28;

  vec3 baseColor = scientificColormap(v_t);

  // Screen-space anti-aliased parameter mesh lines (16 x 16 grid)
  vec2 gridUv = v_uv * 16.0;
  vec2 gridDist = abs(fract(gridUv - 0.5) - 0.5) / max(fwidth(gridUv), vec2(0.0001));
  float meshLine = 1.0 - min(min(gridDist.x, gridDist.y), 1.0);

  // Screen-space elevation contour isolines (12 levels)
  float contourVal = v_t * 12.0;
  float contourDist = abs(fract(contourVal - 0.5) - 0.5) / max(fwidth(contourVal), 0.0001);
  float contourLine = 1.0 - min(contourDist, 1.0);

  vec3 litColor = baseColor * (0.36 + 0.58 * diff1 + diff2) + vec3(spec);
  litColor = mix(litColor, vec3(0.06, 0.09, 0.16), meshLine * 0.34);
  litColor = mix(litColor, vec3(1.0, 1.0, 1.0), contourLine * 0.22);

  outColor = vec4(litColor, 0.95);
}
''';

  static String _colormapCss(double t, {double alpha = 1.0}) {
    final s = t.clamp(0.0, 1.0);
    final r = (38 + s * 210).round().clamp(0, 255);
    final g = (64 + math.sin(s * math.pi) * 140 + s * 40).round().clamp(0, 255);
    final b = (175 + (1.0 - s) * 65 - s * 110).round().clamp(0, 255);
    return 'rgba($r, $g, $b, $alpha)';
  }

  static String _fmt(double v) {
    if (v.abs() < 1e-9) return '0';
    if ((v - v.roundToDouble()).abs() < 1e-6 && v.abs() < 1e5) {
      return v.round().toString();
    }
    return v.toStringAsPrecision(3);
  }

  static Float32List _perspective(
    double fovY,
    double aspect,
    double near,
    double far,
  ) {
    final f = 1.0 / math.tan(fovY * 0.5);
    final nf = 1.0 / (near - far);
    final m = Float32List(16);
    m[0] = f / aspect;
    m[5] = f;
    m[10] = (far + near) * nf;
    m[11] = -1.0;
    m[14] = (2.0 * far * near) * nf;
    return m;
  }

  static Float32List _lookAt(
    double eyeX,
    double eyeY,
    double eyeZ,
    double centerX,
    double centerY,
    double centerZ,
    double upX,
    double upY,
    double upZ,
  ) {
    var fx = centerX - eyeX;
    var fy = centerY - eyeY;
    var fz = centerZ - eyeZ;
    final fLen = math.sqrt(fx * fx + fy * fy + fz * fz);
    if (fLen > 1e-6) {
      fx /= fLen;
      fy /= fLen;
      fz /= fLen;
    }

    var sx = fy * upZ - fz * upY;
    var sy = fz * upX - fx * upZ;
    var sz = fx * upY - fy * upX;
    final sLen = math.sqrt(sx * sx + sy * sy + sz * sz);
    if (sLen > 1e-6) {
      sx /= sLen;
      sy /= sLen;
      sz /= sLen;
    }

    final ux = sy * fz - sz * fy;
    final uy = sz * fx - sx * fz;
    final uz = sx * fy - sy * fx;

    final m = Float32List(16);
    m[0] = sx;
    m[1] = ux;
    m[2] = -fx;
    m[3] = 0.0;

    m[4] = sy;
    m[5] = uy;
    m[6] = -fy;
    m[7] = 0.0;

    m[8] = sz;
    m[9] = uz;
    m[10] = -fz;
    m[11] = 0.0;

    m[12] = -(sx * eyeX + sy * eyeY + sz * eyeZ);
    m[13] = -(ux * eyeX + uy * eyeY + uz * eyeZ);
    m[14] = fx * eyeX + fy * eyeY + fz * eyeZ;
    m[15] = 1.0;
    return m;
  }

  static Float32List _mulMat4(Float32List a, Float32List b) {
    final out = Float32List(16);
    for (var col = 0; col < 4; col++) {
      for (var row = 0; row < 4; row++) {
        out[col * 4 + row] =
            a[0 * 4 + row] * b[col * 4 + 0] +
            a[1 * 4 + row] * b[col * 4 + 1] +
            a[2 * 4 + row] * b[col * 4 + 2] +
            a[3 * 4 + row] * b[col * 4 + 3];
      }
    }
    return out;
  }

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
}

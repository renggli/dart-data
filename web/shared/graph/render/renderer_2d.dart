import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../webgl_utils.dart';
import '../model/axis.dart';
import '../model/dataset.dart';
import '../model/dataset_2d.dart';
import '../model/style.dart';

/// Interactive 2D graph renderer using a WebGL2 raster underlay and Canvas2D HUD.
class Renderer2D {
  /// Creates a 2D renderer mounted inside the container element.
  new(this._container, {this._theme = GraphTheme.dark, this.onProbeChanged}) {
    _glCanvas = web.HTMLCanvasElement()
      ..className = 'graph-canvas-layer graph-gl-layer';
    _hudCanvas = web.HTMLCanvasElement()
      ..className = 'graph-canvas-layer graph-hud-layer';
    _container.appendChild(_glCanvas);
    _container.appendChild(_hudCanvas);

    _gl = _glCanvas.getContext('webgl2') as web.WebGL2RenderingContext?;
    _hud = _hudCanvas.getContext('2d') as web.CanvasRenderingContext2D?;
    _initGl();
    _attachEvents();
    resize();
  }

  /// Callback invoked when the pointer probe moves or leaves the plot area.
  final void Function(Probe2D? probe)? onProbeChanged;

  final web.HTMLElement _container;
  late final web.HTMLCanvasElement _glCanvas;
  late final web.HTMLCanvasElement _hudCanvas;
  web.WebGL2RenderingContext? _gl;
  web.CanvasRenderingContext2D? _hud;

  GraphTheme _theme;
  Scene2D _scene = const Scene2D(datasets: <Dataset2D>[]);
  final Map<String, bool> _visibilityOverrides = <String, bool>{};
  Bounds2D _viewBounds = const Bounds2D(xMin: -5, xMax: 5, yMin: -5, yMax: 5);
  Bounds2D _defaultBounds = const Bounds2D(
    xMin: -5,
    xMax: 5,
    yMin: -5,
    yMax: 5,
  );
  Probe2D? _probe;

  int _width = 1;
  int _height = 1;
  double _dpr = 1.0;

  bool _dragging = false;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  Bounds2D? _dragStartBounds;

  web.WebGLProgram? _texProgram;
  web.WebGLBuffer? _quadBuffer;
  final Map<String, _TextureEntry> _textures = <String, _TextureEntry>{};

  late final JSFunction _onPointerDownJs;
  late final JSFunction _onPointerMoveJs;
  late final JSFunction _onPointerUpJs;
  late final JSFunction _onPointerLeaveJs;
  late final JSFunction _onWheelJs;
  late final JSFunction _onDblClickJs;

  /// Updates the active 2D scene and resets viewport bounds.
  void setScene(Scene2D scene, {bool preserveView = false}) {
    _scene = scene;
    final computed =
        scene.computeBounds() ??
        const Bounds2D(xMin: -5, xMax: 5, yMin: -5, yMax: 5);
    _defaultBounds = _padBounds(computed);
    if (!preserveView) {
      _viewBounds = _applyEqualAspect(_defaultBounds);
    }
    _syncTextures();
    render();
  }

  /// Updates the active theme and re-renders.
  void setTheme(GraphTheme theme) {
    _theme = theme;
    render();
  }

  /// Overrides visibility for [datasetId] without rebuilding the scene.
  void setVisibility(String datasetId, bool visible) {
    _visibilityOverrides[datasetId] = visible;
    render();
  }

  /// Resets pan/zoom back to the scene's initial bounds.
  void resetView() {
    _viewBounds = _applyEqualAspect(_defaultBounds);
    render();
  }

  /// Zooms the current viewport around its center by [factor] (`< 1` zooms in).
  void zoomBy(double factor) {
    final cx = 0.5 * (_viewBounds.xMin + _viewBounds.xMax);
    final cy = 0.5 * (_viewBounds.yMin + _viewBounds.yMax);
    final halfW = 0.5 * _viewBounds.xSpan * factor;
    final halfH = 0.5 * _viewBounds.ySpan * factor;
    double? y2Min;
    double? y2Max;
    if (_viewBounds.y2Min != null && _viewBounds.y2Max != null) {
      final cy2 = 0.5 * (_viewBounds.y2Min! + _viewBounds.y2Max!);
      final halfH2 = 0.5 * _viewBounds.y2Span! * factor;
      y2Min = cy2 - halfH2;
      y2Max = cy2 + halfH2;
    }
    _viewBounds = Bounds2D(
      xMin: cx - halfW,
      xMax: cx + halfW,
      yMin: cy - halfH,
      yMax: cy + halfH,
      y2Min: y2Min,
      y2Max: y2Max,
    );
    render();
  }

  /// Synchronizes canvas pixel dimensions to the container's CSS layout box.
  void resize() {
    final rect = _container.getBoundingClientRect();
    final cssW = math.max(1, rect.width.round());
    final cssH = math.max(1, rect.height.round());
    _dpr = web.window.devicePixelRatio.clamp(1.0, 3.0);
    _width = cssW;
    _height = cssH;

    final pxW = (cssW * _dpr).round();
    final pxH = (cssH * _dpr).round();
    if (_glCanvas.width != pxW || _glCanvas.height != pxH) {
      _glCanvas.width = pxW;
      _glCanvas.height = pxH;
    }
    if (_hudCanvas.width != pxW || _hudCanvas.height != pxH) {
      _hudCanvas.width = pxW;
      _hudCanvas.height = pxH;
    }
    render();
  }

  /// Composites the WebGL2 and Canvas2D layers into a PNG data URL.
  String? exportPngDataUrl() {
    final out = web.HTMLCanvasElement()
      ..width = _hudCanvas.width
      ..height = _hudCanvas.height;
    final ctx = out.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return null;
    ctx.fillStyle = _theme.background.toJS;
    ctx.fillRect(0, 0, out.width.toDouble(), out.height.toDouble());
    ctx.drawImage(_glCanvas, 0, 0);
    ctx.drawImage(_hudCanvas, 0, 0);
    return out.toDataURL('image/png');
  }

  /// Renders both the WebGL2 underlay and Canvas2D HUD.
  void render() {
    final plot = _plotRect();
    _renderGl(plot);
    _renderHud(plot);
  }

  /// Releases DOM listeners and WebGL resources.
  void dispose() {
    _hudCanvas.removeEventListener('pointerdown', _onPointerDownJs);
    _hudCanvas.removeEventListener('pointermove', _onPointerMoveJs);
    _hudCanvas.removeEventListener('pointerup', _onPointerUpJs);
    _hudCanvas.removeEventListener('pointerleave', _onPointerLeaveJs);
    _hudCanvas.removeEventListener('wheel', _onWheelJs);
    _hudCanvas.removeEventListener('dblclick', _onDblClickJs);

    final gl = _gl;
    if (gl != null) {
      for (final entry in _textures.values) {
        gl.deleteTexture(entry.texture);
      }
      _textures.clear();
      if (_quadBuffer != null) gl.deleteBuffer(_quadBuffer);
      if (_texProgram != null) gl.deleteProgram(_texProgram);
    }
    _glCanvas.remove();
    _hudCanvas.remove();
  }

  bool _isVisible(Dataset2D ds) => _visibilityOverrides[ds.id] ?? ds.visible;

  _PlotRect _plotRect() {
    final hasY2 =
        _scene.y2Axis != null ||
        _scene.datasets.any((d) => _isVisible(d) && d.yAxis == YAxisSide.right);
    const left = 54.0;
    final right = hasY2 ? 54.0 : 18.0;
    const top = 16.0;
    final bottom = _scene.xAxis.label.isNotEmpty ? 42.0 : 30.0;
    final w = math.max(10.0, _width - left - right);
    final h = math.max(10.0, _height - top - bottom);
    return _PlotRect(left: left, top: top, width: w, height: h);
  }

  void _initGl() {
    final gl = _gl;
    if (gl == null) return;
    const vertSrc = '''#version 300 es
in vec2 aPos;
in vec2 aUv;
out vec2 vUv;
void main() {
  vUv = aUv;
  gl_Position = vec4(aPos, 0.0, 1.0);
}''';
    const fragSrc = '''#version 300 es
precision mediump float;
uniform sampler2D uTex;
in vec2 vUv;
out vec4 outColor;
void main() {
  outColor = texture(uTex, vUv);
}''';
    _texProgram = compileProgram(gl, vertSrc, fragSrc);
    _quadBuffer = gl.createBuffer();
  }

  void _syncTextures() {
    final gl = _gl;
    if (gl == null) return;
    final activeIds = <String>{};
    for (final ds in _scene.datasets) {
      if (ds is Field2DDataset && ds.showRaster && ds.rgbaPixels != null) {
        activeIds.add(ds.id);
        final pixels = ds.rgbaPixels!;
        final existing = _textures[ds.id];
        final tex = existing?.texture ?? gl.createTexture();
        if (tex == null) continue;
        gl.bindTexture(web.WebGLRenderingContext.TEXTURE_2D, tex);
        gl.texParameteri(
          web.WebGLRenderingContext.TEXTURE_2D,
          web.WebGLRenderingContext.TEXTURE_MIN_FILTER,
          web.WebGLRenderingContext.LINEAR,
        );
        gl.texParameteri(
          web.WebGLRenderingContext.TEXTURE_2D,
          web.WebGLRenderingContext.TEXTURE_MAG_FILTER,
          web.WebGLRenderingContext.LINEAR,
        );
        gl.texParameteri(
          web.WebGLRenderingContext.TEXTURE_2D,
          web.WebGLRenderingContext.TEXTURE_WRAP_S,
          web.WebGLRenderingContext.CLAMP_TO_EDGE,
        );
        gl.texParameteri(
          web.WebGLRenderingContext.TEXTURE_2D,
          web.WebGLRenderingContext.TEXTURE_WRAP_T,
          web.WebGLRenderingContext.CLAMP_TO_EDGE,
        );
        gl.texImage2D(
          web.WebGLRenderingContext.TEXTURE_2D,
          0,
          web.WebGLRenderingContext.RGBA,
          ds.cols.toJS,
          ds.rows.toJS,
          0.toJS,
          web.WebGLRenderingContext.RGBA,
          web.WebGLRenderingContext.UNSIGNED_BYTE,
          pixels.toJS,
        );
        _textures[ds.id] = _TextureEntry(tex, ds.cols, ds.rows);
      }
    }
    final stale = _textures.keys.where((k) => !activeIds.contains(k)).toList();
    for (final k in stale) {
      final entry = _textures.remove(k);
      if (entry != null) gl.deleteTexture(entry.texture);
    }
  }

  void _renderGl(_PlotRect plot) {
    final gl = _gl;
    final prog = _texProgram;
    final buf = _quadBuffer;
    if (gl == null || prog == null || buf == null) return;

    gl.viewport(0, 0, _glCanvas.width, _glCanvas.height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(web.WebGLRenderingContext.COLOR_BUFFER_BIT);

    gl.enable(web.WebGLRenderingContext.SCISSOR_TEST);
    final sx = (plot.left * _dpr).round();
    final sy = ((_height - plot.top - plot.height) * _dpr).round();
    final sw = (plot.width * _dpr).round();
    final sh = (plot.height * _dpr).round();
    gl.scissor(sx, sy, math.max(1, sw), math.max(1, sh));

    gl.enable(web.WebGLRenderingContext.BLEND);
    gl.blendFunc(
      web.WebGLRenderingContext.SRC_ALPHA,
      web.WebGLRenderingContext.ONE_MINUS_SRC_ALPHA,
    );
    gl.useProgram(prog);

    final aPos = gl.getAttribLocation(prog, 'aPos');
    final aUv = gl.getAttribLocation(prog, 'aUv');
    final uTex = gl.getUniformLocation(prog, 'uTex');

    for (final ds in _scene.datasets) {
      if (!_isVisible(ds) || ds is! Field2DDataset || !ds.showRaster) continue;
      final texEntry = _textures[ds.id];
      if (texEntry == null) continue;

      final x0 = _dataToNdcX(ds.domain.xMin, plot);
      final x1 = _dataToNdcX(ds.domain.xMax, plot);
      final y0 = _dataToNdcY(ds.domain.yMin, plot, ds.yAxis);
      final y1 = _dataToNdcY(ds.domain.yMax, plot, ds.yAxis);

      final verts = Float32List.fromList(<double>[
        x0,
        y0,
        0.0,
        0.0,
        x1,
        y0,
        1.0,
        0.0,
        x0,
        y1,
        0.0,
        1.0,
        x1,
        y1,
        1.0,
        1.0,
      ]);

      gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, buf);
      gl.bufferData(
        web.WebGLRenderingContext.ARRAY_BUFFER,
        verts.toJS,
        web.WebGLRenderingContext.DYNAMIC_DRAW,
      );
      if (aPos >= 0) {
        gl.enableVertexAttribArray(aPos);
        gl.vertexAttribPointer(
          aPos,
          2,
          web.WebGLRenderingContext.FLOAT,
          false,
          16,
          0,
        );
      }
      if (aUv >= 0) {
        gl.enableVertexAttribArray(aUv);
        gl.vertexAttribPointer(
          aUv,
          2,
          web.WebGLRenderingContext.FLOAT,
          false,
          16,
          8,
        );
      }
      gl.activeTexture(web.WebGLRenderingContext.TEXTURE0);
      gl.bindTexture(web.WebGLRenderingContext.TEXTURE_2D, texEntry.texture);
      gl.uniform1i(uTex, 0);
      gl.drawArrays(web.WebGLRenderingContext.TRIANGLE_STRIP, 0, 4);
    }

    gl.disable(web.WebGLRenderingContext.SCISSOR_TEST);
  }

  void _renderHud(_PlotRect plot) {
    final ctx = _hud;
    if (ctx == null) return;

    ctx.save();
    ctx.setTransform(1.0.toJS, 0, 0, 1.0, 0, 0);
    ctx.clearRect(
      0,
      0,
      _hudCanvas.width.toDouble(),
      _hudCanvas.height.toDouble(),
    );
    ctx.scale(_dpr, _dpr);

    // Clip plot area for curves, fields, and references.
    ctx.save();
    ctx.beginPath();
    ctx.rect(plot.left, plot.top, plot.width, plot.height);
    ctx.clip();

    // Draw grid and zero axes.
    final xTicks = _computeTicks(
      _viewBounds.xMin,
      _viewBounds.xMax,
      6,
      isInteger: _scene.xAxis.isInteger,
    );
    final yTicks = _computeTicks(
      _viewBounds.yMin,
      _viewBounds.yMax,
      5,
      isInteger: _scene.yAxis.isInteger,
    );

    ctx.strokeStyle = _theme.gridColor.toJS;
    ctx.lineWidth = 1.0;
    for (final x in xTicks) {
      final px = _dataToPxX(x, plot);
      ctx.beginPath();
      ctx.moveTo(px, plot.top);
      ctx.lineTo(px, plot.top + plot.height);
      ctx.stroke();
    }
    for (final y in yTicks) {
      final py = _dataToPxY(y, plot, YAxisSide.left);
      ctx.beginPath();
      ctx.moveTo(plot.left, py);
      ctx.lineTo(plot.left + plot.width, py);
      ctx.stroke();
    }

    ctx.strokeStyle = _theme.axisColor.toJS;
    ctx.lineWidth = 1.25;
    if (_viewBounds.xMin < 0 && _viewBounds.xMax > 0) {
      final px = _dataToPxX(0, plot);
      ctx.beginPath();
      ctx.moveTo(px, plot.top);
      ctx.lineTo(px, plot.top + plot.height);
      ctx.stroke();
    }
    if (_viewBounds.yMin < 0 && _viewBounds.yMax > 0) {
      final py = _dataToPxY(0, plot, YAxisSide.left);
      ctx.beginPath();
      ctx.moveTo(plot.left, py);
      ctx.lineTo(plot.left + plot.width, py);
      ctx.stroke();
    }

    // Fallback 2D raster rendering if WebGL2 was unavailable.
    if (_gl == null) {
      for (final ds in _scene.datasets) {
        if (_isVisible(ds) && ds is Field2DDataset && ds.showRaster) {
          _drawFallbackRaster(ctx, ds, plot);
        }
      }
    }

    // Draw vector fields, curves, parametric paths, and markers.
    for (final ds in _scene.datasets) {
      if (!_isVisible(ds)) continue;
      switch (ds) {
        case Field2DDataset():
          if (ds.showVectors) _drawVectorField(ctx, ds, plot);
        case Function2DDataset():
          _drawFunctionDataset(ctx, ds, plot);
        case Parametric2DDataset():
          _drawParametricDataset(ctx, ds, plot);
      }
    }

    for (final ref in _scene.references) {
      _drawReferenceLine(ctx, ref, plot, YAxisSide.left);
    }

    // Hover crosshair.
    final probe = _probe;
    if (probe != null) {
      final px = _dataToPxX(probe.x, plot);
      final py = _dataToPxY(probe.y, plot, YAxisSide.left);
      ctx.save();
      ctx.strokeStyle = _theme.mutedTextColor.toJS;
      ctx.lineWidth = 1.0;
      ctx.setLineDash([4.0.toJS, 4.0.toJS].toJS);
      ctx.beginPath();
      ctx.moveTo(px, plot.top);
      ctx.lineTo(px, plot.top + plot.height);
      ctx.moveTo(plot.left, py);
      ctx.lineTo(plot.left + plot.width, py);
      ctx.stroke();
      ctx.restore();
    }

    ctx.restore(); // end clip

    // Frame border & ticks.
    ctx.strokeStyle = _theme.axisColor.toJS;
    ctx.lineWidth = 1.0;
    ctx.strokeRect(plot.left, plot.top, plot.width, plot.height);

    ctx.fillStyle = _theme.mutedTextColor.toJS;
    ctx.font = '11px system-ui, -apple-system, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    for (final x in xTicks) {
      final px = _dataToPxX(x, plot);
      ctx.fillText(formatGraphNumber(x), px, plot.top + plot.height + 5);
    }

    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';
    for (final y in yTicks) {
      final py = _dataToPxY(y, plot, YAxisSide.left);
      ctx.fillText(formatGraphNumber(y), plot.left - 6, py);
    }

    if (_viewBounds.y2Min != null && _viewBounds.y2Max != null) {
      final y2Ticks = _computeTicks(
        _viewBounds.y2Min!,
        _viewBounds.y2Max!,
        5,
        isInteger: _scene.y2Axis?.isInteger ?? false,
      );
      ctx.textAlign = 'left';
      for (final y2 in y2Ticks) {
        final py = _dataToPxY(y2, plot, YAxisSide.right);
        ctx.fillText(formatGraphNumber(y2), plot.left + plot.width + 6, py);
      }
    }

    if (_scene.xAxis.label.isNotEmpty) {
      ctx.fillStyle = _theme.textColor.toJS;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'bottom';
      ctx.fillText(
        _scene.xAxis.label,
        plot.left + plot.width * 0.5,
        _height - 4,
      );
    }

    if (_scene.yAxis.label.isNotEmpty) {
      ctx.save();
      ctx.fillStyle = _theme.textColor.toJS;
      ctx.translate(14, plot.top + plot.height * 0.5);
      ctx.rotate(-math.pi * 0.5);
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';
      ctx.fillText(_scene.yAxis.label, 0, 0);
      ctx.restore();
    }

    ctx.restore();
  }

  void _drawFallbackRaster(
    web.CanvasRenderingContext2D ctx,
    Field2DDataset ds,
    _PlotRect plot,
  ) {
    final pixels = ds.rgbaPixels;
    if (pixels == null) return;
    final cellW =
        (ds.domain.xSpan / ds.cols) * (plot.width / _viewBounds.xSpan);
    final cellH =
        (ds.domain.ySpan / ds.rows) * (plot.height / _viewBounds.ySpan);
    for (var row = 0; row < ds.rows; row++) {
      final y = ds.domain.yMin + (row / ds.rows) * ds.domain.ySpan;
      final py = _dataToPxY(y, plot, ds.yAxis);
      for (var col = 0; col < ds.cols; col++) {
        final x = ds.domain.xMin + (col / ds.cols) * ds.domain.xSpan;
        final px = _dataToPxX(x, plot);
        final base = (row * ds.cols + col) * 4;
        final a = pixels[base + 3] / 255.0;
        if (a <= 0) continue;
        ctx.fillStyle =
            'rgba(${pixels[base]}, ${pixels[base + 1]}, ${pixels[base + 2]}, $a)'
                .toJS;
        ctx.fillRect(px, py - cellH, cellW + 0.5, cellH + 0.5);
      }
    }
  }

  void _drawVectorField(
    web.CanvasRenderingContext2D ctx,
    Field2DDataset ds,
    _PlotRect plot,
  ) {
    if (ds.samples.isEmpty) return;
    var maxMag = 0.0;
    for (final s in ds.samples) {
      if (s.scalar.isFinite && s.scalar > maxMag) maxMag = s.scalar;
    }
    if (maxMag <= 0) maxMag = 1.0;

    final cellPx = math.min(
      plot.width / math.max(2, ds.cols),
      plot.height / math.max(2, ds.rows),
    );
    final maxArrowLen = math.max(8.0, cellPx * 0.78);

    ctx.lineWidth = 1.4;
    for (final s in ds.samples) {
      if (!s.u.isFinite ||
          !s.v.isFinite ||
          !s.scalar.isFinite ||
          s.scalar == 0) {
        continue;
      }
      final t = (s.scalar / maxMag).clamp(0.0, 1.0);
      final color = ds.colormap.sampleCss(t);
      final px = _dataToPxX(s.x, plot);
      final py = _dataToPxY(s.y, plot, ds.yAxis);
      final len = maxArrowLen * (0.25 + 0.75 * t);
      final angle = math.atan2(-s.v, s.u);
      final dx = math.cos(angle) * len;
      final dy = math.sin(angle) * len;
      final tx = px + dx;
      final ty = py + dy;

      ctx.strokeStyle = color.toJS;
      ctx.fillStyle = color.toJS;
      ctx.beginPath();
      ctx.moveTo(px, py);
      ctx.lineTo(tx, ty);
      ctx.stroke();

      const head = 4.5;
      ctx.beginPath();
      ctx.moveTo(tx, ty);
      ctx.lineTo(
        tx - head * math.cos(angle - 0.5),
        ty - head * math.sin(angle - 0.5),
      );
      ctx.lineTo(
        tx - head * math.cos(angle + 0.5),
        ty - head * math.sin(angle + 0.5),
      );
      ctx.closePath();
      ctx.fill();
    }
  }

  void _drawFunctionDataset(
    web.CanvasRenderingContext2D ctx,
    Function2DDataset ds,
    _PlotRect plot,
  ) {
    final n = math.min(ds.xs.length, ds.ys.length);
    if (n == 0) return;

    for (final ref in ds.references) {
      _drawReferenceLine(ctx, ref, plot, ds.yAxis);
    }

    if (ds.fill != null && ds.mode == CurveRenderMode.continuous) {
      final fill = ds.fill!;
      final basePy = _dataToPxY(fill.baseline, plot, ds.yAxis);
      ctx.save();
      ctx.globalAlpha = fill.opacity;
      ctx.fillStyle = fill.color.toJS;
      var inSeg = false;
      var firstPx = 0.0;
      var lastPx = 0.0;
      for (var i = 0; i < n; i++) {
        final x = ds.xs[i];
        final y = ds.ys[i];
        if (!x.isFinite || !y.isFinite) {
          if (inSeg) {
            ctx.lineTo(lastPx, basePy);
            ctx.lineTo(firstPx, basePy);
            ctx.closePath();
            ctx.fill();
            inSeg = false;
          }
          continue;
        }
        final px = _dataToPxX(x, plot);
        final py = _dataToPxY(y, plot, ds.yAxis);
        if (!inSeg) {
          ctx.beginPath();
          ctx.moveTo(px, py);
          firstPx = px;
          inSeg = true;
        } else {
          ctx.lineTo(px, py);
        }
        lastPx = px;
      }
      if (inSeg) {
        ctx.lineTo(lastPx, basePy);
        ctx.lineTo(firstPx, basePy);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();
    }

    ctx.save();
    ctx.strokeStyle = ds.color.toJS;
    ctx.fillStyle = ds.color.toJS;
    ctx.lineWidth = ds.width;
    if (ds.dashed) {
      ctx.setLineDash([6.0.toJS, 4.0.toJS].toJS);
    }

    switch (ds.mode) {
      case CurveRenderMode.continuous:
        var drawing = false;
        ctx.beginPath();
        for (var i = 0; i < n; i++) {
          final x = ds.xs[i];
          final y = ds.ys[i];
          if (!x.isFinite || !y.isFinite) {
            drawing = false;
            continue;
          }
          final px = _dataToPxX(x, plot);
          final py = _dataToPxY(y, plot, ds.yAxis);
          if (!drawing) {
            ctx.moveTo(px, py);
            drawing = true;
          } else {
            ctx.lineTo(px, py);
          }
        }
        ctx.stroke();
      case CurveRenderMode.step:
        ctx.beginPath();
        var started = false;
        var prevPy = 0.0;
        for (var i = 0; i < n; i++) {
          final x = ds.xs[i];
          final y = ds.ys[i];
          if (!x.isFinite || !y.isFinite) {
            started = false;
            continue;
          }
          final px = _dataToPxX(x, plot);
          final py = _dataToPxY(y, plot, ds.yAxis);
          if (!started) {
            ctx.moveTo(px, py);
            started = true;
          } else {
            ctx.lineTo(px, prevPy);
            ctx.lineTo(px, py);
          }
          prevPy = py;
        }
        ctx.stroke();
      case CurveRenderMode.stem:
        final basePy = _dataToPxY(0, plot, ds.yAxis);
        for (var i = 0; i < n; i++) {
          final x = ds.xs[i];
          final y = ds.ys[i];
          if (!x.isFinite || !y.isFinite) continue;
          final px = _dataToPxX(x, plot);
          final py = _dataToPxY(y, plot, ds.yAxis);
          ctx.beginPath();
          ctx.moveTo(px, basePy);
          ctx.lineTo(px, py);
          ctx.stroke();
          ctx.beginPath();
          ctx.arc(px, py, math.max(2.5, ds.width + 1.0), 0, math.pi * 2);
          ctx.fill();
        }
      case CurveRenderMode.histogram:
        final basePy = _dataToPxY(0, plot, ds.yAxis);
        ctx.globalAlpha = 0.75;
        for (var i = 0; i < n; i++) {
          final x = ds.xs[i];
          final y = ds.ys[i];
          if (!x.isFinite || !y.isFinite) continue;
          final px = _dataToPxX(x, plot);
          final py = _dataToPxY(y, plot, ds.yAxis);
          final nextPx = i + 1 < n
              ? _dataToPxX(ds.xs[i + 1], plot)
              : px + (i > 0 ? px - _dataToPxX(ds.xs[i - 1], plot) : 10.0);
          final barW = math.max(2.0, (nextPx - px).abs() * 0.85);
          ctx.fillRect(
            px - barW * 0.5,
            math.min(py, basePy),
            barW,
            (basePy - py).abs(),
          );
        }
      case CurveRenderMode.scatter:
        for (var i = 0; i < n; i++) {
          final x = ds.xs[i];
          final y = ds.ys[i];
          if (!x.isFinite || !y.isFinite) continue;
          final px = _dataToPxX(x, plot);
          final py = _dataToPxY(y, plot, ds.yAxis);
          ctx.beginPath();
          ctx.arc(px, py, math.max(2.5, ds.width + 0.8), 0, math.pi * 2);
          ctx.fill();
        }
    }
    ctx.restore();

    // Markers.
    for (final m in ds.markers) {
      if (!m.x.isFinite || !m.y.isFinite) continue;
      final px = _dataToPxX(m.x, plot);
      final py = _dataToPxY(m.y, plot, ds.yAxis);
      ctx.save();
      ctx.fillStyle = (m.color ?? ds.color).toJS;
      ctx.strokeStyle = _theme.background.toJS;
      ctx.lineWidth = 1.5;
      ctx.beginPath();
      ctx.arc(px, py, m.radius, 0, math.pi * 2);
      ctx.fill();
      ctx.stroke();
      if (m.label != null && m.label!.isNotEmpty) {
        ctx.fillStyle = _theme.textColor.toJS;
        ctx.font = '11px system-ui, -apple-system, sans-serif';
        ctx.textAlign = 'left';
        ctx.textBaseline = 'bottom';
        ctx.fillText(m.label!, px + m.radius + 4, py - 2);
      }
      ctx.restore();
    }
  }

  void _drawParametricDataset(
    web.CanvasRenderingContext2D ctx,
    Parametric2DDataset ds,
    _PlotRect plot,
  ) {
    final n = math.min(ds.xs.length, ds.ys.length);
    if (n == 0) return;
    ctx.save();
    ctx.strokeStyle = ds.color.toJS;
    ctx.lineWidth = ds.width;
    if (ds.dashed) {
      ctx.setLineDash([6.0.toJS, 4.0.toJS].toJS);
    }
    ctx.beginPath();
    var drawing = false;
    for (var i = 0; i < n; i++) {
      final x = ds.xs[i];
      final y = ds.ys[i];
      if (!x.isFinite || !y.isFinite) {
        drawing = false;
        continue;
      }
      final px = _dataToPxX(x, plot);
      final py = _dataToPxY(y, plot, ds.yAxis);
      if (!drawing) {
        ctx.moveTo(px, py);
        drawing = true;
      } else {
        ctx.lineTo(px, py);
      }
    }
    ctx.stroke();
    ctx.restore();
  }

  void _drawReferenceLine(
    web.CanvasRenderingContext2D ctx,
    ReferenceLine ref,
    _PlotRect plot,
    YAxisSide yAxis,
  ) {
    if (!ref.value.isFinite) return;
    ctx.save();
    ctx.strokeStyle = ref.color.toJS;
    ctx.lineWidth = 1.2;
    if (ref.dashed) {
      ctx.setLineDash([5.0.toJS, 4.0.toJS].toJS);
    }
    ctx.beginPath();
    if (ref.isVertical) {
      final px = _dataToPxX(ref.value, plot);
      ctx.moveTo(px, plot.top);
      ctx.lineTo(px, plot.top + plot.height);
    } else {
      final py = _dataToPxY(ref.value, plot, yAxis);
      ctx.moveTo(plot.left, py);
      ctx.lineTo(plot.left + plot.width, py);
    }
    ctx.stroke();
    ctx.restore();
  }

  double _dataToPxX(double x, _PlotRect plot) =>
      plot.left + ((x - _viewBounds.xMin) / _viewBounds.xSpan) * plot.width;

  double _dataToPxY(double y, _PlotRect plot, YAxisSide side) {
    final minY = side == YAxisSide.right
        ? (_viewBounds.y2Min ?? _viewBounds.yMin)
        : _viewBounds.yMin;
    final spanY = side == YAxisSide.right
        ? (_viewBounds.y2Span ?? _viewBounds.ySpan)
        : _viewBounds.ySpan;
    return plot.top + plot.height - ((y - minY) / spanY) * plot.height;
  }

  double _dataToNdcX(double x, _PlotRect plot) {
    final px = _dataToPxX(x, plot);
    return (px / _width) * 2.0 - 1.0;
  }

  double _dataToNdcY(double y, _PlotRect plot, YAxisSide side) {
    final py = _dataToPxY(y, plot, side);
    return 1.0 - (py / _height) * 2.0;
  }

  Bounds2D _padBounds(Bounds2D b) {
    final padX = b.xSpan * 0.05;
    final padY = b.ySpan * 0.08;
    var y2Min = b.y2Min;
    var y2Max = b.y2Max;
    if (y2Min != null && y2Max != null) {
      final padY2 = (y2Max - y2Min) * 0.08;
      y2Min -= padY2;
      y2Max += padY2;
    }
    return Bounds2D(
      xMin: b.xMin - padX,
      xMax: b.xMax + padX,
      yMin: b.yMin - padY,
      yMax: b.yMax + padY,
      y2Min: y2Min,
      y2Max: y2Max,
    );
  }

  Bounds2D _applyEqualAspect(Bounds2D b) {
    if (!_scene.equalAspect) return b;
    final plot = _plotRect();
    if (plot.width <= 0 || plot.height <= 0) return b;
    final aspect = plot.width / plot.height;
    final dataAspect = b.xSpan / b.ySpan;
    if (dataAspect < aspect) {
      final targetSpan = b.ySpan * aspect;
      final cx = 0.5 * (b.xMin + b.xMax);
      return b.copyWith(
        xMin: cx - 0.5 * targetSpan,
        xMax: cx + 0.5 * targetSpan,
      );
    } else {
      final targetSpan = b.xSpan / aspect;
      final cy = 0.5 * (b.yMin + b.yMax);
      return b.copyWith(
        yMin: cy - 0.5 * targetSpan,
        yMax: cy + 0.5 * targetSpan,
      );
    }
  }

  void _attachEvents() {
    _onPointerDownJs = ((web.PointerEvent e) {
      _dragging = true;
      _dragStartX = e.offsetX;
      _dragStartY = e.offsetY;
      _dragStartBounds = _viewBounds;
      _hudCanvas.setPointerCapture(e.pointerId);
    }).toJS;

    _onPointerMoveJs = ((web.PointerEvent e) {
      final plot = _plotRect();
      if (_dragging && _dragStartBounds != null) {
        final start = _dragStartBounds!;
        final dx = (e.offsetX - _dragStartX) / plot.width * start.xSpan;
        final dy = (e.offsetY - _dragStartY) / plot.height * start.ySpan;
        var y2Min = start.y2Min;
        var y2Max = start.y2Max;
        if (y2Min != null && y2Max != null) {
          final dy2 = (e.offsetY - _dragStartY) / plot.height * (y2Max - y2Min);
          y2Min += dy2;
          y2Max += dy2;
        }
        _viewBounds = Bounds2D(
          xMin: start.xMin - dx,
          xMax: start.xMax - dx,
          yMin: start.yMin + dy,
          yMax: start.yMax + dy,
          y2Min: y2Min,
          y2Max: y2Max,
        );
        render();
        return;
      }

      if (e.offsetX < plot.left ||
          e.offsetX > plot.left + plot.width ||
          e.offsetY < plot.top ||
          e.offsetY > plot.top + plot.height) {
        if (_probe != null) {
          _probe = null;
          onProbeChanged?.call(null);
          render();
        }
        return;
      }

      final x =
          _viewBounds.xMin +
          ((e.offsetX - plot.left) / plot.width) * _viewBounds.xSpan;
      final y =
          _viewBounds.yMax -
          ((e.offsetY - plot.top) / plot.height) * _viewBounds.ySpan;
      double? y2;
      if (_viewBounds.y2Min != null && _viewBounds.y2Max != null) {
        y2 =
            _viewBounds.y2Max! -
            ((e.offsetY - plot.top) / plot.height) * _viewBounds.y2Span!;
      }
      _probe = Probe2D(x: x, y: y, y2: y2);
      onProbeChanged?.call(_probe);
      render();
    }).toJS;

    _onPointerUpJs = ((web.PointerEvent e) {
      _dragging = false;
      _dragStartBounds = null;
      if (_hudCanvas.hasPointerCapture(e.pointerId)) {
        _hudCanvas.releasePointerCapture(e.pointerId);
      }
    }).toJS;

    _onPointerLeaveJs = ((web.Event _) {
      if (!_dragging && _probe != null) {
        _probe = null;
        onProbeChanged?.call(null);
        render();
      }
    }).toJS;

    _onWheelJs = ((web.WheelEvent e) {
      e.preventDefault();
      final plot = _plotRect();
      final factor = e.deltaY > 0 ? 1.12 : 1.0 / 1.12;
      final fx = ((e.offsetX - plot.left) / plot.width).clamp(0.0, 1.0);
      final fy = ((e.offsetY - plot.top) / plot.height).clamp(0.0, 1.0);

      final anchorX = _viewBounds.xMin + fx * _viewBounds.xSpan;
      final anchorY = _viewBounds.yMax - fy * _viewBounds.ySpan;

      final newXSpan = _viewBounds.xSpan * factor;
      final newYSpan = _viewBounds.ySpan * factor;

      var y2Min = _viewBounds.y2Min;
      var y2Max = _viewBounds.y2Max;
      if (y2Min != null && y2Max != null) {
        final anchorY2 = y2Max - fy * (y2Max - y2Min);
        final newY2Span = (y2Max - y2Min) * factor;
        y2Min = anchorY2 - (1.0 - fy) * newY2Span;
        y2Max = anchorY2 + fy * newY2Span;
      }

      _viewBounds = Bounds2D(
        xMin: anchorX - fx * newXSpan,
        xMax: anchorX + (1.0 - fx) * newXSpan,
        yMin: anchorY - (1.0 - fy) * newYSpan,
        yMax: anchorY + fy * newYSpan,
        y2Min: y2Min,
        y2Max: y2Max,
      );
      render();
    }).toJS;

    _onDblClickJs = ((web.Event _) {
      resetView();
    }).toJS;

    _hudCanvas.addEventListener('pointerdown', _onPointerDownJs);
    _hudCanvas.addEventListener('pointermove', _onPointerMoveJs);
    _hudCanvas.addEventListener('pointerup', _onPointerUpJs);
    _hudCanvas.addEventListener('pointerleave', _onPointerLeaveJs);
    _hudCanvas.addEventListener('wheel', _onWheelJs);
    _hudCanvas.addEventListener('dblclick', _onDblClickJs);
  }
}

class _PlotRect {
  const new({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class _TextureEntry {
  const new(this.texture, this.cols, this.rows);

  final web.WebGLTexture texture;
  final int cols;
  final int rows;
}

List<double> _computeTicks(
  double minVal,
  double maxVal,
  int targetCount, {
  bool isInteger = false,
}) {
  if (!minVal.isFinite || !maxVal.isFinite || maxVal <= minVal) {
    return const <double>[];
  }
  final span = maxVal - minVal;
  final rawStep = span / math.max(1, targetCount);
  final mag = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
  final norm = rawStep / mag;
  final niceNorm = norm < 1.5
      ? 1.0
      : norm < 3.0
      ? 2.0
      : norm < 7.0
      ? 5.0
      : 10.0;
  var step = niceNorm * mag;
  if (isInteger && step < 1.0) step = 1.0;

  final start = (minVal / step).ceil() * step;
  final ticks = <double>[];
  for (var v = start; v <= maxVal + step * 1e-6; v += step) {
    ticks.add(v.abs() < step * 1e-9 ? 0.0 : v);
    if (ticks.length > 32) break;
  }
  return ticks;
}

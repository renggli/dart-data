import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../webgl_utils.dart';
import '../model/axis.dart';
import '../model/dataset.dart';
import '../model/dataset_3d.dart';
import '../model/style.dart';

/// Interactive 3D graph renderer using depth-buffered WebGL2 and a Canvas2D HUD.
class Renderer3D {
  /// Creates a 3D renderer mounted inside the container element.
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

  /// Callback invoked when the 3D pointer probe updates or clears.
  final void Function(Probe3D? probe)? onProbeChanged;

  final web.HTMLElement _container;
  late final web.HTMLCanvasElement _glCanvas;
  late final web.HTMLCanvasElement _hudCanvas;
  web.WebGL2RenderingContext? _gl;
  web.CanvasRenderingContext2D? _hud;

  GraphTheme _theme;
  Scene3D _scene = const Scene3D(datasets: <Dataset3D>[]);
  final Map<String, bool> _visibilityOverrides = <String, bool>{};
  Bounds3D _bounds = const Bounds3D(
    xMin: -1,
    xMax: 1,
    yMin: -1,
    yMax: 1,
    zMin: -1,
    zMax: 1,
  );

  double _yaw = -0.68;
  double _pitch = 0.48;
  double _distance = 3.2;

  int _width = 1;
  int _height = 1;
  double _dpr = 1.0;

  bool _dragging = false;
  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  double _dragStartYaw = 0.0;
  double _dragStartPitch = 0.0;
  Probe3D? _probe;

  web.WebGLProgram? _meshProgram;
  web.WebGLProgram? _lineProgram;
  final Map<String, _SurfaceMeshBuffers> _surfaceMeshes =
      <String, _SurfaceMeshBuffers>{};
  final Map<String, _LineBuffers> _lineBuffers = <String, _LineBuffers>{};

  late final JSFunction _onPointerDownJs;
  late final JSFunction _onPointerMoveJs;
  late final JSFunction _onPointerUpJs;
  late final JSFunction _onPointerLeaveJs;
  late final JSFunction _onWheelJs;
  late final JSFunction _onDblClickJs;

  /// Updates the active 3D scene and rebuilds GPU geometry buffers.
  void setScene(Scene3D scene, {bool preserveView = false}) {
    _scene = scene;
    _bounds =
        scene.computeBounds() ??
        const Bounds3D(xMin: -1, xMax: 1, yMin: -1, yMax: 1, zMin: -1, zMax: 1);
    if (!preserveView) {
      _yaw = -0.68;
      _pitch = 0.48;
      _distance = 3.2;
    }
    _rebuildBuffers();
    render();
  }

  /// Updates the active theme and re-renders.
  void setTheme(GraphTheme theme) {
    _theme = theme;
    render();
  }

  /// Overrides visibility for [datasetId] without rebuilding buffers.
  void setVisibility(String datasetId, bool visible) {
    _visibilityOverrides[datasetId] = visible;
    render();
  }

  /// Resets orbit angles and zoom distance to default.
  void resetView() {
    _yaw = -0.68;
    _pitch = 0.48;
    _distance = 3.2;
    render();
  }

  /// Zooms the camera distance by [factor] (`< 1` zooms in).
  void zoomBy(double factor) {
    _distance = (_distance * factor).clamp(1.4, 12.0);
    render();
  }

  /// Synchronizes canvas backing sizes to the container CSS layout box.
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

  /// Renders the 3D WebGL2 scene and Canvas2D axes/labels HUD.
  void render() {
    final mvp = _computeMvpMatrix();
    _renderGl(mvp);
    _renderHud(mvp);
  }

  /// Releases DOM listeners and WebGL resources.
  void dispose() {
    _hudCanvas.removeEventListener('pointerdown', _onPointerDownJs);
    _hudCanvas.removeEventListener('pointermove', _onPointerMoveJs);
    _hudCanvas.removeEventListener('pointerup', _onPointerUpJs);
    _hudCanvas.removeEventListener('pointerleave', _onPointerLeaveJs);
    _hudCanvas.removeEventListener('wheel', _onWheelJs);
    _hudCanvas.removeEventListener('dblclick', _onDblClickJs);

    _clearGpuBuffers();
    final gl = _gl;
    if (gl != null) {
      if (_meshProgram != null) gl.deleteProgram(_meshProgram);
      if (_lineProgram != null) gl.deleteProgram(_lineProgram);
    }
    _glCanvas.remove();
    _hudCanvas.remove();
  }

  bool _isVisible(Dataset3D ds) => _visibilityOverrides[ds.id] ?? ds.visible;

  void _initGl() {
    final gl = _gl;
    if (gl == null) return;

    const meshVert = '''#version 300 es
uniform mat4 uMvp;
in vec3 aPos;
in vec3 aNormal;
in vec3 aColor;
out vec3 vNormal;
out vec3 vColor;
void main() {
  vNormal = aNormal;
  vColor = aColor;
  gl_Position = uMvp * vec4(aPos, 1.0);
}''';

    const meshFrag = '''#version 300 es
precision mediump float;
in vec3 vNormal;
in vec3 vColor;
out vec4 outColor;
void main() {
  vec3 n = normalize(vNormal);
  vec3 lightDir = normalize(vec3(0.45, 0.55, 0.85));
  float diff = abs(dot(n, lightDir));
  float shade = 0.35 + 0.65 * diff;
  outColor = vec4(vColor * shade, 0.94);
}''';

    const lineVert = '''#version 300 es
uniform mat4 uMvp;
in vec3 aPos;
in vec3 aColor;
out vec3 vColor;
void main() {
  vColor = aColor;
  gl_Position = uMvp * vec4(aPos, 1.0);
}''';

    const lineFrag = '''#version 300 es
precision mediump float;
in vec3 vColor;
out vec4 outColor;
void main() {
  outColor = vec4(vColor, 1.0);
}''';

    _meshProgram = compileProgram(gl, meshVert, meshFrag);
    _lineProgram = compileProgram(gl, lineVert, lineFrag);
  }

  void _clearGpuBuffers() {
    final gl = _gl;
    if (gl == null) return;
    for (final m in _surfaceMeshes.values) {
      gl.deleteBuffer(m.vbo);
      gl.deleteBuffer(m.ibo);
      if (m.wireIbo != null) gl.deleteBuffer(m.wireIbo);
    }
    _surfaceMeshes.clear();
    for (final l in _lineBuffers.values) {
      gl.deleteBuffer(l.vbo);
    }
    _lineBuffers.clear();
  }

  void _rebuildBuffers() {
    final gl = _gl;
    if (gl == null) return;
    _clearGpuBuffers();

    for (final ds in _scene.datasets) {
      switch (ds) {
        case Surface3DDataset():
          _buildSurfaceBuffers(gl, ds);
        case Parametric3DDataset():
          _buildParametricBuffers(gl, ds);
        case VectorField3DDataset():
          _buildVectorFieldBuffers(gl, ds);
      }
    }
  }

  void _buildSurfaceBuffers(
    web.WebGL2RenderingContext gl,
    Surface3DDataset ds,
  ) {
    final nx = ds.nx;
    final ny = ds.ny;
    if (nx < 2 || ny < 2) return;

    // 9 floats per vertex: px, py, pz, nx, ny, nz, r, g, b
    final verts = Float32List(nx * ny * 9);
    for (var j = 0; j < ny; j++) {
      final y = _normY(ds.ys[j]);
      for (var i = 0; i < nx; i++) {
        final x = _normX(ds.xs[i]);
        final rawZ = ds.zs[j * nx + i];
        final z = rawZ.isFinite ? _normZ(rawZ) : 0.0;
        final t = rawZ.isFinite
            ? ((rawZ - _bounds.zMin) / _bounds.zSpan).clamp(0.0, 1.0)
            : 0.0;
        final c = ds.colormap.sampleRgba(t);

        // Central difference normal in normalized coordinates.
        final iPrev = math.max(0, i - 1);
        final iNext = math.min(nx - 1, i + 1);
        final jPrev = math.max(0, j - 1);
        final jNext = math.min(ny - 1, j + 1);
        final zx0 = ds.zs[j * nx + iPrev];
        final zx1 = ds.zs[j * nx + iNext];
        final zy0 = ds.zs[jPrev * nx + i];
        final zy1 = ds.zs[jNext * nx + i];
        final dx = _normX(ds.xs[iNext]) - _normX(ds.xs[iPrev]);
        final dy = _normY(ds.ys[jNext]) - _normY(ds.ys[jPrev]);
        final dzdx = (zx0.isFinite && zx1.isFinite && dx != 0)
            ? (_normZ(zx1) - _normZ(zx0)) / dx
            : 0.0;
        final dzdy = (zy0.isFinite && zy1.isFinite && dy != 0)
            ? (_normZ(zy1) - _normZ(zy0)) / dy
            : 0.0;
        final nLen = math.sqrt(dzdx * dzdx + dzdy * dzdy + 1.0);

        final base = (j * nx + i) * 9;
        verts[base] = x;
        verts[base + 1] = y;
        verts[base + 2] = z;
        verts[base + 3] = -dzdx / nLen;
        verts[base + 4] = -dzdy / nLen;
        verts[base + 5] = 1.0 / nLen;
        verts[base + 6] = c.r / 255.0;
        verts[base + 7] = c.g / 255.0;
        verts[base + 8] = c.b / 255.0;
      }
    }

    final indices = <int>[];
    final wireIndices = <int>[];
    for (var j = 0; j < ny - 1; j++) {
      for (var i = 0; i < nx - 1; i++) {
        final a = j * nx + i;
        final b = a + 1;
        final c = (j + 1) * nx + i;
        final d = c + 1;
        if (ds.zs[a].isFinite &&
            ds.zs[b].isFinite &&
            ds.zs[c].isFinite &&
            ds.zs[d].isFinite) {
          indices.addAll(<int>[a, b, d, a, d, c]);
          if (ds.wireframe) {
            wireIndices.addAll(<int>[a, b, a, c]);
          }
        }
      }
    }

    final vbo = gl.createBuffer();
    final ibo = gl.createBuffer();
    if (vbo == null || ibo == null) return;
    gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, vbo);
    gl.bufferData(
      web.WebGLRenderingContext.ARRAY_BUFFER,
      verts.toJS,
      web.WebGLRenderingContext.STATIC_DRAW,
    );
    final idxArray = Uint32List.fromList(indices);
    gl.bindBuffer(web.WebGLRenderingContext.ELEMENT_ARRAY_BUFFER, ibo);
    gl.bufferData(
      web.WebGLRenderingContext.ELEMENT_ARRAY_BUFFER,
      idxArray.toJS,
      web.WebGLRenderingContext.STATIC_DRAW,
    );

    web.WebGLBuffer? wireIbo;
    if (ds.wireframe && wireIndices.isNotEmpty) {
      wireIbo = gl.createBuffer();
      if (wireIbo != null) {
        gl.bindBuffer(web.WebGLRenderingContext.ELEMENT_ARRAY_BUFFER, wireIbo);
        gl.bufferData(
          web.WebGLRenderingContext.ELEMENT_ARRAY_BUFFER,
          Uint32List.fromList(wireIndices).toJS,
          web.WebGLRenderingContext.STATIC_DRAW,
        );
      }
    }

    _surfaceMeshes[ds.id] = _SurfaceMeshBuffers(
      vbo: vbo,
      ibo: ibo,
      indexCount: idxArray.length,
      wireIbo: wireIbo,
      wireCount: wireIndices.length,
    );
  }

  void _buildParametricBuffers(
    web.WebGL2RenderingContext gl,
    Parametric3DDataset ds,
  ) {
    final n = math.min(ds.xs.length, math.min(ds.ys.length, ds.zs.length));
    if (n < 2) return;
    final rgb = _parseHexColor(ds.color);
    final floats = <double>[];
    for (var i = 0; i < n - 1; i++) {
      final x0 = ds.xs[i];
      final y0 = ds.ys[i];
      final z0 = ds.zs[i];
      final x1 = ds.xs[i + 1];
      final y1 = ds.ys[i + 1];
      final z1 = ds.zs[i + 1];
      if (!x0.isFinite ||
          !y0.isFinite ||
          !z0.isFinite ||
          !x1.isFinite ||
          !y1.isFinite ||
          !z1.isFinite) {
        continue;
      }
      floats.addAll(<double>[
        _normX(x0),
        _normY(y0),
        _normZ(z0),
        rgb.r,
        rgb.g,
        rgb.b,
        _normX(x1),
        _normY(y1),
        _normZ(z1),
        rgb.r,
        rgb.g,
        rgb.b,
      ]);
    }
    if (floats.isEmpty) return;
    final vbo = gl.createBuffer();
    if (vbo == null) return;
    gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, vbo);
    gl.bufferData(
      web.WebGLRenderingContext.ARRAY_BUFFER,
      Float32List.fromList(floats).toJS,
      web.WebGLRenderingContext.STATIC_DRAW,
    );
    _lineBuffers[ds.id] = _LineBuffers(
      vbo: vbo,
      vertexCount: floats.length ~/ 6,
    );
  }

  void _buildVectorFieldBuffers(
    web.WebGL2RenderingContext gl,
    VectorField3DDataset ds,
  ) {
    if (ds.samples.isEmpty) return;
    var maxMag = 0.0;
    for (final s in ds.samples) {
      final m = s.magnitude;
      if (m.isFinite && m > maxMag) maxMag = m;
    }
    if (maxMag <= 0) maxMag = 1.0;

    final floats = <double>[];
    final arrowScale = 0.28 * ds.scale;
    for (final s in ds.samples) {
      final mag = s.magnitude;
      if (!mag.isFinite || mag == 0) continue;
      final t = (mag / maxMag).clamp(0.0, 1.0);
      final c = ds.colormap.sampleRgba(t);
      final r = c.r / 255.0;
      final g = c.g / 255.0;
      final b = c.b / 255.0;

      final px = _normX(s.x);
      final py = _normY(s.y);
      final pz = _normZ(s.z);
      final len = arrowScale * (0.3 + 0.7 * t);
      final ux = s.vx / mag;
      final uy = s.vy / mag;
      final uz = s.vz / mag;
      final tx = px + ux * len;
      final ty = py + uy * len;
      final tz = pz + uz * len;

      floats.addAll(<double>[px, py, pz, r, g, b, tx, ty, tz, r, g, b]);

      // Small perpendicular arrowhead ticks.
      final perpX = uy.abs() < 0.9 ? -uz : 0.0;
      final perpY = uy.abs() < 0.9 ? 0.0 : -uz;
      final perpZ = uy.abs() < 0.9 ? ux : uy;
      final pLen = math.sqrt(perpX * perpX + perpY * perpY + perpZ * perpZ);
      if (pLen > 1e-6) {
        final hx = (perpX / pLen) * len * 0.22;
        final hy = (perpY / pLen) * len * 0.22;
        final hz = (perpZ / pLen) * len * 0.22;
        final bx = tx - ux * len * 0.28;
        final by = ty - uy * len * 0.28;
        final bz = tz - uz * len * 0.28;
        floats.addAll(<double>[
          tx,
          ty,
          tz,
          r,
          g,
          b,
          bx + hx,
          by + hy,
          bz + hz,
          r,
          g,
          b,
          tx,
          ty,
          tz,
          r,
          g,
          b,
          bx - hx,
          by - hy,
          bz - hz,
          r,
          g,
          b,
        ]);
      }
    }

    if (floats.isEmpty) return;
    final vbo = gl.createBuffer();
    if (vbo == null) return;
    gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, vbo);
    gl.bufferData(
      web.WebGLRenderingContext.ARRAY_BUFFER,
      Float32List.fromList(floats).toJS,
      web.WebGLRenderingContext.STATIC_DRAW,
    );
    _lineBuffers[ds.id] = _LineBuffers(
      vbo: vbo,
      vertexCount: floats.length ~/ 6,
    );
  }

  void _renderGl(Float32List mvp) {
    final gl = _gl;
    if (gl == null) return;

    gl.viewport(0, 0, _glCanvas.width, _glCanvas.height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(
      web.WebGLRenderingContext.COLOR_BUFFER_BIT |
          web.WebGLRenderingContext.DEPTH_BUFFER_BIT,
    );
    gl.enable(web.WebGLRenderingContext.DEPTH_TEST);
    gl.depthFunc(web.WebGLRenderingContext.LEQUAL);

    final meshProg = _meshProgram;
    if (meshProg != null) {
      gl.useProgram(meshProg);
      final uMvp = gl.getUniformLocation(meshProg, 'uMvp');
      gl.uniformMatrix4fv(uMvp, false, mvp.toJS);
      final aPos = gl.getAttribLocation(meshProg, 'aPos');
      final aNormal = gl.getAttribLocation(meshProg, 'aNormal');
      final aColor = gl.getAttribLocation(meshProg, 'aColor');

      for (final ds in _scene.datasets) {
        if (!_isVisible(ds) || ds is! Surface3DDataset) continue;
        final mesh = _surfaceMeshes[ds.id];
        if (mesh == null || mesh.indexCount == 0) continue;

        gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, mesh.vbo);
        if (aPos >= 0) {
          gl.enableVertexAttribArray(aPos);
          gl.vertexAttribPointer(
            aPos,
            3,
            web.WebGLRenderingContext.FLOAT,
            false,
            36,
            0,
          );
        }
        if (aNormal >= 0) {
          gl.enableVertexAttribArray(aNormal);
          gl.vertexAttribPointer(
            aNormal,
            3,
            web.WebGLRenderingContext.FLOAT,
            false,
            36,
            12,
          );
        }
        if (aColor >= 0) {
          gl.enableVertexAttribArray(aColor);
          gl.vertexAttribPointer(
            aColor,
            3,
            web.WebGLRenderingContext.FLOAT,
            false,
            36,
            24,
          );
        }
        gl.bindBuffer(web.WebGLRenderingContext.ELEMENT_ARRAY_BUFFER, mesh.ibo);
        gl.drawElements(
          web.WebGLRenderingContext.TRIANGLES,
          mesh.indexCount,
          web.WebGLRenderingContext.UNSIGNED_INT,
          0,
        );
      }
    }

    final lineProg = _lineProgram;
    if (lineProg != null) {
      gl.useProgram(lineProg);
      final uMvp = gl.getUniformLocation(lineProg, 'uMvp');
      gl.uniformMatrix4fv(uMvp, false, mvp.toJS);
      final aPos = gl.getAttribLocation(lineProg, 'aPos');
      final aColor = gl.getAttribLocation(lineProg, 'aColor');

      for (final ds in _scene.datasets) {
        if (!_isVisible(ds)) continue;
        final buf = _lineBuffers[ds.id];
        if (buf == null || buf.vertexCount == 0) continue;

        gl.bindBuffer(web.WebGLRenderingContext.ARRAY_BUFFER, buf.vbo);
        if (aPos >= 0) {
          gl.enableVertexAttribArray(aPos);
          gl.vertexAttribPointer(
            aPos,
            3,
            web.WebGLRenderingContext.FLOAT,
            false,
            24,
            0,
          );
        }
        if (aColor >= 0) {
          gl.enableVertexAttribArray(aColor);
          gl.vertexAttribPointer(
            aColor,
            3,
            web.WebGLRenderingContext.FLOAT,
            false,
            24,
            12,
          );
        }
        gl.drawArrays(web.WebGLRenderingContext.LINES, 0, buf.vertexCount);
      }
    }
  }

  void _renderHud(Float32List mvp) {
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

    // Bounding box wireframe in data-normalized [-1, 1]^3.
    const corners = <(double, double, double)>[
      (-1, -1, -1),
      (1, -1, -1),
      (1, 1, -1),
      (-1, 1, -1),
      (-1, -1, 1),
      (1, -1, 1),
      (1, 1, 1),
      (-1, 1, 1),
    ];
    const edges = <(int, int)>[
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 0),
      (4, 5),
      (5, 6),
      (6, 7),
      (7, 4),
      (0, 4),
      (1, 5),
      (2, 6),
      (3, 7),
    ];

    final projected = corners
        .map((c) => _project(c.$1, c.$2, c.$3, mvp))
        .toList(growable: false);

    ctx.strokeStyle = _theme.gridColor.toJS;
    ctx.lineWidth = 1.0;
    for (final e in edges) {
      final p0 = projected[e.$1];
      final p1 = projected[e.$2];
      if (p0 == null || p1 == null) continue;
      ctx.beginPath();
      ctx.moveTo(p0.x, p0.y);
      ctx.lineTo(p1.x, p1.y);
      ctx.stroke();
    }

    // Highlighted primary X, Y, Z axes along bottom/side edges.
    _drawHudAxis(
      ctx,
      mvp,
      (-1, -1, -1),
      (1, -1, -1),
      '${_scene.xAxis.label}: ${formatGraphNumber(_bounds.xMin)} .. ${formatGraphNumber(_bounds.xMax)}',
    );
    _drawHudAxis(
      ctx,
      mvp,
      (-1, -1, -1),
      (-1, 1, -1),
      '${_scene.yAxis.label}: ${formatGraphNumber(_bounds.yMin)} .. ${formatGraphNumber(_bounds.yMax)}',
    );
    _drawHudAxis(
      ctx,
      mvp,
      (-1, -1, -1),
      (-1, -1, 1),
      '${_scene.zAxis.label}: ${formatGraphNumber(_bounds.zMin)} .. ${formatGraphNumber(_bounds.zMax)}',
    );

    if (_probe != null) {
      final p = _project(
        _normX(_probe!.x),
        _normY(_probe!.y),
        _normZ(_probe!.z),
        mvp,
      );
      if (p != null) {
        ctx.fillStyle = _theme.textColor.toJS;
        ctx.beginPath();
        ctx.arc(p.x, p.y, 4.0, 0, math.pi * 2);
        ctx.fill();
      }
    }

    ctx.restore();
  }

  void _drawHudAxis(
    web.CanvasRenderingContext2D ctx,
    Float32List mvp,
    (double, double, double) start,
    (double, double, double) end,
    String label,
  ) {
    final p0 = _project(start.$1, start.$2, start.$3, mvp);
    final p1 = _project(end.$1, end.$2, end.$3, mvp);
    if (p0 == null || p1 == null) return;
    ctx.strokeStyle = _theme.axisColor.toJS;
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(p0.x, p0.y);
    ctx.lineTo(p1.x, p1.y);
    ctx.stroke();

    final mx = 0.5 * (p0.x + p1.x);
    final my = 0.5 * (p0.y + p1.y);
    ctx.fillStyle = _theme.mutedTextColor.toJS;
    ctx.font = '11px system-ui, -apple-system, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(label, mx, my + 12);
  }

  Float32List _computeMvpMatrix() {
    final aspect = _width / math.max(1, _height);
    final proj = _perspective(0.75, aspect, 0.1, 50.0);

    final cosP = math.cos(_pitch);
    final sinP = math.sin(_pitch);
    final cosY = math.cos(_yaw);
    final sinY = math.sin(_yaw);

    final eyeX = _distance * cosP * cosY;
    final eyeY = _distance * cosP * sinY;
    final eyeZ = _distance * sinP;

    final view = _lookAt(eyeX, eyeY, eyeZ, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
    return _mulMat4(proj, view);
  }

  ({double x, double y})? _project(
    double nx,
    double ny,
    double nz,
    Float32List mvp,
  ) {
    final cx = mvp[0] * nx + mvp[4] * ny + mvp[8] * nz + mvp[12];
    final cy = mvp[1] * nx + mvp[5] * ny + mvp[9] * nz + mvp[13];
    final cw = mvp[3] * nx + mvp[7] * ny + mvp[11] * nz + mvp[15];
    if (cw <= 1e-4) return null;
    final ndcX = cx / cw;
    final ndcY = cy / cw;
    return (x: (ndcX * 0.5 + 0.5) * _width, y: (0.5 - ndcY * 0.5) * _height);
  }

  double _normX(double x) => ((x - _bounds.xMin) / _bounds.xSpan) * 2.0 - 1.0;

  double _normY(double y) => ((y - _bounds.yMin) / _bounds.ySpan) * 2.0 - 1.0;

  double _normZ(double z) => ((z - _bounds.zMin) / _bounds.zSpan) * 2.0 - 1.0;

  void _updateHoverProbe(double offsetX, double offsetY) {
    final mvp = _computeMvpMatrix();
    Probe3D? best;
    var bestD2 = 400.0; // 20px threshold

    for (final ds in _scene.datasets) {
      if (!_isVisible(ds)) continue;
      switch (ds) {
        case Surface3DDataset():
          final stepI = math.max(1, ds.nx ~/ 16);
          final stepJ = math.max(1, ds.ny ~/ 16);
          for (var j = 0; j < ds.ny; j += stepJ) {
            for (var i = 0; i < ds.nx; i += stepI) {
              final z = ds.zs[j * ds.nx + i];
              if (!z.isFinite) continue;
              final p = _project(
                _normX(ds.xs[i]),
                _normY(ds.ys[j]),
                _normZ(z),
                mvp,
              );
              if (p == null) continue;
              final dx = p.x - offsetX;
              final dy = p.y - offsetY;
              final d2 = dx * dx + dy * dy;
              if (d2 < bestD2) {
                bestD2 = d2;
                best = Probe3D(x: ds.xs[i], y: ds.ys[j], z: z);
              }
            }
          }
        case Parametric3DDataset():
          final n = math.min(
            ds.xs.length,
            math.min(ds.ys.length, ds.zs.length),
          );
          final step = math.max(1, n ~/ 64);
          for (var i = 0; i < n; i += step) {
            final x = ds.xs[i];
            final y = ds.ys[i];
            final z = ds.zs[i];
            if (!x.isFinite || !y.isFinite || !z.isFinite) continue;
            final p = _project(_normX(x), _normY(y), _normZ(z), mvp);
            if (p == null) continue;
            final dx = p.x - offsetX;
            final dy = p.y - offsetY;
            final d2 = dx * dx + dy * dy;
            if (d2 < bestD2) {
              bestD2 = d2;
              best = Probe3D(x: x, y: y, z: z);
            }
          }
        case VectorField3DDataset():
          for (final s in ds.samples) {
            final p = _project(_normX(s.x), _normY(s.y), _normZ(s.z), mvp);
            if (p == null) continue;
            final dx = p.x - offsetX;
            final dy = p.y - offsetY;
            final d2 = dx * dx + dy * dy;
            if (d2 < bestD2) {
              bestD2 = d2;
              best = Probe3D(x: s.x, y: s.y, z: s.z);
            }
          }
      }
    }

    if (best != null || _probe != null) {
      _probe = best;
      onProbeChanged?.call(best);
      render();
    }
  }

  void _attachEvents() {
    _onPointerDownJs = ((web.PointerEvent e) {
      _dragging = true;
      _dragStartX = e.offsetX;
      _dragStartY = e.offsetY;
      _dragStartYaw = _yaw;
      _dragStartPitch = _pitch;
      _hudCanvas.setPointerCapture(e.pointerId);
    }).toJS;

    _onPointerMoveJs = ((web.PointerEvent e) {
      if (_dragging) {
        _yaw = _dragStartYaw - (e.offsetX - _dragStartX) * 0.01;
        _pitch = (_dragStartPitch + (e.offsetY - _dragStartY) * 0.01).clamp(
          -1.45,
          1.45,
        );
        render();
        return;
      }
      _updateHoverProbe(e.offsetX, e.offsetY);
    }).toJS;

    _onPointerUpJs = ((web.PointerEvent e) {
      _dragging = false;
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
      final factor = e.deltaY > 0 ? 1.1 : 1.0 / 1.1;
      zoomBy(factor);
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

class _SurfaceMeshBuffers {
  const new({
    required this.vbo,
    required this.ibo,
    required this.indexCount,
    this.wireIbo,
    this.wireCount = 0,
  });

  final web.WebGLBuffer vbo;
  final web.WebGLBuffer ibo;
  final int indexCount;
  final web.WebGLBuffer? wireIbo;
  final int wireCount;
}

class _LineBuffers {
  const new({required this.vbo, required this.vertexCount});

  final web.WebGLBuffer vbo;
  final int vertexCount;
}

({double r, double g, double b}) _parseHexColor(String hex) {
  final clean = hex.startsWith('#') ? hex.substring(1) : hex;
  if (clean.length == 6) {
    final val = int.tryParse(clean, radix: 16);
    if (val != null) {
      return (
        r: ((val >> 16) & 0xff) / 255.0,
        g: ((val >> 8) & 0xff) / 255.0,
        b: (val & 0xff) / 255.0,
      );
    }
  }
  return (r: 0.38, g: 0.65, b: 0.98);
}

Float32List _perspective(double fovY, double aspect, double near, double far) {
  final f = 1.0 / math.tan(fovY * 0.5);
  final nf = 1.0 / (near - far);
  return Float32List.fromList(<double>[
    f / aspect,
    0,
    0,
    0,
    0,
    f,
    0,
    0,
    0,
    0,
    (far + near) * nf,
    -1,
    0,
    0,
    2 * far * near * nf,
    0,
  ]);
}

Float32List _lookAt(
  double ex,
  double ey,
  double ez,
  double cx,
  double cy,
  double cz,
  double ux,
  double uy,
  double uz,
) {
  var zx = ex - cx;
  var zy = ey - cy;
  var zz = ez - cz;
  final zLen = math.sqrt(zx * zx + zy * zy + zz * zz);
  if (zLen > 0) {
    zx /= zLen;
    zy /= zLen;
    zz /= zLen;
  }

  var xx = uy * zz - uz * zy;
  var xy = uz * zx - ux * zz;
  var xz = ux * zy - uy * zx;
  final xLen = math.sqrt(xx * xx + xy * xy + xz * xz);
  if (xLen > 0) {
    xx /= xLen;
    xy /= xLen;
    xz /= xLen;
  }

  final yx = zy * xz - zz * xy;
  final yy = zz * xx - zx * xz;
  final yz = zx * xy - zy * xx;

  return Float32List.fromList(<double>[
    xx,
    yx,
    zx,
    0,
    xy,
    yy,
    zy,
    0,
    xz,
    yz,
    zz,
    0,
    -(xx * ex + xy * ey + xz * ez),
    -(yx * ex + yy * ey + yz * ez),
    -(zx * ex + zy * ey + zz * ez),
    1,
  ]);
}

Float32List _mulMat4(Float32List a, Float32List b) {
  final out = Float32List(16);
  for (var col = 0; col < 4; col++) {
    for (var row = 0; row < 4; row++) {
      out[col * 4 + row] =
          a[row] * b[col * 4] +
          a[4 + row] * b[col * 4 + 1] +
          a[8 + row] * b[col * 4 + 2] +
          a[12 + row] * b[col * 4 + 3];
    }
  }
  return out;
}

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:web/web.dart' as web;

import '../model/style.dart';

/// Shared base class for interactive WebGL2 + Canvas2D HUD graph renderers.
abstract base class GraphRenderer {
  /// Mounts a WebGL2 underlay canvas and Canvas2D HUD canvas inside [container].
  new(this.container, {this.theme = GraphTheme.dark}) {
    glCanvas = web.HTMLCanvasElement()
      ..className = 'graph-canvas-layer graph-gl-layer';
    hudCanvas = web.HTMLCanvasElement()
      ..className = 'graph-canvas-layer graph-hud-layer';
    container.appendChild(glCanvas);
    container.appendChild(hudCanvas);

    gl = glCanvas.getContext('webgl2') as web.WebGL2RenderingContext?;
    hud = hudCanvas.getContext('2d') as web.CanvasRenderingContext2D?;
  }

  /// Host DOM element containing the canvas layers.
  final web.HTMLElement container;

  /// WebGL2 underlay canvas.
  late final web.HTMLCanvasElement glCanvas;

  /// Canvas2D HUD overlay canvas.
  late final web.HTMLCanvasElement hudCanvas;

  /// WebGL2 context, or `null` if unavailable.
  web.WebGL2RenderingContext? gl;

  /// Canvas2D context, or `null` if unavailable.
  web.CanvasRenderingContext2D? hud;

  /// Active visual theme.
  GraphTheme theme;

  /// Per-dataset visibility overrides toggled from the legend.
  final Map<String, bool> visibilityOverrides = <String, bool>{};

  /// Current CSS width in logical pixels.
  int width = 1;

  /// Current CSS height in logical pixels.
  int height = 1;

  /// Current device pixel ratio clamped to `[1, 3]`.
  double dpr = 1.0;

  /// Returns whether a dataset is currently visible.
  bool isDatasetVisible(String id, bool defaultVisible) =>
      visibilityOverrides[id] ?? defaultVisible;

  /// Updates the active theme and triggers a redraw.
  void setTheme(GraphTheme nextTheme) {
    theme = nextTheme;
    onStyleOrVisibilityChanged();
    render();
  }

  /// Overrides visibility for [datasetId] and triggers a redraw.
  void setVisibility(String datasetId, bool visible) {
    visibilityOverrides[datasetId] = visible;
    onStyleOrVisibilityChanged();
    render();
  }

  /// Hook invoked before [render] when theme or visibility changes.
  void onStyleOrVisibilityChanged() {}

  /// Synchronizes backing canvas pixel dimensions to [container].
  ///
  /// Returns `true` if the backing pixel dimensions changed.
  bool syncCanvasSize() {
    final rect = container.getBoundingClientRect();
    final cssW = math.max(1, rect.width.round());
    final cssH = math.max(1, rect.height.round());
    dpr = web.window.devicePixelRatio.clamp(1.0, 3.0);
    width = cssW;
    height = cssH;

    final pxW = (cssW * dpr).round();
    final pxH = (cssH * dpr).round();
    var changed = false;
    if (glCanvas.width != pxW || glCanvas.height != pxH) {
      glCanvas.width = pxW;
      glCanvas.height = pxH;
      changed = true;
    }
    if (hudCanvas.width != pxW || hudCanvas.height != pxH) {
      hudCanvas.width = pxW;
      hudCanvas.height = pxH;
      changed = true;
    }
    return changed;
  }

  /// Composites the WebGL2 underlay and Canvas2D HUD into a PNG data URL.
  String? exportPngDataUrl() {
    final out = web.HTMLCanvasElement()
      ..width = hudCanvas.width
      ..height = hudCanvas.height;
    final ctx = out.getContext('2d') as web.CanvasRenderingContext2D?;
    if (ctx == null) return null;
    ctx.fillStyle = theme.background.toJS;
    ctx.fillRect(0, 0, out.width.toDouble(), out.height.toDouble());
    ctx.drawImage(glCanvas, 0, 0);
    ctx.drawImage(hudCanvas, 0, 0);
    return out.toDataURL('image/png');
  }

  /// Synchronizes layout dimensions and re-renders.
  void resize();

  /// Renders the graph.
  void render();

  /// Resets camera or viewport bounds back to default.
  void resetView();

  /// Zooms the view by [factor] (`< 1` zooms in).
  void zoomBy(double factor);

  /// Releases DOM canvas elements and GPU resources.
  @mustCallSuper
  void dispose() {
    glCanvas.remove();
    hudCanvas.remove();
  }
}

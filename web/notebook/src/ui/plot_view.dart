import 'dart:js_interop';

import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../../../shared/chart.dart';
import '../../../shared/domain_coloring.dart';
import '../../../shared/webgl_chart.dart';
import '../../../shared/webgl_surface.dart';
import '../model/value.dart';
import 'icons.dart';

/// Frameless/hairline interactive plot renderer for 2D, 3D, and complex
/// domain-coloring [PlotValue]s.
final class PlotView {
  new(this.plot) {
    _minX = plot.minX;
    _maxX = plot.maxX;
    _minY = plot.minY;
    _maxY = plot.maxY;
    _buildDom();
    _render();
  }

  final PlotValue plot;
  late final web.HTMLDivElement root;
  late final web.HTMLDivElement _stage;
  late final web.HTMLCanvasElement _canvas;
  WebGLSurfaceRenderer? _surfaceRenderer;

  late double _minX;
  late double _maxX;
  late double _minY;
  late double _maxY;

  double? _hoverX;
  double? _hoverY;
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartY = 0;

  DomainColoringPass? _domainPass;
  int _domainTimer = 0;

  void _buildDom() {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-plot';

    if (plot.title != null && plot.title!.isNotEmpty) {
      final titleEl = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-plot-title'
        ..textContent = plot.title;
      root.append(titleEl);
    }

    _stage = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-plot-stage';

    _canvas = (web.document.createElement('canvas') as web.HTMLCanvasElement)
      ..className = 'nb-plot-canvas';

    final controls = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-plot-controls';

    final resetBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'icon-btn'
          ..title = 'Reset view'
          ..innerHTML = NbIcons.reset.toJS;
    resetBtn.onclick = ((web.MouseEvent _) {
      _minX = plot.minX;
      _maxX = plot.maxX;
      _minY = plot.minY;
      _maxY = plot.maxY;
      _render();
    }).toJS;

    final exportBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'icon-btn'
          ..title = 'Export PNG'
          ..innerHTML = NbIcons.download.toJS;
    exportBtn.onclick = ((web.MouseEvent _) {
      final url = WebGL2ChartLayer.exportPngDataUrl(_canvas);
      final a = (web.document.createElement('a') as web.HTMLAnchorElement)
        ..href = url
        ..download = 'plot.png';
      a.click();
    }).toJS;

    controls
      ..append(resetBtn)
      ..append(exportBtn);

    _stage
      ..append(_canvas)
      ..append(controls);
    root.append(_stage);

    if (plot.curves.isNotEmpty) {
      final legend = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-plot-legend';
      for (var i = 0; i < plot.curves.length; i++) {
        final c = plot.curves[i];
        final color = chartCurvePalette[i % chartCurvePalette.length];
        final item = (web.document.createElement('span') as web.HTMLSpanElement)
          ..className = 'nb-plot-legend-item';
        final swatch =
            (web.document.createElement('span') as web.HTMLSpanElement)
              ..className = 'nb-plot-swatch'
              ..style.backgroundColor = color;
        final label =
            (web.document.createElement('span') as web.HTMLSpanElement)
              ..textContent = c.label;
        item
          ..append(swatch)
          ..append(label);
        legend.append(item);
      }
      root.append(legend);
    }

    if (!plot.is3d) {
      _wire2dInteraction();
    }
  }

  void _wire2dInteraction() {
    _canvas.onmousedown = ((web.MouseEvent e) {
      _isDragging = true;
      _dragStartX = e.offsetX.toDouble();
      _dragStartY = e.offsetY.toDouble();
    }).toJS;

    _canvas.onmousemove = ((web.MouseEvent e) {
      final rect = _canvas.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      final vp = PlotViewport(
        minX: _minX,
        maxX: _maxX,
        minY: _minY,
        maxY: _maxY,
        width: rect.width,
        height: rect.height,
      );
      if (_isDragging) {
        final dx = e.offsetX.toDouble() - _dragStartX;
        final dy = e.offsetY.toDouble() - _dragStartY;
        _dragStartX = e.offsetX.toDouble();
        _dragStartY = e.offsetY.toDouble();
        final spanX = _maxX - _minX;
        final spanY = _maxY - _minY;
        final shiftX = dx * spanX / vp.plotWidth;
        final shiftY = dy * spanY / vp.plotHeight;
        _minX -= shiftX;
        _maxX -= shiftX;
        _minY += shiftY;
        _maxY += shiftY;
        _render();
        return;
      }
      _hoverX = e.offsetX.toDouble();
      _hoverY = e.offsetY.toDouble();
      _render();
    }).toJS;

    _canvas.onmouseup = ((web.MouseEvent _) {
      _isDragging = false;
    }).toJS;

    _canvas.onmouseleave = ((web.MouseEvent _) {
      _isDragging = false;
      _hoverX = null;
      _hoverY = null;
      _render();
    }).toJS;

    _canvas.onwheel = ((web.WheelEvent e) {
      e.preventDefault();
      final rect = _canvas.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return;
      final vp = PlotViewport(
        minX: _minX,
        maxX: _maxX,
        minY: _minY,
        maxY: _maxY,
        width: rect.width,
        height: rect.height,
      );
      final cx = vp.fromPixelX(e.offsetX.toDouble());
      final cy = vp.fromPixelY(e.offsetY.toDouble());
      final factor = e.deltaY > 0 ? 1.15 : 1.0 / 1.15;
      _minX = cx + (_minX - cx) * factor;
      _maxX = cx + (_maxX - cx) * factor;
      _minY = cy + (_minY - cy) * factor;
      _maxY = cy + (_maxY - cy) * factor;
      _render();
    }).toJS;
  }

  /// Re-renders the plot when mounted or resized.
  void render() => _render();

  void _render() {
    if (plot.surface3d case final s3d?) {
      _surfaceRenderer ??= WebGLSurfaceRenderer.forCanvas(
        _canvas,
        onUpdate: _render,
      );
      _surfaceRenderer!.renderSurface(
        gridSize: s3d.gridSize,
        zValues: s3d.zValues,
        phaseValues: s3d.phaseValues,
        minX: s3d.minX,
        maxX: s3d.maxX,
        minY: s3d.minY,
        maxY: s3d.maxY,
        minZ: s3d.minZ,
        maxZ: s3d.maxZ,
        xVar: s3d.xVar,
        yVar: s3d.yVar,
      );
      return;
    }

    if (plot.parametric3d case final p3d?) {
      _surfaceRenderer ??= WebGLSurfaceRenderer.forCanvas(
        _canvas,
        onUpdate: _render,
      );
      _surfaceRenderer!.renderParametricCurve(
        tValues: p3d.tValues,
        xValues: p3d.xValues,
        yValues: p3d.yValues,
        zValues: p3d.zValues,
        minX: p3d.minX,
        maxX: p3d.maxX,
        minY: p3d.minY,
        maxY: p3d.maxY,
        minZ: p3d.minZ,
        maxZ: p3d.maxZ,
        tVar: p3d.tVar,
      );
      return;
    }

    final setup = initCanvas(_canvas);
    if (setup == null) return;
    final (:ctx, :width, :height) = setup;
    final theme = ChartTheme.current();

    final vp = PlotViewport(
      minX: _minX,
      maxX: _maxX,
      minY: _minY,
      maxY: _maxY,
      width: width,
      height: height,
    );

    if (plot.isComplex && plot.expressions.isNotEmpty) {
      _renderComplexDomain(ctx, vp, theme);
      return;
    }

    if (plot.showGrid) {
      drawGrid(ctx, vp, theme: theme);
    }

    for (var i = 0; i < plot.curves.length; i++) {
      final curve = plot.curves[i];
      final color = chartCurvePalette[i % chartCurvePalette.length];
      final segs = [for (final s in curve.segments) (x: s.x, y: s.y)];
      drawSampledSegments(ctx, vp, segs, strokeColor: color, lineWidth: 2.0);
      if (curve.hasImaginary) {
        final imSegs = [
          for (final s in curve.imaginarySegments) (x: s.x, y: s.y),
        ];
        drawSampledSegments(
          ctx,
          vp,
          imSegs,
          strokeColor: color,
          lineWidth: 1.5,
          lineDash: const [4, 4],
        );
      }
      if (plot.showMarkers) {
        for (final m in curve.markers) {
          drawPointMarker(ctx, vp, m.x, m.y, color: color);
        }
      }
    }

    if (_hoverX != null && _hoverY != null) {
      final xVal = vp.fromPixelX(_hoverX!);
      final yVal = vp.fromPixelY(_hoverY!);
      if (xVal >= _minX && xVal <= _maxX && yVal >= _minY && yVal <= _maxY) {
        drawCrosshairAndTooltip(
          ctx,
          vp,
          targetX: xVal,
          targetY: yVal,
          tooltipLines: [
            '${plot.variable} = ${formatRealDigits(xVal, 5)}',
            'y = ${formatRealDigits(yVal, 5)}',
          ],
          color: chartCurvePalette.first,
        );
      }
    }
  }

  void _renderComplexDomain(
    web.CanvasRenderingContext2D ctx,
    PlotViewport vp,
    ChartTheme theme,
  ) {
    final fnC = plot.expressions.first.toComplexFunction1D(plot.variable);
    if (_domainPass == null || !_domainPass!.matches(vp, 0)) {
      final offscreen =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      _domainPass = DomainColoringPass(
        offscreenCanvas: offscreen,
        fn: fnC,
        minX: vp.minX,
        maxX: vp.maxX,
        minY: vp.minY,
        maxY: vp.maxY,
        plotWidth: vp.plotWidth,
        plotHeight: vp.plotHeight,
        paramVersion: 0,
        pixelStep: 2,
      );
    }
    final done = _domainPass!.renderChunk(budgetMs: 12);
    _domainPass!.drawOnto(ctx, vp);
    drawGrid(ctx, vp, theme: theme);
    if (!done) {
      if (_domainTimer != 0) web.window.cancelAnimationFrame(_domainTimer);
      _domainTimer = web.window.requestAnimationFrame(
        ((num _) {
          _domainTimer = 0;
          _render();
        }).toJS,
      );
    }
  }

  /// Disposes any pending animation frames when the plot is removed.
  void dispose() {
    if (_domainTimer != 0) {
      web.window.cancelAnimationFrame(_domainTimer);
      _domainTimer = 0;
    }
  }
}

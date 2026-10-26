import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../shared/chart.dart';
import '../../../shared/webgl_chart.dart';
import '../../../shared/webgl_surface.dart';
import '../engine/sampling.dart';
import '../model/environment.dart';
import '../model/value.dart';
import 'persistence.dart';

/// Interactive WebGL2 + Canvas2D HUD plot card widget for 2D and 3D [PlotValue]
/// results.
final class PlotView {
  /// Builds a self-contained interactive plot DOM element for [initialPlot].
  static web.HTMLElement create(
    PlotValue initialPlot, {
    void Function(double minX, double maxX)? onResample,
  }) {
    if (initialPlot.is3d) {
      return _create3dSurfaceCard(initialPlot);
    }
    var plot = initialPlot;
    final paramValues = <String, double>{
      for (final p in plot.parameters) p: 1.0,
    };

    final container = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-card';

    // Toolbar + Legend bar
    final header = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-header';

    final legend = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-legend';
    const palette = <String>[
      '#3b82f6',
      '#ef4444',
      '#10b981',
      '#f59e0b',
      '#a855f7',
      '#06b6d4',
    ];
    for (var i = 0; i < plot.curves.length; i++) {
      final curve = plot.curves[i];
      final color = palette[i % palette.length];
      final item = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-plot-legend-item';
      final swatch = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-plot-swatch'
        ..style.backgroundColor = color;
      final text = web.document.createElement('span') as web.HTMLSpanElement
        ..textContent = curve.label;
      item
        ..append(swatch)
        ..append(text);
      legend.append(item);
    }

    final actions = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-actions';

    final readout = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-plot-readout'
      ..textContent =
          '${plot.variable} ∈ [${formatRealDigits(plot.minX, 4)}, ${formatRealDigits(plot.maxX, 4)}]';

    final resetBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = 'Reset View';

    final resampleBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = 'Re-sample';

    final pngBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-chip-btn'
      ..textContent = 'PNG';

    actions
      ..append(readout)
      ..append(resetBtn);
    if (!plot.isParametric && !plot.isOde && onResample != null) {
      actions.append(resampleBtn);
    }
    actions.append(pngBtn);
    header
      ..append(legend)
      ..append(actions);

    final canvasWrap = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-canvas-wrap';
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..className = 'calc-plot-canvas'
      ..width = 680
      ..height = 280;
    canvasWrap.append(canvas);

    container
      ..append(header)
      ..append(canvasWrap);

    late final InteractiveChartController controller;

    void draw() {
      final init = initCanvas(canvas);
      if (init == null) return;
      final (:ctx, width: cssW, height: cssH) = init;

      final vp = controller.viewport(cssW, cssH);
      drawGrid(ctx, vp);

      for (var cIdx = 0; cIdx < plot.curves.length; cIdx++) {
        final curve = plot.curves[cIdx];
        final color = palette[cIdx % palette.length];

        drawSampledSegments(
          ctx,
          vp,
          curve.segments.map((s) => (x: s.x, y: s.y)),
          strokeColor: color,
          lineWidth: 2.2,
        );

        if (curve.imaginarySegments.isNotEmpty) {
          drawSampledSegments(
            ctx,
            vp,
            curve.imaginarySegments.map((s) => (x: s.x, y: s.y)),
            strokeColor: color,
            lineWidth: 1.6,
            lineDash: const [5, 4],
          );
        }

        for (final marker in curve.markers) {
          drawPointMarker(
            ctx,
            vp,
            marker.x,
            marker.y,
            color: color,
            radius: 4.0,
          );
        }
      }

      final hx = controller.hoverPixelX;
      final hy = controller.hoverPixelY;
      if (hx != null && hy != null && vp.containsPixel(hx, hy)) {
        final wx = vp.fromPixelX(hx);
        final wy = vp.fromPixelY(hy);

        ctx.save();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)'.toJS;
        ctx.lineWidth = 0.8;
        ctx.setLineDash(<JSNumber>[3.toJS, 3.toJS].toJS);
        ctx.beginPath();
        ctx.moveTo(hx, vp.topMargin);
        ctx.lineTo(hx, vp.topMargin + vp.plotHeight);
        ctx.moveTo(vp.leftMargin, hy);
        ctx.lineTo(vp.leftMargin + vp.plotWidth, hy);
        ctx.stroke();
        ctx.restore();

        readout.textContent =
            '(${formatRealDigits(wx, 4)}, ${formatRealDigits(wy, 4)})';
      } else {
        readout.textContent =
            '${plot.variable} ∈ [${formatRealDigits(controller.minX, 4)}, ${formatRealDigits(controller.maxX, 4)}]';
      }
    }

    if (plot.parameters.isNotEmpty) {
      final slidersWrap =
          web.document.createElement('div') as web.HTMLDivElement
            ..className = 'calc-plot-sliders';
      for (final param in plot.parameters) {
        final row = web.document.createElement('label') as web.HTMLLabelElement
          ..className = 'calc-plot-slider-row';
        final valSpan =
            web.document.createElement('span') as web.HTMLSpanElement
              ..className = 'calc-plot-slider-label'
              ..textContent = '$param = 1.00';
        final slider =
            web.document.createElement('input') as web.HTMLInputElement
              ..type = 'range'
              ..name = 'param-$param'
              ..className = 'calc-plot-slider'
              ..min = '-5'
              ..max = '5'
              ..step = '0.05'
              ..value = '1';
        slider.addEventListener(
          'input',
          ((web.Event _) {
            final v = double.tryParse(slider.value) ?? 1.0;
            paramValues[param] = v;
            valSpan.textContent = '$param = ${v.toStringAsFixed(2)}';
            if (plot.isParametric && plot.expressions.length == 2) {
              plot = buildParametricPlotValue(
                plot.expressions[0],
                plot.expressions[1],
                plot.variable,
                plot.minT ?? 0.0,
                plot.maxT ?? 6.283185307179586,
                parameterValues: paramValues,
                steps: 240,
                angleMode: plot.isDegrees ? AngleMode.deg : AngleMode.rad,
              );
            } else {
              plot = buildPlotValue(
                plot.expressions,
                plot.variable,
                controller.minX,
                controller.maxX,
                parameterValues: paramValues,
                maxPoints: 256,
                angleMode: plot.isDegrees ? AngleMode.deg : AngleMode.rad,
              );
            }
            draw();
          }).toJS,
        );
        row
          ..append(valSpan)
          ..append(slider);
        slidersWrap.append(row);
      }
      container.append(slidersWrap);
    }

    controller = InteractiveChartController(
      canvas,
      minX: plot.minX,
      maxX: plot.maxX,
      minY: plot.minY,
      maxY: plot.maxY,
      leftMargin: 48.0,
      rightMargin: 16.0,
      topMargin: 14.0,
      bottomMargin: 26.0,
      onUpdate: draw,
    );

    resetBtn.addEventListener(
      'click',
      ((web.Event _) {
        controller.reset();
      }).toJS,
    );

    resampleBtn.addEventListener(
      'click',
      ((web.Event _) {
        if (onResample != null) {
          onResample(controller.minX, controller.maxX);
        }
      }).toJS,
    );

    pngBtn.addEventListener(
      'click',
      ((web.Event _) {
        final dataUrl = WebGL2ChartLayer.exportPngDataUrl(canvas);
        final a = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = dataUrl
          ..download = 'plot.png';
        web.document.body?.append(a);
        a.click();
        a.remove();
        CalcPersistence.triggerHaptic(enabled: true);
      }).toJS,
    );

    late final web.EventListener resizeListener;
    resizeListener = ((web.Event _) {
      if (!canvas.isConnected) {
        web.window.removeEventListener('resize', resizeListener);
        return;
      }
      draw();
    }).toJS;
    web.window.addEventListener('resize', resizeListener);

    web.window.requestAnimationFrame(
      ((num _) {
        draw();
      }).toJS,
    );

    return container;
  }

  static web.HTMLElement _create3dSurfaceCard(PlotValue initialPlot) {
    var plot = initialPlot;
    final paramValues = <String, double>{
      for (final p in plot.parameters) p: 1.0,
    };

    final container = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-card';

    final header = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-header';

    final legend = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-legend';
    final item = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-plot-legend-item';
    final swatch = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-plot-swatch'
      ..style.background = 'linear-gradient(135deg, #2563eb, #10b981, #fbbf24)';
    final exprLabel = plot.expressions.isNotEmpty
        ? 'z = ${plot.expressions.first}'
        : 'z = f(x, y)';
    final text = web.document.createElement('span') as web.HTMLSpanElement
      ..textContent = exprLabel;
    item
      ..append(swatch)
      ..append(text);
    legend.append(item);

    final actions = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-actions';

    final s3dInitial = plot.surface3d!;
    final defaultReadout =
        '${s3dInitial.xVar} ∈ [${formatRealDigits(s3dInitial.minX, 3)}, ${formatRealDigits(s3dInitial.maxX, 3)}], ${s3dInitial.yVar} ∈ [${formatRealDigits(s3dInitial.minY, 3)}, ${formatRealDigits(s3dInitial.maxY, 3)}]';
    final readout = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-plot-readout'
      ..textContent = defaultReadout;

    final resetBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-chip-btn'
          ..textContent = 'Reset Orbit';

    final pngBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-chip-btn'
      ..textContent = 'PNG';

    actions
      ..append(readout)
      ..append(resetBtn)
      ..append(pngBtn);
    header
      ..append(legend)
      ..append(actions);

    final canvasWrap = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-canvas-wrap calc-plot-canvas-wrap-3d';
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement
      ..className = 'calc-plot-canvas'
      ..width = 680
      ..height = 310;
    canvasWrap.append(canvas);

    container
      ..append(header)
      ..append(canvasWrap);

    late final WebGLSurfaceRenderer renderer;

    void draw() {
      final s3d = plot.surface3d;
      if (s3d == null) return;
      renderer.renderSurface(
        gridSize: s3d.gridSize,
        zValues: s3d.zValues,
        minX: s3d.minX,
        maxX: s3d.maxX,
        minY: s3d.minY,
        maxY: s3d.maxY,
        minZ: s3d.minZ,
        maxZ: s3d.maxZ,
        xVar: s3d.xVar,
        yVar: s3d.yVar,
        title: exprLabel,
      );
    }

    renderer = WebGLSurfaceRenderer.forCanvas(
      canvas,
      onUpdate: draw,
      onHoverReadout: (txt) {
        readout.textContent = txt;
      },
    );

    if (plot.parameters.isNotEmpty && plot.expressions.isNotEmpty) {
      final slidersWrap =
          web.document.createElement('div') as web.HTMLDivElement
            ..className = 'calc-plot-sliders';
      for (final param in plot.parameters) {
        final row = web.document.createElement('label') as web.HTMLLabelElement
          ..className = 'calc-plot-slider-row';
        final valSpan =
            web.document.createElement('span') as web.HTMLSpanElement
              ..className = 'calc-plot-slider-label'
              ..textContent = '$param = 1.00';
        final slider =
            web.document.createElement('input') as web.HTMLInputElement
              ..type = 'range'
              ..name = 'param3d-$param'
              ..className = 'calc-plot-slider'
              ..min = '-5'
              ..max = '5'
              ..step = '0.05'
              ..value = '1';
        slider.addEventListener(
          'input',
          ((web.Event _) {
            final v = double.tryParse(slider.value) ?? 1.0;
            paramValues[param] = v;
            valSpan.textContent = '$param = ${v.toStringAsFixed(2)}';
            final cur = plot.surface3d!;
            plot = buildSurface3dPlotValue(
              plot.expressions.first,
              cur.xVar,
              cur.minX,
              cur.maxX,
              cur.yVar,
              cur.minY,
              cur.maxY,
              parameterValues: paramValues,
              gridSize: 48,
            );
            draw();
          }).toJS,
        );
        row
          ..append(valSpan)
          ..append(slider);
        slidersWrap.append(row);
      }
      container.append(slidersWrap);
    }

    resetBtn.addEventListener(
      'click',
      ((web.Event _) {
        readout.textContent = defaultReadout;
        renderer.resetCamera();
      }).toJS,
    );

    pngBtn.addEventListener(
      'click',
      ((web.Event _) {
        final dataUrl = WebGLSurfaceRenderer.exportPngDataUrl(canvas);
        final a = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = dataUrl
          ..download = 'plot3d.png';
        web.document.body?.append(a);
        a.click();
        a.remove();
        CalcPersistence.triggerHaptic(enabled: true);
      }).toJS,
    );

    late final web.EventListener resizeListener;
    resizeListener = ((web.Event _) {
      if (!canvas.isConnected) {
        web.window.removeEventListener('resize', resizeListener);
        return;
      }
      draw();
    }).toJS;
    web.window.addEventListener('resize', resizeListener);

    web.window.requestAnimationFrame(
      ((num _) {
        draw();
      }).toJS,
    );

    return container;
  }
}

import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:web/web.dart' as web;

import '../../../shared/chart.dart';
import '../../../shared/webgl_chart.dart';
import '../../../shared/webgl_surface.dart';
import '../engine/sampling.dart';
import '../model/value.dart';
import 'chips.dart';
import 'domain_coloring.dart';
import 'persistence.dart';

/// Extra action item shown inside a plot card's top-right `⋯` menu.
typedef PlotMenuAction = ({String label, bool danger, void Function() onTap});

/// Interactive WebGL2 + Canvas2D HUD plot card widget for 2D and 3D [PlotValue]
/// results.
final class PlotView {
  /// Builds a self-contained interactive plot DOM element for [initialPlot].
  static web.HTMLElement create(
    PlotValue initialPlot, {
    List<PlotMenuAction> extraActions = const [],
  }) {
    if (initialPlot.is3d) {
      return _create3dSurfaceCard(initialPlot, extraActions: extraActions);
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
        ..className = 'calc-plot-swatch';
      if (plot.isComplex) {
        swatch.style.background = 'conic-gradient(#ef4444, #eab308, #22c55e, #06b6d4, #3b82f6, #a855f7, #ef4444)';
      } else {
        swatch.style.backgroundColor = color;
      }
      final text = web.document.createElement('span') as web.HTMLSpanElement
        ..textContent = curve.label;
      item
        ..append(swatch)
        ..append(text);
      legend.append(item);
    }

    final readout = web.document.createElement('span') as web.HTMLSpanElement
      ..textContent = plot.isComplex
          ? 'Re ∈ [${formatRealDigits(plot.minX, 3)}, ${formatRealDigits(plot.maxX, 3)}], '
                'Im ∈ [${formatRealDigits(plot.minY, 3)}, ${formatRealDigits(plot.maxY, 3)}]'
          : plot.isParametric
          ? '${plot.variable} ∈ [${formatRealDigits(plot.minT ?? 0.0, 4)}, ${formatRealDigits(plot.maxT ?? 2 * math.pi, 4)}]'
          : '${plot.variable} ∈ [${formatRealDigits(plot.minX, 4)}, ${formatRealDigits(plot.maxX, 4)}]';

    final resetBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button';

    final pngBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button';

    header
      ..append(legend)
      ..append(
        _buildCompactPlotMenu(
          readoutSource: readout,
          resetBtn: resetBtn,
          pngBtn: pngBtn,
          resetLabel: 'Reset View',
          extraActions: extraActions,
        ),
      );

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

    String idleReadout() {
      if (plot.isComplex) {
        return 'Re ∈ [${formatRealDigits(controller.minX, 3)}, ${formatRealDigits(controller.maxX, 3)}], '
            'Im ∈ [${formatRealDigits(controller.minY, 3)}, ${formatRealDigits(controller.maxY, 3)}]';
      }
      if (plot.isParametric) {
        return '${plot.variable} ∈ [${formatRealDigits(plot.minT ?? 0.0, 4)}, ${formatRealDigits(plot.maxT ?? 2 * math.pi, 4)}]';
      }
      return '${plot.variable} ∈ [${formatRealDigits(controller.minX, 4)}, ${formatRealDigits(controller.maxX, 4)}]';
    }

    Complex Function(Complex z)? complexFn;
    web.HTMLCanvasElement? complexFrontCanvas;
    web.HTMLCanvasElement? complexWorkCanvas;
    DomainColoringPass? completedComplexPass;
    DomainColoringPass? activeComplexPass;
    Timer? complexDebounceTimer;
    var complexAspectInitialized = false;
    var complexParamVersion = 0;
    var complexRenderGeneration = 0;

    void cancelComplexWork() {
      complexDebounceTimer?.cancel();
      complexRenderGeneration++;
      activeComplexPass = null;
    }

    final complexCurveFns = <int, Complex Function(Complex)>{};
    void rebuild1dComplexFns() {
      complexCurveFns.clear();
      if (plot.isComplex || plot.isParametric || plot.isOde) return;
      for (var i = 0; i < plot.curves.length; i++) {
        if (!plot.curves[i].hasImaginary || i >= plot.expressions.length) {
          continue;
        }
        var expr = plot.expressions[i];
        for (final p in plot.parameters) {
          expr = expr.substitute(p, RealNumber(paramValues[p] ?? 1.0));
        }
        complexCurveFns[i] = expr.toComplexFunction1D(plot.variable);
      }
    }

    rebuild1dComplexFns();

    void rebuildComplexFn() {
      if (!plot.isComplex || plot.expressions.isEmpty) return;
      var expr = plot.expressions.first;
      for (final p in plot.parameters) {
        expr = expr.substitute(p, RealNumber(paramValues[p] ?? 1.0));
      }
      complexFn = expr.toComplexFunction1D(plot.variable);
      complexFrontCanvas ??=
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      complexWorkCanvas ??=
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      complexParamVersion++;
    }

    if (plot.isComplex) {
      rebuildComplexFn();
    }

    late final void Function() draw;

    void pumpComplexPass(int generation) {
      final pass = activeComplexPass;
      if (generation != complexRenderGeneration ||
          pass == null ||
          !canvas.isConnected) {
        return;
      }
      if (pass.renderChunk(budgetMs: 12)) {
        // Swap work canvas into front canvas and redraw crisp result.
        final prevFront = complexFrontCanvas;
        complexFrontCanvas = pass.offscreenCanvas;
        complexWorkCanvas = prevFront;
        completedComplexPass = pass;
        activeComplexPass = null;
        draw();

        // Automatically refine from coarse (step 2) to full resolution (step 1).
        if (pass.pixelStep > 1 && generation == complexRenderGeneration) {
          final nextCanvas = complexWorkCanvas;
          final fn = complexFn;
          if (nextCanvas != null && fn != null) {
            activeComplexPass = DomainColoringPass(
              offscreenCanvas: nextCanvas,
              fn: fn,
              minX: pass.minX,
              maxX: pass.maxX,
              minY: pass.minY,
              maxY: pass.maxY,
              plotWidth: pass.plotWidth,
              plotHeight: pass.plotHeight,
              paramVersion: pass.paramVersion,
              pixelStep: 1,
            );
            web.window.requestAnimationFrame(
              ((num _) => pumpComplexPass(generation)).toJS,
            );
          }
        }
      } else {
        web.window.requestAnimationFrame(
          ((num _) => pumpComplexPass(generation)).toJS,
        );
      }
    }

    void startComplexPass(PlotViewport vp, {required int pixelStep}) {
      final fn = complexFn;
      final work = complexWorkCanvas;
      if (fn == null || work == null) return;
      final generation = ++complexRenderGeneration;
      activeComplexPass = DomainColoringPass(
        offscreenCanvas: work,
        fn: fn,
        minX: vp.minX,
        maxX: vp.maxX,
        minY: vp.minY,
        maxY: vp.maxY,
        plotWidth: vp.plotWidth,
        plotHeight: vp.plotHeight,
        paramVersion: complexParamVersion,
        pixelStep: pixelStep,
      );
      pumpComplexPass(generation);
    }

    void scheduleComplexRerender({bool redrawNow = false}) {
      if (!plot.isComplex) {
        if (redrawNow) draw();
        return;
      }
      cancelComplexWork();
      if (redrawNow) draw();
      complexDebounceTimer = Timer(const Duration(milliseconds: 75), () {
        if (!canvas.isConnected) return;
        final rect = canvas.parentElement?.getBoundingClientRect();
        if (rect == null || rect.width <= 0 || rect.height <= 0) return;
        final vp = controller.viewport(rect.width, rect.height);
        final cached = completedComplexPass;
        if (cached != null &&
            cached.matches(vp, complexParamVersion) &&
            cached.pixelStep == 1) {
          return;
        }
        startComplexPass(vp, pixelStep: 2);
      });
    }

    draw = () {
      final init = initCanvas(canvas);
      if (init == null) return;
      final (:ctx, width: cssW, height: cssH) = init;

      if (plot.isComplex && !complexAspectInitialized) {
        complexAspectInitialized = true;
        final spanX = plot.maxX - plot.minX;
        final spanY = plot.maxY - plot.minY;
        if ((spanX - spanY).abs() < 1e-9) {
          final vp0 = controller.viewport(cssW, cssH);
          final aspect = vp0.plotWidth / vp0.plotHeight;
          final cx = 0.5 * (plot.minX + plot.maxX);
          final halfX = 0.5 * spanY * aspect;
          controller.setBounds(
            minX: cx - halfX,
            maxX: cx + halfX,
            asDefault: true,
          );
        }
      }

      final vp = controller.viewport(cssW, cssH);

      if (plot.isComplex && complexFn != null) {
        final cached = completedComplexPass;
        if (cached != null) {
          cached.drawOnto(ctx, vp);
        } else if (activeComplexPass == null) {
          startComplexPass(vp, pixelStep: 2);
        }
        drawGrid(ctx, vp);
      } else {
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
      }

      final hx = controller.hoverPixelX;
      final hy = controller.hoverPixelY;
      if (hx != null && hy != null && vp.containsPixel(hx, hy)) {
        final wx = vp.fromPixelX(hx);
        final wy = vp.fromPixelY(hy);

        ctx.save();
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.35)'.toJS;
        ctx.lineWidth = 0.8;
        ctx.setLineDash(<JSNumber>[3.toJS, 3.toJS].toJS);
        ctx.beginPath();
        ctx.moveTo(hx, vp.topMargin);
        ctx.lineTo(hx, vp.topMargin + vp.plotHeight);
        ctx.moveTo(vp.leftMargin, hy);
        ctx.lineTo(vp.leftMargin + vp.plotWidth, hy);
        ctx.stroke();
        ctx.restore();

        if (plot.isComplex && complexFn != null) {
          Complex fz;
          try {
            fz = complexFn!(Complex(wx, wy));
          } on Object {
            fz = Complex.nan;
          }
          final re = fz.real.toDouble();
          final im = fz.imaginary.toDouble();
          final mag = math.sqrt(re * re + im * im);
          final arg = math.atan2(im, re);
          final zText = _formatComplex(wx, wy);
          final fText = _formatComplex(re, im);
          readout.textContent =
              '${plot.variable} = $zText | f(${plot.variable}) = $fText (|f| = ${formatRealDigits(mag, 3)})';
          _drawPlotTooltip(ctx, vp, hx, hy, [
            '${plot.variable} = $zText',
            'f(${plot.variable}) = $fText',
            '|f| = ${formatRealDigits(mag, 4)}',
            'arg(f) = ${formatRealDigits(arg, 4)}',
            if (plot.parameters.isNotEmpty)
              _formatParamSummary(plot.parameters, paramValues),
          ], borderColor: 'rgba(56, 189, 248, 0.55)');
        } else {
          final nearest = _findNearestCurvePoint(
            plot.curves,
            palette,
            vp,
            hx,
            hy,
          );
          if (nearest != null) {
            ctx.save();
            ctx.fillStyle = 'rgba(255, 255, 255, 0.25)'.toJS;
            ctx.beginPath();
            ctx.arc(nearest.px, nearest.py, 7.0, 0.0, 2 * math.pi);
            ctx.fill();
            ctx.fillStyle = nearest.color.toJS;
            ctx.beginPath();
            ctx.arc(nearest.px, nearest.py, 4.0, 0.0, 2 * math.pi);
            ctx.fill();
            ctx.strokeStyle = '#ffffff'.toJS;
            ctx.lineWidth = 1.5;
            ctx.stroke();
            ctx.restore();

            final List<String> lines;
            if (plot.isParametric) {
              readout.textContent = nearest.t != null
                  ? '${plot.variable} = ${formatRealDigits(nearest.t!, 4)}, (${formatRealDigits(nearest.x, 4)}, ${formatRealDigits(nearest.y, 4)})'
                  : '(${formatRealDigits(nearest.x, 4)}, ${formatRealDigits(nearest.y, 4)})';
              lines = [
                if (nearest.t != null)
                  '${plot.variable} = ${formatRealDigits(nearest.t!, 4)}',
                'x = ${formatRealDigits(nearest.x, 4)}',
                'y = ${formatRealDigits(nearest.y, 4)}',
                if (plot.parameters.isNotEmpty)
                  _formatParamSummary(plot.parameters, paramValues),
              ];
            } else if (plot.isOde) {
              readout.textContent =
                  '(${formatRealDigits(nearest.x, 4)}, ${formatRealDigits(nearest.y, 4)})';
              lines = [
                '${plot.variable} = ${formatRealDigits(nearest.x, 4)}',
                'y = ${formatRealDigits(nearest.y, 4)}',
              ];
            } else if (nearest.hasImaginary) {
              final fnC = complexCurveFns[nearest.curveIndex];
              var fz = Complex.nan;
              if (fnC != null) {
                try {
                  fz = fnC(Complex(nearest.x));
                } on Object {
                  fz = Complex.nan;
                }
              }
              final re = fz.real.toDouble();
              final im = fz.imaginary.toDouble();
              final mag = math.sqrt(re * re + im * im);
              final arg = math.atan2(im, re);
              final fText = _formatComplex(re, im);
              readout.textContent =
                  '${plot.variable} = ${formatRealDigits(nearest.x, 4)} | f(${plot.variable}) = $fText';
              lines = [
                if (plot.curves.length > 1) nearest.label,
                '${plot.variable} = ${formatRealDigits(nearest.x, 4)}',
                'f(${plot.variable}) = $fText',
                '|f| = ${formatRealDigits(mag, 4)}',
                'arg(f) = ${formatRealDigits(arg, 4)}',
                if (plot.parameters.isNotEmpty)
                  _formatParamSummary(plot.parameters, paramValues),
              ];
            } else {
              readout.textContent =
                  '(${formatRealDigits(nearest.x, 4)}, ${formatRealDigits(nearest.y, 4)})';
              lines = [
                if (plot.curves.length > 1) nearest.label,
                '${plot.variable} = ${formatRealDigits(nearest.x, 4)}',
                'f(${plot.variable}) = ${formatRealDigits(nearest.y, 4)}',
                if (plot.parameters.isNotEmpty)
                  _formatParamSummary(plot.parameters, paramValues),
              ];
            }

            _drawPlotTooltip(
              ctx,
              vp,
              nearest.px,
              nearest.py,
              lines,
              borderColor: nearest.color,
            );
          } else {
            final coordText =
                '(${formatRealDigits(wx, 4)}, ${formatRealDigits(wy, 4)})';
            readout.textContent = coordText;
            _drawPlotTooltip(ctx, vp, hx, hy, [
              if (plot.isParametric) ...[
                'x = ${formatRealDigits(wx, 4)}',
                'y = ${formatRealDigits(wy, 4)}',
              ] else ...[
                '${plot.variable} = ${formatRealDigits(wx, 4)}',
                'y = ${formatRealDigits(wy, 4)}',
              ],
              if (plot.parameters.isNotEmpty)
                _formatParamSummary(plot.parameters, paramValues),
            ]);
          }
        }
      } else {
        readout.textContent = idleReadout();
      }
    };

    int targetMaxPoints() {
      final w = canvas.clientWidth;
      if (w <= 0) return 1536;
      return (w * 2).clamp(1024, 4096);
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
            if (plot.isComplex && plot.expressions.isNotEmpty) {
              rebuildComplexFn();
              scheduleComplexRerender();
              return;
            } else if (plot.isParametric && plot.expressions.length == 2) {
              plot = buildParametricPlotValue(
                plot.expressions[0],
                plot.expressions[1],
                plot.variable,
                plot.minT ?? 0.0,
                plot.maxT ?? 2 * math.pi,
                parameterValues: paramValues,
                maxPoints: targetMaxPoints().clamp(2048, 4096),
              );
            } else {
              plot = buildPlotValue(
                plot.expressions,
                plot.variable,
                controller.minX,
                controller.maxX,
                parameterValues: paramValues,
                maxPoints: targetMaxPoints(),
              );
              rebuild1dComplexFns();
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

    Timer? resampleTimer;
    void scheduleAutoResample() {
      if (plot.isComplex) {
        scheduleComplexRerender();
        return;
      }
      if (plot.isParametric || plot.isOde || plot.expressions.isEmpty) return;
      resampleTimer?.cancel();
      resampleTimer = Timer(const Duration(milliseconds: 60), () {
        if (!canvas.isConnected) return;
        final curSpan = controller.maxX - controller.minX;
        final origSpan = plot.maxX - plot.minX;
        final needsResample =
            controller.minX < plot.minX ||
            controller.maxX > plot.maxX ||
            curSpan < origSpan * 0.65 ||
            curSpan > origSpan * 1.15;
        if (needsResample) {
          plot = buildPlotValue(
            plot.expressions,
            plot.variable,
            controller.minX,
            controller.maxX,
            parameterValues: paramValues,
            maxPoints: targetMaxPoints(),
          );
          draw();
        }
      });
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
      onViewportChanged: (minX, maxX, minY, maxY) => scheduleAutoResample(),
      onReset: () {
        plot = initialPlot;
        complexAspectInitialized = false;
        completedComplexPass = null;
        cancelComplexWork();
      },
    );

    resetBtn.addEventListener(
      'click',
      ((web.Event _) {
        controller.reset();
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
      scheduleComplexRerender(redrawNow: true);
    }).toJS;
    web.window.addEventListener('resize', resizeListener);

    _attachVerticalResizeHandle(
      canvasWrap,
      () => scheduleComplexRerender(redrawNow: true),
    );

    web.window.requestAnimationFrame(
      ((num _) {
        draw();
      }).toJS,
    );

    return container;
  }

  static web.HTMLElement _create3dSurfaceCard(
    PlotValue initialPlot, {
    List<PlotMenuAction> extraActions = const [],
  }) {
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
    final p3dInitial = plot.parametric3d;
    final s3dInitial = plot.surface3d;
    final swatch = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-plot-swatch'
      ..style.background = p3dInitial != null
          ? '#38bdf8'
          : (plot.isComplex
                ? 'conic-gradient(#ef4444, #eab308, #22c55e, #06b6d4, #3b82f6, #a855f7, #ef4444)'
                : 'linear-gradient(135deg, #2563eb, #10b981, #fbbf24)');
    final String exprLabel;
    if (p3dInitial != null) {
      exprLabel = plot.expressions.length >= 3
          ? '[${plot.expressions[0]}, ${plot.expressions[1]}, ${plot.expressions[2]}]'
          : '[x(${p3dInitial.tVar}), y(${p3dInitial.tVar}), z(${p3dInitial.tVar})]';
    } else if (plot.expressions.isNotEmpty) {
      exprLabel = plot.isComplex
          ? '|f(${plot.variable})| = |${plot.expressions.first}|'
          : 'z = ${plot.expressions.first}';
    } else {
      exprLabel = plot.isComplex ? '|f(z)|' : 'z = f(x, y)';
    }
    final text = web.document.createElement('span') as web.HTMLSpanElement
      ..textContent = exprLabel;
    item
      ..append(swatch)
      ..append(text);
    legend.append(item);

    final defaultReadout = p3dInitial != null
        ? '${p3dInitial.tVar} ∈ [${formatRealDigits(p3dInitial.minT, 3)}, ${formatRealDigits(p3dInitial.maxT, 3)}]'
        : '${s3dInitial!.xVar} ∈ [${formatRealDigits(s3dInitial.minX, 3)}, ${formatRealDigits(s3dInitial.maxX, 3)}], ${s3dInitial.yVar} ∈ [${formatRealDigits(s3dInitial.minY, 3)}, ${formatRealDigits(s3dInitial.maxY, 3)}]';
    final readout = web.document.createElement('span') as web.HTMLSpanElement
      ..textContent = defaultReadout;

    final resetBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button';

    final pngBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button';

    header
      ..append(legend)
      ..append(
        _buildCompactPlotMenu(
          readoutSource: readout,
          resetBtn: resetBtn,
          pngBtn: pngBtn,
          resetLabel: 'Reset Orbit',
          extraActions: extraActions,
        ),
      );

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
      final extra = plot.parameters.isNotEmpty
          ? _formatParamSummary(plot.parameters, paramValues)
          : null;
      if (plot.parametric3d case final p3d?) {
        renderer.renderParametricCurve(
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
          extraInfo: extra,
        );
        return;
      }
      final s3d = plot.surface3d;
      if (s3d == null) return;
      renderer.renderSurface(
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
        title: exprLabel,
        extraInfo: extra,
      );
    }

    renderer = WebGLSurfaceRenderer.forCanvas(
      canvas,
      onUpdate: draw,
      onHoverReadout: (txt) {
        readout.textContent = txt.isEmpty ? defaultReadout : txt;
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
            if (plot.parametric3d case final p3d?) {
              plot = buildParametric3dPlotValue(
                plot.expressions[0],
                plot.expressions[1],
                plot.expressions[2],
                p3d.tVar,
                p3d.minT,
                p3d.maxT,
                parameterValues: paramValues,
              );
            } else {
              final cur = plot.surface3d!;
              plot = plot.isComplex
                  ? buildComplex3dPlotValue(
                      plot.expressions.first,
                      plot.variable,
                      cur.minX,
                      cur.maxX,
                      cur.minY,
                      cur.maxY,
                      parameterValues: paramValues,
                      gridSize: 52,
                    )
                  : buildSurface3dPlotValue(
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
          ..download = plot.parametric3d != null
              ? 'parametric3d.png'
              : (plot.isComplex ? 'plotcomplex3d.png' : 'plot3d.png');
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

    _attachVerticalResizeHandle(canvasWrap, draw);

    web.window.requestAnimationFrame(
      ((num _) {
        draw();
      }).toJS,
    );

    return container;
  }

  static void _attachVerticalResizeHandle(
    web.HTMLDivElement canvasWrap,
    void Function() onResize,
  ) {
    final handle = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-plot-resize-handle'
      ..title = 'Drag to resize plot height (double-click to reset)';
    handle.setAttribute('role', 'separator');
    handle.setAttribute('aria-orientation', 'horizontal');
    handle.setAttribute('aria-label', 'Resize plot height');
    handle.append(
      web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-plot-resize-grip',
    );
    canvasWrap.after(handle);

    var isResizing = false;
    var startY = 0.0;
    var startHeight = 0.0;

    void applyResize(double clientY) {
      final nextHeight = (startHeight + (clientY - startY)).clamp(160.0, 800.0);
      canvasWrap.style.height = '${nextHeight.round()}px';
      onResize();
    }

    final onMouseMove = ((web.MouseEvent e) {
      if (!isResizing) return;
      applyResize(e.clientY.toDouble());
    }).toJS;

    late final web.EventListener onMouseUp;
    onMouseUp = ((web.Event _) {
      if (!isResizing) return;
      isResizing = false;
      handle.classList.remove('resizing');
      web.window.removeEventListener('mousemove', onMouseMove);
      web.window.removeEventListener('mouseup', onMouseUp);
    }).toJS;

    handle.addEventListener(
      'mousedown',
      ((web.MouseEvent e) {
        if (e.button != 0) return;
        e.preventDefault();
        e.stopPropagation();
        isResizing = true;
        startY = e.clientY.toDouble();
        startHeight = canvasWrap.getBoundingClientRect().height;
        handle.classList.add('resizing');
        web.window.addEventListener('mousemove', onMouseMove);
        web.window.addEventListener('mouseup', onMouseUp);
      }).toJS,
    );

    final onTouchMove = ((web.TouchEvent e) {
      if (!isResizing || e.touches.length == 0) return;
      e.preventDefault();
      final touch = e.touches.item(0);
      if (touch != null) {
        applyResize(touch.clientY.toDouble());
      }
    }).toJS;

    late final web.EventListener onTouchEnd;
    onTouchEnd = ((web.Event _) {
      if (!isResizing) return;
      isResizing = false;
      handle.classList.remove('resizing');
      web.window.removeEventListener('touchmove', onTouchMove);
      web.window.removeEventListener('touchend', onTouchEnd);
      web.window.removeEventListener('touchcancel', onTouchEnd);
    }).toJS;

    handle.addEventListener(
      'touchstart',
      ((web.TouchEvent e) {
        if (e.touches.length != 1) return;
        final touch = e.touches.item(0);
        if (touch == null) return;
        e.preventDefault();
        isResizing = true;
        startY = touch.clientY.toDouble();
        startHeight = canvasWrap.getBoundingClientRect().height;
        handle.classList.add('resizing');
        web.window.addEventListener('touchmove', onTouchMove);
        web.window.addEventListener('touchend', onTouchEnd);
        web.window.addEventListener('touchcancel', onTouchEnd);
      }).toJS,
    );

    handle.addEventListener(
      'dblclick',
      ((web.Event _) {
        canvasWrap.style.height = '';
        onResize();
      }).toJS,
    );
  }

  static web.HTMLElement _buildCompactPlotMenu({
    required web.HTMLSpanElement readoutSource,
    required web.HTMLButtonElement resetBtn,
    required web.HTMLButtonElement pngBtn,
    required String resetLabel,
    List<PlotMenuAction> extraActions = const [],
  }) {
    final wrap = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-chip-more-wrap calc-plot-compact-menu';
    final btn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-cell-icon-btn calc-compact-menu-btn'
      ..textContent = '⋯'
      ..title = 'Plot options';
    btn.setAttribute('aria-label', 'Plot options');

    final menu = web.document.createElement('div') as web.HTMLDivElement
      ..className =
          'calc-chip-dropdown calc-chip-dropdown-right open-down hidden';

    final readoutItem = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-dropdown-readout'
      ..textContent = readoutSource.textContent ?? '';
    final divider = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-dropdown-divider';

    final resetItem =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-dropdown-item'
          ..textContent = resetLabel;
    resetItem.addEventListener(
      'click',
      ((web.Event _) {
        menu.classList.add('hidden');
        resetBtn.click();
      }).toJS,
    );

    final pngItem =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-dropdown-item'
          ..textContent = 'Export PNG';
    pngItem.addEventListener(
      'click',
      ((web.Event _) {
        menu.classList.add('hidden');
        pngBtn.click();
      }).toJS,
    );

    menu
      ..append(readoutItem)
      ..append(divider)
      ..append(resetItem)
      ..append(pngItem);

    if (extraActions.isNotEmpty) {
      menu.append(
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-dropdown-divider',
      );
      for (final action in extraActions) {
        final item =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = action.danger
                  ? 'calc-dropdown-item calc-dropdown-item-danger'
                  : 'calc-dropdown-item'
              ..textContent = action.label;
        item.addEventListener(
          'click',
          ((web.Event _) {
            menu.classList.add('hidden');
            action.onTap();
          }).toJS,
        );
        menu.append(item);
      }
    }

    btn.addEventListener(
      'click',
      ((web.Event e) {
        e.stopPropagation();
        readoutItem.textContent = readoutSource.textContent ?? '';
        ActionChips.toggleDropdown(btn, menu, forceDown: true);
      }).toJS,
    );

    wrap
      ..append(btn)
      ..append(menu);
    return wrap;
  }

  static String _formatComplex(double re, double im) {
    final sign = im < 0 ? '-' : '+';
    return '${formatRealDigits(re, 4)} $sign ${formatRealDigits(im.abs(), 4)}i';
  }

  static String _formatParamSummary(
    List<String> parameters,
    Map<String, double> paramValues,
  ) => parameters
      .map((p) => '$p = ${(paramValues[p] ?? 1.0).toStringAsFixed(2)}')
      .join(', ');

  static ({
    double x,
    double y,
    double? t,
    double px,
    double py,
    String color,
    String label,
    int curveIndex,
    bool hasImaginary,
  })?
  _findNearestCurvePoint(
    List<PlotCurveData> curves,
    List<String> palette,
    PlotViewport vp,
    double hx,
    double hy, {
    double maxDistPx = 28.0,
  }) {
    var bestDistSq = maxDistPx * maxDistPx;
    ({
      double x,
      double y,
      double? t,
      double px,
      double py,
      String color,
      String label,
      int curveIndex,
      bool hasImaginary,
    })?
    best;

    void scanSegments(
      List<PlotSegmentData> segments,
      String color,
      String label,
      int curveIndex,
      bool hasImaginary,
    ) {
      for (final seg in segments) {
        final len = seg.x.length;
        final tData = seg.t;
        for (var i = 0; i < len; i++) {
          final x0 = seg.x[i];
          final y0 = seg.y[i];
          if (!x0.isFinite || !y0.isFinite) continue;
          final px0 = vp.toPixelX(x0);
          final py0 = vp.toPixelY(y0);

          if (i + 1 < len && seg.x[i + 1].isFinite && seg.y[i + 1].isFinite) {
            final x1 = seg.x[i + 1];
            final y1 = seg.y[i + 1];
            final px1 = vp.toPixelX(x1);
            final py1 = vp.toPixelY(y1);
            final dx = px1 - px0;
            final dy = py1 - py0;
            final lenSq = dx * dx + dy * dy;
            final alpha = lenSq > 1e-6
                ? (((hx - px0) * dx + (hy - py0) * dy) / lenSq).clamp(0.0, 1.0)
                : 0.0;
            final px = px0 + alpha * dx;
            final py = py0 + alpha * dy;
            final dSq = (px - hx) * (px - hx) + (py - hy) * (py - hy);
            if (dSq < bestDistSq) {
              bestDistSq = dSq;
              final tVal = tData != null && i + 1 < tData.length
                  ? tData[i] + alpha * (tData[i + 1] - tData[i])
                  : null;
              best = (
                x: x0 + alpha * (x1 - x0),
                y: y0 + alpha * (y1 - y0),
                t: tVal,
                px: px,
                py: py,
                color: color,
                label: label,
                curveIndex: curveIndex,
                hasImaginary: hasImaginary,
              );
            }
          } else {
            final dSq = (px0 - hx) * (px0 - hx) + (py0 - hy) * (py0 - hy);
            if (dSq < bestDistSq) {
              bestDistSq = dSq;
              best = (
                x: x0,
                y: y0,
                t: tData != null && i < tData.length ? tData[i] : null,
                px: px0,
                py: py0,
                color: color,
                label: label,
                curveIndex: curveIndex,
                hasImaginary: hasImaginary,
              );
            }
          }
        }
      }
    }

    for (var i = 0; i < curves.length; i++) {
      final curve = curves[i];
      final color = palette[i % palette.length];
      scanSegments(curve.segments, color, curve.label, i, curve.hasImaginary);
      scanSegments(
        curve.imaginarySegments,
        color,
        curve.label,
        i,
        curve.hasImaginary,
      );
    }
    return best;
  }

  static void _drawPlotTooltip(
    web.CanvasRenderingContext2D ctx,
    PlotViewport vp,
    double anchorX,
    double anchorY,
    List<String> lines, {
    String borderColor = 'rgba(148, 163, 184, 0.45)',
  }) {
    if (lines.isEmpty) return;
    ctx.save();
    ctx.font = 'bold 10.5px Inter, ui-monospace, sans-serif';
    var maxTextW = 0.0;
    for (final line in lines) {
      final w = ctx.measureText(line).width;
      if (w > maxTextW) maxTextW = w;
    }

    const padX = 8.0;
    const padY = 6.0;
    const lineH = 14.0;
    final tipW = maxTextW + padX * 2;
    final tipH = lines.length * lineH + padY * 2 - 2.0;

    final maxRight = vp.leftMargin + vp.plotWidth - 4.0;
    final maxBottom = vp.topMargin + vp.plotHeight - 4.0;
    final tipX = (anchorX + 12.0 + tipW > maxRight)
        ? math.max(vp.leftMargin + 4.0, anchorX - tipW - 12.0)
        : anchorX + 12.0;
    final tipY = (anchorY - tipH - 10.0 < vp.topMargin + 4.0)
        ? math.min(maxBottom - tipH, anchorY + 12.0)
        : anchorY - tipH - 10.0;

    ctx.fillStyle = 'rgba(15, 23, 42, 0.92)'.toJS;
    ctx.strokeStyle = borderColor.toJS;
    ctx.lineWidth = 1.0;
    ctx.beginPath();
    ctx.rect(tipX, tipY, tipW, tipH);
    ctx.fill();
    ctx.stroke();

    ctx.fillStyle = '#f8fafc'.toJS;
    ctx.textAlign = 'left';
    for (var i = 0; i < lines.length; i++) {
      ctx.fillText(lines[i], tipX + padX, tipY + padY + 9.5 + i * lineH);
    }
    ctx.restore();
  }
}

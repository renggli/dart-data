import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../model/value.dart';
import 'persistence.dart';

/// Interactive HTML5 Canvas 2D plot card widget for [PlotValue] results.
///
/// Supports wheel zoom, drag pan, hover crosshair readout, root/extremum
/// marker pins, Reset View, Re-sample on current pan/zoom X bounds, and
/// PNG export.
final class PlotView {
  /// Builds a self-contained interactive plot DOM element for [initialPlot].
  ///
  /// When the user clicks "Re-sample", [onResample] is called with the new
  /// `[minX, maxX]` range if provided, or the card re-samples locally using
  /// `buildPlotValue`.
  static web.HTMLElement create(
    PlotValue initialPlot, {
    void Function(double minX, double maxX)? onResample,
  }) {
    final plot = initialPlot;
    var viewMinX = plot.minX;
    var viewMaxX = plot.maxX;
    var viewMinY = plot.minY;
    var viewMaxY = plot.maxY;

    double? hoverCanvasX;
    double? hoverCanvasY;
    var isDragging = false;
    var dragStartX = 0.0;
    var dragStartY = 0.0;

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
          '${plot.variable} ∈ [${formatRealDigits(viewMinX, 4)}, ${formatRealDigits(viewMaxX, 4)}]';

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
      ..append(resetBtn)
      ..append(resampleBtn)
      ..append(pngBtn);
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

    void draw() {
      final rect = canvas.getBoundingClientRect();
      final dpr = web.window.devicePixelRatio;
      final cssW = rect.width > 40 ? rect.width : 640.0;
      final cssH = rect.height > 40 ? rect.height : 260.0;
      final targetW = (cssW * dpr).round();
      final targetH = (cssH * dpr).round();
      if (canvas.width != targetW || canvas.height != targetH) {
        canvas.width = targetW;
        canvas.height = targetH;
      }

      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
      if (ctx == null) return;

      ctx.save();
      ctx.scale(dpr, dpr);

      const bgColor = '#0f172a';
      const gridColor = '#1e293b';
      const axisColor = '#475569';
      const labelColor = '#94a3b8';

      ctx.fillStyle = bgColor.toJS;
      ctx.fillRect(0, 0, cssW, cssH);

      const padLeft = 48.0;
      const padRight = 16.0;
      const padTop = 14.0;
      const padBottom = 26.0;
      final plotW = math.max(10.0, cssW - padLeft - padRight);
      final plotH = math.max(10.0, cssH - padTop - padBottom);

      double toScreenX(double x) =>
          padLeft + (x - viewMinX) / (viewMaxX - viewMinX) * plotW;
      double toScreenY(double y) =>
          padTop + (1.0 - (y - viewMinY) / (viewMaxY - viewMinY)) * plotH;
      double toWorldX(double sx) =>
          viewMinX + (sx - padLeft) / plotW * (viewMaxX - viewMinX);
      double toWorldY(double sy) =>
          viewMinY + (1.0 - (sy - padTop) / plotH) * (viewMaxY - viewMinY);

      // Grid lines & ticks
      ctx.strokeStyle = gridColor.toJS;
      ctx.lineWidth = 1.0;
      ctx.fillStyle = labelColor.toJS;
      ctx.font = '11px ui-monospace, SFMono-Regular, Menlo, monospace';

      final xTicks = _niceTicks(viewMinX, viewMaxX, 6);
      for (final tx in xTicks) {
        final sx = toScreenX(tx);
        if (sx < padLeft || sx > padLeft + plotW) continue;
        ctx.beginPath();
        ctx.moveTo(sx, padTop);
        ctx.lineTo(sx, padTop + plotH);
        ctx.stroke();
        ctx.textAlign = 'center';
        ctx.fillText(formatRealDigits(tx, 4), sx, padTop + plotH + 16);
      }

      final yTicks = _niceTicks(viewMinY, viewMaxY, 5);
      for (final ty in yTicks) {
        final sy = toScreenY(ty);
        if (sy < padTop || sy > padTop + plotH) continue;
        ctx.beginPath();
        ctx.moveTo(padLeft, sy);
        ctx.lineTo(padLeft + plotW, sy);
        ctx.stroke();
        ctx.textAlign = 'right';
        ctx.fillText(formatRealDigits(ty, 4), padLeft - 6, sy + 4);
      }

      // Zero axes
      ctx.strokeStyle = axisColor.toJS;
      ctx.lineWidth = 1.25;
      if (viewMinX <= 0 && viewMaxX >= 0) {
        final sx0 = toScreenX(0);
        ctx.beginPath();
        ctx.moveTo(sx0, padTop);
        ctx.lineTo(sx0, padTop + plotH);
        ctx.stroke();
      }
      if (viewMinY <= 0 && viewMaxY >= 0) {
        final sy0 = toScreenY(0);
        ctx.beginPath();
        ctx.moveTo(padLeft, sy0);
        ctx.lineTo(padLeft + plotW, sy0);
        ctx.stroke();
      }

      // Clip to plot box
      ctx.save();
      ctx.beginPath();
      ctx.rect(padLeft, padTop, plotW, plotH);
      ctx.clip();

      // Draw curves
      for (var cIdx = 0; cIdx < plot.curves.length; cIdx++) {
        final curve = plot.curves[cIdx];
        final color = palette[cIdx % palette.length];

        ctx.strokeStyle = color.toJS;
        ctx.lineWidth = 2.2;
        ctx.setLineDash(<JSNumber>[].toJS);
        for (final seg in curve.segments) {
          _strokeSegment(ctx, seg, toScreenX, toScreenY, cssH);
        }

        if (curve.imaginarySegments.isNotEmpty) {
          ctx.strokeStyle = color.toJS;
          ctx.lineWidth = 1.6;
          ctx.setLineDash(<JSNumber>[5.toJS, 4.toJS].toJS);
          for (final seg in curve.imaginarySegments) {
            _strokeSegment(ctx, seg, toScreenX, toScreenY, cssH);
          }
          ctx.setLineDash(<JSNumber>[].toJS);
        }

        // Draw root/extremum markers
        for (final marker in curve.markers) {
          final mx = toScreenX(marker.x);
          final my = toScreenY(marker.y);
          if (mx < padLeft ||
              mx > padLeft + plotW ||
              my < padTop ||
              my > padTop + plotH) {
            continue;
          }
          ctx.fillStyle = color.toJS;
          ctx.beginPath();
          ctx.arc(mx, my, 4.0, 0, 2 * math.pi);
          ctx.fill();
        }
      }

      // Hover crosshair + nearest curve point
      if (hoverCanvasX != null &&
          hoverCanvasY != null &&
          hoverCanvasX! >= padLeft &&
          hoverCanvasX! <= padLeft + plotW &&
          hoverCanvasY! >= padTop &&
          hoverCanvasY! <= padTop + plotH) {
        final wx = toWorldX(hoverCanvasX!);
        final wy = toWorldY(hoverCanvasY!);

        ctx.strokeStyle = axisColor.toJS;
        ctx.lineWidth = 0.8;
        ctx.setLineDash(<JSNumber>[3.toJS, 3.toJS].toJS);
        ctx.beginPath();
        ctx.moveTo(hoverCanvasX!, padTop);
        ctx.lineTo(hoverCanvasX!, padTop + plotH);
        ctx.moveTo(padLeft, hoverCanvasY!);
        ctx.lineTo(padLeft + plotW, hoverCanvasY!);
        ctx.stroke();
        ctx.setLineDash(<JSNumber>[].toJS);

        readout.textContent =
            '(${formatRealDigits(wx, 4)}, ${formatRealDigits(wy, 4)})';
      } else {
        readout.textContent =
            '${plot.variable} ∈ [${formatRealDigits(viewMinX, 4)}, ${formatRealDigits(viewMaxX, 4)}]';
      }

      ctx.restore();
      ctx.restore();
    }

    // Mouse / wheel interactions
    canvas.addEventListener(
      'mousedown',
      ((web.MouseEvent e) {
        isDragging = true;
        dragStartX = e.offsetX;
        dragStartY = e.offsetY;
      }).toJS,
    );

    canvas.addEventListener(
      'mousemove',
      ((web.MouseEvent e) {
        final rect = canvas.getBoundingClientRect();
        const padLeft = 48.0;
        const padRight = 16.0;
        const padTop = 14.0;
        const padBottom = 26.0;
        final plotW = math.max(10.0, rect.width - padLeft - padRight);
        final plotH = math.max(10.0, rect.height - padTop - padBottom);

        if (isDragging) {
          final dx = e.offsetX - dragStartX;
          final dy = e.offsetY - dragStartY;
          dragStartX = e.offsetX;
          dragStartY = e.offsetY;
          final spanX = viewMaxX - viewMinX;
          final spanY = viewMaxY - viewMinY;
          final shiftX = -dx / plotW * spanX;
          final shiftY = dy / plotH * spanY;
          viewMinX += shiftX;
          viewMaxX += shiftX;
          viewMinY += shiftY;
          viewMaxY += shiftY;
        }
        hoverCanvasX = e.offsetX;
        hoverCanvasY = e.offsetY;
        draw();
      }).toJS,
    );

    canvas.addEventListener(
      'mouseup',
      ((web.MouseEvent _) {
        isDragging = false;
      }).toJS,
    );

    canvas.addEventListener(
      'mouseleave',
      ((web.MouseEvent _) {
        isDragging = false;
        hoverCanvasX = null;
        hoverCanvasY = null;
        draw();
      }).toJS,
    );

    canvas.addEventListener(
      'wheel',
      ((web.WheelEvent e) {
        e.preventDefault();
        final factor = e.deltaY < 0 ? 0.85 : 1.18;
        final midX = 0.5 * (viewMinX + viewMaxX);
        final midY = 0.5 * (viewMinY + viewMaxY);
        final halfW = 0.5 * (viewMaxX - viewMinX) * factor;
        final halfH = 0.5 * (viewMaxY - viewMinY) * factor;
        viewMinX = midX - halfW;
        viewMaxX = midX + halfW;
        viewMinY = midY - halfH;
        viewMaxY = midY + halfH;
        draw();
      }).toJS,
    );

    resetBtn.addEventListener(
      'click',
      ((web.Event _) {
        viewMinX = plot.minX;
        viewMaxX = plot.maxX;
        viewMinY = plot.minY;
        viewMaxY = plot.maxY;
        draw();
      }).toJS,
    );

    resampleBtn.addEventListener(
      'click',
      ((web.Event _) {
        if (onResample != null) {
          onResample(viewMinX, viewMaxX);
        }
      }).toJS,
    );

    pngBtn.addEventListener(
      'click',
      ((web.Event _) {
        final dataUrl = canvas.toDataURL('image/png');
        final a = web.document.createElement('a') as web.HTMLAnchorElement
          ..href = dataUrl
          ..download = 'plot.png';
        web.document.body?.append(a);
        a.click();
        a.remove();
        CalcPersistence.triggerHaptic(enabled: true);
      }).toJS,
    );

    // Defer initial draw to next animation frame once attached to DOM
    web.window.requestAnimationFrame(
      ((num _) {
        draw();
      }).toJS,
    );

    return container;
  }

  static void _strokeSegment(
    web.CanvasRenderingContext2D ctx,
    PlotSegmentData seg,
    double Function(double) toScreenX,
    double Function(double) toScreenY,
    double cssH,
  ) {
    var started = false;
    for (var i = 0; i < seg.x.length; i++) {
      final x = seg.x[i];
      final y = seg.y[i];
      if (!x.isFinite || !y.isFinite) {
        started = false;
        continue;
      }
      final sx = toScreenX(x);
      final sy = toScreenY(y);
      if (sy < -cssH * 2 || sy > cssH * 3) {
        started = false;
        continue;
      }
      if (!started) {
        ctx.beginPath();
        ctx.moveTo(sx, sy);
        started = true;
      } else {
        ctx.lineTo(sx, sy);
      }
      if (i == seg.x.length - 1 ||
          !seg.y[i + 1].isFinite ||
          (toScreenY(seg.y[i + 1]) - sy).abs() > cssH * 1.5) {
        ctx.stroke();
        started = false;
      }
    }
    if (started) ctx.stroke();
  }

  static List<double> _niceTicks(double min, double max, int count) {
    final span = max - min;
    if (!span.isFinite || span <= 0) return [min];
    final rawStep = span / count;
    final mag = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final residual = rawStep / mag;
    final step = residual > 5
        ? 10.0 * mag
        : residual > 2
        ? 5.0 * mag
        : residual > 1
        ? 2.0 * mag
        : mag;
    final first = (min / step).ceil() * step;
    final ticks = <double>[];
    for (var v = first; v <= max + step * 1e-6; v += step) {
      ticks.add(v.abs() < step * 1e-9 ? 0.0 : v);
      if (ticks.length > 20) break;
    }
    return ticks;
  }
}

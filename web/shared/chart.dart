import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/numeric.dart';
import 'package:web/web.dart' as web;

import 'webgl_chart.dart';

/// Mathematical plotting viewport defining domain, range, and pixel geometry.
class PlotViewport {
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double width;
  final double height;
  final double leftMargin;
  final double rightMargin;
  final double topMargin;
  final double bottomMargin;

  const new({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.width,
    required this.height,
    this.leftMargin = 55.0,
    this.rightMargin = 20.0,
    this.topMargin = 20.0,
    this.bottomMargin = 36.0,
  });

  double get plotWidth => math.max(10.0, width - leftMargin - rightMargin);
  double get plotHeight => math.max(10.0, height - topMargin - bottomMargin);

  double toPixelX(double x) =>
      leftMargin + (x - minX) * plotWidth / (maxX - minX);

  double toPixelY(double y) =>
      topMargin + plotHeight - (y - minY) * plotHeight / (maxY - minY);

  double fromPixelX(double px) =>
      minX + (px - leftMargin) * (maxX - minX) / plotWidth;

  double fromPixelY(double py) =>
      minY + (topMargin + plotHeight - py) * (maxY - minY) / plotHeight;

  bool containsPixel(double px, double py) =>
      px >= leftMargin &&
      px <= leftMargin + plotWidth &&
      py >= topMargin &&
      py <= topMargin + plotHeight;
}

/// Shared interactive pan/zoom/hover controller for an HTML5 `<canvas>` chart.
///
/// Supports:
/// - Mouse drag and single-finger touch drag to pan X (and Y when [panY] is enabled).
/// - Mouse wheel zoom anchored at the cursor position (for X and optionally Y).
/// - Double-click on the plot area to reset the view.
/// - Hover coordinate tracking (`hoverPixelX`, `hoverPixelY`) with `requestAnimationFrame` throttling.
class InteractiveChartController {
  final web.HTMLCanvasElement canvas;
  final double leftMargin;
  final double rightMargin;
  final double topMargin;
  final double bottomMargin;
  final bool panY;
  final bool zoomY;
  final void Function() onUpdate;
  final void Function(double minX, double maxX, double minY, double maxY)?
  onViewportChanged;
  final void Function()? onReset;

  double minX;
  double maxX;
  double minY;
  double maxY;

  double _defaultMinX;
  double _defaultMaxX;
  double _defaultMinY;
  double _defaultMaxY;

  double? hoverPixelX;
  double? hoverPixelY;
  bool isDragging = false;
  bool hasUserPannedOrZoomed = false;
  bool enabled = true;

  double _dragStartX = 0.0;
  double _dragStartY = 0.0;
  bool _rafPending = false;

  new(
    this.canvas, {
    required this.minX,
    required this.maxX,
    this.minY = -5.0,
    this.maxY = 5.0,
    this.leftMargin = 55.0,
    this.rightMargin = 20.0,
    this.topMargin = 20.0,
    this.bottomMargin = 36.0,
    this.panY = true,
    this.zoomY = true,
    required this.onUpdate,
    this.onViewportChanged,
    this.onReset,
  }) : _defaultMinX = minX,
       _defaultMaxX = maxX,
       _defaultMinY = minY,
       _defaultMaxY = maxY {
    _attachListeners();
  }

  /// Updates the current bounds (and optionally the default reset bounds).
  void setBounds({
    double? minX,
    double? maxX,
    double? minY,
    double? maxY,
    bool asDefault = false,
    bool clearUserInteraction = false,
  }) {
    if (minX != null) {
      this.minX = minX;
      if (asDefault) _defaultMinX = minX;
    }
    if (maxX != null) {
      this.maxX = maxX;
      if (asDefault) _defaultMaxX = maxX;
    }
    if (minY != null) {
      this.minY = minY;
      if (asDefault) _defaultMinY = minY;
    }
    if (maxY != null) {
      this.maxY = maxY;
      if (asDefault) _defaultMaxY = maxY;
    }
    if (clearUserInteraction) {
      hasUserPannedOrZoomed = false;
    }
  }

  /// Resets the viewport to the default bounds and triggers a redraw.
  void reset() {
    minX = _defaultMinX;
    maxX = _defaultMaxX;
    minY = _defaultMinY;
    maxY = _defaultMaxY;
    hasUserPannedOrZoomed = false;
    onReset?.call();
    onViewportChanged?.call(minX, maxX, minY, maxY);
    scheduleUpdate();
  }

  /// Creates a [PlotViewport] for the given canvas logical [width] and [height].
  PlotViewport viewport(
    double width,
    double height, {
    double? overrideMinY,
    double? overrideMaxY,
  }) => PlotViewport(
    minX: minX,
    maxX: maxX,
    minY: overrideMinY ?? minY,
    maxY: overrideMaxY ?? maxY,
    width: width,
    height: height,
    leftMargin: leftMargin,
    rightMargin: rightMargin,
    topMargin: topMargin,
    bottomMargin: bottomMargin,
  );

  /// Throttles redraws via `requestAnimationFrame`.
  void scheduleUpdate() {
    if (_rafPending) return;
    _rafPending = true;
    web.window.requestAnimationFrame(
      ((num _) {
        _rafPending = false;
        onUpdate();
      }).toJS,
    );
  }

  void _attachListeners() {
    canvas.style.cursor = 'grab';

    canvas.addEventListener(
      'mousedown',
      ((web.MouseEvent e) {
        if (!enabled || e.button != 0) return;
        isDragging = true;
        final rect = canvas.getBoundingClientRect();
        _dragStartX = e.clientX - rect.left;
        _dragStartY = e.clientY - rect.top;
        canvas.style.cursor = 'grabbing';
      }).toJS,
    );

    canvas.addEventListener(
      'mousemove',
      ((web.MouseEvent e) {
        if (!enabled) return;
        final rect = canvas.getBoundingClientRect();
        final curX = e.clientX - rect.left;
        final curY = e.clientY - rect.top;
        final plotW = math.max(10.0, rect.width - leftMargin - rightMargin);
        final plotH = math.max(10.0, rect.height - topMargin - bottomMargin);

        if (isDragging) {
          final dx = curX - _dragStartX;
          final dy = curY - _dragStartY;
          _dragStartX = curX;
          _dragStartY = curY;

          final spanX = maxX - minX;
          final shiftX = -dx / plotW * spanX;
          minX += shiftX;
          maxX += shiftX;

          if (panY) {
            final spanY = maxY - minY;
            final shiftY = dy / plotH * spanY;
            minY += shiftY;
            maxY += shiftY;
          }
          hasUserPannedOrZoomed = true;
          onViewportChanged?.call(minX, maxX, minY, maxY);
        }

        hoverPixelX = curX;
        hoverPixelY = curY;
        scheduleUpdate();
      }).toJS,
    );

    void endDrag() {
      if (isDragging) {
        isDragging = false;
        canvas.style.cursor = 'grab';
      }
    }

    canvas.addEventListener('mouseup', ((web.MouseEvent _) => endDrag()).toJS);

    canvas.addEventListener(
      'mouseleave',
      ((web.MouseEvent _) {
        endDrag();
        hoverPixelX = null;
        hoverPixelY = null;
        scheduleUpdate();
      }).toJS,
    );

    canvas.addEventListener(
      'dblclick',
      ((web.MouseEvent _) {
        if (!enabled) return;
        reset();
      }).toJS,
    );

    canvas.addEventListener(
      'wheel',
      ((web.WheelEvent e) {
        if (!enabled) return;
        e.preventDefault();
        final rect = canvas.getBoundingClientRect();
        final curX = e.clientX - rect.left;
        final curY = e.clientY - rect.top;
        final plotW = math.max(10.0, rect.width - leftMargin - rightMargin);
        final plotH = math.max(10.0, rect.height - topMargin - bottomMargin);

        final factor = e.deltaY < 0 ? 0.85 : 1.18;

        // Anchor zoom at cursor fraction inside plot box (or 0.5 if outside)
        final fracX = ((curX - leftMargin) / plotW).clamp(0.0, 1.0);
        final anchorX = minX + fracX * (maxX - minX);
        final newSpanX = (maxX - minX) * factor;
        if (newSpanX > 1e-9 && newSpanX < 1e9) {
          minX = anchorX - fracX * newSpanX;
          maxX = minX + newSpanX;
        }

        if (zoomY) {
          final fracY = (1.0 - (curY - topMargin) / plotH).clamp(0.0, 1.0);
          final anchorY = minY + fracY * (maxY - minY);
          final newSpanY = (maxY - minY) * factor;
          if (newSpanY > 1e-9 && newSpanY < 1e9) {
            minY = anchorY - fracY * newSpanY;
            maxY = minY + newSpanY;
          }
        }

        hasUserPannedOrZoomed = true;
        onViewportChanged?.call(minX, maxX, minY, maxY);
        scheduleUpdate();
      }).toJS,
    );

    // Touch pan support for mobile
    canvas.addEventListener(
      'touchstart',
      ((web.TouchEvent e) {
        if (!enabled) return;
        if (e.touches.length == 1) {
          final t = e.touches.item(0)!;
          final rect = canvas.getBoundingClientRect();
          isDragging = true;
          _dragStartX = t.clientX - rect.left;
          _dragStartY = t.clientY - rect.top;
        }
      }).toJS,
    );

    canvas.addEventListener(
      'touchmove',
      ((web.TouchEvent e) {
        if (!isDragging || e.touches.length != 1) return;
        e.preventDefault();
        final t = e.touches.item(0)!;
        final rect = canvas.getBoundingClientRect();
        final curX = t.clientX - rect.left;
        final curY = t.clientY - rect.top;
        final plotW = math.max(10.0, rect.width - leftMargin - rightMargin);
        final plotH = math.max(10.0, rect.height - topMargin - bottomMargin);

        final dx = curX - _dragStartX;
        final dy = curY - _dragStartY;
        _dragStartX = curX;
        _dragStartY = curY;

        final spanX = maxX - minX;
        final shiftX = -dx / plotW * spanX;
        minX += shiftX;
        maxX += shiftX;

        if (panY) {
          final spanY = maxY - minY;
          final shiftY = dy / plotH * spanY;
          minY += shiftY;
          maxY += shiftY;
        }
        hasUserPannedOrZoomed = true;
        hoverPixelX = curX;
        hoverPixelY = curY;
        onViewportChanged?.call(minX, maxX, minY, maxY);
        scheduleUpdate();
      }).toJS,
    );

    canvas.addEventListener('touchend', ((web.TouchEvent _) => endDrag()).toJS);
  }
}

/// Computes human-friendly 1/2/5×10^k tick positions across `[min, max]`.
List<double> niceTicks(double min, double max, int count) {
  final span = max - min;
  if (!span.isFinite || span <= 0) return [min];
  final rawStep = span / count;
  final mag = math.pow(10, (math.log(rawStep) / math.ln10).floor()).toDouble();
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

String _formatTick(double val) {
  if (val.abs() < 1e-10) return '0';
  if ((val - val.roundToDouble()).abs() < 1e-9 && val.abs() < 1e6) {
    return val.round().toString();
  }
  final s = val.toStringAsPrecision(4);
  if (s.contains('.') && !s.contains('e')) {
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s;
}

/// Sets up a high-DPI crisp canvas backing store. Returns null if dimensions are zero.
(web.CanvasRenderingContext2D, double, double)? initCanvas(
  web.HTMLCanvasElement canvas,
) {
  final parentRect = canvas.parentElement?.getBoundingClientRect();
  final selfRect = canvas.getBoundingClientRect();
  final width = (parentRect != null && parentRect.width > 0)
      ? parentRect.width
      : selfRect.width;
  final height = (parentRect != null && parentRect.height > 0)
      ? parentRect.height
      : selfRect.height;
  if (width <= 0 || height <= 0) return null;

  final dpr = web.window.devicePixelRatio;
  canvas.width = (width * dpr).toInt();
  canvas.height = (height * dpr).toInt();
  canvas.style.width = '${width}px';
  canvas.style.height = '${height}px';

  WebGL2ChartLayer.attachAndClear(canvas, width, height, dpr);

  final ctx = canvas.context2D;
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, width, height);

  return (ctx, width, height);
}

/// Draws Cartesian grid lines, nice tick labels, and zero axes.
void drawGrid(
  web.CanvasRenderingContext2D ctx,
  PlotViewport vp, {
  int xTicks = 6,
  int yTicks = 5,
  bool drawZeroAxes = true,
}) {
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)'.toJS;
  ctx.lineWidth = 1.0;
  ctx.fillStyle = '#64748b'.toJS;
  ctx.font = '10px Inter, ui-monospace, sans-serif';

  // 1. Vertical grid lines & nice X ticks
  final xTickVals = niceTicks(vp.minX, vp.maxX, xTicks);
  for (final xVal in xTickVals) {
    final px = vp.toPixelX(xVal);
    if (px < vp.leftMargin - 1 || px > vp.leftMargin + vp.plotWidth + 1) {
      continue;
    }

    ctx.beginPath();
    ctx.moveTo(px, vp.topMargin);
    ctx.lineTo(px, vp.topMargin + vp.plotHeight);
    ctx.stroke();

    ctx.textAlign = 'center';
    ctx.fillText(_formatTick(xVal), px, vp.topMargin + vp.plotHeight + 15);
  }

  // 2. Horizontal grid lines & nice Y ticks
  final yTickVals = niceTicks(vp.minY, vp.maxY, yTicks);
  for (final yVal in yTickVals) {
    final py = vp.toPixelY(yVal);
    if (py < vp.topMargin - 1 || py > vp.topMargin + vp.plotHeight + 1) {
      continue;
    }

    ctx.beginPath();
    ctx.moveTo(vp.leftMargin, py);
    ctx.lineTo(vp.leftMargin + vp.plotWidth, py);
    ctx.stroke();

    ctx.textAlign = 'right';
    ctx.fillText(_formatTick(yVal), vp.leftMargin - 8, py + 3);
  }

  // 3. Highlighted Zero axes
  if (drawZeroAxes) {
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.16)'.toJS;
    ctx.lineWidth = 1.15;

    // Y = 0 axis line
    if (vp.minY <= 0 && vp.maxY >= 0) {
      final pyZero = vp.toPixelY(0.0);
      ctx.beginPath();
      ctx.moveTo(vp.leftMargin, pyZero);
      ctx.lineTo(vp.leftMargin + vp.plotWidth, pyZero);
      ctx.stroke();
    }

    // X = 0 axis line
    if (vp.minX <= 0 && vp.maxX >= 0) {
      final pxZero = vp.toPixelX(0.0);
      ctx.beginPath();
      ctx.moveTo(pxZero, vp.topMargin);
      ctx.lineTo(pxZero, vp.topMargin + vp.plotHeight);
      ctx.stroke();
    }
  }

  // 4. Border box
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)'.toJS;
  ctx.lineWidth = 1.0;
  ctx.beginPath();
  ctx.rect(vp.leftMargin, vp.topMargin, vp.plotWidth, vp.plotHeight);
  ctx.stroke();
}

/// Plots a smooth mathematical curve [fn] across the viewport's X range.
///
/// Uses [sampleCurve] to adaptively subdivide high-curvature regions and
/// automatically split paths across discontinuities and vertical asymptotes.
void drawCurve(
  web.CanvasRenderingContext2D ctx,
  PlotViewport vp,
  double Function(double x) fn, {
  required String strokeColor,
  double lineWidth = 2.0,
  List<num>? lineDash,
  String? fillColor,
  double stepPx = 1.5,
  double? fillBaseY = 0.0,
}) {
  ctx.save();
  ctx.strokeStyle = strokeColor.toJS;
  ctx.lineWidth = lineWidth;
  if (lineDash != null) {
    ctx.setLineDash(lineDash.map((d) => d.toJS).toList().toJS);
  }

  // Clip to inner plot box so curves don't bleed into margins
  ctx.beginPath();
  ctx.rect(vp.leftMargin, vp.topMargin, vp.plotWidth, vp.plotHeight);
  ctx.clip();

  final yMinPx = vp.topMargin - 50.0;
  final yMaxPx = vp.topMargin + vp.plotHeight + 50.0;
  final maxPoints = math.max(256, (vp.plotWidth / stepPx).ceil() * 2);
  final sample = sampleCurve(
    fn,
    vp.minX,
    vp.maxX,
    maxPoints: maxPoints,
    initialPoints: 97,
  );

  final glLayer = WebGL2ChartLayer.of(ctx.canvas);
  if (glLayer != null && glLayer.isAvailable) {
    for (final segment in sample.segments) {
      if (segment.x.length < 2) continue;
      final buf = Float32List(segment.x.length * 2);
      var count = 0;

      void flushRun() {
        if (count >= 2) {
          if (fillColor != null && fillBaseY != null) {
            final basePy = vp
                .toPixelY(fillBaseY)
                .clamp(vp.topMargin, vp.topMargin + vp.plotHeight);
            glLayer.drawAreaFill(
              buf,
              count,
              basePy: basePy,
              fillColor: fillColor,
              clipLeft: vp.leftMargin,
              clipTop: vp.topMargin,
              clipWidth: vp.plotWidth,
              clipHeight: vp.plotHeight,
              verticalGradient: true,
            );
          }
          glLayer.drawPolyline(
            buf,
            count,
            strokeColor: strokeColor,
            lineWidth: lineWidth,
            lineDash: lineDash,
            clipLeft: vp.leftMargin,
            clipTop: vp.topMargin,
            clipWidth: vp.plotWidth,
            clipHeight: vp.plotHeight,
          );
        }
        count = 0;
      }

      for (var i = 0; i < segment.x.length; i++) {
        final curPx = vp.toPixelX(segment.x[i]);
        final py = vp.toPixelY(segment.y[i]);
        if (!curPx.isFinite || !py.isFinite || py < yMinPx || py > yMaxPx) {
          if (count > 0 && curPx.isFinite && py.isFinite) {
            buf[count * 2] = curPx;
            buf[count * 2 + 1] = py.clamp(yMinPx, yMaxPx);
            count++;
          }
          flushRun();
          continue;
        }
        buf[count * 2] = curPx;
        buf[count * 2 + 1] = py;
        count++;
      }
      flushRun();
    }
    ctx.restore();
    return;
  }

  for (final segment in sample.segments) {
    var inPath = false;
    var pathStartX = vp.leftMargin;
    var lastX = vp.leftMargin;

    for (var i = 0; i < segment.x.length; i++) {
      final curPx = vp.toPixelX(segment.x[i]);
      final py = vp.toPixelY(segment.y[i]);

      if (py < yMinPx || py > yMaxPx) {
        if (inPath) {
          ctx.lineTo(curPx, py.clamp(yMinPx, yMaxPx));
          ctx.stroke();
          inPath = false;
        }
        continue;
      }

      if (!inPath) {
        ctx.beginPath();
        ctx.moveTo(curPx, py);
        inPath = true;
        pathStartX = curPx;
      } else {
        ctx.lineTo(curPx, py);
      }
      lastX = curPx;
    }

    if (inPath) {
      ctx.stroke();

      if (fillColor != null && fillBaseY != null) {
        final basePy = vp
            .toPixelY(fillBaseY)
            .clamp(vp.topMargin, vp.topMargin + vp.plotHeight);
        ctx.lineTo(lastX, basePy);
        ctx.lineTo(pathStartX, basePy);
        ctx.closePath();
        ctx.fillStyle = fillColor.toJS;
        ctx.fill();
      }
    }
  }

  ctx.restore();
}

/// Draws pre-sampled curve segments `(x, y)` inside the clipped viewport.
void drawSampledSegments(
  web.CanvasRenderingContext2D ctx,
  PlotViewport vp,
  Iterable<({List<double> x, List<double> y})> segments, {
  required String strokeColor,
  double lineWidth = 2.2,
  List<num>? lineDash,
}) {
  ctx.save();
  ctx.strokeStyle = strokeColor.toJS;
  ctx.lineWidth = lineWidth;
  ctx.setLineDash(
    lineDash != null
        ? lineDash.map((d) => d.toJS).toList().toJS
        : <JSNumber>[].toJS,
  );

  ctx.beginPath();
  ctx.rect(vp.leftMargin, vp.topMargin, vp.plotWidth, vp.plotHeight);
  ctx.clip();

  final cssH = vp.height;
  final glLayer = WebGL2ChartLayer.of(ctx.canvas);
  if (glLayer != null && glLayer.isAvailable) {
    for (final seg in segments) {
      if (seg.x.length < 2) continue;
      final buf = Float32List(seg.x.length * 2);
      var count = 0;

      void flushRun() {
        if (count >= 2) {
          glLayer.drawPolyline(
            buf,
            count,
            strokeColor: strokeColor,
            lineWidth: lineWidth,
            lineDash: lineDash,
            clipLeft: vp.leftMargin,
            clipTop: vp.topMargin,
            clipWidth: vp.plotWidth,
            clipHeight: vp.plotHeight,
          );
        }
        count = 0;
      }

      for (var i = 0; i < seg.x.length; i++) {
        final x = seg.x[i];
        final y = seg.y[i];
        if (!x.isFinite || !y.isFinite) {
          flushRun();
          continue;
        }
        final sx = vp.toPixelX(x);
        final sy = vp.toPixelY(y);
        if (sy < -cssH * 2 || sy > cssH * 3) {
          flushRun();
          continue;
        }
        buf[count * 2] = sx;
        buf[count * 2 + 1] = sy;
        count++;
        if (i == seg.x.length - 1 ||
            !seg.y[i + 1].isFinite ||
            (vp.toPixelY(seg.y[i + 1]) - sy).abs() > cssH * 1.5) {
          flushRun();
        }
      }
      flushRun();
    }
    ctx.restore();
    return;
  }
  for (final seg in segments) {
    var started = false;
    for (var i = 0; i < seg.x.length; i++) {
      final x = seg.x[i];
      final y = seg.y[i];
      if (!x.isFinite || !y.isFinite) {
        started = false;
        continue;
      }
      final sx = vp.toPixelX(x);
      final sy = vp.toPixelY(y);
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
          (vp.toPixelY(seg.y[i + 1]) - sy).abs() > cssH * 1.5) {
        ctx.stroke();
        started = false;
      }
    }
    if (started) ctx.stroke();
  }

  ctx.restore();
}

/// Shading region under [fn] between [fromX] and [toX] down to [baseY].
void drawShadedInterval(
  web.CanvasRenderingContext2D ctx,
  PlotViewport vp,
  double Function(double x) fn,
  double fromX,
  double toX, {
  required String fillColor,
  String? strokeColor,
  double baseY = 0.0,
}) {
  final startX = math.max(vp.minX, math.min(fromX, toX));
  final endX = math.min(vp.maxX, math.max(fromX, toX));
  if (startX >= endX) return;

  final startPx = vp.toPixelX(startX);
  final endPx = vp.toPixelX(endX);
  final basePy = vp
      .toPixelY(baseY)
      .clamp(vp.topMargin, vp.topMargin + vp.plotHeight);

  final glLayer = WebGL2ChartLayer.of(ctx.canvas);
  if (glLayer != null && glLayer.isAvailable) {
    final maxPts = ((endPx - startPx) / 1.5).ceil() + 3;
    final buf = Float32List(maxPts * 2);
    var count = 0;
    for (var px = startPx; px <= endPx; px += 1.5) {
      final x = vp.fromPixelX(px);
      double y;
      try {
        y = fn(x);
      } catch (_) {
        y = baseY;
      }
      if (!y.isFinite || y.isNaN) y = baseY;
      final py = vp
          .toPixelY(y)
          .clamp(vp.topMargin, vp.topMargin + vp.plotHeight);
      buf[count * 2] = px;
      buf[count * 2 + 1] = py;
      count++;
    }
    glLayer.drawAreaFill(
      buf,
      count,
      basePy: basePy,
      fillColor: fillColor,
      clipLeft: vp.leftMargin,
      clipTop: vp.topMargin,
      clipWidth: vp.plotWidth,
      clipHeight: vp.plotHeight,
    );
    if (strokeColor != null) {
      glLayer.drawPolyline(
        buf,
        count,
        strokeColor: strokeColor,
        lineWidth: 1.5,
        clipLeft: vp.leftMargin,
        clipTop: vp.topMargin,
        clipWidth: vp.plotWidth,
        clipHeight: vp.plotHeight,
      );
    }
    return;
  }

  ctx.save();
  ctx.beginPath();
  ctx.rect(vp.leftMargin, vp.topMargin, vp.plotWidth, vp.plotHeight);
  ctx.clip();

  ctx.beginPath();
  ctx.moveTo(startPx, basePy);

  for (var px = startPx; px <= endPx; px += 1.5) {
    final x = vp.fromPixelX(px);
    double y;
    try {
      y = fn(x);
    } catch (_) {
      y = baseY;
    }
    if (!y.isFinite || y.isNaN) y = baseY;
    final py = vp.toPixelY(y).clamp(vp.topMargin, vp.topMargin + vp.plotHeight);
    ctx.lineTo(px, py);
  }

  ctx.lineTo(endPx, basePy);
  ctx.closePath();

  ctx.fillStyle = fillColor.toJS;
  ctx.fill();

  if (strokeColor != null) {
    ctx.strokeStyle = strokeColor.toJS;
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }

  ctx.restore();
}

/// Draws a vertical reference line at [x] with a styled label.
void drawReferenceLine(
  web.CanvasRenderingContext2D ctx,
  PlotViewport vp,
  double x, {
  required String color,
  required String label,
  bool topLabel = true,
  double labelYOffset = 0.0,
}) {
  if (x < vp.minX || x > vp.maxX) return;
  final px = vp.toPixelX(x);

  ctx.save();
  ctx.lineWidth = 1.0;
  ctx.setLineDash([4.toJS, 4.toJS].toJS);
  ctx.strokeStyle = color.toJS;

  ctx.beginPath();
  ctx.moveTo(px, vp.topMargin);
  ctx.lineTo(px, vp.topMargin + vp.plotHeight);
  ctx.stroke();

  ctx.fillStyle = color.toJS;
  ctx.font = '9px monospace';
  ctx.textAlign = 'center';
  final yPos = topLabel
      ? vp.topMargin - 4.0 - labelYOffset
      : vp.topMargin + vp.plotHeight + 12.0 + labelYOffset;
  ctx.fillText(label, px, yPos);
  ctx.restore();
}

/// Draws a prominent point marker with halo.
void drawPointMarker(
  web.CanvasRenderingContext2D ctx,
  PlotViewport vp,
  double x,
  double y, {
  required String color,
  double radius = 4.0,
  String? label,
}) {
  if (x < vp.minX || x > vp.maxX || y < vp.minY || y > vp.maxY) return;
  final px = vp.toPixelX(x);
  final py = vp.toPixelY(y);

  ctx.save();

  // Halo
  ctx.fillStyle = '${color}33'.toJS;
  ctx.beginPath();
  ctx.arc(px, py, radius + 3.0, 0.0, 2 * math.pi);
  ctx.fill();

  // Core dot
  ctx.fillStyle = color.toJS;
  ctx.beginPath();
  ctx.arc(px, py, radius, 0.0, 2 * math.pi);
  ctx.fill();

  if (label != null) {
    ctx.font = 'bold 10px Inter, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(label, px, py - radius - 5.0);
  }

  ctx.restore();
}

/// Renders interactive hover crosshairs, curve point dot, and glassmorphic tooltip card.
void drawCrosshairAndTooltip(
  web.CanvasRenderingContext2D ctx,
  PlotViewport vp, {
  required double targetX,
  required double targetY,
  required List<String> tooltipLines,
  required String color,
}) {
  final px = vp.toPixelX(targetX);
  final py = vp
      .toPixelY(targetY)
      .clamp(vp.topMargin, vp.topMargin + vp.plotHeight);

  ctx.save();

  // 1. Crosshair lines
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)'.toJS;
  ctx.lineWidth = 1.0;
  ctx.beginPath();
  ctx.moveTo(px, vp.topMargin);
  ctx.lineTo(px, vp.topMargin + vp.plotHeight);
  ctx.stroke();

  // 2. Highlight dot
  ctx.fillStyle = '${color}3b'.toJS;
  ctx.beginPath();
  ctx.arc(px, py, 6.0, 0.0, 2 * math.pi);
  ctx.fill();

  ctx.fillStyle = color.toJS;
  ctx.beginPath();
  ctx.arc(px, py, 3.0, 0.0, 2 * math.pi);
  ctx.fill();

  // 3. Floating Tooltip Card
  const cardW = 140.0;
  final cardH = 20.0 + tooltipLines.length * 16.0;

  var cardX = px + 12.0;
  if (cardX + cardW > vp.leftMargin + vp.plotWidth) {
    cardX = px - cardW - 12.0;
  }

  var cardY = py - cardH - 12.0;
  if (cardY < vp.topMargin) {
    cardY = py + 12.0;
  }
  if (cardY + cardH > vp.topMargin + vp.plotHeight) {
    cardY = vp.topMargin + vp.plotHeight - cardH;
  }

  ctx.fillStyle = 'rgba(15, 23, 42, 0.90)'.toJS;
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)'.toJS;
  ctx.lineWidth = 1.0;
  ctx.beginPath();
  ctx.rect(cardX, cardY, cardW, cardH);
  ctx.fill();
  ctx.stroke();

  // Text Lines
  ctx.textAlign = 'left';
  for (var i = 0; i < tooltipLines.length; i++) {
    if (i == 0) {
      ctx.fillStyle = '#f8fafc'.toJS;
      ctx.font = 'bold 11px Inter, sans-serif';
    } else {
      ctx.fillStyle = 'rgba(248, 250, 252, 0.75)'.toJS;
      ctx.font = '10px Inter, sans-serif';
    }
    ctx.fillText(tooltipLines[i], cardX + 8.0, cardY + 16.0 + i * 16.0);
  }

  ctx.restore();
}

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/numeric.dart';
import 'package:web/web.dart' as web;

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

/// Sets up a high-DPI crisp canvas backing store. Returns null if dimensions are zero.
(web.CanvasRenderingContext2D, double, double)? initCanvas(
  web.HTMLCanvasElement canvas,
) {
  final rect = canvas.parentElement?.getBoundingClientRect();
  if (rect == null || rect.width <= 0 || rect.height <= 0) return null;

  final dpr = web.window.devicePixelRatio;
  final width = rect.width;
  final height = rect.height;

  canvas.width = (width * dpr).toInt();
  canvas.height = (height * dpr).toInt();
  canvas.style.width = '${width}px';
  canvas.style.height = '${height}px';

  final ctx = canvas.context2D;
  ctx.scale(dpr, dpr);
  ctx.clearRect(0, 0, width, height);

  return (ctx, width, height);
}

/// Draws Cartesian grid lines, tick labels, and axes.
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
  ctx.font = '10px Inter, sans-serif';

  // 1. Vertical grid lines & X ticks
  for (var i = 0; i < xTicks; i++) {
    final xVal = vp.minX + i * (vp.maxX - vp.minX) / (xTicks - 1);
    final px = vp.toPixelX(xVal);

    ctx.beginPath();
    ctx.moveTo(px, vp.topMargin);
    ctx.lineTo(px, vp.topMargin + vp.plotHeight);
    ctx.stroke();

    ctx.textAlign = 'center';
    final label = (xVal.abs() < 1e-10)
        ? '0'
        : (xVal % 1 == 0 && xVal.abs() < 1e6)
        ? xVal.toInt().toString()
        : xVal.toStringAsFixed(2);
    ctx.fillText(label, px, vp.topMargin + vp.plotHeight + 15);
  }

  // 2. Horizontal grid lines & Y ticks
  for (var i = 0; i < yTicks; i++) {
    final yVal = vp.minY + i * (vp.maxY - vp.minY) / (yTicks - 1);
    final py = vp.toPixelY(yVal);

    ctx.beginPath();
    ctx.moveTo(vp.leftMargin, py);
    ctx.lineTo(vp.leftMargin + vp.plotWidth, py);
    ctx.stroke();

    ctx.textAlign = 'right';
    final label = (yVal.abs() < 1e-10)
        ? '0'
        : (yVal % 1 == 0 && yVal.abs() < 1e6)
        ? yVal.toInt().toString()
        : yVal.toStringAsFixed(2);
    ctx.fillText(label, vp.leftMargin - 8, py + 3);
  }

  // 3. Highlighted Zero axes
  if (drawZeroAxes) {
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)'.toJS;
    ctx.lineWidth = 1.0;

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

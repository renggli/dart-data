import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/type.dart';
import 'package:web/web.dart' as web;

import '../../../shared/chart.dart';

/// Incremental, non-blocking OKLCH domain-coloring renderer for a complex
/// function `f(z)` over a [PlotViewport].
///
/// Renders rows in time-budgeted slices so expensive special functions (such as
/// `zeta(z)`) never stall panning, zooming, or slider interaction.
///
/// Visual encoding:
/// - **Hue**: Perceptually uniform cyclic OKLCH hue derived directly from
///   `z / |z|` without redundant `cos`/`sin` calls.
/// - **Lightness**: Monotonic magnitude compression `L = sqrt(r) / (sqrt(r) + 1)`
///   mapping `0 -> black`, `1 -> mid-tone`, and `infinity -> white`.
/// - **Wegert contours**: Periodic sawtooth shading on `log2(|f(z)|)` and 16
///   orthogonal phase rays.
final class DomainColoringPass {
  /// Starts a new domain-coloring render pass into [offscreenCanvas].
  new({
    required this.offscreenCanvas,
    required this.fn,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required double plotWidth,
    required double plotHeight,
    required this.paramVersion,
    required this.pixelStep,
  }) : plotWidth = plotWidth,
       plotHeight = plotHeight,
       width = math.max(1, (plotWidth / pixelStep).ceil()),
       height = math.max(1, (plotHeight / pixelStep).ceil()) {
    if (offscreenCanvas.width != width || offscreenCanvas.height != height) {
      offscreenCanvas.width = width;
      offscreenCanvas.height = height;
    }
    _offCtx = offscreenCanvas.context2D;
    _imgData = _offCtx.createImageData(width.toJS, height);
    _rgba = _imgData.data.toDart;
    _dx = (maxX - minX) / width;
    _dy = (maxY - minY) / height;
  }

  /// Target offscreen canvas receiving the rendered pixels.
  final web.HTMLCanvasElement offscreenCanvas;

  /// Compiled complex evaluator `f(z)`.
  final Complex Function(Complex z) fn;

  /// Viewport bounds and dimensions for cache validation.
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final double plotWidth;
  final double plotHeight;
  final int paramVersion;
  final int pixelStep;

  /// Offscreen buffer dimensions in pixels.
  final int width;
  final int height;

  /// Whether all rows have been rendered and committed to [offscreenCanvas].
  bool get isComplete => _nextRow >= height;

  /// Whether this pass matches the exact viewport and parameter state.
  bool matches(PlotViewport vp, int currentParamVersion) =>
      minX == vp.minX &&
      maxX == vp.maxX &&
      minY == vp.minY &&
      maxY == vp.maxY &&
      plotWidth == vp.plotWidth &&
      plotHeight == vp.plotHeight &&
      paramVersion == currentParamVersion;

  /// Renders rows until either [budgetMs] milliseconds have elapsed or the pass
  /// completes, then flushes the updated image data to [offscreenCanvas].
  ///
  /// Returns `true` when the entire image is complete.
  bool renderChunk({int budgetMs = 12}) {
    if (isComplete) return true;
    final sw = Stopwatch()..start();

    const twoPi = 2.0 * math.pi;
    const invLn2 = 1.0 / math.ln2;
    const phaseRays = 16.0;

    while (_nextRow < height) {
      final py = _nextRow++;
      final im = maxY - (py + 0.5) * _dy;
      var offset = py * width * 4;

      for (var px = 0; px < width; px++) {
        final re = minX + (px + 0.5) * _dx;

        Complex val;
        try {
          val = fn(Complex(re, im));
        } on Object {
          val = Complex.nan;
        }

        final u = val.real.toDouble();
        final v = val.imaginary.toDouble();

        int r8;
        int g8;
        int b8;

        if (u.isNaN || v.isNaN) {
          r8 = 15;
          g8 = 23;
          b8 = 42;
        } else if (u.isInfinite || v.isInfinite) {
          r8 = 255;
          g8 = 255;
          b8 = 255;
        } else {
          final mag2 = u * u + v * v;
          if (mag2 == 0.0) {
            r8 = 0;
            g8 = 0;
            b8 = 0;
          } else if (mag2.isInfinite) {
            r8 = 255;
            g8 = 255;
            b8 = 255;
          } else {
            final mag = math.sqrt(mag2);
            final invMag = 1.0 / mag;
            final cosH = u * invMag;
            final sinH = v * invMag;

            // Monotonic magnitude compression: 0 -> 0, 1 -> 0.5, inf -> 1
            final sqrtMag = math.sqrt(mag);
            final baseL = sqrtMag / (sqrtMag + 1.0);

            // Wegert's logarithmic magnitude sawtooth & 16 phase rays
            final log2r = 0.5 * math.log(mag2) * invLn2;
            final magSaw = log2r - log2r.floorToDouble();
            final phase = math.atan2(v, u);
            final rayPos = ((phase + math.pi) / twoPi) * phaseRays;
            final raySaw = rayPos - rayPos.floorToDouble();

            final l = (baseL + (magSaw - 0.5) * 0.13 + (raySaw - 0.5) * 0.055)
                .clamp(0.02, 0.98);
            final c = 0.54 * baseL * (1.0 - baseL);

            (:r8, :g8, :b8) = _oklchToSrgb8(l, c * cosH, c * sinH);
          }
        }

        _rgba[offset] = r8;
        _rgba[offset + 1] = g8;
        _rgba[offset + 2] = b8;
        _rgba[offset + 3] = 255;
        offset += 4;
      }

      if (budgetMs > 0 && sw.elapsedMilliseconds >= budgetMs) {
        break;
      }
    }

    if (isComplete) {
      _offCtx.putImageData(_imgData, 0, 0);
    }
    return isComplete;
  }

  /// Draws the completed offscreen image mapped onto [vp] (warping smoothly if
  /// the viewport has panned/zoomed since this pass was rendered).
  void drawOnto(web.CanvasRenderingContext2D ctx, PlotViewport vp) {
    if (!isComplete || offscreenCanvas.width == 0) return;

    final dx = vp.toPixelX(minX);
    final dy = vp.toPixelY(maxY);
    final dw = vp.toPixelX(maxX) - dx;
    final dh = vp.toPixelY(minY) - dy;
    if (dw <= 0 || dh <= 0) return;

    ctx.save();
    ctx.beginPath();
    ctx.rect(vp.leftMargin, vp.topMargin, vp.plotWidth, vp.plotHeight);
    ctx.clip();
    ctx.imageSmoothingEnabled = true;
    ctx.drawImage(offscreenCanvas, dx, dy, dw, dh);
    ctx.restore();
  }

  late final web.CanvasRenderingContext2D _offCtx;
  late final web.ImageData _imgData;
  late final Uint8ClampedList _rgba;
  late final double _dx;
  late final double _dy;
  var _nextRow = 0;
}

final Uint8List _srgbLut = () {
  final lut = Uint8List(1024);
  for (var i = 0; i < 1024; i++) {
    final c = i / 1023.0;
    final srgb = c <= 0.0031308
        ? 12.92 * c
        : 1.055 * math.pow(c, 1.0 / 2.4) - 0.055;
    lut[i] = (srgb * 255.0).round().clamp(0, 255);
  }
  return lut;
}();

({int r8, int g8, int b8}) _oklchToSrgb8(double l, double a, double b) {
  // OKLab -> LMS'
  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

  final lmsL = l_ * l_ * l_;
  final lmsM = m_ * m_ * m_;
  final lmsS = s_ * s_ * s_;

  // LMS -> linear sRGB
  final lr = 4.0767416621 * lmsL - 3.3077115913 * lmsM + 0.2309699292 * lmsS;
  final lg = -1.2684380046 * lmsL + 2.6097574011 * lmsM - 0.3413193965 * lmsS;
  final lb = -0.0041960863 * lmsL - 0.7034186147 * lmsM + 1.7076147010 * lmsS;

  return (
    r8: _linearToSrgb8(lr),
    g8: _linearToSrgb8(lg),
    b8: _linearToSrgb8(lb),
  );
}

int _linearToSrgb8(double c) {
  if (c <= 0.0) return 0;
  if (c >= 1.0) return 255;
  return _srgbLut[(c * 1023.0).round()];
}

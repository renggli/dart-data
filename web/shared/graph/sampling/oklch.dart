import 'dart:math' as math;
import 'dart:typed_data';

import '../model/axis.dart';
import '../model/dataset_2d.dart';
import '../model/style.dart';

/// Converts OKLCH color `(l, c, hRadians)` to clamped sRGB bytes `(r, g, b)`.
({int r, int g, int b}) oklchToSrgb(double l, double c, double hRadians) {
  final a = c * math.cos(hRadians);
  final b = c * math.sin(hRadians);

  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

  final l3 = l_ * l_ * l_;
  final m3 = m_ * m_ * m_;
  final s3 = s_ * s_ * s_;

  final lr = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
  final mg = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  final sb = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

  return (
    r: _linearToSrgbByte(lr),
    g: _linearToSrgbByte(mg),
    b: _linearToSrgbByte(sb),
  );
}

/// Computes an RGBA pixel for complex output `(re, im)` using Wegert phase-modulus shading.
({int r, int g, int b, int a}) sampleDomainColoringRgba(double re, double im) {
  if (!re.isFinite || !im.isFinite) {
    return (r: 255, g: 255, b: 255, a: 255);
  }
  final mag = math.sqrt(re * re + im * im);
  if (mag == 0.0) {
    return (r: 0, g: 0, b: 0, a: 255);
  }
  final arg = math.atan2(im, re);
  final logMag = math.log(mag) / math.ln2;
  final frac = logMag - logMag.floorToDouble();
  final contour = 0.85 + 0.15 * frac;
  final baseL = (0.15 + 0.7 * (1.0 - 1.0 / (1.0 + math.sqrt(mag)))).clamp(
    0.05,
    0.95,
  );
  final lightness = (baseL * contour).clamp(0.0, 1.0);
  final rgb = oklchToSrgb(lightness, 0.16, arg);
  return (r: rgb.r, g: rgb.g, b: rgb.b, a: 255);
}

/// Samples a complex function `f(x + i*y)` onto a [Field2DDataset] with OKLCH domain coloring.
Field2DDataset sampleComplexDomainGrid({
  required String id,
  required String label,
  required ({double re, double im}) Function(double x, double y) fn,
  required Bounds2D domain,
  int cols = 160,
  int rows = 160,
}) {
  final safeCols = math.max(2, cols);
  final safeRows = math.max(2, rows);
  final pixels = Uint8List(safeCols * safeRows * 4);
  final samples = <Field2DSample>[];

  for (var row = 0; row < safeRows; row++) {
    final y = domain.yMin + (row / (safeRows - 1)) * domain.ySpan;
    for (var col = 0; col < safeCols; col++) {
      final x = domain.xMin + (col / (safeCols - 1)) * domain.xSpan;
      final z = fn(x, y);
      final rgba = sampleDomainColoringRgba(z.re, z.im);
      final base = (row * safeCols + col) * 4;
      pixels[base] = rgba.r;
      pixels[base + 1] = rgba.g;
      pixels[base + 2] = rgba.b;
      pixels[base + 3] = rgba.a;
      samples.add(
        Field2DSample(
          x: x,
          y: y,
          u: z.re,
          v: z.im,
          scalar: math.sqrt(z.re * z.re + z.im * z.im),
        ),
      );
    }
  }

  return Field2DDataset(
    id: id,
    label: label,
    cols: safeCols,
    rows: safeRows,
    domain: domain,
    samples: samples,
    colormap: Colormap.oklchPhase,
    showRaster: true,
    showVectors: false,
    rgbaPixels: pixels,
  );
}

int _linearToSrgbByte(double c) {
  final clamped = c.clamp(0.0, 1.0);
  final srgb = clamped <= 0.0031308
      ? 12.92 * clamped
      : 1.055 * math.pow(clamped, 1.0 / 2.4) - 0.055;
  return (srgb * 255.0).round().clamp(0, 255);
}

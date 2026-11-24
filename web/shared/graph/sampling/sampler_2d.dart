import 'dart:math' as math;
import 'dart:typed_data';

import '../model/axis.dart';
import '../model/dataset.dart';
import '../model/dataset_2d.dart';
import '../model/style.dart';

/// Adaptively samples a 1D function `y = fn(x)` over `[xMin, xMax]` into a [Function2DDataset].
Function2DDataset sampleFunction2D({
  required String id,
  required String label,
  required double Function(double x) fn,
  required double xMin,
  required double xMax,
  required String color,
  int baseSamples = 256,
  int maxDepth = 5,
  double width = 2.0,
  bool dashed = false,
  CurveRenderMode mode = CurveRenderMode.continuous,
  YAxisSide yAxis = YAxisSide.left,
  AreaFill? fill,
  List<PointMarker> markers = const <PointMarker>[],
  List<ReferenceLine> references = const <ReferenceLine>[],
}) {
  final count = math.max(8, baseSamples);
  final xs = <double>[];
  final ys = <double>[];
  final step = (xMax - xMin) / (count - 1);

  final baseX = List<double>.generate(
    count,
    (i) => i == count - 1 ? xMax : xMin + i * step,
    growable: false,
  );
  final baseY = List<double>.generate(
    count,
    (i) => _safeEval(fn, baseX[i]),
    growable: false,
  );

  // Estimate vertical scale to detect discontinuities and high-curvature intervals.
  final finiteYs = baseY.where((y) => y.isFinite).toList()..sort();
  var yScale = 1.0;
  if (finiteYs.length >= 4) {
    final q1 = finiteYs[finiteYs.length ~/ 4];
    final q3 = finiteYs[(3 * finiteYs.length) ~/ 4];
    yScale = math.max(1e-6, (q3 - q1).abs());
  } else if (finiteYs.length >= 2) {
    yScale = math.max(1e-6, (finiteYs.last - finiteYs.first).abs());
  }

  for (var i = 0; i < count - 1; i++) {
    final x0 = baseX[i];
    final y0 = baseY[i];
    final x1 = baseX[i + 1];
    final y1 = baseY[i + 1];

    xs.add(x0);
    ys.add(y0);
    _refineInterval(
      fn: fn,
      x0: x0,
      y0: y0,
      x1: x1,
      y1: y1,
      yScale: yScale,
      depth: 0,
      maxDepth: maxDepth,
      xs: xs,
      ys: ys,
    );
  }
  xs.add(baseX.last);
  ys.add(baseY.last);

  // Insert NaN breaks across steep sign-flipping asymptotes.
  final jumpThreshold = yScale * 25.0;
  for (var i = 1; i < ys.length; i++) {
    final prev = ys[i - 1];
    final curr = ys[i];
    if (prev.isFinite &&
        curr.isFinite &&
        (prev - curr).abs() > jumpThreshold &&
        prev.sign != curr.sign) {
      ys[i - 1] = double.nan;
    }
  }

  return Function2DDataset(
    id: id,
    label: label,
    xs: Float64List.fromList(xs),
    ys: Float64List.fromList(ys),
    color: color,
    width: width,
    dashed: dashed,
    mode: mode,
    yAxis: yAxis,
    fill: fill,
    markers: markers,
    references: references,
  );
}

/// Samples a parametric 2D curve `(x(t), y(t))` over `[tMin, tMax]`.
Parametric2DDataset sampleParametric2D({
  required String id,
  required String label,
  required ({double x, double y}) Function(double t) fn,
  required double tMin,
  required double tMax,
  required String color,
  int samples = 360,
  double width = 2.0,
  bool dashed = false,
}) {
  final count = math.max(8, samples);
  final ts = Float64List(count);
  final xs = Float64List(count);
  final ys = Float64List(count);
  final dt = (tMax - tMin) / (count - 1);

  for (var i = 0; i < count; i++) {
    final t = i == count - 1 ? tMax : tMin + i * dt;
    ts[i] = t;
    try {
      final p = fn(t);
      xs[i] = p.x.isFinite ? p.x : double.nan;
      ys[i] = p.y.isFinite ? p.y : double.nan;
    } on Object {
      xs[i] = double.nan;
      ys[i] = double.nan;
    }
  }

  return Parametric2DDataset(
    id: id,
    label: label,
    ts: ts,
    xs: xs,
    ys: ys,
    color: color,
    width: width,
    dashed: dashed,
  );
}

/// Samples a 2D scalar field `z = fn(x, y)` into a rasterized [Field2DDataset].
Field2DDataset sampleScalarField2D({
  required String id,
  required String label,
  required double Function(double x, double y) fn,
  required Bounds2D domain,
  int cols = 96,
  int rows = 96,
  Colormap colormap = Colormap.viridis,
}) {
  final safeCols = math.max(2, cols);
  final safeRows = math.max(2, rows);
  final samples = <Field2DSample>[];
  var zMin = double.infinity;
  var zMax = double.negativeInfinity;

  for (var row = 0; row < safeRows; row++) {
    final y = domain.yMin + (row / (safeRows - 1)) * domain.ySpan;
    for (var col = 0; col < safeCols; col++) {
      final x = domain.xMin + (col / (safeCols - 1)) * domain.xSpan;
      final z = _safeEval2(fn, x, y);
      if (z.isFinite) {
        if (z < zMin) zMin = z;
        if (z > zMax) zMax = z;
      }
      samples.add(Field2DSample(x: x, y: y, scalar: z));
    }
  }

  final pixels = Uint8List(safeCols * safeRows * 4);
  final span = (zMax - zMin).abs();
  final hasRange = zMin.isFinite && zMax.isFinite && span > 0;

  for (var i = 0; i < samples.length; i++) {
    final z = samples[i].scalar;
    final base = i * 4;
    if (!z.isFinite) {
      pixels[base] = 0;
      pixels[base + 1] = 0;
      pixels[base + 2] = 0;
      pixels[base + 3] = 0;
      continue;
    }
    final t = hasRange ? ((z - zMin) / span).clamp(0.0, 1.0) : 0.5;
    final rgba = colormap.sampleRgba(t);
    pixels[base] = rgba.r;
    pixels[base + 1] = rgba.g;
    pixels[base + 2] = rgba.b;
    pixels[base + 3] = rgba.a;
  }

  return Field2DDataset(
    id: id,
    label: label,
    cols: safeCols,
    rows: safeRows,
    domain: domain,
    samples: samples,
    colormap: colormap,
    showRaster: true,
    showVectors: false,
    rgbaPixels: pixels,
    minLabel: zMin.isFinite ? formatGraphNumber(zMin) : '',
    maxLabel: zMax.isFinite ? formatGraphNumber(zMax) : '',
  );
}

/// Samples a 2D vector field `(u(x, y), v(x, y))` into a [Field2DDataset].
Field2DDataset sampleVectorField2D({
  required String id,
  required String label,
  required ({double u, double v}) Function(double x, double y) fn,
  required Bounds2D domain,
  int cols = 16,
  int rows = 16,
  Colormap colormap = Colormap.plasma,
  bool showRaster = false,
}) {
  final safeCols = math.max(2, cols);
  final safeRows = math.max(2, rows);
  final samples = <Field2DSample>[];
  var maxMag = 0.0;

  for (var row = 0; row < safeRows; row++) {
    final y = domain.yMin + (row / (safeRows - 1)) * domain.ySpan;
    for (var col = 0; col < safeCols; col++) {
      final x = domain.xMin + (col / (safeCols - 1)) * domain.xSpan;
      var u = double.nan;
      var v = double.nan;
      try {
        final vec = fn(x, y);
        u = vec.u;
        v = vec.v;
      } on Object {
        u = double.nan;
        v = double.nan;
      }
      final mag = u.isFinite && v.isFinite
          ? math.sqrt(u * u + v * v)
          : double.nan;
      if (mag.isFinite && mag > maxMag) maxMag = mag;
      samples.add(Field2DSample(x: x, y: y, u: u, v: v, scalar: mag));
    }
  }

  Uint8List? pixels;
  if (showRaster) {
    pixels = Uint8List(safeCols * safeRows * 4);
    for (var i = 0; i < samples.length; i++) {
      final mag = samples[i].scalar;
      final base = i * 4;
      if (!mag.isFinite) {
        pixels[base + 3] = 0;
        continue;
      }
      final t = maxMag > 0 ? (mag / maxMag).clamp(0.0, 1.0) : 0.0;
      final rgba = colormap.sampleRgba(t);
      pixels[base] = rgba.r;
      pixels[base + 1] = rgba.g;
      pixels[base + 2] = rgba.b;
      pixels[base + 3] = 160;
    }
  }

  return Field2DDataset(
    id: id,
    label: label,
    cols: safeCols,
    rows: safeRows,
    domain: domain,
    samples: samples,
    colormap: colormap,
    showRaster: showRaster,
    showVectors: true,
    rgbaPixels: pixels,
    minLabel: '0',
    maxLabel: formatGraphNumber(maxMag),
  );
}

double _safeEval(double Function(double x) fn, double x) {
  try {
    final y = fn(x);
    return y.isFinite ? y : double.nan;
  } on Object {
    return double.nan;
  }
}

double _safeEval2(double Function(double x, double y) fn, double x, double y) {
  try {
    final z = fn(x, y);
    return z.isFinite ? z : double.nan;
  } on Object {
    return double.nan;
  }
}

void _refineInterval({
  required double Function(double x) fn,
  required double x0,
  required double y0,
  required double x1,
  required double y1,
  required double yScale,
  required int depth,
  required int maxDepth,
  required List<double> xs,
  required List<double> ys,
}) {
  if (depth >= maxDepth) return;
  final xm = 0.5 * (x0 + x1);
  final ym = _safeEval(fn, xm);

  var needsRefine = false;
  if (!y0.isFinite || !y1.isFinite || !ym.isFinite) {
    needsRefine = y0.isFinite || y1.isFinite || ym.isFinite;
  } else {
    final expected = 0.5 * (y0 + y1);
    final err = (ym - expected).abs();
    if (err > yScale * 0.015 || (y1 - y0).abs() > yScale * 0.5) {
      needsRefine = true;
    }
  }

  if (!needsRefine) return;

  _refineInterval(
    fn: fn,
    x0: x0,
    y0: y0,
    x1: xm,
    y1: ym,
    yScale: yScale,
    depth: depth + 1,
    maxDepth: maxDepth,
    xs: xs,
    ys: ys,
  );
  xs.add(xm);
  ys.add(ym);
  _refineInterval(
    fn: fn,
    x0: xm,
    y0: ym,
    x1: x1,
    y1: y1,
    yScale: yScale,
    depth: depth + 1,
    maxDepth: maxDepth,
    xs: xs,
    ys: ys,
  );
}

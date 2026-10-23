import 'dart:math' as math;

import '../../linear.dart';
import '../../type.dart';
import '../tensor/layout.dart';
import '../tensor/tensor.dart';

/// A single continuous polyline segment of a sampled 1D curve.
typedef CurveSegment = ({Vector<double> x, Vector<double> y});

/// Result of adaptive 1D curve sampling produced by [sampleCurve].
final class CurveSample {
  /// Creates a sampled curve with continuous [segments] and robust vertical
  /// bounds `[yMin, yMax]`.
  const new({required this.segments, required this.yMin, required this.yMax});

  /// Disjoint continuous curve segments separated by domain gaps, jump
  /// discontinuities, or vertical asymptotes.
  final List<CurveSegment> segments;

  /// Robust lower vertical bound (clipped to the 2nd–98th percentile when
  /// vertical asymptotes are present).
  final double yMin;

  /// Robust upper vertical bound (clipped to the 2nd–98th percentile when
  /// vertical asymptotes are present).
  final double yMax;

  /// Total number of sampled points across all [segments].
  int get pointCount {
    var total = 0;
    for (final segment in segments) {
      total += segment.x.length;
    }
    return total;
  }
}

/// Generates a [Vector] with a sequence of [count] evenly spaced values over
/// the interval `[start, stop]`.
///
/// Conceptually, this partitions the continuous line segment between [start]
/// and [stop] into equal step increments, equivalent to NumPy's `linspace`.
///
/// When [endpoint] is `true` (the default), [stop] is included as the final
/// element of the vector. When [endpoint] is `false`, the step size is
/// `(stop - start) / count` and [stop] is excluded.
///
/// ```dart
/// final grid = linearSpaced(0.0, 1.0, count: 5);
/// // [0.0, 0.25, 0.5, 0.75, 1.0]
/// ```
Vector<double> linearSpaced(
  double start,
  double stop, {
  int count = 50,
  bool endpoint = true,
  DataType<double>? type,
}) {
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
  }
  final effectiveType = type ?? DataType.float64;
  final data = effectiveType.newList(count);
  if (count == 1) {
    data[0] = start;
  } else if (count > 1) {
    final divisor = endpoint ? count - 1 : count;
    for (var i = 0; i < count; i++) {
      if (i == 0) {
        data[i] = start;
      } else if (endpoint && i == count - 1) {
        data[i] = stop;
      } else {
        final t = i / divisor;
        data[i] = start * (1.0 - t) + stop * t;
      }
    }
  }
  return Vector(
    Tensor.internal(
      type: effectiveType,
      layout: Layout(shape: [count]),
      data: data,
    ),
  );
}

/// Generates a [Vector] with a sequence of [count] evenly spaced values on a
/// logarithmic scale over `[base^start, base^stop]`.
///
/// Conceptually, this evaluates base raised to powers that are linearly spaced
/// from [start] to [stop], equivalent to NumPy's `logspace`.
///
/// Base defaults to 10.0.
///
/// ```dart
/// final freq = logarithmicSpaced(0.0, 3.0, count: 4);
/// // [1.0, 10.0, 100.0, 1000.0]
/// ```
Vector<double> logarithmicSpaced(
  double start,
  double stop, {
  int count = 50,
  double base = 10.0,
  bool endpoint = true,
  DataType<double>? type,
}) {
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
  }
  if (base <= 0.0) {
    throw ArgumentError.value(base, 'base', 'Base must be positive.');
  }
  final effectiveType = type ?? DataType.float64;
  final data = effectiveType.newList(count);
  if (count == 1) {
    data[0] = math.pow(base, start).toDouble();
  } else if (count > 1) {
    final divisor = endpoint ? count - 1 : count;
    for (var i = 0; i < count; i++) {
      if (i == 0) {
        data[i] = math.pow(base, start).toDouble();
      } else if (endpoint && i == count - 1) {
        data[i] = math.pow(base, stop).toDouble();
      } else {
        final t = i / divisor;
        final exp = start * (1.0 - t) + stop * t;
        data[i] = math.pow(base, exp).toDouble();
      }
    }
  }
  return Vector(
    Tensor.internal(
      type: effectiveType,
      layout: Layout(shape: [count]),
      data: data,
    ),
  );
}

/// Generates a [Vector] with a sequence of [count] geometrically spaced values
/// over the interval `[start, stop]`.
///
/// Conceptually, this generates numbers spaced evenly on a log scale with the
/// start and stop points specified directly, equivalent to NumPy's `geomspace`.
/// Both [start] and [stop] must be non-zero and share the same sign.
///
/// ```dart
/// final scale = geometricSpaced(1.0, 1000.0, count: 4);
/// // [1.0, 10.0, 100.0, 1000.0]
/// ```
Vector<double> geometricSpaced(
  double start,
  double stop, {
  int count = 50,
  bool endpoint = true,
  DataType<double>? type,
}) {
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
  }
  if (start == 0.0) {
    throw ArgumentError.value(
      start,
      'start',
      'Geometric spacing requires non-zero start.',
    );
  }
  if (stop == 0.0) {
    throw ArgumentError.value(
      stop,
      'stop',
      'Geometric spacing requires non-zero stop.',
    );
  }
  if ((start > 0.0) != (stop > 0.0)) {
    throw ArgumentError(
      'Geometric spacing requires start ($start) and stop ($stop) to have the same sign.',
    );
  }
  final sign = start > 0.0 ? 1.0 : -1.0;
  final logStart = math.log(start.abs());
  final logStop = math.log(stop.abs());
  final effectiveType = type ?? DataType.float64;
  final data = effectiveType.newList(count);
  if (count == 1) {
    data[0] = start;
  } else if (count > 1) {
    final divisor = endpoint ? count - 1 : count;
    for (var i = 0; i < count; i++) {
      if (i == 0) {
        data[i] = start;
      } else if (endpoint && i == count - 1) {
        data[i] = stop;
      } else {
        final t = i / divisor;
        final logVal = logStart * (1.0 - t) + logStop * t;
        data[i] = sign * math.exp(logVal);
      }
    }
  }
  return Vector(
    Tensor.internal(
      type: effectiveType,
      layout: Layout(shape: [count]),
      data: data,
    ),
  );
}

/// Adaptively samples a 1D function [f] over `[a, b]` with curvature refinement
/// and automatic splitting at vertical asymptotes, jump discontinuities, and
/// out-of-domain intervals.
///
/// Starts from an initial grid of [initialPoints] samples and recursively
/// bisects intervals whose midpoint deviates from linear interpolation by more
/// than [tolerance] times the characteristic vertical scale, up to [maxPoints]
/// total evaluations.
///
/// ```dart
/// final sample = sampleCurve((x) => 1.0 / x, -1.0, 1.0);
/// print(sample.segments.length); // 2
/// ```
CurveSample sampleCurve(
  double Function(double) f,
  double a,
  double b, {
  int initialPoints = 65,
  int maxPoints = 2048,
  double tolerance = 1e-3,
}) {
  if (!a.isFinite || !b.isFinite || a >= b) {
    throw ArgumentError('Interval [a, b] must be finite with a < b: [$a, $b]');
  }
  if (initialPoints < 3) {
    throw ArgumentError.value(
      initialPoints,
      'initialPoints',
      'Must be at least 3',
    );
  }
  if (maxPoints < initialPoints) {
    throw ArgumentError.value(
      maxPoints,
      'maxPoints',
      'Must be at least initialPoints ($initialPoints)',
    );
  }
  if (tolerance <= 0 || !tolerance.isFinite) {
    throw ArgumentError.value(tolerance, 'tolerance', 'Must be positive');
  }

  final span = b - a;
  final step = span / (initialPoints - 1);
  // Slight irrational jitter on interior grid nodes avoids landing exactly on
  // symmetric rational poles while keeping endpoints exact.
  const jitter = 1e-9 * 0.6180339887498949;
  final initialX = List<double>.generate(initialPoints, (i) {
    if (i == 0) return a;
    if (i == initialPoints - 1) return b;
    return a + (i + jitter) * step;
  });
  final initialY = List<double>.generate(
    initialPoints,
    (i) => _evalSafe(f, initialX[i]),
  );

  final yScale = _estimateVerticalScale(initialY);
  final maxDepth = math.min(
    10,
    math.max(1, (math.log(maxPoints / initialPoints) / math.ln2).ceil() + 3),
  );
  var remainingBudget = maxPoints - initialPoints;

  final pointsX = <double>[initialX.first];
  final pointsY = <double>[initialY.first];

  void refine(double x0, double y0, double x1, double y1, int depth) {
    if (remainingBudget <= 0 || depth >= maxDepth) {
      pointsX.add(x1);
      pointsY.add(y1);
      return;
    }

    final xm = 0.5 * (x0 + x1);
    if (xm <= x0 || xm >= x1) {
      pointsX.add(x1);
      pointsY.add(y1);
      return;
    }

    final f0 = y0.isFinite;
    final f1 = y1.isFinite;

    // If neither endpoint is finite, do not bisect further.
    if (!f0 && !f1) {
      pointsX.add(x1);
      pointsY.add(y1);
      return;
    }

    final ym = _evalSafe(f, xm);
    remainingBudget--;
    final fm = ym.isFinite;

    // Domain boundary: one endpoint is finite and the other is not.
    if (f0 != f1 || !fm) {
      refine(x0, y0, xm, ym, depth + 1);
      refine(xm, ym, x1, y1, depth + 1);
      return;
    }

    final linearMid = 0.5 * (y0 + y1);
    final err = (ym - linearMid).abs();
    final dy = (y1 - y0).abs();

    // Subdivide when curvature error exceeds tolerance or across a sharp jump.
    if (err > tolerance * yScale || (dy > 0.25 * yScale && depth < 5)) {
      refine(x0, y0, xm, ym, depth + 1);
      refine(xm, ym, x1, y1, depth + 1);
    } else {
      pointsX.add(xm);
      pointsY.add(ym);
      pointsX.add(x1);
      pointsY.add(y1);
    }
  }

  for (var i = 0; i < initialPoints - 1; i++) {
    refine(initialX[i], initialY[i], initialX[i + 1], initialY[i + 1], 0);
  }

  return _buildSegments(pointsX, pointsY, span, yScale);
}

double _evalSafe(double Function(double) f, double x) {
  try {
    return f(x);
  } on ArgumentError {
    return double.nan;
  } on StateError {
    return double.nan;
  } on UnsupportedError {
    return double.nan;
  } on Exception {
    return double.nan;
  }
}

double _estimateVerticalScale(List<double> ys) {
  final finite = <double>[
    for (final y in ys)
      if (y.isFinite) y,
  ]..sort();
  if (finite.isEmpty) return 1.0;
  final lo = finite[(finite.length * 0.1).floor()];
  final hi = finite[((finite.length - 1) * 0.9).ceil()];
  final span = (hi - lo).abs();
  if (span > 1e-9) return span;
  final maxAbs = math.max(finite.first.abs(), finite.last.abs());
  return maxAbs > 1e-9 ? maxAbs : 1.0;
}

CurveSample _buildSegments(
  List<double> xs,
  List<double> ys,
  double xSpan,
  double yScale,
) {
  final asymptoticCutoff = 100.0 * yScale;
  final segments = <CurveSegment>[];
  var currentX = <double>[];
  var currentY = <double>[];

  void flushSegment() {
    if (currentX.isNotEmpty) {
      segments.add((
        x: Vector<double>.fromList(currentX),
        y: Vector<double>.fromList(currentY),
      ));
      currentX = <double>[];
      currentY = <double>[];
    }
  }

  for (var i = 0; i < xs.length; i++) {
    final x = xs[i];
    final y = ys[i];
    if (!y.isFinite || y.abs() > asymptoticCutoff) {
      flushSegment();
      continue;
    }

    if (currentX.isNotEmpty) {
      final prevX = currentX.last;
      final prevY = currentY.last;
      final dx = x - prevX;
      final dy = y - prevY;
      final absDy = dy.abs();

      var prevDy = 0.0;
      if (currentY.length >= 2) {
        prevDy = prevY - currentY[currentY.length - 2];
      }
      var nextDy = 0.0;
      if (i + 1 < ys.length && ys[i + 1].isFinite) {
        nextDy = ys[i + 1] - y;
      }

      // 1. Asymptotic sign-reversal jump (e.g. tan(x) or 1/x across pole)
      final isAsymptoteFlip =
          absDy > 2.5 * yScale &&
          ((prevDy != 0 && dy * prevDy < 0) ||
              (nextDy != 0 && dy * nextDy < 0));

      // 2. Step / jump discontinuity (e.g. floor(x), sign(x), piecewise jump)
      final neighborMaxDy = math.max(prevDy.abs(), nextDy.abs());
      final secantSlope = dx > 0 ? absDy / dx : double.infinity;
      final isStepJump =
          secantSlope > 60.0 * yScale / xSpan &&
          absDy > 8.0 * neighborMaxDy + 1e-5 * yScale;

      if (isAsymptoteFlip || isStepJump) {
        flushSegment();
      }
    }

    currentX.add(x);
    currentY.add(y);
  }
  flushSegment();

  // Compute robust vertical range [yMin, yMax]
  final allFiniteY = <double>[
    for (final segment in segments)
      for (var i = 0; i < segment.y.length; i++) segment.y[i],
  ]..sort();

  if (allFiniteY.isEmpty) {
    return CurveSample(segments: segments, yMin: -1.0, yMax: 1.0);
  }

  final hasDiscontinuity = segments.length > 1;
  final yMin = hasDiscontinuity
      ? allFiniteY[(allFiniteY.length * 0.02).floor()]
      : allFiniteY.first;
  final yMax = hasDiscontinuity
      ? allFiniteY[((allFiniteY.length - 1) * 0.98).ceil()]
      : allFiniteY.last;

  return CurveSample(
    segments: List<CurveSegment>.unmodifiable(segments),
    yMin: yMin,
    yMax: yMax,
  );
}
